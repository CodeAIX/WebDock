import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var launcherPanelController: LauncherPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment()
            self.environment = environment
            launcherPanelController = LauncherPanelController(environment: environment)
            launcherPanelController?.showNearDock()
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        launcherPanelController?.toggleNearDock()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let importCoordinator = environment?.importCoordinator else { return }
        Task { @MainActor in
            for url in urls {
                do {
                    try await importCoordinator.importFile(url)
                } catch {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }
}
