# Architecture Decisions

## ADR-001 — Native SwiftUI + AppKit

Status: Accepted.

Reason: WebDock depends heavily on Dock lifecycle, `NSPanel`, `NSWorkspace`, Finder file-open events, and native macOS presentation. A web shell adds complexity without benefit.

## ADR-002 — Use NSPanel for the launcher

Status: Accepted.

Reason: There is no supported public API to anchor an `NSPopover` precisely to a Dock tile. We position an `NSPanel` near the Dock edge inferred from `NSScreen.visibleFrame`.

## ADR-003 — Preserve Chrome `.crwebloc`

Status: Accepted.

Chromium stores `URL` and `CrProfile` in the shortcut. WebDock may parse these fields for display, but launch should open the managed original file so Chrome owns profile dispatch.

## ADR-004 — No App Sandbox in v0.1

Status: Accepted for direct/private distribution.

Reason: Simplifies transactional adoption of Finder files and reopening managed shortcut files with external browsers. Revisit only if Mac App Store distribution becomes a goal.

## ADR-005 — External `.app` Web Apps are references in v0.1

Status: Accepted.

Reason: Moving browser-managed app bundles may break registration/update assumptions. WebDock stores an external reference and does not delete the original by default.

## ADR-006 — SwiftData persistence

Status: Accepted.

Reason: macOS 14+ target and simple local model. Keep filesystem source files separately from DB metadata.
