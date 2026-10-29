# Launcher reactivation race fix

The launcher must not be shown synchronously from `applicationShouldHandleReopen` when it is currently hidden. A Dock click can overlap the tail end of an application deactivation cycle, so a late resign notification can otherwise hide a panel that was just shown.

The current contract is:

- Dock reopen while launcher is visible: hide immediately.
- Dock reopen while launcher is hidden: set a pending-show flag only.
- Service the pending show on a later main run-loop turn.
- Consume the pending show only when `NSApp.isActive == true`.
- `applicationDidResignActive` hides the launcher but does not cancel a pending Dock show.
- `applicationDidBecomeActive` schedules another attempt to service the pending show.
- `LauncherPanelController` never calls `NSApp.activate` and never owns app-activation notifications.

This keeps activation and window visibility as separate phases and makes AppDelegate the sole visibility owner.
