#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "XcodeGen is required. Install Homebrew first or install XcodeGen manually." >&2
    exit 1
  fi
  echo "Installing XcodeGen..."
  brew install xcodegen
fi

echo "Generating WebDock.xcodeproj..."
xcodegen generate

echo "Validating scheme..."
xcodebuild -project WebDock.xcodeproj -scheme WebDock -list

echo
echo "Done. Open WebDock.xcodeproj in Xcode, or run:"
echo "  xcodebuild -project WebDock.xcodeproj -scheme WebDock -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test"
