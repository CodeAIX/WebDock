import Carbon
import XCTest
@testable import WebDock

@MainActor
final class GlobalHotKeyServiceTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "WebDockTests.hotkey.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testCustomShortcutAndDisabledPreferenceSurviveServiceRestart() {
        let defaults = defaults()
        let registrar = FakeRegistrar()
        let service = GlobalHotKeyService(defaults: defaults, registrar: registrar)
        var invocations = 0
        service.start { invocations += 1 }
        registrar.action?()
        XCTAssertEqual(invocations, 1)
        let custom = LauncherHotKey(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(controlKey | cmdKey))
        service.save(custom)
        XCTAssertEqual(registrar.active, custom)
        service.setEnabled(false)
        XCTAssertNil(registrar.active)
        service.stop()
        let restarted = GlobalHotKeyService(defaults: defaults, registrar: FakeRegistrar())
        XCTAssertEqual(restarted.hotKey, custom)
        XCTAssertFalse(restarted.isEnabled)
        restarted.start {}
        XCTAssertFalse(restarted.isRegistered)
    }

    func testRejectedReplacementPreservesActiveAndPersistedCombination() {
        let defaults = defaults()
        let registrar = FakeRegistrar()
        let service = GlobalHotKeyService(defaults: defaults, registrar: registrar)
        service.start {}
        let rejected = LauncherHotKey(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(controlKey | cmdKey))
        registrar.rejected = rejected
        service.save(rejected)
        XCTAssertEqual(service.error, .unavailable)
        XCTAssertEqual(service.hotKey, .defaultValue)
        XCTAssertEqual(registrar.active, .defaultValue)
        XCTAssertTrue(service.isRegistered)
        XCTAssertNil(defaults.data(forKey: GlobalHotKeyService.shortcutKey))
    }

    func testRecordingSuspendsCancelRestoresAndConflictRollsBack() {
        let registrar = FakeRegistrar()
        let service = GlobalHotKeyService(defaults: defaults(), registrar: registrar)
        service.start {}
        service.beginRecording()
        XCTAssertNil(registrar.active)
        XCTAssertTrue(service.isRecording)
        service.save(LauncherHotKey(keyCode: 0, modifiers: 0))
        XCTAssertEqual(service.error, .invalidCombination)
        XCTAssertTrue(service.isRecording)
        service.cancelRecording()
        XCTAssertEqual(registrar.active, .defaultValue)
        let rejected = LauncherHotKey(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(optionKey | cmdKey))
        registrar.rejected = rejected
        service.beginRecording()
        service.save(rejected)
        XCTAssertFalse(service.isRecording)
        XCTAssertEqual(service.error, .unavailable)
        XCTAssertEqual(registrar.active, .defaultValue)
        XCTAssertEqual(service.hotKey, .defaultValue)
    }

    func testStartupConflictIsVisibleAndCanBeRetried() {
        let registrar = FakeRegistrar()
        registrar.rejected = .defaultValue
        let service = GlobalHotKeyService(defaults: defaults(), registrar: registrar)
        service.start {}
        XCTAssertTrue(service.isEnabled)
        XCTAssertFalse(service.isRegistered)
        XCTAssertEqual(service.error, .unavailable)
        registrar.rejected = nil
        service.retry()
        XCTAssertNil(service.error)
        XCTAssertTrue(service.isRegistered)
    }

    func testInvalidStoredCombinationFallsBackAndValidationCopyDefaultsOff() throws {
        let defaults = defaults()
        defaults.set(try JSONEncoder().encode(LauncherHotKey(keyCode: 999, modifiers: 0)),
                     forKey: GlobalHotKeyService.shortcutKey)
        let service = GlobalHotKeyService(defaults: defaults, registrar: FakeRegistrar(), enabledByDefault: false)
        XCTAssertEqual(service.hotKey, .defaultValue)
        XCTAssertFalse(service.isEnabled)
    }

    func testQueuedOldCallbackCannotInvokeAfterRecordingOrDisable() {
        let registrar = FakeRegistrar()
        let service = GlobalHotKeyService(defaults: defaults(), registrar: registrar)
        var invocations = 0
        service.start { invocations += 1 }
        let beforeRecording = registrar.action
        service.beginRecording()
        service.cancelRecording()
        beforeRecording?()
        XCTAssertEqual(invocations, 0)
        let beforeDisable = registrar.action
        service.setEnabled(false)
        service.setEnabled(true)
        beforeDisable?()
        XCTAssertEqual(invocations, 0)
        registrar.action?()
        XCTAssertEqual(invocations, 1)
    }

    func testExclusiveNativeRegistrationRejectsDuplicateAndReleasesOnStop() throws {
        let first = CarbonHotKeyRegistrar()
        let second = CarbonHotKeyRegistrar()
        defer { first.unregister(); second.unregister() }
        // An unusual chord avoids ordinary user shortcuts. No keyboard events are generated.
        let key = LauncherHotKey(keyCode: UInt32(kVK_F19), modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey))
        try first.register(key) {}
        XCTAssertThrowsError(try second.register(key) {}) { error in
            XCTAssertEqual(error as? GlobalHotKeyError, .unavailable)
        }
        first.unregister()
        XCTAssertNoThrow(try second.register(key) {})
    }
}

@MainActor
private final class FakeRegistrar: GlobalHotKeyRegistering {
    var active: LauncherHotKey?
    var rejected: LauncherHotKey?
    var action: (() -> Void)?
    func register(_ hotKey: LauncherHotKey, action: @escaping () -> Void) throws {
        if rejected == hotKey { throw GlobalHotKeyError.unavailable }
        active = hotKey
        self.action = action
    }
    func unregister() { active = nil; action = nil }
}
