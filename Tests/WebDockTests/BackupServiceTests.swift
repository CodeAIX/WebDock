import XCTest
@testable import WebDock

final class BackupServiceTests: XCTestCase {
    @MainActor
    func testPortableBackupExcludesLocalProfileBindings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockBackupTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try WebDockDataStore(rootURL: root)
        let shortcut = WebShortcut(
            displayName: "ChatGPT",
            normalizedURLString: "https://chatgpt.com/",
            preferredBrowserFamily: .chrome,
            targetAccountEmail: "user@example.com"
        )
        try store.insertShortcut(shortcut)
        var binding = DeviceShortcutBinding(shortcutID: shortcut.id)
        binding.resolvedProfileDirectory = "Profile 12"
        try store.upsertDeviceBinding(binding)

        let service = try BackupService(dataStore: store)
        let exportURL = root.appendingPathComponent("portable.webdockbackup")
        try service.exportPortable(to: exportURL)

        let text = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(text.contains("user@example.com"))
        XCTAssertFalse(text.contains("Profile 12"))
        XCTAssertFalse(text.contains("deviceBindings"))
    }

    @MainActor
    func testPortableReplaceRestoreClearsDeviceBindings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockRestoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try WebDockDataStore(rootURL: root)
        let original = WebShortcut(
            displayName: "One",
            normalizedURLString: "https://one.example/"
        )
        try store.insertShortcut(original)
        var binding = DeviceShortcutBinding(shortcutID: original.id)
        binding.overrideProfileDirectory = "Profile 9"
        try store.upsertDeviceBinding(binding)

        let service = try BackupService(dataStore: store)
        let exportURL = root.appendingPathComponent("portable.webdockbackup")
        try service.exportPortable(to: exportURL)

        let second = WebShortcut(
            displayName: "Two",
            normalizedURLString: "https://two.example/"
        )
        try store.insertShortcut(second)
        try service.restore(from: exportURL, mode: .replace)

        XCTAssertEqual(store.activeShortcuts.map(\.displayName), ["One"])
        XCTAssertTrue(store.deviceBindings.isEmpty)
    }
}
