import AppKit
import Combine
import Foundation
import SwiftUI

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", simplifiedChinese = "zh-Hans"
    var id: String { rawValue }

    func resolvedCode(preferredLanguages: [String]) -> String {
        guard self == .system else { return rawValue }
        for language in preferredLanguages {
            let base = language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            if base == "zh" { return "zh-Hans" }
            if base == "en" { return "en" }
        }
        return "en"
    }
}

enum L10n {
    static let preferenceKey = "WebDock.interfaceLanguage"

    static var systemLanguages: [String] {
        // Read the global preference, not the app's manual AppleLanguages override.
        (UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String])
            ?? Locale.preferredLanguages
    }

    static var languageCode: String {
        let preference = InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "system") ?? .system
        return preference.resolvedCode(preferredLanguages: systemLanguages)
    }

    static var locale: Locale { Locale(identifier: languageCode) }

    static func localized(_ key: String, languageCode: String, bundle: Bundle = .main) -> String {
        guard let path = bundle.path(forResource: languageCode, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else { return key }
        return languageBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let value = localized(key, languageCode: languageCode)
        return arguments.isEmpty ? value : String(format: value, locale: locale, arguments: arguments)
    }

    /// Keep persisted device warnings in their original form; translate only at presentation time.
    static func message(_ original: String) -> String {
        translatedMessage(original, languageCode: languageCode)
    }

    static func translatedMessage(_ original: String, languageCode: String) -> String {
        let direct = localized(original, languageCode: languageCode)
        guard direct == original, languageCode != "en" else { return direct }
        for template in warningTemplates {
            let parts = template.components(separatedBy: "%@")
            let pattern = "^" + parts.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "(.+?)") + "$"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: original, range: NSRange(original.startIndex..., in: original)) else { continue }
            let arguments = (1..<match.numberOfRanges).map { (original as NSString).substring(with: match.range(at: $0)) }
            return String(format: localized(template, languageCode: languageCode), locale: Locale(identifier: languageCode), arguments: arguments)
        }
        return original
    }

    static func errorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch URLError.Code(rawValue: nsError.code) {
            case .notConnectedToInternet: return tr("There is no internet connection.")
            case .timedOut: return tr("The network request timed out. Try again.")
            case .cannotFindHost, .cannotConnectToHost: return tr("Cannot connect to the server. Check the address and connection.")
            case .userAuthenticationRequired: return tr("The server requires authentication. Check the saved credentials.")
            default: return tr("Network error (%ld): %@", nsError.code, nsError.localizedDescription)
            }
        }
        if nsError.domain == NSCocoaErrorDomain {
            switch CocoaError.Code(rawValue: nsError.code) {
            case .fileReadNoPermission, .fileWriteNoPermission: return tr("WebDock does not have permission to access this file or folder.")
            case .fileReadNoSuchFile: return tr("The file or folder could not be found.")
            default: break
            }
        }
        return message(error.localizedDescription)
    }

    private static let warningTemplates = [
        "Preferred browser %@ is not installed on this Mac. Using the system default browser.",
        "%@ does not expose a profile for %@ on this Mac. Using the browser default profile.",
        "Account %@ was not found in %@ on this Mac. Using the browser default profile.",
        "Account %@ exists in more than one local profile. Using the browser default until you choose a profile for this Mac."
    ]
}

@MainActor
final class AppLanguage: ObservableObject {
    static let shared = AppLanguage()
    @Published var preference: InterfaceLanguage {
        didSet {
            defaults.set(preference.rawValue, forKey: L10n.preferenceKey)
            if preference == .system { defaults.removeObject(forKey: "AppleLanguages") }
            else { defaults.set([preference.rawValue], forKey: "AppleLanguages") }
        }
    }
    private let defaults: UserDefaults
    private var localeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preference = InterfaceLanguage(rawValue: defaults.string(forKey: L10n.preferenceKey) ?? "system") ?? .system
        localeObserver = NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.preference == .system else { return }
                self.objectWillChange.send()
            }
        }
    }
    deinit { if let localeObserver { NotificationCenter.default.removeObserver(localeObserver) } }
}

struct LanguageSettingsView: View {
    @ObservedObject private var language = AppLanguage.shared
    var body: some View {
        Picker(L10n.tr("Display Language"), selection: $language.preference) {
            Text(L10n.tr("Follow System")).tag(InterfaceLanguage.system)
            Text(verbatim: "简体中文").tag(InterfaceLanguage.simplifiedChinese)
            Text(verbatim: "English").tag(InterfaceLanguage.english)
        }
        Text(L10n.tr("App content changes immediately. Restart WebDock to fully update macOS menus and system dialogs."))
            .font(.caption).foregroundStyle(.secondary)
    }
}

