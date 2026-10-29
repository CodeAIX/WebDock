# Architecture Decisions

## ADR-001 — Native SwiftUI + AppKit
Status: Accepted.

WebDock depends on Dock lifecycle, `NSPanel`, `NSWorkspace`, and native macOS behavior. Keep the app native; no Electron/Tauri/WebView.

## ADR-002 — Use NSPanel for the launcher
Status: Accepted.

There is no supported API to anchor an NSPopover precisely to a Dock tile. WebDock positions an NSPanel near the Dock edge using public screen geometry.

## ADR-003 — Preserve Chrome `.crwebloc`
Status: Superseded.

Historical only. The product does not import browser shortcut files. A transient `.crwebloc` may still be generated internally to route a URL to a resolved Chromium profile.

## ADR-004 — No App Sandbox for current direct distribution
Status: Accepted.

Browser profile discovery, arbitrary Synced Folder selection, and direct distribution are simpler without App Sandbox. Revisit only if Mac App Store distribution becomes a goal.

## ADR-005 — External browser Web Apps
Status: Deferred.

WebDock launches normal browser tabs/windows. Browser-managed standalone web apps are outside the core model.

## ADR-006 — SwiftData local persistence
Status: Superseded by ADR-016.

SwiftData required macOS 14 and no longer fits the macOS 13 support target.

## ADR-007 — Imported files as canonical inputs
Status: Superseded by ADR-010.

Import-era behavior is removed from the product and source tree.

## ADR-008 — Imported source cleanup
Status: Superseded by ADR-010.

There are no browser shortcut-file imports, managed source files, staging transactions, or source cleanup flows.

## ADR-009 — Shortcut creation belongs to Launcher/Manager
Status: Accepted.

Primary creation surfaces are Launcher `+` and Manager `+`; future `File > New Shortcut` / `⌘N` may call the same creation service. Settings contains global preferences, not shortcut content creation.

## ADR-010 — Manual-first portable launch rules
Status: Accepted.

Canonical WebShortcut is portable user intent:

`URL + BrowserFamily + optional Account Email + name/group/order`

WebDock does not register/import `.crwebloc`, `.webloc`, or `.url` files.

## ADR-011 — Account email is cross-device identity
Status: Accepted.

`Default`, `Profile 3`, and `Profile 12` are machine-local implementation details. The portable account key is the browser's locally reported signed-in account email. Matching trims whitespace and compares normalized lowercase strings; Gmail-specific dot/plus rewriting is intentionally not performed.

## ADR-012 — Separate canonical intent from DeviceShortcutBinding
Status: Accepted.

Each Mac resolves canonical intent against its own installed browsers/profile metadata. Local bundle identifier, Profile directory, warning state, and device-only override live in DeviceShortcutBinding and never enter portable backup/sync data.

Resolution degrades gracefully:
- missing account -> preferred browser default profile + warning;
- ambiguous account -> preferred browser default + warning;
- missing browser -> system default browser + warning.

## ADR-013 — Transient Chromium profile routing remains internal
Status: Accepted.

When a local Chromium profile is resolved, WebDock creates a transient runtime `.crwebloc` containing URL + `CrProfile`, then explicitly opens it with the resolved browser. This is runtime cache only.

## ADR-014 — Provider-independent canonical snapshots
Status: Accepted.

Portable backup and synchronization use the same canonical model. Stable UUIDs identify records; `updatedAt` drives initial conflict merge and `deletedAt` tombstones prevent stale resurrection. DeviceShortcutBinding is excluded.

## ADR-015 — Apple cloud provider
Status: Superseded by ADR-018.

The earlier Apple cloud provider design was abandoned. WebDock does not carry Apple cloud entitlements and does not depend on paid Apple developer capabilities for synchronization.

## ADR-016 — Codable JSON persistence for macOS 13+
Status: Accepted.

Local persistence is split into:

- `Canonical.json` — portable shortcuts/groups/tombstones;
- `DeviceBindings.json` — local browser/Profile resolution and overrides.

Atomic JSON writes replace SwiftData. This supports macOS 13 and makes the portable schema directly reusable by backup and sync providers.

## ADR-017 — Built-in backup and recovery
Status: Accepted.

WebDock provides:
- at most one automatic full local snapshot per day;
- retention of newest 20 automatic snapshots;
- manual full local snapshot;
- portable `.webdockbackup` export without DeviceBindings/Profile N;
- Replace and Merge restore;
- Pre-Restore and Pre-Sync safety snapshots.

## ADR-018 — Synced Folder and WebDAV are the sync providers
Status: Accepted.

Exactly one provider may be active: Off, Synced Folder, or WebDAV.

Synced Folder writes `WebDockSync.json` to an ordinary user-selected directory. The directory may independently be synchronized by iCloud Drive, Dropbox, OneDrive, Syncthing, NAS software, etc.; WebDock itself integrates with none of those provider APIs.

WebDAV uses the same canonical JSON schema. Passwords live in macOS Keychain and writes use ETag/`If-Match` conflict protection.

## ADR-019 — macOS owns browser-data permission
Status: Accepted.

WebDock may trigger profile metadata reads and provide permission guidance, but it cannot grant or toggle Files & Folders authorization. First-run onboarding and Settings must make this boundary explicit and provide Authorize/Rescan plus a Privacy & Security shortcut.

## ADR-020 — macOS 13+ Universal support
Status: Accepted.

Deployment target is macOS 13.0. Release smoke artifacts must contain arm64 and x86_64 slices. macOS 14-only framework/UI dependencies require removal or explicit compatibility fallback.
