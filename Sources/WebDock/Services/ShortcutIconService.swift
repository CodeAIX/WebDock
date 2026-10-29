import AppKit
import Combine
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Content-addressed, normalized PNGs. Absolute paths never enter a portable rule.
@MainActor
final class IconAssetStore {
    nonisolated static let maximumAssetBytes = 4 * 1024 * 1024
    let directory: URL

    init(rootURL: URL) throws {
        directory = rootURL.appendingPathComponent("Icons", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func validID(_ id: String) -> Bool {
        id.count == 64 && id.allSatisfy { "0123456789abcdef".contains($0) }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func url(for id: String) throws -> URL {
        guard Self.validID(id) else { throw IconError.invalidAsset }
        return directory.appendingPathComponent(id + ".png")
    }

    func data(for id: String) throws -> Data {
        let url = try url(for: id)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= Self.maximumAssetBytes else { throw IconError.invalidAsset }
        let data = try Data(contentsOf: url)
        guard Self.digest(data) == id else { throw IconError.invalidAsset }
        return data
    }

    func image(for id: String?) -> NSImage? {
        guard let id, let data = try? data(for: id) else { return nil }
        return NSImage(data: data)
    }

    @discardableResult
    func importImage(_ data: Data) throws -> String {
        guard data.count <= Self.maximumAssetBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw IconError.invalidAsset }
        let index = (0..<min(256, CGImageSourceGetCount(source))).max { lhs, rhs in
            Self.pixelWidth(source, index: lhs) < Self.pixelWidth(source, index: rhs)
        } ?? 0
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16384, height <= 16384,
              let image = CGImageSourceCreateThumbnailAtIndex(source, index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw IconError.invalidAsset }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw IconError.invalidAsset }
        let id = Self.digest(png)
        try install(png, id: id)
        return id
    }

    private static func pixelWidth(_ source: CGImageSource, index: Int) -> Int {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        return properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
    }

    func pixelWidth(for id: String) -> Int {
        guard let data = try? data(for: id), let source = CGImageSourceCreateWithData(data as CFData, nil) else { return 0 }
        return Self.pixelWidth(source, index: 0)
    }

    func validate(_ data: Data, id: String) throws {
        guard Self.validID(id), data.count <= Self.maximumAssetBytes,
              Self.digest(data) == id,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source), type as String == UTType.png.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 512, height <= 512,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw IconError.invalidAsset }
    }

    /// Verify before installation; used by backup/sync too. Never re-encode a transported asset.
    func install(_ data: Data, id: String) throws {
        try validate(data, id: id)
        try data.write(to: url(for: id), options: .atomic)
    }
}

struct WebIconCandidate: Equatable {
    let url: URL
    let priority: Int
}

enum WebIconDiscovery {
    /// Parse only icon metadata from an unauthenticated homepage; no browser data is accessed.
    static func links(in html: String, baseURL: URL) -> (icons: [WebIconCandidate], manifests: [URL]) {
        let tagPattern = try! NSRegularExpression(pattern: "<link\\b[^>]*>", options: .caseInsensitive)
        let attributePattern = try! NSRegularExpression(pattern: "([\\w-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))")
        let source = html as NSString
        var icons: [WebIconCandidate] = []
        var manifests: [URL] = []
        for match in tagPattern.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let tag = source.substring(with: match.range) as NSString
            var attributes: [String: String] = [:]
            for attribute in attributePattern.matches(in: tag as String, range: NSRange(location: 0, length: tag.length)) {
                let name = tag.substring(with: attribute.range(at: 1)).lowercased()
                for index in 2...4 where attribute.range(at: index).location != NSNotFound {
                    attributes[name] = tag.substring(with: attribute.range(at: index)).replacingOccurrences(of: "&amp;", with: "&")
                }
            }
            guard let href = attributes["href"], let url = URL(string: href, relativeTo: baseURL)?.absoluteURL,
                  isWebURL(url) else { continue }
            let rel = (attributes["rel"] ?? "").lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
            if rel.contains("manifest") { manifests.append(url) }
            if rel.contains("apple-touch-icon") || rel.contains("apple-touch-icon-precomposed") {
                icons.append(WebIconCandidate(url: url, priority: 2000 + sizeScore(attributes["sizes"])))
            } else if rel.contains("icon") {
                icons.append(WebIconCandidate(url: url, priority: 1000 + sizeScore(attributes["sizes"])))
            }
        }
        return (icons.sorted { $0.priority > $1.priority }, manifests)
    }

    static func manifestIcons(_ data: Data, baseURL: URL) -> [WebIconCandidate] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let icons = object["icons"] as? [[String: Any]] else { return [] }
        return icons.compactMap { icon in
            guard let src = icon["src"] as? String, let url = URL(string: src, relativeTo: baseURL)?.absoluteURL,
                  isWebURL(url) else { return nil }
            return WebIconCandidate(url: url, priority: 3000 + sizeScore(icon["sizes"] as? String))
        }.sorted { $0.priority > $1.priority }
    }

    static func isWebURL(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil && url.user == nil && url.password == nil
    }

    private static func sizeScore(_ value: String?) -> Int {
        let sizes = (value ?? "").lowercased().split(whereSeparator: \.isWhitespace)
        return min(512, sizes.compactMap { Int($0.split(separator: "x").first ?? "") }.max() ?? 0)
    }
}

