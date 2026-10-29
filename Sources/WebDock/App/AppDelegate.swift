import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var launcherPanelController: LauncherPanelController?
    private var managerWindowController: ManagerWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            try bootstrapIfNeeded()
        } catch {
            presentFatalLaunchError(error)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try bootstrapIfNeeded()
            launcherPanelController?.showNearDock()
        } catch {
            presentFatalLaunchError(error)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        launcherPanelController?.toggleNearDock()
        return false
    }

    /// LaunchServices may deliver files before applicationDidFinishLaunching
    /// when a non-running app is opened by a document. Bootstrap defensively
    /// here as well so a Dock/Finder cold-start delivery is never discarded.
    func application(_ application: NSApplication, open urls: [URL]) {
        do {
            try bootstrapIfNeeded()
        } catch {
            presentFatalLaunchError(error)
            return
        }

        guard let importCoordinator = environment?.importCoordinator else { return }

        Task { @MainActor [weak self] in
            var failures: [(url: URL, message: String)] = []

            for url in urls {
                do {
                    try await importCoordinator.importItem(url)
                } catch {
                    failures.append((url, error.localizedDescription))
                }
            }

            self?.launcherPanelController?.showNearDock()

            guard !failures.isEmpty else { return }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = failures.count == 1
                ? "Shortcut Could Not Be Added"
                : "Some Shortcuts Could Not Be Added"
            alert.informativeText = failures.map { failure in
                let name = failure.url.lastPathComponent.isEmpty
                    ? failure.url.absoluteString
                    : failure.url.lastPathComponent
                return "• \(name): \(failure.message)"
            }
            .joined(separator: "\n")
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func bootstrapIfNeeded() throws {
        guard environment == nil else { return }

        let environment = try AppEnvironment()
        self.environment = environment

        let manager = ManagerWindowController(environment: environment)
        managerWindowController = manager

        launcherPanelController = LauncherPanelController(
            environment: environment,
            onOpenManager: { [weak self] in
                self?.launcherPanelController?.hide()
                self?.managerWindowController?.showManager()
            }
        )
    }

    private func presentFatalLaunchError(_ error: Error) {
        NSAlert(error: error).runModal()
        NSApp.terminate(nil)
    }
}
