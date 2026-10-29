# AGENTS.md — Codex instructions for WebDock

Read `docs/SPEC.md` before changing code. Treat it as the product contract.

## Priorities

1. Reliability of import and launch.
2. Preserve Chrome `.crwebloc` behavior and `CrProfile` by retaining and opening the original managed shortcut file.
3. Never use private Dock APIs or Accessibility hacks to locate the Dock tile.
4. Avoid destructive file operations. Imports must be transactional and deletions should go through Trash when possible.
5. Keep the app native: Swift + SwiftUI + AppKit. Do not introduce Electron/Tauri.
6. Keep third-party dependencies at zero unless there is a strong documented reason.
7. Do not add an embedded browser/WebView for launching shortcuts.

## Target

- macOS 14+
- Swift 6 or the current stable Swift mode available in the installed Xcode
- Bundle ID: `io.github.codeaix.WebDock`

## Architecture

- SwiftUI for views.
- AppKit for lifecycle, Dock integration, `NSPanel`, `NSWorkspace`, Finder/open-file events.
- SwiftData for persistence.
- `OSLog` for diagnostics.
- Wrap OS integrations behind protocols so tests can mock them.

## Workflow

Implement in small, buildable increments. After each meaningful feature:

1. Build.
2. Run tests.
3. Commit with a focused message.
4. Update docs if behavior differs from the spec.

If an Apple API limitation requires changing a non-negotiable requirement, document the evidence first in `docs/DECISIONS.md`; do not silently work around it with private APIs.

## Definition of Done

Use the acceptance checklist in `docs/SPEC.md` and `docs/TEST_PLAN.md`.
