import XCTest
@testable import WebDock

final class URLImporterTests: XCTestCase {
    func testDirectHTTPSURLCreatesNormalizedDraftWithoutSourceFile() async throws {
        let importer = URLImporter()
        let url = try XCTUnwrap(URL(string: "https://example.com/path?q=1"))

        XCTAssertTrue(importer.canImport(url))
        let draft = try await importer.inspect(url)

        XCTAssertEqual(draft.displayName, "example.com")
        XCTAssertEqual(draft.url, url)
        XCTAssertEqual(draft.sourceType, .directURL)
        XCTAssertEqual(draft.launchMode, .defaultBrowser)
        XCTAssertNil(draft.sourceFileURL)
        XCTAssertNil(draft.browserProfileHint)
    }

    func testRejectsUnsafeSchemes() async throws {
        let importer = URLImporter()
        let javascript = try XCTUnwrap(URL(string: "javascript:alert(1)"))
        let file = URL(fileURLWithPath: "/tmp/example.webloc")

        XCTAssertFalse(importer.canImport(javascript))
        XCTAssertFalse(importer.canImport(file))
        await XCTAssertThrowsErrorAsync(try await importer.inspect(javascript)) { error in
            guard case ShortcutImportError.unsafeScheme = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
