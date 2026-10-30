# 0.5.1 (9) feedback candidate — 2026-10-30

Base release: v0.5.0 / f227d8f. Branch: feat/v0.5.1-ui-icon-permissions. This is an unreleased
candidate for the user's four follow-up points; the v0.5.0 release and tag are unchanged.

1. Launcher Library action uses SF Symbols bookmark instead of rectangle.grid.1x2. Its action,
   tooltip, keyboard shortcut and accessibility label retain the existing Library semantics.
2. The entire padded Settings row has a rectangular content shape. Blank space inside a row is
   clickable; spacing between rows is not part of either target. Native keyboard/button behavior stays.
3. Appearance offers local ICNS selection, preview and Restore Default Icon. Up to 16 MiB, valid
   ICNS header/declared length and a decodable image are required. Data is copied atomically to
   Application Support/WebDock/Appearance/CustomAppIcon.icns. It survives app restart and is never
   part of canonical data, portable backups or provider payloads. An asynchronous native sheet
   selects the local file; no upload, signed resource replacement or browser data access is involved.

The selected icon overrides the **running Dock / app switcher** via NSApplication.applicationIconImage.
Finder retains the installed app icon, as explained in Settings. Testing NSWorkspace.setIcon on an
isolated diagnostic app showed it attaches FinderInfo metadata and causes strict codesign validation
to fail. That approach is not in the final implementation. It must not be restored silently as a
way to promise Finder customization while claiming the installed bundle signature remains intact.
The user was asked asynchronously whether runtime-only scope meets their preference.

4. Browser profile discovery now attempts the Local State read directly. Only a true no-such-file
   result becomes an empty list; permission failures propagate to the existing access-required UI.
   The old fileExists preflight could return false for an inaccessible directory and report zero
   accounts. A temporary Unix-permission test proves this distinction without touching TCC settings.

## Reinstallation and privacy permissions

The released 0.5.0 and earlier 0.4.1 package both have ad-hoc designated requirements consisting of
their concrete cdhash values, and those values differ. Apple TN3127 explains that privacy grants
track code identity via designated requirements and ad-hoc code is tied to a specific build. This
is a strong explanation for stale permission records after replacing a build, not proof from the
user's TCC logs. It is not a rule that every reinstall of an identical package must require deletion.

Stable Developer ID signing with the same app identity is the distribution improvement. Credentials
are not currently configured. Fixed Applications placement and avoiding concurrently running old
copies also reduce ambiguity. This patch improves actual read attempts and error reporting; it does
not claim to solve cross-build permission continuity for ad-hoc signatures. It never runs tccutil,
edits the TCC database, resets grants, adds an identifier-only signing requirement, or grants access.

Primary references:
- [Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
- [Apple DTS on ad-hoc signing and Files & Folders](https://developer.apple.com/forums/thread/125438)
- [AppKit runtime icon](https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage)
- [NSWorkspace file icon and write requirements](https://developer.apple.com/documentation/appkit/nsworkspace/seticon(_:forfile:options:))

## Validation boundary

50 tests cover existing behavior, ICNS persistence/restart/reset, invalid-file and storage-failure
preservation, exclusion from portable backups, missing metadata and real temporary directory read
denial. Settings hit testing and actual runtime icon selection/reset/restart require isolated XMAC
UI checks, plus native Intel acceptance before this candidate is promoted. The previous Intel pass
applies to 0.5.0; it is not copied onto this new feature. No new release is published by these changes.
