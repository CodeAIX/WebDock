# Build and package

## Requirements

- macOS, Xcode 26 or later and its command-line tools.
- XcodeGen 2.38 or later (`brew install xcodegen`).
- No third-party runtime packages or paid Apple capabilities are required.

The generated Xcode project is local output. Source configuration is project.yml.

```sh
xcodegen generate
python3 scripts/validate_localizations.py
python3 scripts/validate_document_types.py Config/Info.plist
python3 scripts/validate_app_icon.py
xcodebuild -project WebDock.xcodeproj -scheme WebDock \
  -destination 'platform=macOS' -derivedDataPath /tmp/WebDockDebug \
  MACOSX_DEPLOYMENT_TARGET=13.0 CODE_SIGNING_ALLOWED=NO test
```

Build a universal Release:

```sh
xcodebuild -project WebDock.xcodeproj -scheme WebDock -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath /tmp/WebDockRelease \
  MACOSX_DEPLOYMENT_TARGET=13.0 ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build
```

Use separate derived-data paths for parallel configurations. Regenerate icon assets with
`bash scripts/generate_app_icon.sh`; see Design/AppIcon/README.md.

## Distribution checks

Verify both architecture slices and their minimum OS, built Info.plist and all icon resources.
Ad-hoc signing provides local structural integrity; it is not Developer ID signing/notarization.
Create ZIP with ditto, check its integrity and extracted signature. Create a DMG with an Applications
link, verify and mount read-only, then compare the packaged app to the signed build. Generate source
ZIP from the exact release tag and compare every tracked file. Publish SHA-256 checksums and a
manifest containing the source commit, version, architectures, minimum OS and signing status.

The macOS CI workflow builds/tests; macOS Smoke Build produces a universal ad-hoc signed ZIP and
read-only device collector. CI and package checks do not replace the native acceptance checklist.

## Working on the application

Read AGENTS.md, SPEC.md and SYNC_AND_DEVICE_RESOLUTION.md. Keep URL/browser/email portable and
all profile paths/overrides local. Use the isolated fixture for UI experiments, with automatic
backup and sync disabled. Tests and validation contracts are described in TEST_PLAN.md.
