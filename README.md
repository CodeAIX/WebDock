# WebDock

WebDock is a native macOS website launcher that lives as one icon in the Dock.

Its core object is a **portable website launch rule** rather than a browser-exported shortcut file:

`URL + preferred browser family + optional account email + name/group/order`

Each Mac resolves that portable intent to its own installed browser and local profile. Chromium `Default` / `Profile N` directory names are machine-local implementation details and are never used as portable identity.

## Current product direction

- Manual creation/editing is the primary workflow (`+` in Launcher and Manager).
- `.crwebloc`, `.webloc`, and `.url` import is intentionally unsupported.
- Chrome/Chromium-family accounts are matched between Macs by signed-in account email.
- Missing account -> preferred browser default profile + warning.
- Missing browser -> system default browser + warning.
- Device-only browser/profile overrides never alter portable data.
- Local canonical data uses human-readable Codable JSON, not SwiftData.
- Automatic local snapshots and `.webdockbackup` export/restore are built in.
- Cross-device sync providers are **Synced Folder** and **WebDAV**.
- A Synced Folder may live in iCloud Drive, Dropbox, OneDrive, Syncthing, a NAS-mounted directory, or any other ordinary file-sync location. WebDock itself uses no Apple cloud service entitlement.

## UI v0.4

Launcher keeps search, New, Library and Settings in a fixed bar above a remembered group sidebar.
Tiles show website icons, the resolved browser badge and account username; warnings keep fallbacks
launchable. Use ⌘F to search, ⌘N to create, ⌘1 for Launcher, ⌘2 for Library and ⌘, for Settings.
Right-click offers editing, duplication, icons, group movement and confirmed deletion. Keyboard
focus supports directional navigation. Reorder from unfiltered All Shortcuts.

Library uses four editor cards with explicit Save Changes and separate local override save.
Settings has six sidebar pages, theme, density, subtitle and badge preferences. Custom and automatic
icons travel in backup/sync JSON; all devices editing icons should use v0.4 because v0.3 writers
cannot retain unknown metadata. Real-device acceptance status is tracked in docs/UI_V04_STATUS.md.

### Chinese and English

Settings → General → Display Language offers Follow System (default), 简体中文 and English.
App content changes immediately and draft edits are retained; restart WebDock to fully update
macOS-owned menus and system dialogs. This preference belongs to each Mac and does not sync.
Version 0.4.1 also includes the WebDock app icon and removes the overlapping Launcher focus frame.
Build 7 adds the native File → New Shortcut / ⌘N command across Launcher, Library and Settings.
The icon is accepted; remaining device acceptance and evidence collection are described in
docs/DEVICE_ACCEPTANCE.md.

## Browser account access

On newer macOS versions, the OS may require explicit Files & Folders permission before WebDock can read another browser's profile metadata. WebDock provides first-run guidance, per-browser Authorize/Rescan controls, and a shortcut to Privacy & Security. The system remains the authority that grants or revokes access.

WebDock reads only profile metadata needed to identify account names/emails and local profile directories. It does not read browser cookies, saved passwords, browsing history, tokens, or browser page content. Automatic icon discovery separately requests public website icon metadata without browser credentials.

## Backup and synchronization

Local storage:

- `Canonical.json` — portable shortcuts/groups/tombstones
- `DeviceBindings.json` — local browser/Profile resolution and overrides
- `Icons/` — normalized website icons addressed by content hash
- `Backups/` — automatic/manual safety snapshots

Portable `.webdockbackup` exports omit local Profile numbers and device overrides, so a backup restored on another Mac resolves account email to that Mac's own local profile.

Synchronization transports portable rules and referenced icon assets, excluding device bindings:

- **Synced Folder** -> `WebDockSync.json` in a user-selected folder
- **WebDAV** -> `WebDockSync.json` with ETag / conditional-write conflict detection; password stored in macOS Keychain

## Technology

- macOS 13 Ventura or later
- Universal binary: arm64 + x86_64
- Swift + SwiftUI + AppKit
- Codable JSON persistence
- `NSWorkspace` for external browser launches
- no Electron/Tauri
- no embedded browser/WebView
- no private Dock APIs or Accessibility hacks
- no Apple cloud entitlement

Build with Xcode 26 or later and XcodeGen; the icon source uses Apple's `.icon` format.
The deployment target remains macOS 13.0. A standalone ICNS and reproduction notes are in
Design/AppIcon/.

## Architecture docs

Start with:

1. `AGENTS.md`
2. `docs/SYNC_AND_DEVICE_RESOLUTION.md`
3. `docs/SPEC.md`
4. `docs/TEST_PLAN.md`
5. `docs/DECISIONS.md`

Repository: `CodeAIX/WebDock`
