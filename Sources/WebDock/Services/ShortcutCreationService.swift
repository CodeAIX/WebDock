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
        browser: BrowserOption?,
        profile: BrowserProfileOption?
    ) throws -> WebShortcut {
        let url = try validatedURL(rawURL)
        let name = resolvedName(proposedName, url: url)

        if let profile {
            guard let browser,
                  profile.browserBundleIdentifier == browser.bundleIdentifier else {
                throw ShortcutCreationError.profileBrowserMismatch
            }
        }

        let shortcut = WebShortcut(
            displayName: name,
            normalizedURLString: url.absoluteString,
            sourceType: .directURL,
            launchMode: browser == nil ? .defaultBrowser : .specifiedBrowser,
            sortIndex: Date().timeIntervalSince1970
        )

        shortcut.browserBundleIdentifier = browser?.bundleIdentifier
        shortcut.browserDisplayName = browser?.displayName
        shortcut.browserProfileDirectory = profile?.profileDirectory
        shortcut.browserProfileDisplayName = profile?.accountDisplayName ?? profile?.localProfileName
        shortcut.browserProfileAccountEmail = profile?.accountEmail

        let context = modelContainer.mainContext
        do {
            context.insert(shortcut)
            try context.save()
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
    case profileBrowserMismatch

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter a valid HTTP or HTTPS URL."
        case .profileBrowserMismatch:
            "The selected profile does not belong to the selected browser."
        }
    }
}
