# WebDock Smoke Build

The `macOS Smoke Build` GitHub Actions workflow produces a downloadable `WebDock-smoke-macos.zip` for interactive testing on a real Mac.

## What this build is

- Release configuration.
- Built on GitHub's macOS runner from the exact repository commit.
- Ad-hoc signed so the app bundle has a coherent code signature.
- Packaged with `ditto` to preserve macOS bundle/resource metadata.
- Includes a SHA-256 checksum next to the ZIP.

## What this build is not

It is **not** signed with an Apple Developer ID certificate and it is **not notarized by Apple**. It is a development/smoke-test artifact, not the final distributable release.

## Install for testing

1. Open the successful `macOS Smoke Build` workflow run in GitHub Actions.
2. Download the `WebDock-smoke-macos` artifact.
3. Extract `WebDock-smoke-macos.zip`.
4. Move `WebDock.app` to `/Applications` or `~/Applications`.
5. On first launch, use Finder's **Open** command from the context menu if macOS warns that the developer cannot be verified.
6. If macOS still blocks the app, use **System Settings → Privacy & Security → Open Anyway** for WebDock.

Do not disable Gatekeeper system-wide.

## Interactive acceptance

After launch, follow `docs/DOCK_DROP_SMOKE_TEST.md`.

At minimum verify:

- cold launch shows the Launcher panel;
- clicking the running WebDock Dock icon toggles the panel;
- Manager opens from the Launcher;
- grid drag-reorder persists after relaunch;
- `.crwebloc` can be dropped onto the Dock icon and opens later with the original Chrome profile;
- `.webloc` and `.url` import successfully;
- malformed shortcuts remain at the original Finder location;
- deleting a managed shortcut sends its managed files to Trash.

## Final distribution later

A production release should replace ad-hoc signing with:

1. Developer ID Application signing;
2. hardened-runtime verification;
3. Apple notarization;
4. stapling where applicable;
5. a signed/notarized ZIP or DMG release artifact.
