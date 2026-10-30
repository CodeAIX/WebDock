import AppKit
import XCTest
@testable import WebDock

@MainActor
final class AppIconServiceTests: XCTestCase {
    func testChoiceSurvivesRestartStaysOutOfPortableBackupAndResets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WebDockDataStore(rootURL: root)
        let fixture = try XCTUnwrap(Bundle.main.url(forResource: "WebDock", withExtension: "icns"))
        let adapter = RecordingIconApplier()
        let service = AppIconService(rootURL: root, applier: adapter)
        try service.chooseIcon(from: fixture)
        XCTAssertTrue(service.hasCustomIcon)
        XCTAssertEqual(adapter.applications, [true])
        let saved = root.appendingPathComponent("Appearance/CustomAppIcon.icns")
        XCTAssertEqual(try Data(contentsOf: saved), try Data(contentsOf: fixture))
        let restarted = AppIconService(rootURL: root, applier: adapter)
        restarted.applySavedIcon()
        XCTAssertTrue(restarted.hasCustomIcon)
        XCTAssertEqual(adapter.applications, [true, true])
        let backup = try BackupService(dataStore: store, automaticBackupsEnabled: false)
        let portable = root.appendingPathComponent("portable.webdockbackup")
        try backup.exportPortable(to: portable)
        let payload = try Data(contentsOf: portable)
        XCTAssertLessThan(payload.count, 4096)
        XCTAssertFalse(String(decoding: payload, as: UTF8.self).contains("CustomAppIcon"))
        try restarted.restoreDefault()
        XCTAssertFalse(restarted.hasCustomIcon)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))
        XCTAssertEqual(adapter.applications.last, false)
    }

    func testMalformedICNSCannotReplaceExistingChoice() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let adapter = RecordingIconApplier()
        let service = AppIconService(rootURL: root, applier: adapter)
        try service.chooseIcon(from: XCTUnwrap(Bundle.main.url(forResource: "WebDock", withExtension: "icns")))
        let saved = root.appendingPathComponent("Appearance/CustomAppIcon.icns")
        let original = try Data(contentsOf: saved)
        let invalid = root.appendingPathComponent("invalid.icns")
        try Data("icns-not-an-icon".utf8).write(to: invalid)
        XCTAssertThrowsError(try service.chooseIcon(from: invalid))
        XCTAssertEqual(try Data(contentsOf: saved), original)
        XCTAssertTrue(service.hasCustomIcon)
        XCTAssertEqual(adapter.applications, [true])
    }

    func testStorageFailureLeavesExistingFileAndRuntimeIconUntouched() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocked = root.appendingPathComponent("Appearance")
        let original = Data("keep this existing file".utf8)
        try original.write(to: blocked)
        let adapter = RecordingIconApplier()
        let service = AppIconService(rootURL: root, applier: adapter)
        XCTAssertThrowsError(try service.chooseIcon(from: XCTUnwrap(Bundle.main.url(forResource: "WebDock", withExtension: "icns"))))
        XCTAssertFalse(service.hasCustomIcon)
        XCTAssertEqual(try Data(contentsOf: blocked), original)
        XCTAssertTrue(adapter.applications.isEmpty)
    }
}

@MainActor
private final class RecordingIconApplier: AppIconApplying {
    var applications: [Bool] = []
    func apply(_ image: NSImage?) {
        applications.append(image != nil)
    }
}
