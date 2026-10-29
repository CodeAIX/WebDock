# Known Limitations — Starter Skeleton

This repository is intentionally an implementation starter, not a finished app.

- The Xcode project/targets have not yet been generated; Issue #1 is the bootstrap task.
- `ImportCoordinator` contains only a guarded starter move/rollback path. Replace it with a tested `ImportTransaction` before calling imports production-safe.
- `specifiedBrowser` and external `.app` launch modes are placeholders.
- Manager UI, grouping, reordering, icon management, and polished keyboard navigation are not yet implemented.
- Dock/Finder document type declarations must be verified against real macOS UTType metadata before finalizing `Info.plist`.
- Exact Dock tile anchoring is intentionally not implemented because the design uses only supported public APIs.
