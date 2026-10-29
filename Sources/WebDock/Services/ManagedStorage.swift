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
        try self.init(
            rootURL: support.appendingPathComponent("WebDock", isDirectory: true),
            fileManager: fileManager
        )
    }

    /// Injectable root used by tests and future portable-profile features.
    init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL
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

    func stagingDirectory(for id: UUID) -> URL {
        stagingURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    /// Reversible holding area used while a database deletion is being committed.
    /// It intentionally remains inside WebDock's Application Support tree until
    /// the SwiftData record is gone; only then is it sent to the system Trash.
    func deletionStagingDirectory(for id: UUID) -> URL {
        stagingURL.appendingPathComponent("Delete-\(id.uuidString)", isDirectory: true)
    }

    func relativePath(forManagedFile url: URL) -> String? {
        let root = rootURL.standardizedFileURL.path
        let file = url.standardizedFileURL.path
        guard file.hasPrefix(root + "/") else { return nil }
        return String(file.dropFirst(root.count + 1))
    }
}
