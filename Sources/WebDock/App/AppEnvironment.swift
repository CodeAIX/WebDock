import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let managedStorage: ManagedStorage
    let importCoordinator: ImportCoordinator
    let shortcutLauncher: ShortcutLauncher
    let shortcutStore: ShortcutStore
    let shortcutCreationService: ShortcutCreationService
    let browserCatalog: BrowserCatalog

    init() throws {
        modelContainer = try ModelContainer(for: WebShortcut.self, ShortcutGroup.self)
        managedStorage = try ManagedStorage()
        shortcutLauncher = ShortcutLauncher()
        shortcutStore = ShortcutStore(
            modelContainer: modelContainer,
            managedStorage: managedStorage
        )
        shortcutCreationService = ShortcutCreationService(modelContainer: modelContainer)
        browserCatalog = BrowserCatalog()
        importCoordinator = ImportCoordinator(
            modelContainer: modelContainer,
            managedStorage: managedStorage
        )
    }
}
