#!/usr/bin/env python3
"""Audit shipped font integrity, normal weight and complete current UI coverage (fonttools)."""
from pathlib import Path
import hashlib
import json
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]

def audit():
    folder = ROOT / 'top/fonts'
    manifest = json.loads((folder / 'manifest.json').read_text())
    coverage = set()
    faces = {}
    for key in ('primary', 'symbols'):
        item = manifest[key]
        path = folder / item['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], path
        face = TTFont(path)
        cmap = face.getBestCmap()
        assert len(cmap) == item['glyph_coverage'], path
        assert (folder / item['license_file']).is_file(), 'Missing font license'
        coverage.update(cmap)
        faces[key] = {'characters': len(cmap), 'weight': face['OS/2'].usWeightClass}
        if key == 'primary':
            assert 'fvar' not in face and face['OS/2'].usWeightClass == 400, 'Use static Regular, not Thin defaults'
            assert len(cmap) > 40000, 'Do not regress to a hand-maintained CJK subset'
    locations = {}
    for base in ('top/scripts', 'top/data'):
        for path in sorted((ROOT / base).rglob('*')):
            if path.suffix not in ('.gd', '.json'):
                continue
            for number, line in enumerate(path.read_text().splitlines(), 1):
                for char in set(line):
                    if ord(char) > 127 and char.isprintable() and not char.isspace():
                        locations.setdefault(char, []).append(f'{path.relative_to(ROOT)}:{number}')
    missing = {f'U+{ord(char):04X} {char}': paths for char, paths in locations.items() if ord(char) not in coverage}
    result = {'faces': faces, 'current_non_ascii_characters': len(locations), 'missing': missing}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    assert not missing, 'Missing shipped UI glyphs; see locations above'
    return result

if __name__ == '__main__':
    audit()
