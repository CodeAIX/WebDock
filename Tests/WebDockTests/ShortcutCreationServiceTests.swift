import SwiftData
import XCTest
@testable import WebDock

final class ShortcutCreationServiceTests: XCTestCase {
    @MainActor
    func testCreatesPortableChromeAccountRule() throws {
        let container = try makeContainer()
        let service = ShortcutCreationService(modelContainer: container)

        let shortcut = try service.create(
            name: "ChatGPT",
            url: "https://chatgpt.com/",
            browserFamily: .chrome,
            targetAccountEmail: "  User@Example.COM  "
        )

        XCTAssertEqual(shortcut.preferredBrowserFamily, .chrome)
        XCTAssertEqual(shortcut.targetAccountEmail, "user@example.com")
        XCTAssertEqual(shortcut.normalizedURLString, "https://chatgpt.com/")
    }

    @MainActor
    func testDefaultBrowserDropsAccountIdentity() throws {
        let container = try makeContainer()
        let service = ShortcutCreationService(modelContainer: container)

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
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            DeviceShortcutBinding.self,
            configurations: configuration
        )
    }
}
