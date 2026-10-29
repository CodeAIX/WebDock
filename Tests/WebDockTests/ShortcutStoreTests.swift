import SwiftData
import XCTest
@testable import WebDock

final class ShortcutStoreTests: XCTestCase {
    @MainActor
    func testUpdateStoresPortableBrowserAndAccountIdentity() throws {
        let container = try makeContainer()
        let shortcut = WebShortcut(
            displayName: "Old",
            normalizedURLString: "https://example.com/"
        )
        container.mainContext.insert(shortcut)
        try container.mainContext.save()

        let store = ShortcutStore(modelContainer: container)
        try store.updateMetadata(
            shortcut,
            name: "Mail",
            normalizedURL: "https://mail.google.com/",
            browserFamily: .chrome,
            targetAccountEmail: "USER@EXAMPLE.COM"
        )

        XCTAssertEqual(shortcut.displayName, "Mail")
        XCTAssertEqual(shortcut.preferredBrowserFamily, .chrome)
        XCTAssertEqual(shortcut.targetAccountEmail, "user@example.com")
    }

    @MainActor
    func testDeleteCreatesTombstoneInsteadOfRemovingCanonicalRecord() throws {
        let container = try makeContainer()
        let shortcut = WebShortcut(
            displayName: "Example",
            normalizedURLString: "https://example.com/"
        )
        container.mainContext.insert(shortcut)
        try container.mainContext.save()

        let store = ShortcutStore(modelContainer: container)
        try store.delete(shortcut)

        let records = try container.mainContext.fetch(FetchDescriptor<WebShortcut>())
        XCTAssertEqual(records.count, 1)
        XCTAssertNotNil(records[0].deletedAt)
        XCTAssertTrue(try store.orderedActiveShortcuts().isEmpty)
    }

    @MainActor
    func testDropReorderPersistsActiveShortcutOrder() throws {
        let container = try makeContainer()
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
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()

        let store = ShortcutStore(modelContainer: container)
        try store.moveForDrop(shortcutID: first.id, onto: second.id)

        let ordered = try store.orderedActiveShortcuts()
        XCTAssertEqual(ordered.map(\.displayName), ["Two", "One"])
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            DeviceShortcutBinding.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
