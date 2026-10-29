# WebDock Product Specification — Portable Backup & Sync Architecture

Status: active for v0.3.

## 1. Product

WebDock is a native macOS Dock launcher for portable website launch rules. Users manually create and edit shortcuts; browser-exported shortcut files are not part of the workflow.

Canonical shortcut intent:

`Name + HTTP/HTTPS URL + optional BrowserFamily + optional Account Email + Group + Order`

Each Mac resolves that intent into its own installed browser and local Chromium profile.

Supported platform: macOS 13.0+ on arm64 and x86_64.

## 2. Creation and editing

Primary creation surfaces:
- Launcher `+`
- Manager `+`
- future `File > New Shortcut` / `⌘N`

Editable fields:
- name
- URL
- preferred browser family
- target account email for supported Chromium-family browsers
- group/order when surfaced

WebDock does not register or import `.crwebloc`, `.webloc`, or `.url` files.

## 3. Portable browser/account identity

Browser intent uses BrowserFamily rather than an installation path or bundle instance.

Cross-device account identity is the signed-in account email reported in local Chromium profile metadata.

Never export/sync `Default`, `Profile 1`, `Profile 12`, or another local profile directory.

Email normalization:
- trim whitespace;
- lowercase for comparison;
- no Gmail-specific dot/plus canonicalization.

## 4. Device-local resolution

Each Mac stores DeviceShortcutBinding separately from canonical data.

Resolution order:
1. valid device-only override;
2. preferred browser installed + one matching email profile -> exact local profile;
3. browser installed but email absent -> browser default + `missingAccount` warning;
4. multiple local profiles with same email -> browser default + `ambiguousAccount` warning;
5. preferred browser missing -> system default + `missingBrowser` warning;
6. no preferred browser -> system default.

Fallbacks keep shortcuts launchable. Warnings do not block launch.

## 5. Browser account permission UX

WebDock may need macOS Files & Folders approval to read another browser's profile metadata.

Requirements:
- explain the request before attempting access;
- first-run Browser Account Access guidance;
- Settings > Browsers & Accounts lists installed supported browsers;
- per-browser Authorize/Rescan action;
- best-effort Open Privacy & Security shortcut;
- never claim WebDock can grant or toggle the system permission itself;
- `NSAppDataUsageDescription` explains the metadata-only use.

WebDock does not read cookies, passwords, browsing history, tokens, or page content.

## 6. Launch behavior

- system default -> open URL through macOS;
- selected browser without resolved profile -> explicitly open URL in that browser;
- Chromium browser with resolved local profile -> create a transient `URL + CrProfile` routing `.crwebloc` and explicitly open it with that local browser;
- transient routing files are runtime cache only and never portable data.

## 7. Local persistence

Persistence uses Codable JSON, not SwiftData.

```text
Application Support/WebDock/
  Canonical.json
  DeviceBindings.json
  Backups/
  Cache/
```

Canonical deletion writes `deletedAt` tombstones instead of immediately destroying record identity.

## 8. Backup & restore

Automatic backups:
- full local snapshot;
- at most one automatic snapshot per day;
- retain newest 20 automatic snapshots.

Safety backups:
- create a Pre-Restore snapshot before restore;
- create a Pre-Sync snapshot before applying remote changes.

Manual actions:
- Back Up Now;
- Export Portable Backup…;
- Restore from Backup…;
- Open Backup Folder.

Portable `.webdockbackup` contains canonical data only and excludes DeviceBindings/Profile N.

Restore modes:
- Replace Current Library;
- Merge with Current Library using stable UUID + newest-record-wins/tombstone semantics.

## 9. Sync contract

Exactly one provider may be active:
- Off
- Synced Folder
- WebDAV

Sync only canonical intent:
- shortcut/group UUID;
- name;
- URL;
- BrowserFamily;
- target account email;
- group/order;
- created/updated/deleted timestamps.

Never sync DeviceShortcutBinding, local bundle paths, Profile N, warning state, local overrides, runtime cache, browser credentials, or WebDAV password.

### Synced Folder

User selects an ordinary folder. WebDock reads/writes `WebDockSync.json`. The folder may independently be synchronized by iCloud Drive, Dropbox, OneDrive, Syncthing, NAS software, etc. WebDock has no Apple cloud entitlement/provider.

### WebDAV

- existing folder URL;
- username in preferences;
- password/app-password in macOS Keychain;
- canonical `WebDockSync.json` only;
- ETag / `If-Match` conditional writes;
- `If-None-Match: *` on first create;
- HTTP 412 triggers conflict reload/merge retry.

## 10. UI

Launcher (UI-1):
- fixed full-width content top bar, independent of sidebar visibility;
- persistent local sidebar visibility, initially shown, with All Shortcuts and existing groups;
- direct Settings and Library actions;
- ⌘N new shortcut, ⌘F search, ⌘, settings, ⌘1 Launcher, ⌘2 Library;
- Return launches a single matching result;
- search includes group names;
- search;
- `+` creation;
- persistent drag reorder in the unfiltered All Shortcuts view;
- subtle warning badge;
- click launch with fallback.

Manager:
- list/edit/delete;
- portable launch rule fields;
- `This Mac` resolution and device-only override.

Settings:
- Browsers & Accounts permission status/actions;
- Sync provider + provider-specific configuration + Sync Now;
- Backup & Restore actions;
- privacy/device-resolution explanation.

## 11. Acceptance

- macOS deployment target 13.0;
- universal arm64 + x86_64 Release artifact;
- no SwiftData dependency;
- no Apple cloud entitlement/provider;
- no browser shortcut-file import handler;
- manual creation/edit/reorder remains functional;
- account email, never Profile N, is portable identity;
- missing/ambiguous account and missing browser fall back with warnings;
- local override remains device-only;
- local JSON persists across restart;
- portable backup excludes DeviceBindings/Profile N;
- replace/merge restore works and creates safety backup;
- Synced Folder round-trip works;
- WebDAV uses Keychain + conditional writes;
- two Macs may resolve the same email to different Profile N directories;
- real acceptance includes Intel macOS 13.6.9 and a current Apple Silicon Mac;
- CI + universal Release smoke build pass before merge.
