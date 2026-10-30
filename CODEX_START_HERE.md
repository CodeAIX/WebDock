# Codex: Start Here

Continue **WebDock**, a native macOS launcher for portable website launch rules.

## Read first

1. `AGENTS.md`
2. `docs/UI_V04_STATUS.md`
3. `docs/SPEC.md`
4. `docs/SYNC_AND_DEVICE_RESOLUTION.md`
5. `docs/TEST_PLAN.md`
6. `docs/DEVICE_ACCEPTANCE.md`

The release target is 0.5.0 (8), promoted from validated 0.4.1 (7) without runtime behavior changes.
UI-1 through UI-5 and the feedback patch are tracked in PRs #25–30. The user accepted the icon,
confirmed Intel macOS 13.6.9 validation passed and explicitly authorized GitHub release on 2026-10-30. Check live
branch heads and CI before acting; implementation, automated checks and real-device acceptance
are separate states. Do not restart the historical bootstrap/import milestones.

## Build and validate

Use Xcode 26+ and XcodeGen, with deployment target macOS 13.0. Generate from project.yml, run
the 45-test suite and source/built-app validators, then build universal Release (arm64 + x86_64).
The app uses a standard .icon source plus older-system resources; Design/AppIcon/WebDock.icns is
the separate full-size ICNS export. See docs/SMOKE_BUILD.md and the CI workflows.

Use scripts/prepare_ui_validation.py for isolated UI work. Never use the normal library for
automated restore/delete/sync experiments. scripts/collect_device_acceptance.sh inspects a package
and host without launching the app or reading browser profiles/library data.

## Remaining gates

Intel macOS 13.6.9 validation is passed by user report. The user has authorized merging and releasing
0.5.0. Additional real two-Mac/provider/account and VoiceOver results were not separately supplied;
retain that distinction. Loopback HTTP tests are transport evidence, not production-server or
two-device acceptance. See docs/RELEASE_0.5.0.md for source/artifact contracts and release context.

Portable identity is URL + browser family + optional email. Profile N stays device-local. There
are no shortcut-file import handlers, SwiftData, Apple cloud providers or cloud entitlements.
Old issue text about macOS 14/import/iCloud is historical; current SPEC and decisions govern.
