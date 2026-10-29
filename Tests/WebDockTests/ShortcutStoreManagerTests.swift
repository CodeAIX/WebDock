import SwiftData
import XCTest
@testable import WebDock

final class ShortcutStoreManagerTests: XCTestCase {
    @MainActor
    func testAtomicMetadataUpdateAppliesNameURLAndBrowserTogether() throws {
        let fixture = try makeFixture()
        let shortcut = makeShortcut(name: "Old", index: 0)
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        try fixture.store.updateMetadata(
            shortcut,
            name: "  Research  ",
            normalizedURL: " https://pubmed.ncbi.nlm.nih.gov/ ",
            browserBundleIdentifier: "com.apple.Safari",
            browserDisplayName: "Safari"
        )

        XCTAssertEqual(shortcut.displayName, "Research")
        XCTAssertEqual(shortcut.normalizedURLString, "https://pubmed.ncbi.nlm.nih.gov/")
        XCTAssertEqual(shortcut.launchMode, .specifiedBrowser)
        XCTAssertEqual(shortcut.browserBundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(shortcut.browserDisplayName, "Safari")
    }

    @MainActor
    func testAtomicMetadataValidationDoesNotPartiallyRenameOriginalShortcut() throws {
        let fixture = try makeFixture()
        let shortcut = makeShortcut(
            name: "ChatGPT",
            index: 0,
            sourceType: .chromeWebloc,
            launchMode: .originalShortcutFile
        )
        shortcut.normalizedURLString = "https://chatgpt.com/"
        shortcut.browserProfileHint = "Profile 12"
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        XCTAssertThrowsError(
            try fixture.store.updateMetadata(
                shortcut,
                name: "Changed Name",
                normalizedURL: "https://example.com/",
                browserBundleIdentifier: nil,
                browserDisplayName: nil
            )
        ) { error in
            guard case ShortcutStoreError.originalShortcutIsReadOnly = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(shortcut.displayName, "ChatGPT")
        XCTAssertEqual(shortcut.normalizedURLString, "https://chatgpt.com/")
    }

    @MainActor
    func testAtomicMetadataAllowsRenameOfOriginalShortcutWithoutChangingProfileSemantics() throws {
        let fixture = try makeFixture()
        let shortcut = makeShortcut(
            name: "ChatGPT",
            index: 0,
            sourceType: .chromeWebloc,
            launchMode: .originalShortcutFile
        )
        shortcut.normalizedURLString = "https://chatgpt.com/"
        shortcut.browserProfileHint = "Profile 12"
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        try fixture.store.updateMetadata(
            shortcut,
            name: "AI Chat",
            normalizedURL: "https://chatgpt.com/",
            browserBundleIdentifier: nil,
            browserDisplayName: nil
        )

        XCTAssertEqual(shortcut.displayName, "AI Chat")
        XCTAssertEqual(shortcut.launchMode, .originalShortcutFile)
        XCTAssertEqual(shortcut.browserProfileHint, "Profile 12")
        XCTAssertNil(shortcut.browserBundleIdentifier)
    }

    @MainActor
    func testDropForwardPlacesSourceAfterTargetAndDropBackwardBeforeTarget() throws {
        let fixture = try makeFixture()
        let a = makeShortcut(name: "A", index: 0)
        let b = makeShortcut(name: "B", index: 1)
        let c = makeShortcut(name: "C", index: 2)
        let d = makeShortcut(name: "D", index: 3)
        [a, b, c, d].forEach { fixture.container.mainContext.insert($0) }
        try fixture.container.mainContext.save()

        try fixture.store.moveForDrop(shortcutID: a.id, onto: c.id)
        XCTAssertEqual(try orderedNames(in: fixture.container), ["B", "C", "A", "D"])

        try fixture.store.moveForDrop(shortcutID: d.id, onto: b.id)
        XCTAssertEqual(try orderedNames(in: fixture.container), ["D", "B", "C", "A"])
    }

    @MainActor
    private func orderedNames(in container: ModelContainer) throws -> [String] {
        let descriptor = FetchDescriptor<WebShortcut>(
            sortBy: [SortDescriptor(\WebShortcut.sortIndex)]
        )
        return try container.mainContext.fetch(descriptor).map(\.displayName)
    }

    @MainActor
    private func makeFixture() throws -> (
        container: ModelContainer,
        storage: ManagedStorage,
        store: ShortcutStore
    ) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            configurations: configuration
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockManagerTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let storage = try ManagedStorage(rootURL: root)
        let store = ShortcutStore(
            modelContainer: container,
            managedStorage: storage
        )
        return (container, storage, store)
    }

    @MainActor
    private func makeShortcut(
        name: String,
        index: Double,
        sourceType: ShortcutSourceType = .webLoc,
        launchMode: ShortcutLaunchMode = .defaultBrowser
    ) -> WebShortcut {
        WebShortcut(
            displayName: name,
            normalizedURLString: "https://example.com/",
            sourceType: sourceType,
            launchMode: launchMode,
            sortIndex: index
        )
    }
}
