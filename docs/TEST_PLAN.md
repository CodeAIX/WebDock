# Validation plan

## Automated coverage

- URL validation, conservative account normalization, canonical identity and tombstones.
- Atomic JSON persistence, reload, unsupported schemas and write-failure preservation.
- Exact/absent/ambiguous account matching, browser disappearance, local overrides and fallbacks.
- Browser metadata missing-file versus actual temporary-directory read denial.
- Transient Chromium URL/CrProfile launch routing and default-browser fallback.
- Portable icon normalization/hash/size limits, embedded assets, invalid imports and offline restore.
- Replace/Merge restore, Pre-Restore/Pre-Sync snapshots and device-binding exclusion.
- Folder synchronization, timestamp/tombstone merge, actual loopback HTTP GET/PUT/ETag/412,
  icon transfer, damaged response, service failure and local state preservation.
- ICNS persistence/reset, invalid/storage-failure preservation and portable-backup exclusion.
- Hotkey persistence/disabled restart, recording cancellation, failed replacement rollback,
  stale callbacks, startup retry, corrupt preference fallback and native exclusive registration/release.
- Deferred Dock/global activation state ordering and preservation across late resign notifications.
- English/Chinese localization and placeholder integrity.

## Source and package contracts

Generate with XcodeGen. Build/test against macOS 13.0 and build universal arm64 + x86_64 Release.
Check source/built Info.plist, minimum OS, icon stack/legacy resources, standalone ICNS alpha
representations, localization and absence of shortcut-file/HTTP(S) handlers or restricted entitlements.
Verify strict signature, ZIP integrity, read-only DMG mounting, extracted app byte correspondence,
tagged-source archive correspondence and SHA-256 checksums. Verify published downloads as well.

## Real-Mac checklist

Use a separate diagnostic library and public test websites. Keep normal user data protected.

- Launch, Dock toggle/reopen, near-Dock placement and default icon on supported macOS versions.
- Search, groups, keyboard navigation, context actions, create/edit/duplicate/delete/reorder and restart.
- Unsaved draft preservation and repeated-command protection in Launcher, Library and Settings.
- Entire Settings sidebar row, including blank padding, responds to mouse clicks.
- Global shortcut from another foreground app; custom recording, conflict, cancellation, reset,
  disabled state, real restart retention and existing modal-sheet behavior.
- Follow System/Chinese/English, live content update and native menus after restart.
- Light/dark/system appearance, density, subtitles, badges and sidebar preferences.
- Native ICNS picker, runtime Dock/app-switcher change, real restart, reset and signature invariance.
- Actual macOS browser metadata permission and profile-specific launch on each native platform.
- Missing account/browser fallbacks and device-only overrides.
- Portable export, both restore modes, safety snapshots and restart/offline behavior.
- Two Macs: same email resolves to different local profile directories; create/order/delete/icon sync.
- Actual selected WebDAV server: read AND write, conditional conflict, offline recovery and TLS behavior.
- VoiceOver labels and native keyboard focus.

Package checks, loopback HTTP, emulation and user-reported acceptance have distinct evidence
boundaries. Do not infer native Intel or real two-device/provider results from an Apple Silicon build.
Record results outside product documentation; see DEVICE_ACCEPTANCE.md for collection instructions.
