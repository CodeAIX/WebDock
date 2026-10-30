import AppKit
import Network
import XCTest
@testable import WebDock

/// Exercises URLSession over a real loopback TCP connection, without URLProtocol interception,
/// a remote account, Keychain writes, or access to the normal WebDock library.
final class WebDAVHTTPIntegrationTests: XCTestCase {
    @MainActor
    func testTwoStoresTransferIconsAndTombstonesThenRestoreOffline() async throws {
        let server = try await LoopbackWebDAV.start()
        defer { server.stop() }
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = try WebDockDataStore(rootURL: root.appendingPathComponent("A"))
        let b = try WebDockDataStore(rootURL: root.appendingPathComponent("B"))
        let assets = try IconAssetStore(rootURL: a.rootURL)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let iconID = try assets.importImage(XCTUnwrap(bitmap.representation(using: .png, properties: [:])))
        var shortcut = WebShortcut(displayName: "Portable", normalizedURLString: "https://example.com/",
            preferredBrowserFamily: .chrome, targetAccountEmail: "account@example.com")
        shortcut.iconMode = "custom"
        shortcut.iconAssetID = iconID
        try a.insertShortcut(shortcut)
        var localA = DeviceShortcutBinding(shortcutID: shortcut.id)
        localA.overrideProfileDirectory = "Profile 12"
        try a.upsertDeviceBinding(localA)
        var localB = DeviceShortcutBinding(shortcutID: shortcut.id)
        localB.overrideProfileDirectory = "Profile 3"
        try b.upsertDeviceBinding(localB)
        let backupA = try BackupService(dataStore: a, automaticBackupsEnabled: false)
        let backupB = try BackupService(dataStore: b, automaticBackupsEnabled: false)
        let syncA = SyncCoordinator(dataStore: a, backupService: backupA, enabled: false)
        let syncB = SyncCoordinator(dataStore: b, backupService: backupB, enabled: false)
        func provider() -> WebDAVProvider {
            WebDAVProvider(baseURL: server.url, username: "fixture", password: "fixture", session: session)
        }
        try await syncA.synchronize(with: provider())
        try await syncB.synchronize(with: provider())
        XCTAssertEqual(b.activeShortcuts.first?.targetAccountEmail, "account@example.com")
        XCTAssertEqual(b.binding(for: shortcut.id)?.overrideProfileDirectory, "Profile 3")
        XCTAssertEqual(try IconAssetStore(rootURL: b.rootURL).data(for: iconID), try assets.data(for: iconID))
        let uploaded = try XCTUnwrap(server.resource)
        let text = String(decoding: uploaded, as: UTF8.self)
        for forbidden in ["Profile 12", "Profile 3", "deviceBindings", "overrideProfileDirectory"] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        let portable = root.appendingPathComponent("portable.webdockbackup")
        try backupB.exportPortable(to: portable)
        shortcut.updatedAt = shortcut.updatedAt.addingTimeInterval(5)
        shortcut.deletedAt = shortcut.updatedAt
        try a.updateShortcut(shortcut)
        try await syncA.synchronize(with: provider())
        try await syncB.synchronize(with: provider())
        XCTAssertTrue(b.activeShortcuts.isEmpty)
        XCTAssertNotNil(b.shortcut(id: shortcut.id)?.deletedAt)

        server.stop()
        let restarted = try WebDockDataStore(rootURL: b.rootURL)
        XCTAssertTrue(restarted.activeShortcuts.isEmpty)
        let offlineBackup = try BackupService(dataStore: restarted, automaticBackupsEnabled: false)
        try offlineBackup.restore(from: portable, mode: .replace)
        XCTAssertEqual(restarted.activeShortcuts.map(\.id), [shortcut.id])
        XCTAssertTrue(restarted.deviceBindings.isEmpty)
        XCTAssertEqual(try IconAssetStore(rootURL: restarted.rootURL).data(for: iconID), try assets.data(for: iconID))
        let backups = try FileManager.default.contentsOfDirectory(atPath: offlineBackup.backupsURL.path)
        XCTAssertTrue(backups.contains { $0.hasPrefix("Pre-Sync-") })
        XCTAssertTrue(backups.contains { $0.hasPrefix("Pre-Restore-") })
        XCTAssertTrue(server.requests.contains { $0.headers["if-none-match"] == "*" })
        XCTAssertTrue(server.requests.contains { $0.headers["if-match"] != nil })
        XCTAssertTrue(server.requests.allSatisfy { $0.path == "/library/WebDockSync.json" })
    }

