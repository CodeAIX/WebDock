# Canonical WebShortcut Model

Status: adopted for M8.2 / Issue #18

## 1. Product model

WebDock is not a repository of browser shortcut files. It is a local database of website launch rules.

The canonical website shortcut is:

```text
WebShortcut
  URL
  display name
  browser (optional; nil = system default)
  browser profile directory (optional)
  cached human-readable profile/account metadata
  icon
  group
  custom order
  provenance/source type
```

Browser-exported files are adapters into this model.

## 2. Input surfaces

All of the following create the same kind of editable WebShortcut:

- Chrome/Chromium `.crwebloc`
- Apple `.webloc`
- Windows/standard `.url`
- direct HTTP/HTTPS URL
- manual New Shortcut UI
- future share extension / browser extension / clipboard flow

Source type is provenance only. It must not determine whether an item is editable after normalization.

## 3. Chrome `.crwebloc`

### Import

For new imports, parse:

```text
URL
CrProfile
```

Normalize to:

```text
normalizedURLString = URL
browserBundleIdentifier = com.google.Chrome
browserProfileDirectory = CrProfile
launchMode = specifiedBrowser
```

Resolve account/profile display metadata locally when available.

The imported file is not retained as the canonical object.

### Launch

Profile-specific Chrome launch still uses the proven Chrome-native routing mechanism:

1. create a transient WebDock `.crwebloc` containing the current URL and selected `CrProfile`;
2. explicitly open that routing file with the selected Chrome/Chromium application;
3. Chrome opens a normal browser tab/window in the selected profile.

Therefore `.crwebloc` remains useful as a **runtime routing format**, but not as a permanent storage format.

## 4. `.webloc` and `.url`

Parse URL, validate HTTP/HTTPS, and store as a normal WebShortcut.

Default launch rule:

```text
browser = system default
profile = nil
```

The user may later select another browser/profile without any relationship to the imported source format.

## 5. Manual creation

Primary entry points:

- Launcher `+`
- Manager `+`
- future `File > New Shortcut` / `⌘N`

Fields:

- URL — required, HTTP/HTTPS only
- Name — optional; derive from host when blank
- Browser — Default Browser or installed browser
- Profile / Account — shown when supported
- Group — add when group UI is surfaced
- Icon — future/customization pass

Manual creation and file import must share the same canonical model and launch service.

## 6. Browser/profile identity

Stable routing fields:

```text
browserBundleIdentifier
browserProfileDirectory
```

Human-readable fields such as profile name, Google account display name and email are display/cache metadata, not routing identity.

If a profile is renamed, the directory still routes correctly. If the directory disappears, WebDock should show the last-known label plus a missing-profile warning and allow reselection.

## 7. Import source cleanup

New normalized imports follow this safety sequence:

1. inspect/parse source without mutation;
2. validate URL/profile metadata;
3. create and commit WebShortcut in SwiftData;
4. only after DB success, move source file to macOS Trash;
5. if Trash fails, keep both source and WebShortcut.

A source-cleanup failure must never invalidate a working normalized shortcut.

No permanent unlink/delete is required for successful website imports.

## 8. Legacy source-preserving records

Existing records created before M8.2 may still have:

```text
launchMode = originalShortcutFile
managedFileRelativePath != nil
```

They remain supported and launch exactly as before until migration.

Do not silently delete these managed files during the first canonical-model release.

### Safe migration path

For a legacy Chrome record:

1. parse its managed original again;
2. validate URL + `CrProfile`;
3. create/validate structured Chrome + profile routing metadata;
4. save the converted DB state;
5. verify the converted record is launchable;
6. only then move the old managed source to Trash.

On failure, restore/retain the legacy record and original managed file.

A later UI may expose `Convert to editable shortcut` before migration becomes automatic.

## 9. Launch matrix

| Browser selection | Profile selection | Launch behavior |
|---|---|---|
| System default | none | open URL via normal macOS default handling |
| Specific non-profile browser | none | open URL explicitly with selected browser |
| Chrome/Chromium | profile | generate transient `URL + CrProfile` routing file and open with selected browser |
| Edge/Brave/Vivaldi | profile | same Chromium routing path while marked experimental until real-Mac validated |
| Legacy original shortcut | preserved | open managed original file unchanged |

## 10. Settings boundary

Settings contains global preferences, not shortcut creation.

Potential global settings:

- default browser/profile for newly created shortcuts;
- after-import source behavior (`Move to Trash` default, future `Keep Original` option);
- whether account email is shown in profile menus;
- launcher behavior/appearance;
- icon/cache controls.

Content creation and editing belongs in Launcher/Manager.

## 11. UI implications

Manager should stop presenting normalized shortcuts as files. For normalized records, use language such as:

> Stored as an editable WebDock launch rule; no source shortcut file is required.

Only legacy records expose `Reveal Managed File`.

Imported provenance may be shown as read-only metadata (`Imported from Chrome shortcut`, `.webloc`, etc.) but must not restrict editing.

## 12. Acceptance

The canonical model is considered validated when:

- a newly imported `.crwebloc` has no managed source file;
- its URL/browser/profile are editable;
- it still opens the same Chrome account/profile as the original;
- source is moved to Trash after successful import;
- manual creation can select Browser + Profile/Account;
- manual shortcuts persist across restart;
- old legacy `.crwebloc` items still launch unchanged;
- existing user data and ordering survive upgrade.
