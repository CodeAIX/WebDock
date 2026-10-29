import Foundation

enum BrowserFamily: String, Codable, CaseIterable, Identifiable, Hashable {
    case safari
    case chrome
    case chromium
    case edge
    case firefox
    case brave
    case arc
    case vivaldi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        case .chromium: "Chromium"
        case .edge: "Microsoft Edge"
        case .firefox: "Firefox"
        case .brave: "Brave Browser"
        case .arc: "Arc"
        case .vivaldi: "Vivaldi"
        }
    }

    var supportsAccountRouting: Bool {
        switch self {
        case .chrome, .chromium, .edge, .brave, .vivaldi:
            true
        case .safari, .firefox, .arc:
            false
        }
    }
}

enum DeviceResolutionStatus: String, Codable, CaseIterable {
    case systemDefault
    case resolved
    case localOverride
    case missingBrowser
    case missingAccount
    case ambiguousAccount
}

enum SyncProviderKind: String, Codable, CaseIterable, Identifiable {
    case off
    case syncedFolder
    case webDAV

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .syncedFolder: "Synced Folder"
        case .webDAV: "WebDAV"
        }
    }
}

struct ShortcutGroup: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var sortIndex: Double
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        sortIndex: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

struct WebShortcut: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var displayName: String
    var normalizedURLString: String
    var iconMode: String?
    var iconAssetID: String?
    var iconSourceURL: String?
    var preferredBrowserFamilyRaw: String?
    var targetAccountEmail: String?
    var groupID: UUID?
    var sortIndex: Double
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        normalizedURLString: String,
        preferredBrowserFamily: BrowserFamily? = nil,
        targetAccountEmail: String? = nil,
        groupID: UUID? = nil,
        sortIndex: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.normalizedURLString = normalizedURLString
        self.preferredBrowserFamilyRaw = preferredBrowserFamily?.rawValue
        self.targetAccountEmail = targetAccountEmail
        self.groupID = groupID
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    var preferredBrowserFamily: BrowserFamily? {
        get {
            guard let preferredBrowserFamilyRaw else { return nil }
            return BrowserFamily(rawValue: preferredBrowserFamilyRaw)
        }
        set {
            preferredBrowserFamilyRaw = newValue?.rawValue
        }
    }
}

/// Machine-local resolution state. This never appears in portable backups or
/// synchronization payloads: local `Profile N` directory names are details of
/// one Mac, not portable account identity.
struct DeviceShortcutBinding: Identifiable, Codable, Equatable, Hashable {
    var shortcutID: UUID
    var resolvedBrowserBundleIdentifier: String?
    var resolvedProfileDirectory: String?
    var resolvedAccountEmail: String?
    var resolutionStatusRaw: String
    var warningMessage: String?
    var overrideBrowserBundleIdentifier: String?
    var overrideProfileDirectory: String?
    var updatedAt: Date

    var id: UUID { shortcutID }

    init(shortcutID: UUID) {
        self.shortcutID = shortcutID
        self.resolutionStatusRaw = DeviceResolutionStatus.systemDefault.rawValue
        self.updatedAt = Date()
    }

    var resolutionStatus: DeviceResolutionStatus {
        get { DeviceResolutionStatus(rawValue: resolutionStatusRaw) ?? .systemDefault }
        set { resolutionStatusRaw = newValue.rawValue }
    }
}

struct CanonicalSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var shortcuts: [WebShortcut]
    var groups: [ShortcutGroup]
    var generatedAt: Date
    var iconAssets: [String: Data]?

    static var empty: CanonicalSnapshot {
        CanonicalSnapshot(shortcuts: [], groups: [], generatedAt: Date(timeIntervalSince1970: 0))
    }
}
