# WebDock Test Plan — M9

## Automated unit tests

### Canonical model
- only valid HTTP/HTTPS URLs accepted
- BrowserFamily persists
- account email is trimmed/lowercased
- unsupported/default browser rules do not retain irrelevant account identity
- canonical tombstone deletion persists

### Account matching
- email match succeeds regardless of local Profile number
- email comparison is case-insensitive
- zero matches -> none
- duplicate matches -> ambiguous
- Gmail dots/plus aliases are not rewritten

### Device resolution
- exact account match resolves local Profile directory
- missing account -> preferred browser default + warning
- ambiguous account -> preferred browser default + warning
- missing browser -> system default + warning
- valid device override takes precedence
- override is stored only in DeviceShortcutBinding

### Launching
- system default opens URL normally
- resolved Chromium profile writes transient URL + CrProfile route
- missing account opens URL in preferred browser without profile route
- disappearance of browser between resolution/click falls back safely

### Sync
- snapshot contains BrowserFamily/account email
- snapshot never contains local profile directory or DeviceShortcutBinding
- UUID identity merges per-record by updatedAt
- tombstones merge like normal records
- groups/order round-trip

### Persistence
- canonical shortcut survives local SwiftData reload
- DeviceShortcutBinding can persist locally without appearing in sync snapshot

## CI contract

Every branch/PR must:
- validate Info.plist
- assert no `.crwebloc`, `.webloc`, `.url` document handlers
- assert WebDock is not an HTTP/HTTPS handler
- validate iCloud entitlement plist
- generate Xcode project
- compile app/tests
- pass tests

Release smoke build must additionally:
- build Release app
- validate built Info.plist
- ad-hoc sign with configured entitlements
- verify signature/bundle
- package and integrity-check ZIP

## Real-Mac acceptance

### Core launcher
1. fresh v0.2 starts with no legacy shortcuts
2. create via Launcher `+`
3. create via Manager `+`
4. reorder and verify persistence after restart
5. edit/delete and verify UI state
6. outside-click/Dock-reopen behavior remains correct

### Account routing
On Mac A:
1. choose Chrome + a readable signed-in account email
2. verify resolution shows the local Profile directory/account
3. launch into the correct normal Chrome tab/profile

Missing-account scenario:
1. set target email not present locally
2. verify warning badge/editor warning
3. launch still succeeds in Chrome default profile

Ambiguous scenario:
1. if reproducible, same email in multiple profiles
2. verify ambiguous warning
3. choose a device-only override
4. verify launch uses selected local profile without changing canonical email

Missing-browser scenario:
1. choose browser family unavailable on the Mac
2. verify warning
3. verify URL opens in system default browser

## Two-Mac sync acceptance

Prerequisite: both builds signed/provisioned for `iCloud.io.github.codeaix.WebDock` and signed into iCloud.

1. Mac A Chrome: `account@example.com -> Profile 12`
2. Mac B Chrome: same email -> `Profile 3`
3. create shortcut on A with Chrome + `account@example.com`
4. sync to B
5. verify B canonical record contains email, not Profile 12
6. verify B resolves locally to Profile 3
7. launch and verify correct account
8. reorder/edit/delete on either Mac and verify propagation
9. verify a device-only override on B does not modify A

## WebDAV future gate

Before enabling WebDAV:
- same canonical snapshot encoder/merge engine reused
- credentials stored in Keychain
- ETag/If-Match conflict handling tested
- no Profile N/device binding in payload
- sync errors never corrupt local canonical data
