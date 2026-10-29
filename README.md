# WebDock

WebDock is a native macOS website launcher that lives as one icon in the Dock.

Its core object is a **portable website launch rule** rather than a browser-exported shortcut file:

`URL + preferred browser family + optional account email + name/group/order`

On each Mac, WebDock resolves that portable intent to the browser and local profile available on that device. Chromium `Profile N` directory names are local implementation details and are never used as cross-device identity.

## Current product direction

- Manual creation/editing is the primary workflow (`+` in Launcher and Manager).
- `.crwebloc`, `.webloc`, and `.url` import is intentionally not supported.
- Chrome/Chromium-family accounts are matched between Macs by signed-in account email.
- If a preferred account is missing, WebDock opens the preferred browser with its default profile and shows a warning.
- If a preferred browser is missing, WebDock opens the system default browser and shows a warning.
- Device-only browser/profile overrides never change the synced rule.
- iCloud/CloudKit is the first sync provider; WebDAV is planned against the same provider-independent snapshot schema.

## Privacy boundary

WebDock may read browser profile metadata required to map an account email to a local profile directory. It does not need cookies, passwords, history, or page content.

## Technology

- macOS 14+
- Swift + SwiftUI + AppKit
- SwiftData for local canonical data and device bindings
- CloudKit private database for portable sync snapshots
- `NSWorkspace` for external browser launches
- no Electron/Tauri
- no embedded browser/WebView
- no private Dock APIs or Accessibility hacks

## Architecture docs

Start with:

1. `AGENTS.md`
2. `docs/SYNC_AND_DEVICE_RESOLUTION.md`
3. `docs/SPEC.md`
4. `docs/TEST_PLAN.md`
5. `docs/DECISIONS.md`

Repository: `CodeAIX/WebDock`
