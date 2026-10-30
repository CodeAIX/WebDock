import AppKit
import XCTest
@testable import WebDock

final class PortableIconTests: XCTestCase {
    @MainActor
    func testCustomIconRoundTripsBackupAndFolderWithoutDeviceIdentity() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try WebDockDataStore(rootURL: root.appendingPathComponent("A"))
        let destination = try WebDockDataStore(rootURL: root.appendingPathComponent("B"))
        let assets = try IconAssetStore(rootURL: source.rootURL)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let id = try assets.importImage(XCTUnwrap(bitmap.representation(using: .png, properties: [:])))
        var shortcut = WebShortcut(displayName: "Icon", normalizedURLString: "https://example.com/", targetAccountEmail: "a@example.com")
        shortcut.iconMode = "custom"
        shortcut.iconAssetID = id
        try source.insertShortcut(shortcut)
        var binding = DeviceShortcutBinding(shortcutID: shortcut.id)
        binding.overrideProfileDirectory = "Profile 12"
        try source.upsertDeviceBinding(binding)
        let backup = try BackupService(dataStore: source)
        let url = root.appendingPathComponent("portable.webdockbackup")
        try backup.exportPortable(to: url)
        XCTAssertFalse(try String(contentsOf: url).contains("Profile 12"))
        let targetBackup = try BackupService(dataStore: destination)
        try targetBackup.restore(from: url, mode: .replace)
        XCTAssertEqual(destination.activeShortcuts.first?.iconAssetID, id)
        XCTAssertNotNil(try IconAssetStore(rootURL: destination.rootURL).image(for: id))
        XCTAssertTrue(destination.deviceBindings.isEmpty)
        XCTAssertFalse(try String(contentsOf: destination.canonicalURL).contains("iconAssets"))
        let other = WebShortcut(displayName: "Keep Local", normalizedURLString: "https://local.example/")
        try destination.insertShortcut(other)
        try targetBackup.restore(from: url, mode: .merge)
        XCTAssertEqual(destination.activeShortcuts.count, 2)
        XCTAssertNotNil(try IconAssetStore(rootURL: destination.rootURL).image(for: id))

        let folder = SyncedFolderProvider(folderURL: root.appendingPathComponent("Sync"))
        try await folder.save(source.snapshotWithAssets())
        let response = try await folder.load()
        let loaded = try XCTUnwrap(response)
        XCTAssertEqual(loaded.iconAssets?[id], try assets.data(for: id))
        let third = try WebDockDataStore(rootURL: root.appendingPathComponent("C"))
        try third.applyCanonicalSnapshot(loaded, notify: false)
        XCTAssertNotNil(try IconAssetStore(rootURL: third.rootURL).image(for: id))
        let snapshot = try third.snapshotWithAssets()
        XCTAssertEqual(SyncMergeEngine.merge(local: .empty, remote: snapshot).iconAssets?[id], loaded.iconAssets?[id])
    }

    @MainActor
    func testCorruptTransportCannotReplaceLibrary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WebDockDataStore(rootURL: root)
        let original = WebShortcut(displayName: "Keep", normalizedURLString: "https://example.com/")
        try store.insertShortcut(original)
        var incoming = WebShortcut(displayName: "Bad", normalizedURLString: "https://other.example/")
        incoming.iconAssetID = String(repeating: "a", count: 64)
        let remote = CanonicalSnapshot(shortcuts: [incoming], groups: [], generatedAt: Date(),
                                       iconAssets: [incoming.iconAssetID!: Data("corrupt".utf8)])
        XCTAssertThrowsError(try store.applyCanonicalSnapshot(remote, notify: false))
        XCTAssertEqual(store.activeShortcuts.map(\.id), [original.id])
        incoming.iconAssetID = "../../file"
        XCTAssertThrowsError(try store.applyCanonicalSnapshot(CanonicalSnapshot(shortcuts: [incoming], groups: [], generatedAt: Date()), notify: false))
    }
}

@MainActor
private final class EditingSyncProvider: CanonicalSyncProvider {
    let store: WebDockDataStore
    var saved: CanonicalSnapshot?
    init(store: WebDockDataStore) { self.store = store }
    func load() async throws -> CanonicalSnapshot? {
        // Models the user creating a shortcut while a remote GET is outstanding.
        await Task.yield()
        try store.insertShortcut(WebShortcut(displayName: "During GET", normalizedURLString: "https://local.example/"))
        return nil
    }
    func save(_ snapshot: CanonicalSnapshot) async throws { saved = snapshot }
}

extension PortableIconTests {
    @MainActor
    func testSyncKeepsEditsMadeDuringRemoteLoad() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WebDockDataStore(rootURL: root)
        let backup = try BackupService(dataStore: store)
        let provider = EditingSyncProvider(store: store)
        try await SyncCoordinator(dataStore: store, backupService: backup).synchronize(with: provider)
        XCTAssertEqual(store.activeShortcuts.map(\.displayName), ["During GET"])
        XCTAssertEqual(provider.saved?.shortcuts.map(\.displayName), ["During GET"])
    }
}
