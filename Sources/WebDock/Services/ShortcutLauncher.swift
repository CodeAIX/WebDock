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

    init(
        workspace: (any WorkspaceOpening)? = nil,
        profileShortcutWriter: (any BrowserProfileShortcutWriting)? = nil
    ) {
        self.workspace = workspace ?? SystemWorkspace()
        self.profileShortcutWriter = profileShortcutWriter ?? ChromiumProfileShortcutWriter()
    }

    /// Launching consumes the device-local resolution rather than reading any
    /// local profile directory from the synced shortcut itself.
    func launch(
        _ shortcut: WebShortcut,
        resolution: ShortcutResolution,
        storageRoot: URL
    ) throws {
        let url = try validatedURL(for: shortcut)

        guard let browser = resolution.browser else {
            guard workspace.open(url) else {
                throw ShortcutLaunchError.openFailed
            }
            return
        }

        guard let applicationURL = workspace.applicationURL(
            forBundleIdentifier: browser.bundleIdentifier
        ) else {
            // Resolution normally catches this before launch. Falling back here
            // still keeps a shortcut usable if the browser disappeared between
            // resolution and the click.
            guard workspace.open(url) else {
                throw ShortcutLaunchError.openFailed
            }
            return
        }

        if let profile = resolution.profile {
            let profileShortcut: URL
            do {
                profileShortcut = try profileShortcutWriter.writeShortcut(
                    targetURL: url,
                    profileDirectory: profile.profileDirectory,
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
    }

    private func validatedURL(for shortcut: WebShortcut) throws -> URL {
        guard let url = URL(string: shortcut.normalizedURLString) else {
            throw ShortcutLaunchError.invalidURL
        }
        do {
            try validateWebURL(url)
            return url
        } catch {
            throw ShortcutLaunchError.invalidURL
        }
    }
}

enum ShortcutLaunchError: LocalizedError, Equatable {
    case invalidURL
    case profileShortcutCreationFailed
    case openFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            L10n.tr("The shortcut does not contain a valid HTTP or HTTPS URL.")
        case .profileShortcutCreationFailed:
            L10n.tr("WebDock could not prepare the browser profile route.")
        case .openFailed:
            L10n.tr("macOS could not open the shortcut.")
        }
    }
}
