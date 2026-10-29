# WebDock Finder → Dock Import Smoke Test

This test must be run on a real interactive macOS desktop. Headless GitHub Actions can validate the app, importers, transactions, and LaunchServices metadata, but cannot prove the Finder/Dock drag gesture itself.

## Preconditions

1. Build WebDock from the current `main` or candidate branch.
2. Copy `WebDock.app` to `/Applications` or `~/Applications`.
3. Launch it once and keep its icon in the Dock.
4. Prepare three disposable shortcut files on the Desktop:
   - a Chrome/Chromium `.crwebloc` created by the browser shortcut flow;
   - a standard `.webloc` (Safari/Finder internet location);
   - a `.url` Microsoft Internet Shortcut containing an HTTP(S) URL.
5. For the `.crwebloc`, record its Chrome profile before import so profile routing can be checked after launch.

## Test A — single `.crwebloc`

1. Quit WebDock completely.
2. Drag the `.crwebloc` from Finder onto the WebDock Dock icon.
3. Expected while hovering: Dock accepts the item as an openable document.
4. Drop it.
5. Expected:
   - WebDock launches;
   - Launcher appears;
   - the new shortcut appears once;
   - the original Desktop `.crwebloc` disappears only after import succeeds;
   - a managed copy exists under `~/Library/Application Support/WebDock/Shortcuts/<UUID>/`.
6. Click the new tile.
7. Expected: Chrome handles the managed `.crwebloc` and opens the URL in the original Chrome profile.

## Test B — running app + `.webloc`

1. Leave WebDock running.
2. Drag a `.webloc` onto its Dock icon.
3. Expected:
   - no second WebDock process/window is created;
   - Launcher is brought forward after import;
   - source file is consumed only after the managed copy + SwiftData record commit;
   - clicking the tile opens the normalized URL in the default browser unless overridden in Manager.

## Test C — multiple files

1. Select `.crwebloc`, `.webloc`, and `.url` together in Finder.
2. Drag the selection onto WebDock in the Dock.
3. Expected:
   - all supported files are processed sequentially;
   - successful files are added even if another file fails;
   - failures are summarized once after the batch;
   - successful source files disappear only after their individual transaction commits;
   - failed source files remain at their original locations.

## Test D — malformed source safety

1. Create a text file renamed to `Broken.crwebloc`, without a valid property list.
2. Drag it onto WebDock.
3. Expected:
   - WebDock reports the import error;
   - `Broken.crwebloc` remains untouched in Finder;
   - no managed shortcut directory or SwiftData record is created for it.

## Test E — Manager and delete

1. Open Manager from the Launcher toolbar.
2. Select the imported `.crwebloc`.
3. Expected:
   - name is editable;
   - URL/browser override is locked;
   - Chrome profile hint is displayed.
4. Use Reveal in Finder and confirm the managed file exists.
5. Delete the shortcut and confirm.
6. Expected: the managed shortcut directory is sent to macOS Trash; it is not permanently erased.

## Pass criteria

All five tests pass without data loss, duplicate database records, silent profile changes, or WebDock becoming the default handler for normal `http`/`https` URLs.
