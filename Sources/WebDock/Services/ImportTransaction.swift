import Foundation

/// File-system portion of a shortcut import transaction.
///
/// Safety invariant: the user's source file is never removed until a verified
/// managed copy exists. Rollback therefore never needs to reconstruct the
/// user's original file.
struct ImportTransaction {
    enum State: Equatable {
        case initialized
        case staged
        case installed
        case sourceConsumed
        case rolledBack
    }

    let id: UUID
    let sourceURL: URL
    let managedStorage: ManagedStorage

    private let fileManager: FileManager
    private(set) var state: State = .initialized
    private(set) var stagedFileURL: URL?
    private(set) var installedFileURL: URL?

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        managedStorage: ManagedStorage,
        fileManager: FileManager = .default
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.managedStorage = managedStorage
        self.fileManager = fileManager
    }

    mutating func stage() throws -> URL {
        guard state == .initialized else {
            throw ImportTransactionError.invalidState
        }

        let directory = managedStorage.stagingDirectory(for: id)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let stagedURL = directory
            .appendingPathComponent("original")
            .appendingPathExtension(sourceURL.pathExtension)

        do {
            try fileManager.copyItem(at: sourceURL, to: stagedURL)
            try verifySameContents(sourceURL, stagedURL)
            stagedFileURL = stagedURL
            state = .staged
            return stagedURL
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    mutating func install() throws -> URL {
        guard state == .staged, let stagedFileURL else {
            throw ImportTransactionError.invalidState
        }

        let destinationDirectory = managedStorage.directory(for: id)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let destinationURL = destinationDirectory
            .appendingPathComponent("original")
            .appendingPathExtension(sourceURL.pathExtension)

        do {
            try fileManager.moveItem(at: stagedFileURL, to: destinationURL)
            try verifySameContents(sourceURL, destinationURL)
            installedFileURL = destinationURL
            state = .installed
            try? fileManager.removeItem(at: managedStorage.stagingDirectory(for: id))
            return destinationURL
        } catch {
            try? fileManager.removeItem(at: destinationDirectory)
            throw error
        }
    }

    /// Removes the user's original only after a verified managed file exists.
    mutating func consumeSource() throws {
        guard state == .installed, let installedFileURL else {
            throw ImportTransactionError.invalidState
        }
        guard fileManager.fileExists(atPath: installedFileURL.path) else {
            throw ImportTransactionError.managedCopyMissing
        }

        try fileManager.removeItem(at: sourceURL)
        state = .sourceConsumed
    }

    /// Deletes WebDock-owned artifacts. The user's source file is deliberately
    /// untouched. This is safe both before and after database insertion as long
    /// as callers only invoke it before `consumeSource()` or after restoring the
    /// corresponding database state.
    mutating func rollbackManagedArtifacts() {
        try? fileManager.removeItem(at: managedStorage.stagingDirectory(for: id))
        try? fileManager.removeItem(at: managedStorage.directory(for: id))
        stagedFileURL = nil
        installedFileURL = nil
        state = .rolledBack
    }

    private func verifySameContents(_ lhs: URL, _ rhs: URL) throws {
        let left = try Data(contentsOf: lhs, options: [.mappedIfSafe])
        let right = try Data(contentsOf: rhs, options: [.mappedIfSafe])
        guard left == right else {
            throw ImportTransactionError.verificationFailed
        }
    }
}

enum ImportTransactionError: LocalizedError {
    case invalidState
    case verificationFailed
    case managedCopyMissing

    var errorDescription: String? {
        switch self {
        case .invalidState:
            "The import transaction is in an invalid state."
        case .verificationFailed:
            "The managed shortcut copy did not match the original file."
        case .managedCopyMissing:
            "The verified managed shortcut copy is missing."
        }
    }
}
