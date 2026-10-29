import Foundation

@MainActor
final class ShortcutStore {
    private let dataStore: WebDockDataStore

    init(dataStore: WebDockDataStore) {
        self.dataStore = dataStore
    }

    @discardableResult
    func updateMetadata(
        _ shortcut: WebShortcut,
        name proposedName: String,
        normalizedURL rawURL: String,
        browserFamily: BrowserFamily?,
        targetAccountEmail: String?
    ) throws -> WebShortcut {
        let name = try validatedName(proposedName)
        let url = try validatedURL(rawURL)
        let email = browserFamily?.supportsAccountRouting == true
            ? normalizeAccountEmail(targetAccountEmail)
            : nil

        var updated = shortcut
        updated.displayName = name
        updated.normalizedURLString = url.absoluteString
        updated.preferredBrowserFamily = browserFamily
        updated.targetAccountEmail = email
        updated.updatedAt = Date()
        try dataStore.updateShortcut(updated)
        return updated
    }

    func move(shortcutID: UUID, before targetID: UUID?) throws {
        var shortcuts = dataStore.activeShortcuts
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

    func moveForDrop(shortcutID: UUID, onto targetID: UUID) throws {
        var shortcuts = dataStore.activeShortcuts
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

    /// Canonical deletions remain tombstones so a stale synced copy cannot
    /// resurrect a record when Synced Folder or WebDAV merges later.
    func delete(_ shortcut: WebShortcut) throws {
        var updated = shortcut
        let now = Date()
        updated.deletedAt = now
        updated.updatedAt = now
        try dataStore.updateShortcut(updated)
        try dataStore.removeDeviceBinding(for: shortcut.id)
    }

    func orderedActiveShortcuts() -> [WebShortcut] {
        dataStore.activeShortcuts
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

    private func persistOrder(_ shortcuts: [WebShortcut]) throws {
        let now = Date()
        let reordered = shortcuts.enumerated().map { index, shortcut -> WebShortcut in
            var updated = shortcut
            updated.sortIndex = Double(index)
            updated.updatedAt = now
            return updated
        }
        try dataStore.replaceShortcutOrder(reordered)
    }
}

enum ShortcutStoreError: LocalizedError {
    case emptyName
    case invalidURL
    case shortcutNotFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Shortcut names cannot be empty."
        case .invalidURL:
            "Enter a valid HTTP or HTTPS URL."
        case .shortcutNotFound:
            "The shortcut could not be found."
        }
    }
}
