import Combine
import Foundation

@MainActor
final class AppEnvironment {
    let libraryNavigation = LibraryNavigation()
    let isValidation: Bool
    let runtimeStorage: RuntimeStorage
    let dataStore: WebDockDataStore
    let backupService: BackupService
    let iconService: ShortcutIconService
    let shortcutLauncher: ShortcutLauncher
    let shortcutStore: ShortcutStore
    let shortcutCreationService: ShortcutCreationService
    let browserCatalog: BrowserCatalog
    let deviceBindingResolver: DeviceBindingResolver
    let syncCoordinator: SyncCoordinator

    init(rootURL: URL? = nil, isValidation: Bool = false) throws {
        self.isValidation = isValidation
        runtimeStorage = try RuntimeStorage(rootURL: rootURL)
        dataStore = try WebDockDataStore(rootURL: runtimeStorage.rootURL)
        backupService = try BackupService(dataStore: dataStore, automaticBackupsEnabled: !isValidation)
        iconService = try ShortcutIconService(dataStore: dataStore, backupService: backupService)
        browserCatalog = BrowserCatalog()
        shortcutLauncher = ShortcutLauncher()
        shortcutStore = ShortcutStore(dataStore: dataStore)
        shortcutCreationService = ShortcutCreationService(dataStore: dataStore)
        deviceBindingResolver = DeviceBindingResolver(
            dataStore: dataStore,
            browserCatalog: browserCatalog
        )
        syncCoordinator = SyncCoordinator(
            dataStore: dataStore,
            backupService: backupService,
            enabled: !isValidation
        )
    }
}

@MainActor
final class AppEnvironmentRegistry: ObservableObject {
    static let shared = AppEnvironmentRegistry()
    @Published var environment: AppEnvironment?
    private init() {}
}

@MainActor
final class LibraryNavigation: ObservableObject {
    @Published var shortcutID: UUID?
}
