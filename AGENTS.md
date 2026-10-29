# AGENTS.md — WebDock implementation rules

Read `docs/SYNC_AND_DEVICE_RESOLUTION.md` and `docs/SPEC.md` before changing product behavior.

## Priorities

1. WebDock is a manual-first website launch-rule manager, not a browser shortcut-file importer.
2. Portable shortcut identity is `URL + browser family + optional account email`; never use local `Profile N` as synced identity.
3. Device-local browser/profile resolution must degrade gracefully when a browser/account is missing.
4. Device-only overrides must never alter another Mac's canonical synced rule.
5. Keep sync payloads provider-independent. iCloud is first; WebDAV must be able to reuse the same schema.
6. Keep the app native: Swift + SwiftUI + AppKit. No Electron/Tauri and no embedded WebView.
7. Never use private Dock APIs or Accessibility hacks to locate the Dock tile.
8. Keep third-party dependencies at zero unless strongly justified and documented.

## Data boundary

### Canonical/syncable
- shortcut UUID
- display name
- HTTP/HTTPS URL
- preferred BrowserFamily
- optional target account email
- group/order
- created/updated/deleted timestamps

### Device-local only
- installed browser bundle/path
- resolved `Default` / `Profile N`
- detected account/profile display cache
- warning/resolution status
- per-Mac overrides
- favicon/runtime caches

No canonical sync payload may contain a local profile directory.

## Browser account matching

For Chromium-family browsers, match accounts using the browser's locally reported signed-in account email:
- trim surrounding whitespace;
- case-insensitive comparison via normalized lowercase;
- do not apply Gmail dot or plus-address rewriting.

If zero matches: use browser default and warn.
If multiple matches: use browser default and warn until a local override is chosen.
If browser missing: use system default and warn.

## Sync

- Canonical records use stable UUIDs.
- Deletions are tombstones so offline devices cannot resurrect records.
- CloudKit private database is the first provider.
- WebDAV credentials must eventually live in Keychain, not SwiftData or plaintext configuration.
- DeviceShortcutBinding must never be uploaded.

## Workflow

After meaningful changes:
1. generate the Xcode project;
2. build/test on macOS CI;
3. run the Release smoke build;
4. update architecture/test docs when behavior changes;
5. do not merge red CI.

## Definition of Done

Use `docs/SPEC.md`, `docs/TEST_PLAN.md`, and Issue #20 acceptance criteria.
