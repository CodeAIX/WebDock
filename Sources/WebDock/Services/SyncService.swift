import CloudKit
import Combine
import Foundation
import SwiftData

extension Notification.Name {
    static let webDockCanonicalDataDidChange = Notification.Name("WebDockCanonicalDataDidChange")
    static let webDockSyncRequested = Notification.Name("WebDockSyncRequested")
    static let webDockSyncPreferenceChanged = Notification.Name("WebDockSyncPreferenceChanged")
}

enum SyncPreferences {
    static let providerKey = "WebDock.syncProvider"
    static let cloudKitContainerIdentifier = "iCloud.io.github.codeaix.WebDock"

    static var providerKind: SyncProviderKind {
        let raw = UserDefaults.standard.string(forKey: providerKey)
        return raw.flatMap(SyncProviderKind.init(rawValue:)) ?? .off
    }
}

struct SyncedShortcutRecord: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
    var normalizedURLString: String
    var preferredBrowserFamilyRaw: String?
    var targetAccountEmail: String?
    var groupID: UUID?
    var sortIndex: Double
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(_ shortcut: WebShortcut) {
        id = shortcut.id
        displayName = shortcut.displayName
        normalizedURLString = shortcut.normalizedURLString
        preferredBrowserFamilyRaw = shortcut.preferredBrowserFamilyRaw
        targetAccountEmail = normalizeAccountEmail(shortcut.targetAccountEmail)
        groupID = shortcut.groupID
        sortIndex = shortcut.sortIndex
        createdAt = shortcut.createdAt
        updatedAt = shortcut.updatedAt
        deletedAt = shortcut.deletedAt
    }
}

struct SyncedGroupRecord: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var sortIndex: Double
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(_ group: ShortcutGroup) {
        id = group.id
        name = group.name
        sortIndex = group.sortIndex
        createdAt = group.createdAt
        updatedAt = group.updatedAt
        deletedAt = group.deletedAt
    }
}

struct SyncSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var shortcuts: [SyncedShortcutRecord]
    var groups: [SyncedGroupRecord]
    var generatedAt: Date

    static var empty: SyncSnapshot {
        SyncSnapshot(shortcuts: [], groups: [], generatedAt: Date(timeIntervalSince1970: 0))
    }
}

struct SyncMergeEngine {
    static func merge(local: SyncSnapshot, remote: SyncSnapshot) -> SyncSnapshot {
        var shortcuts = Dictionary(uniqueKeysWithValues: local.shortcuts.map { ($0.id, $0) })
        for remoteRecord in remote.shortcuts {
            if let localRecord = shortcuts[remoteRecord.id] {
                shortcuts[remoteRecord.id] = remoteRecord.updatedAt > localRecord.updatedAt
                    ? remoteRecord
                    : localRecord
            } else {
                shortcuts[remoteRecord.id] = remoteRecord
            }
        }

        var groups = Dictionary(uniqueKeysWithValues: local.groups.map { ($0.id, $0) })
        for remoteRecord in remote.groups {
            if let localRecord = groups[remoteRecord.id] {
                groups[remoteRecord.id] = remoteRecord.updatedAt > localRecord.updatedAt
                    ? remoteRecord
                    : localRecord
            } else {
                groups[remoteRecord.id] = remoteRecord
            }
        }

        return SyncSnapshot(
            shortcuts: shortcuts.values.sorted { $0.id.uuidString < $1.id.uuidString },
            groups: groups.values.sorted { $0.id.uuidString < $1.id.uuidString },
            generatedAt: Date()
        )
    }
}

@MainActor
protocol CanonicalSyncProvider: AnyObject {
    func load() async throws -> SyncSnapshot?
    func save(_ snapshot: SyncSnapshot) async throws
}

@MainActor
final class CloudKitSyncProvider: CanonicalSyncProvider {
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: "canonical-state")
    private var fetchedRecord: CKRecord?

    init(containerIdentifier: String = SyncPreferences.cloudKitContainerIdentifier) {
        database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    func load() async throws -> SyncSnapshot? {
        do {
            let record = try await database.record(for: recordID)
            fetchedRecord = record
            guard let data = record["payload"] as? Data else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SyncSnapshot.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            fetchedRecord = nil
            return nil
        }
    }

    func save(_ snapshot: SyncSnapshot) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)

        let record = fetchedRecord ?? CKRecord(recordType: "WebDockState", recordID: recordID)
        record["payload"] = data as NSData
        record["schemaVersion"] = NSNumber(value: SyncSnapshot.currentSchemaVersion)
        record["updatedAt"] = Date() as NSDate
        fetchedRecord = try await database.save(record)
    }
}

enum SyncDisplayState: Equatable {
    case idle
    case syncing
    case success(Date)
    case failure(String)
    case unavailable(String)

    var summary: String {
        switch self {
        case .idle:
            "Not syncing"
        case .syncing:
            "Syncing…"
        case .success(let date):
            "Last synced \(date.formatted(date: .omitted, time: .shortened))"
        case .failure(let message):
            "Sync failed: \(message)"
        case .unavailable(let message):
            message
        }
    }
}

@MainActor
final class SyncStatusCenter: ObservableObject {
    static let shared = SyncStatusCenter()
    @Published var state: SyncDisplayState = .idle
    private init() {}
}

