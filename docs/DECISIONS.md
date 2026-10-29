# Architecture Decisions

## ADR-001 — Native SwiftUI + AppKit

Status: Accepted.

Reason: WebDock depends heavily on Dock lifecycle, `NSPanel`, `NSWorkspace`, Finder file-open events, and native macOS presentation. A web shell adds complexity without benefit.

## ADR-002 — Use NSPanel for the launcher

Status: Accepted.

Reason: There is no supported public API to anchor an `NSPopover` precisely to a Dock tile. We position an `NSPanel` near the Dock edge inferred from `NSScreen.visibleFrame`.

## ADR-003 — Preserve Chrome `.crwebloc`

Status: Superseded by ADR-007 for new imports. Retained only for legacy compatibility.

Historical reason: before WebDock had verified browser-profile routing of its own, preserving the original `.crwebloc` was the safest way to keep Chrome `CrProfile` semantics.

Current policy: existing legacy records that already use `originalShortcutFile` continue to launch unchanged until safely migrated. New `.crwebloc` imports are parsed into editable WebShortcut rules instead of becoming permanent managed files.

## ADR-004 — No App Sandbox in v0.1

Status: Accepted for direct/private distribution.

Reason: Simplifies Finder file adoption, browser profile discovery, and public `NSWorkspace` integration. Revisit only if Mac App Store distribution becomes a goal.

## ADR-005 — External `.app` Web Apps are references in v0.1

Status: Accepted.

Reason: Moving browser-managed app bundles may break registration/update assumptions. WebDock stores an external reference and does not delete the original by default.

## ADR-006 — SwiftData persistence

Status: Accepted.

Reason: macOS 14+ target and simple local model. SwiftData stores canonical shortcut metadata; filesystem storage is reserved for icons, cache, temporary browser-routing files, recovery staging, and legacy managed sources during migration.

## ADR-007 — Canonical editable WebShortcut rules

Status: Accepted.

A website shortcut is fundamentally a launch rule, not a browser-exported file. The canonical representation is:

`URL + browser + optional profile/account + name + icon + group + order`

`.crwebloc`, `.webloc`, `.url`, direct URL input, and manual creation are import/creation surfaces that converge on the same WebShortcut model.

Consequences:

- New `.crwebloc` imports parse `URL` and `CrProfile`, then become ordinary editable shortcuts.
- Chrome profile routing uses a transient WebDock-generated `.crwebloc` containing `URL + CrProfile` at launch time; the imported source file is not needed afterward.
- `.webloc` and `.url` are likewise normalized into URL-based records.
- Source type remains provenance metadata and must not restrict editing after normalization.
- `originalShortcutFile` is legacy-only and should disappear after safe migration of existing records.
- Browser profile directory is the stable routing key; account/profile names and email are display metadata that can be refreshed from the browser's local profile metadata.

## ADR-008 — Imported source files are disposable inputs

Status: Accepted.

For normalized website imports:

1. inspect source without mutation;
2. persist and verify the canonical WebShortcut record;
3. only after DB success, move the source file to macOS Trash;
4. if Trash cleanup fails, keep both source and imported record rather than risking data loss.

No imported website shortcut file is required for future launch.

Legacy managed source files are excluded from this rule until migrated.

## ADR-009 — Shortcut creation belongs to Launcher/Manager, not Settings

Status: Accepted.

Creating a website shortcut is content management, not application configuration. The primary entry points are:

- Launcher `+` button;
- Manager `+` button;
- future `File > New Shortcut` / `⌘N` command.

Settings should contain global defaults only, such as preferred browser/profile for new shortcuts, import cleanup behavior, and privacy/display preferences.
