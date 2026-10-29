#!/usr/bin/env python3
"""Validate WebDock's LaunchServices contract for shortcut file drops."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path

DEFAULT_PLIST = Path(__file__).resolve().parents[1] / "Config" / "Info.plist"

EXPECTED = {
    "crwebloc": "org.chromium.shortcut",
    "webloc": "com.apple.web-internet-location",
    "url": "com.microsoft.internet-shortcut",
}


def fail(message: str) -> None:
    print(f"LaunchServices validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    plist_path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_PLIST
    if not plist_path.is_file():
        fail(f"Info.plist not found: {plist_path}")

    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)

    document_types = plist.get("CFBundleDocumentTypes")
    if not isinstance(document_types, list):
        fail(f"CFBundleDocumentTypes is missing in {plist_path}")

    found: dict[str, dict] = {}
    for declaration in document_types:
        if not isinstance(declaration, dict):
            continue
        extensions = declaration.get("CFBundleTypeExtensions", [])
        for extension in extensions:
            if isinstance(extension, str):
                found[extension.lower()] = declaration

    for extension, expected_uti in EXPECTED.items():
        declaration = found.get(extension)
        if declaration is None:
            fail(f"missing .{extension} document declaration")

        content_types = declaration.get("LSItemContentTypes", [])
        if expected_uti not in content_types:
            fail(f".{extension} must include LSItemContentTypes={expected_uti}")
        if declaration.get("CFBundleTypeRole") != "Viewer":
            fail(f".{extension} must use CFBundleTypeRole=Viewer")
        if declaration.get("LSHandlerRank") != "Alternate":
            fail(f".{extension} must use LSHandlerRank=Alternate")

    for url_type in plist.get("CFBundleURLTypes", []):
        for scheme in url_type.get("CFBundleURLSchemes", []):
            if str(scheme).lower() in {"http", "https"}:
                fail("WebDock must not register as an http/https URL handler")

    exported = {
        declaration.get("UTTypeIdentifier")
        for declaration in plist.get("UTExportedTypeDeclarations", [])
        if isinstance(declaration, dict)
    }
    conflicts = set(EXPECTED.values()) & exported
    if conflicts:
        fail(f"must not export externally-owned UTIs: {sorted(conflicts)}")

    print(f"LaunchServices document declarations OK: {plist_path}")
    for extension, uti in EXPECTED.items():
        print(f"  .{extension} -> {uti} (Viewer, Alternate)")


if __name__ == "__main__":
    main()
