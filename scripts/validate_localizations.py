#!/usr/bin/env python3
"""Check owned UI translations and format placeholders without extra dependencies."""
from collections import Counter
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
resources = root / 'Sources/WebDock/Resources'
pattern = re.compile(r'("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*");')

def read_language(code):
    text = (resources / f'{code}.lproj/Localizable.strings').read_text()
    result = {}
    for match in pattern.finditer(text):
        key, value = (json.loads(group) for group in match.groups())
        assert key not in result, f'{code}: duplicate key {key}'
        assert value, f'{code}: empty value {key}'
        result[key] = value
    return result

en, zh = (read_language(code) for code in ['en', 'zh-Hans'])
assert en.keys() == zh.keys(), 'English and Chinese resource keys differ'
placeholders = re.compile(r'%(?:\d+\$)?(@|ld|d)')
for key in en:
    assert en[key] == key, f'English key/value mismatch: {key}'
    assert Counter(placeholders.findall(en[key])) == Counter(placeholders.findall(zh[key])), f'Placeholder mismatch: {key}'
for path in (root / 'Sources/WebDock').rglob('*.swift'):
    for key in re.findall(r'L10n\.tr\("((?:\\.|[^"\\])*)"', path.read_text()):
        key = json.loads('"' + key + '"')
        assert key in en, f'{path.name}: missing key {key}'
# This file describes a browser protocol, not UI strings.
assert 'L10n' not in (root / 'Sources/WebDock/Services/ChromiumProfileShortcutWriter.swift').read_text()
print(f'Localization contract OK: {len(en)} English/Chinese keys; placeholders and protocol keys preserved.')
