import SwiftData
import XCTest
@testable import WebDock

final class ShortcutCreationServiceTests: XCTestCase {
    @MainActor
    func testCreatesDefaultBrowserShortcutAndDerivesNameFromHost() throws {
        let container = try makeContainer()
        let service = ShortcutCreationService(modelContainer: container)

        let shortcut = try service.create(
            name: "   ",
            url: "https://example.com/path",
            browser: nil,
            profile: nil
        )

        XCTAssertEqual(shortcut.displayName, "example.com")
        XCTAssertEqual(shortcut.normalizedURLString, "https://example.com/path")
        XCTAssertEqual(shortcut.sourceType, .directURL)
        XCTAssertEqual(shortcut.launchMode, .defaultBrowser)
        XCTAssertNil(shortcut.browserBundleIdentifier)
        XCTAssertNil(shortcut.browserProfileDirectory)

        let stored = try container.mainContext.fetch(FetchDescriptor<WebShortcut>())
        XCTAssertEqual(stored.count, 1)
    }

    @MainActor
    func testCreatesChromeProfileShortcutWithReadableAccountMetadata() throws {
        let container = try makeContainer()
        let service = ShortcutCreationService(modelContainer: container)
        let browser = BrowserOption(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            chromiumUserDataRelativePath: "Google/Chrome",
            profileRoutingSupport: .verifiedChromiumWebloc
        )
        let profile = BrowserProfileOption(
            browserBundleIdentifier: "com.google.Chrome",
            browserDisplayName: "Google Chrome",
            profileDirectory: "Profile 12",
            localProfileName: "Research",
            accountDisplayName: "Research Account",
            accountEmail: "research@example.com",
            routingSupport: .verifiedChromiumWebloc
        )

        let shortcut = try service.create(
            name: "ChatGPT",
            url: "https://chatgpt.com/",
            browser: browser,
            profile: profile
        )

        XCTAssertEqual(shortcut.launchMode, .specifiedBrowser)
        XCTAssertEqual(shortcut.browserBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(shortcut.browserDisplayName, "Google Chrome")
        XCTAssertEqual(shortcut.browserProfileDirectory, "Profile 12")
        XCTAssertEqual(shortcut.browserProfileDisplayName, "Research Account")
        XCTAssertEqual(shortcut.browserProfileAccountEmail, "research@example.com")
        XCTAssertNil(shortcut.managedFileRelativePath)
    }

    @MainActor
    func testRejectsProfileFromDifferentBrowser() throws {
        let container = try makeContainer()
        let service = ShortcutCreationService(modelContainer: container)
        let browser = BrowserOption(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome"
        )
        let profile = BrowserProfileOption(
            browserBundleIdentifier: "com.brave.Browser",
            browserDisplayName: "Brave Browser",
            profileDirectory: "Profile 1",
            localProfileName: "Work",
            accountDisplayName: nil,
            accountEmail: nil,
            routingSupport: .experimentalChromiumWebloc
        )

        XCTAssertThrowsError(
            try service.create(
                name: "Example",
                url: "https://example.com/",
                browser: browser,
                profile: profile
            )
        ) { error in
            XCTAssertEqual(error as? ShortcutCreationError, .profileBrowserMismatch)
        }
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<WebShortcut>()).isEmpty)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            configurations: configuration
        )
    }
}
