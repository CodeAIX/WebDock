# WebDock v0.1 Implementation Plan

## Milestone 0 — Project bootstrap

- Create a macOS App Xcode project named `WebDock`.
- Deployment target: macOS 14.0.
- Bundle identifier: `io.github.codeaix.WebDock`.
- Add unit test target `WebDockTests`.
- Prefer SwiftData and SwiftUI; keep AppKit controllers in separate files.
- Do not create a normal default WindowGroup on app launch.
- Add GitHub Actions build/test workflow after the project builds locally.

Exit criteria:

- Empty app builds.
- App icon can be placed in Dock.
- Clicking Dock while running is observable through AppDelegate.

## Milestone 1 — Domain model and storage

Implement:

- `WebShortcut`
- `ShortcutGroup`
- `ShortcutSourceType`
- `ShortcutLaunchMode`
- `ManagedStorage`
- `ImportTransaction`

Storage root:

`~/Library/Application Support/WebDock/`

Exit criteria:

- Unit tests create/delete temp managed directories.
- SwiftData can persist/reload shortcuts.

## Milestone 2 — Importers

Implement importer protocol and adapters:

1. `ChromeWeblocImporter`
2. `WeblocImporter`
3. `InternetShortcutImporter`
4. `URLImporter`

Important:

- Parse `.crwebloc` with `PropertyListSerialization`.
- Validate `URL` + `CrProfile`.
- Preserve the original file.
- Do not synthesize Chrome CLI profile flags for launch.

Exit criteria:

- Fixture tests cover XML and binary plist.
- Import transaction removes source from original location only after managed copy/move is safe.

## Milestone 3 — Launch service

Introduce a `WorkspaceOpening` protocol wrapping `NSWorkspace`.

Implement launch modes:

- original managed shortcut file
- default browser URL
- specified browser URL
- external `.app`

Exit criteria:

- Unit tests assert correct workspace method for each launch mode.
- Manual `.crwebloc` test opens the correct Chrome profile.

## Milestone 4 — Dock integration and Launcher Panel

Implement:

- `AppDelegate`
- reopen toggle
- `DockPositionResolver`
- `LauncherPanelController`
- borderless `NSPanel`
- `NSVisualEffectView.Material.popover`
- hide on deactivate
- Esc to close

Exit criteria:

- App launch shows panel.
- repeated Dock click toggles panel.
- panel stays on visible screen.
- bottom/left/right Dock positioning behaves acceptably.

## Milestone 5 — Launcher UI

Implement:

- adaptive grid
- shortcut tile
- search
- keyboard navigation
- click launch
- drag reorder
- empty state

Exit criteria:

- 100 fake shortcuts render smoothly.
- order persists.

## Milestone 6 — Manager UI

Implement:

- manager window
- list/grid
- rename
- URL edit for normalized shortcuts
- browser override
- delete
- group assignment
- reveal managed source in Finder

Exit criteria:

- destructive operations respect Trash/transaction rules.

## Milestone 7 — Dock file drop registration

Configure document/imported types and confirm Finder -> Dock icon import.

Use `mdls` on real sample files to verify UTIs before final Info.plist declarations.

Fixtures to test manually:

- Chrome `.crwebloc`
- Safari/Finder `.webloc`
- `.url`

Exit criteria:

- Works with app stopped and already running.

## Milestone 8 — Polish

- Light/dark/system appearance
- Reduce Motion
- Reduce Transparency fallback
- VoiceOver labels
- context menus
- onboarding notice
- duplicate import UX
- OSLog categories

## Milestone 9 — Experimental `.app` adapter

Only after MVP acceptance passes.

- Detect `.app` bundles.
- Store external reference.
- Launch with `NSWorkspace`.
- Never auto-delete external app in v0.1.
