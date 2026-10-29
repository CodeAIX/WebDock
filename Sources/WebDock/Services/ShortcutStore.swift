import AppKit
import Foundation
import SwiftData

protocol FileTrashing {
    func trashItem(at url: URL) throws
}

struct SystemFileTrasher: FileTrashing {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func trashItem(at url: URL) throws {
        var resultingURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
    }
}

@MainActor
final class ShortcutStore {
    private let modelContainer: ModelContainer
    private let managedStorage: ManagedStorage
    private let fileManager: FileManager
    private let fileTrasher: any FileTrashing

    init(
        modelContainer: ModelContainer,
        managedStorage: ManagedStorage,
        fileManager: FileManager = .default,
        fileTrasher: (any FileTrashing)? = nil
    ) {
        self.modelContainer = modelContainer
        self.managedStorage = managedStorage
        self.fileManager = fileManager
        self.fileTrasher = fileTrasher ?? SystemFileTrasher(fileManager: fileManager)
    }

    func rename(_ shortcut: WebShortcut, to proposedName: String) throws {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ShortcutStoreError.emptyName }

        shortcut.displayName = name
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    func updateNormalizedURL(_ shortcut: WebShortcut, to rawValue: String) throws {
        guard shortcut.launchMode != .originalShortcutFile else {
            throw ShortcutStoreError.originalShortcutIsReadOnly
        }
        guard let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ShortcutStoreError.invalidURL
        }

        do {
            try validateWebURL(url)
        } catch {
            throw ShortcutStoreError.invalidURL
        }

        shortcut.normalizedURLString = url.absoluteString
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    func setBrowserOverride(
        _ shortcut: WebShortcut,
        bundleIdentifier: String,
        displayName: String
    ) throws {
        guard shortcut.launchMode != .originalShortcutFile else {
            throw ShortcutStoreError.originalShortcutIsReadOnly
        }

        let bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleIdentifier.isEmpty else { throw ShortcutStoreError.missingBrowserIdentifier }

        shortcut.browserBundleIdentifier = bundleIdentifier
        shortcut.browserDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        shortcut.launchMode = .specifiedBrowser
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    func clearBrowserOverride(_ shortcut: WebShortcut) throws {
        guard shortcut.launchMode != .originalShortcutFile else {
            throw ShortcutStoreError.originalShortcutIsReadOnly
        }

        shortcut.browserBundleIdentifier = nil
        shortcut.browserDisplayName = nil
        shortcut.launchMode = .defaultBrowser
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    /// Moves one item immediately before another and normalizes all sort indexes.
    /// Passing nil as the target appends the item to the end.
    func move(shortcutID: UUID, before targetID: UUID?) throws {
        var shortcuts = try modelContainer.mainContext.fetch(
            FetchDescriptor<WebShortcut>(sortBy: [SortDescriptor(\WebShortcut.sortIndex)])
        )
        guard let sourceIndex = shortcuts.firstIndex(where: { $0.id == shortcutID }) else {
            throw ShortcutStoreError.shortcutNotFound
        }
        if targetID == shortcutID { return }

        let moving = shortcuts.remove(at: sourceIndex)
        if let targetID {
            guard let targetIndex = shortcuts.firstIndex(where: { $0.id == targetID }) else {
                throw ShortcutStoreError.shortcutNotFound
            }
            shortcuts.insert(moving, at: targetIndex)
        } else {
            shortcuts.append(moving)
        }

        let now = Date()
        for (index, shortcut) in shortcuts.enumerated() {
            shortcut.sortIndex = Double(index)
            shortcut.updatedAt = now
        }
        try saveOrRollback()
    }

    func managedSourceURL(for shortcut: WebShortcut) -> URL? {
        guard let relativePath = shortcut.managedFileRelativePath, !relativePath.isEmpty else {
            return nil
        }
        return managedStorage.rootURL.appendingPathComponent(relativePath)
    }

    func revealManagedSource(_ shortcut: WebShortcut) throws {
        guard let sourceURL = managedSourceURL(for: shortcut),
              fileManager.fileExists(atPath: sourceURL.path) else {
            throw ShortcutStoreError.managedSourceMissing
        }
        NSWorkspace.shared.activateFileViewerSelecting([sourceURL])
    }

    /// Deletes the database record only after any managed directory has been
    /// moved to a reversible staging location. After the database commit, that
    /// staging directory is handed to the macOS Trash rather than removed.
    func delete(_ shortcut: WebShortcut) throws {
        let context = modelContainer.mainContext
        let originalDirectory = managedStorage.directory(for: shortcut.id)
        let deletionStaging = managedStorage.deletionStagingDirectory(for: shortcut.id)
        let hasManagedDirectory = fileManager.fileExists(atPath: originalDirectory.path)

        if hasManagedDirectory {
            guard !fileManager.fileExists(atPath: deletionStaging.path) else {
                throw ShortcutStoreError.deletionStagingAlreadyExists(deletionStaging)
            }
            try fileManager.moveItem(at: originalDirectory, to: deletionStaging)
        }

        context.delete(shortcut)
        do {
            try context.save()
        } catch let databaseError {
            context.rollback()
            if hasManagedDirectory {
                do {
                    try fileManager.moveItem(at: deletionStaging, to: originalDirectory)
                } catch let restoreError {
                    throw ShortcutStoreError.deletionRollbackFailed(
                        databaseError: databaseError,
                        restoreError: restoreError,
                        recoverableURL: deletionStaging
                    )
                }
            }
            throw databaseError
        }

        guard hasManagedDirectory else { return }

        do {
            try fileTrasher.trashItem(at: deletionStaging)
        } catch {
            // The database record is already gone, but the files remain in a
            // known WebDock-owned recovery location. Do not permanently delete.
            throw ShortcutStoreError.trashCleanupPending(deletionStaging)
        }
    }

    private func saveOrRollback() throws {
        do {
            try modelContainer.mainContext.save()
        } catch {
            modelContainer.mainContext.rollback()
            throw error
        }
    }
}

enum ShortcutStoreError: LocalizedError {
    case emptyName
    case invalidURL
    case originalShortcutIsReadOnly
    case missingBrowserIdentifier
    case shortcutNotFound
    case managedSourceMissing
    case deletionStagingAlreadyExists(URL)
    case deletionRollbackFailed(databaseError: Error, restoreError: Error, recoverableURL: URL)
    case trashCleanupPending(URL)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Shortcut names cannot be empty."
        case .invalidURL:
            "Enter a valid HTTP or HTTPS URL."
        case .originalShortcutIsReadOnly:
            "This shortcut preserves its original browser/profile behavior, so its URL and browser cannot be overridden."
        case .missingBrowserIdentifier:
            "The selected browser does not have a valid bundle identifier."
        case .shortcutNotFound:
            "The shortcut could not be found."
        case .managedSourceMissing:
            "The managed shortcut file is missing."
        case .deletionStagingAlreadyExists(let url):
            "A previous deletion is still waiting for cleanup at \(url.path)."
        case .deletionRollbackFailed(_, _, let recoverableURL):
            "WebDock could not restore the managed files after a database error. They remain recoverable at \(recoverableURL.path)."
        case .trashCleanupPending(let url):
            "The shortcut was removed from WebDock, but its files could not be moved to Trash. They remain recoverable at \(url.path)."
        }
    }
}
