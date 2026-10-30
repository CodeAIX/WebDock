# WebDock 0.4.1 (6) — XMAC feedback follow-up

Date: 2026-10-30. Base: UI-5 commit 4852fed. Branch: feat/v0.4.1-branding-localization.
The user reports XMAC validation is basically normal, with three remaining issues. This branch
addresses those issues without changing launch rules, storage schema, browser routing or sync payloads.

## Changes

1. **Application icon**: the user rejected build 5's browser-window mark and its white backing.
   Build 6 uses the user's uploaded globe-and-Dock artwork, with exterior white background removed
   using built-in image_gen. Design/AppIcon/ contains the transparent master, exact final prompt,
   and a standalone WebDock.icns with ten 16–1024px representations. Standard WebDock.icon source
   fills the modern system mask; Xcode builds Assets.car and compatibility WebDock.icns. The native
   About panel at 0.4.1 (6) was checked on XMAC without the silver-white outer plate. See the design
   README for reproduction and the distinction between standalone export and compiled resources.
2. **Focus**: the custom selected-tile stroke was stacked with the system focus ring. The extra
   stroke is removed. Launcher tiles remain native buttons and retain keyboard focus accessibility;
   launching clears SwiftUI focus instead of retaining a persistent selection. Clicking a website,
   reopening Launcher, and returning to ⌘F → Return → arrow navigation were checked locally.
3. **Languages**: General → Display Language provides Follow System, 简体中文 and English. The
   default matches the first supported macOS global preferred language, falling back to English.
   All Chinese variants use Simplified Chinese. Manual selection persists in app-local preferences;
   Follow System removes only WebDock's AppleLanguages override. No OS/global preference is changed.

App content updates immediately without reconstructing the editor or losing draft fields.
macOS-owned menus/dialogs complete their language change after restarting WebDock; the UI explains
this. English selection was verified after restart, and Follow System restored Chinese and native
Chinese menus on this XMAC. These language preferences are device-local and are never synchronized.

## Localization boundary

English localization keys are stable. en.lproj and zh-Hans.lproj contain 255 matching entries,
including dialogs, permission guidance, settings, status, accessibility and app errors. Native
permission usage text has matching InfoPlist.strings. Browser brands, user-created names, URLs,
account emails, Profile directories, JSON/plist keys, UUIDs and raw preference values are unchanged.
Persisted device warnings remain in their original form and are translated only for display.

scripts/validate_localizations.py checks key parity, placeholders and protocol-key isolation.
scripts/validate_app_icon.py checks all ten standalone ICNS slots and alpha channels, modern source,
and the built modern stack, legacy multi-size representations and bundle references. Both
validators run in the regular CI and universal smoke workflow. Localization tests cover system
matching, explicit overrides, persistence/removal, bundled resources, formatted warnings and stable
portable identities. The Chromium launch payload remains URL + CrProfile in every language.

## Validation / remaining acceptance

Local combined suite: 42 tests. Build target remains macOS 13.0 and Release arm64 + x86_64.
Live UI checks use an isolated diagnostic app/library: system Chinese, manual English, restart
persistence/native menus, draft retention, single keyboard focus, and no retained tile focus after
opening a website. Temporary browser pages were closed. The normal user library was not used.

XMAC user acceptance of this patch is still pending; the earlier user report is recorded above.
Intel macOS 13.6.9 and outstanding two-device/real-account acceptance remain required before release.
See the PR's live checks and the artifact validation report for final build/package/CI results.
