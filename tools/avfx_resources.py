#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read-only, bounded AVFX resource acquisition using the existing Lumina reader.

Only source-defined AVFX Tex records are dependency edges. EID/PAP/SHPK roots
must be supplied explicitly; this is not an assertion of complete runtime data.
"""
from __future__ import annotations
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
try:
    from . import avfx_meshes as mesh
except ImportError:
    import avfx_meshes as mesh

MAX_FILES = 4096
MAX_TOTAL_BYTES = 256 * 1024 * 1024
EXTENSIONS = {'.avfx', '.atex', '.tex', '.eid', '.sklb', '.pap', '.tmb', '.shpk'}

class ResourceTooLarge(ValueError):
    def __init__(self, path, size):
        self.path, self.size = path, size
        super().__init__('Resource byte budget exceeded: %s (%d)' % (path, size))

def virtual_path(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-z0-9_./-]+', value):
        raise ValueError('Invalid virtual resource path')
    path = PurePosixPath(value)
    if (path.is_absolute() or str(path) != value or '..' in path.parts
            or path.parts[0] not in {'vfx', 'chara', 'shader'}
            or path.suffix not in EXTENSIONS):
        raise ValueError('Unsafe or unsupported virtual resource path')
    return value

def texture_references(data):
    roots = mesh.blocks(data)
    if len(roots) != 1 or roots[0][0] != 'AVFX':
        raise ValueError('Expected exactly one AVFX root')
    rows = mesh.blocks(roots[0][1])
    if mesh.integer(rows, 'Ver') != mesh.VERSION:
        raise ValueError('Unsupported AVFX version')
    values = [v for tag, v in rows if tag == 'Tex']
    if mesh.integer(rows, 'TxCn') != len(values):
        raise ValueError('AVFX texture count mismatch')
    result = []
    for value in values:
        if not value.endswith(b'\0') or b'\0' in value[:-1]:
            raise ValueError('Invalid AVFX texture string')
        path = virtual_path(value[:-1].decode('ascii'))
        if PurePosixPath(path).suffix not in {'.tex', '.atex'}:
            raise ValueError('Non-texture in AVFX Tex record')
        result.append(path)
    return result

def collect(roots, read, output, decode_texture=None, *, version='unknown',
            max_files=MAX_FILES, max_bytes=MAX_TOTAL_BYTES, max_resource_bytes=mesh.MAX_BYTES):
    """Injectable raw-read/PNG callbacks; never mutate an installed game."""
    if not 1 <= max_resource_bytes <= 64 * 1024 * 1024:
        raise ValueError("Invalid resource size limit")
    # Validate the ENTIRE request before creating output or reading anything.
    pending = deque((virtual_path(row['path']), bool(row.get('required', True)), None)
                    for row in roots)
    if not pending or len(pending) > max_files:
        raise ValueError('Invalid resource root count')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    manifest = {'schema': 1, 'game_version': version,
                'dependency_scope': 'AVFX Tex records only; other roots explicit',
                'rendering_complete': False, 'resources': [], 'edges': [],
                'missing_required': [], 'missing_candidates': [], 'rejected_candidates': [], 'total_bytes': 0}
    visited = {}
    def save():
        temp = output / 'manifest.tmp'
        temp.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        temp.replace(output / 'manifest.json')
    try:
        while pending:
            path, required, owner = pending.popleft()
            if owner is not None:
                manifest['edges'].append({'owner': owner, 'target': path, 'kind': 'AVFX/Tex'})
            if path in visited:
                if required and visited[path] is None and path not in manifest['missing_required']:
                    manifest['missing_required'].append(path)
                    if path in manifest['missing_candidates']: manifest['missing_candidates'].remove(path)
                continue
            if len(visited) >= max_files:
                raise ValueError('Resource count budget exceeded')
            try:
                data = read(path)
            except ResourceTooLarge as error:
                if required: raise
                visited[path] = None
                manifest['rejected_candidates'].append({'path': path, 'reason': 'asset_byte_budget', 'bytes': error.size})
                continue
            if data is None:
                visited[path] = None
                manifest['missing_required' if required else 'missing_candidates'].append(path)
                continue
            if not isinstance(data, bytes) or len(data) > max_resource_bytes:
                if not required and isinstance(data, bytes):
                    visited[path] = None
                    manifest['rejected_candidates'].append({'path': path, 'reason': 'asset_byte_budget', 'bytes': len(data)})
                    continue
                raise ValueError('Resource byte budget exceeded: ' + path)
            if manifest['total_bytes'] + len(data) > max_bytes:
                raise ValueError('Total resource byte budget exceeded: ' + path)
            target = output / 'source' / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            entry = {'path': path, 'file': 'source/' + path, 'bytes': len(data),
                     'sha256': hashlib.sha256(data).hexdigest()}
            visited[path] = entry
            manifest['resources'].append(entry)
            manifest['total_bytes'] += len(data)
            suffix = PurePosixPath(path).suffix
            if suffix == '.avfx':
                refs = texture_references(data)
                entry['texture_refs'] = refs
                pending.extend((ref, True, path) for ref in refs)
            elif suffix in {'.tex', '.atex'} and decode_texture is not None:
                png, width, height = decode_texture(path)
                if not 1 <= width <= 4096 or not 1 <= height <= 4096 or len(png) > mesh.MAX_BYTES:
                    raise ValueError('Decoded texture budget exceeded')
                if manifest['total_bytes'] + len(png) > max_bytes:
                    raise ValueError('Total decoded resource byte budget exceeded')
                relative = 'png/' + path + '.png'
                target = output / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(png)
                entry.update(png=relative, png_sha256=hashlib.sha256(png).hexdigest(),
                             width=width, height=height)
                manifest['total_bytes'] += len(png)
            save()
        manifest['collection_complete'] = not manifest['missing_required']
        return manifest
    except Exception as error:
        manifest['collection_complete'] = False
        manifest['error'] = str(error)
        raise
    finally:
        save()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game-dir', 'lumina-dir', 'textools-dir', 'output', 'request']:
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--pythonnet-dir', type=Path)
    parser.add_argument('--max-resource-bytes', type=int, default=mesh.MAX_BYTES)
    args = parser.parse_args()
    request = json.loads(args.request.read_text(encoding='utf-8'))
    # initialize writes a runtime-config in a separate temporary sibling, never
    # in the bundle, so collection refuses accidental previous-output overwrite.
    import tempfile
    from types import SimpleNamespace
    import export_official_models as models
    import io
    with tempfile.TemporaryDirectory(prefix='avfx-lumina-') as temp:
        init = SimpleNamespace(**vars(args)); init.output = Path(temp)
        realm = models.initialize(init)
        try:
            from Lumina.Data import FileResource
            from Lumina.Data.Files import TexFile
            from PIL import Image
            def read(path):
                metadata = realm.GetFileMetadata(path)
                if metadata is None: return None
                if int(metadata.RawFileSize) > args.max_resource_bytes:
                    raise ResourceTooLarge(path, int(metadata.RawFileSize))
                resource = realm.GetFile[FileResource](path)
                return None if resource is None else bytes(resource.Data)
            def decode(path):
                texture = realm.GetFile[TexFile](path)
                w, h = int(texture.Header.Width), int(texture.Header.Height)
                if not 1 <= w <= 4096 or not 1 <= h <= 4096:
                    raise ValueError('Decoded texture dimensions exceeded')
                image = Image.frombytes('RGBA', (w, h), bytes(texture.ImageData), 'raw', 'BGRA')
                with io.BytesIO() as buffer:
                    image.save(buffer, format='PNG'); png = buffer.getvalue()
                image.close()
                return png, w, h
            result = collect(request['roots'], read, args.output, decode,
                             version=(args.game_dir / 'game/ffxivgame.ver').read_text().strip(),
                             max_resource_bytes=args.max_resource_bytes)
        finally:
            realm.Dispose()
    print(json.dumps({'resources': len(result['resources']), 'bytes': result['total_bytes'],
                      'missing_required': result['missing_required'],
                      'missing_candidates': result['missing_candidates'],
                      'rejected_candidates': result['rejected_candidates'],
                      'collection_complete': result['collection_complete']}))
    return 0 if result['collection_complete'] else 1
if __name__ == '__main__':
    raise SystemExit(main())
