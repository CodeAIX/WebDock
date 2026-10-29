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
            InternetShortcutImporter(),
            URLImporter()
        ]
    }

    /// Imports either a managed shortcut file or a direct HTTP(S) URL.
    /// File-backed inputs use the full source-preserving transaction. Direct
    /// URLs have no user-owned source file and only require a database commit.
    func importItem(_ inputURL: URL) async throws {
        guard let importer = importers.first(where: { $0.canImport(inputURL) }) else {
            throw ShortcutImportError.unsupported
        }

        let originalDraft = try await importer.inspect(inputURL)
        if originalDraft.sourceFileURL == nil {
            try persistDirectDraft(originalDraft)
            return
        }

        try await importFileDraft(originalDraft, sourceURL: inputURL, using: importer)
    }

    /// Compatibility entry point for existing callers. Despite the historical
    /// name it also accepts direct HTTP(S) URLs; new code should use importItem.
    func importFile(_ sourceURL: URL) async throws {
        try await importItem(sourceURL)
    }

    private func persistDirectDraft(_ draft: ImportedShortcutDraft) throws {
        let context = modelContainer.mainContext
        let shortcut = makeShortcut(from: draft, id: UUID())

        do {
            context.insert(shortcut)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func importFileDraft(
        _ originalDraft: ImportedShortcutDraft,
        sourceURL: URL,
        using importer: any ShortcutImporter
    ) async throws {
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

            shortcut = makeShortcut(from: originalDraft, id: id)
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

            transaction.rollbackManagedArtifacts()
            throw sourceRemovalError
        }
    }

    private func makeShortcut(from draft: ImportedShortcutDraft, id: UUID) -> WebShortcut {
        let shortcut = WebShortcut(
            id: id,
            displayName: draft.displayName,
            normalizedURLString: draft.url.absoluteString,
            sourceType: draft.sourceType,
            launchMode: draft.launchMode,
            sortIndex: Date().timeIntervalSince1970
        )
        shortcut.browserProfileHint = draft.browserProfileHint
        return shortcut
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