    @MainActor
    func testStaleETagIsRejectedAndFreshMergePreservesBothWriters() async throws {
        let server = try await LoopbackWebDAV.start()
        defer { server.stop() }
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let a = WebDAVProvider(baseURL: server.url, username: "fixture", password: "fixture", session: session)
        let b = WebDAVProvider(baseURL: server.url, username: "fixture", password: "fixture", session: session)
        let first = WebShortcut(displayName: "First", normalizedURLString: "https://one.example/")
        let second = WebShortcut(displayName: "Other writer", normalizedURLString: "https://two.example/")
        try await a.save(CanonicalSnapshot(shortcuts: [first], groups: [], generatedAt: Date()))
        _ = try await b.load()
        try await a.save(CanonicalSnapshot(shortcuts: [first, second], groups: [], generatedAt: Date()))
        let before = server.resource
        do { try await b.save(.empty); XCTFail("Stale writer must receive 412") }
        catch { XCTAssertEqual(error as? SyncError, .conflict) }
        XCTAssertEqual(server.resource, before)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WebDockDataStore(rootURL: root)
        let own = WebShortcut(displayName: "Local edit", normalizedURLString: "https://local.example/")
        try store.insertShortcut(own)
        let backup = try BackupService(dataStore: store, automaticBackupsEnabled: false)
        try await SyncCoordinator(dataStore: store, backupService: backup, enabled: false).synchronize(with: b)
        XCTAssertEqual(Set(store.activeShortcuts.map(\.id)), Set([first.id, second.id, own.id]))
        let remote = try await a.load()
        XCTAssertEqual(Set(try XCTUnwrap(remote).shortcuts.map(\.id)), Set([first.id, second.id, own.id]))
    }

    @MainActor
    func testHTTPFailureAndCorruptAssetsLeaveDurableLibraryUntouched() async throws {
        let server = try await LoopbackWebDAV.start()
        defer { server.stop() }
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WebDockDataStore(rootURL: root)
        try store.insertShortcut(WebShortcut(displayName: "Keep", normalizedURLString: "https://keep.example/"))
        let original = try Data(contentsOf: store.canonicalURL)
        let backup = try BackupService(dataStore: store, automaticBackupsEnabled: false)
        let coordinator = SyncCoordinator(dataStore: store, backupService: backup, enabled: false)
        let provider = WebDAVProvider(baseURL: server.url, username: "fixture", password: "fixture", session: session)
        server.overrideGET(status: 503, body: Data())
        do { try await coordinator.synchronize(with: provider); XCTFail("Expected HTTP failure") }
        catch { XCTAssertEqual(error as? SyncError, .httpStatus(503)) }
        var incoming = WebShortcut(displayName: "Corrupt", normalizedURLString: "https://bad.example/")
        incoming.iconAssetID = String(repeating: "a", count: 64)
        let invalid = CanonicalSnapshot(shortcuts: [incoming], groups: [], generatedAt: Date(),
            iconAssets: [incoming.iconAssetID!: Data("not an image".utf8)])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        server.overrideGET(status: 200, body: try encoder.encode(invalid))
        do { try await coordinator.synchronize(with: provider); XCTFail("Expected invalid asset") }
        catch { XCTAssertTrue(error is IconError) }
        XCTAssertEqual(try Data(contentsOf: store.canonicalURL), original)
        XCTAssertEqual(try WebDockDataStore(rootURL: root).activeShortcuts.map(\.displayName), ["Keep"])
        XCTAssertFalse(server.requests.contains { $0.method == "PUT" })
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: backup.backupsURL.path).isEmpty)
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        config.connectionProxyDictionary = [:]
        return URLSession(configuration: config)
    }
}

