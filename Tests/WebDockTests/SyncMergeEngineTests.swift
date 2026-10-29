import Foundation
import XCTest
@testable import WebDock

final class SyncMergeEngineTests: XCTestCase {
    func testNewerRecordWinsPerShortcutUUID() {
        let id = UUID()
        let old = WebShortcut(
            id: id,
            displayName: "Old",
            normalizedURLString: "https://example.com/",
            preferredBrowserFamily: .chrome,
            targetAccountEmail: "user@example.com",
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newer = WebShortcut(
            id: id,
            displayName: "New",
            normalizedURLString: "https://example.com/new",
            preferredBrowserFamily: .chrome,
            targetAccountEmail: "user@example.com",
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let merged = SyncMergeEngine.merge(
            local: CanonicalSnapshot(
                shortcuts: [old],
                groups: [],
                generatedAt: Date(timeIntervalSince1970: 10)
            ),
            remote: CanonicalSnapshot(
                shortcuts: [newer],
                groups: [],
                generatedAt: Date(timeIntervalSince1970: 20)
            )
        )

        XCTAssertEqual(merged.shortcuts.count, 1)
        XCTAssertEqual(merged.shortcuts[0].displayName, "New")
        XCTAssertEqual(merged.shortcuts[0].normalizedURLString, "https://example.com/new")
    }

    func testSyncPayloadContainsEmailIdentityButNoProfileDirectory() throws {
        let shortcut = WebShortcut(
            displayName: "ChatGPT",
            normalizedURLString: "https://chatgpt.com/",
            preferredBrowserFamily: .chrome,
            targetAccountEmail: "user@example.com"
        )
        let snapshot = CanonicalSnapshot(
            shortcuts: [shortcut],
            groups: [],
            generatedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(text.contains("user@example.com"))
        XCTAssertTrue(text.contains("chrome"))
        XCTAssertFalse(text.contains("profileDirectory"))
        XCTAssertFalse(text.contains("Profile 12"))
    }

    func testTombstoneWinsWhenItIsNewer() {
        let id = UUID()
        let live = WebShortcut(
            id: id,
            displayName: "Live",
            normalizedURLString: "https://example.com/",
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let deletedAt = Date(timeIntervalSince1970: 20)
        let tombstone = WebShortcut(
            id: id,
            displayName: "Live",
            normalizedURLString: "https://example.com/",
            updatedAt: deletedAt,
            deletedAt: deletedAt
        )
        let merged = SyncMergeEngine.merge(
            local: CanonicalSnapshot(shortcuts: [live], groups: [], generatedAt: .distantPast),
            remote: CanonicalSnapshot(shortcuts: [tombstone], groups: [], generatedAt: .distantFuture)
        )
        XCTAssertEqual(merged.shortcuts.first?.deletedAt, deletedAt)
    }
}
