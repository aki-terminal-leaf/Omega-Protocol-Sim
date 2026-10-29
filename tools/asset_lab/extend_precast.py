#!/usr/bin/env python3
"""Add exact ActionCastVFX resources to a NEW private inspection cache.
Ownership is checked. Begincast launch timing is provisional, NOT native proof.
No cast duration, host stop or C012 node is invented. Player pose stays OPEN.
Run full_replay/compile_resources.py on the preserved closure first.
"""
import argparse
import hashlib
import json
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text())


def checked_path(root, name):
    if not isinstance(name, str) or not name or '\\' in name or ':' in name:
        raise ValueError('Invalid source resource path')
    p = Path(name)
    if p.is_absolute() or '..' in p.parts:
        raise ValueError('Invalid source resource path')
    return root / p


def extend(data, closure, sheets, catalog, out):
    if out.exists():
        raise FileExistsError('Fresh private cache required')
    manifest = read(data / 'manifest.json')
    full = read(data / 'full-data.json')
    record = read(data / 'record.json')
    plan = read(data / 'motion-plan.json')
    metadata = read(sheets)
    source = read(closure / 'bundle/manifest.json')
    textures = read(closure / 'bundle/textures.json')['textures']
    packs = read(closure / 'packs.json')
    wanted = {action for unit in read(catalog)['units'] for action in unit['actions']}
    actions = {r['id']: r['fields'] for r in metadata['actions']}
    vfx = {r['id']: int(r['fields'][0]) for r in metadata['cast_vfx']}
    locations = {r['id']: r['fields'][0] for r in metadata['vfx']}
    starts = {r['id']: r['fields'] for r in metadata['cast_timeline']}
    if source['missing']:
        raise ValueError('Original closure is incomplete')
    paths = {}
    separate_start_vfx = []
    for ability in wanted & actions.keys():
        row = actions[ability]
        old = manifest.get('action_rows', {}).get(str(ability))
        if old and any(int(row[i]) != int(old[field]) for i, field in
                       [(5, 'start_cast_timeline'), (7, 'end'), (8, 'hit')]):
            raise ValueError('Action schema/source mismatch: ' + str(ability))
        if int(starts[int(row[5])][1]):
            separate_start_vfx.append({'ability': ability, 'vfx_id': int(starts[int(row[5])][1]),
                                       'status': 'SEPARATE_ANIMATION_START_VFX_NOT_IMPLEMENTED'})
        location = locations[vfx[int(row[6])]]
        paths[ability] = 'vfx/common/eff/' + location + '.avfx' if location else ''
    proof = {'schema': 1, 'status': 'PROVISIONAL_PRECAST_INSPECTION_NOT_ACCEPTANCE',
             'all96_accepted': False, 'timing_status': 'UNVERIFIED_HOST_SEMANTICS',
             'host_stop_status': 'UNKNOWN', 'cues': [], 'not_rendered': [],
             'separate_start_vfx_open': separate_start_vfx,
             'source_pins': {str(p): sha(p.read_bytes()) for p in
                             [sheets, catalog, closure / 'bundle/manifest.json',
                              closure / 'packs.json', closure / 'bundle/textures.json']}}
    needed = set()
    keys = {c['key'] for c in full['cues']}
    for index, event in enumerate(record['events']):
        if event['type'] != 'begincast' or event.get('a') not in wanted:
            continue
        ability = event['a']
        if ability not in paths:
            raise ValueError('Missing original Action row: ' + str(ability))
        path = paths[ability]
        if not path:
            proof['not_rendered'].append({'event_index': index, 'reason': 'ZERO_CAST_VFX_REFERENCE'})
            continue
        actor = str(event['s'])
        identity = record['actors'].get(actor, {})
        if identity.get('player') or identity.get('friendly') or actor not in plan['actors']:
            proof['not_rendered'].append({'event_index': index, 'path': path,
                                          'reason': 'ORIGINAL_PLAYER_POSE_OR_ACTOR_DEPENDENCY_OPEN'})
            continue
        if path not in source['resources'] or path not in packs:
            raise ValueError('Missing exact original cast resource: ' + path)
        raw = checked_path(closure / 'bundle/raw', path).read_bytes()
        digest = sha(raw)
        if digest != source['resources'][path]['sha256'] or digest != packs[path]['source_sha256']:
            raise ValueError('Original cast resource hash mismatch: ' + path)
        key = 'prepare/' + str(index) + '/' + actor + '/' + str(ability)
        if key in keys:
            raise ValueError('Duplicate original event identity: ' + key)
        keys.add(key)
        row = actions[ability]
        provenance = {'action_id': ability, 'action_cast_vfx_id': int(row[6]),
                      'vfx_id': vfx[int(row[6])], 'original_avfx_sha256': digest,
                      'timing_status': 'UNVERIFIED_HOST_SEMANTICS', 'host_stop_status': 'UNKNOWN',
                      'cast_successful': event.get('castSuccessful'),
                      'root_mode': 'static_at_begincast_unverified',
                      'start_basis': 'recorded begincast; native launch offset unverified'}
        cue = {'key': key, 'start': event['t'], 'anchor': event['t'],
               'source': actor, 'target': str(event.get('d') or actor), 'ability': ability,
               'phase': event['phase'], 'kind': 'cast_prepare', 'path': path,
               'event_index': index, 'source_pos': event.get('source_pos'),
               'prepare_provenance': provenance,
               'lifecycle_basis': 'UNKNOWN; no release/kill synthesized from cast duration'}
        full['cues'].append(cue)
        proof['cues'].append(cue)
        needed.add(path)
    if not needed:
        raise ValueError('Empty original preparation selection is INVALID')
    texture_rows = {r['source']: r for r in textures}
    needed_textures = {t for path in needed for t in packs[path]['textures']}
    for texture in needed_textures:
        row = texture_rows[texture]
        if sha(checked_path(closure / 'bundle', row['file']).read_bytes()) != row['sha256']:
            raise ValueError('Original texture hash mismatch: ' + texture)
    # Validate first, then create a fresh cache; the accepted input is never edited.
    out.mkdir(parents=True)
    (out / 'assets').mkdir()
    for p in (data / 'assets').iterdir():
        (out / 'assets' / p.name).symlink_to(p.resolve())
    for p in data.iterdir():
        if p.name not in ['assets', 'manifest.json', 'full-data.json'] and p.is_file():
            (out / p.name).symlink_to(p.resolve())
    def add(name, payload, kind):
        relative = 'assets/' + name
        (out / relative).write_bytes(payload)
        key = 'prepare_' + name.rsplit('.', 1)[0]
        if key in manifest['native_assets']:
            raise ValueError('Duplicate prepared asset identity')
        manifest['native_assets'][key] = {'file': relative, 'kind': kind,
                                         'sha256': sha(payload), 'bytes': len(payload)}
        return key
    for texture in sorted(needed_textures):
        row = texture_rows[texture]
        key = add('precast_' + sha(texture.encode())[:24] + '.png',
                  checked_path(closure / 'bundle', row['file']).read_bytes(), 'png')
        full['textures'][texture] = key
    for path in sorted(needed):
        key = add('precast_' + sha(path.encode())[:24] + '.json',
                  json.dumps(packs[path], separators=(',', ':'), allow_nan=False).encode(), 'json')
        full['packs'][path] = key
    full['cues'].sort(key=lambda c: (c['start'], c['key']))
    full['precast_inspection'] = {k: v for k, v in proof.items() if k not in ['cues', 'not_rendered']}
    for name, doc in [('manifest.json', manifest), ('full-data.json', full), ('precast-proof.json', proof)]:
        (out / name).write_text(json.dumps(doc, ensure_ascii=False, indent=2, allow_nan=False) + '\n')
    return proof


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ['data', 'closure', 'sheets', 'catalog', 'out']:
        ap.add_argument('--' + name, type=Path, required=True)
    a = ap.parse_args()
    result = extend(a.data.resolve(), a.closure.resolve(), a.sheets.resolve(),
                    a.catalog.resolve(), a.out.resolve())
    print(json.dumps({'provisional_cues': len(result['cues']),
                      'not_rendered': len(result['not_rendered']), 'all96_accepted': False}))
