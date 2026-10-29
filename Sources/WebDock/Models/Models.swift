import Foundation
import SwiftData

enum ShortcutSourceType: String, Codable, CaseIterable {
    case chromeWebloc
    case webLoc
    case internetShortcut
    case directURL
    case appBundle
}

enum ShortcutLaunchMode: String, Codable, CaseIterable {
    case originalShortcutFile
    case defaultBrowser
    case specifiedBrowser
    case externalAppBundle
}

@Model
final class ShortcutGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Double
    var createdAt: Date

    init(id: UUID = UUID(), name: String, sortIndex: Double = 0) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }
}

@Model
final class WebShortcut {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var normalizedURLString: String
    var sourceTypeRaw: String
    var launchModeRaw: String
    var browserBundleIdentifier: String?
    var browserDisplayName: String?
    var browserProfileDirectory: String?
    var browserProfileDisplayName: String?
    var browserProfileAccountEmail: String?
    var browserProfileHint: String?
    var managedFileRelativePath: String?
    var externalAppBookmarkData: Data?
    var externalAppPathHint: String?
    var iconRelativePath: String?
    var groupID: UUID?
    var sortIndex: Double
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?
    var openCount: Int

    init(
        id: UUID = UUID(),
        displayName: String,
        normalizedURLString: String,
        sourceType: ShortcutSourceType,
        launchMode: ShortcutLaunchMode,
        sortIndex: Double = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.normalizedURLString = normalizedURLString
        self.sourceTypeRaw = sourceType.rawValue
        self.launchModeRaw = launchMode.rawValue
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.updatedAt = Date()
        self.openCount = 0
    }

    var sourceType: ShortcutSourceType? {
        get { ShortcutSourceType(rawValue: sourceTypeRaw) }
        set { sourceTypeRaw = newValue?.rawValue ?? sourceTypeRaw }
    }

    var launchMode: ShortcutLaunchMode? {
        get { ShortcutLaunchMode(rawValue: launchModeRaw) }
        set { launchModeRaw = newValue?.rawValue ?? launchModeRaw }
    }
}
