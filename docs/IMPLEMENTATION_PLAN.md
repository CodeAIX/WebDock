# WebDock Implementation Plan — 0.4.1 (7)

Updated 2026-10-30. Implementation is complete for the items below unless explicitly marked optional.
Current evidence: 45 tests, macOS 13.0 target, universal Release, source/bundle contracts and isolated
XMAC interaction checks. UI_V04_STATUS.md tracks live PRs; DEVICE_ACCEPTANCE.md tracks remaining gates.

## M9 — Manual-first portable launch rules
Completed foundation:
- remove browser shortcut-file imports and document handlers;
- canonical WebShortcut = URL + BrowserFamily + optional account email + metadata;
- Launcher/Manager `+` creation;
- account email resolves to machine-local Profile N;
- missing/ambiguous account and missing browser fall back with warnings;
- device-only overrides.

## M10 — macOS 13 persistence and browser permission UX
Implemented; native Intel and real account acceptance pending:
- deployment target macOS 13.0;
- universal arm64 + x86_64 Release build;
- replace SwiftData with Codable JSON (`Canonical.json`, `DeviceBindings.json`);
- replace macOS 14-only UI APIs;
- add `NSAppDataUsageDescription`;
- first-run Browser Account Access guidance;
- Settings > Browsers & Accounts with Authorize/Rescan and Privacy & Security shortcut;
- validate on Intel macOS 13.6.9 and current Apple Silicon macOS.

## M11 — Backup and restore
Implemented and covered by backup/restore and offline integration tests:
- daily automatic full local snapshot, retain newest 20 automatic snapshots;
- manual Back Up Now;
- portable `.webdockbackup` export excluding DeviceBindings/Profile N;
- Replace and Merge restore;
- automatic Pre-Restore snapshot;
- automatic Pre-Sync snapshot when remote merge changes local canonical state.

## M12 — Cross-device sync without Apple entitlements
Implemented; real two-Mac and production WebDAV acceptance pending:

### Synced Folder
- user-selected ordinary directory;
- canonical `WebDockSync.json` only;
- compatible with any external file-sync tool/provider;
- startup/local-change/manual synchronization;
- validate two-Mac account-email -> different Profile N scenario.

### WebDAV
- existing WebDAV folder URL;
- username + Keychain password/app-password;
- canonical `WebDockSync.json`;
- ETag / `If-Match` writes;
- first-create `If-None-Match: *`;
- conflict reload/merge retry;
- offline/error diagnostics.

There is no Apple cloud entitlement/provider roadmap.

## M13 — Product polish
- implemented: website/custom icons, portable icon backup/sync and browser badges;
- implemented: group navigation, Library editor and six Settings pages;
- implemented: keyboard navigation, accessible labels and single native focus indicator;
- accepted by user: globe-and-Dock application icon;
- implemented: sync status/error presentation, conditional writes and safety snapshots;
- implemented in build 7: File > New Shortcut / Cmd-N across Launcher, Library and Settings;
- implemented: system-default Chinese/English and manual language selection;
- optional/deferred: client-side WebDAV payload encryption; no inactive setting is exposed.

## Release gates
Every milestone requires:
- macOS 13 deployment CI green;
- universal Release smoke build green (`arm64 + x86_64`);
- no shortcut-file document handlers;
- no SwiftData dependency;
- no Apple cloud entitlement/provider;
- no local Profile N in portable backup/sync payload;
- real-Mac acceptance for affected behavior.
