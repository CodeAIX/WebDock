import SwiftData
import XCTest
@testable import WebDock

final class SwiftDataPersistenceTests: XCTestCase {
    @MainActor
    func testPortableShortcutPersistsAcrossContainerReload() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockSwiftData-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = root.appendingPathComponent("WebDock.store")
        let schema = Schema([WebShortcut.self, ShortcutGroup.self, DeviceShortcutBinding.self])
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
            preferredBrowserFamily: .chrome,
            targetAccountEmail: "user@example.com",
            sortIndex: 42
        )
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
        let reloaded = try secondContainer.mainContext.fetch(FetchDescriptor<WebShortcut>())

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.id, insertedID)
        XCTAssertEqual(reloaded.first?.preferredBrowserFamily, .chrome)
        XCTAssertEqual(reloaded.first?.targetAccountEmail, "user@example.com")
    }
}
