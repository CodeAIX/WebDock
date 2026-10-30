# Known Limitations — 0.4.1 (7), 2026-10-30

- Implementation and automatic checks are complete for UI-1–5 and the current feedback patch;
  required native Intel macOS 13.6.9 and real two-device/account acceptance remain open. See
  UI_V04_STATUS.md and DEVICE_ACCEPTANCE.md. Apple Silicon or Rosetta cannot close the Intel gate.
- Real WebDAV server configuration, credentials, TLS, network failures and external folder transport
  still require device acceptance. Loopback HTTP tests establish actual URLSession GET/PUT, ETag,
  icon/tombstone transfer and failure preservation, not production-server or two-Mac behavior.
- The app targets macOS 13.0 but its .icon source requires Xcode 26+ to build. The accepted icon is
  verified on XMAC; older-system visual appearance still needs native Ventura confirmation.
- Sync conflicts use whole-record updatedAt/tombstone semantics, not field-level merging. Pre-Sync
  and Pre-Restore local snapshots provide recovery; optional client-side encryption is not implemented.
- Devices editing shared icons should all use v0.4+, because older v0.3 writers drop unknown fields.
  Icon files are retained for old backup recovery; automatic garbage collection is not implemented.
- Test packages are ad-hoc signed and not notarized. Developer ID signing/notarization is a later
  distribution step, after required acceptance and suitable signing credentials.
- Exact Dock tile anchoring uses supported public positioning heuristics; no private Dock APIs.

Shortcut-file import and Apple cloud providers are intentionally outside the current product.
Earlier skeleton/import notes and old issue descriptions do not describe this implementation.