/// A minimal, authenticated GET/PUT endpoint. Every mutable field is confined to queue.
private final class LoopbackWebDAV {
    struct Request {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }
    private let queue = DispatchQueue(label: "WebDock.loopback-webdav")
    private let listener: NWListener
    private var contents: Data?
    private var version = 0
    private var received: [Request] = []
    private var getOverride: (Int, Data)?
    private var connections: [NWConnection] = []
    var url: URL { URL(string: "http://127.0.0.1:\(listener.port!.rawValue)/library")! }
    var resource: Data? { queue.sync { contents } }
    var requests: [Request] { queue.sync { received } }

    private init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }
    static func start() async throws -> LoopbackWebDAV {
        let server = try LoopbackWebDAV()
        server.listener.newConnectionHandler = { [weak server] connection in
            guard let server else { connection.cancel(); return }
            server.connections.append(connection)
            connection.start(queue: server.queue)
            server.receive(connection, buffer: Data())
        }
        try await withCheckedThrowingContinuation { (ready: CheckedContinuation<Void, Error>) in
            server.listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    server.listener.stateUpdateHandler = nil
                    ready.resume()
                case .failed(let error):
                    server.listener.stateUpdateHandler = nil
                    ready.resume(throwing: error)
                default: break
                }
            }
            server.listener.start(queue: server.queue)
        }
        return server
    }
    func stop() {
        queue.sync {
            listener.cancel()
            connections.forEach { $0.cancel() }
            connections.removeAll()
        }
    }
    func overrideGET(status: Int, body: Data) { queue.sync { getOverride = (status, body) } }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, done, error in
            guard let self else { return }
            var buffer = buffer
            buffer.append(data ?? Data())
            guard buffer.count <= 2 * 1024 * 1024 else { connection.cancel(); return }
            if let separator = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let lines = String(decoding: buffer[..<separator.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
                let first = lines[0].split(separator: " ")
                guard first.count >= 2 else { connection.cancel(); return }
                var headers: [String: String] = [:]
                for line in lines.dropFirst() {
                    let pair = line.split(separator: ":", maxSplits: 1)
                    if pair.count == 2 { headers[pair[0].lowercased()] = pair[1].trimmingCharacters(in: .whitespaces) }
                }
                let length = Int(headers["content-length"] ?? "0") ?? 0
                if buffer.count - separator.upperBound >= length {
                    let request = Request(method: String(first[0]), path: String(first[1]), headers: headers,
                        body: Data(buffer[separator.upperBound...].prefix(length)))
                    let (status, body) = self.handle(request)
                    let response = "HTTP/1.1 \(status) Fixture\r\nContent-Length: \(body.count)\r\nETag: \"v\(self.version)\"\r\nConnection: close\r\n\r\n"
                    connection.send(content: Data(response.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
                    return
                }
            }
            if done || error != nil { connection.cancel() }
            else { self.receive(connection, buffer: buffer) }
        }
    }
    private func handle(_ request: Request) -> (Int, Data) {
        received.append(request)
        guard request.path == "/library/WebDockSync.json" else { return (404, Data()) }
        let auth = "Basic " + Data("fixture:fixture".utf8).base64EncodedString()
        guard request.headers["authorization"] == auth else { return (401, Data()) }
        if request.method == "GET" { return getOverride ?? contents.map { (200, $0) } ?? (404, Data()) }
        guard request.method == "PUT" else { return (405, Data()) }
        if contents == nil {
            guard request.headers["if-none-match"] == "*" else { return (412, Data()) }
        } else {
            guard request.headers["if-match"] == "\"v\(version)\"" else { return (412, Data()) }
        }
        let created = contents == nil
        contents = request.body
        version += 1
        return (created ? 201 : 204, Data())
    }
}
