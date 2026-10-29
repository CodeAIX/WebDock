# WebDock Implementation Plan — M9+

## M9.1 — Manual-first core
- remove `.crwebloc/.webloc/.url` LaunchServices registrations
- remove import coordinator/transaction/managed-source code
- fresh SwiftData schema/store; no migration of test-era data
- canonical WebShortcut = URL + BrowserFamily + optional account email + metadata
- Launcher/Manager `+` creation

## M9.2 — Device resolution
- discover Chromium profile/account metadata locally
- resolve account email to local Profile directory
- missing account -> browser default + warning
- ambiguous account -> browser default + warning
- missing browser -> system default + warning
- device-only browser/profile override
- launcher warning badge and Manager `This Mac` status

## M9.3 — Sync core
- provider-independent Codable canonical snapshot
- stable UUIDs + updatedAt merge
- deletedAt tombstones
- explicitly exclude DeviceShortcutBinding from payload
- CloudKit private-database provider
- Settings provider selector/status/manual sync

## M9.4 — iCloud real-device validation
Prerequisite: Apple Developer CloudKit container `iCloud.io.github.codeaix.WebDock` and signed provisioning.

Validate on two Macs:
- create/edit/order/delete propagation
- same email mapped to different local Profile N values
- local override remains local
- missing-account warning/fallback
- offline/reconnect tombstone behavior

## M10 — Product polish
- favicon/icon cache
- groups
- keyboard navigation/accessibility
- app icon
- sync diagnostics/conflict UI
- File > New Shortcut / Cmd-N

## M11 — WebDAV provider
- reuse canonical snapshot + merge engine
- Keychain credentials
- ETag/If-Match conditional writes
- robust offline/retry behavior
- optional client-side payload encryption

## Release gates
Every implementation milestone requires:
- macOS CI green
- Release smoke build green
- no shortcut-file document handlers
- no local Profile N in sync payload
- real-Mac acceptance for affected user-facing behavior
