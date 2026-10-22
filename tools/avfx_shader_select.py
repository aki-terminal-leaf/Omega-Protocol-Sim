#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Bounded semantic scene-key selection over immutable shpk_inspect metadata.

This does not derive host state, invent defaults, choose shaders from AVFX flags,
execute bytecode or certify rendering. Every vector belongs to its own package.
"""
from collections import defaultdict
from functools import lru_cache
import json
from pathlib import Path

DATA = Path(__file__).with_name('data') / 'apricot_crc_names.json'
STAGES = ('vertex', 'pixel', 'hull', 'domain', 'geometry')
MAX_NODE_DETAILS = 64
MAX_DISTINCT_VALUES = 4096
_INDEX_CACHE = None

class ConstraintError(ValueError):
    pass

class ExactIndex(dict):
    """An explicit caller-owned index, bound to its immutable metadata object."""
    def __init__(self, owner):
        super().__init__()
        self.owner = owner
        self.schema = tuple(k['id'] for k in owner['keys']['scene'])

@lru_cache(maxsize=1)
def load_names(path=DATA):
    # The packaged, revision-pinned database is immutable. Never accumulate a
    # fresh database/cache on every per-particle selection call.
    with open(path, encoding='utf8') as source:
        return json.load(source)

def hx(value):
    return f'0x{value:08X}'

def indexes(db):
    global _INDEX_CACHE
    if _INDEX_CACHE is not None and _INDEX_CACHE[0] is db:
        return _INDEX_CACHE[1]
    if not isinstance(db.get('keys'), dict) or not isinstance(db.get('passes'), dict):
        raise ConstraintError('invalid semantic database')
    ids = {int(key, 16): value for key, value in db['keys'].items()}
    names = defaultdict(list)
    for value, name in ids.items():
        names[name].append(value)
    result = ids, names
    # One cache entry, not an unbounded id(db) -> strong-reference registry.
    _INDEX_CACHE = db, result
    return result

def package_identity(meta):
    return {'source_sha256': meta.get('source_sha256'),
            'format_version': meta.get('version'),
            'scene_key_ids': [key['id'] for key in meta['keys']['scene']]}

def semantic(value, db):
    ids, _ = indexes(db)
    return {'id': value, 'hex': hx(value), 'name': ids.get(value), 'known': value in ids}

def pass_ref(source, db):
    name = db['passes'].get(hx(source['id']))
    return {'id': source['id'], 'hex': hx(source['id']), 'name': name,
            'known': name is not None,
            'programs': {stage: source[stage] for stage in STAGES}}

def check_vectors(meta):
    count = len(meta['keys']['scene'])
    for node in meta['nodes']:
        if len(node['keys']['scene']) != count:
            raise ConstraintError(f"node {node['index']} scene vector length mismatch")

def describe_scene(meta, db=None, *, node_details=0):
    """Describe keys and observed values; detailed node expansion is opt-in/capped.

    A model package may have thousands of nodes. Repeating all 55+ labeled keys
    for every node can exceed the source file's memory many times over.
    """
    if not isinstance(node_details, int) or not 0 <= node_details <= MAX_NODE_DETAILS:
        raise ConstraintError('node detail budget must be 0..64')
    db = load_names() if db is None else db
    ids, _ = indexes(db)
    check_vectors(meta)
    declared = meta['keys']['scene']
    seen, duplicates, keys = {}, [], []
    for ordinal, key in enumerate(declared):
        if key['id'] in seen:
            duplicates.append({'id': hx(key['id']), 'ordinals': [seen[key['id']], ordinal]})
        else:
            seen[key['id']] = ordinal
        keys.append({'ordinal': ordinal, 'key': semantic(key['id'], db),
                     'default': semantic(key['default'], db)})
    aliases = defaultdict(list)
    for alias in meta.get('aliases', []):
        aliases[alias['node']].append(alias['selector'])
    observed = [set() for _ in keys]
    truncated_values = set()
    value_count = known_values = distinct_count = 0
    nodes = []
    for node in meta['nodes']:
        values = node['keys']['scene']
        for ordinal, value in enumerate(values):
            value_count += 1
            known_values += value in ids
            if value not in observed[ordinal]:
                if distinct_count < MAX_DISTINCT_VALUES:
                    observed[ordinal].add(value)
                    distinct_count += 1
                else:
                    truncated_values.add(ordinal)
        if len(nodes) < node_details:
            nodes.append({'index': node['index'], 'selector': hx(node['selector']),
                          'alias_selectors': [hx(x) for x in aliases[node['index']]],
                          'values': [{'ordinal': i, 'key': keys[i]['key'],
                                      'value': semantic(value, db)}
                                     for i, value in enumerate(values)],
                          'passes': [pass_ref(p, db) for p in node['passes']]})
    for ordinal, key in enumerate(keys):
        key['observed_values'] = [semantic(v, db) for v in sorted(observed[ordinal])]
        key['observed_values_truncated'] = ordinal in truncated_values
    known_keys = sum(k['key']['known'] for k in keys)
    return {'rendering_complete': False, 'package': package_identity(meta), 'scope': 'package-local scene keys only',
            'keys': keys, 'duplicate_key_ids': duplicates, 'nodes': nodes,
            'node_count': len(meta['nodes']),
            'node_details_truncated': len(nodes) < len(meta['nodes']),
            'semantic_coverage': {'key_count': len(keys), 'known_key_count': known_keys,
                                  'known_key_ratio': known_keys / len(keys) if keys else 1.0,
                                  'node_value_count': value_count,
                                  'known_node_value_count': known_values}}

def resolve_token(token, ids, names, role):
    if isinstance(token, int) and not isinstance(token, bool):
        if 0 <= token <= 0xffffffff:
            return token
        raise ConstraintError(f'{role} integer outside uint32')
    if isinstance(token, str) and token.lower().startswith('0x'):
        try:
            value = int(token, 16)
        except ValueError:
            raise ConstraintError(f'invalid {role} hex: {token}')
        if len(token) > 10 or not 0 <= value <= 0xffffffff:
            raise ConstraintError(f'{role} hex outside uint32: {token}')
        return value
    found = names.get(token, []) if isinstance(token, str) else []
    if not found:
        raise ConstraintError(f'unknown {role} semantic: {token!r}; use explicit hexadecimal IDs')
    if len(found) != 1:
        raise ConstraintError(f'ambiguous {role} semantic {token!r}')
    return found[0]

def resolve_constraints(meta, constraints, db=None):
    db = load_names() if db is None else db
    ids, names = indexes(db)
    positions = defaultdict(list)
    for ordinal, key in enumerate(meta['keys']['scene']):
        positions[key['id']].append(ordinal)
    if not isinstance(constraints, dict):
        raise ConstraintError('constraints must be a mapping')
    result = {}
    for key, value in constraints.items():
        key_id = resolve_token(key, ids, names, 'key')
        ordinals = positions.get(key_id, [])
        if not ordinals:
            raise ConstraintError(f'key {hx(key_id)} is not declared by this package')
        if len(ordinals) != 1:
            raise ConstraintError(f'key {hx(key_id)} has duplicate package ordinals')
        ordinal = ordinals[0]
        resolved = resolve_token(value, ids, names, 'value')
        if ordinal in result and result[ordinal] != resolved:
            raise ConstraintError(f'conflicting semantic/hex constraints for {hx(key_id)}')
        result[ordinal] = resolved
    return result

def build_exact_index(meta):
    """Build once per immutable package; duplicate vectors retain every node."""
    check_vectors(meta)
    result = ExactIndex(meta)
    for node in meta['nodes']:
        result.setdefault(tuple(node['keys']['scene']), []).append(node)
    return result

def select_nodes(meta, constraints=None, *, exact_vector=None, db=None, exact_index=None):
    db = load_names() if db is None else db
    try:
        if exact_vector is not None and constraints:
            raise ConstraintError('supply constraints or exact_vector, not both')
        if exact_index is not None:
            if (not isinstance(exact_index, ExactIndex) or exact_index.owner is not meta
                    or exact_index.schema != tuple(k['id'] for k in meta['keys']['scene'])):
                raise ConstraintError('exact index belongs to a different package/schema')
        count = len(meta['keys']['scene'])
        if exact_vector is not None:
            if not isinstance(exact_vector, (list, tuple)):
                raise ConstraintError("exact vector must be a list/tuple")
            if len(exact_vector) != count:
                raise ConstraintError(f'exact vector has {len(exact_vector)} values; expected {count}')
            ids, names = indexes(db)
            resolved = {i: resolve_token(v, ids, names, 'value') for i, v in enumerate(exact_vector)}
        else:
            if not constraints:
                raise ConstraintError('empty constraints do not select a node')
            resolved = resolve_constraints(meta, constraints, db)
        if len(resolved) == count:
            index = build_exact_index(meta) if exact_index is None else exact_index
            matches = index.get(tuple(resolved[i] for i in range(count)), [])
        else:
            check_vectors(meta)
            matches = [node for node in meta['nodes']
                       if all(node['keys']['scene'][i] == v for i, v in resolved.items())]
    except ConstraintError as error:
        return {'status': 'invalid', 'rendering_complete': False, 'package': package_identity(meta),
                'diagnostics': [str(error)], 'matches': []}
    diagnostics = []
    if len(matches) > 1:
        diagnostics.append('multiple nodes match; no arbitrary node was chosen')
    if not matches:
        diagnostics.append('no node has the requested scene-key values')
    return {'status': 'match' if len(matches) == 1 else 'ambiguous' if matches else 'no_match',
            'rendering_complete': False, 'package': package_identity(meta), 'scope': 'scene keys only; not full host state',
            'diagnostics': diagnostics,
            'resolved_constraints': [{'ordinal': i, 'value': semantic(v, db)}
                                     for i, v in sorted(resolved.items())],
            'matches': [{'index': n['index'], 'selector': hx(n['selector']),
                         'passes': [pass_ref(p, db) for p in n['passes']]} for n in matches]}

def main():
    import argparse
    import sys
    try:
        from .shpk_inspect import inspect, MAX
    except ImportError:
        from shpk_inspect import inspect, MAX
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='private source .shpk')
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--describe', action='store_true')
    mode.add_argument('--constraints', type=Path, help='JSON semantic/hex key-value mapping')
    mode.add_argument('--exact-vector', type=Path, help='JSON values in this package\'s own order')
    parser.add_argument('--node-details', type=int, default=0)
    parser.add_argument('--output', type=Path, help='exclusive report creation, never overwrite proof')
    args = parser.parse_args()
    try:
        with args.input.open('rb') as source:
            meta = inspect(source.read(MAX + 1))
        if args.describe:
            result = dict(describe_scene(meta, node_details=args.node_details), status='described')
        elif args.constraints is not None:
            result = select_nodes(meta, json.loads(args.constraints.read_text(encoding='utf8')))
        else:
            result = select_nodes(meta, exact_vector=json.loads(args.exact_vector.read_text(encoding='utf8')))
        if args.output is not None:
            with args.output.open('x', encoding='utf8') as report:
                json.dump(result, report, indent=2, ensure_ascii=True)
                report.write('\n')
            print(json.dumps({'status': result['status'], 'report': str(args.output),
                              'matches': len(result.get('matches', [])), 'rendering_complete': False}))
        else:
            print(json.dumps(result, sort_keys=True, ensure_ascii=True))
    except (ValueError, OSError) as error:
        print(json.dumps({'status': 'invalid', 'diagnostics': [str(error)],
                          'rendering_complete': False}), file=sys.stderr)
        return 2
    return {'match': 0, 'described': 0, 'invalid': 2, 'no_match': 3, 'ambiguous': 4}[result['status']]

if __name__ == '__main__':
    raise SystemExit(main())
