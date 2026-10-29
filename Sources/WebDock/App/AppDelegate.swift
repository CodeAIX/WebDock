import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var launcherPanelController: LauncherPanelController?
    private var managerWindowController: ManagerWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
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

    /// LaunchServices calls this for Finder/Open/Dock-delivered documents.
    /// Import sequentially so each shortcut completes its transaction before
    /// the next source file is touched. Failures are summarized after the batch
    /// rather than interrupting subsequent imports with one modal per file.
    func application(_ application: NSApplication, open urls: [URL]) {
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
}
