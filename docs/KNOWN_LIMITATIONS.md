# Usage and distribution limits

- WebDock must be running for its global shortcut to work. System symbolic shortcuts and exclusive
  native registrations are checked; third-party keyboard/event-tap utilities may intercept keys.
- Browser accounts and browsers must already exist on each Mac. WebDock does not transfer browser
  sign-ins, cookies, passwords or browser profile folders. Ambiguous/missing accounts use a fallback.
- macOS manages browser metadata permission. Ad-hoc signed updates may require renewed authorization.
- Runtime ICNS customization applies to Dock/app switcher only; Finder retains the installed icon.
- Synchronization uses whole-record timestamps/tombstones, not field-level conflict merging.
  Pre-Sync/Pre-Restore local snapshots provide recovery; client-side encryption is not implemented.
- Portable backups/sync include configured account emails and website icons. Choose a trusted
  destination and HTTPS for remote WebDAV. External file transport and WebDAV availability depend
  on the selected service; a connection check is not proof of all read/write/recovery scenarios.
- Referenced icon data is retained for backup recovery; automatic icon garbage collection is absent.
- Positioning near the Dock uses public screen/Dock-position heuristics, not private tile APIs.
- Packages are ad-hoc signed and not Apple notarized. First launch may need explicit macOS approval.
- Building the modern icon source requires Xcode 26+; the application deployment target is macOS 13.
- Browser shortcut-file import and an integrated Apple cloud provider are outside the product.
