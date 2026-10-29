# Real Mac Acceptance Notes

## Current manual status

- Finder/Dock import of `.crwebloc`: PASS after built-Info.plist + cold-start lifecycle fix.
- Launcher drag reorder: PASS after migration to `NSItemProvider` + `DropDelegate`.
- Manager: PASS.
- Safe delete to Trash: PASS.
- Launcher outside-click hide followed by a single Dock click: FAIL on the previous build; the current fix defers Dock-triggered show until the application is active on a later main run-loop turn.

## Regression sequence for Dock reactivation

1. Click Dock icon: Launcher appears.
2. Click outside Launcher: Launcher hides.
3. Click Dock icon once.
4. Expected: Launcher appears and remains visible.
5. Repeating Dock clicks while Launcher is visible should still toggle it off/on normally.

This sequence must be retested on the current smoke build before the launcher lifecycle milestone is considered complete.
