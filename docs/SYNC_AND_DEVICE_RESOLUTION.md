# WebDock Manual-First Sync & Device Resolution

Status: proposed architecture for M9 / Issue #20

## 1. Product definition

WebDock is a local-first, cross-device website launch-rule manager for macOS.

The primary workflow is manual creation and editing. Browser-exported shortcut files (`.crwebloc`, `.webloc`, `.url`) are no longer a product input surface.

Primary creation surfaces:

- Launcher `+`
- Manager `+`
- `File > New Shortcut` / `⌘N`
- optional future URL paste, browser-address drag, Share Extension, or browser extension

The canonical product object is a portable launch intent, not a local browser profile path.

## 2. Two-layer model

### 2.1 Synced shortcut intent

This data may sync between Macs:

```text
SyncedShortcut
  id: UUID
  name: String
  url: HTTP(S) URL
  preferredBrowserFamily: BrowserFamily?
  preferredAccountEmail: String?
  groupID: UUID?
  orderKey: String/Double
  customIconReference/payload: optional
  createdAt
  modifiedAt
  deletion/tombstone metadata
```

The synced layer describes **what the user wants**.

### 2.2 Device-local binding

This data never becomes canonical cross-device state:

```text
DeviceShortcutBinding
  shortcutID: UUID
  resolvedBrowserBundleIdentifier: String?
  resolvedBrowserApplicationURL: URL?
  resolvedProfileDirectory: String?    // Default / Profile N
  resolvedAccountEmail: String?
  resolvedAccountDisplayName: String?
  resolutionStatus: ResolutionStatus
  localOverrideProfileDirectory: String?
  lastResolvedAt: Date
```

The device layer describes **how this Mac can satisfy the intent**.

## 3. Browser identity

Do not use local application paths as synchronized identity.

Use a stable browser family enum, for example:

```text
systemDefault
safari
chrome
chromeBeta
chromeDev
chromeCanary
chromium
edge
brave
vivaldi
firefox
arc
```

Each Mac maps that family to an installed application/bundle identifier.

If the preferred browser is unavailable, WebDock opens the URL with the system default browser and records `missingBrowser` locally.

## 4. Account identity across devices

A Chromium profile directory such as `Default`, `Profile 3`, or `Profile 12` is local installation state and must never be synchronized as the canonical account identity.

For Chromium-family browsers, the portable account identity is the primary signed-in account email.

Email comparison rules:

1. trim surrounding whitespace;
2. normalize case for comparison;
3. compare exact email identity after normalization;
4. do not apply provider-specific transformations such as Gmail dot removal or `+tag` removal.

The local profile directory remains only a cache/output of resolution.

Example:

```text
Mac A
  foo@example.com -> Profile 12

Synced intent
  preferredAccountEmail = foo@example.com

Mac B
  foo@example.com -> Profile 3

Result
  WebDock on Mac B launches Profile 3.
```

## 5. Device resolution algorithm

For each shortcut:

### Browser resolution

1. Resolve the preferred browser family to an installed browser.
2. If not installed, set `missingBrowser` and use the macOS default browser.

### Account resolution

If no account is requested, use the selected browser's normal default/last-used behavior.

If an account email is requested:

1. enumerate supported local browser profiles;
2. find profiles whose primary signed-in email matches the requested email;
3. exactly one match -> bind to that profile directory (`resolved`);
4. zero matches -> use browser default/last-used behavior (`missingAccount`);
5. multiple matches -> use browser default/last-used behavior (`ambiguousAccount`) until a local override is selected.

Never silently choose one of multiple matches based only on profile number or local name.

## 6. Device-only overrides

A shortcut may need a different local binding without changing its cross-device meaning.

Examples:

- corporate account is named differently on one managed Mac;
- the same email exists in two local Chrome profiles;
- one Mac should intentionally use a different local profile.

Provide an action:

> Use a different account/profile on this Mac

The resulting mapping is stored only in `DeviceShortcutBinding`.

Editing the synchronized target account should be a separate explicit action:

> Change account on all synced devices

This prevents accidental global changes caused by one device's local configuration.

## 7. Warning and fallback UX

Resolution failure does not make a shortcut unusable.

### `missingAccount`

Launch behavior:

- open the preferred browser using its default/last-used profile.

UI:

- yellow warning icon next to Account;
- message: `Account foo@example.com is not available on this Mac. WebDock is using the browser default.`
- actions: `Choose for This Mac…` and `Change Synced Account…`.

### `ambiguousAccount`

Launch behavior:

- use browser default/last-used profile until the user chooses a local binding.

UI:

- warning explaining multiple profiles match;
- action: `Choose Profile for This Mac…`.

### `missingBrowser`

Launch behavior:

- system default browser.

UI:

- warning: `Preferred browser is not installed on this Mac. Using system default.`

### Surfaces

