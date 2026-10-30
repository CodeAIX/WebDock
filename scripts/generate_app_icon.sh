#!/bin/bash
# Rebuild the standalone macOS icon from the transparent design master.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_WORK="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK"' EXIT
ICON_SET="$ICON_WORK/WebDock.iconset"
mkdir -p "$ICON_SET"
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        pixels=$((size * scale))
        suffix=""
        if [[ "$scale" == 2 ]]; then suffix="@2x"; fi
        sips -z "$pixels" "$pixels" \
            "$PROJECT_ROOT/Design/AppIcon/WebDock-AppIcon-master.png" \
            --out "$ICON_SET/icon_${size}x${size}${suffix}.png" >/dev/null
    done
done
iconutil -c icns "$ICON_SET" \
    -o "$PROJECT_ROOT/Design/AppIcon/WebDock.icns"
mkdir -p "$PROJECT_ROOT/Sources/WebDock/Resources/WebDock.icon/Assets"
sips -z 1024 1024 "$PROJECT_ROOT/Design/AppIcon/WebDock-AppIcon-master.png" \
    --out "$PROJECT_ROOT/Sources/WebDock/Resources/WebDock.icon/Assets/WebDock.png" >/dev/null
python3 "$PROJECT_ROOT/scripts/validate_app_icon.py"
