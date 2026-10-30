import Foundation

/// Pure state machine for launcher visibility around Dock reopen/activation.
/// Keeping this independent of AppKit makes the event ordering testable.
struct LauncherVisibilityState {
    enum Action: Equatable {
        case none
        case hide
    }

    private(set) var hasPendingShow = false

    /// A global shortcut explicitly requests a show, even if the panel was already visible.
    mutating func requestShow() { hasPendingShow = true }

    /// Dock reopen should never synchronously show a hidden launcher. Instead,
    /// queue a show request and let the app delegate service it on the next main
    /// run-loop turn once the application is actually active.
    mutating func handleDockReopen(isLauncherVisible: Bool) -> Action {
        if isLauncherVisible {
            hasPendingShow = false
            return .hide
        }

        hasPendingShow = true
        return .none
    }

    /// Losing activation always hides the panel, but deliberately preserves a
    /// pending Dock-requested show. This absorbs late resign notifications from
    /// the previous activation cycle without losing the user's click.
    mutating func handleDidResignActive() -> Action {
        .hide
    }

    /// Called from a deferred main-run-loop task. A pending show is consumed
    /// only if the application is truly active at that moment.
    mutating func consumePendingShowIfActive(_ isApplicationActive: Bool) -> Bool {
        guard hasPendingShow, isApplicationActive else { return false }
        hasPendingShow = false
        return true
    }

    mutating func cancelPendingShow() {
        hasPendingShow = false
    }
}
