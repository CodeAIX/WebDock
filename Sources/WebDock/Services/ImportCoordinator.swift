import Foundation
import SwiftData

@MainActor
final class ImportCoordinator {
    private let modelContainer: ModelContainer
    private let managedStorage: ManagedStorage
    private let importers: [any ShortcutImporter]
    private let fileTrasher: any FileTrashing

    init(
        modelContainer: ModelContainer,
        managedStorage: ManagedStorage,
        fileTrasher: (any FileTrashing)? = nil
    ) {
        self.modelContainer = modelContainer
        self.managedStorage = managedStorage
        self.fileTrasher = fileTrasher ?? SystemFileTrasher()
        self.importers = [
            ChromeWeblocImporter(),
            WeblocImporter(),
            InternetShortcutImporter(),
            URLImporter()
        ]
    }

    /// Imports all website shortcut formats into the same canonical WebShortcut
    /// representation. File inputs are parse-only sources: after the database
    /// commit succeeds they are moved to the macOS Trash and are never required
    /// again for launching.
    func importItem(_ inputURL: URL) async throws {
        guard let importer = importers.first(where: { $0.canImport(inputURL) }) else {
            throw ShortcutImportError.unsupported
        }

        let draft = try await importer.inspect(inputURL)
        let shortcut = makeShortcut(from: draft, id: UUID())
        let context = modelContainer.mainContext

        do {
            context.insert(shortcut)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        guard let sourceURL = draft.sourceFileURL else { return }

        do {
            try fileTrasher.trashItem(at: sourceURL)
        } catch {
            // The normalized database record is already valid and does not
            // depend on the source file. Keep both rather than rolling back a
            // successful import or risking source loss.
            throw ImportCoordinatorError.sourceCleanupPending(sourceURL)
        }
    }

    /// Compatibility entry point for existing callers.
    func importFile(_ sourceURL: URL) async throws {
        try await importItem(sourceURL)
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
        shortcut.browserBundleIdentifier = draft.browserBundleIdentifier
        shortcut.browserDisplayName = draft.browserDisplayName
        shortcut.browserProfileDirectory = draft.browserProfileDirectory
        shortcut.browserProfileHint = draft.browserProfileHint

        // New normalized imports intentionally do not retain a managed source
        // file. managedStorage remains injected for legacy records/migrations.
        shortcut.managedFileRelativePath = nil
        return shortcut
    }
}

enum ImportCoordinatorError: LocalizedError {
    case sourceCleanupPending(URL)

    var errorDescription: String? {
        switch self {
        case .sourceCleanupPending(let url):
            "The shortcut was imported successfully, but the original file could not be moved to Trash: \(url.path)"
        }
    }
}
