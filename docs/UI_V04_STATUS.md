# WebDock UI v0.4 implementation handoff — 2026-10-30

Baseline: main 4d4dd96aa6cbe371c91bf0a5d12f604190bd2922. Working checkout is source/ under
/Users/x/Agent/WebDock. Initial UI-5 build is 0.4.0 (4); validated candidate 0.4.1 (7) is promoted
to release 0.5.0 (8), macOS 13.0, arm64 + x86_64.

## Release authorization — 2026-10-30

The user reports Intel macOS 13.6.9 validation passed and explicitly requests the formal GitHub
0.5.0 release. Earlier XMAC validation was basically normal and the replacement icon was accepted.
This authorizes completing the ordered PR integration and publication after green release checks.
No itemized Intel report or additional real two-device/provider/VoiceOver result was supplied;
do not manufacture those results. See RELEASE_0.5.0.md and live GitHub PR/release state.

## XMAC feedback follow-up — 2026-10-30

The user reports XMAC validation is basically normal, with missing app branding, overlapping focus
frames and a request for Chinese/English UI. Branch feat/v0.4.1-branding-localization addresses these
in version 0.4.1, stacked on UI-5. Build 6 replaces build 5's icon with the user's globe-and-Dock
artwork and removes the white outer backing in the native XMAC About panel. A standalone ICNS is
also available. The user explicitly accepted this icon on 2026-10-30. Build 7 completes the File
New Shortcut / ⌘N command and transport acceptance preparation. See V041_XMAC_FEEDBACK.md;
no new Intel or two-device acceptance is implied by the XMAC report.

## Review order

The implementation used stacked changes while device acceptance was pending. Intel acceptance is
now confirmed by the user and release integration is authorized.
Review/accept/merge in order; update dependent PR base branches after each merge.

| Phase | Branch | Draft PR | Contents |
| --- | --- | --- | --- |
| UI-1 | feat/ui-1-launcher-layout | #25 | Fixed top bar, persistent group sidebar, direct actions |
| UI-2 | feat/ui-2-library-settings | #26 | Library cards, accounts, groups/duplicate, six Settings pages |
| UI-3 | feat/ui-3-shortcut-icons | #27 | Optional icon metadata, discovery/cache, manual icons, browser badge |
| UI-4 | feat/ui-4-portable-icons | #28 | Shared backup/sync icon payload, validation and safety snapshots |
| UI-5 | feat/ui-5-interaction-polish | #29 | Focus, menu, density, accessibility, editor safeguards, diagnostic fixture |

GitHub PR checks are the live authority for each branch head's remote CI and smoke builds.
The table records the original review stack; live GitHub PR state is authoritative for integration.

## Validation established

- Local tests: UI-1 26, UI-2 27, UI-3 30, UI-4 34; final combined suite 37 tests passed.
- Each phase generated the project, built/tested at deployment target 13.0, and built a universal
  Release. Smoke packages verify arm64/x86_64, built minimum OS 13.0, ad-hoc signature and ZIP integrity.
- Source/LaunchServices contracts remain: no shortcut-file/HTTP(S) import registration, no SwiftData
  or Apple cloud provider/entitlement in active sources. Existing launch routing/fallback stays intact.
- Independent-root tests establish custom icon replace/merge backup and folder transport; injected
  WebDAV transport tests cover byte preservation, ETag, initial create and 412. Corrupt assets cannot
  replace canonical state. A test verifies edits during remote GET survive.
- Isolated XMAC UI checks establish layout/theme/navigation, draft preservation, keyboard focus,
  menus, delete confirmation/Cancel, Compact/hidden-subtitle/browser-badge settings, Return launching Google in the system default Safari, and live public icon discovery. The
  test-created Safari page was closed afterwards. Real drag moved ChatGPT after Google and the
  resulting order was verified in Canonical.json and survived a real app restart. Drag uses live, reversible reorder with per-session
  nonce validation rather than depending only on a native drop-finish callback. The final Button-based
  tiles were checked for both arrow focus and actual drag reordering on macOS 27.0.1 arm64.
  Five reference icons: ChatGPT 180px, Claude 512px, Google
  192px, DeepSeek 512px, GitHub 512px. Network availability can differ on another Mac.

## Data and portability

Canonical.json adds optional iconMode/iconAssetID/iconSourceURL; old files still decode. Normalized
PNG assets live at Icons/<SHA256>.png. Portable snapshots embed only referenced active PNGs as an
optional iconAssets map, allowing a single atomic file / WebDAV ETag transaction. Local browser paths,
Profile N, warning state, permissions and device overrides remain excluded. All devices editing
icons should upgrade to v0.4; v0.3 writers drop unknown fields. Limits and recovery details are in
SYNC_AND_DEVICE_RESOLUTION.md. No automatic icon garbage collection removes old backup assets.

Before the first icon metadata change, a safety snapshot is required. Restore and sync require
successful safety snapshots before library replacement. Snapshot filenames use a random suffix to
avoid same-second overwrites. Invalid payloads fail before canonical updates; unreferenced installed
files can remain after an I/O failure. They are harmless and retained for recovery.

## Acceptance history / additional coverage

- Intel macOS 13.6.9 validation: passed by user report on 2026-10-30.
- Real account permission and exact Chromium routing after redesign, including local overrides.
- Two real Macs with the same email mapped to different local Profile N values; folder and real
  WebDAV icon transport, offline restart, restore, conflict/network-failure behavior.
- Full drag/drop/restart, deletion, density and VoiceOver acceptance on both target Macs.
- Keyboard and system-default Return launch were checked on XMAC; the user now reports Intel validation passed.
- The icon is visually accepted. Other itemized device evidence is not inferred from automated tests.

The application icon is accepted. New automatic evidence (build 7): 45 tests, including real TCP /
URLSession WebDAV transfer between two isolated local stores, icon/tombstone transfer, ETag conflict
rejection and fresh merge, HTTP/corrupt-payload failure preservation, offline restart/restore and
safety snapshots. This is still one host and an in-process loopback server. XMAC native UI also
verified the File command in Launcher/Library/Settings, repeated-command form retention, unsaved
Library draft retention and successful new-record persistence after restart. DEVICE_ACCEPTANCE.md
and scripts/collect_device_acceptance.sh provide the remaining native-device evidence workflow.

The design's optional future navigation (Favorites/Recent), login/Dock/menu-presence controls and
resizable sidebar are not added. Existing groups and a remembered 200pt sidebar cover this phase.
No inert preferences are displayed. A read-only WebDAV Test Connection does not prove PUT permission.

## Continue from here

Read this file, AGENTS.md, TEST_PLAN.md, SPEC.md and SYNC_AND_DEVICE_RESOLUTION.md, then inspect
current code and live PR checks. Use the UI-5 smoke package for full-stack review. Preserve the
normal library; scripts/prepare_ui_validation.py produces a separate Debug app/library for UI work.
Follow the real-device checklist before changing draft status or merging. Do not restart UI-1 or
replace the JSON/backup/sync/browser architecture with the historical designs.
