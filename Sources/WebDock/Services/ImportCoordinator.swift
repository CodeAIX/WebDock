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

        let draft = try await importer.inspect(sourceURL)

        // Starter implementation only. Replace with ImportTransaction before MVP:
        // inspect -> stage -> verify -> persist -> commit -> rollback on failure.
        let id = UUID()
        let destinationDirectory = managedStorage.directory(for: id)
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        let destination = destinationDirectory
            .appendingPathComponent("original")
            .appendingPathExtension(sourceURL.pathExtension)

        do {
            try FileManager.default.moveItem(at: sourceURL, to: destination)

            let shortcut = WebShortcut(
                id: id,
                displayName: draft.displayName,
                normalizedURLString: draft.url.absoluteString,
                sourceType: draft.sourceType,
                launchMode: draft.launchMode,
                sortIndex: Date().timeIntervalSince1970
            )
            shortcut.browserProfileHint = draft.browserProfileHint
            shortcut.managedFileRelativePath = "Shortcuts/\(id.uuidString)/\(destination.lastPathComponent)"

            modelContainer.mainContext.insert(shortcut)
            try modelContainer.mainContext.save()
        } catch {
            // Until ImportTransaction lands, make a best-effort rollback of the move.
            if FileManager.default.fileExists(atPath: destination.path),
               !FileManager.default.fileExists(atPath: sourceURL.path) {
                try? FileManager.default.moveItem(at: destination, to: sourceURL)
            }
            try? FileManager.default.removeItem(at: destinationDirectory)
            throw error
        }
    }
}
