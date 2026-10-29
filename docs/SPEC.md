# WebDock v0.1 — Product & Technical Specification

Status: implementation-ready

Target: macOS 14+

Stack: Swift + SwiftUI + AppKit + SwiftData

Bundle ID: `io.github.codeaix.WebDock`

## 1. Product definition

WebDock is a native macOS website-shortcut launcher and manager. It occupies one Dock icon and provides a fast grid launcher for browser shortcuts. It is not a browser and must not embed user websites in a WebView.

Primary goals:

- import browser-generated website shortcut files;
- preserve browser-specific launch semantics where valuable;
- especially preserve Chrome `.crwebloc` `CrProfile` behavior;
- organize shortcuts in one local collection;
- present them in a polished Dock-adjacent launcher panel;
- support rename, delete, reorder, search, grouping, and browser selection;
- keep all user data local by default.

Canonical ChatGPT use case:

`Dock -> WebDock -> ChatGPT.crwebloc -> Chrome profile -> normal Chrome tab -> https://chatgpt.com/`

The result must be a regular Chrome tab/window, not a standalone Chrome Web App.

## 2. Non-negotiable requirements

1. Native macOS app. No Electron or Tauri.
2. SwiftUI for most UI; AppKit for Dock lifecycle, panel/window behavior, Finder open-file events and `NSWorkspace` integration.
3. No private Dock APIs.
4. No Accessibility tricks to discover the Dock tile location.
5. No embedded browser/WebView for shortcut launch.
6. `.crwebloc` must not be reduced to only its URL; preserve the original managed file and its `CrProfile` field.
7. Imports must be transactional. A failed import must not destroy the source file.
8. User deletion should use Trash when practical instead of irreversible unlink/delete.
9. Browser-managed `.app` Web Apps are not moved/deleted automatically in v0.1.
10. No telemetry, account, sign-in, or cloud requirement.
11. Prefer zero third-party dependencies.

## 3. Supported inputs

MVP required:

- `.crwebloc`
- `.webloc`
- Windows/standard `.url`
- direct HTTP/HTTPS URL drop into the app when represented on pasteboard
- Finder -> WebDock Dock icon file drop
- in-app file/URL drop

Experimental after MVP:

- Safari Web App `.app`
- Chrome Web App `.app`
- Edge Web App `.app`

MVP does not require browser extensions, bookmark sync, iCloud sync, browser tab automation, App Store distribution, or private Dock anchoring.

## 4. Dock behavior

When WebDock is not running:

- clicking the Dock icon launches the app;
- after initialization, the launcher panel appears.

When already running:

- `applicationShouldHandleReopen(_:hasVisibleWindows:)` toggles the launcher panel;
- do not create another normal app window;
- return `false` after handling.

Panel interactions:

- click Dock: show/toggle;
- Esc: hide;
- app deactivation: hide by default;
- clicking a shortcut: launch target, then hide by default.

The launcher may visually appear to rise from the Dock but must not claim exact Dock-tile anchoring. Position it using screen visible-frame geometry.

## 5. Launcher panel

Use an `NSPanel` subclass with SwiftUI content.

Recommended defaults:

- 600 x 420 pt;
- min width about 480 pt;
- max width about 760 pt;
- borderless/full-size-content style;
- transparent window background;
- native shadow;
- `NSVisualEffectView` / material background;
- continuous rounded rectangle around 20 pt;
- floating/transient behavior;
- can become key but not main.

Grid:

- adaptive 4–6 columns;
- icon about 56–64 pt;
- tile width about 88–110 pt;
- labels truncate cleanly;
- small hover/click feedback;
- clear drag insertion feedback.

Search:

- name;
- URL/host;
- group;
- browser/profile metadata;
- Cmd+F focuses search;
- expected to remain instantaneous with several hundred items.

Empty state should explicitly invite dropping `.crwebloc`, `.webloc`, and `.url` files onto WebDock.

## 6. Panel positioning

