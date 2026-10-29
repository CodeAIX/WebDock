import AppKit
import Foundation

struct BrowserOption: Identifiable, Hashable {
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier }
}

@MainActor
final class BrowserCatalog {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    private let candidates: [BrowserOption] = [
        BrowserOption(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
        BrowserOption(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
        BrowserOption(bundleIdentifier: "com.microsoft.edgemac", displayName: "Microsoft Edge"),
        BrowserOption(bundleIdentifier: "org.mozilla.firefox", displayName: "Firefox"),
        BrowserOption(bundleIdentifier: "com.brave.Browser", displayName: "Brave Browser"),
        BrowserOption(bundleIdentifier: "company.thebrowser.Browser", displayName: "Arc"),
        BrowserOption(bundleIdentifier: "com.vivaldi.Vivaldi", displayName: "Vivaldi")
    ]

    func installedBrowsers() -> [BrowserOption] {
        candidates.filter {
            workspace.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
        }
    }
}
