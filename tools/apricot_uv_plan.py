#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Hash-pinned paired VS/PS UV ABI, not game-host UV generation.

Inputs are explicit vertex INPUT semantics, not AVFX UvSN or mesh-channel guesses.
Only UV varyings and color sampler coordinates are evaluated; projection, color,
Fresnel, interpolation, input-layout packing and host curve matrices are excluded.
"""
from functools import lru_cache
import math
from pathlib import Path
import struct
try:
    from .apricot_color_plan import binding_signature
except ImportError:
    from apricot_color_plan import binding_signature
import json

DATA = Path(__file__).with_name('data') / 'apricot_verified_uv_programs.json'

class UvPlanError(ValueError):
    pass

@lru_cache(maxsize=1)
def load_verified(path=DATA):
    with open(path, encoding='utf8') as source:
        return json.load(source)

def _review(book, stage, digest, layout):
    matches = [p for p in book[stage] if p['bytecode_sha256'] == digest
               and p['bindings_sha256'] == layout]
    if len(matches) != 1:
        raise UvPlanError('bytecode/resource layout lacks a unique reviewed UV ABI')
    return matches[0]

def _pair(book, package, vertex, pixel):
    if not any(p['package_sha256'] == package and p['vertex_sha256'] == vertex
               and p['pixel_sha256'] == pixel for p in book['pairs']):
        raise UvPlanError('VS/PS pair not observed in original package passes')

def compile_uv_plan(meta, node_index, *, pass_index=None, verified=None):
    result = {'status': 'unsupported', 'rendering_complete': False,
              'scope': 'paired UV ABI only; explicit vertex INPUT semantics and consumed PS rows',
              'diagnostics': []}
    try:
        if type(node_index) is not int or node_index < 0:
            raise UvPlanError('node index must be a nonnegative integer')
        nodes = [n for n in meta['nodes'] if n['index'] == node_index]
        if len(nodes) != 1:
            raise UvPlanError('node is absent or duplicated')
        passes = nodes[0]['passes']
        if pass_index is None:
            if len(passes) != 1:
                raise UvPlanError('explicit pass index required')
            pass_index = 0
        if type(pass_index) is not int or not 0 <= pass_index < len(passes):
            raise UvPlanError('pass index outside node')
        if any(passes[pass_index].get(stage, 0xffffffff) != 0xffffffff
               for stage in ('hull', 'domain', 'geometry')):
            raise UvPlanError('unreviewed intervening shader stage')
        identities = {}
        book = load_verified() if verified is None else verified
        for stage, group in [('vertex', 'vertices'), ('pixel', 'pixels')]:
            index = passes[pass_index][stage]
            if type(index) is not int or not 0 <= index < len(meta['programs'][stage]):
                raise UvPlanError('missing executable ' + stage + ' program')
            program = meta['programs'][stage][index]
            if program['index'] != index:
                raise UvPlanError('program array/index disagreement')
            digest = program['bytecode']['sha256']
            layout = binding_signature(program['bindings'])
            _review(book, group, digest, layout)
            identities[stage] = {'sha256': digest, 'bindings_sha256': layout}
        package = meta['source_sha256']
        _pair(book, package, identities['vertex']['sha256'], identities['pixel']['sha256'])
        result.update(status='verified_uv_abi', package_sha256=package,
                      node_index=node_index, pass_index=pass_index, programs=identities)
    except (UvPlanError, KeyError, TypeError, IndexError) as error:
        result['diagnostics'].append(str(error))
    return result

def _f32(value):
    if type(value) not in (int, float):
        raise UvPlanError('finite explicit numeric input required')
    try:
        result = struct.unpack('<f', struct.pack('<f', value))[0]
    except (OverflowError, struct.error):
        raise UvPlanError('input exceeds finite float32 range')
    if not math.isfinite(result):
        raise UvPlanError('finite explicit numeric input required')
    return result

def sample_coordinates(plan, attributes, *, uv_transform_rows=None, verified=None):
    """CPU float32 reference, not bit-exact GPU dp3/interpolation equivalence.

    `uv_transform_rows` contains exactly the two consumed float4 rows, not a full
    constant buffer. Their .z components are ignored by original dp3(...,.xyw).
    No identity matrix or missing attribute is silently supplied.
    """
    if not isinstance(plan, dict) or plan.get('status') != 'verified_uv_abi':
        raise UvPlanError('verified paired UV plan required')
    book = load_verified() if verified is None else verified
    try:
        ids = plan['programs']
        vertex = _review(book, 'vertices', ids['vertex']['sha256'], ids['vertex']['bindings_sha256'])
        pixel = _review(book, 'pixels', ids['pixel']['sha256'], ids['pixel']['bindings_sha256'])
        _pair(book, plan['package_sha256'], ids['vertex']['sha256'], ids['pixel']['sha256'])
    except (KeyError, TypeError) as error:
        raise UvPlanError('invalid program identity') from error
    if not isinstance(attributes, dict):
        raise UvPlanError('explicit vertex attribute mapping required')
    varyings = {}
    for route in vertex['routes']:
        values = attributes.get(route['input'])
        if not isinstance(values, (tuple, list)) or len(values) != route['width']:
            raise UvPlanError('explicit vertex input required: ' + route['input'])
        if route['input_type'] == 'int' and any(type(x) is not int or not -(1 << 31) <= x < (1 << 31) for x in values):
            raise UvPlanError('signed int32 vertex input required')
        scale = _f32(route['scale'])
        varyings[route['varying']] = [_f32(_f32(x) * scale) for x in values]
    rows = None
    if any(r['affine_xyw'] for r in pixel['samples']):
        if not isinstance(uv_transform_rows, (tuple, list)) or len(uv_transform_rows) != 2:
            raise UvPlanError('two explicit consumed g_PS_UvTransform float4 rows required')
        if any(not isinstance(r, (tuple, list)) or len(r) != 4 for r in uv_transform_rows):
            raise UvPlanError('two explicit consumed g_PS_UvTransform float4 rows required')
        rows = [[_f32(x) for x in r] for r in uv_transform_rows]
    result = []
    for route in pixel['samples']:
        values = varyings[route['varying']]
        uv = [values[i] for i in route['components']]
        if route['affine_xyw']:
            uv = [_f32(_f32(_f32(uv[0] * r[0]) + _f32(uv[1] * r[1])) + r[3]) for r in rows]
        result.append({'layer': route['layer'], 'texture_slot': route['texture_slot'], 'uv': uv})
    return {'status': 'evaluated_uv_abi', 'rendering_complete': False,
            'samples': result, 'scope': 'explicit vertex-input to sampler coordinates; no host layout/matrix construction or rasterization'}
