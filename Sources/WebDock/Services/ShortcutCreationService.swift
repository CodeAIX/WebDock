import Foundation

@MainActor
final class ShortcutCreationService {
    private let dataStore: WebDockDataStore

    init(dataStore: WebDockDataStore) {
        self.dataStore = dataStore
    }

    @discardableResult
    func create(
        name proposedName: String,
        url rawURL: String,
        browserFamily: BrowserFamily?,
        targetAccountEmail: String?
    ) throws -> WebShortcut {
        let url = try validatedURL(rawURL)
        let name = resolvedName(proposedName, url: url)
        let accountEmail = browserFamily?.supportsAccountRouting == true
            ? normalizeAccountEmail(targetAccountEmail)
            : nil

        let shortcut = WebShortcut(
            displayName: name,
            normalizedURLString: url.absoluteString,
            preferredBrowserFamily: browserFamily,
            targetAccountEmail: accountEmail,
            sortIndex: (dataStore.activeShortcuts.map(\.sortIndex).max() ?? -1) + 1
        )
        try dataStore.insertShortcut(shortcut)
        return shortcut
    }

    private func validatedURL(_ rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw ShortcutCreationError.invalidURL
        }
        do {
            try validateWebURL(url)
            return url
        } catch {
            throw ShortcutCreationError.invalidURL
        }
    }

    private func resolvedName(_ proposedName: String, url: URL) -> String {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return url.host ?? url.absoluteString
    }
}

enum ShortcutCreationError: LocalizedError, Equatable {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            L10n.tr("Enter a valid HTTP or HTTPS URL.")
        }
    }
}
