import AppKit
import Foundation

@MainActor
protocol WorkspaceOpening: AnyObject {
    @discardableResult
    func open(_ url: URL) -> Bool
    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL?
    func open(_ url: URL, withApplicationAt applicationURL: URL)
}

@MainActor
final class SystemWorkspace: WorkspaceOpening {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    @discardableResult
    func open(_ url: URL) -> Bool {
        workspace.open(url)
    }

    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    func open(_ url: URL, withApplicationAt applicationURL: URL) {
        workspace.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }
}

@MainActor
final class ShortcutLauncher {
    private let workspace: any WorkspaceOpening
    private let profileShortcutWriter: any BrowserProfileShortcutWriting

    private static let chromiumProfileCapableBundleIdentifiers: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.vivaldi.Vivaldi"
    ]

    init(
        workspace: (any WorkspaceOpening)? = nil,
        profileShortcutWriter: (any BrowserProfileShortcutWriting)? = nil
    ) {
        self.workspace = workspace ?? SystemWorkspace()
        self.profileShortcutWriter = profileShortcutWriter ?? ChromiumProfileShortcutWriter()
    }

    func launch(_ shortcut: WebShortcut, storageRoot: URL) throws {
        guard let mode = shortcut.launchMode else {
            throw ShortcutLaunchError.invalidLaunchMode
        }

        switch mode {
        case .originalShortcutFile:
            guard let relative = shortcut.managedFileRelativePath,
                  !relative.isEmpty else {
                throw ShortcutLaunchError.missingManagedShortcut
            }
            let managedURL = storageRoot.appendingPathComponent(relative)
            guard workspace.open(managedURL) else {
                throw ShortcutLaunchError.openFailed
            }

        case .defaultBrowser:
            let url = try validatedURL(for: shortcut)
            guard workspace.open(url) else {
                throw ShortcutLaunchError.openFailed
            }

        case .specifiedBrowser:
            let url = try validatedURL(for: shortcut)
            guard let bundleIdentifier = shortcut.browserBundleIdentifier,
                  !bundleIdentifier.isEmpty else {
                throw ShortcutLaunchError.missingBrowserIdentifier
            }
            guard let applicationURL = workspace.applicationURL(
                forBundleIdentifier: bundleIdentifier
            ) else {
                throw ShortcutLaunchError.browserNotInstalled(bundleIdentifier)
            }

            if let profileDirectory = normalizedProfileDirectory(shortcut.browserProfileDirectory) {
                guard Self.chromiumProfileCapableBundleIdentifiers.contains(bundleIdentifier) else {
                    throw ShortcutLaunchError.profileRoutingNotSupported(bundleIdentifier)
                }
                let profileShortcut: URL
                do {
                    profileShortcut = try profileShortcutWriter.writeShortcut(
                        targetURL: url,
                        profileDirectory: profileDirectory,
                        shortcutID: shortcut.id,
                        storageRoot: storageRoot
                    )
                } catch {
                    throw ShortcutLaunchError.profileShortcutCreationFailed
                }
                workspace.open(profileShortcut, withApplicationAt: applicationURL)
            } else {
                workspace.open(url, withApplicationAt: applicationURL)
            }

        case .externalAppBundle:
            // Explicitly deferred to Milestone 9. Keeping this as an error is
            // safer than silently falling back to the default browser.
            throw ShortcutLaunchError.externalAppNotSupported
        }
    }

    private func validatedURL(for shortcut: WebShortcut) throws -> URL {
        guard let url = URL(string: shortcut.normalizedURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw ShortcutLaunchError.invalidURL
        }
        return url
    }

    private func normalizedProfileDirectory(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ShortcutLaunchError: LocalizedError, Equatable {
    case invalidLaunchMode
    case invalidURL
    case missingManagedShortcut
    case missingBrowserIdentifier
    case browserNotInstalled(String)
    case profileRoutingNotSupported(String)
    case profileShortcutCreationFailed
    case externalAppNotSupported
    case openFailed

    var errorDescription: String? {
        switch self {
        case .invalidLaunchMode:
            "The shortcut has an invalid launch mode."
        case .invalidURL:
            "The shortcut does not contain a valid HTTP or HTTPS URL."
        case .missingManagedShortcut:
            "The managed shortcut file is missing from this WebDock item."
        case .missingBrowserIdentifier:
            "No browser is configured for this shortcut."
        case .browserNotInstalled(let bundleIdentifier):
            "The selected browser is not installed: \(bundleIdentifier)."
        case .profileRoutingNotSupported(let bundleIdentifier):
            "Profile-specific launching is not supported for this browser: \(bundleIdentifier)."
        case .profileShortcutCreationFailed:
            "WebDock could not prepare the browser profile shortcut."
        case .externalAppNotSupported:
            "External app shortcuts are not enabled in WebDock v0.1."
        case .openFailed:
            "macOS could not open the shortcut."
        }
    }
}
