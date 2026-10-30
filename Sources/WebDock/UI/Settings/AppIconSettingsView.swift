import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppIconSettingsView: View {
    @ObservedObject private var language = AppLanguage.shared
    @ObservedObject var service: AppIconService
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: service.preview).resizable().scaledToFit().frame(width: 56, height: 56)
                .accessibilityLabel(L10n.tr("Application icon"))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(L10n.tr("Choose ICNS…")) { chooseIcon() }
                    Button(L10n.tr("Restore Default Icon")) { perform { try service.restoreDefault() } }
                        .disabled(!service.hasCustomIcon)
                }
                Text(L10n.tr("Customizes the running Dock and app-switcher icon and persists after restart. Finder keeps the installed app icon. This choice is local and is not synchronized."))
                    .font(.caption).foregroundStyle(.secondary)
                if let message = service.lastError {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .alert("WebDock", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(L10n.tr("OK"), role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "icns") ?? .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in perform { try service.chooseIcon(from: url) } }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() }
        catch { errorMessage = L10n.errorDescription(error) }
    }
}
