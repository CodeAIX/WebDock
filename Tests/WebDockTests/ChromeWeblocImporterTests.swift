import XCTest
@testable import WebDock

final class ChromeWeblocImporterTests: XCTestCase {
    func testParsesURLAndChromeProfile() async throws {
        let importer = ChromeWeblocImporter()
        let fixture = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "ChatGPT_Profile12",
                withExtension: "crwebloc",
                subdirectory: "Fixtures"
            )
        )

        let draft = try await importer.inspect(fixture)

        XCTAssertEqual(draft.url.absoluteString, "https://chatgpt.com/")
        XCTAssertEqual(draft.browserProfileHint, "Profile 12")
        XCTAssertEqual(draft.sourceType, .chromeWebloc)
        XCTAssertEqual(draft.launchMode, .originalShortcutFile)
    }
}
