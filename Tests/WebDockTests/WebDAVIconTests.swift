import Foundation
import XCTest
@testable import WebDock

private final class WebDAVStub: URLProtocol {
    static var response: ((URLRequest) throws -> (Int, [String: String], Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.response else { throw URLError(.badServerResponse) }
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class WebDAVIconTests: XCTestCase {
    @MainActor
    func testWebDAVRetainsIconBytesAndUsesETagOnWrite() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebDAVStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); WebDAVStub.response = nil }
        var shortcut = WebShortcut(displayName: "Example", normalizedURLString: "https://example.com/")
        let bytes = Data([1, 2, 3, 4]) // Provider transports bytes; DataStore performs PNG/hash validation.
        let id = String(repeating: "a", count: 64)
        shortcut.iconAssetID = id
        let snapshot = CanonicalSnapshot(shortcuts: [shortcut], groups: [], generatedAt: Date(), iconAssets: [id: bytes])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(snapshot)
        var didPut = false
        WebDAVStub.response = { request in
            if request.httpMethod == "GET" { return (200, ["ETag": "\"v1\""], payload) }
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-Match"), "\"v1\"")
            XCTAssertNil(request.value(forHTTPHeaderField: "If-None-Match"))
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }; body.append(buffer, count: count)
                }
            }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            XCTAssertEqual(try decoder.decode(CanonicalSnapshot.self, from: body).iconAssets?[id], bytes)
            didPut = true
            return (200, ["ETag": "\"v2\""], Data())
        }
        let provider = WebDAVProvider(baseURL: URL(string: "https://sync.example/webdock/")!, username: "test", password: "test", session: session)
        let loaded = try await provider.load()
        XCTAssertEqual(loaded?.iconAssets?[id], bytes)
        try await provider.save(snapshot)
        XCTAssertTrue(didPut)
        WebDAVStub.response = { _ in (412, [:], Data()) }
        do { try await provider.save(snapshot); XCTFail("Expected conflict") }
        catch { XCTAssertEqual(error as? SyncError, .conflict) }
    }
}

extension WebDAVIconTests {
    @MainActor
    func testInitialWebDAVCreateUsesIfNoneMatch() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebDAVStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); WebDAVStub.response = nil }
        var didPut = false
        WebDAVStub.response = { request in
            if request.httpMethod == "GET" { return (404, [:], Data()) }
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "*")
            XCTAssertNil(request.value(forHTTPHeaderField: "If-Match"))
            didPut = true
            return (201, ["ETag": "\"new\""], Data())
        }
        let provider = WebDAVProvider(baseURL: URL(string: "https://sync.example/webdock/")!, username: "", password: nil, session: session)
        let result = try await provider.load()
        XCTAssertNil(result)
        try await provider.save(.empty)
        XCTAssertTrue(didPut)
    }
}
