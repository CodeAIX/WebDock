import AppKit
import Foundation

struct WebDockBackupEnvelope: Codable, Equatable {
    enum Kind: String, Codable {
        case portable
        case localSnapshot
    }

    static let formatIdentifier = "io.github.codeaix.WebDock.backup"
    static let currentFormatVersion = 1

    var formatIdentifier: String = Self.formatIdentifier
    var formatVersion: Int = Self.currentFormatVersion
    var createdAt: Date
    var appVersion: String
    var kind: Kind
    var canonical: CanonicalSnapshot
    var deviceBindings: [DeviceShortcutBinding]?
}

enum BackupRestoreMode {
    case replace
    case merge
}

@MainActor
final class BackupService {
    private static let automaticBackupKey = "WebDock.lastAutomaticBackupAt"
    private static let maximumAutomaticBackups = 20

    let backupsURL: URL

    private let dataStore: WebDockDataStore
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var canonicalChangeObserver: NSObjectProtocol?

    init(
        dataStore: WebDockDataStore,
        fileManager: FileManager = .default,
        automaticBackupsEnabled: Bool = true
    ) throws {
        self.dataStore = dataStore
        self.fileManager = fileManager
        backupsURL = dataStore.rootURL.appendingPathComponent("Backups", isDirectory: true)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)

        guard automaticBackupsEnabled else { return }
        canonicalChangeObserver = NotificationCenter.default.addObserver(
            forName: .webDockCanonicalDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? self?.performAutomaticBackupIfNeeded()
            }
        }
    }

    deinit {
        if let canonicalChangeObserver {
            NotificationCenter.default.removeObserver(canonicalChangeObserver)
        }
    }

    func performAutomaticBackupIfNeeded(now: Date = Date()) throws {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: Self.automaticBackupKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: now) {
            return
        }

        _ = try createLocalSnapshot(prefix: "Auto", date: now)
        defaults.set(now, forKey: Self.automaticBackupKey)
        try pruneAutomaticBackups()
    }

    @discardableResult
    func createManualSnapshot() throws -> URL {
        try createLocalSnapshot(prefix: "Manual", date: Date())
    }

    @discardableResult
    func createSafetySnapshot(prefix: String) throws -> URL {
        try createLocalSnapshot(prefix: prefix, date: Date())
    }

    @discardableResult
    func createPreRestoreSnapshot() throws -> URL {
        try createLocalSnapshot(prefix: "Pre-Restore", date: Date())
    }

    func exportPortable(to url: URL) throws {
        let envelope = WebDockBackupEnvelope(
            createdAt: Date(),
            appVersion: appVersion,
            kind: .portable,
            canonical: try dataStore.snapshotWithAssets(),
            deviceBindings: nil
        )
        try write(envelope, to: url)
    }

    func restore(from url: URL, mode: BackupRestoreMode) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 48 * 1024 * 1024 else { throw BackupError.unsupportedBackup }
        let data = try Data(contentsOf: url)
        let envelope = try decoder.decode(WebDockBackupEnvelope.self, from: data)
        guard envelope.formatIdentifier == WebDockBackupEnvelope.formatIdentifier,
              envelope.formatVersion <= WebDockBackupEnvelope.currentFormatVersion else {
            throw BackupError.unsupportedBackup
        }

        try dataStore.validateAssets(in: envelope.canonical)
        _ = try createPreRestoreSnapshot()

        switch mode {
        case .replace:
            let bindings = envelope.kind == .localSnapshot
                ? (envelope.deviceBindings ?? [])
                : []
            try dataStore.replaceAll(
                canonical: envelope.canonical,
                bindings: bindings,
                notify: true
            )
        case .merge:
            let merged = SyncMergeEngine.merge(
                local: try dataStore.snapshotWithAssets(requireAll: false),
                remote: envelope.canonical
            )
            try dataStore.applyCanonicalSnapshot(merged, notify: true)
        }
    }

    func openBackupFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([backupsURL])
    }

    private func createLocalSnapshot(prefix: String, date: Date) throws -> URL {
        let envelope = WebDockBackupEnvelope(
            createdAt: date,
            appVersion: appVersion,
            kind: .localSnapshot,
            canonical: try dataStore.snapshotWithAssets(requireAll: false),
            deviceBindings: dataStore.deviceBindings
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let safePrefix = prefix.replacingOccurrences(of: "/", with: "-")
        let filename = "\(safePrefix)-\(formatter.string(from: date))-\(UUID().uuidString.prefix(8)).webdockbackup"
        let url = backupsURL.appendingPathComponent(filename, isDirectory: false)
        try write(envelope, to: url)
        return url
    }

    private func write(_ envelope: WebDockBackupEnvelope, to url: URL) throws {
        let data = try encoder.encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    private func pruneAutomaticBackups() throws {
        let files = try fileManager.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let automatic = files
            .filter { $0.lastPathComponent.hasPrefix("Auto-") && $0.pathExtension == "webdockbackup" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }

        for url in automatic.dropFirst(Self.maximumAutomaticBackups) {
            try? fileManager.removeItem(at: url)
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}

enum BackupError: LocalizedError {
    case unsupportedBackup

    var errorDescription: String? {
        switch self {
        case .unsupportedBackup:
            "This file is not a supported WebDock backup."
        }
    }
}