/// Ephemeral session: no shared cookies, browser credentials, history or persistent cache.
actor WebIconDownloader {
    private let session: URLSession
    init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        self.session = session ?? URLSession(configuration: config)
    }

    func candidates(for website: URL) async -> [URL] {
        guard let origin = URL(string: "/", relativeTo: website)?.absoluteURL,
              WebIconDiscovery.isWebURL(origin) else { return [] }
        var candidates: [WebIconCandidate] = []
        if let (data, responseURL) = try? await fetch(origin, limit: 1024 * 1024),
           let html = String(data: data, encoding: .utf8) {
            let links = WebIconDiscovery.links(in: html, baseURL: responseURL)
            for manifest in links.manifests.prefix(2) {
                if let (data, base) = try? await fetch(manifest, limit: 256 * 1024) {
                    candidates += WebIconDiscovery.manifestIcons(data, baseURL: base)
                }
            }
            candidates += links.icons
        }
        // Stable origin-local fallbacks; an unavailable site still reaches the generic globe.
        candidates += [WebIconCandidate(url: origin.appendingPathComponent("apple-touch-icon.png"), priority: 500),
                       WebIconCandidate(url: origin.appendingPathComponent("favicon.ico"), priority: 100)]
        if ["google.com", "www.google.com"].contains(origin.host?.lowercased() ?? ""),
           let url = URL(string: "https://www.gstatic.com/images/branding/product/2x/googleg_96dp.png") {
            candidates.append(WebIconCandidate(url: url, priority: 200))
        }
        var seen: Set<URL> = []
        return candidates.sorted { $0.priority > $1.priority }.map(\.url).filter { seen.insert($0).inserted }
    }

    func fetch(_ url: URL, limit: Int = IconAssetStore.maximumAssetBytes) async throws -> (Data, URL) {
        guard WebIconDiscovery.isWebURL(url) else { throw IconError.invalidAsset }
        var request = URLRequest(url: url)
        request.setValue("WebDock/0.4 IconDiscovery", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let finalURL = response.url, WebIconDiscovery.isWebURL(finalURL),
              response.expectedContentLength <= limit else { throw IconError.unavailable }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw IconError.invalidAsset }
            data.append(byte)
        }
        return (data, finalURL)
    }
}

