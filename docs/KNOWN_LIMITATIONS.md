# Known Limitations — 0.5.0 (8), 2026-10-30

- The user reports native Intel macOS 13.6.9 validation passed and authorizes the 0.5.0 release.
  Additional real two-device/account/provider and VoiceOver evidence remains separately tracked.
  See DEVICE_ACCEPTANCE.md. Apple Silicon or Rosetta is not used as Intel evidence.
- Real WebDAV server configuration, credentials, TLS, network failures and external folder transport
  still require device acceptance. Loopback HTTP tests establish actual URLSession GET/PUT, ETag,
  icon/tombstone transfer and failure preservation, not production-server or two-Mac behavior.
- The app targets macOS 13.0 but its .icon source requires Xcode 26+ to build. The accepted icon is
  verified on XMAC; the user's Intel pass does not include an attached itemized visual report.
- Sync conflicts use whole-record updatedAt/tombstone semantics, not field-level merging. Pre-Sync
  and Pre-Restore local snapshots provide recovery; optional client-side encryption is not implemented.
- Devices editing shared icons should all use v0.4+, because older v0.3 writers drop unknown fields.
  Icon files are retained for old backup recovery; automatic garbage collection is not implemented.
- Release packages are ad-hoc signed and not notarized. No Developer ID identity or signing secrets
  were configured at publication preparation; Developer ID/notarization remains a later distribution step.
- Exact Dock tile anchoring uses supported public positioning heuristics; no private Dock APIs.

Shortcut-file import and Apple cloud providers are intentionally outside the current product.
Earlier skeleton/import notes and old issue descriptions do not describe this implementation.
