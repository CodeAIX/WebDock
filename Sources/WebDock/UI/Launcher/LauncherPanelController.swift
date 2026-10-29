import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LauncherPanelController: NSWindowController {
    private let positionResolver = DockPositionResolver()

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(environment: AppEnvironment, onOpenManager: @escaping () -> Void) {
        let size = NSSize(width: 600, height: 420)
        let panel = LauncherPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true

        // AppDelegate is the sole owner of visibility and activation timing.
        // The panel must not independently hide or activate the application.
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let root = LauncherView(
            environment: environment,
            onOpenManager: onOpenManager
        )
        .modelContainer(environment.modelContainer)
        panel.contentView = NSHostingView(rootView: root)

        super.init(window: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showNearDock() {
        guard let panel = window, let screen = positionResolver.targetScreen() else { return }
        panel.setFrameOrigin(positionResolver.origin(for: panel.frame.size, on: screen))
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
