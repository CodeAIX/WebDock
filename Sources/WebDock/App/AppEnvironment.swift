import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let runtimeStorage: RuntimeStorage
    let shortcutLauncher: ShortcutLauncher
    let shortcutStore: ShortcutStore
    let shortcutCreationService: ShortcutCreationService
    let browserCatalog: BrowserCatalog
    let deviceBindingResolver: DeviceBindingResolver
    let syncCoordinator: SyncCoordinator

    init() throws {
        // This is an intentional clean break from the import-era schema. The
        // previous data was test-only, so M9 starts with a fresh named store
        // rather than carrying migration-only fields into the new model.
        let configuration = ModelConfiguration(
            "WebDockManualFirstV1",
            cloudKitDatabase: .none
        )
        modelContainer = try ModelContainer(
            for: WebShortcut.self,
            ShortcutGroup.self,
            DeviceShortcutBinding.self,
            configurations: configuration
        )

        runtimeStorage = try RuntimeStorage()
        browserCatalog = BrowserCatalog()
        shortcutLauncher = ShortcutLauncher()
        shortcutStore = ShortcutStore(modelContainer: modelContainer)
        shortcutCreationService = ShortcutCreationService(modelContainer: modelContainer)
        deviceBindingResolver = DeviceBindingResolver(
            modelContainer: modelContainer,
            browserCatalog: browserCatalog
        )
        syncCoordinator = SyncCoordinator(modelContainer: modelContainer)
    }
}
