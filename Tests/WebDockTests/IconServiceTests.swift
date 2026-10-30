import AppKit
import XCTest
@testable import WebDock

final class IconServiceTests: XCTestCase {
    func testMetadataDiscoveryResolvesRelativeLinksAndPrioritizesSources() throws {
        let base = try XCTUnwrap(URL(string: "https://example.com/page/"))
        let html = """
        <link sizes='16x16' href='/favicon.ico' rel='shortcut icon'>
        <link REL="apple-touch-icon" href="../apple.png">
        <link rel=manifest href=/site.webmanifest>
        <link rel=icon sizes=256x256 href=large.png>
        <link rel=icon href='file:///tmp/no.png'>
        """
        let links = WebIconDiscovery.links(in: html, baseURL: base)
        XCTAssertEqual(links.icons.map(\.url.absoluteString), ["https://example.com/apple.png", "https://example.com/page/large.png", "https://example.com/favicon.ico"])
        XCTAssertEqual(links.manifests.first?.absoluteString, "https://example.com/site.webmanifest")
        let manifest = Data(#"{"icons":[{"src":"/512.png","sizes":"512x512"},{"src":"/192.png","sizes":"192x192"}]}"#.utf8)
        XCTAssertEqual(WebIconDiscovery.manifestIcons(manifest, baseURL: base).first?.url.absoluteString, "https://example.com/512.png")
    }

    @MainActor
    func testAssetNormalizationRejectsTraversalAndCorruption() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try IconAssetStore(rootURL: root)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let id = try store.importImage(png)
        XCTAssertTrue(IconAssetStore.validID(id))
        XCTAssertNotNil(store.image(for: id))
        XCTAssertThrowsError(try store.url(for: "../../secret"))
        XCTAssertThrowsError(try store.install(Data("bad".utf8), id: id))
        XCTAssertThrowsError(try store.importImage(Data("bad".utf8)))
    }

    func testOldShortcutDecodesWithoutIconFields() throws {
        let shortcut = WebShortcut(displayName: "Legacy", normalizedURLString: "https://example.com/")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(shortcut)
        XCTAssertNil(try decoder.decode(WebShortcut.self, from: data).iconAssetID)
        XCTAssertEqual(shortcut.displaySubtitle, "example.com")
    }
}
