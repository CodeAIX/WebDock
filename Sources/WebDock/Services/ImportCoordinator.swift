import Foundation
import SwiftData

@MainActor
final class ImportCoordinator {
    private let modelContainer: ModelContainer
    private let managedStorage: ManagedStorage
    private let importers: [any ShortcutImporter]

    init(modelContainer: ModelContainer, managedStorage: ManagedStorage) {
        self.modelContainer = modelContainer
        self.managedStorage = managedStorage
        self.importers = [
            ChromeWeblocImporter(),
            WeblocImporter(),
            InternetShortcutImporter()
        ]
    }

    func importFile(_ sourceURL: URL) async throws {
        guard let importer = importers.first(where: { $0.canImport(sourceURL) }) else {
            throw ShortcutImportError.unsupported
        }

        // Inspect before touching the source. Unsupported, malformed, or unsafe
        // shortcuts therefore leave the user's file completely untouched.
        let originalDraft = try await importer.inspect(sourceURL)
        let id = UUID()
        var transaction = ImportTransaction(
            id: id,
            sourceURL: sourceURL,
            managedStorage: managedStorage
        )

        let context = modelContainer.mainContext
        var insertedShortcut: WebShortcut?

        do {
            let stagedURL = try transaction.stage()

            // Parse the staged copy as a second verification that the managed
            // bytes remain a valid shortcut, not merely byte-identical data.
            let stagedDraft = try await importer.inspect(stagedURL)
            guard stagedDraft.url == originalDraft.url,
                  stagedDraft.sourceType == originalDraft.sourceType,
                  stagedDraft.launchMode == originalDraft.launchMode,
                  stagedDraft.browserProfileHint == originalDraft.browserProfileHint else {
                throw ImportCoordinatorError.stagedMetadataMismatch
            }

            let installedURL = try transaction.install()
            guard let relativePath = managedStorage.relativePath(forManagedFile: installedURL) else {
                throw ImportCoordinatorError.invalidManagedPath
            }

            let shortcut = WebShortcut(
                id: id,
                displayName: originalDraft.displayName,
                normalizedURLString: originalDraft.url.absoluteString,
                sourceType: originalDraft.sourceType,
                launchMode: originalDraft.launchMode,
                sortIndex: Date().timeIntervalSince1970
            )
            shortcut.browserProfileHint = originalDraft.browserProfileHint
            shortcut.managedFileRelativePath = relativePath

            context.insert(shortcut)
            insertedShortcut = shortcut
            try context.save()

            do {
                // The source is removed only after both the managed file and
                // SwiftData record have been committed successfully.
                try transaction.consumeSource()
            } catch let sourceRemovalError {
                // If Finder/iCloud/etc. refuses source deletion, revert the
                // WebDock-side import and leave the source in place.
                context.delete(shortcut)
                do {
                    try context.save()
                } catch let rollbackError {
                    transaction.rollbackManagedArtifacts()
                    throw ImportCoordinatorError.databaseRollbackFailed(
                        importError: sourceRemovalError,
                        rollbackError: rollbackError
                    )
                }
                transaction.rollbackManagedArtifacts()
                throw sourceRemovalError
            }
        } catch {
            // Before source consumption, rollback never needs to recreate the
            // original because ImportTransaction deliberately leaves it alone.
            if let insertedShortcut {
                context.delete(insertedShortcut)
            }
            context.rollback()
            transaction.rollbackManagedArtifacts()
            throw error
        }
    }
}

enum ImportCoordinatorError: LocalizedError {
    case stagedMetadataMismatch
    case invalidManagedPath
    case databaseRollbackFailed(importError: Error, rollbackError: Error)

    var errorDescription: String? {
        switch self {
        case .stagedMetadataMismatch:
            "The staged shortcut metadata did not match the original."
        case .invalidManagedPath:
            "The shortcut could not be represented inside WebDock managed storage."
        case .databaseRollbackFailed:
            "WebDock could not roll back its database after an import failure."
        }
    }
}