Use the display associated with the current interaction when possible, otherwise key-window/main screen fallback.

Infer probable Dock edge from `NSScreen.frame` versus `visibleFrame`:

- reduced bottom inset => bottom Dock;
- reduced left inset => left Dock;
- reduced right inset => right Dock.

If inference is ambiguous, default to bottom.

Position:

- bottom Dock: horizontal center, just above visibleFrame.minY;
- left Dock: near visibleFrame.minX, vertical center;
- right Dock: near visibleFrame.maxX, vertical center.

Always clamp the complete panel within the visible screen.

Must be tested with:

- Dock bottom/left/right;
- auto-hide on/off;
- primary and secondary displays.

## 7. Data model

Use SwiftData.

`WebShortcut` minimum fields:

- `id: UUID`
- `displayName: String`
- `normalizedURLString: String`
- source type
- launch mode
- optional browser bundle identifier
- optional browser display name
- optional browser profile hint
- optional managed original-file relative path
- optional external `.app` bookmark/reference metadata
- optional icon relative path
- optional group ID
- `sortIndex: Double`
- created/updated timestamps
- last opened timestamp
- open count

Source types:

- chromeWebloc
- webLoc
- internetShortcut
- directURL
- appBundle

Launch modes:

- originalShortcutFile
- defaultBrowser
- specifiedBrowser
- externalAppBundle

`ShortcutGroup` minimum fields:

- id
- name
- sortIndex
- createdAt

Filesystem and database responsibilities must remain separate: SwiftData stores metadata; managed shortcut source files and cached icons live under Application Support.

## 8. Managed storage

Root:

`~/Library/Application Support/WebDock/`

Suggested structure:

```text
WebDock/
  Shortcuts/
    <UUID>/
      original.crwebloc | original.webloc | original.url
      icon.*
      metadata.json   # optional/export/debug only
  Cache/
  Staging/
```

Never rely on a source Desktop/Documents path after successful adoption.

## 9. Import architecture

Define a `ShortcutImporter` protocol. Each adapter must expose:

- whether it can handle the input;
- inspection/parsing into an `ImportedShortcutDraft`;
- no destructive mutation during inspection.

Required adapters:

- `ChromeWeblocImporter`
- `WeblocImporter`
- `InternetShortcutImporter`
- `URLImporter`

### `.crwebloc`

Parse as a property list. Required fields:

- `URL`
- `CrProfile`

Validate URL scheme is HTTP or HTTPS.

Store the profile as display/search metadata, but launch by opening the preserved managed `.crwebloc` file and letting Chrome dispatch it natively.

Do not replace this with guessed `--profile-directory` command-line behavior.

### `.webloc`

Parse property list `URL`; normalize and validate HTTP/HTTPS.

Default launch mode may be the normal default browser unless the user overrides it.

### `.url`

Parse common INI-like Internet Shortcut form, including UTF-8 and UTF-16 where feasible. Extract `URL=`. Ignore unknown fields. Reject unsafe schemes.

## 10. Transactional import

A successful import means WebDock takes responsibility for the shortcut. The user's original shortcut may disappear from its prior location only after safety is established.

Implement an `ImportTransaction` rather than a naked `moveItem` call.

Preferred sequence:

1. Inspect input without mutation.
2. Create UUID and staging directory.
3. Copy or move into staging using safe filesystem semantics.
4. Verify destination exists and is readable.
5. Construct/persist SwiftData record.
6. Move staging payload into final managed location if needed.
7. Commit.
8. Only then ensure the original is removed if copy semantics were used.

On any failure:

- rollback DB insert;
- remove incomplete managed/staging artifacts;
- leave or restore the original source.

Same-volume atomic move is preferred where it is safe, but the design must also work across volumes.

Do not silently overwrite duplicate filenames. UUID directories eliminate most collisions.

## 11. Launch service

Wrap AppKit behind testable abstractions.

For `originalShortcutFile`:

