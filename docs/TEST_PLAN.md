# WebDock Test Plan — v0.4.1

## 0.5.1 feedback candidate

- Verify Launcher uses a bookmark line icon for Library, retaining the tooltip/action.
- Click Settings rows on their right blank padding, icon and label; each selects the same page.
- Appearance → Choose ICNS: valid file previews and changes the running Dock/app-switcher icon;
  restart retains it; Restore Default Icon returns the bundled default. Cancel preserves selection.
- Finder's installed bundle icon stays default. Strict codesign verification and designated
  requirement must remain unchanged before/after selection, restart and reset.
- Invalid/oversized ICNS and storage failures cannot replace a prior saved choice or runtime icon.
- App icon data is device-local and absent from portable backups and sync payloads.
- Browser metadata genuinely missing means empty profiles; directory read denial must raise an
  error/access-required status instead of zero-account success. Never reset TCC during automation.
- Recheck native Intel UI for this new candidate; the user's 0.5.0 pass is recorded separately.

XMAC follow-up completed after the user confirmed runtime-only scope and unlocked the Mac: native
ICNS picker selection, retained preview/reset state after a real quit/restart, restore default and
a second restart retaining default. Strict signature, all Contents hashes, root xattr names and
designated requirement stayed unchanged at every checkpoint. Diagnostic app reset and closed.

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

## UI-3 icons

Automated: icon metadata parsing/priority/relative URLs, forbidden URL schemes, hash/path validation,
invalid image rejection, optional legacy fields. Pending real-Mac: ChatGPT, Claude, Google, DeepSeek,
GitHub high-resolution appearance; PNG/JPEG/ICO/ICNS picker, custom/reset/refresh, local browser
badge reflects override/default, account subtitle, warning tooltip, offline globe, light/dark.

## UI-4 icon transport

Automated: portable custom icon backup/restore and folder round-trip on independent roots;
canonical file excludes embedded blobs; hash/path/corrupt data rejected before replacement;
WebDAV icon bytes preserved with ETag/If-Match and 412 conflict; edits during GET survive.
Existing backup tests verify local bindings never enter portable data and Replace resets bindings.
Pending two-device acceptance: manual icon on A arrives on B by folder and real WebDAV, works
offline after restart, replace/merge restore preserves icons, account email re-resolves locally.

## UI-5 interaction and appearance

Automated: all four manual image formats normalize to portable PNG, changed website host clears
an automatic icon but keeps a custom icon, initial WebDAV create uses If-None-Match: *.
Local interactive evidence (isolated Debug app on XMAC): fixed bar across sidebar toggles,
Library four cards, unsaved-change prompt/Keep Editing, direct Settings and ⌘,; ⌘N sheet and
Esc cancel; ⌘F then Return enters grid focus, Right moves to next tile; light/dark rendering;
context menu; high-resolution icons for all five reference sites; Return launched Google in
system-default Safari and the test page was closed afterwards.

Still validate on Ventura: Return launch. On both target Macs validate persistent drag/drop, delete confirmation,
all density/subtitle/badge combinations, VoiceOver, file picker/sync/backup dialogs, screen sizes,
Dock reopen after transitions and actual browser/account routing. Verify save/discard with external
sync edits: clean editors reload metadata; dirty editors offer Reload Saved Values or Save.

A separate UI fixture can be created without using the normal library:

```sh
python3 scripts/prepare_ui_validation.py \
  --app /absolute/DerivedData/Build/Products/Debug/WebDock.app \
  --output-dir /absolute/new-validation-directory
```

Open the generated WebDock UI Validation.app. It uses its own bundle ID, defaults domain and JSON
root; background sync/automatic backups/onboarding are disabled. Its public icon requests remain
active. The fixture is synthetic and does not establish browser-profile or two-device acceptance.
Normal Release smoke packages contain no validation-library Info.plist key.

### Final XMAC drag correction

The original drop-finish-only route did not submit reliably during local UI automation. UI-5 now
uses per-session nonce payloads and shared drag state, reorders/persists as a valid dragged tile
enters another tile, and ignores stale asynchronous payload callbacks. A local real drag moved
ChatGPT after Google; Canonical.json recorded the resulting order and a real restart preserved it. Cancelled drags retain the
last live order; reordering back reverses it. External text is not accepted as a shortcut import.
Ventura drag behavior and repeated restart acceptance remain in the device checklist.

Final combined XMAC checks also verified native Button tile arrow focus with live drag reorder,
Compact density + hidden subtitle + hidden browser badge (then restored defaults), and Delete
confirmation with Cancel. The diagnostic app was closed after validation.

## 0.4.1 XMAC feedback regression

- App icon: verify Dock, Finder and native About panel against the uploaded globe-and-Dock design;
  no large silver-white outer backing. Packaged WebDock.icns and Assets.car exist. Source validator
  checks all ten standalone ICNS representations (16–1024px) with alpha; built-app checks require
  the modern icon stack, legacy multi-size images and matching icon names. Build 6's native About
  panel was checked on XMAC without the white backing; Intel Ventura still needs visual acceptance.
- Mouse click launch → reopen Launcher: no retained selection frame. ⌘F → Return → arrows still
  navigate, with a single native focus indicator. Recheck on Ventura.
- Fresh language preference: Chinese macOS starts in Chinese; English starts in English; unsupported
  language lists fall back to English. Chinese variants map to Simplified Chinese.
- General → Display Language: switch English/简体中文/Follow System, checking Launcher, Library,
  Settings, creation/account sheets, errors and tooltips. Existing draft text must survive switching.
- Restart after a manual choice: native macOS menus/dialogs and content agree. Follow System removes
  WebDock's per-app override and follows the global OS language; it does not change global settings.
- Canonical data, URL/CrProfile protocol keys, Profile N directories, user names/URLs/emails, theme and
  density raw values must not be translated or changed. Language preferences remain local-only.

The isolated XMAC UI run covered language switching/restart, draft preservation, single focus and
click-launch → keyboard-navigation recovery; patch acceptance on the user's normal installation
and Intel macOS 13.6.9 remain pending.

## Build 7 acceptance closure

45 automated tests pass. WebDAVHTTPIntegrationTests uses Network/NWListener bound only to
127.0.0.1 on an ephemeral port and the production URLSession transport, with no URLProtocol stub.
It checks two independent local stores, real conditional create/update, custom icon and tombstone
transfer, stale ETag rejection and fresh merge, HTTP 503 / corrupt asset rejection before durable
replacement, offline store restart/portable restore and Pre-Sync/Pre-Restore snapshots. It uses
synthetic credentials and never reads/writes real WebDAV settings or Keychain. This does not close
the two-real-Mac, production-server or real browser-account gates.

Native XMAC build 7 checks: File > New Shortcut is visible; menu click / ⌘N work in Launcher,
Library and Settings; repeated ⌘N retains the existing form text; cancel retains unsaved Library
editor text; creating a synthetic record succeeds and persists after a real restart. The diagnostic
app was closed afterwards. The previously accepted icon is unchanged.

Run scripts/collect_device_acceptance.sh on each target Mac as described in DEVICE_ACCEPTANCE.md.
The collector is read-only, refuses to overwrite prior evidence, and leaves interactive checkboxes
unticked. An Apple Silicon report explicitly cannot count as native Intel Ventura acceptance.
