import Foundation
import SwiftData

@MainActor
final class ShortcutStore {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func updateMetadata(
        _ shortcut: WebShortcut,
        name proposedName: String,
        normalizedURL rawURL: String,
        browserFamily: BrowserFamily?,
        targetAccountEmail: String?
    ) throws {
        let name = try validatedName(proposedName)
        let url = try validatedURL(rawURL)
        let email = browserFamily?.supportsAccountRouting == true
            ? normalizeAccountEmail(targetAccountEmail)
            : nil

        shortcut.displayName = name
        shortcut.normalizedURLString = url.absoluteString
        shortcut.preferredBrowserFamily = browserFamily
        shortcut.targetAccountEmail = email
        shortcut.updatedAt = Date()
        try saveCanonicalChanges()
    }

    func move(shortcutID: UUID, before targetID: UUID?) throws {
        var shortcuts = try orderedActiveShortcuts()
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
        var shortcuts = try orderedActiveShortcuts()
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

    /// Canonical deletions are tombstoned so another offline Mac cannot revive
    /// a stale copy on its next synchronization.
    func delete(_ shortcut: WebShortcut) throws {
        let now = Date()
        shortcut.deletedAt = now
        shortcut.updatedAt = now

        let shortcutID = shortcut.id
        let bindingDescriptor = FetchDescriptor<DeviceShortcutBinding>(
            predicate: #Predicate<DeviceShortcutBinding> { binding in
                binding.shortcutID == shortcutID
            }
        )
        if let binding = try modelContainer.mainContext.fetch(bindingDescriptor).first {
            modelContainer.mainContext.delete(binding)
        }
        try saveCanonicalChanges()
    }

    func orderedActiveShortcuts() throws -> [WebShortcut] {
        try modelContainer.mainContext.fetch(
            FetchDescriptor<WebShortcut>(sortBy: [SortDescriptor(\WebShortcut.sortIndex)])
        )
        .filter { $0.deletedAt == nil }
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
        for (index, shortcut) in shortcuts.enumerated() {
            shortcut.sortIndex = Double(index)
            shortcut.updatedAt = now
        }
        try saveCanonicalChanges()
    }

    private func saveCanonicalChanges() throws {
        do {
            try modelContainer.mainContext.save()
            NotificationCenter.default.post(name: .webDockCanonicalDataDidChange, object: nil)
        } catch {
            modelContainer.mainContext.rollback()
            throw error
        }
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
