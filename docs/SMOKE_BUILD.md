# WebDock Smoke Build

The `macOS Smoke Build` GitHub Actions workflow produces a downloadable `WebDock-smoke-macos.zip` for interactive testing on a real Mac.

## What this build is

- Release configuration.
- Built on GitHub's macOS runner from the exact repository commit.
- Ad-hoc signed so the app bundle has a coherent local-test code signature.
- Packaged with `ditto` to preserve macOS bundle/resource metadata.
- Includes a SHA-256 checksum next to the ZIP.
- Intentionally signed **without restricted iCloud/CloudKit entitlements**.

## What this build is not

It is **not** signed with an Apple Developer ID/development certificate, does not contain a provisioning profile, and is **not notarized by Apple**. It is a local smoke-test artifact, not the final distributable release.

Because iCloud/CloudKit is a restricted macOS entitlement that must be authorized by a provisioning profile, the smoke artifact must not claim the production CloudKit entitlement. iCloud sync therefore reports itself as unavailable in this build. A properly provisioned Apple-signed build is required for real CloudKit testing.

## Install for testing

1. Open the successful `macOS Smoke Build` workflow run in GitHub Actions.
2. Download the `WebDock-smoke-macos` artifact.
3. Extract `WebDock-smoke-macos.zip`.
4. Move `WebDock.app` to `/Applications` or `~/Applications`.
5. On first launch, use Finder's **Open** command from the context menu if macOS warns that the developer cannot be verified.
6. If macOS still blocks the app, use **System Settings → Privacy & Security → Open Anyway** for WebDock.

Do not disable Gatekeeper system-wide.

## Interactive acceptance

At minimum verify:

- cold launch shows the Launcher panel;
- clicking the running WebDock Dock icon toggles the panel;
- a shortcut can be created manually from the Launcher or Manager;
- Browser Family and Account Email persist after relaunch;
- a matching Chromium account resolves to the correct local profile;
- a missing account shows a warning but still opens in the selected browser's default profile;
- a missing browser falls back to the system default browser with a warning;
- this-Mac browser/profile overrides do not change the synced launch rule;
- grid drag-reorder persists after relaunch;
- deleting a shortcut creates a tombstone and it does not return after relaunch;
- selecting iCloud in this ad-hoc smoke build reports sync as unavailable rather than crashing or preventing app launch.

## Final distribution later

A production release should replace ad-hoc signing with:

1. an Apple Developer signing identity;
2. an App ID / provisioning profile that authorizes the CloudKit capability;
3. the `iCloud.io.github.codeaix.WebDock` container entitlement;
4. hardened-runtime verification;
5. Apple notarization and stapling where applicable;
6. a signed/notarized ZIP or DMG release artifact.
