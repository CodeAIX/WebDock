import XCTest
@testable import WebDock

final class ShortcutStoreTests: XCTestCase {
    @MainActor
    func testUpdateStoresPortableBrowserAndAccountIdentity() throws {
        let (dataStore, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shortcut = WebShortcut(
            displayName: "Old",
            normalizedURLString: "https://example.com/"
        )
        try dataStore.insertShortcut(shortcut)

        let store = ShortcutStore(dataStore: dataStore)
        let updated = try store.updateMetadata(
            shortcut,
            name: "Mail",
            normalizedURL: "https://mail.google.com/",
            browserFamily: .chrome,
            targetAccountEmail: "USER@EXAMPLE.COM"
        )

        XCTAssertEqual(updated.displayName, "Mail")
        XCTAssertEqual(updated.preferredBrowserFamily, .chrome)
        XCTAssertEqual(updated.targetAccountEmail, "user@example.com")
        XCTAssertEqual(dataStore.shortcut(id: shortcut.id)?.displayName, "Mail")
    }

    @MainActor
    func testDeleteCreatesTombstoneInsteadOfRemovingCanonicalRecord() throws {
        let (dataStore, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shortcut = WebShortcut(
            displayName: "Example",
            normalizedURLString: "https://example.com/"
        )
        try dataStore.insertShortcut(shortcut)

        let store = ShortcutStore(dataStore: dataStore)
        try store.delete(shortcut)

        XCTAssertEqual(dataStore.shortcuts.count, 1)
        XCTAssertNotNil(dataStore.shortcuts[0].deletedAt)
        XCTAssertTrue(store.orderedActiveShortcuts().isEmpty)
    }

    @MainActor
    func testDropReorderPersistsActiveShortcutOrder() throws {
        let (dataStore, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = WebShortcut(
            displayName: "One",
            normalizedURLString: "https://one.example/",
            sortIndex: 0
        )
        let second = WebShortcut(
            displayName: "Two",
            normalizedURLString: "https://two.example/",
            sortIndex: 1
        )
        try dataStore.insertShortcut(first)
        try dataStore.insertShortcut(second)

        let store = ShortcutStore(dataStore: dataStore)
        try store.moveForDrop(shortcutID: first.id, onto: second.id)

        XCTAssertEqual(store.orderedActiveShortcuts().map(\.displayName), ["Two", "One"])
    }

    @MainActor
    private func makeStore() throws -> (WebDockDataStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockStoreTests-\(UUID().uuidString)", isDirectory: true)
        return (try WebDockDataStore(rootURL: root), root)
    }
}
