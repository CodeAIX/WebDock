import AppKit
import Combine
import Foundation

func normalizeAccountEmail(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed.lowercased(with: Locale(identifier: "en_US_POSIX"))
}

enum BrowserProfileRoutingSupport: String, Codable, Hashable {
    case none
    case verifiedChromiumWebloc
    case experimentalChromiumWebloc
}

enum BrowserProfileAccessStatus: Equatable {
    case unknown
    case notApplicable
    case authorized(Int)
    case needsAuthorization
    case unavailable(String)

    var label: String {
        switch self {
        case .unknown: "Not checked"
        case .notApplicable: "Not required"
        case .authorized(let count): count == 1 ? "1 profile available" : "\(count) profiles available"
        case .needsAuthorization: "Account access required"
        case .unavailable(let message): message
        }
    }
}

struct BrowserOption: Identifiable, Hashable {
    let family: BrowserFamily
    let bundleIdentifier: String
    let displayName: String
    let chromiumUserDataRelativePath: String?
    let profileRoutingSupport: BrowserProfileRoutingSupport

    init(
        family: BrowserFamily = .chrome,
        bundleIdentifier: String,
        displayName: String,
        chromiumUserDataRelativePath: String? = nil,
        profileRoutingSupport: BrowserProfileRoutingSupport = .none
    ) {
        self.family = family
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

struct BrowserAccountOption: Identifiable, Hashable {
    let email: String
    let displayName: String?

    var id: String { normalizeAccountEmail(email) ?? email }

    var displayLabel: String {
        guard let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !displayName.isEmpty,
              displayName.caseInsensitiveCompare(email) != .orderedSame else {
            return email
        }
        return "\(displayName) · \(email)"
    }
}

@MainActor
protocol ApplicationLocating: AnyObject {
    func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL?
}

extension NSWorkspace: ApplicationLocating {}

@MainActor
final class BrowserCatalog: ObservableObject {
    private let workspace: any ApplicationLocating
    private let profileDiscovery: BrowserProfileDiscovery

    @Published private(set) var accessStatuses: [String: BrowserProfileAccessStatus] = [:]

    init(
        workspace: (any ApplicationLocating)? = nil,
        profileDiscovery: BrowserProfileDiscovery = BrowserProfileDiscovery()
    ) {
        self.workspace = workspace ?? NSWorkspace.shared
        self.profileDiscovery = profileDiscovery
    }

    private let candidates: [BrowserOption] = [
        BrowserOption(family: .safari, bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
        BrowserOption(
            family: .chrome,
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            chromiumUserDataRelativePath: "Google/Chrome",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            family: .chrome,
            bundleIdentifier: "com.google.Chrome.beta",
            displayName: "Google Chrome Beta",
            chromiumUserDataRelativePath: "Google/Chrome Beta",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            family: .chrome,
            bundleIdentifier: "com.google.Chrome.dev",
            displayName: "Google Chrome Dev",
            chromiumUserDataRelativePath: "Google/Chrome Dev",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            family: .chrome,
            bundleIdentifier: "com.google.Chrome.canary",
            displayName: "Google Chrome Canary",
            chromiumUserDataRelativePath: "Google/Chrome Canary",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            family: .chromium,
            bundleIdentifier: "org.chromium.Chromium",
            displayName: "Chromium",
            chromiumUserDataRelativePath: "Chromium",
            profileRoutingSupport: .verifiedChromiumWebloc
        ),
        BrowserOption(
            family: .edge,
            bundleIdentifier: "com.microsoft.edgemac",
            displayName: "Microsoft Edge",
            chromiumUserDataRelativePath: "Microsoft Edge",
            profileRoutingSupport: .experimentalChromiumWebloc
        ),
        BrowserOption(family: .firefox, bundleIdentifier: "org.mozilla.firefox", displayName: "Firefox"),
        BrowserOption(
            family: .brave,
            bundleIdentifier: "com.brave.Browser",
            displayName: "Brave Browser",
            chromiumUserDataRelativePath: "BraveSoftware/Brave-Browser",
            profileRoutingSupport: .experimentalChromiumWebloc
        ),
        BrowserOption(family: .arc, bundleIdentifier: "company.thebrowser.Browser", displayName: "Arc"),
        BrowserOption(
            family: .vivaldi,
            bundleIdentifier: "com.vivaldi.Vivaldi",
            displayName: "Vivaldi",
            chromiumUserDataRelativePath: "Vivaldi",
            profileRoutingSupport: .experimentalChromiumWebloc
        )
    ]

    func installedBrowsers() -> [BrowserOption] {
        candidates.filter(isInstalled)
    }

    func installedProfileBrowsers() -> [BrowserOption] {
        installedBrowsers().filter(\.supportsProfiles)
    }

    func installedBrowser(for family: BrowserFamily) -> BrowserOption? {
        candidates.first { $0.family == family && isInstalled($0) }
    }

    func browser(bundleIdentifier: String) -> BrowserOption? {
        candidates.first(where: { $0.bundleIdentifier == bundleIdentifier })
    }

    func isInstalled(_ browser: BrowserOption) -> Bool {
        workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
    }

    func accessStatus(for browser: BrowserOption) -> BrowserProfileAccessStatus {
        guard browser.supportsProfiles else { return .notApplicable }
        return accessStatuses[browser.bundleIdentifier] ?? .unknown
    }

    @discardableResult
    func requestProfileAccess(for browser: BrowserOption) -> BrowserProfileAccessStatus {
        guard browser.supportsProfiles else {
            accessStatuses[browser.bundleIdentifier] = .notApplicable
            return .notApplicable
        }
        do {
            let profiles = try profileDiscovery.discoverProfiles(for: browser)
            let status: BrowserProfileAccessStatus = .authorized(profiles.count)
            accessStatuses[browser.bundleIdentifier] = status
            return status
        } catch {
            let status: BrowserProfileAccessStatus
            if Self.isPermissionError(error) {
                status = .needsAuthorization
            } else {
                status = .unavailable(error.localizedDescription)
            }
            accessStatuses[browser.bundleIdentifier] = status
            return status
        }
    }

    func requestProfileAccess(for family: BrowserFamily) {
        guard let browser = installedBrowser(for: family) else { return }
        _ = requestProfileAccess(for: browser)
    }

    func requestAccessForInstalledProfileBrowsers() {
        for browser in installedProfileBrowsers() {
            _ = requestProfileAccess(for: browser)
        }
    }

    func profiles(for browser: BrowserOption) -> [BrowserProfileOption] {
        guard browser.supportsProfiles else { return [] }
        do {
            let profiles = try profileDiscovery.discoverProfiles(for: browser)
            accessStatuses[browser.bundleIdentifier] = .authorized(profiles.count)
            return profiles
        } catch {
            accessStatuses[browser.bundleIdentifier] = Self.isPermissionError(error)
                ? .needsAuthorization
                : .unavailable(error.localizedDescription)
            return []
        }
    }

    func profiles(for family: BrowserFamily) -> [BrowserProfileOption] {
        guard let browser = installedBrowser(for: family) else { return [] }
        return profiles(for: browser)
    }

    func profile(
        bundleIdentifier: String,
        profileDirectory: String
    ) -> BrowserProfileOption? {
        guard let browser = browser(bundleIdentifier: bundleIdentifier),
              isInstalled(browser) else { return nil }
        return profiles(for: browser)
            .first(where: { $0.profileDirectory == profileDirectory })
    }

    func accounts(for family: BrowserFamily) -> [BrowserAccountOption] {
        var byEmail: [String: BrowserAccountOption] = [:]
        for profile in profiles(for: family) {
            guard let email = normalizeAccountEmail(profile.accountEmail) else { continue }
            if byEmail[email] == nil {
                byEmail[email] = BrowserAccountOption(
                    email: email,
                    displayName: profile.accountDisplayName ?? profile.localProfileName
                )
            }
        }
        return byEmail.values.sorted {
            $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending
        }
    }

    func openPrivacySettings() {
        let workspace = NSWorkspace.shared
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ]
        for raw in urls {
            if let url = URL(string: raw), workspace.open(url) {
                return
            }
        }
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileReadNoPermissionError {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == Int(EACCES) || nsError.code == Int(EPERM) {
            return true
        }
        return false
    }
}
