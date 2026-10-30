import AppKit
import Combine

@MainActor
protocol AppIconApplying {
    func apply(_ image: NSImage?)
}

@MainActor
private final class SystemAppIconApplier: AppIconApplying {
    func apply(_ image: NSImage?) {
        // Runtime Dock / app-switcher override. Do not attach FinderInfo/resource-fork
        // metadata to the signed bundle: that fails strict signature verification.
        NSApp.applicationIconImage = image
    }
}

@MainActor
final class AppIconService: ObservableObject {
    @Published private(set) var customImage: NSImage?
    @Published private(set) var hasCustomIcon = false
    @Published private(set) var lastError: String?

    private let iconURL: URL
    private let applier: any AppIconApplying
    private let maximumBytes = 16 * 1024 * 1024

    init(rootURL: URL, applier: (any AppIconApplying)? = nil) {
        iconURL = rootURL.appendingPathComponent("Appearance/CustomAppIcon.icns")
        self.applier = applier ?? SystemAppIconApplier()
        hasCustomIcon = FileManager.default.fileExists(atPath: iconURL.path)
        if hasCustomIcon {
            do { customImage = try decode(read(iconURL)) }
            catch { lastError = L10n.errorDescription(error) }
        }
    }

    var preview: NSImage {
        customImage ?? Bundle.main.url(forResource: "WebDock", withExtension: "icns")
            .flatMap { NSImage(contentsOf: $0) } ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    func applySavedIcon() {
        guard let customImage else { return }
        applier.apply(customImage)
    }

    func chooseIcon(from url: URL) throws {
        guard url.pathExtension.lowercased() == "icns" else { throw AppIconError.invalidFormat }
        let data = try read(url)
        let image = try decode(data)
        try FileManager.default.createDirectory(at: iconURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: iconURL, options: .atomic)
        applier.apply(image)
        customImage = image
        hasCustomIcon = true
        lastError = nil
    }

    func restoreDefault() throws {
        if FileManager.default.fileExists(atPath: iconURL.path) {
            try FileManager.default.removeItem(at: iconURL)
        }
        applier.apply(nil)
        customImage = nil
        hasCustomIcon = false
        lastError = nil
    }

    private func read(_ url: URL) throws -> Data {
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? maximumBytes + 1) <= maximumBytes else {
            throw AppIconError.tooLarge
        }
        return try Data(contentsOf: url)
    }

    private func decode(_ data: Data) throws -> NSImage {
        guard data.count <= maximumBytes else { throw AppIconError.tooLarge }
        guard data.count >= 8, data.prefix(4) == Data("icns".utf8),
              data[4..<8].reduce(UInt32(0), { ($0 << 8) | UInt32($1) }) == UInt32(data.count),
              let image = NSImage(data: data), image.isValid,
              image.representations.contains(where: { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }) else {
            throw AppIconError.invalidFormat
        }
        return image
    }
}

enum AppIconError: LocalizedError {
    case invalidFormat, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalidFormat: L10n.tr("Choose a valid ICNS application icon.")
        case .tooLarge: L10n.tr("The ICNS file must be no larger than 16 MB.")
        }
    }
}
