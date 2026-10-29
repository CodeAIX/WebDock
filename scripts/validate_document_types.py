#!/usr/bin/env python3
"""Validate WebDock's manual-first LaunchServices contract."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path

DEFAULT_PLIST = Path(__file__).resolve().parents[1] / "Config" / "Info.plist"
DISALLOWED_SHORTCUT_EXTENSIONS = {"crwebloc", "webloc", "url"}


def fail(message: str) -> None:
    print(f"LaunchServices validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    plist_path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_PLIST
    if not plist_path.is_file():
        fail(f"Info.plist not found: {plist_path}")

    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)

    for declaration in plist.get("CFBundleDocumentTypes", []):
        if not isinstance(declaration, dict):
            continue
        extensions = {
            str(value).lower()
            for value in declaration.get("CFBundleTypeExtensions", [])
        }
        conflicts = extensions & DISALLOWED_SHORTCUT_EXTENSIONS
        if conflicts:
            fail(f"manual-first WebDock must not register shortcut-file imports: {sorted(conflicts)}")

    for url_type in plist.get("CFBundleURLTypes", []):
        for scheme in url_type.get("CFBundleURLSchemes", []):
            if str(scheme).lower() in {"http", "https"}:
                fail("WebDock must not register as an http/https URL handler")

    print(f"Manual-first LaunchServices contract OK: {plist_path}")
    print("  no .crwebloc/.webloc/.url document handlers")
    print("  no http/https URL handler")


if __name__ == "__main__":
    main()
