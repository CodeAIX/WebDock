import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let managedStorage: ManagedStorage
    let importCoordinator: ImportCoordinator
    let shortcutLauncher: ShortcutLauncher

    init() throws {
        modelContainer = try ModelContainer(for: WebShortcut.self, ShortcutGroup.self)
        managedStorage = try ManagedStorage()
        shortcutLauncher = ShortcutLauncher()
        importCoordinator = ImportCoordinator(
            modelContainer: modelContainer,
            managedStorage: managedStorage
        )
    }
}
