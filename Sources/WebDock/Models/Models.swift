import Foundation
import SwiftData

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
    case iCloud
    case webDAV

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .iCloud: "iCloud"
        case .webDAV: "WebDAV"
        }
    }
}

@Model
final class ShortcutGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Double
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(id: UUID = UUID(), name: String, sortIndex: Double = 0) {
        let now = Date()
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = now
        self.updatedAt = now
    }
}

@Model
final class WebShortcut {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var normalizedURLString: String
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

/// Machine-local resolution state. This model is deliberately excluded from
/// every sync payload: local profile directory names such as `Profile 12` are
/// implementation details of one Mac and are never portable shortcut identity.
@Model
final class DeviceShortcutBinding {
    @Attribute(.unique) var shortcutID: UUID
    var resolvedBrowserBundleIdentifier: String?
    var resolvedProfileDirectory: String?
    var resolvedAccountEmail: String?
    var resolutionStatusRaw: String
    var warningMessage: String?

    /// Explicit per-device override. These values never sync.
    var overrideBrowserBundleIdentifier: String?
    var overrideProfileDirectory: String?
    var updatedAt: Date

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
