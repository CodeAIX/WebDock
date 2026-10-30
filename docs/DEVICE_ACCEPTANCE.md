# WebDock 0.4.1 device acceptance

Current candidate: 0.4.1 (7), macOS 13.0+, Intel + Apple Silicon. The globe-and-Dock icon is
accepted by the user. Implementation and automatic checks are complete; the device gates below
remain open. Old issue descriptions about importing shortcut files, macOS 14-only support or
Apple cloud providers are historical and superseded by SPEC.md / DECISIONS.md.

## Collect evidence on each Mac

Extract the app ZIP and put collect_device_acceptance.sh beside it. In Terminal:

```sh
bash ./collect_device_acceptance.sh \
  --app ./WebDock.app \
  --output-dir ./WebDock-device-report
```

Choose a new output directory for each run. The script does not launch WebDock, change system
settings, or read its library/browser accounts. It collects OS/build, non-unique hardware model,
architecture, app version/minimum OS, executable hash and signature status. It distinguishes
Apple Silicon/Rosetta from the native Intel macOS 13.6.9 target and refuses to overwrite evidence.
It requires only built-in macOS shell tools, not Xcode, Homebrew or Python.

ENVIRONMENT.txt and SIGNATURE.txt establish package/host facts only. CHECKLIST.md starts entirely
unticked. Fill actual results after testing, with screenshots or specific failure details. Use a
dedicated test library/account; make a local/portable backup before any restore experiment. Do not
test Replace Restore on an unprotected daily library. Do not include credentials or browser data
in the report. Developers can use prepare_ui_validation.py with a Debug build for isolated UI tests.

## Required evidence

| Gate | Established | Still needed |
| --- | --- | --- |
| Icon | User accepted replacement; XMAC native About has no white outer plate | Native Ventura appearance |
| Platform | CI macOS 13 target; universal arm64/x86_64 slices | Native launch/UI/file dialogs on Intel macOS 13.6.9 |
| Launcher / Library / Settings | Isolated XMAC layout, navigation, draft/focus/drag checks | Remaining Ventura and VoiceOver checks |
| File > New Shortcut | XMAC menu / ⌘N in all three contexts, repeated-command guard, draft retention, restart persistence | Native Ventura menu/keyboard behavior |
| Language | XMAC system Chinese / English override / native-menu restart and unit tests | Final user recheck and Ventura behavior |
| Backup / sync | Independent-root tests; real loopback HTTP, icons/tombstones, ETag conflict, offline restore, safety snapshots | Real two-Mac folder/WebDAV transfer and failures |
| Browser account | Matcher, transient URL/CrProfile and fallback tests | Real permission flow and exact profile routing on each target Mac |
| Distribution | Ad-hoc signature, hashes and ZIP checks | Device acceptance before merge/release; later Developer ID/notarization |

The critical two-Mac scenario is the same signed-in email under Profile 12 on Mac A and Profile 3
on Mac B. A's portable record must not transmit Profile 12. B must open the actual intended local
browser profile. Test create/edit/order/delete/custom icons, offline restart and restore using
both Synced Folder and the intended WebDAV server. A successful read-only connection check is not
write acceptance; successful loopback HTTP is not real-server/TLS/two-device acceptance.

## Merge / release

Keep stacked PRs #25–30 in draft until the required device evidence is recorded. Their review order
is UI-1 through UI-5, then the feedback/acceptance patch. Recheck CI for each current head; after
each merge update dependent bases. Do not mark unchecked gates complete or infer native Intel
acceptance from an Apple Silicon or translated process. No release is published by the collector.
