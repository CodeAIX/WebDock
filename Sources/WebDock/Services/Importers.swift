import Foundation

struct ImportedShortcutDraft: Sendable {
    let displayName: String
    let url: URL
    let sourceType: ShortcutSourceType
    let launchMode: ShortcutLaunchMode
    let browserBundleIdentifier: String?
    let browserDisplayName: String?
    let browserProfileDirectory: String?
    let browserProfileHint: String?
    let sourceFileURL: URL?
}

protocol ShortcutImporter: Sendable {
    func canImport(_ url: URL) -> Bool
    func inspect(_ url: URL) async throws -> ImportedShortcutDraft
}

enum ShortcutImportError: LocalizedError {
    case unsupported
    case malformedFile
    case missingURL
    case missingChromeProfile
    case unsafeScheme

    var errorDescription: String? {
        switch self {
        case .unsupported: "Unsupported shortcut type."
        case .malformedFile: "The shortcut file could not be parsed."
        case .missingURL: "The shortcut does not contain a valid URL."
        case .missingChromeProfile: "The Chrome shortcut is missing CrProfile."
        case .unsafeScheme: "Only HTTP and HTTPS URLs are allowed."
        }
    }
}

@discardableResult
func validateWebURL(_ url: URL) throws -> URL {
    guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
        throw ShortcutImportError.unsafeScheme
    }
    return url
}

/// Treats Chrome `.crwebloc` as an import format. The original file is no
/// longer the canonical launch object for new imports: URL + Chrome profile are
/// normalized into editable WebShortcut fields and the launch service can
/// recreate the small routing plist when needed.
struct ChromeWeblocImporter: ShortcutImporter {
    func canImport(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == "crwebloc"
    }

    func inspect(_ url: URL) async throws -> ImportedShortcutDraft {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        ) as? [String: Any] else {
            throw ShortcutImportError.malformedFile
        }
        guard let rawURL = plist["URL"] as? String,
              let target = URL(string: rawURL) else {
            throw ShortcutImportError.missingURL
        }
        try validateWebURL(target)
        guard let rawProfile = plist["CrProfile"] as? String else {
            throw ShortcutImportError.missingChromeProfile
        }
        let profile = rawProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profile.isEmpty else {
            throw ShortcutImportError.missingChromeProfile
        }

        return ImportedShortcutDraft(
            displayName: url.deletingPathExtension().lastPathComponent,
            url: target,
            sourceType: .chromeWebloc,
            launchMode: .specifiedBrowser,
            browserBundleIdentifier: "com.google.Chrome",
            browserDisplayName: "Google Chrome",
            browserProfileDirectory: profile,
            browserProfileHint: profile,
            sourceFileURL: url
        )
    }
}

struct WeblocImporter: ShortcutImporter {
    func canImport(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == "webloc"
    }

    func inspect(_ url: URL) async throws -> ImportedShortcutDraft {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        ) as? [String: Any] else {
            throw ShortcutImportError.malformedFile
        }
        guard let rawURL = plist["URL"] as? String,
              let target = URL(string: rawURL) else {
            throw ShortcutImportError.missingURL
        }
        try validateWebURL(target)
        return ImportedShortcutDraft(
            displayName: url.deletingPathExtension().lastPathComponent,
            url: target,
            sourceType: .webLoc,
            launchMode: .defaultBrowser,
            browserBundleIdentifier: nil,
            browserDisplayName: nil,
            browserProfileDirectory: nil,
            browserProfileHint: nil,
            sourceFileURL: url
        )
    }
}

struct InternetShortcutImporter: ShortcutImporter {
    func canImport(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == "url"
    }

    func inspect(_ url: URL) async throws -> ImportedShortcutDraft {
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .unicode)
        guard let text else { throw ShortcutImportError.malformedFile }

        guard let line = text.split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("url=") }),
              let equals = line.firstIndex(of: "=") else {
            throw ShortcutImportError.missingURL
        }

        let rawURL = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let target = URL(string: rawURL) else { throw ShortcutImportError.missingURL }
        try validateWebURL(target)

        return ImportedShortcutDraft(
            displayName: url.deletingPathExtension().lastPathComponent,
            url: target,
            sourceType: .internetShortcut,
            launchMode: .defaultBrowser,
            browserBundleIdentifier: nil,
            browserDisplayName: nil,
            browserProfileDirectory: nil,
            browserProfileHint: nil,
            sourceFileURL: url
        )
    }
}

/// Imports an HTTP(S) URL directly without creating or consuming a Finder file.
/// This is used when a URL is dragged to WebDock or is added from the manager UI.
struct URLImporter: ShortcutImporter {
    func canImport(_ url: URL) -> Bool {
        guard !url.isFileURL, let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    func inspect(_ url: URL) async throws -> ImportedShortcutDraft {
        let target = try validateWebURL(url)
        let name = target.host(percentEncoded: false)
            ?? target.host
            ?? target.absoluteString

        return ImportedShortcutDraft(
            displayName: name,
            url: target,
            sourceType: .directURL,
            launchMode: .defaultBrowser,
            browserBundleIdentifier: nil,
            browserDisplayName: nil,
            browserProfileDirectory: nil,
            browserProfileHint: nil,
            sourceFileURL: nil
        )
    }
}
