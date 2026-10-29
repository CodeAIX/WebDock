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
        let name = try validatedName(proposedName)
        shortcut.displayName = name
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    func updateNormalizedURL(_ shortcut: WebShortcut, to rawValue: String) throws {
        guard shortcut.launchMode != .originalShortcutFile else {
            throw ShortcutStoreError.originalShortcutIsReadOnly
        }
        let url = try validatedURL(rawValue)

        shortcut.normalizedURLString = url.absoluteString
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    func setBrowserOverride(
        _ shortcut: WebShortcut,
        bundleIdentifier: String,
        displayName: String,
        profileDirectory: String? = nil,
        profileDisplayName: String? = nil,
        profileAccountEmail: String? = nil
    ) throws {
        guard shortcut.launchMode != .originalShortcutFile else {
            throw ShortcutStoreError.originalShortcutIsReadOnly
        }
        let browser = try validatedBrowser(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName
        )
        let profile = try validatedBrowserProfile(
            directory: profileDirectory,
            displayName: profileDisplayName,
            accountEmail: profileAccountEmail
        )

        shortcut.browserBundleIdentifier = browser.bundleIdentifier
        shortcut.browserDisplayName = browser.displayName
        shortcut.browserProfileDirectory = profile?.directory
        shortcut.browserProfileDisplayName = profile?.displayName
        shortcut.browserProfileAccountEmail = profile?.accountEmail
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
        shortcut.browserProfileDirectory = nil
        shortcut.browserProfileDisplayName = nil
        shortcut.browserProfileAccountEmail = nil
        shortcut.launchMode = .defaultBrowser
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    /// Atomically applies the fields editable in Manager. All values are
    /// validated before any model property is mutated, avoiding partial saves.
    func updateMetadata(
        _ shortcut: WebShortcut,
        name proposedName: String,
        normalizedURL rawURL: String,
        browserBundleIdentifier: String?,
        browserDisplayName: String?,
        browserProfileDirectory: String? = nil,
        browserProfileDisplayName: String? = nil,
        browserProfileAccountEmail: String? = nil
    ) throws {
        let name = try validatedName(proposedName)

        if shortcut.launchMode == .originalShortcutFile {
            guard browserBundleIdentifier == nil,
                  browserProfileDirectory == nil,
                  rawURL.trimmingCharacters(in: .whitespacesAndNewlines) == shortcut.normalizedURLString else {
                throw ShortcutStoreError.originalShortcutIsReadOnly
            }
            shortcut.displayName = name
            shortcut.updatedAt = Date()
            try saveOrRollback()
            return
        }

        let url = try validatedURL(rawURL)
        let browser: (bundleIdentifier: String, displayName: String)?
        let profile: (directory: String, displayName: String?, accountEmail: String?)?
        if let browserBundleIdentifier {
            browser = try validatedBrowser(
                bundleIdentifier: browserBundleIdentifier,
                displayName: browserDisplayName ?? browserBundleIdentifier
            )
            profile = try validatedBrowserProfile(
                directory: browserProfileDirectory,
                displayName: browserProfileDisplayName,
                accountEmail: browserProfileAccountEmail
            )
        } else {
            browser = nil
            profile = nil
        }

        shortcut.displayName = name
        shortcut.normalizedURLString = url.absoluteString
        shortcut.browserBundleIdentifier = browser?.bundleIdentifier
        shortcut.browserDisplayName = browser?.displayName
        shortcut.browserProfileDirectory = profile?.directory
        shortcut.browserProfileDisplayName = profile?.displayName
        shortcut.browserProfileAccountEmail = profile?.accountEmail
        shortcut.launchMode = browser == nil ? .defaultBrowser : .specifiedBrowser
        shortcut.updatedAt = Date()
        try saveOrRollback()
    }

    /// Moves one item immediately before another and normalizes all sort indexes.
    /// Passing nil as the target appends the item to the end.
    func move(shortcutID: UUID, before targetID: UUID?) throws {
        var shortcuts = try orderedShortcuts()
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
        try persistOrder(shortcuts)
    }

    /// Natural drag/drop behavior: dragging a preceding item onto a later item
    /// places it after that target; dragging backward places it before target.
    func moveForDrop(shortcutID: UUID, onto targetID: UUID) throws {
        var shortcuts = try orderedShortcuts()
        guard let sourceIndex = shortcuts.firstIndex(where: { $0.id == shortcutID }),
              let originalTargetIndex = shortcuts.firstIndex(where: { $0.id == targetID }) else {
            throw ShortcutStoreError.shortcutNotFound
        }
        guard sourceIndex != originalTargetIndex else { return }

        let moving = shortcuts.remove(at: sourceIndex)
        guard let targetIndex = shortcuts.firstIndex(where: { $0.id == targetID }) else {
            throw ShortcutStoreError.shortcutNotFound
        }
        let insertionIndex = sourceIndex < originalTargetIndex ? targetIndex + 1 : targetIndex
        shortcuts.insert(moving, at: insertionIndex)
        try persistOrder(shortcuts)
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

    private func validatedName(_ proposedName: String) throws -> String {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ShortcutStoreError.emptyName }
        return name
    }

    private func validatedURL(_ rawValue: String) throws -> URL {
        guard let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ShortcutStoreError.invalidURL
        }
        do {
            try validateWebURL(url)
            return url
        } catch {
            throw ShortcutStoreError.invalidURL
        }
    }

    private func validatedBrowser(
        bundleIdentifier: String,
        displayName: String
    ) throws -> (bundleIdentifier: String, displayName: String) {
        let bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleIdentifier.isEmpty else { throw ShortcutStoreError.missingBrowserIdentifier }
        let displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return (bundleIdentifier, displayName.isEmpty ? bundleIdentifier : displayName)
    }

    private func validatedBrowserProfile(
        directory: String?,
        displayName: String?,
        accountEmail: String?
    ) throws -> (directory: String, displayName: String?, accountEmail: String?)? {
        guard let directory else { return nil }
        let trimmed = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              !trimmed.contains("\0") else {
            throw ShortcutStoreError.invalidBrowserProfile
        }
        return (
            trimmed,
            normalizedOptionalText(displayName),
            normalizedOptionalText(accountEmail)
        )
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func orderedShortcuts() throws -> [WebShortcut] {
        try modelContainer.mainContext.fetch(
            FetchDescriptor<WebShortcut>(sortBy: [SortDescriptor(\WebShortcut.sortIndex)])
        )
    }

    private func persistOrder(_ shortcuts: [WebShortcut]) throws {
        let now = Date()
        for (index, shortcut) in shortcuts.enumerated() {
            shortcut.sortIndex = Double(index)
            shortcut.updatedAt = now
        }
        try saveOrRollback()
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
    case invalidBrowserProfile
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
        case .invalidBrowserProfile:
            "The selected browser profile is not valid."
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
