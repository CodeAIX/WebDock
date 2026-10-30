import AppKit
import SwiftUI

struct GlobalHotKeySettingsView: View {
    @ObservedObject var service: GlobalHotKeyService
    @ObservedObject private var language = AppLanguage.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L10n.tr("Enable global Launcher shortcut"), isOn: Binding(
                get: { service.isEnabled }, set: { service.setEnabled($0) }
            )).disabled(service.isRecording)
            HStack {
                if service.isRecording {
                    HotKeyRecorder(service: service)
                        .frame(width: 180, height: 30)
                    Button(L10n.tr("Cancel")) { service.cancelRecording() }
                } else {
                    Text(service.hotKey.displayValue)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .frame(minWidth: 90, alignment: .leading)
                        .accessibilityLabel(L10n.tr("Launcher shortcut"))
                        .accessibilityValue(service.hotKey.displayValue)
                    Button(L10n.tr("Record Shortcut…")) { service.beginRecording() }
                    Button(L10n.tr("Restore Default")) { service.save(.defaultValue) }
                        .disabled(service.hotKey == .defaultValue)
                }
            }
            if let error = service.error {
                Text(error.message).font(.caption).foregroundStyle(.red)
            }
            if service.isEnabled && !service.isRegistered && !service.isRecording {
                Button(L10n.tr("Retry Registration")) { service.retry() }
            }
            Text(service.isRecording
                ? L10n.tr("Press a key combination. Escape cancels; switching away cancels recording.")
                : L10n.tr("Open Launcher from any application while WebDock is running. This shortcut is saved only on this Mac."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear { service.cancelRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            service.cancelRecording()
        }
    }
}

/// A focused responder captures only deliberate recording input, including menu equivalents.
/// No global keyboard monitor or accessibility/input-monitoring permission is used.
private struct HotKeyRecorder: NSViewRepresentable {
    let service: GlobalHotKeyService

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.service = service
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.service = service
        nsView.needsDisplay = true
        nsView.setAccessibilityLabel(L10n.tr("Press shortcut…"))
        nsView.setAccessibilityElement(true)
        nsView.setAccessibilityRole(.textField)
    }

    final class RecorderView: NSView {
        weak var service: GlobalHotKeyService?
        private var didFocus = false
        override var acceptsFirstResponder: Bool { true }
        override var focusRingType: NSFocusRingType { get { .exterior } set {} }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, !didFocus else { return }
            didFocus = true
            DispatchQueue.main.async { [weak self] in
                guard let self, self.service?.isRecording == true else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func resignFirstResponder() -> Bool {
            // Defer because SwiftUI may remove this view while committing a combination.
            DispatchQueue.main.async { [weak service] in service?.cancelRecording() }
            return true
        }

        override func keyDown(with event: NSEvent) { capture(event) }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self, service?.isRecording == true else { return false }
            capture(event)
            return true
        }

        private func capture(_ event: NSEvent) {
            guard !event.isARepeat else { return }
            if event.keyCode == 53 { service?.cancelRecording() }
            else { service?.save(LauncherHotKey(event: event)) }
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5).fill()
            NSColor.controlAccentColor.setStroke()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5).stroke()
            let text = L10n.tr("Press shortcut…") as NSString
            text.draw(at: NSPoint(x: 10, y: (bounds.height - 16) / 2), withAttributes: [
                .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor
            ])
        }
    }
}
