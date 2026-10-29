# WebDock Sync, Backup & Device Resolution

Status: authoritative architecture for WebDock 0.3+

## 1. Product definition

WebDock is a local-first, cross-device website launch-rule manager for macOS 13+.

The primary workflow is manual creation/editing. Browser-exported shortcut files (`.crwebloc`, `.webloc`, `.url`) are not product inputs.

The canonical object is portable launch intent:

```text
WebShortcut
  id: UUID
  name
  HTTP(S) URL
  preferredBrowserFamily?
  targetAccountEmail?
  groupID?
  sortIndex
  createdAt / updatedAt / deletedAt
```

## 2. Portable vs device-local data

Portable data describes **what the user wants** and may be exported/synchronized.

Device-local data describes **how this Mac satisfies the rule**:

```text
DeviceShortcutBinding
  shortcutID
  resolvedBrowserBundleIdentifier
  resolvedProfileDirectory        // Default / Profile N
  resolvedAccountEmail
  resolutionStatus / warning
  local browser/profile overrides
  updatedAt
```

`DeviceShortcutBinding` never appears in portable backups, Synced Folder data, or WebDAV data.

## 3. Account identity across Macs

Never synchronize Chromium profile directories such as `Default`, `Profile 3`, or `Profile 12`.

Portable Chromium account identity is the locally reported primary signed-in account email.

Matching rules:
1. trim whitespace;
2. lowercase for comparison;
3. exact email identity after normalization;
4. no Gmail dot removal or `+tag` rewriting.

Example:

```text
Mac A: foo@example.com -> Profile 12
portable rule: foo@example.com
Mac B: foo@example.com -> Profile 3
result on Mac B: launch Profile 3
```

## 4. Device resolution

1. Resolve BrowserFamily to an installed browser.
2. Missing browser -> system default browser + local warning.
3. No target email -> selected browser's normal default/last-used profile.
4. One matching email -> that local profile.
5. Zero matches -> browser default + `missingAccount` warning.
6. Multiple matches -> browser default + `ambiguousAccount` warning until a local override is selected.
7. Per-Mac overrides are stored only in DeviceBindings.

## 5. Browser account access

On macOS versions that protect other applications' data, reading Chromium profile metadata may require user approval in Privacy & Security > Files & Folders.

WebDock:
- explains why profile metadata is needed;
- can initiate a profile read so macOS can present its permission flow;
- shows per-browser access/rescan status;
- provides a best-effort shortcut to Privacy & Security;
- cannot grant or toggle the OS permission itself.

WebDock reads profile metadata only. It does not read cookies, browsing history, saved passwords, tokens, or page content.

## 6. Local storage

WebDock uses Codable JSON instead of SwiftData:

```text
Application Support/WebDock/
  Canonical.json
  DeviceBindings.json
  Backups/
  Cache/
```

Writes use atomic replacement. This avoids a macOS 14-only persistence dependency and keeps the portable model directly inspectable.

## 7. Backup model

### Automatic/local snapshots

Full local snapshots may contain canonical data plus DeviceBindings. WebDock creates at most one automatic snapshot per day and keeps the newest 20 automatic snapshots.

Additional safety snapshots are created before restore and before a sync merge changes local canonical data.

### Portable export

`.webdockbackup` contains:
- format/schema metadata;
- canonical shortcuts/groups/tombstones;
- browser family and account email;
- ordering.

It excludes DeviceBindings and all local `Profile N` values.

Restore modes:
- **Replace Current Library** — replace canonical data; portable backups intentionally reset device bindings so the destination Mac resolves accounts afresh.
- **Merge with Current Library** — stable UUID merge using newest-record-wins semantics, including tombstones.

## 8. Sync provider policy

Exactly one provider may be active:

```text
Off
Synced Folder
WebDAV
```

There is no Apple cloud entitlement/provider in WebDock.

### Synced Folder

The user selects an ordinary directory. WebDock reads/writes:

```text
WebDockSync.json
```

The directory may itself be transported by iCloud Drive, Dropbox, OneDrive, Syncthing, NAS tools, or another filesystem synchronization product. This is ordinary file synchronization; WebDock does not integrate with the cloud provider API.

### WebDAV

- user supplies an existing WebDAV folder URL;
- username stored in preferences;
- password/app-password stored in macOS Keychain;
- `GET WebDockSync.json` reads remote canonical state;
- `PUT WebDockSync.json` uses `ETag` plus `If-Match`, or `If-None-Match: *` for first creation;
- HTTP 412 is treated as a conflict and triggers a fresh merge attempt;
- DeviceBindings are never uploaded.

HTTPS is recommended for remote WebDAV servers.

## 9. Conflict and deletion model

Every canonical object has a stable UUID and `updatedAt`.

Initial merge policy:
- different UUIDs merge;
- same UUID -> newer `updatedAt` wins;
- deletion is represented by a `deletedAt` tombstone and participates in the same rule.

This prevents stale replicas from resurrecting deleted shortcuts.

## 10. Privacy boundary

Portable data may contain target account email because deterministic account resolution requires it.

Never export/synchronize:
- cookies;
- browser history;
- passwords or tokens;
- browser profile folders/config files;
- `Default` / `Profile N` directories;
- local warnings/overrides;
- runtime cache.

WebDAV password is stored in Keychain and never written to canonical JSON or backup files.

## 11. Critical acceptance scenario

Mac A:

```text
ChatGPT
https://chatgpt.com/
Browser: Chrome
Account: foo@example.com
local directory: Profile 12
```

After Synced Folder or WebDAV sync to Mac B:

```text
foo@example.com exists locally as Profile 3
```

Expected:

```text
WebDock -> Chrome -> Profile 3 -> normal ChatGPT tab
```

If Mac C has Chrome but no `foo@example.com` profile:

```text
WebDock -> Chrome default profile -> ChatGPT
```

and the shortcut shows a visible missing-account warning.

## 12. Platform acceptance

- deployment target macOS 13.0+
- universal `arm64 + x86_64` release artifact
- real acceptance target includes Intel macOS 13.6.9 and a current Apple Silicon Mac
- no SwiftData dependency
- no macOS 14-only UI without fallback
