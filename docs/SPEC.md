# WebDock product specification

## Platform and interface

Native Swift/SwiftUI/AppKit macOS application, macOS 13.0+, Intel and Apple Silicon.
One Dock entry opens a floating Launcher. Library provides persistent editing; Settings has
General, Browsers & Accounts, Sync, Backup & Restore, Appearance and Privacy pages.

Launcher supports website/group search, group filtering, website icons, browser/warning badges,
keyboard navigation, contextual actions and drag ordering in unfiltered All Shortcuts.
Clicking the Dock entry toggles Launcher; activation is deferred until the app is active.

## Website rules

Manually create rules through Launcher/Library `+` or File → New Shortcut / ⌘N.
A rule contains stable UUID, name, HTTP/HTTPS URL, optional browser family, optional account
email, group/order, website icon metadata and created/updated/deleted timestamps.
Edit, duplicate and delete actions preserve unsaved-draft handling. Deletions use tombstones.
Shortcut-file imports and HTTP/HTTPS handler registration are not supported.

## Browser resolution

Supported families: Safari, Chrome, Chromium, Edge, Firefox, Brave, Arc and Vivaldi.
Account routing: Chrome, Chromium, Edge, Brave and Vivaldi, using locally reported signed-in email.
Normalize email by trimming and lowercasing, without Gmail dot/plus rewriting.

Resolution order:
1. Valid device-only override.
2. Installed browser and exactly one matching email profile.
3. Missing or ambiguous account: selected browser default with a warning.
4. Missing browser: system default browser with a warning.
5. No preference: system default browser.

The URL, browser family and optional email are portable intent. Local application paths and
`Default` / `Profile N` directory names are device-local implementation details.
Chromium launching uses transient URL/CrProfile routing files opened explicitly with that browser.
These runtime files are never portable data.

## Global Launcher shortcut

Default Control–Option–W (⌃⌥W), enabled in ordinary installations while WebDock is running.
General Settings offers enable/disable, focused recording, conflict reporting and Restore Default.
A combination requires Control, Option or Command with a non-modifier key; Shift-only/plain typing
is rejected. Escape, switching away or leaving the view cancels recording.

Public Carbon exclusive registration and enabled system symbolic-hotkey checks detect reported
conflicts. Failed replacement restores the previous choice; startup registration failure is
nonfatal and offers retry. Existing sheets are brought forward instead of opening another flow.
Activation waits until the application is active and survives late resign notifications.
No event tap, global keyboard monitor or accessibility/input-monitoring grant is used.
⌘1, ⌘2, ⌘N, ⌘F and ⌘, remain app commands.

## Language and appearance

Simplified Chinese and English; follow system or choose manually. App content changes immediately;
restart updates native menus/dialogs. System/light/dark themes, density, subtitle and badge options
are local preferences. Settings rows respond across their full padded hit target.

The bundled icon uses globe/orbit/Dock artwork, modern compiled resources and earlier-system
representations. A local ICNS override changes the running Dock/app-switcher icon, persists after
restart and supports reset. Finder uses the installed default. Signed bundle resources and Finder
metadata are not modified. Input ICNS must decode correctly, have a valid header/length and be at
most 16 MiB; it is copied atomically to local Appearance/CustomAppIcon.icns.

## Storage, backup and sync

Codable JSON under Application Support/WebDock, with atomic writes:
Canonical.json, DeviceBindings.json, Icons/, Backups/, Cache/ and Appearance/.
Appearance/language/global-hotkey preferences are stored locally in UserDefaults as applicable.

Automatic full local snapshots run at most daily and retain the newest 20 automatic snapshots.
Manual backup, portable export, Replace Restore and Merge Restore are supported. Restore makes
a Pre-Restore snapshot; synchronization makes a Pre-Sync snapshot before changing local data.

Portable snapshots contain canonical rules, groups, tombstones and referenced website icon assets.
They exclude browser paths/profiles, bindings, overrides, warnings, caches and runtime preferences.
Exactly one sync provider is active: Off, Synced Folder or WebDAV. Both use WebDockSync.json.
WebDAV passwords use Keychain; ETag/If-Match and first-create If-None-Match protect writes.
Conflicts use whole-record UUID + updatedAt/tombstone merging. See SYNC_AND_DEVICE_RESOLUTION.md.

## Permissions and privacy

Read browser profile metadata directly so genuine missing files and permission denial remain
distinguishable. First-run guidance and per-browser Authorize/Rescan explain and initiate reads;
macOS controls actual Files & Folders authorization.
No browser cookies, passwords, history, tokens or page content are read. Website-icon discovery
uses a bounded ephemeral request without browser cookies/credentials. Portable data includes
configured account emails and website icons, so destination selection belongs to the user.

## Validation contract

macOS 13 deployment, universal Release, source/localization/icon/LaunchServices validation,
unit/integration tests, strict signature/package checks and current-head CI before merge.
Actual browser permissions/profile routing, native hardware, external sync services and VoiceOver
require real-device evidence. Diagnostic roots disable automatic backups and sync and default
the global shortcut off so they do not compete with normal installations.
