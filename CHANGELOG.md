# Changelog

## 0.5.1 — Unreleased

- Clearer bookmark line icon for Launcher Library access.
- Full padded Settings sidebar rows respond to mouse clicks.
- Local ICNS customization of the running Dock/app-switcher icon, restart persistence and reset.
- Direct profile-metadata read preserves permission failures instead of misreporting no accounts.
- Explain ad-hoc update permission identity limits; no automatic system permission resets.

## 0.5.0 — 2026-10-30

- Native Launcher with fixed search/actions, group sidebar and keyboard navigation.
- Library editor and six Settings pages; safe draft handling and persistent reordering.
- Website/custom icons, browser badges and portable icon backup/synchronization.
- Chinese and English, system-default matching and manual display-language selection.
- Accepted globe-and-Dock app icon with modern and earlier-macOS resources.
- Single Launcher focus indicator; File → New Shortcut / ⌘N across app windows.
- Codable JSON, portable backup/restore, safety snapshots, Synced Folder and conditional WebDAV.
- 45 automated tests, including real loopback HTTP transport/conflict/failure/restore checks.
- macOS 13.0+ universal arm64 + x86_64. Intel 13.6.9 validation passed by user report.

Release packages are ad-hoc signed; Developer ID signing and notarization are not configured.
Devices sharing icon metadata should all upgrade from v0.3 to v0.5.0 to retain the added fields.
