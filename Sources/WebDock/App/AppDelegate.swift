import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var launcherPanelController: LauncherPanelController?
    private var managerWindowController: ManagerWindowController?
    private var launcherVisibilityState = LauncherVisibilityState()

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
            try environment?.backupService.performAutomaticBackupIfNeeded()
            environment?.syncCoordinator.start()
            launcherVisibilityState.cancelPendingShow()
            launcherPanelController?.showNearDock()
        } catch {
            presentFatalLaunchError(error)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        servicePendingLauncherShowOnNextRunLoop()
    }

    func applicationDidResignActive(_ notification: Notification) {
        applyLauncherAction(launcherVisibilityState.handleDidResignActive())
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard let launcherPanelController else { return false }

        let action = launcherVisibilityState.handleDockReopen(
            isLauncherVisible: launcherPanelController.isVisible
        )
        applyLauncherAction(action)
        servicePendingLauncherShowOnNextRunLoop()
        return false
    }

    func openLauncher() {
        launcherVisibilityState.cancelPendingShow()
        launcherPanelController?.showNearDock()
    }

    func openLibrary() {
        launcherVisibilityState.cancelPendingShow()
        launcherPanelController?.hide()
        managerWindowController?.showManager()
    }

    private func servicePendingLauncherShowOnNextRunLoop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.launcherVisibilityState.consumePendingShowIfActive(NSApp.isActive) else {
                return
            }
            self.launcherPanelController?.showNearDock()
        }
    }

    private func applyLauncherAction(_ action: LauncherVisibilityState.Action) {
        switch action {
        case .none:
            break
        case .hide:
            launcherPanelController?.hide()
        }
    }

    private func bootstrapIfNeeded() throws {
        guard environment == nil else { return }

        let environment = try AppEnvironment()
        self.environment = environment
        AppEnvironmentRegistry.shared.environment = environment

        let manager = ManagerWindowController(environment: environment)
        managerWindowController = manager

        launcherPanelController = LauncherPanelController(
            environment: environment,
            onOpenManager: { [weak self] in
                self?.openLibrary()
            },
            onPrepareSettings: { [weak self] in
                self?.launcherVisibilityState.cancelPendingShow()
                self?.launcherPanelController?.hide()
            }
        )
    }

    private func presentFatalLaunchError(_ error: Error) {
        NSAlert(error: error).runModal()
        NSApp.terminate(nil)
    }
}