- resolve the managed original file;
- call `NSWorkspace` open on that file.

For `defaultBrowser`:

- open normalized HTTP/HTTPS URL with system default behavior.

For `specifiedBrowser`:

- resolve application by bundle identifier and request that browser to open the URL using public `NSWorkspace` APIs.

For `externalAppBundle`:

- open referenced application using public AppKit APIs.

On launch success update last-opened/open-count metadata.

## 12. Finder/Dock file drop

Register supported document/content types in the app target so dragging a supported file onto the WebDock Dock icon routes to the app.

Handle both cold-start and already-running cases.

Route all accepted files through `ImportCoordinator`; never implement a second import path in AppDelegate.

Before finalizing UTType declarations, inspect real Chrome/Safari sample metadata on macOS (`mdls`) and document any OS-specific behavior.

## 13. Manager window

Provide a normal resizable management window separate from the launcher.

Functions required:

- grid/list view;
- search;
- rename;
- edit normalized URL for appropriate source types;
- choose default/specified browser where applicable;
- delete;
- custom reorder;
- group assignment;
- reveal managed original in Finder;
- inspect source type/profile metadata.

Deleting a shortcut should remove its database record and managed payload through a reversible/trash-oriented file service where practical.

For externally referenced `.app` Web Apps, remove the WebDock reference only; do not delete the application by default.

## 14. Sorting

Custom ordering is the default.

Use a numeric `sortIndex` strategy that permits insertion between neighbors. Rebalance when gaps become too small or values become unwieldy.

Order must survive app restart.

Drag-and-drop reordering is required in the launcher or manager; at minimum it must be available in the manager for v0.1.

## 15. Groups

Groups are first-class metadata. MVP may keep group presentation simple, but the data model and manager must permit assigning a shortcut to a group.

Future folder-like launcher presentation must not require a migration that breaks the model.

## 16. Icons

Icon source priority should evolve as follows:

1. custom user icon;
2. original shortcut/app icon if meaningful;
3. locally cached site icon;
4. generated fallback using domain/initial.

Advanced HTML icon discovery is not a release blocker.

Do not make remote icon fetching necessary to launch a shortcut.

## 17. Accessibility and appearance

Must support:

- system Light/Dark appearance;
- Reduce Motion;
- Reduce Transparency fallback;
- Increase Contrast reasonably;
- keyboard access;
- VoiceOver labels for tiles including shortcut name and host.

Use semantic system colors/materials. Avoid hard-coded appearance assumptions.

## 18. Keyboard behavior

Required:

- Esc hides launcher;
- Cmd+F focuses search;
- Return launches selected result where selection exists;
- sensible tab/focus order;
- manager supports ordinary macOS editing shortcuts.

Arrow-key grid navigation is strongly preferred for v0.1 and required before calling the launcher polished.

## 19. Context menus

Shortcut context menu should support at least:

- Open
- Open With…
- Rename
- Edit
- Reveal Managed File (when applicable)
- Delete

Later/group-aware options may include Move to Group and Change Icon.

Dock right-click menu may provide recent shortcuts and Show WebDock, but this is secondary to correct launcher behavior.

## 20. Diagnostics

Use `OSLog` categories such as:

- app lifecycle
- import
- storage
- launch
- UI

Never log sensitive browser data, cookies, local document contents, or account tokens.

Errors shown to the user should be actionable and concise.

## 21. Security and privacy

- Accept only intended HTTP/HTTPS URL schemes for website shortcuts.
- Reject `javascript:`, executable shell-like schemes, and malformed inputs.
- Do not execute data from shortcut files.
- Do not collect telemetry.
- Do not transmit the shortcut library to a service.
- Do not require Full Disk Access.

No App Sandbox is required for the direct-distribution v0.1 architecture; revisit only if App Store distribution becomes a goal.

## 22. Performance targets

Smoke test with 100, 500, and 1000 synthetic shortcuts.

Expected behavior:

