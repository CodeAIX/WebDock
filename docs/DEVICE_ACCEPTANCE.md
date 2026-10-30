# WebDock 0.5.0 device acceptance

Release 0.5.0 (8), promoted from 0.4.1 (7), macOS 13.0+, Intel + Apple Silicon. The user accepted
the icon, confirmed Intel macOS 13.6.9 validation passed and explicitly authorized GitHub release
on 2026-10-30. This is user-reported acceptance; no itemized Intel report was attached. Additional
coverage below remains separately tracked. Old issue descriptions about importing shortcut files, macOS 14-only support or
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
| Icon | User accepted replacement; XMAC native About has no white outer plate | No itemized Ventura icon report attached |
| Platform | CI macOS 13 target; universal slices; user reports Intel 13.6.9 validation passed | Preserve detailed device reports when available |
| Launcher / Library / Settings | Isolated XMAC layout, navigation, draft/focus/drag checks | Remaining Ventura and VoiceOver checks |
| File > New Shortcut | XMAC menu / ⌘N in all three contexts, repeated-command guard, draft retention, restart persistence | Native Ventura menu/keyboard behavior |
| Language | XMAC system Chinese / English override / native-menu restart and unit tests | Final user recheck and Ventura behavior |
| Backup / sync | Independent-root tests; real loopback HTTP, icons/tombstones, ETag conflict, offline restore, safety snapshots | Real two-Mac folder/WebDAV transfer and failures |
| Browser account | Matcher, transient URL/CrProfile and fallback tests | Real permission flow and exact profile routing on each target Mac |
| Distribution | User authorizes 0.5.0 release; ad-hoc signature and package checks | Later Developer ID/notarization |

The critical two-Mac scenario is the same signed-in email under Profile 12 on Mac A and Profile 3
on Mac B. A's portable record must not transmit Profile 12. B must open the actual intended local
browser profile. Test create/edit/order/delete/custom icons, offline restart and restore using
both Synced Folder and the intended WebDAV server. A successful read-only connection check is not
write acceptance; successful loopback HTTP is not real-server/TLS/two-device acceptance.

## Merge / release

The user's 2026-10-30 instruction authorizes releasing 0.5.0 after their Intel validation passed.
Integrate PRs #25–30 in order after green CI. Additional unreported coverage remains unverified;
it does not revoke the explicit release instruction. Never infer native Intel acceptance from
an Apple Silicon/translated process. The collector itself never publishes a release.
