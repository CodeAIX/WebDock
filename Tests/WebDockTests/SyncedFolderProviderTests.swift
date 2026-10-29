import XCTest
@testable import WebDock

final class SyncedFolderProviderTests: XCTestCase {
    @MainActor
    func testRoundTripUsesCanonicalSnapshotOnly() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockSyncedFolder-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let shortcut = WebShortcut(
            displayName: "ChatGPT",
            normalizedURLString: "https://chatgpt.com/",
            preferredBrowserFamily: .chrome,
            targetAccountEmail: "user@example.com"
        )
        let snapshot = CanonicalSnapshot(
            shortcuts: [shortcut],
            groups: [],
            generatedAt: Date()
        )

        let provider = SyncedFolderProvider(folderURL: folder)
        try await provider.save(snapshot)
        let loaded = try await provider.load()

        XCTAssertEqual(loaded?.shortcuts.first?.targetAccountEmail, "user@example.com")
        XCTAssertEqual(loaded?.shortcuts.first?.preferredBrowserFamily, .chrome)

        let syncFile = folder.appendingPathComponent("WebDockSync.json")
        let text = try String(contentsOf: syncFile, encoding: .utf8)
        XCTAssertFalse(text.contains("Profile 12"))
        XCTAssertFalse(text.contains("DeviceShortcutBinding"))
        XCTAssertFalse(text.contains("resolvedProfileDirectory"))
    }
}
