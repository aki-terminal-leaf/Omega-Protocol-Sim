#!/usr/bin/env python3
"""Close Action -> ActionCastTimeline -> VFX sources, never launch a cue.

All source validation precedes output creation. Original texture bytes must be
present at bundle/raw/{source}; a raw_sha256 declaration alone is not evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path, PureWindowsPath
import re
import shutil


def sha(payload):
    return hashlib.sha256(payload).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def encode(document):
    return (json.dumps(document, ensure_ascii=False, indent=2,
                       allow_nan=False) + '\n').encode('utf-8')


def checked_path(root, name):
    """Reject Windows aliases, traversal and links escaping the source root."""
    if not isinstance(name, str) or not name or '\\' in name:
        raise ValueError('Invalid source resource path: ' + repr(name))
    parts = name.split('/')
    if any(not p or p in ('.', '..') or p.endswith((' ', '.')) or
           re.search(r'[<>:"|?*\x00-\x1f]', p) or
           PureWindowsPath(p).is_reserved() for p in parts):
        raise ValueError('Unsafe source resource path: ' + name)
    root = root.resolve()
    result = root.joinpath(*parts)
    if not result.resolve().is_relative_to(root):
        raise ValueError('Source path escapes root: ' + name)
    return result


def verified(path, expected):
    if not isinstance(expected, str) or not re.fullmatch('[0-9a-f]{64}', expected):
        raise ValueError('Invalid SHA256 for ' + str(path))
    payload = path.read_bytes()
    if sha(payload) != expected:
        raise ValueError('SHA256 mismatch: ' + str(path))
    return payload


def rows(metadata, key):
    result = {}
    for row in metadata[key]:
        ident = int(row['id'])
        if ident in result:
            raise ValueError('Duplicate ' + key + ' row: ' + str(ident))
        result[ident] = row['fields']
    return result


def require(mapping, key, kind):
    if key not in mapping:
        raise ValueError('Missing exact ' + kind + ': ' + str(key))
    return mapping[key]


def extend(data: Path, closure: Path, sheets: Path, catalog: Path, out: Path):
    data, closure, sheets, catalog, out = (
        p.resolve() for p in (data, closure, sheets, catalog, out))
    if out.exists():
        raise FileExistsError('Fresh private cache required')
    if any(out.is_relative_to(p) or p.is_relative_to(out)
           for p in (data, closure, sheets, catalog)):
        raise ValueError('Output overlaps immutable inputs')
    manifest = read(data / 'manifest.json')
    full = read(data / 'full-data.json')
    record = read(data / 'record.json')
    metadata = read(sheets)
    source = read(closure / 'bundle/manifest.json')
    packs = read(closure / 'packs.json')
    textures = read(closure / 'bundle/textures.json')['textures']
    if source['missing']:
        raise ValueError('Original closure is incomplete')
    wanted = {int(a) for unit in read(catalog)['units'] for a in unit['actions']}
    actions, starts, locations = (rows(metadata, k) for k in
                                  ('actions', 'cast_timeline', 'vfx'))
    pins = [sheets, catalog, closure / 'bundle/manifest.json',
            closure / 'packs.json', closure / 'bundle/textures.json']
    pins += [data / name for name in ('manifest.json', 'full-data.json',
                                     'record.json', 'motion-plan.json')]
    proof = {'schema': 1, 'status': 'SOURCE_CLOSURE_ONLY',
             'all96_accepted': False, 'rendering_complete': False,
             'dependencies': [], 'zero_start_vfx_references': [],
             'source_pins': {str(p): sha(p.read_bytes()) for p in pins}}
    needed = set()
    for index, event in enumerate(record['events']):
        if event['type'] != 'begincast' or event.get('a') not in wanted:
            continue
        action = event['a']
        row = require(actions, action, 'Action row')
        old = manifest.get('action_rows', {}).get(str(action))
        if old and any(int(row[i]) != int(old[field]) for i, field in
                       ((5, 'start_cast_timeline'), (7, 'end'), (8, 'hit'))):
            raise ValueError('Action schema/source mismatch: ' + str(action))
        cast_id = int(row[5])
        start = require(starts, cast_id, 'ActionCastTimeline row')
        vfx_id = int(start[1])
        actor = str(event['s'])
        identity = require(record['actors'], actor, 'original event actor')
        if 'id' in identity and str(identity['id']) != actor:
            raise ValueError('Original actor identity mismatch: ' + actor)
        ownership = {'event_index': index, 'action_id': action, 'source': actor,
                     'action_cast_timeline_id': cast_id, 'vfx_id': vfx_id}
        if vfx_id == 0:
            proof['zero_start_vfx_references'].append(ownership)
            continue
        location = require(locations, vfx_id, 'VFX row')[0]
        if not isinstance(location, str) or not location:
            raise ValueError('Nonzero VFX reference has no original location')
        path = 'vfx/common/eff/' + location + '.avfx'
        checked_path(closure / 'bundle/raw', path)
        proof['dependencies'].append({**ownership, 'path': path,
            'original_start_timeline_id': int(start[0]),
            'original_actor': identity, 'original_event_ref': event.get('ref'),
            'timing_status': 'UNKNOWN', 'host_stop_status': 'UNKNOWN',
            'pose_status': 'UNKNOWN'})
        needed.add(path)

    # Prepare all payloads before creating output, including path/hash checks.
    additions = {}
    def add(name, payload, kind, **provenance):
        key = 'animation_start_' + name
        relative = 'assets/' + key
        if key in manifest['native_assets'] or (data / relative).exists():
            raise ValueError('Duplicate animation-start asset identity: ' + key)
        additions[relative] = payload
        manifest['native_assets'][key] = {
            'file': relative, 'kind': kind, 'sha256': sha(payload),
            'bytes': len(payload), **provenance}
        return key

    texture_rows = {}
    for row in textures:
        checked_path(closure / 'bundle', row['file'])
        checked_path(closure / 'bundle/raw', row['source'])
        if row['source'] in texture_rows:
            raise ValueError('Duplicate texture source: ' + row['source'])
        texture_rows[row['source']] = row
    needed_textures = set()
    for path in sorted(needed):
        resource = require(source['resources'], path, 'original AVFX')
        pack = require(packs, path, 'compiled AVFX pack')
        raw = verified(checked_path(closure / 'bundle/raw', path), resource['sha256'])
        if sha(raw) != pack['source_sha256']:
            raise ValueError('Compiled AVFX source SHA256 mismatch: ' + path)
        for dep in proof['dependencies']:
            if dep['path'] == path:
                dep['original_avfx_sha256'] = sha(raw)
        token = sha(path.encode('utf-8'))
        raw_key = add(token + '.avfx', raw, 'avfx', source=path)
        full['packs'][path] = add(token + '.json', encode(pack), 'json',
            source=path, original_sha256=sha(raw), original_asset=raw_key,
            compiled_container_sha256=proof['source_pins'][str(closure / 'packs.json')])
        needed_textures.update(pack['textures'])
    for texture in sorted(needed_textures):
        row = require(texture_rows, texture, 'original texture')
        png = verified(checked_path(closure / 'bundle', row['file']), row['sha256'])
        original = verified(checked_path(closure / 'bundle/raw', texture), row['raw_sha256'])
        token = sha(texture.encode('utf-8'))
        raw_key = add(token + '.atex', original, 'atex', source=texture)
        full['textures'][texture] = add(token + '.png', png, 'png', source=texture,
            original_sha256=sha(original), original_asset=raw_key)
    full['animation_start_dependencies'] = proof['dependencies']
    # Check every inherited path before copying. Copies avoid symlink privileges
    # and writable aliases to the accepted cache on Windows.
    inherited = []
    for p in data.rglob('*'):
        relative = p.relative_to(data).as_posix()
        checked_path(data, relative)
        if p.is_symlink() or p.is_junction():
            raise ValueError('Linked cache input is not portable: ' + relative)
        if p.is_file():
            inherited.append((p, relative))
    for row in manifest['native_assets'].values():
        checked_path(out, row['file'])
    documents = {'manifest.json': encode(manifest), 'full-data.json': encode(full),
                 'animation-start-proof.json': encode(proof)}
    out.mkdir(parents=True)
    for p, relative in inherited:
        if relative in documents:
            continue
        target = out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, target)
    for relative, payload in {**additions, **documents}.items():
        target = out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        if sha(target.read_bytes()) != sha(payload):
            raise ValueError('Output verification failed: ' + relative)
    return proof


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('data', 'closure', 'sheets', 'catalog', 'out'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    result = extend(args.data, args.closure, args.sheets, args.catalog, args.out)
    print(json.dumps(result, ensure_ascii=False, allow_nan=False))
