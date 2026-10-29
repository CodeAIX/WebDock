import XCTest
@testable import WebDock

final class ImportTransactionTests: XCTestCase {
    func testStageAndInstallPreserveSourceUntilConsume() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("ChatGPT.crwebloc")
        let payload = Data("shortcut-payload".utf8)
        try payload.write(to: source)

        let storage = try ManagedStorage(
            rootURL: root.appendingPathComponent("Managed", isDirectory: true)
        )
        var transaction = ImportTransaction(
            sourceURL: source,
            managedStorage: storage
        )

        let staged = try transaction.stage()
        XCTAssertTrue(fileManager.fileExists(atPath: source.path))
        XCTAssertTrue(fileManager.fileExists(atPath: staged.path))
        XCTAssertEqual(try Data(contentsOf: staged), payload)
        XCTAssertEqual(transaction.state, .staged)

        let installed = try transaction.install()
        XCTAssertTrue(fileManager.fileExists(atPath: source.path))
        XCTAssertTrue(fileManager.fileExists(atPath: installed.path))
        XCTAssertEqual(try Data(contentsOf: installed), payload)
        XCTAssertEqual(transaction.state, .installed)

        try transaction.consumeSource()
        XCTAssertFalse(fileManager.fileExists(atPath: source.path))
        XCTAssertTrue(fileManager.fileExists(atPath: installed.path))
        XCTAssertEqual(transaction.state, .sourceConsumed)
    }

    func testRollbackRemovesManagedArtifactsButPreservesSource() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Example.webloc")
        let payload = Data("important-user-file".utf8)
        try payload.write(to: source)

        let storage = try ManagedStorage(
            rootURL: root.appendingPathComponent("Managed", isDirectory: true)
        )
        var transaction = ImportTransaction(
            sourceURL: source,
            managedStorage: storage
        )

        _ = try transaction.stage()
        _ = try transaction.install()
        transaction.rollbackManagedArtifacts()

        XCTAssertTrue(fileManager.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: source), payload)
        XCTAssertFalse(fileManager.fileExists(atPath: storage.directory(for: transaction.id).path))
        XCTAssertFalse(fileManager.fileExists(atPath: storage.stagingDirectory(for: transaction.id).path))
        XCTAssertEqual(transaction.state, .rolledBack)
    }

    func testConsumeFailsIfManagedCopyDisappears() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("WebDockTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Example.url")
        try Data("[InternetShortcut]\nURL=https://example.com/\n".utf8).write(to: source)

        let storage = try ManagedStorage(
            rootURL: root.appendingPathComponent("Managed", isDirectory: true)
        )
        var transaction = ImportTransaction(
            sourceURL: source,
            managedStorage: storage
        )

        _ = try transaction.stage()
        let installed = try transaction.install()
        try fileManager.removeItem(at: installed)

        XCTAssertThrowsError(try transaction.consumeSource()) { error in
            guard case ImportTransactionError.managedCopyMissing = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(fileManager.fileExists(atPath: source.path))
    }
}
