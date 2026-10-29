import Foundation
import XCTest
@testable import WebDock

@MainActor
final class ShortcutLauncherTests: XCTestCase {
    func testSystemDefaultResolutionOpensURLNormally() throws {
        let workspace = RecordingWorkspace()
        let writer = RecordingProfileWriter()
        let launcher = ShortcutLauncher(workspace: workspace, profileShortcutWriter: writer)
        let shortcut = makeShortcut()

        try launcher.launch(
            shortcut,
            resolution: ShortcutResolution(
                browser: nil,
                profile: nil,
                status: .systemDefault,
                warningMessage: nil,
                usesLocalOverride: false
            ),
            storageRoot: URL(fileURLWithPath: "/tmp/WebDockTests")
        )

        XCTAssertEqual(workspace.defaultOpenedURLs, [URL(string: "https://example.com/")!])
        XCTAssertTrue(workspace.applicationOpenedURLs.isEmpty)
    }

    func testResolvedProfileUsesLocalProfileDirectoryOnlyAtLaunchTime() throws {
        let workspace = RecordingWorkspace()
        workspace.applications["com.google.Chrome"] = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        let writer = RecordingProfileWriter()
        let launcher = ShortcutLauncher(workspace: workspace, profileShortcutWriter: writer)
        let shortcut = WebShortcut(
            displayName: "Mail",
            normalizedURLString: "https://mail.google.com/",
            preferredBrowserFamily: .chrome,
            targetAccountEmail: "user@example.com"
        )
        let browser = BrowserOption(
            family: .chrome,
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            chromiumUserDataRelativePath: "Google/Chrome",
            profileRoutingSupport: .verifiedChromiumWebloc
        )
        let profile = BrowserProfileOption(
            browserBundleIdentifier: browser.bundleIdentifier,
            browserDisplayName: browser.displayName,
            profileDirectory: "Profile 3",
            localProfileName: "Work",
            accountDisplayName: "User",
            accountEmail: "user@example.com",
            routingSupport: .verifiedChromiumWebloc
        )

        try launcher.launch(
            shortcut,
            resolution: ShortcutResolution(
                browser: browser,
                profile: profile,
                status: .resolved,
                warningMessage: nil,
                usesLocalOverride: false
            ),
            storageRoot: URL(fileURLWithPath: "/tmp/WebDockTests")
        )

        XCTAssertEqual(writer.lastProfileDirectory, "Profile 3")
        XCTAssertEqual(writer.lastTargetURL, URL(string: "https://mail.google.com/")!)
        XCTAssertEqual(workspace.applicationOpenedURLs.count, 1)
        XCTAssertEqual(workspace.applicationOpenedURLs.first?.applicationURL.lastPathComponent, "Google Chrome.app")
    }

    func testMissingAccountFallsBackToPreferredBrowserDefaultProfile() throws {
        let workspace = RecordingWorkspace()
        workspace.applications["com.google.Chrome"] = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        let writer = RecordingProfileWriter()
        let launcher = ShortcutLauncher(workspace: workspace, profileShortcutWriter: writer)
        let shortcut = makeShortcut()
        let browser = BrowserOption(
            family: .chrome,
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            chromiumUserDataRelativePath: "Google/Chrome",
            profileRoutingSupport: .verifiedChromiumWebloc
        )

        try launcher.launch(
            shortcut,
            resolution: ShortcutResolution(
                browser: browser,
                profile: nil,
                status: .missingAccount,
                warningMessage: "missing",
                usesLocalOverride: false
            ),
            storageRoot: URL(fileURLWithPath: "/tmp/WebDockTests")
        )

        XCTAssertNil(writer.lastProfileDirectory)
        XCTAssertEqual(workspace.applicationOpenedURLs.first?.url, URL(string: "https://example.com/")!)
    }

    private func makeShortcut() -> WebShortcut {
        WebShortcut(
            displayName: "Example",
            normalizedURLString: "https://example.com/"
        )
    }
}

@MainActor
private final class RecordingWorkspace: WorkspaceOpening {
    var applications: [String: URL] = [:]
    var defaultOpenedURLs: [URL] = []
    var applicationOpenedURLs: [(url: URL, applicationURL: URL)] = []

    func open(_ url: URL) -> Bool {
        defaultOpenedURLs.append(url)
        return true
    }

    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        applications[bundleIdentifier]
    }

    func open(_ url: URL, withApplicationAt applicationURL: URL) {
        applicationOpenedURLs.append((url, applicationURL))
    }
}

private final class RecordingProfileWriter: BrowserProfileShortcutWriting {
    var lastTargetURL: URL?
    var lastProfileDirectory: String?

    func writeShortcut(
        targetURL: URL,
        profileDirectory: String,
        shortcutID: UUID,
        storageRoot: URL
    ) throws -> URL {
        lastTargetURL = targetURL
        lastProfileDirectory = profileDirectory
        return storageRoot.appendingPathComponent("route.crwebloc")
    }
}
