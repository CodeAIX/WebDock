# Device validation

Use a fresh test library and public websites. Create a backup before any restore/sync experiment.
Do not test Replace Restore on an unprotected daily library or include credentials in reports.

## Collect package and host facts

Run with built-in macOS tools:

```sh
bash scripts/collect_device_acceptance.sh \
  --app /path/to/WebDock.app \
  --output-dir /path/to/new-report-directory
```

The collector does not launch WebDock, change system settings or read its library/browser accounts.
It records OS/build, hardware model, architecture, app version/minimum OS, executable hash and
signature. Output must be a new directory. CHECKLIST.md starts unticked: record actual results
with screenshots or failure details. A package signature check does not validate runtime features.

## Interactive checks

Follow TEST_PLAN.md on native Intel macOS 13 and a current Apple Silicon Mac. Cover Launcher,
Library, Settings, global shortcut, language/appearance, custom app/website icons, draft handling,
real restart, actual permission prompts and exact browser/account routing.

For synchronization, use two real Macs and the intended folder/WebDAV service. The same account
email must resolve independently even when its local Profile N differs. Exercise create, edit,
order, deletion, website icons, offline behavior and restore. A successful connection check or
loopback test does not establish production read/write, TLS or two-device acceptance.

Developers can prepare an isolated Debug application using scripts/prepare_ui_validation.py.
It uses a separate library/domain, disables sync/automatic backup/onboarding and defaults its
hotkey to off. Close other diagnostic copies before starting another one.
