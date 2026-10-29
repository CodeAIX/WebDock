import SwiftUI

@main
struct WebDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView()
        }
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Open Launcher") { appDelegate.openLauncher() }
                    .keyboardShortcut("1")
                Button("Open Library") { appDelegate.openLibrary() }
                    .keyboardShortcut("2")
            }
        }
    }
}

private struct SettingsRootView: View {
    @ObservedObject private var registry = AppEnvironmentRegistry.shared

    var body: some View {
        Group {
            if let environment = registry.environment {
                SettingsView(environment: environment)
            } else {
                ProgressView("Loading WebDock…")
                    .frame(width: 420, height: 220)
            }
        }
    }
}
