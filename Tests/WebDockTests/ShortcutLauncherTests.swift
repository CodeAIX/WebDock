import XCTest
@testable import WebDock

@MainActor
private final class WorkspaceSpy: WorkspaceOpening {
    private(set) var openedURLs: [URL] = []
    private(set) var specifiedOpenCalls: [(url: URL, applicationURL: URL)] = []
    var applicationURLs: [String: URL] = [:]
    var defaultOpenResult = true

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return defaultOpenResult
    }

    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        applicationURLs[bundleIdentifier]
    }

    func open(_ url: URL, withApplicationAt applicationURL: URL) {
        specifiedOpenCalls.append((url, applicationURL))
    }
}

final class ShortcutLauncherTests: XCTestCase {
    @MainActor
    func testChromeWeblocLaunchesManagedShortcutFileInsteadOfNormalizedURL() throws {
        let workspace = WorkspaceSpy()
        let launcher = ShortcutLauncher(workspace: workspace)
        let root = URL(fileURLWithPath: "/tmp/WebDock", isDirectory: true)

        let shortcut = WebShortcut(
            displayName: "ChatGPT",
            normalizedURLString: "https://chatgpt.com/",
            sourceType: .chromeWebloc,
            launchMode: .originalShortcutFile
        )
        shortcut.browserProfileHint = "Profile 12"
        shortcut.managedFileRelativePath = "Shortcuts/example/original.crwebloc"

        try launcher.launch(shortcut, storageRoot: root)

        XCTAssertEqual(workspace.openedURLs.count, 1)
        XCTAssertEqual(
            workspace.openedURLs.first,
            root.appendingPathComponent("Shortcuts/example/original.crwebloc")
        )
        XCTAssertNotEqual(workspace.openedURLs.first?.absoluteString, "https://chatgpt.com/")
        XCTAssertTrue(workspace.specifiedOpenCalls.isEmpty)
    }

    @MainActor
    func testStandardWeblocLaunchesNormalizedURLInDefaultBrowser() throws {
        let workspace = WorkspaceSpy()
        let launcher = ShortcutLauncher(workspace: workspace)

        let shortcut = WebShortcut(
            displayName: "Example",
            normalizedURLString: "https://example.com/",
            sourceType: .webLoc,
            launchMode: .defaultBrowser
        )

        try launcher.launch(
            shortcut,
            storageRoot: URL(fileURLWithPath: "/tmp/WebDock", isDirectory: true)
        )

        XCTAssertEqual(workspace.openedURLs, [URL(string: "https://example.com/")!])
        XCTAssertTrue(workspace.specifiedOpenCalls.isEmpty)
    }

    @MainActor
    func testSpecifiedBrowserResolvesBundleIdentifierAndOpensURLThere() throws {
        let workspace = WorkspaceSpy()
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        workspace.applicationURLs["com.google.Chrome"] = chromeURL
        let launcher = ShortcutLauncher(workspace: workspace)

        let shortcut = WebShortcut(
            displayName: "Example",
            normalizedURLString: "https://example.com/research",
            sourceType: .webLoc,
            launchMode: .specifiedBrowser
        )
        shortcut.browserBundleIdentifier = "com.google.Chrome"

        try launcher.launch(
            shortcut,
            storageRoot: URL(fileURLWithPath: "/tmp/WebDock", isDirectory: true)
        )

        XCTAssertTrue(workspace.openedURLs.isEmpty)
        XCTAssertEqual(workspace.specifiedOpenCalls.count, 1)
        XCTAssertEqual(workspace.specifiedOpenCalls[0].url.absoluteString, "https://example.com/research")
        XCTAssertEqual(workspace.specifiedOpenCalls[0].applicationURL, chromeURL)
    }

    @MainActor
    func testSpecifiedBrowserFailsClearlyWhenBrowserIsNotInstalled() throws {
        let workspace = WorkspaceSpy()
        let launcher = ShortcutLauncher(workspace: workspace)

        let shortcut = WebShortcut(
            displayName: "Example",
            normalizedURLString: "https://example.com/",
            sourceType: .webLoc,
            launchMode: .specifiedBrowser
        )
        shortcut.browserBundleIdentifier = "com.example.MissingBrowser"

        XCTAssertThrowsError(
            try launcher.launch(
                shortcut,
                storageRoot: URL(fileURLWithPath: "/tmp/WebDock", isDirectory: true)
            )
        ) { error in
            XCTAssertEqual(
                error as? ShortcutLaunchError,
                .browserNotInstalled("com.example.MissingBrowser")
            )
        }
        XCTAssertTrue(workspace.openedURLs.isEmpty)
        XCTAssertTrue(workspace.specifiedOpenCalls.isEmpty)
    }
}
