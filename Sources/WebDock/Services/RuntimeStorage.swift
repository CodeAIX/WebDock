import Foundation

struct RuntimeStorage {
    let rootURL: URL
    let cacheURL: URL

    init(
        fileManager: FileManager = .default,
        rootURL: URL? = nil
    ) throws {
        let resolvedRoot: URL
        if let rootURL {
            resolvedRoot = rootURL
        } else {
            let applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            resolvedRoot = applicationSupport
                .appendingPathComponent("WebDock", isDirectory: true)
        }

        self.rootURL = resolvedRoot
        self.cacheURL = resolvedRoot.appendingPathComponent("Cache", isDirectory: true)

        try fileManager.createDirectory(at: resolvedRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }
}
