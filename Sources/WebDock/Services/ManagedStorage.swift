import Foundation

struct ManagedStorage {
    let rootURL: URL
    let shortcutsURL: URL
    let cacheURL: URL
    let stagingURL: URL

    init(fileManager: FileManager = .default) throws {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        rootURL = support.appendingPathComponent("WebDock", isDirectory: true)
        shortcutsURL = rootURL.appendingPathComponent("Shortcuts", isDirectory: true)
        cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        stagingURL = rootURL.appendingPathComponent("Staging", isDirectory: true)

        try fileManager.createDirectory(at: shortcutsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
    }

    func directory(for id: UUID) -> URL {
        shortcutsURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}
