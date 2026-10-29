import AppKit
import Foundation

struct BrowserOption: Identifiable, Hashable {
    let bundleIdentifier: String
    let displayName: String
    let chromiumUserDataRelativePath: String?
    let profileRoutingSupport: BrowserProfileRoutingSupport

    init(
        bundleIdentifier: String,
        displayName: String,
        chromiumUserDataRelativePath: String? = nil,
        profileRoutingSupport: BrowserProfileRoutingSupport = .none
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.chromiumUserDataRelativePath = chromiumUserDataRelativePath
        self.profileRoutingSupport = profileRoutingSupport
    }

    var id: String { bundleIdentifier }

    var supportsProfiles: Bool {
        chromiumUserDataRelativePath != nil && profileRoutingSupport != .none
    }
}

@MainActor
final class BrowserCatalog {
    private let workspace: NSWorkspace
    private let profileDiscovery: BrowserProfileDiscovery

    init(
        workspace: NSWorkspace = .shared,
        profileDiscovery: BrowserProfileDiscovery = BrowserProfileDiscovery()
    ) {
        self.workspace = workspace
        self.profileDiscovery = profileDiscovery
    }

    private let candidates: [BrowserOption] = [
        BrowserOption(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
        BrowserOption(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            chromiumUserDataRelativePath: "Google/Chrome",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            bundleIdentifier: "com.google.Chrome.beta",
            displayName: "Google Chrome Beta",
            chromiumUserDataRelativePath: "Google/Chrome Beta",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            bundleIdentifier: "com.google.Chrome.dev",
            displayName: "Google Chrome Dev",
            chromiumUserDataRelativePath: "Google/Chrome Dev",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            bundleIdentifier: "com.google.Chrome.canary",
            displayName: "Google Chrome Canary",
            chromiumUserDataRelativePath: "Google/Chrome Canary",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            bundleIdentifier: "org.chromium.Chromium",
            displayName: "Chromium",
            chromiumUserDataRelativePath: "Chromium",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            bundleIdentifier: "com.microsoft.edgemac",
            displayName: "Microsoft Edge",
            chromiumUserDataRelativePath: "Microsoft Edge",
            profileRoutingSupport: .experimentalChromiumWebloc
        ),
        BrowserOption(bundleIdentifier: "org.mozilla.firefox", displayName: "Firefox"),
        BrowserOption(
            bundleIdentifier: "com.brave.Browser",
            displayName: "Brave Browser",
            chromiumUserDataRelativePath: "BraveSoftware/Brave-Browser",
            profileRoutingSupport: .experimentalChromiumWebloc
        ),
        BrowserOption(bundleIdentifier: "company.thebrowser.Browser", displayName: "Arc"),
        BrowserOption(
            bundleIdentifier: "com.vivaldi.Vivaldi",
            displayName: "Vivaldi",
            chromiumUserDataRelativePath: "Vivaldi",
            profileRoutingSupport: .experimentalChromiumWebloc
        )
    ]

    func installedBrowsers() -> [BrowserOption] {
        candidates.filter {
            workspace.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
        }
    }

    func browser(bundleIdentifier: String) -> BrowserOption? {
        candidates.first(where: { $0.bundleIdentifier == bundleIdentifier })
    }

    func profiles(for browser: BrowserOption) -> [BrowserProfileOption] {
        guard browser.supportsProfiles else { return [] }
        return (try? profileDiscovery.discoverProfiles(for: browser)) ?? []
    }

    func profiles(forBundleIdentifier bundleIdentifier: String) -> [BrowserProfileOption] {
        guard let browser = browser(bundleIdentifier: bundleIdentifier) else { return [] }
        return profiles(for: browser)
    }

    func profile(
        bundleIdentifier: String,
        profileDirectory: String
    ) -> BrowserProfileOption? {
        profiles(forBundleIdentifier: bundleIdentifier)
            .first(where: { $0.profileDirectory == profileDirectory })
    }

    /// Imported `.crwebloc` files carry only the profile directory, not the
    /// account display name. Resolve it locally for Manager UI convenience.
    func displayLabelForImportedChromeProfile(_ profileDirectory: String) -> String? {
        let preferredIDs = [
            "com.google.Chrome",
            "com.google.Chrome.beta",
            "com.google.Chrome.dev",
            "com.google.Chrome.canary",
            "org.chromium.Chromium"
        ]

        for bundleIdentifier in preferredIDs {
            if let profile = profile(
                bundleIdentifier: bundleIdentifier,
                profileDirectory: profileDirectory
            ) {
                return profile.displayLabel
            }
        }
        return nil
    }
}
