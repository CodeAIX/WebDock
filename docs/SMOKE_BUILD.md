# WebDock Smoke Build

The `macOS Smoke Build` workflow produces `WebDock-smoke-macos.zip` for interactive testing on real Macs.
The download also contains collect_device_acceptance.sh and DEVICE_ACCEPTANCE.md for read-only
package/host evidence and the remaining native-device checklist.

## Build contract

- Release configuration.
- Deployment target macOS 13.0.
- Universal executable containing arm64 and x86_64 slices.
- Ad-hoc signed without restricted entitlements.
- Packaged with `ditto` to preserve bundle metadata.
- SHA-256 checksum included.
- Built from the exact repository commit.

WebDock has no Apple cloud entitlement/provider. Synced Folder and WebDAV work without paid Apple developer capabilities.

## What this build is not

It is not Developer ID signed and is not notarized. First launch may therefore require Finder **Open** and/or System Settings > Privacy & Security > Open Anyway. Do not disable Gatekeeper system-wide.

Because browser profile metadata may be protected by macOS, browser-account access is a separate OS permission concern from code signing. WebDock can initiate the access request but the user controls the Files & Folders switch.

## Interactive acceptance

### Both architectures
- cold launch shows Launcher;
- Dock click show/hide/reactivation remains correct;
- Launcher/Manager manual create works;
- edit/delete/reorder persist after relaunch;
- Browser Family + Account Email persist;
- matching Chromium account resolves to correct local Profile;
- missing account/browser warnings and fallback work;
- local overrides stay local.

### Browser access UX
- first-run Browser Account Access sheet appears;
- Authorize/Rescan attempts browser metadata access;
- Settings shows access state;
- Open Privacy & Security opens the relevant System Settings area as closely as supported by that macOS release.

### Backup
- Back Up Now creates a local `.webdockbackup` snapshot;
- Export Portable Backup creates a portable file;
- portable file contains account email but no local Profile N;
- Replace and Merge restore both work;
- pre-restore backup is created.

### Sync
- Synced Folder writes/reads `WebDockSync.json`;
- WebDAV credentials are saved in Keychain;
- Sync Now reports success/failure without corrupting local data;
- two Macs may map the same account email to different Profile directories.

### Intel Ventura gate

On the designated Intel macOS 13.6.9 machine verify launch, create/edit/reorder, browser routing, backup/restore, and at least one synchronization provider.

## Distribution later

Developer ID signing/notarization remains desirable for smoother Gatekeeper behavior, but it is not a functional requirement for WebDock backup or synchronization. Synced Folder and WebDAV require no Apple cloud entitlement.
