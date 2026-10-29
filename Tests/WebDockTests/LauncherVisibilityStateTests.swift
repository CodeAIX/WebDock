import XCTest
@testable import WebDock

final class LauncherVisibilityStateTests: XCTestCase {
    func testDockClickOnVisibleLauncherRequestsHide() {
        var state = LauncherVisibilityState()

        let action = state.handleDockReopen(isLauncherVisible: true)

        XCTAssertEqual(action, .hide)
        XCTAssertFalse(state.hasPendingShow)
    }

    func testDockClickOnHiddenLauncherDefersShowUntilActive() {
        var state = LauncherVisibilityState()

        let action = state.handleDockReopen(isLauncherVisible: false)

        XCTAssertEqual(action, .none)
        XCTAssertTrue(state.hasPendingShow)
        XCTAssertFalse(state.consumePendingShowIfActive(false))
        XCTAssertTrue(state.hasPendingShow)
        XCTAssertTrue(state.consumePendingShowIfActive(true))
        XCTAssertFalse(state.hasPendingShow)
    }

    func testLateResignDoesNotCancelPendingDockShow() {
        var state = LauncherVisibilityState()

        _ = state.handleDockReopen(isLauncherVisible: false)
        XCTAssertTrue(state.hasPendingShow)

        XCTAssertEqual(state.handleDidResignActive(), .hide)
        XCTAssertTrue(state.hasPendingShow)

        XCTAssertFalse(state.consumePendingShowIfActive(false))
        XCTAssertTrue(state.hasPendingShow)
        XCTAssertTrue(state.consumePendingShowIfActive(true))
        XCTAssertFalse(state.hasPendingShow)
    }

    func testVisibleDockToggleCancelsPendingShow() {
        var state = LauncherVisibilityState()

        _ = state.handleDockReopen(isLauncherVisible: false)
        XCTAssertTrue(state.hasPendingShow)

        XCTAssertEqual(state.handleDockReopen(isLauncherVisible: true), .hide)
        XCTAssertFalse(state.hasPendingShow)
    }
}
