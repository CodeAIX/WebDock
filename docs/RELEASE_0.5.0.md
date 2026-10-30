# WebDock 0.5.0 (8) release record

Date: 2026-10-30. Release target: https://github.com/CodeAIX/WebDock/releases/tag/v0.5.0

The user confirmed Intel macOS 13.6.9 validation passed and explicitly requested the formal
GitHub release. Earlier XMAC validation and acceptance of the replacement icon are recorded in
UI_V04_STATUS.md. Version 0.5.0 (8) promotes candidate 0.4.1 (7) with version/documentation changes;
no runtime feature change is introduced after that accepted candidate.

The user's report is acceptance evidence, not an independently captured itemized Intel report.
Additional real two-device/provider/VoiceOver results were not separately supplied. They remain
documented as coverage limits without overriding the user's explicit publication instruction.

Release verification must establish:

- 45 tests at deployment target macOS 13.0; current head CI and universal smoke green.
- Source/localization/icon/LaunchServices contracts; no cloud entitlement or SwiftData regression.
- Release app version 0.5.0 (8); arm64 + x86_64, both minimum OS 13.0.
- Strict ad-hoc signature, entitlements inspection, ZIP/DMG integrity and SHA-256 hashes.
- Tagged source archive corresponds byte-for-byte to released source; release assets are
  downloaded after publication and compared to their published checksums.

No valid Developer ID identity or repository signing secrets were configured during preparation.
Packages use ad-hoc signing and are not notarized; this must be stated on the release page.
Formal GitHub release status does not imply Developer ID signing or Apple notarization.

Integrate the reviewed UI-1 through UI-5 stack and final feedback/release patch in PR order,
using merge commits to retain ancestry. Tag the integrated main commit as v0.5.0. Publish a stable,
latest GitHub Release with DMG, universal app ZIP, source ZIP, standalone ICNS and SHA256SUMS.txt.
Local detailed validation logs/hashes/CI snapshots live under artifacts/v0.5.0 outside the checkout.
