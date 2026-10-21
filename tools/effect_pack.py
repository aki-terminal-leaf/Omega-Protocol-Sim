# SPDX-License-Identifier: MIT
#!/usr/bin/env python3
"""Validate schema-1 effect inventories or migrate legacy paths (stdlib only).

Validation proves stored AVFX/PNG integrity, not rendering fidelity. Raw texture
hashes are retained metadata: original TEX/ATEX bytes are not in these packs.
PNG checks cover hashes, chunk framing/CRCs and IHDR, not decoded pixel content;
AVFX checks cover hashes, not graph semantics.
Migration copies only referenced assets and the manifest to a new directory;
it never deletes or changes the input. Ambiguous legacy locations are rejected.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import struct
import zlib


class PackError(ValueError):
    """Invalid or unsafe effect inventory."""


def canonical_path(value, *, legacy=False):
    """Return a portable relative path; never silently repair unsafe paths."""
    if not isinstance(value, str) or not value:
        raise PackError('Expected a nonempty relative path')
    if '\\' in value and not legacy:
        raise PackError('Backslash path requires explicit migration: ' + value)
    value = value.replace('\\', '/') if legacy else value
    parts = value.split('/')
    for part in parts:
        if (part in ('', '.', '..') or part.endswith((' ', '.'))
                or re.search(r'[<>:"|?*\x00-\x1f\x7f]', part)
                or re.fullmatch(r'(?i:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\..*)?', part)):
            raise PackError('Unsafe or nonportable path: ' + value)
    return '/'.join(parts)


def texture_output_path(form, source):
    """Keep hierarchy AND source extension so TEX and ATEX cannot collide."""
    form = canonical_path(form)
    if '/' in form:
        raise PackError('Effect form must be one directory name')
    return f'{form}/textures/{canonical_path(source)}.png'


def _inside(root, path):
    try:
        path.resolve().relative_to(root)
        relative = path.relative_to(root)
    except ValueError as exc:
        raise PackError('Path escapes pack root') from exc
    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        if cursor.is_symlink() or (hasattr(cursor, 'is_junction') and cursor.is_junction()):
            raise PackError('Symlinks/junctions are unsupported: ' + str(relative))
    return path


def _locate(root, original, canonical, legacy):
    candidates = [root.joinpath(*canonical.split('/'))]
    if legacy:
        # On POSIX a synced Windows path can be a literal filename. On Windows
        # these candidates collapse to the same nested filesystem path.
        candidates += [root / original, root / canonical.replace('/', '\\')]
    found = []
    for candidate in dict.fromkeys(candidates):
        _inside(root, candidate)
        if candidate.is_file():
            found.append(candidate)
    if len(found) != 1:
        raise PackError(('Missing' if not found else 'Ambiguous legacy') + ' asset: ' + canonical)
    return found[0]


def _digest(value):
    if not isinstance(value, str) or not re.fullmatch('[0-9a-fA-F]{64}', value):
        raise PackError('Invalid SHA256 metadata')
    return value.lower()


def png_dimensions(data):
    """Check PNG framing/CRCs and read IHDR without an image dependency."""
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise PackError('Invalid PNG signature')
    offset, dimensions, seen_data = 8, None, False
    while offset < len(data):
        if len(data) - offset < 12:
            raise PackError('Truncated PNG chunk')
        size = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + size
        if end > len(data):
            raise PackError('Truncated PNG payload')
        payload = data[offset + 8:end - 4]
        crc = struct.unpack_from('>I', data, end - 4)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise PackError('Invalid PNG CRC')
        if dimensions is None and kind != b'IHDR':
            raise PackError('PNG must start with IHDR')
        if kind == b'IHDR':
            if dimensions is not None or size != 13:
                raise PackError('Invalid PNG IHDR')
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            depths = {0: (1, 2, 4, 8, 16), 2: (8, 16), 3: (1, 2, 4, 8), 4: (8, 16), 6: (8, 16)}
            if (not 0 < width <= 0x7fffffff or not 0 < height <= 0x7fffffff
                    or depth not in depths.get(color, ()) or compression or filtering or interlace not in (0, 1)):
                raise PackError('Invalid PNG IHDR fields')
            dimensions = (width, height)
        if kind == b'IDAT':
            seen_data = True
        if kind == b'IEND':
            if size or end != len(data) or not seen_data:
                raise PackError('Invalid PNG end/data')
            return dimensions
        offset = end
    raise PackError('Missing PNG IEND')


def _inventory(root, legacy=False):
    root = Path(root).resolve(strict=True)
    manifest_path = _inside(root, root / 'effects-manifest.json')
    try:
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'), object_pairs_hook=_unique_object)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise PackError('Invalid manifest JSON') from exc
    if not isinstance(manifest, dict) or type(manifest.get('schema')) is not int or manifest['schema'] != 1:
        raise PackError('Only schema 1 is supported')
    if 'rendering_complete' in manifest and manifest['rendering_complete'] is not False:
        raise PackError('Inventory cannot claim rendering_complete')
    effects = manifest.get('effects')
    if not isinstance(effects, dict) or not effects:
        raise PackError('Expected nonempty effects object')
    normalized, assets, outputs = copy.deepcopy(manifest), [], set()

    def asset(original, digest, dimensions=None):
        canonical = canonical_path(original, legacy=legacy)
        key = canonical.casefold()
        if key in outputs:
            raise PackError('Duplicate output reference: ' + canonical)
        outputs.add(key)
        source = _locate(root, original, canonical, legacy)
        data = source.read_bytes()
        if hashlib.sha256(data).hexdigest() != _digest(digest):
            raise PackError('SHA256 mismatch: ' + canonical)
        if dimensions is not None and png_dimensions(data) != dimensions:
            raise PackError('PNG dimensions mismatch: ' + canonical)
        assets.append((canonical, data))
        return canonical

    forms = set()
    for form, entry in effects.items():
        if '/' in canonical_path(form) or form.casefold() in forms:
            raise PackError('Invalid/duplicate form directory')
        forms.add(form.casefold())
        if not isinstance(entry, dict) or entry.get('rendering_complete') is not False:
            raise PackError('Each effect must declare rendering_complete=false')
        canonical_path(entry.get('source_path'))
        avfx = entry.get('file', f'{form}/effect.avfx')
        canonical = asset(avfx, entry.get('sha256'))
        if 'file' in entry:
            normalized['effects'][form]['file'] = canonical
        textures = entry.get('textures')
        if not isinstance(textures, list):
            raise PackError('Expected textures list')
        for index, texture in enumerate(textures):
            if not isinstance(texture, dict):
                raise PackError('Expected texture object')
            canonical_path(texture.get('source'))
            _digest(texture.get('raw_sha256'))
            dims = (texture.get('width'), texture.get('height'))
            if any(type(n) is not int or n <= 0 for n in dims):
                raise PackError('Invalid PNG dimensions metadata')
            canonical = asset(texture.get('file'), texture.get('sha256'), dims)
            normalized['effects'][form]['textures'][index]['file'] = canonical
    # A file cannot also serve as a parent directory of another output.
    for name in outputs:
        parts = name.split('/')
        if any('/'.join(parts[:i]) in outputs for i in range(1, len(parts))):
            raise PackError('Output file/directory collision')
    return normalized, assets


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise PackError('Duplicate JSON key: ' + key)
        result[key] = value
    return result


def validate_pack(root):
    """Validate a canonical pack and return its unmodified manifest."""
    return _inventory(root)[0]


def migrate_pack(root, output):
    """Normalize recoverable legacy paths into an absent, disjoint directory."""
    root, output = Path(root).resolve(strict=True), Path(output).absolute()
    resolved = output.resolve()
    if output.exists() or output.is_symlink() or resolved == root or root in resolved.parents or resolved in root.parents:
        raise PackError('Output must be a new directory disjoint from the input')
    # Refuse symlinked output ancestors as well as source links.
    _inside(Path(output.anchor), output)
    manifest, assets = _inventory(root, legacy=True)
    output.mkdir(parents=True, exist_ok=False)
    for name, data in assets:
        target = output.joinpath(*name.split('/'))
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as stream:
            stream.write(data)
    (output / 'effects-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    validate_pack(output)
    return manifest


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    validate = commands.add_parser('validate', help='Check canonical schema-1 inventory')
    validate.add_argument('root', type=Path)
    migrate = commands.add_parser('migrate', help='Explicitly normalize legacy backslashes; never modify input')
    migrate.add_argument('root', type=Path)
    migrate.add_argument('--output', type=Path, required=True, help='New, different, disjoint directory')
    args = parser.parse_args(argv)
    try:
        manifest = validate_pack(args.root) if args.command == 'validate' else migrate_pack(args.root, args.output)
    except (PackError, OSError) as exc:
        parser.exit(1, f'Invalid effect pack: {exc}\n')
    print(f'Validated {len(manifest["effects"])} effects; rendering_complete=false (inventory only)')


if __name__ == '__main__':
    main()
