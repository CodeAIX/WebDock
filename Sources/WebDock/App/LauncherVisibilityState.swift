import Foundation

/// Pure state machine for launcher visibility around Dock reopen/activation.
/// Keeping this independent of AppKit makes the event ordering testable.
struct LauncherVisibilityState {
    enum Action: Equatable {
        case none
        case show
        case hide
    }

    private(set) var showAfterActivation = false

    mutating func handleDockReopen(
        isApplicationActive: Bool,
        isLauncherVisible: Bool
    ) -> Action {
        if isLauncherVisible {
            showAfterActivation = false
            return .hide
        }

        if isApplicationActive {
            showAfterActivation = false
            return .show
        }

        // A Dock click can arrive while the app is still inactive. Do not show
        // the panel yet: showing and activating in the same callback can race
        // with the previous deactivation cycle. Wait for didBecomeActive.
        showAfterActivation = true
        return .none
    }

    mutating func handleDidBecomeActive() -> Action {
        guard showAfterActivation else { return .none }
        showAfterActivation = false
        return .show
    }

    mutating func handleDidResignActive() -> Action {
        // Preserve a pending Dock-requested show across any late resign event;
        // the next didBecomeActive is the authoritative point to display.
        return .hide
    }

    mutating func cancelPendingShow() {
        showAfterActivation = false
    }
}
