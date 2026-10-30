import AppKit
import SwiftUI

/// AppKit bridge for Return/Space on a focused grid tile (Ventura does not submit arbitrary SwiftUI views).
/// It observes only the containing key window and leaves text editing/menu shortcuts untouched.
struct LauncherReturnKey: NSViewRepresentable {
    var action: () -> Bool
    func makeNSView(context: Context) -> ReturnKeyView { ReturnKeyView(action: action) }
    func updateNSView(_ view: ReturnKeyView, context: Context) { view.action = action }

    final class ReturnKeyView: NSView {
        var action: () -> Bool
        private var monitor: Any?
        init(action: @escaping () -> Bool) {
            self.action = action
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.window, self.window?.isKeyWindow == true,
                      [36, 49, 76].contains(event.keyCode),
                      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return event }
                return self.action() ? nil : event
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
