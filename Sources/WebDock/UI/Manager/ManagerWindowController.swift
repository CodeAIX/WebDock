import AppKit
import SwiftUI

@MainActor
final class ManagerWindowController: NSWindowController {
    private let newShortcut = NewShortcutPresentation()
    init(environment: AppEnvironment) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WebDock"
        window.minSize = NSSize(width: 700, height: 460)
        window.center()
        window.setFrameAutosaveName("WebDockManagerWindow")
        window.isReleasedWhenClosed = false

        let root = ManagerView(environment: environment, newShortcut: newShortcut)
        window.contentView = NSHostingView(rootView: root.modifier(WebDockAppearance()))

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showManager() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func presentNewShortcut() {
        guard window?.attachedSheet == nil else { return }
        newShortcut.isPresented = true
    }
}
