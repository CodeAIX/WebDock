import SwiftData
import XCTest
@testable import WebDock

final class ImportCoordinatorTests: XCTestCase {
    @MainActor
    func testDirectURLPersistsWithoutCreatingManagedFile() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            configurations: configuration
        )

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockCoordinator-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let storage = try ManagedStorage(rootURL: root)
        let coordinator = ImportCoordinator(
            modelContainer: container,
            managedStorage: storage
        )

        try await coordinator.importItem(URL(string: "https://example.com/path")!)

        let shortcuts = try container.mainContext.fetch(FetchDescriptor<WebShortcut>())
        XCTAssertEqual(shortcuts.count, 1)
        XCTAssertEqual(shortcuts[0].displayName, "example.com")
        XCTAssertEqual(shortcuts[0].normalizedURLString, "https://example.com/path")
        XCTAssertEqual(shortcuts[0].sourceType, .directURL)
        XCTAssertEqual(shortcuts[0].launchMode, .defaultBrowser)
        XCTAssertNil(shortcuts[0].managedFileRelativePath)
        XCTAssertTrue(
            (try? fileManager.contentsOfDirectory(at: storage.shortcutsURL, includingPropertiesForKeys: nil))?.isEmpty == true
        )
    }
}
