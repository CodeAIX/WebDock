import SwiftData
import XCTest
@testable import WebDock

private final class RecordingImportTrasher: FileTrashing {
    private(set) var trashedURLs: [URL] = []
    var error: Error?

    func trashItem(at url: URL) throws {
        if let error { throw error }
        trashedURLs.append(url)
    }
}

private enum ImportTrashTestError: Error {
    case failed
}

final class ImportCoordinatorTests: XCTestCase {
    @MainActor
    func testDirectURLPersistsWithoutCreatingManagedFile() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        try await fixture.coordinator.importItem(URL(string: "https://example.com/path")!)

        let shortcuts = try fixture.container.mainContext.fetch(FetchDescriptor<WebShortcut>())
        XCTAssertEqual(shortcuts.count, 1)
        XCTAssertEqual(shortcuts[0].displayName, "example.com")
        XCTAssertEqual(shortcuts[0].normalizedURLString, "https://example.com/path")
        XCTAssertEqual(shortcuts[0].sourceType, .directURL)
        XCTAssertEqual(shortcuts[0].launchMode, .defaultBrowser)
        XCTAssertNil(shortcuts[0].managedFileRelativePath)
        XCTAssertTrue(fixture.trasher.trashedURLs.isEmpty)
        XCTAssertTrue(
            (try? FileManager.default.contentsOfDirectory(
                at: fixture.storage.shortcutsURL,
                includingPropertiesForKeys: nil
            ))?.isEmpty == true
        )
    }

    @MainActor
    func testChromeFileImportNormalizesURLBrowserAndProfileWithoutManagedCopy() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let source = fixture.root.appendingPathComponent("ChatGPT.crwebloc")
        let plist: [String: Any] = [
            "URL": "https://chatgpt.com/",
            "CrProfile": "Profile 12"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: source)

        try await fixture.coordinator.importItem(source)

        let shortcuts = try fixture.container.mainContext.fetch(FetchDescriptor<WebShortcut>())
        let shortcut = try XCTUnwrap(shortcuts.first)
        XCTAssertEqual(shortcuts.count, 1)
        XCTAssertEqual(shortcut.sourceType, .chromeWebloc)
        XCTAssertEqual(shortcut.launchMode, .specifiedBrowser)
        XCTAssertEqual(shortcut.normalizedURLString, "https://chatgpt.com/")
        XCTAssertEqual(shortcut.browserBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(shortcut.browserProfileDirectory, "Profile 12")
        XCTAssertNil(shortcut.managedFileRelativePath)
        XCTAssertEqual(fixture.trasher.trashedURLs, [source])
        XCTAssertTrue(
            (try? FileManager.default.contentsOfDirectory(
                at: fixture.storage.shortcutsURL,
                includingPropertiesForKeys: nil
            ))?.isEmpty == true
        )
    }

    @MainActor
    func testSourceCleanupFailureKeepsSuccessfulNormalizedRecord() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        fixture.trasher.error = ImportTrashTestError.failed
        let source = fixture.root.appendingPathComponent("Example.webloc")
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["URL": "https://example.com/"],
            format: .xml,
            options: 0
        )
        try data.write(to: source)

        do {
            try await fixture.coordinator.importItem(source)
            XCTFail("Expected source cleanup warning")
        } catch let error as ImportCoordinatorError {
            guard case .sourceCleanupPending(let pendingURL) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(pendingURL, source)
        }

        let shortcuts = try fixture.container.mainContext.fetch(FetchDescriptor<WebShortcut>())
        XCTAssertEqual(shortcuts.count, 1)
        XCTAssertEqual(shortcuts[0].normalizedURLString, "https://example.com/")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertNil(shortcuts[0].managedFileRelativePath)
    }

    @MainActor
    private func makeFixture() throws -> (
        container: ModelContainer,
        storage: ManagedStorage,
        root: URL,
        trasher: RecordingImportTrasher,
        coordinator: ImportCoordinator
    ) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            configurations: configuration
        )
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockCoordinator-\(UUID().uuidString)", isDirectory: true)
        let storage = try ManagedStorage(rootURL: root.appendingPathComponent("Managed", isDirectory: true))
        let trasher = RecordingImportTrasher()
        let coordinator = ImportCoordinator(
            modelContainer: container,
            managedStorage: storage,
            fileTrasher: trasher
        )
        return (container, storage, root, trasher, coordinator)
    }
}