- shortcut editor: full warning text;
- Launcher: optional subtle warning badge;
- Settings > Sync & Device Resolution: aggregate unresolved items for the current Mac.

## 8. Sync provider policy

Support exactly one active provider at a time:

```text
Off
iCloud
WebDAV
```

The domain model must remain provider-independent.

### 8.1 iCloud

Recommended first implementation.

Reasons:

- no server URL/account setup inside WebDock;
- natural fit for a macOS-only personal utility;
- Apple's CloudKit stack provides private per-user cloud storage and change synchronization.

Only `SyncedShortcut`, groups, ordering, tombstones, and explicitly synchronized custom assets belong in cloud state.

`DeviceShortcutBinding` stays in a separate local-only store.

Implementation should prefer an explicit sync boundary rather than allowing machine-local fields to leak into a CloudKit-backed model.

### 8.2 WebDAV

Advanced/self-hosted provider added after iCloud is stable.

Requirements:

- URL + username/app-password configuration;
- credentials stored in Keychain only;
- same portable record schema as iCloud;
- conditional writes with ETag / `If-Match` to avoid blind overwrite;
- optional client-side encryption for the synchronized payload;
- no browser cookies/passwords/profile files are uploaded.

Switching sync providers must never change shortcut semantics.

## 9. Privacy model

The minimum synchronized personal account identifier is the target account email because cross-device account matching depends on it.

Do not synchronize:

- cookies;
- browser history;
- passwords;
- tokens;
- Chrome profile folders;
- local browser config files;
- local `Profile N` directory names;
- favicon cache;
- local resolution warnings/overrides.

A future privacy mode may store a derived account match key rather than plaintext email, but the first implementation should prioritize deterministic matching, clear UX, and transport security.

## 10. Conflict model

Every synchronized object has a stable UUID.

Deletion uses tombstones so offline Macs do not resurrect removed shortcuts.

Initial conflict policy:

- changes to different records merge automatically;
- ordering uses stable order keys rather than device-local array offsets;
- simultaneous edits to the same shortcut must not silently discard user data;
- keep a recoverable conflict copy or surface an explicit conflict notice if both versions changed from the same base.

For WebDAV, ETag-based conditional writes are required to detect remote modification rather than using modification time alone.

## 11. Legacy migration and removal of import support

The final manual-first release removes:

- `.crwebloc` document registration;
- `.webloc` document registration;
- `.url` document registration;
- Finder -> Dock shortcut-file import;
- ImportCoordinator/importer UI flows;
- managed shortcut source files as runtime assets.

Existing user data must be migrated before those compatibility paths are removed.

### Existing normalized shortcuts

Keep URL/name/browser information. Convert the current selected profile directory into an account email using local browser metadata when possible.

### Existing legacy `originalShortcutFile`

1. parse the managed original once during migration;
2. extract URL + local browser/profile information;
3. resolve profile directory to account email when possible;
4. save the new canonical portable rule;
5. preserve a reversible legacy backup for one release;
6. stop using the original file for launch.

If the old profile cannot be mapped to an email, migrate the URL/browser and leave account unset; show a one-time account-selection warning instead of blocking launch.

## 12. Settings information architecture

### General

- Launcher behavior
- default browser for new shortcuts
- default account for new shortcuts (optional)

### Sync

- provider: Off / iCloud / WebDAV
- sync status
- last successful sync
- provider-specific configuration
- `Sync Now`

### Device Resolution

- installed/detected browsers
- detected accounts
- unresolved shortcut count
- list of `missingBrowser`, `missingAccount`, and `ambiguousAccount` shortcuts
- local bindings/overrides

### Privacy

- whether account emails are shown in UI
- WebDAV encryption settings when implemented
- clear local favicon/cache data

## 13. Recommended implementation sequence

1. Remove shortcut-file import UI and LaunchServices document declarations.
2. Migrate old records to manual-first canonical shortcuts.
3. Introduce `BrowserFamily` and remove profile directory from portable identity.
4. Add local `DeviceShortcutBinding` and account-email resolver.
5. Add missing/ambiguous account and missing-browser fallback UX.
6. Add device-only overrides.
7. Add iCloud sync.
8. Test two-Mac scenario with intentionally different Chrome profile numbers.
9. Add WebDAV provider after iCloud behavior is stable.
10. Add optional encrypted WebDAV payload support.

## 14. Critical acceptance scenario

Mac A:

```text
Shortcut: ChatGPT
URL: https://chatgpt.com/
Browser: Chrome
Account: foo@example.com
Local Chrome directory: Profile 12
```

After sync to Mac B:

```text
foo@example.com exists as Profile 3
```

Expected:

```text
WebDock -> Chrome -> local Profile 3 -> normal ChatGPT browser tab
```

If Mac C has Chrome but no `foo@example.com` profile:

```text
WebDock -> Chrome default profile -> ChatGPT
```

and the shortcut editor must display a visible warning that `foo@example.com` is unavailable on this Mac.
