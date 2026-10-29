import Foundation

@MainActor
final class ShortcutStore {
    private let dataStore: WebDockDataStore

    init(dataStore: WebDockDataStore) {
        self.dataStore = dataStore
    }

    @discardableResult
    func updateMetadata(_ shortcut: WebShortcut, name: String, normalizedURL: String,
                        browserFamily: BrowserFamily?, targetAccountEmail: String?) throws -> WebShortcut {
        try updateMetadata(shortcut, name: name, normalizedURL: normalizedURL,
                           browserFamily: browserFamily, targetAccountEmail: targetAccountEmail,
                           groupID: (dataStore.shortcut(id: shortcut.id) ?? shortcut).groupID)
    }

    @discardableResult
    func updateMetadata(
        _ shortcut: WebShortcut,
        name proposedName: String,
        normalizedURL rawURL: String,
        browserFamily: BrowserFamily?,
        targetAccountEmail: String?,
        groupID: UUID?
    ) throws -> WebShortcut {
        let name = try validatedName(proposedName)
        let url = try validatedURL(rawURL)
        let email = browserFamily?.supportsAccountRouting == true
            ? normalizeAccountEmail(targetAccountEmail)
            : nil

        var updated = dataStore.shortcut(id: shortcut.id) ?? shortcut
        updated.displayName = name
        if updated.iconMode != "custom", URL(string: updated.normalizedURLString)?.host?.lowercased() != url.host?.lowercased() {
            updated.iconMode = nil; updated.iconAssetID = nil; updated.iconSourceURL = nil
        }
        updated.normalizedURLString = url.absoluteString
        updated.preferredBrowserFamily = browserFamily
        updated.targetAccountEmail = email
        updated.groupID = groupID
        updated.updatedAt = Date()
        try dataStore.updateShortcut(updated)
        return updated
    }

    @discardableResult
    func duplicate(_ shortcut: WebShortcut) throws -> WebShortcut {
        var copy = dataStore.shortcut(id: shortcut.id) ?? shortcut
        copy.id = UUID()
        copy.displayName += " Copy"
        copy.createdAt = Date()
        copy.updatedAt = copy.createdAt
        copy.deletedAt = nil
        copy.sortIndex = (dataStore.activeShortcuts.map(\.sortIndex).max() ?? -1) + 1
        try dataStore.insertShortcut(copy)
        return copy
    }

    @discardableResult
    func createGroup(name: String) throws -> ShortcutGroup {
        let group = ShortcutGroup(name: try validatedName(name), sortIndex: Double(dataStore.activeGroups.count))
        try dataStore.upsertGroup(group)
        return group
    }

    func setGroup(_ groupID: UUID?, for shortcut: WebShortcut) throws {
        var updated = dataStore.shortcut(id: shortcut.id) ?? shortcut
        updated.groupID = groupID
        updated.updatedAt = Date()
        try dataStore.updateShortcut(updated)
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
        var updated = dataStore.shortcut(id: shortcut.id) ?? shortcut
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
            var updated = dataStore.shortcut(id: shortcut.id) ?? shortcut
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
            L10n.tr("Shortcut names cannot be empty.")
        case .invalidURL:
            L10n.tr("Enter a valid HTTP or HTTPS URL.")
        case .shortcutNotFound:
            L10n.tr("The shortcut could not be found.")
        }
    }
}
