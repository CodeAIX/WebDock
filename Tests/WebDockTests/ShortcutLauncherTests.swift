import XCTest
@testable import WebDock

private final class WorkspaceSpy: WorkspaceOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
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
    }
}