- panel appears promptly;
- scrolling remains usable;
- search for several hundred items feels immediate;
- no synchronous remote network fetch blocks panel opening.

## 23. Error behavior

Examples:

- malformed shortcut: show import error, preserve source;
- unsupported scheme: reject and preserve source;
- browser unavailable: explain and offer changing launch mode;
- managed file missing: mark item as needing repair and do not silently recreate profile-specific shortcuts;
- DB write failure: rollback file adoption.

## 24. `.app` Web App policy

Safari/Chrome/Edge Web Apps are a separate source class.

For v0.1 experimental support:

- detect a dropped `.app` bundle;
- store a stable reference/bookmark/path hint;
- display its icon/name;
- launch the external app;
- do not move or delete the original application automatically.

Conversion from browser Web App to a normal browser URL is optional and must be explicit.

## 25. Testing requirements

Automated unit tests must cover:

- `.crwebloc` parsing including XML/binary plist;
- missing URL/profile;
- unsafe schemes;
- `.webloc` parsing;
- `.url` encodings;
- storage/import rollback;
- sorting;
- launch dispatch with mocked workspace.

Manual integration tests must cover:

- Dock click/reopen toggle;
- Dock bottom/left/right;
- multi-monitor;
- drag supported shortcut to Dock icon;
- source only disappears after successful import;
- persistence across quit/relaunch;
- Chrome profile correctness;
- ChatGPT file-upload regression in a normal Chrome tab.

## 26. Critical regression test

Use a `.crwebloc` with:

```text
URL = https://chatgpt.com/
CrProfile = Profile 12
```

After import and tile launch:

- Chrome opens ordinary browser UI;
- the intended profile is used;
- ChatGPT opens in a normal tab/window;
- file upload behaves like ordinary Chrome, not the problematic standalone Web App mode.

## 27. Development sequence

1. Bootstrap Xcode app/test targets.
2. Make starter skeleton compile.
3. Implement models/storage.
4. Implement import adapters.
5. Implement transactional import and rollback tests.
6. Implement launch service and Chrome-profile manual test.
7. Implement Dock lifecycle and panel.
8. Implement grid/search/keyboard.
9. Implement manager, rename/delete/reorder/groups.
10. Register Dock file-drop document types.
11. Accessibility/appearance polish.
12. Only then experiment with `.app` Web Apps and advanced icons.

## 28. MVP acceptance criteria

WebDock v0.1 is accepted only if all of the following pass:

1. Builds and runs on macOS 14+.
2. App can live normally in Dock.
3. Cold Dock launch shows launcher.
4. Re-clicking Dock toggles launcher without spawning extra normal windows.
5. Launcher stays visible on-screen with bottom Dock.
6. Launcher stays visible on-screen with left Dock.
7. Launcher stays visible on-screen with right Dock.
8. `.crwebloc` imports successfully.
9. `.crwebloc` original file is preserved under managed storage.
10. Chrome profile hint is parsed and persisted.
11. Launching imported `.crwebloc` opens the intended normal Chrome profile context.
12. `.webloc` imports and launches.
13. `.url` imports and launches.
14. Failed import does not destroy the user's source.
15. Shortcuts persist across restart.
16. Rename works and persists.
17. Delete removes the WebDock entry safely.
18. Custom order persists.
19. Search works by name and URL/host.
20. Dragging supported files onto the Dock icon works in cold and warm states.
21. Dark and Light appearance are usable.
22. Esc hides launcher.
23. Keyboard focus/search are usable.
24. No private Dock APIs are present.
25. No embedded browser is present.
26. No telemetry/cloud dependency is present.
27. Chrome/ChatGPT regression test opens a normal browser tab.
28. The same local file that failed in standalone ChatGPT Web App mode can be uploaded normally when ChatGPT is launched through WebDock into ordinary Chrome.

Any deviation from these requirements must be documented in `docs/DECISIONS.md` before implementation diverges.