@MainActor
final class ShortcutIconService: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var loading: Set<UUID> = []
    @Published private(set) var failed: Set<UUID> = []
    let assets: IconAssetStore
    private let dataStore: WebDockDataStore
    private let backupService: BackupService
    private let downloader = WebIconDownloader()
    private var attempted: Set<String> = []
    private var didBackUp = false
    private var imageCache: [String: NSImage] = [:]

    init(dataStore: WebDockDataStore, backupService: BackupService) throws {
        self.dataStore = dataStore
        self.backupService = backupService
        assets = try IconAssetStore(rootURL: dataStore.rootURL)
    }

    func image(for shortcut: WebShortcut) -> NSImage? {
        guard let id = shortcut.iconAssetID else { return nil }
        if let image = imageCache[id] { return image }
        let image = assets.image(for: id)
        imageCache[id] = image
        return image
    }

    func loadIfNeeded(_ shortcut: WebShortcut, force: Bool = false) async {
        guard shortcut.iconMode != "custom", !loading.contains(shortcut.id),
              image(for: shortcut) == nil || force else { return }
        let key = shortcut.id.uuidString + shortcut.normalizedURLString
        guard force || !attempted.contains(key), let url = URL(string: shortcut.normalizedURLString) else { return }
        while loading.count >= 4 {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard !loading.contains(shortcut.id), !Task.isCancelled else { return }
        attempted.insert(key)
        loading.insert(shortcut.id)
        failed.remove(shortcut.id)
        defer {
            loading.remove(shortcut.id)
            if Task.isCancelled { attempted.remove(key) }
        }
        var smallFallback: (String, String)?
        for candidate in await downloader.candidates(for: url).prefix(12) {
            guard !Task.isCancelled else { return }
            guard let (data, sourceURL) = try? await downloader.fetch(candidate),
                  let id = try? assets.importImage(data) else { continue }
            if assets.pixelWidth(for: id) < 128 {
                if smallFallback == nil || assets.pixelWidth(for: id) > assets.pixelWidth(for: smallFallback!.0) {
                    smallFallback = (id, sourceURL.absoluteString)
                }
                continue
            }
            // A late download must not overwrite a user choice, changed URL or deleted shortcut.
            guard let current = dataStore.shortcut(id: shortcut.id), current.deletedAt == nil,
                  current.iconMode != "custom", current.normalizedURLString == shortcut.normalizedURLString else { return }
            do { try update(current, assetID: id, mode: "automatic", source: sourceURL.absoluteString) }
            catch { failed.insert(shortcut.id) }
            return
        }
        if let (id, source) = smallFallback, let current = dataStore.shortcut(id: shortcut.id),
           current.deletedAt == nil, current.iconMode != "custom", current.normalizedURLString == shortcut.normalizedURLString {
            do { try update(current, assetID: id, mode: "automatic", source: source) }
            catch { failed.insert(shortcut.id) }
        } else { failed.insert(shortcut.id) }
    }

    func chooseIcon(for shortcut: WebShortcut) throws {
        let panel = NSOpenPanel()
        panel.title = "Choose Website Icon"
        panel.allowedContentTypes = [.png, .jpeg, .ico, .icns]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= IconAssetStore.maximumAssetBytes else { throw IconError.invalidAsset }
        let id = try assets.importImage(Data(contentsOf: url))
        try update(shortcut, assetID: id, mode: "custom", source: nil)
    }

    func reset(_ shortcut: WebShortcut) throws {
        try update(shortcut, assetID: nil, mode: nil, source: nil)
        attempted = attempted.filter { !$0.hasPrefix(shortcut.id.uuidString) }
        failed.remove(shortcut.id)
    }

    private func update(_ shortcut: WebShortcut, assetID: String?, mode: String?, source: String?) throws {
        if !didBackUp {
            _ = try backupService.createSafetySnapshot(prefix: "Pre-Icon-Metadata")
            didBackUp = true
        }
        guard var current = dataStore.shortcut(id: shortcut.id), current.deletedAt == nil else { return }
        current.iconAssetID = assetID
        current.iconMode = mode
        current.iconSourceURL = source
        current.updatedAt = Date()
        try dataStore.updateShortcut(current)
        revision += 1
    }
}

enum IconError: LocalizedError {
    case invalidAsset, unavailable, payloadTooLarge
    var errorDescription: String? {
        switch self {
        case .invalidAsset: "Choose a valid PNG, JPEG, ICO or ICNS image up to 4 MB."
        case .unavailable: "The website icon is unavailable."
        case .payloadTooLarge: "Portable icons exceed the limit of 512 assets or 32 MB. Reduce custom icon size before syncing or exporting."
        }
    }
}
