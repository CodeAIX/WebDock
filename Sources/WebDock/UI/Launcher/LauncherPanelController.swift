import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class LauncherPanelController: NSWindowController {
    private let positionResolver = DockPositionResolver()
    private var resignActiveObserver: NSObjectProtocol?

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

        // Keep visibility under WebDock's control. NSPanel.hidesOnDeactivate can
        // race with Dock reopen handling: a panel shown by the Dock click can be
        // immediately hidden by the previous deactivation cycle, producing the
        // observed "flash then disappear" behavior.
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let root = LauncherView(
            environment: environment,
            onOpenManager: onOpenManager
        )
        .modelContainer(environment.modelContainer)
        panel.contentView = NSHostingView(rootView: root)

        super.init(window: panel)

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
        }
    }

    func showNearDock() {
        guard let panel = window, let screen = positionResolver.targetScreen() else { return }
        panel.setFrameOrigin(positionResolver.origin(for: panel.frame.size, on: screen))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggleNearDock() {
        if window?.isVisible == true {
            hide()
        } else {
            showNearDock()
        }
    }
}
