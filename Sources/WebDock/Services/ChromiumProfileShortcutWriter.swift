import Foundation

protocol BrowserProfileShortcutWriting {
    func writeShortcut(
        targetURL: URL,
        profileDirectory: String,
        shortcutID: UUID,
        storageRoot: URL
    ) throws -> URL
}

struct ChromiumProfileShortcutWriter: BrowserProfileShortcutWriting {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func writeShortcut(
        targetURL: URL,
        profileDirectory: String,
        shortcutID: UUID,
        storageRoot: URL
    ) throws -> URL {
        let directory = storageRoot
            .appendingPathComponent("Cache", isDirectory: true)
            .appendingPathComponent("ProfileLaunch", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let destination = directory
            .appendingPathComponent(shortcutID.uuidString, isDirectory: false)
            .appendingPathExtension("crwebloc")

        let payload: [String: String] = [
            "URL": targetURL.absoluteString,
            "CrProfile": profileDirectory
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: payload,
            format: .xml,
            options: 0
        )
        try data.write(to: destination, options: .atomic)
        return destination
    }
}
