import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var launcherPanelController: LauncherPanelController?
    private var managerWindowController: ManagerWindowController?
    private var launcherVisibilityState = LauncherVisibilityState()

    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !isTestHost else { return }
        do {
            try bootstrapIfNeeded()
        } catch {
            presentFatalLaunchError(error)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isTestHost else { return }
        do {
            try bootstrapIfNeeded()
            if environment?.isValidation != true {
                try environment?.backupService.performAutomaticBackupIfNeeded()
                environment?.syncCoordinator.start()
            }
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

        let arguments = ProcessInfo.processInfo.arguments
        let validationIndex = arguments.firstIndex(of: "--validation-library")
        let root: URL? = validationIndex.flatMap { index in
            arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1], isDirectory: true) : nil
        }
        #if DEBUG
        let validationRoot = root ?? (Bundle.main.object(forInfoDictionaryKey: "WebDockValidationLibrary") as? String).map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
        #else
        let validationRoot = root
        #endif
        let environment = try AppEnvironment(rootURL: validationRoot, isValidation: validationRoot != nil)
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
