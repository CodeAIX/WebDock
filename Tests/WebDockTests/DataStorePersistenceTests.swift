import XCTest
@testable import WebDock

final class DataStorePersistenceTests: XCTestCase {
    @MainActor
    func testPortableShortcutAndLocalBindingPersistAcrossReload() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockJSONStore-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let insertedID = UUID()
        do {
            let store = try WebDockDataStore(rootURL: root)
            let shortcut = WebShortcut(
                id: insertedID,
                displayName: "ChatGPT",
                normalizedURLString: "https://chatgpt.com/",
                preferredBrowserFamily: .chrome,
                targetAccountEmail: "user@example.com",
                sortIndex: 42
            )
            try store.insertShortcut(shortcut)

            var binding = DeviceShortcutBinding(shortcutID: insertedID)
            binding.resolvedBrowserBundleIdentifier = "com.google.Chrome"
            binding.resolvedProfileDirectory = "Profile 12"
            try store.upsertDeviceBinding(binding)
        }

        let reloaded = try WebDockDataStore(rootURL: root)
        XCTAssertEqual(reloaded.shortcuts.count, 1)
        XCTAssertEqual(reloaded.shortcuts.first?.id, insertedID)
        XCTAssertEqual(reloaded.shortcuts.first?.preferredBrowserFamily, .chrome)
        XCTAssertEqual(reloaded.shortcuts.first?.targetAccountEmail, "user@example.com")
        XCTAssertEqual(reloaded.binding(for: insertedID)?.resolvedProfileDirectory, "Profile 12")
    }

    @MainActor
    func testCanonicalSnapshotNeverContainsDeviceProfileDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockSnapshot-\(UUID().uuidString)", isDirectory: true)
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

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store.canonicalSnapshot())
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("user@example.com"))
        XCTAssertFalse(text.contains("Profile 12"))
        XCTAssertFalse(text.contains("resolvedProfileDirectory"))
    }
}
