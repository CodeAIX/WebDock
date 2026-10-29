import SwiftData
import XCTest
@testable import WebDock

final class SwiftDataPersistenceTests: XCTestCase {
    @MainActor
    func testShortcutPersistsAcrossContainerReload() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockSwiftData-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = root.appendingPathComponent("WebDock.store")
        let schema = Schema([WebShortcut.self, ShortcutGroup.self])
        let configuration = ModelConfiguration(
            "WebDockTests",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        var firstContainer: ModelContainer? = try ModelContainer(
            for: schema,
            configurations: configuration
        )
        let insertedID = UUID()
        let shortcut = WebShortcut(
            id: insertedID,
            displayName: "ChatGPT",
            normalizedURLString: "https://chatgpt.com/",
            sourceType: .chromeWebloc,
            launchMode: .originalShortcutFile,
            sortIndex: 42
        )
        shortcut.browserProfileHint = "Profile 12"
        shortcut.managedFileRelativePath = "Shortcuts/\(insertedID.uuidString)/original.crwebloc"
        firstContainer?.mainContext.insert(shortcut)
        try firstContainer?.mainContext.save()
        firstContainer = nil

        let secondConfiguration = ModelConfiguration(
            "WebDockTests",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let secondContainer = try ModelContainer(
            for: schema,
            configurations: secondConfiguration
        )
        let descriptor = FetchDescriptor<WebShortcut>()
        let reloaded = try secondContainer.mainContext.fetch(descriptor)

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.id, insertedID)
        XCTAssertEqual(reloaded.first?.displayName, "ChatGPT")
        XCTAssertEqual(reloaded.first?.browserProfileHint, "Profile 12")
        XCTAssertEqual(reloaded.first?.launchMode, .originalShortcutFile)
        XCTAssertEqual(reloaded.first?.sourceType, .chromeWebloc)
    }
}
