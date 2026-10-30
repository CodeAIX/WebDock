import SwiftUI

@main
struct WebDockApp: App {
    @ObservedObject private var language = AppLanguage.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView().modifier(WebDockAppearance())
        }
        .environment(\.locale, L10n.locale)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.tr("New Shortcut")) { appDelegate.newShortcut() }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .windowArrangement) {
                Button(L10n.tr("Open Launcher")) { appDelegate.openLauncher() }
                    .keyboardShortcut("1")
                Button(L10n.tr("Open Library")) { appDelegate.openLibrary() }
                    .keyboardShortcut("2")
            }
        }
    }
}

private struct SettingsRootView: View {
    @ObservedObject private var language = AppLanguage.shared
    @ObservedObject private var registry = AppEnvironmentRegistry.shared

    var body: some View {
        Group {
            if let environment = registry.environment {
                SettingsView(environment: environment)
            } else {
                ProgressView(L10n.tr("Loading WebDock…"))
                    .frame(width: 420, height: 220)
            }
        }
    }
}
