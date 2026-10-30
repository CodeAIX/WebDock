# WebDock Test Plan — v0.3

## Automated tests

### Canonical model / creation
- only HTTP/HTTPS URLs accepted;
- BrowserFamily persists;
- account email is trimmed/lowercased;
- default/non-profile browser rules drop irrelevant account identity;
- tombstone deletion persists.

### JSON persistence
- Canonical.json survives store reload;
- DeviceBindings.json survives reload;
- canonical snapshot excludes DeviceBindings/Profile N;
- atomic writes do not replace in-memory state until persistence succeeds;
- unsupported future schema is rejected.

### Account matching / device resolution
- email match ignores local Profile number and email case;
- zero matches -> missing account fallback;
- duplicate matches -> ambiguous fallback;
- Gmail dots/plus aliases are not rewritten;
- missing browser -> system default + warning;
- device-only override stays local.

### Launching
- system default opens URL normally;
- resolved Chromium profile writes transient URL + CrProfile route;
- missing account opens preferred browser without profile route;
- browser disappearance between resolution/click falls back safely.

### Backup
- portable `.webdockbackup` contains canonical email/browser identity;
- portable backup excludes DeviceBindings/Profile N;
- local snapshot may contain DeviceBindings;
- portable Replace restore clears device bindings;
- Merge restore uses UUID/updatedAt/tombstone semantics;
- restore creates Pre-Restore snapshot.

### Sync
- Synced Folder round-trips CanonicalSnapshot through WebDockSync.json;
- sync payload never contains Profile N/DeviceBindings;
- same UUID uses newer updatedAt;
- newer tombstone wins;
- WebDAV password is not serialized into canonical data;
- WebDAV conditional write behavior uses ETag/If-Match and detects 412 conflicts.

## CI contract

Every branch/PR must:
- validate Info.plist;
- assert no `.crwebloc`, `.webloc`, `.url` document handlers;
- assert no HTTP/HTTPS handler registration;
- assert macOS deployment target = 13.0;
- fail if SwiftData or Apple cloud entitlement/provider code returns to active sources;
- generate Xcode project;
- build/test with `MACOSX_DEPLOYMENT_TARGET=13.0`;
- verify built `LSMinimumSystemVersion = 13.0`.

Release smoke build additionally must:
- build Release for generic macOS with `ARCHS='arm64 x86_64'`;
- verify both architecture slices with `lipo`;
- ad-hoc sign without restricted entitlements;
- verify bundle signature;
- package and integrity-check ZIP.

## Real-Mac acceptance

### Current Apple Silicon Mac
1. first launch shows Browser Account Access guidance;
2. Authorize triggers macOS-owned access flow where applicable;
3. Settings > Browsers & Accounts reports access/rescan status;
4. Privacy & Security shortcut opens System Settings;
5. create via Launcher + and Manager +;
6. edit/delete/reorder and verify restart persistence;
7. Chrome account routing still opens the correct normal profile/tab;
8. missing account/browser warning/fallback behavior remains correct.

### Intel macOS 13.6.9
1. app launches normally;
2. Launcher/Manager/Settings render without macOS 14-only API failure;
3. create/edit/delete/reorder persist across restart;
4. browser/profile detection and routing work;
5. backup/export/restore work;
6. universal executable runs natively as x86_64.

### Backup & restore
1. Back Up Now creates a full local snapshot;
2. Open Backup Folder reveals it;
3. Export Portable Backup creates `.webdockbackup`;
4. inspect/verify portable file contains account email but no Profile N;
5. Replace restore reverts library and re-resolves local accounts;
6. Merge restore combines nonconflicting records;
7. Pre-Restore safety snapshot exists.

### Synced Folder — two Macs
1. choose the same externally synchronized folder on both Macs;
2. Mac A: `account@example.com -> Profile 12`;
3. Mac B: same email -> `Profile 3`;
4. create/edit/reorder/delete on A and Sync Now;
5. external folder transport completes;
6. Sync Now on B;
7. B receives account email, never Profile 12;
8. B resolves to Profile 3 and launches correctly;
9. local override on B never appears on A.

### WebDAV
1. configure an existing test WebDAV directory;
2. Save Credentials then Sync Now;
3. verify remote `WebDockSync.json` is canonical only;
4. second Mac pulls/merges successfully;
5. edit both sides to exercise ETag conflict retry;
6. wrong credentials/network failure surfaces an error without corrupting local data;
7. Keychain holds password; JSON/preferences do not.

## UI-1 Launcher acceptance (pending real-device validation)

Run on current Apple Silicon macOS and Intel macOS 13.6.9, in light and dark appearance:

1. Launch with a fresh sidebar preference: sidebar is visible. Toggle it repeatedly;
   search, +, Library and Settings keep the same positions. Grid expands into available space.
2. Hide sidebar, restart, and verify it stays hidden; show it and restart again.
3. All Shortcuts shows the library; existing group rows filter correctly. Search matches
   name, URL, email, browser and group within the selected scope. Removing a selected group
   through sync returns the view to All Shortcuts.
4. With no shortcuts/results, the empty state fits beside the sidebar.
5. ⌘F focuses search, ⌘N opens creation, Return launches only when one result remains.
   Esc hides Launcher. ⌘1 opens Launcher and ⌘2 opens Library from other app windows.
6. Click Settings and use ⌘, separately: Launcher hides, Settings opens; repeat with
   Settings already open. On Ventura verify the compatibility action opens Settings.
7. Open Library: Launcher hides. Repeated Dock reopen and deactivate retain prior behavior,
   without flashing or a queued Launcher appearing above Library/Settings.
8. Reorder in All Shortcuts with search cleared; restart and verify persistence. Search/group
   filters disable reorder to avoid changing global order from a partial list.
9. New Shortcut and Browser Account Access sheets remain usable with keyboard and pointer.
10. Confirm critical buttons remain visible and accessible on both OS versions; verify panel
    placement near each Dock edge and on smaller/multiple displays (default size 780 × 520).

Build/test and universal package checks do not establish these visual or browser-routing results.

## UI-2 Library and Settings acceptance

Pending on both target Macs: verify Library content + action is visible without a system toolbar;
search and group filters; four editor cards; account default/local/manual email choices; saved
local overrides (Apply disabled when unchanged); group creation; duplicate excludes local binding;
Save/Delete/Test Launch. Verify each Settings page (General, Browsers & Accounts, Sync,
Backup & Restore, Appearance, Privacy), light/dark/System themes, scrolling at 780 × 600,
Keychain credential save, sync and backup/restore dialogs. Existing services retain their semantics.
