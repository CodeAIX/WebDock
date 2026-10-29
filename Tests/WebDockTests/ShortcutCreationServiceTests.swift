import XCTest
@testable import WebDock

final class ShortcutCreationServiceTests: XCTestCase {
    @MainActor
    func testCreatesPortableChromeAccountRule() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShortcutCreationService(dataStore: store)

        let shortcut = try service.create(
            name: "ChatGPT",
            url: "https://chatgpt.com/",
            browserFamily: .chrome,
            targetAccountEmail: "  User@Example.COM  "
        )

        XCTAssertEqual(shortcut.preferredBrowserFamily, .chrome)
        XCTAssertEqual(shortcut.targetAccountEmail, "user@example.com")
        XCTAssertEqual(shortcut.normalizedURLString, "https://chatgpt.com/")
        XCTAssertEqual(store.activeShortcuts.map(\.id), [shortcut.id])
    }

    @MainActor
    func testDefaultBrowserDropsAccountIdentity() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShortcutCreationService(dataStore: store)

        let shortcut = try service.create(
            name: "",
            url: "https://example.com/path",
            browserFamily: nil,
            targetAccountEmail: "user@example.com"
        )

        XCTAssertNil(shortcut.preferredBrowserFamily)
        XCTAssertNil(shortcut.targetAccountEmail)
        XCTAssertEqual(shortcut.displayName, "example.com")
    }

    @MainActor
    private func makeStore() throws -> (WebDockDataStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebDockCreationTests-\(UUID().uuidString)", isDirectory: true)
        return (try WebDockDataStore(rootURL: root), root)
    }
}
