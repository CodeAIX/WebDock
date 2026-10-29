# AGENTS.md — WebDock implementation rules

Read `docs/SYNC_AND_DEVICE_RESOLUTION.md` and `docs/SPEC.md` before changing product behavior.

## Priorities

1. WebDock is a manual-first website launch-rule manager, not a browser shortcut-file importer.
2. Portable shortcut identity is `URL + browser family + optional account email`; never use local `Profile N` as portable identity.
3. Device-local browser/profile resolution must degrade gracefully when a browser/account is missing.
4. Device-only overrides must never alter another Mac's canonical portable rule.
5. Keep all backup/sync payloads provider-independent and limited to canonical data.
6. Supported sync providers are Synced Folder and WebDAV. Do not add Apple cloud entitlements/providers back into the product.
7. Support macOS 13+ on both x86_64 and arm64.
8. Keep the app native: Swift + SwiftUI + AppKit. No Electron/Tauri and no embedded WebView.
9. Never use private Dock APIs or Accessibility hacks to locate the Dock tile.
10. Keep third-party dependencies at zero unless strongly justified and documented.

## Persistence boundary

### Canonical / portable
- shortcut UUID
- display name
- HTTP/HTTPS URL
- preferred BrowserFamily
- optional target account email
- group/order
- created/updated/deleted timestamps

Stored in `Canonical.json` and allowed in portable backups/sync.

### Device-local only
- installed browser bundle/path
- resolved `Default` / `Profile N`
- detected account/profile display cache
- warning/resolution status
- per-Mac overrides
- favicon/runtime caches

Stored in `DeviceBindings.json`. No portable backup or sync payload may contain a local profile directory.

## Browser account matching

For Chromium-family browsers, match accounts using the browser's locally reported signed-in account email:
- trim surrounding whitespace;
- compare normalized lowercase;
- do not apply Gmail dot or plus-address rewriting.

If zero matches: use browser default and warn.
If multiple matches: use browser default and warn until a local override is chosen.
If browser missing: use system default and warn.

Browser profile metadata access may be protected by macOS Files & Folders. WebDock can trigger access requests and open Privacy & Security, but must never imply it can grant the system permission itself.

## Backup and sync

- Canonical records use stable UUIDs.
- Deletions are tombstones so stale/offline replicas cannot resurrect records.
- Automatic local backups are full local snapshots and may include DeviceBindings.
- Portable `.webdockbackup` files contain canonical data only.
- Restore creates a pre-restore local snapshot first.
- Sync merge should create a pre-sync safety snapshot before applying remote changes.
- Synced Folder writes canonical `WebDockSync.json` to a user-selected ordinary directory.
- WebDAV uses the same canonical schema and conditional writes (`ETag` / `If-Match`).
- WebDAV passwords belong in macOS Keychain only.

## macOS compatibility

- Deployment target: macOS 13.0.
- Release smoke artifacts must contain both `arm64` and `x86_64` slices.
- Do not introduce SwiftData or macOS 14-only UI without an availability fallback.
- CI must verify `LSMinimumSystemVersion = 13.0`.

## Workflow

After meaningful changes:
1. generate the Xcode project;
2. build/test against the macOS 13 deployment target in CI;
3. run the universal Release smoke build;
4. update architecture/test docs when behavior changes;
5. do not merge red CI;
6. real-Mac acceptance is required for behaviors CI cannot prove, especially browser permission prompts and profile routing.

## Definition of Done

Use `docs/SPEC.md`, `docs/TEST_PLAN.md`, and the active roadmap issue acceptance criteria.
