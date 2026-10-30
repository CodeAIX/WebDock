# WebDock

WebDock is a native macOS website launcher that lives as one icon in the Dock.

Download [WebDock 0.5.0](https://github.com/CodeAIX/WebDock/releases/tag/v0.5.0) for macOS 13+,
Intel and Apple Silicon. The release provides DMG and ZIP packages, source and SHA-256 checksums.
Packages use ad-hoc signing; Developer ID signing and Apple notarization are not configured.

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

## Interface

Launcher keeps search, New, Library and Settings in a fixed bar above a remembered group sidebar.
Tiles show website icons, the resolved browser badge and account username; warnings keep fallbacks
launchable. Use ⌘F to search, ⌘N to create, ⌘1 for Launcher, ⌘2 for Library and ⌘, for Settings.
Right-click offers editing, duplication, icons, group movement and confirmed deletion. Keyboard
focus supports directional navigation. Reorder from unfiltered All Shortcuts.

The 0.5.1 candidate adds a global **⌃⌥W** (Control–Option–W) shortcut to open and focus Launcher
while another application is in front. WebDock must be running. Settings → General → Global
Shortcut lets you enable/disable, record another combination or restore the default. Include
Control, Option or Command with a key; Escape cancels recording. Changes stay on this Mac and
survive restart. Registration conflicts keep the previous shortcut and show a message.

Library uses four editor cards with explicit Save Changes and separate local override save.
Settings has six sidebar pages, theme, density, subtitle and badge preferences. Custom and automatic
icons travel in backup/sync JSON; all devices editing icons should use v0.4 because v0.3 writers
cannot retain unknown metadata. Real-device acceptance status is tracked in docs/UI_V04_STATUS.md.

### Chinese and English

Settings → General → Display Language offers Follow System (default), 简体中文 and English.
App content changes immediately and draft edits are retained; restart WebDock to fully update
macOS-owned menus and system dialogs. This preference belongs to each Mac and does not sync.
Version 0.5.0 includes the accepted globe-and-Dock icon, single Launcher focus indicator and
native File → New Shortcut / ⌘N command across Launcher, Library and Settings. The user confirmed
Intel macOS 13.6.9 validation passed and authorized this release. Evidence boundaries and additional
device scenarios are documented in docs/DEVICE_ACCEPTANCE.md.

## Browser account access

The 0.5.1 candidate adds full Settings row hit targets, a bookmark Library icon and local ICNS
customization of the running Dock/app-switcher icon. Finder keeps the installed icon so signed
bundle metadata remains untouched. See docs/V051_FEEDBACK.md for scope and validation status.

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
