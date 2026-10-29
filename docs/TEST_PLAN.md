# WebDock v0.1 Test Plan

## 1. Automated unit tests

### ChromeWeblocImporter

- XML plist with URL + CrProfile -> success.
- Binary plist with URL + CrProfile -> success.
- Missing URL -> failure.
- Invalid URL -> failure.
- Missing CrProfile -> failure.
- Empty CrProfile -> failure.
- http URL -> success.
- https URL -> success.
- javascript URL -> failure.

### WeblocImporter

- XML plist URL -> success.
- Binary plist URL -> success.
- missing URL -> failure.

### InternetShortcutImporter

- UTF-8 `.url` -> success.
- UTF-16 `.url` -> success.
- comments/extra keys ignored.
- unsafe URL schemes rejected.

### ManagedStorage / ImportTransaction

- creates app support structure.
- unique UUID destination.
- move within volume.
- copy across volume if necessary.
- rollback after simulated DB failure.
- rollback after simulated filesystem failure.
- source remains intact on failed import.
- delete uses trash abstraction where possible.

### Sorting

- insert between two items.
- insert first/last.
- rebalance.
- stable after persistence reload.

### Launcher

Using mocked `WorkspaceOpening`:

- `.crwebloc` opens managed file URL.
- `.webloc` normalized/default opens web URL.
- specified browser opens via target application.
- external app opens application.

## 2. Integration/manual tests

### Dock lifecycle

- app stopped -> click Dock -> panel appears.
- app running -> click Dock -> panel toggles.
- Esc closes.
- click another app hides.

### Dock position

Test Dock on:

- bottom
- left
- right
- auto-hide on/off
- external monitor primary/secondary

Panel must remain completely visible.

### Drag to Dock icon

For each supported file type:

1. Put shortcut on Desktop.
2. Drag onto WebDock Dock icon.
3. Verify source disappears only after successful import.
4. Verify tile appears.
5. Quit WebDock.
6. Reopen and verify tile persists.

### Chrome profile critical test

Create two Chrome profiles with visibly different theme/account state.

Create `.crwebloc` for Profile A.

Import into WebDock.

Click tile.

Pass condition: URL opens in ordinary Chrome UI under Profile A; it must not open as a standalone installed web app.

### ChatGPT regression test

- Open ChatGPT through imported `.crwebloc`.
- Upload the same local file that previously failed in standalone Chrome Web App mode.
- Verify upload behaves like a normal Chrome tab.

This is a manual product regression test, not a unit test.

## 3. File safety tests

- simulate destination not writable.
- simulate filename already exists.
- simulate DB save failure after staging.
- simulate app crash after staging; at minimum no permanent source deletion before staging safety is established.

## 4. UI/accessibility tests

- Light mode.
- Dark mode.
- Increase Contrast.
- Reduce Transparency.
- Reduce Motion.
- VoiceOver reads tile name and URL host.
- keyboard only: search, arrows, Return, Esc.

## 5. Performance smoke tests

Generate fake data:

- 100 shortcuts
- 500 shortcuts
- 1000 shortcuts

Check launcher open time, search latency, scrolling.

## 6. Release gate

All acceptance criteria in `docs/SPEC.md` must pass before v0.1 is considered complete.
