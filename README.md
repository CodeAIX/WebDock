# WebDock

WebDock is a native macOS website-shortcut launcher and manager designed to live as one icon in the Dock.

Instead of installing many browser web apps, WebDock stores/organizes shortcuts and launches them back into the appropriate normal browser context. Chrome `.crwebloc` shortcuts are preserved so Chrome can honor their `CrProfile` field.

## Status

This repository handoff contains an implementation-ready specification and starter source skeleton. The first development target is WebDock v0.1 for macOS 14+.

## Start here

1. Read `AGENTS.md`.
2. Read `docs/SPEC.md`.
3. Follow `docs/IMPLEMENTATION_PLAN.md`.
4. Use `docs/TEST_PLAN.md` as the release gate.

## Product constraints

- Native Swift / SwiftUI / AppKit.
- No Electron.
- No embedded browser.
- No private Dock APIs.
- Transactional shortcut import.
- Preserve Chrome `.crwebloc` files.

## Repository

`CodeAIX/WebDock`
