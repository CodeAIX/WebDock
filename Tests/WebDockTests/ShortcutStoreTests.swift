import SwiftData
import XCTest
@testable import WebDock

private final class TrashSpy: FileTrashing {
    private(set) var trashedURLs: [URL] = []
    var error: Error?

    func trashItem(at url: URL) throws {
        if let error { throw error }
        trashedURLs.append(url)
    }
}

private struct TestTrashError: Error {}

final class ShortcutStoreTests: XCTestCase {
    @MainActor
    func testRenameTrimsAndPersists() throws {
        let fixture = try makeFixture()
        let shortcut = makeShortcut(name: "Old", index: 0)
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        try fixture.store.rename(shortcut, to: "  New Name  ")

        XCTAssertEqual(shortcut.displayName, "New Name")
        let reloaded = try fixture.container.mainContext.fetch(FetchDescriptor<WebShortcut>())
        XCTAssertEqual(reloaded.first?.displayName, "New Name")
    }

    @MainActor
    func testRenameRejectsBlankName() throws {
        let fixture = try makeFixture()
        let shortcut = makeShortcut(name: "Keep Me", index: 0)
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        XCTAssertThrowsError(try fixture.store.rename(shortcut, to: "   \n")) { error in
            guard case ShortcutStoreError.emptyName = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(shortcut.displayName, "Keep Me")
    }

    @MainActor
    func testURLAndBrowserOverridesRejectOriginalChromeShortcut() throws {
        let fixture = try makeFixture()
        let shortcut = makeShortcut(
            name: "ChatGPT",
            index: 0,
            sourceType: .chromeWebloc,
            launchMode: .originalShortcutFile
        )
        shortcut.browserProfileHint = "Profile 12"
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        XCTAssertThrowsError(
            try fixture.store.updateNormalizedURL(shortcut, to: "https://example.com/")
        ) { error in
            guard case ShortcutStoreError.originalShortcutIsReadOnly = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(
            try fixture.store.setBrowserOverride(
                shortcut,
                bundleIdentifier: "com.apple.Safari",
                displayName: "Safari"
            )
        ) { error in
            guard case ShortcutStoreError.originalShortcutIsReadOnly = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(shortcut.normalizedURLString, "https://example.com/")
        XCTAssertEqual(shortcut.launchMode, .originalShortcutFile)
        XCTAssertNil(shortcut.browserBundleIdentifier)
    }

    @MainActor
    func testNormalizedShortcutCanChangeURLAndBrowserThenClearOverride() throws {
        let fixture = try makeFixture()
        let shortcut = makeShortcut(name: "Example", index: 0)
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        try fixture.store.updateNormalizedURL(shortcut, to: " https://openai.com/research ")
        XCTAssertEqual(shortcut.normalizedURLString, "https://openai.com/research")

        XCTAssertThrowsError(
            try fixture.store.updateNormalizedURL(shortcut, to: "javascript:alert(1)")
        ) { error in
            guard case ShortcutStoreError.invalidURL = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        try fixture.store.setBrowserOverride(
            shortcut,
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome"
        )
        XCTAssertEqual(shortcut.launchMode, .specifiedBrowser)
        XCTAssertEqual(shortcut.browserBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(shortcut.browserDisplayName, "Google Chrome")

        try fixture.store.clearBrowserOverride(shortcut)
        XCTAssertEqual(shortcut.launchMode, .defaultBrowser)
        XCTAssertNil(shortcut.browserBundleIdentifier)
        XCTAssertNil(shortcut.browserDisplayName)
    }

    @MainActor
    func testMoveBeforePersistsNormalizedOrder() throws {
        let fixture = try makeFixture()
        let a = makeShortcut(name: "A", index: 0)
        let b = makeShortcut(name: "B", index: 1)
        let c = makeShortcut(name: "C", index: 2)
        fixture.container.mainContext.insert(a)
        fixture.container.mainContext.insert(b)
        fixture.container.mainContext.insert(c)
        try fixture.container.mainContext.save()

        try fixture.store.move(shortcutID: c.id, before: a.id)

        let descriptor = FetchDescriptor<WebShortcut>(
            sortBy: [SortDescriptor(\WebShortcut.sortIndex)]
        )
        let ordered = try fixture.container.mainContext.fetch(descriptor)
        XCTAssertEqual(ordered.map(\.displayName), ["C", "A", "B"])
        XCTAssertEqual(ordered.map(\.sortIndex), [0, 1, 2])
    }

    @MainActor
    func testDeleteStagesManagedDirectoryThenHandsItToTrashAfterDatabaseCommit() throws {
        let trash = TrashSpy()
        let fixture = try makeFixture(trasher: trash)
        let shortcut = makeShortcut(name: "ChatGPT", index: 0)
        shortcut.managedFileRelativePath = "Shortcuts/\(shortcut.id.uuidString)/original.crwebloc"
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        let managedDirectory = fixture.storage.directory(for: shortcut.id)
        try FileManager.default.createDirectory(at: managedDirectory, withIntermediateDirectories: true)
        try Data("important shortcut".utf8).write(
            to: managedDirectory.appendingPathComponent("original.crwebloc")
        )

        try fixture.store.delete(shortcut)

        XCTAssertTrue(try fixture.container.mainContext.fetch(FetchDescriptor<WebShortcut>()).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedDirectory.path))
        XCTAssertEqual(trash.trashedURLs, [fixture.storage.deletionStagingDirectory(for: shortcut.id)])
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fixture.storage.deletionStagingDirectory(for: shortcut.id).path
            )
        )
    }

    @MainActor
    func testTrashFailureLeavesRecoverableStagingDirectory() throws {
        let trash = TrashSpy()
        trash.error = TestTrashError()
        let fixture = try makeFixture(trasher: trash)
        let shortcut = makeShortcut(name: "Managed", index: 0)
        fixture.container.mainContext.insert(shortcut)
        try fixture.container.mainContext.save()

        let managedDirectory = fixture.storage.directory(for: shortcut.id)
        try FileManager.default.createDirectory(at: managedDirectory, withIntermediateDirectories: true)
        try Data("recover me".utf8).write(to: managedDirectory.appendingPathComponent("original.webloc"))

        XCTAssertThrowsError(try fixture.store.delete(shortcut)) { error in
            guard case ShortcutStoreError.trashCleanupPending(let url) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(url, fixture.storage.deletionStagingDirectory(for: shortcut.id))
        }
        XCTAssertTrue(try fixture.container.mainContext.fetch(FetchDescriptor<WebShortcut>()).isEmpty)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fixture.storage.deletionStagingDirectory(for: shortcut.id).path
            )
        )
    }

    @MainActor
    private func makeFixture(trasher: (any FileTrashing)? = nil) throws -> (
        container: ModelContainer,
        storage: ManagedStorage,
        store: ShortcutStore,
        root: URL
    ) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            configurations: configuration
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockStore-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let storage = try ManagedStorage(rootURL: root)
        let store = ShortcutStore(
            modelContainer: container,
            managedStorage: storage,
            fileTrasher: trasher
        )
        return (container, storage, store, root)
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
