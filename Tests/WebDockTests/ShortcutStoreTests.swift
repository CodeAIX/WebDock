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
    func testDuplicateKeepsPortableRuleButNotLocalBinding() throws {
        let (dataStore, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ShortcutStore(dataStore: dataStore)
        let group = try store.createGroup(name: "Work")
        let original = WebShortcut(displayName: "Mail", normalizedURLString: "https://example.com/",
                                  preferredBrowserFamily: .chrome, targetAccountEmail: "a@example.com", groupID: group.id)
        try dataStore.insertShortcut(original)
        var binding = DeviceShortcutBinding(shortcutID: original.id)
        binding.overrideProfileDirectory = "Profile 12"
        try dataStore.upsertDeviceBinding(binding)
        let copy = try store.duplicate(original)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.groupID, group.id)
        XCTAssertEqual(copy.targetAccountEmail, original.targetAccountEmail)
        XCTAssertNil(dataStore.binding(for: copy.id))
        let reloaded = try WebDockDataStore(rootURL: root)
        XCTAssertEqual(reloaded.activeGroups.map(\.id), [group.id])
        XCTAssertEqual(reloaded.activeGroups.first?.name, "Work")
        XCTAssertEqual(reloaded.activeShortcuts.count, 2)
    }

    @MainActor
    private func makeStore() throws -> (WebDockDataStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockStoreTests-\(UUID().uuidString)", isDirectory: true)
        return (try WebDockDataStore(rootURL: root), root)
    }
}
