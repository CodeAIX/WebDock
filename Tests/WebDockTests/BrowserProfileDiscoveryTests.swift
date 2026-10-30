import XCTest
import Darwin
@testable import WebDock

final class BrowserProfileDiscoveryTests: XCTestCase {
    func testDiscoversReadableAccountNamesEmailsAndProfileDirectories() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockProfileDiscovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: home) }

        let userData = home
            .appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        try fileManager.createDirectory(
            at: userData.appendingPathComponent("Default", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: userData.appendingPathComponent("Profile 12", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: userData.appendingPathComponent("Profile 13", isDirectory: true),
            withIntermediateDirectories: true
        )

        let localState: [String: Any] = [
            "profile": [
                "info_cache": [
                    "Default": [
                        "name": "Personal",
                        "gaia_name": "Zo Civi",
                        "user_name": "zo@example.com"
                    ],
                    "Profile 12": [
                        "name": "Research",
                        "gaia_name": "Research Account",
                        "user_name": "research@example.com"
                    ],
                    "Profile 13": [
                        "name": "Ephemeral",
                        "is_ephemeral": true
                    ],
                    "Profile 99": [
                        "name": "Stale profile without directory"
                    ]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: localState, options: [.sortedKeys])
        try data.write(to: userData.appendingPathComponent("Local State"))

        let browser = BrowserOption(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            chromiumUserDataRelativePath: "Google/Chrome",
            profileRoutingSupport: .verifiedChromiumWebloc
        )
        let discovery = BrowserProfileDiscovery(
            fileManager: fileManager,
            homeDirectory: home
        )

        let profiles = try discovery.discoverProfiles(for: browser)

        XCTAssertEqual(profiles.map(\.profileDirectory), ["Default", "Profile 12"])
        XCTAssertEqual(profiles[0].accountDisplayName, "Zo Civi")
        XCTAssertEqual(profiles[0].accountEmail, "zo@example.com")
        XCTAssertEqual(profiles[0].localProfileName, "Personal")
        XCTAssertEqual(
            profiles[0].displayLabel,
            "Zo Civi · zo@example.com — Personal [Default]"
        )
        XCTAssertEqual(
            profiles[1].displayLabel,
            "Research Account · research@example.com — Research [Profile 12]"
        )
    }

    func testNonChromiumBrowserHasNoProfiles() throws {
        let discovery = BrowserProfileDiscovery()
        let safari = BrowserOption(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        XCTAssertTrue(try discovery.discoverProfiles(for: safari).isEmpty)
    }

    func testMissingLocalStateIsAnEmptyLibrary() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let browser = BrowserOption(bundleIdentifier: "com.google.Chrome", displayName: "Chrome",
            chromiumUserDataRelativePath: "Google/Chrome", profileRoutingSupport: .verifiedChromiumWebloc)
        XCTAssertTrue(try BrowserProfileDiscovery(homeDirectory: home).discoverProfiles(for: browser).isEmpty)
    }

    func testUnreadableDirectoryThrowsInsteadOfReportingZeroAccounts() throws {
        guard geteuid() != 0 else { throw XCTSkip("Filesystem permission checks require a non-root test user") }
        let manager = FileManager.default
        let home = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dataRoot = home.appendingPathComponent("Library/Application Support/Google/Chrome")
        try manager.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: dataRoot.appendingPathComponent("Local State"))
        defer {
            try? manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dataRoot.path)
            try? manager.removeItem(at: home)
        }
        try manager.setAttributes([.posixPermissions: 0], ofItemAtPath: dataRoot.path)
        let browser = BrowserOption(bundleIdentifier: "com.google.Chrome", displayName: "Chrome",
            chromiumUserDataRelativePath: "Google/Chrome", profileRoutingSupport: .verifiedChromiumWebloc)
        XCTAssertThrowsError(try BrowserProfileDiscovery(homeDirectory: home).discoverProfiles(for: browser))
    }
}
