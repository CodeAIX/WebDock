#!/bin/bash
# Read-only package/host evidence. Never launches WebDock or reads its library/accounts.
set -euo pipefail
usage() {
    echo "Usage: $0 --app /path/WebDock.app --output-dir /path/new-report-directory" >&2
    exit 2
}
APP_PATH=""
REPORT_DIR=""
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || usage
    case "$1" in
        --app) APP_PATH="$2" ;;
        --output-dir) REPORT_DIR="$2" ;;
        *) usage ;;
    esac
    shift 2
done
[[ -n "$APP_PATH" && -n "$REPORT_DIR" ]] || usage
PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$PLIST" ]] || { echo "Application Info.plist not found." >&2; exit 2; }
[[ ! -e "$REPORT_DIR" ]] || { echo "Choose a new output directory to preserve prior evidence." >&2; exit 2; }
EXECUTABLE="$(/usr/bin/plutil -extract CFBundleExecutable raw "$PLIST")"
[[ -n "$EXECUTABLE" && "$EXECUTABLE" != */* ]] || { echo "Invalid executable name." >&2; exit 2; }
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$EXECUTABLE"
[[ -f "$EXECUTABLE_PATH" ]] || { echo "Application executable not found." >&2; exit 2; }
mkdir -p "$REPORT_DIR"
OS_VERSION="$(/usr/bin/sw_vers -productVersion)"
HARDWARE_ARM="$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)"
SHELL_ARCH="$(uname -m)"
TRANSLATED="$(/usr/sbin/sysctl -n sysctl.proc_translated 2>/dev/null || true)"
DEVICE_GATE="other-host; Intel Ventura acceptance remains pending"
if [[ "$HARDWARE_ARM" != 1 && "$TRANSLATED" != 1 && "$SHELL_ARCH" == x86_64 && "$OS_VERSION" == 13.6.9 ]]; then
    DEVICE_GATE="Intel macOS 13.6.9 target detected; interactive acceptance still pending"
elif [[ "$HARDWARE_ARM" == 1 ]]; then
    DEVICE_GATE="Apple Silicon host; cannot establish native Intel Ventura acceptance"
fi
{
    echo "Collected UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    /usr/bin/sw_vers
    echo "Hardware model: $(/usr/sbin/sysctl -n hw.model)"
    echo "Shell architecture: $SHELL_ARCH"
    echo "Process translated: ${TRANSLATED:-not reported}"
    echo "Hardware arm64 capability: ${HARDWARE_ARM:-not reported}"
    echo "Device gate: $DEVICE_GATE"
    echo "Bundle ID: $(/usr/bin/plutil -extract CFBundleIdentifier raw "$PLIST")"
    echo "Version: $(/usr/bin/plutil -extract CFBundleShortVersionString raw "$PLIST") ($(/usr/bin/plutil -extract CFBundleVersion raw "$PLIST"))"
    echo "Minimum macOS: $(/usr/bin/plutil -extract LSMinimumSystemVersion raw "$PLIST")"
    /usr/bin/file -b "$EXECUTABLE_PATH"
    /usr/bin/shasum -a 256 "$EXECUTABLE_PATH"
} > "$REPORT_DIR/ENVIRONMENT.txt"
SIGNATURE_RESULT=pass
if ! /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH" > "$REPORT_DIR/SIGNATURE.txt" 2>&1; then
    SIGNATURE_RESULT=fail
fi
/usr/bin/codesign -dv --verbose=2 "$APP_PATH" >> "$REPORT_DIR/SIGNATURE.txt" 2>&1 || true
cat > "$REPORT_DIR/CHECKLIST.md" <<'CHECKLIST'
# WebDock device acceptance

The collector only inspects this package and host. Nothing below is automatically passed.
Record actual results and screenshots; use a separate test library and disposable test websites.
Do not put account passwords, WebDAV passwords or browser profile contents in this report.

- [ ] Native launch and Dock reopen/toggle work; the globe/orbital-ribbon app icon displays correctly.
- [ ] Launcher / Library / all six Settings pages render; no duplicate mouse-selection frame.
- [ ] Create, edit, reorder and delete persist after a real app restart.
- [ ] Chinese / English / Follow System work; restart updates native menus; editor draft survives.
- [ ] Keyboard search / Return / arrows / Escape and VoiceOver labels work.
- [ ] Global shortcut summons Launcher from another foreground app; custom/disabled/reset state survives restart.
- [ ] App ICNS picker, runtime Dock/app-switcher override and reset survive restart without changing bundle signature.
- [ ] Manual icon selection / reset / offline rendering work in light and dark appearances.
- [ ] Account metadata permission is handled by macOS; selected account opens the correct real browser profile.
- [ ] Missing browser/account fallback works; this Mac's override stays local.
- [ ] Portable export / Replace / Merge restore work and create safety snapshots.
- [ ] Two real Macs: same account email resolves to different local Profile N values correctly.
- [ ] Synced Folder transfers create / edit / order / delete / custom icon to the other real Mac.
- [ ] Real WebDAV: read AND write, conflict handling, offline restart and recovery work.

## Result

Tester / date:
Device gate (copy from ENVIRONMENT.txt):
App version/build:
Passed items and evidence:
Failed or untested items:
Second Mac / transport used (no credentials):
CHECKLIST
echo "Signature check: $SIGNATURE_RESULT" >> "$REPORT_DIR/ENVIRONMENT.txt"
echo "$DEVICE_GATE"
echo "Signature check: $SIGNATURE_RESULT"
echo "Evidence written to $REPORT_DIR; interactive checks remain unverified."
[[ "$SIGNATURE_RESULT" == pass ]]
