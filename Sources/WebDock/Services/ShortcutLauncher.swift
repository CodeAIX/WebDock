import AppKit
import Foundation

protocol WorkspaceOpening {
    @MainActor func open(_ url: URL) -> Bool
}

extension NSWorkspace: WorkspaceOpening {}

@MainActor
final class ShortcutLauncher {
    private let workspace: any WorkspaceOpening

    init(workspace: any WorkspaceOpening = NSWorkspace.shared) {
        self.workspace = workspace
    }

    func launch(_ shortcut: WebShortcut, storageRoot: URL) throws {
        guard let mode = shortcut.launchMode else { return }

        switch mode {
        case .originalShortcutFile:
            guard let relative = shortcut.managedFileRelativePath else { return }
            _ = workspace.open(storageRoot.appendingPathComponent(relative))

        case .defaultBrowser:
            guard let url = URL(string: shortcut.normalizedURLString) else { return }
            _ = workspace.open(url)

        case .specifiedBrowser:
            // TODO(v0.1): use public NSWorkspace application resolution by bundle ID.
            guard let url = URL(string: shortcut.normalizedURLString) else { return }
            _ = workspace.open(url)

        case .externalAppBundle:
            // TODO(v0.1 experimental): open external app reference with NSWorkspace.
            break
        }
    }
}
