# Architecture Decisions

## ADR-001 — Native SwiftUI + AppKit
Status: Accepted.

WebDock depends on Dock lifecycle, `NSPanel`, `NSWorkspace`, and native macOS behavior. Keep the app native; no Electron/Tauri/WebView.

## ADR-002 — Use NSPanel for the launcher
Status: Accepted.

There is no supported API to anchor an NSPopover precisely to a Dock tile. WebDock positions an NSPanel near the Dock edge using public screen geometry.

## ADR-003 — Preserve Chrome `.crwebloc`
Status: Superseded.

Historical only. The product no longer imports browser shortcut files. Transient `.crwebloc` may still be generated internally at launch time to route a URL to a resolved Chromium profile.

## ADR-004 — No App Sandbox for direct/private distribution
Status: Accepted for current distribution.

Browser profile discovery and direct distribution are simpler without App Sandbox. Revisit if Mac App Store distribution becomes a goal.

## ADR-005 — External browser Web Apps
Status: Deferred.

WebDock launches normal browser tabs/windows. Browser-managed standalone web apps are outside the current core model.

## ADR-006 — SwiftData local persistence
Status: Accepted.

SwiftData stores canonical shortcuts/groups plus device-local bindings. M9 deliberately starts a fresh named store because all pre-M9 user data is test-only and no migration is required.

## ADR-007 — Imported files as canonical inputs
Status: Superseded by ADR-010.

Import-era behavior is removed from the product and source tree.

## ADR-008 — Imported source cleanup
Status: Superseded by ADR-010.

There are no browser shortcut-file imports, managed source files, staging transactions, or source cleanup flows in M9.

## ADR-009 — Shortcut creation belongs to Launcher/Manager
Status: Accepted.

Primary creation surfaces are Launcher `+` and Manager `+`; future `File > New Shortcut` / `⌘N` may call the same creation service. Settings contains global preferences, not shortcut content creation.

## ADR-010 — Manual-first portable launch rules
Status: Accepted.

The canonical WebShortcut is portable user intent:

`URL + BrowserFamily + optional Account Email + name/group/order`

WebDock does not register/import `.crwebloc`, `.webloc`, or `.url` files.

## ADR-011 — Account email is cross-device identity
Status: Accepted.

Chromium profile directories such as `Default`, `Profile 3`, or `Profile 12` are machine-local implementation details and must never be synced as account identity.

The portable account key is the browser's locally reported primary signed-in account email. Matching trims whitespace and compares normalized lowercase strings; Gmail-specific dot/plus rewriting is intentionally not performed.

## ADR-012 — Separate canonical intent from DeviceShortcutBinding
Status: Accepted.

Each Mac resolves a canonical shortcut against its own installed browsers/profile metadata. The resulting bundle identifier, local Profile directory, warning state, and device-only override live in `DeviceShortcutBinding` and never enter a sync payload.

Resolution degrades gracefully:
- missing account -> preferred browser default profile + warning;
- ambiguous account -> preferred browser default + warning until local override;
- missing browser -> system default browser + warning.

Warnings do not block launch.

## ADR-013 — Transient Chromium profile routing remains internal
Status: Accepted.

When a local Chromium profile has been resolved, WebDock creates a transient runtime `.crwebloc` containing the current URL and `CrProfile`, then explicitly opens it with the resolved browser. This file is cache/runtime state only and is neither imported nor synced.

## ADR-014 — Provider-independent sync snapshots
Status: Accepted.

Sync payloads contain only canonical shortcut/group records. Stable UUIDs identify records; `updatedAt` participates in conflict merge and `deletedAt` tombstones prevent offline resurrection.

`DeviceShortcutBinding` is explicitly excluded.

## ADR-015 — iCloud first, WebDAV second
Status: Accepted.

iCloud/CloudKit private database is the first sync provider and uses container `iCloud.io.github.codeaix.WebDock`.

WebDAV is planned against the same serialized snapshot model. Credentials must live in Keychain and conditional ETag/If-Match writes must be used before WebDAV is enabled.
