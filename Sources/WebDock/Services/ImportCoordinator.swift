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
        let shortcut: WebShortcut

        // Phase 1: create and verify WebDock-owned state while preserving source.
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

            shortcut = WebShortcut(
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
            try context.save()
        } catch {
            context.rollback()
            transaction.rollbackManagedArtifacts()
            throw error
        }

        // Phase 2: consume the original only after file + database commit.
        do {
            try transaction.consumeSource()
        } catch let sourceRemovalError {
            // Source still exists here. Prefer reverting the WebDock import.
            context.delete(shortcut)
            do {
                try context.save()
                transaction.rollbackManagedArtifacts()
                throw sourceRemovalError
            } catch let rollbackError {
                // If the database rollback itself fails, keep the verified
                // managed copy. This may leave a duplicate source file, but
                // never a database record pointing to a deleted managed file.
                context.rollback()
                throw ImportCoordinatorError.databaseRollbackFailed(
                    importError: sourceRemovalError,
                    rollbackError: rollbackError
                )
            }
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
            "WebDock could not roll back its database after an import failure. The original and managed copy were both preserved."
        }
    }
}
