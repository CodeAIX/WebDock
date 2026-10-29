import XCTest
@testable import WebDock

final class ChromeWeblocImporterTests: XCTestCase {
    func testParsesXMLURLAndChromeProfileFixture() async throws {
        let importer = ChromeWeblocImporter()
        let bundle = Bundle(for: Self.self)
        let fixture = try XCTUnwrap(
            bundle.url(
                forResource: "ChatGPT_Profile12",
                withExtension: "crwebloc",
                subdirectory: "Fixtures"
            ) ?? bundle.url(
                forResource: "ChatGPT_Profile12",
                withExtension: "crwebloc"
            )
        )

        let draft = try await importer.inspect(fixture)

        XCTAssertEqual(draft.url.absoluteString, "https://chatgpt.com/")
        XCTAssertEqual(draft.browserProfileHint, "Profile 12")
        XCTAssertEqual(draft.browserProfileDirectory, "Profile 12")
        XCTAssertEqual(draft.browserBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(draft.browserDisplayName, "Google Chrome")
        XCTAssertEqual(draft.sourceType, .chromeWebloc)
        XCTAssertEqual(draft.launchMode, .specifiedBrowser)
    }

    func testParsesBinaryPropertyList() async throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockBinaryFixture-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: directory) }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fixture = directory.appendingPathComponent("Research.crwebloc")
        let plist: [String: Any] = [
            "URL": "https://pubmed.ncbi.nlm.nih.gov/",
            "CrProfile": "Profile 3"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .binary,
            options: 0
        )
        try data.write(to: fixture)

        let draft = try await ChromeWeblocImporter().inspect(fixture)

        XCTAssertEqual(draft.displayName, "Research")
        XCTAssertEqual(draft.url.absoluteString, "https://pubmed.ncbi.nlm.nih.gov/")
        XCTAssertEqual(draft.browserProfileHint, "Profile 3")
        XCTAssertEqual(draft.browserProfileDirectory, "Profile 3")
        XCTAssertEqual(draft.browserBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(draft.sourceType, .chromeWebloc)
        XCTAssertEqual(draft.launchMode, .specifiedBrowser)
    }
}
