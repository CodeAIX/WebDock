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
            local: SyncSnapshot(
                shortcuts: [SyncedShortcutRecord(old)],
                groups: [],
                generatedAt: Date(timeIntervalSince1970: 10)
            ),
            remote: SyncSnapshot(
                shortcuts: [SyncedShortcutRecord(newer)],
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
        let snapshot = SyncSnapshot(
            shortcuts: [SyncedShortcutRecord(shortcut)],
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
}
