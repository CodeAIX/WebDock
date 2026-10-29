import Foundation
import XCTest
@testable import WebDock

final class LocalizationTests: XCTestCase {
    func testSystemLanguageMatchingAndManualOverrides() {
        XCTAssertEqual(InterfaceLanguage.system.resolvedCode(preferredLanguages: ["zh-CN", "en"]), "zh-Hans")
        XCTAssertEqual(InterfaceLanguage.system.resolvedCode(preferredLanguages: ["zh-Hant-TW", "en"]), "zh-Hans")
        XCTAssertEqual(InterfaceLanguage.system.resolvedCode(preferredLanguages: ["fr", "en-GB", "zh-CN"]), "en")
        XCTAssertEqual(InterfaceLanguage.system.resolvedCode(preferredLanguages: ["ja", "de"]), "en")
        XCTAssertEqual(InterfaceLanguage.english.resolvedCode(preferredLanguages: ["zh-CN"]), "en")
        XCTAssertEqual(InterfaceLanguage.simplifiedChinese.resolvedCode(preferredLanguages: ["en"]), "zh-Hans")
    }

    func testBundledTranslationsAndPlaceholders() {
        XCTAssertEqual(L10n.localized("Search websites", languageCode: "zh-Hans"), "搜索网站")
        XCTAssertEqual(L10n.localized("Search websites", languageCode: "en"), "Search websites")
        XCTAssertEqual(L10n.localized("Untranslated test value", languageCode: "zh-Hans"), "Untranslated test value")
        let format = L10n.localized("Account %@ was not found in %@ on this Mac. Using the browser default profile.", languageCode: "zh-Hans")
        let message = String(format: format, "user@example.com", "Google Chrome")
        XCTAssertTrue(message.contains("Google Chrome 中未找到账号 user@example.com"))
    }

    func testDeviceWarningsTranslateWithoutChangingAccountOrProfileIdentity() throws {
        let original = "Account person+tag@example.com was not found in Google Chrome on this Mac. Using the browser default profile."
        let translated = L10n.translatedMessage(original, languageCode: "zh-Hans")
        XCTAssertEqual(translated, "此 Mac 的 Google Chrome 中未找到账号 person+tag@example.com，将使用浏览器默认配置。")
        XCTAssertEqual(L10n.translatedMessage(original, languageCode: "en"), original)
        let shortcut = WebShortcut(displayName: "My website", normalizedURLString: "https://example.com/", preferredBrowserFamily: .chrome, targetAccountEmail: "person+tag@example.com")
        let payload = try XCTUnwrap(String(data: try JSONEncoder().encode(shortcut), encoding: .utf8))
        XCTAssertTrue(payload.contains("person+tag@example.com"))
        XCTAssertEqual(shortcut.preferredBrowserFamilyRaw, "chrome")
    }

    func testLocalizedURLLabelCannotChangeChromiumRoutingPlistKeys() throws {
        XCTAssertEqual(L10n.localized("URL", languageCode: "zh-Hans"), "网址")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = try XCTUnwrap(URL(string: "https://example.com/path?account=demo"))
        let output = try ChromiumProfileShortcutWriter().writeShortcut(
            targetURL: target, profileDirectory: "Profile 12", shortcutID: UUID(), storageRoot: root)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: output), options: [], format: nil) as? [String: String])
        XCTAssertEqual(Set(plist.keys), ["URL", "CrProfile"])
        XCTAssertEqual(plist["URL"], target.absoluteString)
        XCTAssertEqual(plist["CrProfile"], "Profile 12")
        XCTAssertNil(plist["网址"])
    }

    @MainActor
    func testPreferencePersistsAndSystemRemovesOnlyAppOverride() throws {
        let suite = "WebDockLanguageTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let language = AppLanguage(defaults: defaults)
        XCTAssertEqual(language.preference, .system)
        language.preference = .simplifiedChinese
        XCTAssertEqual(defaults.string(forKey: L10n.preferenceKey), "zh-Hans")
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["zh-Hans"])
        XCTAssertEqual(AppLanguage(defaults: defaults).preference, .simplifiedChinese)
        language.preference = .english
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["en"])
        language.preference = .system
        XCTAssertNil(defaults.persistentDomain(forName: suite)?["AppleLanguages"])
    }
}
