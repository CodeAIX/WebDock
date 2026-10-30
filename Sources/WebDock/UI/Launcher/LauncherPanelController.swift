import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LauncherPanelController: NSWindowController {
    private let positionResolver = DockPositionResolver()
    private let newShortcut = NewShortcutPresentation()

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(environment: AppEnvironment, onOpenManager: @escaping () -> Void, onPrepareSettings: @escaping () -> Void) {
        let size = NSSize(width: 780, height: 520)
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

        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let root = LauncherView(
            environment: environment,
            newShortcut: newShortcut,
            onOpenManager: onOpenManager,
            onPrepareSettings: onPrepareSettings
        )
        panel.contentView = NSHostingView(rootView: root.modifier(WebDockAppearance()))

        super.init(window: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showNearDock() {
        guard let panel = window, let screen = positionResolver.targetScreen() else { return }
        let size = NSSize(width: min(780, screen.visibleFrame.width - 24), height: min(520, screen.visibleFrame.height - 24))
        panel.setContentSize(size)
        panel.setFrameOrigin(positionResolver.origin(for: panel.frame.size, on: screen))
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func presentNewShortcut() {
        guard window?.attachedSheet == nil else { return }
        newShortcut.isPresented = true
    }
}
