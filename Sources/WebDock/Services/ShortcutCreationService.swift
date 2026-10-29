import Foundation
import SwiftData

@MainActor
final class ShortcutCreationService {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
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
            sortIndex: Date().timeIntervalSince1970
        )

        let context = modelContainer.mainContext
        do {
            context.insert(shortcut)
            try context.save()
            NotificationCenter.default.post(name: .webDockCanonicalDataDidChange, object: nil)
            return shortcut
        } catch {
            context.rollback()
            throw error
        }
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
        return url.host(percentEncoded: false)
            ?? url.host
            ?? url.absoluteString
    }
}

enum ShortcutCreationError: LocalizedError, Equatable {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter a valid HTTP or HTTPS URL."
        }
    }
}
