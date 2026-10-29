import Combine
import Foundation

private struct CanonicalStoreFile: Codable {
    var schemaVersion: Int
    var shortcuts: [WebShortcut]
    var groups: [ShortcutGroup]
}

private struct DeviceStoreFile: Codable {
    var schemaVersion: Int
    var bindings: [DeviceShortcutBinding]
}

@MainActor
final class WebDockDataStore: ObservableObject {
    static let schemaVersion = 1

    let rootURL: URL
    let canonicalURL: URL
    let deviceBindingsURL: URL

    @Published private(set) var shortcuts: [WebShortcut] = []
    @Published private(set) var groups: [ShortcutGroup] = []
    @Published private(set) var deviceBindings: [DeviceShortcutBinding] = []

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        self.rootURL = rootURL
        self.fileManager = fileManager
        canonicalURL = rootURL.appendingPathComponent("Canonical.json", isDirectory: false)
        deviceBindingsURL = rootURL.appendingPathComponent("DeviceBindings.json", isDirectory: false)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try load()
    }

    var activeShortcuts: [WebShortcut] {
        shortcuts
            .filter { $0.deletedAt == nil }
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.sortIndex < rhs.sortIndex
            }
    }

    var activeGroups: [ShortcutGroup] {
        groups
            .filter { $0.deletedAt == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    func shortcut(id: UUID) -> WebShortcut? {
        shortcuts.first(where: { $0.id == id })
    }

    func binding(for shortcutID: UUID) -> DeviceShortcutBinding? {
        deviceBindings.first(where: { $0.shortcutID == shortcutID })
    }

    func canonicalSnapshot() -> CanonicalSnapshot {
        CanonicalSnapshot(
            shortcuts: shortcuts,
            groups: groups,
            generatedAt: Date()
        )
    }

    func insertShortcut(_ shortcut: WebShortcut) throws {
        var updated = shortcuts
        updated.append(shortcut)
        try replaceCanonical(shortcuts: updated, groups: groups)
    }

    func updateShortcut(_ shortcut: WebShortcut) throws {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else {
            throw WebDockDataStoreError.shortcutNotFound
        }
        var updated = shortcuts
        updated[index] = shortcut
        try replaceCanonical(shortcuts: updated, groups: groups)
    }

    func replaceShortcutOrder(_ orderedActive: [WebShortcut]) throws {
        let activeByID = Dictionary(uniqueKeysWithValues: orderedActive.map { ($0.id, $0) })
        let updated = shortcuts.map { activeByID[$0.id] ?? $0 }
        try replaceCanonical(shortcuts: updated, groups: groups)
    }

    func removeDeviceBinding(for shortcutID: UUID) throws {
        let updated = deviceBindings.filter { $0.shortcutID != shortcutID }
        try replaceDeviceBindings(updated)
    }

    func upsertDeviceBinding(_ binding: DeviceShortcutBinding) throws {
        var updated = deviceBindings
        if let index = updated.firstIndex(where: { $0.shortcutID == binding.shortcutID }) {
            updated[index] = binding
        } else {
            updated.append(binding)
        }
        try replaceDeviceBindings(updated)
    }

    func applyCanonicalSnapshot(
        _ snapshot: CanonicalSnapshot,
        notify: Bool
    ) throws {
        guard snapshot.schemaVersion <= CanonicalSnapshot.currentSchemaVersion else {
            throw WebDockDataStoreError.unsupportedSchema(snapshot.schemaVersion)
        }
        try replaceCanonical(
            shortcuts: snapshot.shortcuts,
            groups: snapshot.groups,
            notify: notify
        )
    }

    func replaceAll(
        canonical: CanonicalSnapshot,
        bindings: [DeviceShortcutBinding],
        notify: Bool = true
    ) throws {
        guard canonical.schemaVersion <= CanonicalSnapshot.currentSchemaVersion else {
            throw WebDockDataStoreError.unsupportedSchema(canonical.schemaVersion)
        }
        try persistCanonical(canonical.shortcuts, canonical.groups)
        try persistDeviceBindings(bindings)
        shortcuts = canonical.shortcuts
        groups = canonical.groups
        deviceBindings = bindings
        if notify {
            NotificationCenter.default.post(name: .webDockCanonicalDataDidChange, object: nil)
        }
    }

    private func load() throws {
        if fileManager.fileExists(atPath: canonicalURL.path) {
            let data = try Data(contentsOf: canonicalURL)
            let file = try decoder.decode(CanonicalStoreFile.self, from: data)
            guard file.schemaVersion <= Self.schemaVersion else {
                throw WebDockDataStoreError.unsupportedSchema(file.schemaVersion)
            }
            shortcuts = file.shortcuts
            groups = file.groups
        }

        if fileManager.fileExists(atPath: deviceBindingsURL.path) {
            let data = try Data(contentsOf: deviceBindingsURL)
            let file = try decoder.decode(DeviceStoreFile.self, from: data)
            guard file.schemaVersion <= Self.schemaVersion else {
                throw WebDockDataStoreError.unsupportedSchema(file.schemaVersion)
            }
            deviceBindings = file.bindings
        }
    }

    private func replaceCanonical(
        shortcuts: [WebShortcut],
        groups: [ShortcutGroup],
        notify: Bool = true
    ) throws {
        try persistCanonical(shortcuts, groups)
        self.shortcuts = shortcuts
        self.groups = groups
        if notify {
            NotificationCenter.default.post(name: .webDockCanonicalDataDidChange, object: nil)
        }
    }

    private func replaceDeviceBindings(_ bindings: [DeviceShortcutBinding]) throws {
        try persistDeviceBindings(bindings)
        deviceBindings = bindings
    }

    private func persistCanonical(
        _ shortcuts: [WebShortcut],
        _ groups: [ShortcutGroup]
    ) throws {
        let file = CanonicalStoreFile(
            schemaVersion: Self.schemaVersion,
            shortcuts: shortcuts,
            groups: groups
        )
        let data = try encoder.encode(file)
        try data.write(to: canonicalURL, options: .atomic)
    }

    private func persistDeviceBindings(_ bindings: [DeviceShortcutBinding]) throws {
        let file = DeviceStoreFile(
            schemaVersion: Self.schemaVersion,
            bindings: bindings
        )
        let data = try encoder.encode(file)
        try data.write(to: deviceBindingsURL, options: .atomic)
    }
}

enum WebDockDataStoreError: LocalizedError, Equatable {
    case shortcutNotFound
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .shortcutNotFound:
            "The shortcut could not be found in WebDock's local store."
        case .unsupportedSchema(let version):
            "This WebDock data file uses unsupported schema version \(version)."
        }
    }
}