@MainActor
final class SyncCoordinator {
    private let modelContainer: ModelContainer
    private var cloudKitProvider: CloudKitSyncProvider?
    private var observers: [NSObjectProtocol] = []
    private var scheduledTask: Task<Void, Never>?
    private var isSyncing = false

    init(
        modelContainer: ModelContainer,
        cloudKitProvider: CloudKitSyncProvider? = nil
    ) {
        self.modelContainer = modelContainer
        self.cloudKitProvider = cloudKitProvider

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .webDockCanonicalDataDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.scheduleSync() }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .webDockSyncRequested,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in await self?.syncNow() }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .webDockSyncPreferenceChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if SyncPreferences.providerKind == .off {
                        self.scheduledTask?.cancel()
                        SyncStatusCenter.shared.state = .idle
                    } else {
                        await self.syncNow()
                    }
                }
            }
        )
    }

    func start() {
        scheduleSync()
    }

    func scheduleSync() {
        guard SyncPreferences.providerKind != .off else { return }
        scheduledTask?.cancel()
        scheduledTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard !isSyncing else { return }
        switch SyncPreferences.providerKind {
        case .off:
            SyncStatusCenter.shared.state = .idle
            return
        case .webDAV:
            SyncStatusCenter.shared.state = .unavailable(
                "WebDAV uses the same portable sync schema and is the next provider; iCloud is the active implementation."
            )
            return
        case .iCloud:
            break
        }

        isSyncing = true
        SyncStatusCenter.shared.state = .syncing
        defer { isSyncing = false }

        do {
            try await synchronizeWithCloudKit()
            SyncStatusCenter.shared.state = .success(Date())
        } catch let error as CKError where error.code == .serverRecordChanged {
            do {
                try await synchronizeWithCloudKit()
                SyncStatusCenter.shared.state = .success(Date())
            } catch {
                SyncStatusCenter.shared.state = .failure(error.localizedDescription)
            }
        } catch {
            SyncStatusCenter.shared.state = .failure(error.localizedDescription)
        }
    }

    private func iCloudProvider() -> CloudKitSyncProvider {
        if let cloudKitProvider { return cloudKitProvider }
        let provider = CloudKitSyncProvider()
        cloudKitProvider = provider
        return provider
    }

    private func synchronizeWithCloudKit() async throws {
        let provider = iCloudProvider()
        let local = try localSnapshot()
        let remote = try await provider.load() ?? .empty
        let merged = SyncMergeEngine.merge(local: local, remote: remote)
        try apply(merged)
        let refreshed = try localSnapshot()
        try await provider.save(refreshed)
    }

    private func localSnapshot() throws -> SyncSnapshot {
        let context = modelContainer.mainContext
        let shortcuts = try context.fetch(FetchDescriptor<WebShortcut>())
        let groups = try context.fetch(FetchDescriptor<ShortcutGroup>())
        return SyncSnapshot(
            shortcuts: shortcuts.map(SyncedShortcutRecord.init),
            groups: groups.map(SyncedGroupRecord.init),
            generatedAt: Date()
        )
    }

    private func apply(_ snapshot: SyncSnapshot) throws {
        let context = modelContainer.mainContext
        let localShortcuts = try context.fetch(FetchDescriptor<WebShortcut>())
        var shortcutByID = Dictionary(uniqueKeysWithValues: localShortcuts.map { ($0.id, $0) })

        for record in snapshot.shortcuts {
            let shortcut: WebShortcut
            if let existing = shortcutByID[record.id] {
                shortcut = existing
            } else {
                shortcut = WebShortcut(
                    id: record.id,
                    displayName: record.displayName,
                    normalizedURLString: record.normalizedURLString,
                    preferredBrowserFamily: record.preferredBrowserFamilyRaw.flatMap(BrowserFamily.init(rawValue:)),
                    targetAccountEmail: record.targetAccountEmail,
                    groupID: record.groupID,
                    sortIndex: record.sortIndex,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    deletedAt: record.deletedAt
                )
                context.insert(shortcut)
                shortcutByID[record.id] = shortcut
            }
            shortcut.displayName = record.displayName
            shortcut.normalizedURLString = record.normalizedURLString
            shortcut.preferredBrowserFamilyRaw = record.preferredBrowserFamilyRaw
            shortcut.targetAccountEmail = normalizeAccountEmail(record.targetAccountEmail)
            shortcut.groupID = record.groupID
            shortcut.sortIndex = record.sortIndex
            shortcut.createdAt = record.createdAt
            shortcut.updatedAt = record.updatedAt
            shortcut.deletedAt = record.deletedAt
        }

        let localGroups = try context.fetch(FetchDescriptor<ShortcutGroup>())
        var groupByID = Dictionary(uniqueKeysWithValues: localGroups.map { ($0.id, $0) })
        for record in snapshot.groups {
            let group: ShortcutGroup
            if let existing = groupByID[record.id] {
                group = existing
            } else {
                group = ShortcutGroup(id: record.id, name: record.name, sortIndex: record.sortIndex)
                context.insert(group)
                groupByID[record.id] = group
            }
            group.name = record.name
            group.sortIndex = record.sortIndex
            group.createdAt = record.createdAt
            group.updatedAt = record.updatedAt
            group.deletedAt = record.deletedAt
        }

        try context.save()
    }
}
