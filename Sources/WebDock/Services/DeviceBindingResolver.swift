import Foundation

enum AccountProfileMatch {
    case none
    case one(BrowserProfileOption)
    case ambiguous([BrowserProfileOption])
}

struct AccountProfileMatcher {
    static func match(
        targetEmail: String,
        profiles: [BrowserProfileOption]
    ) -> AccountProfileMatch {
        guard let normalizedTarget = normalizeAccountEmail(targetEmail) else {
            return .none
        }
        let matches = profiles.filter {
            normalizeAccountEmail($0.accountEmail) == normalizedTarget
        }
        switch matches.count {
        case 0:
            return .none
        case 1:
            return .one(matches[0])
        default:
            return .ambiguous(matches)
        }
    }
}

struct ShortcutResolution {
    let browser: BrowserOption?
    let profile: BrowserProfileOption?
    let status: DeviceResolutionStatus
    let warningMessage: String?
    let usesLocalOverride: Bool

    var hasWarning: Bool {
        switch status {
        case .missingBrowser, .missingAccount, .ambiguousAccount:
            true
        case .systemDefault, .resolved, .localOverride:
            false
        }
    }

    var summary: String {
        guard let browser else { return "System default browser" }
        if let profile {
            let account = profile.accountEmail ?? profile.localProfileName ?? profile.profileDirectory
            return "\(browser.displayName) · \(account)"
        }
        return "\(browser.displayName) · browser default"
    }
}

@MainActor
final class DeviceBindingResolver {
    private let dataStore: WebDockDataStore
    private let browserCatalog: BrowserCatalog

    init(dataStore: WebDockDataStore, browserCatalog: BrowserCatalog) {
        self.dataStore = dataStore
        self.browserCatalog = browserCatalog
    }

    func binding(for shortcutID: UUID) -> DeviceShortcutBinding? {
        dataStore.binding(for: shortcutID)
    }

    func resolution(for shortcut: WebShortcut) -> ShortcutResolution {
        if let binding = binding(for: shortcut.id),
           let overrideBundleIdentifier = binding.overrideBrowserBundleIdentifier,
           let overrideBrowser = browserCatalog.browser(bundleIdentifier: overrideBundleIdentifier),
           browserCatalog.isInstalled(overrideBrowser) {
            let overrideProfile: BrowserProfileOption?
            if let directory = binding.overrideProfileDirectory {
                overrideProfile = browserCatalog.profile(
                    bundleIdentifier: overrideBundleIdentifier,
                    profileDirectory: directory
                )
            } else {
                overrideProfile = nil
            }

            if binding.overrideProfileDirectory == nil || overrideProfile != nil {
                return ShortcutResolution(
                    browser: overrideBrowser,
                    profile: overrideProfile,
                    status: .localOverride,
                    warningMessage: nil,
                    usesLocalOverride: true
                )
            }
        }

        guard let family = shortcut.preferredBrowserFamily else {
            return ShortcutResolution(
                browser: nil,
                profile: nil,
                status: .systemDefault,
                warningMessage: nil,
                usesLocalOverride: false
            )
        }

        guard let browser = browserCatalog.installedBrowser(for: family) else {
            return ShortcutResolution(
                browser: nil,
                profile: nil,
                status: .missingBrowser,
                warningMessage: "Preferred browser \(family.displayName) is not installed on this Mac. Using the system default browser.",
                usesLocalOverride: false
            )
        }

        guard let targetEmail = normalizeAccountEmail(shortcut.targetAccountEmail) else {
            return ShortcutResolution(
                browser: browser,
                profile: nil,
                status: .resolved,
                warningMessage: nil,
                usesLocalOverride: false
            )
        }

        guard browser.supportsProfiles else {
            return ShortcutResolution(
                browser: browser,
                profile: nil,
                status: .missingAccount,
                warningMessage: "\(browser.displayName) does not expose a profile for \(targetEmail) on this Mac. Using the browser default profile.",
                usesLocalOverride: false
            )
        }

        switch AccountProfileMatcher.match(
            targetEmail: targetEmail,
            profiles: browserCatalog.profiles(for: browser)
        ) {
        case .none:
            return ShortcutResolution(
                browser: browser,
                profile: nil,
                status: .missingAccount,
                warningMessage: "Account \(targetEmail) was not found in \(browser.displayName) on this Mac. Using the browser default profile.",
                usesLocalOverride: false
            )
        case .one(let profile):
            return ShortcutResolution(
                browser: browser,
                profile: profile,
                status: .resolved,
                warningMessage: nil,
                usesLocalOverride: false
            )
        case .ambiguous:
            return ShortcutResolution(
                browser: browser,
                profile: nil,
                status: .ambiguousAccount,
                warningMessage: "Account \(targetEmail) exists in more than one local profile. Using the browser default until you choose a profile for this Mac.",
                usesLocalOverride: false
            )
        }
    }

    @discardableResult
    func refreshBinding(for shortcut: WebShortcut) throws -> ShortcutResolution {
        let resolution = resolution(for: shortcut)
        var binding = binding(for: shortcut.id) ?? DeviceShortcutBinding(shortcutID: shortcut.id)
        binding.resolvedBrowserBundleIdentifier = resolution.browser?.bundleIdentifier
        binding.resolvedProfileDirectory = resolution.profile?.profileDirectory
        binding.resolvedAccountEmail = normalizeAccountEmail(resolution.profile?.accountEmail)
        binding.resolutionStatus = resolution.status
        binding.warningMessage = resolution.warningMessage
        binding.updatedAt = Date()
        try dataStore.upsertDeviceBinding(binding)
        return resolution
    }

    func setLocalOverride(
        for shortcut: WebShortcut,
        browserBundleIdentifier: String,
        profileDirectory: String?
    ) throws {
        guard let browser = browserCatalog.browser(bundleIdentifier: browserBundleIdentifier),
              browserCatalog.isInstalled(browser) else {
            throw DeviceBindingError.browserNotInstalled
        }
        if let profileDirectory,
           browserCatalog.profile(
                bundleIdentifier: browserBundleIdentifier,
                profileDirectory: profileDirectory
           ) == nil {
            throw DeviceBindingError.profileNotFound
        }

        var binding = binding(for: shortcut.id) ?? DeviceShortcutBinding(shortcutID: shortcut.id)
        binding.overrideBrowserBundleIdentifier = browserBundleIdentifier
        binding.overrideProfileDirectory = profileDirectory
        binding.updatedAt = Date()
        try dataStore.upsertDeviceBinding(binding)
        _ = try refreshBinding(for: shortcut)
    }

    func clearLocalOverride(for shortcut: WebShortcut) throws {
        guard var binding = binding(for: shortcut.id) else { return }
        binding.overrideBrowserBundleIdentifier = nil
        binding.overrideProfileDirectory = nil
        binding.updatedAt = Date()
        try dataStore.upsertDeviceBinding(binding)
        _ = try refreshBinding(for: shortcut)
    }
}

enum DeviceBindingError: LocalizedError {
    case browserNotInstalled
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .browserNotInstalled:
            "The browser selected for this Mac is not installed."
        case .profileNotFound:
            "The browser profile selected for this Mac no longer exists."
        }
    }
}
