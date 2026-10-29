import Combine
import Foundation

extension Notification.Name {
    static let webDockCanonicalDataDidChange = Notification.Name("WebDockCanonicalDataDidChange")
    static let webDockSyncRequested = Notification.Name("WebDockSyncRequested")
    static let webDockSyncPreferenceChanged = Notification.Name("WebDockSyncPreferenceChanged")
}

enum SyncPreferences {
    static let providerKey = "WebDock.syncProvider"
    static let syncedFolderPathKey = "WebDock.syncedFolderPath"
    static let webDAVBaseURLKey = "WebDock.webDAVBaseURL"
    static let webDAVUsernameKey = "WebDock.webDAVUsername"

    static var providerKind: SyncProviderKind {
        let raw = UserDefaults.standard.string(forKey: providerKey)
        return raw.flatMap(SyncProviderKind.init(rawValue:)) ?? .off
    }
}

struct SyncMergeEngine {
    static func merge(local: CanonicalSnapshot, remote: CanonicalSnapshot) -> CanonicalSnapshot {
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

        return CanonicalSnapshot(
            shortcuts: shortcuts.values.sorted { $0.id.uuidString < $1.id.uuidString },
            groups: groups.values.sorted { $0.id.uuidString < $1.id.uuidString },
            generatedAt: Date()
        )
    }
}

@MainActor
protocol CanonicalSyncProvider: AnyObject {
    func load() async throws -> CanonicalSnapshot?
    func save(_ snapshot: CanonicalSnapshot) async throws
}

@MainActor
final class SyncedFolderProvider: CanonicalSyncProvider {
    private let folderURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(folderURL: URL, fileManager: FileManager = .default) {
        self.folderURL = folderURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    private var snapshotURL: URL {
        folderURL.appendingPathComponent("WebDockSync.json", isDirectory: false)
    }

    func load() async throws -> CanonicalSnapshot? {
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return nil }
        let data = try Data(contentsOf: snapshotURL)
        let snapshot = try decoder.decode(CanonicalSnapshot.self, from: data)
        guard snapshot.schemaVersion <= CanonicalSnapshot.currentSchemaVersion else {
            throw SyncError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    func save(_ snapshot: CanonicalSnapshot) async throws {
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }
}

@MainActor
final class WebDAVProvider: CanonicalSyncProvider {
    private let fileURL: URL
    private let username: String
    private let password: String?
    private var etag: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let session: URLSession

    init(
        baseURL: URL,
        username: String,
        password: String?,
        session: URLSession = .shared
    ) {
        let normalizedBase = baseURL.absoluteString.hasSuffix("/")
            ? baseURL
            : URL(string: baseURL.absoluteString + "/") ?? baseURL
        fileURL = normalizedBase.appendingPathComponent("WebDockSync.json", isDirectory: false)
        self.username = username
        self.password = password
        self.session = session

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() async throws -> CanonicalSnapshot? {
        var request = URLRequest(url: fileURL)
        request.httpMethod = "GET"
        applyAuthorization(to: &request)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        if http.statusCode == 404 {
            etag = nil
            return nil
        }
        guard (200...299).contains(http.statusCode) else {
            throw SyncError.httpStatus(http.statusCode)
        }
        etag = http.value(forHTTPHeaderField: "ETag")
        let snapshot = try decoder.decode(CanonicalSnapshot.self, from: data)
        guard snapshot.schemaVersion <= CanonicalSnapshot.currentSchemaVersion else {
            throw SyncError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    func save(_ snapshot: CanonicalSnapshot) async throws {
        var request = URLRequest(url: fileURL)
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-Match")
        } else {
            request.setValue("*", forHTTPHeaderField: "If-None-Match")
        }
        applyAuthorization(to: &request)
        request.httpBody = try encoder.encode(snapshot)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        if http.statusCode == 412 {
            throw SyncError.conflict
        }
        guard (200...299).contains(http.statusCode) else {
            throw SyncError.httpStatus(http.statusCode)
        }
        etag = http.value(forHTTPHeaderField: "ETag")
    }

    private func applyAuthorization(to request: inout URLRequest) {
        guard !username.isEmpty else { return }
        let raw = "\(username):\(password ?? "")"
        let token = Data(raw.utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
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
    private let dataStore: WebDockDataStore
    private var observers: [NSObjectProtocol] = []
    private var scheduledTask: Task<Void, Never>?
    private var isSyncing = false

    init(dataStore: WebDockDataStore) {
        self.dataStore = dataStore

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
        guard SyncPreferences.providerKind != .off else {
            SyncStatusCenter.shared.state = .idle
            return
        }

        isSyncing = true
        SyncStatusCenter.shared.state = .syncing
        defer { isSyncing = false }

        do {
            let provider = try makeProvider()
            try await synchronize(with: provider)
            SyncStatusCenter.shared.state = .success(Date())
        } catch SyncError.conflict {
            do {
                let provider = try makeProvider()
                try await synchronize(with: provider)
                SyncStatusCenter.shared.state = .success(Date())
            } catch {
                SyncStatusCenter.shared.state = .failure(error.localizedDescription)
            }
        } catch {
            SyncStatusCenter.shared.state = .failure(error.localizedDescription)
        }
    }

    private func makeProvider() throws -> any CanonicalSyncProvider {
        let defaults = UserDefaults.standard
        switch SyncPreferences.providerKind {
        case .off:
            throw SyncError.providerNotConfigured("Sync is turned off.")
        case .syncedFolder:
            guard let path = defaults.string(forKey: SyncPreferences.syncedFolderPathKey),
                  !path.isEmpty else {
                throw SyncError.providerNotConfigured("Choose a synced folder first.")
            }
            return SyncedFolderProvider(folderURL: URL(fileURLWithPath: path, isDirectory: true))
        case .webDAV:
            guard let rawURL = defaults.string(forKey: SyncPreferences.webDAVBaseURLKey),
                  let url = URL(string: rawURL),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                throw SyncError.providerNotConfigured("Enter a valid WebDAV HTTP or HTTPS folder URL.")
            }
            let username = defaults.string(forKey: SyncPreferences.webDAVUsernameKey) ?? ""
            let password = try WebDAVCredentialStore.password(username: username)
            return WebDAVProvider(baseURL: url, username: username, password: password)
        }
    }

    private func synchronize(with provider: any CanonicalSyncProvider) async throws {
        let local = dataStore.canonicalSnapshot()
        let remote = try await provider.load() ?? .empty
        let merged = SyncMergeEngine.merge(local: local, remote: remote)
        try dataStore.applyCanonicalSnapshot(merged, notify: false)
        try await provider.save(dataStore.canonicalSnapshot())
    }
}

enum SyncError: LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case conflict
    case unsupportedSchema(Int)
    case providerNotConfigured(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The sync server returned an invalid response."
        case .httpStatus(let code):
            "The sync server returned HTTP status \(code)."
        case .conflict:
            "The remote sync file changed while WebDock was saving it."
        case .unsupportedSchema(let version):
            "The sync file uses unsupported schema version \(version)."
        case .providerNotConfigured(let message):
            message
        }
    }
}
