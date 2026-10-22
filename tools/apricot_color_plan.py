#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Execute a reviewed Apricot texture-combiner SECTION, not an entire shader.

Inputs are already-decoded samples and explicitly supplied dynamic controls.
UV generation, texture binding, Fresnel, lighting, tone-map and MRT remain host
responsibilities. Only exact reviewed bytecode AND resource layouts are allowed.
"""
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
try:
    from .avfx_shader_select import load_names
except ImportError:
    from avfx_shader_select import load_names

DATA = Path(__file__).with_name('data') / 'apricot_verified_color_programs.json'
GROUPS = ('constants', 'samplers', 'textures', 'uavs')

class PlanError(ValueError):
    pass

@lru_cache(maxsize=1)
def load_verified(path=DATA):
    with open(path, encoding='utf8') as source:
        return json.load(source)

def binding_signature(bindings):
    normalized = {}
    for group in GROUPS:
        rows = []
        for row in bindings.get(group, []):
            rows.append({'id': row['id'], 'name': row['name'], 'slot': row['slot'],
                         'is_texture': row['is_texture'],
                         'size': row.get('size', row.get('count'))})
        normalized[group] = sorted(rows, key=lambda x: (x['slot'], x['id'], x['name']))
    return hashlib.sha256(json.dumps(normalized, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def _expression(op, *terms):
    if op == 'None': return terms[0]
    if op in ('Mul', 'Add'):
        flat = []
        identity = 1 if op == 'Mul' else 0
        for term in terms:
            if term == identity: continue
            flat.extend(term[1:] if isinstance(term, list) and term[0] == op else [term])
        if not flat: return identity
        if len(flat) == 1: return flat[0]
        return [op, *sorted(flat, key=lambda x: json.dumps(x, sort_keys=True))]
    if op in ('Min', 'Max') and terms[0] == terms[1]: return terms[0]
    return [op, *terms]

def _first(sample, control):
    return 1 if sample == 1 else ['LerpOne', sample, control]

def equation_signature(layers):
    rgb = alpha = 1
    for layer in layers:
        if not layer['enabled']: continue
        n = layer['number']
        color = 1 if layer['color_to_alpha'] else ['RGB', n]
        a = ['Luma', n] if layer['color_to_alpha'] else ['Alpha', n]
        if n == 1:
            rgb, alpha = _first(color, 'CalculateColor'), _first(a, 'CalculateAlpha')
        else:
            rgb = _expression(layer['color_op'], rgb, color)
            alpha = _expression(layer['alpha_op'], alpha, a)
    return hashlib.sha256(json.dumps([rgb, alpha], separators=(',', ':')).encode()).hexdigest()

def reviewed_equation_signature(label):
    # Manual original-instruction equations. Independent of mutable scene metadata.
    m = _first(['RGB', 1], 'CalculateColor')
    ma = _first(['Alpha', 1], 'CalculateAlpha')
    a = _first(['Luma', 1], 'CalculateAlpha')
    mul = lambda *x: _expression('Mul', *x)
    add = lambda *x: _expression('Add', *x)
    equations = {
        'identity': (1, 1), 'shape1': (m, ma), 'powder1': (m, ma),
        'shape2': (['RGB', 2], a),
        'shape3': (mul(m, ['RGB', 3]), mul(ma, ['Alpha', 2], ['Alpha', 3])),
        'shape4': (add(mul(['RGB', 2], ['RGB', 3]), ['RGB', 4]), mul(a, ['Alpha', 2])),
        'model1': (1, a), 'model2': (['RGB', 2], a),
        'model3': (add(m, ['RGB', 2]), mul(ma, ['Luma', 3])),
        'model4': (add(['RGB', 2], ['RGB', 3]), mul(a, ['Alpha', 2], ['Luma', 4])),
    }
    if label not in equations: raise PlanError('no reviewed color equation for program')
    return hashlib.sha256(json.dumps(equations[label], separators=(',', ':')).encode()).hexdigest()

def compile_plan(meta, node_index, *, pass_index=None, verified=None):
    result = {'schema': 1, 'status': 'unsupported', 'rendering_complete': False,
              'section': 'texture color combiner before common factors/postprocess',
              'package_sha256': meta.get('source_sha256'), 'node_index': node_index,
              'diagnostics': []}
    try:
        if not isinstance(node_index, int) or isinstance(node_index, bool):
            raise PlanError('node index must be an integer')
        nodes = [node for node in meta['nodes'] if node['index'] == node_index]
        if len(nodes) != 1:
            raise PlanError('node index is absent or duplicated')
        node = nodes[0]
        passes = node['passes']
        if pass_index is None:
            if len(passes) != 1:
                raise PlanError('an explicit pass index is required')
            pass_index = 0
        if not isinstance(pass_index, int) or isinstance(pass_index, bool) or not 0 <= pass_index < len(passes):
            raise PlanError('pass index outside node')
        shader_pass = passes[pass_index]
        pixel_index = shader_pass['pixel']
        if not isinstance(pixel_index,int) or isinstance(pixel_index,bool) or pixel_index < 0 or pixel_index >= len(meta['programs']['pixel']):
            raise PlanError('no executable pixel program for this pass')
        program = meta['programs']['pixel'][pixel_index]
        code_hash = program['bytecode']['sha256']
        layout_hash = binding_signature(program['bindings'])
        book = load_verified() if verified is None else verified
        reviews = book['programs']
        review = next((row for row in reviews if row['bytecode_sha256'] == code_hash
                       and row['bindings_sha256'] == layout_hash), None)
        if review is None:
            raise PlanError('pixel bytecode/resource layout is not reviewed')
        ids = {int(key, 16): name for key, name in load_names()['keys'].items()}
        declarations = meta['keys']['scene']
        values = node['keys']['scene']
        if len(declarations) != len(values) or len({x['id'] for x in declarations}) != len(declarations):
            raise PlanError('invalid or duplicate package-local scene schema')
        named, unknown = {}, []
        for key, value in zip(declarations, values):
            name = ids.get(key['id'])
            if name is None:
                unknown.append({'id': key['id'], 'value': value})
            else:
                named[name] = ids.get(value, f'0x{value:08X}')
        def choice(key, values):
            value = named.get(key)
            if value not in values:
                raise PlanError(f'unresolved color-stage semantic {key}: {value}')
            return values[value]
        layers = []
        identity = review['equation_id'] == 'identity'
        for number in range(1, 5):
            prefix = f'TextureColor{number}'
            if identity:
                # This is an observed PROGRAM behavior, not an inferred AVFX
                # default: the reviewed identity programs do not sample color.
                enabled = False
            else:
                enabled = choice(prefix + '_Table', {prefix + '_Disable': False, prefix + '_Enable': True})
            layer = {'number': number, 'enabled': enabled}
            if enabled:
                layer['color_to_alpha'] = choice(prefix + '_ColorToAlpha_Table',
                    {prefix + '_ColorToAlpha_Off': False, prefix + '_ColorToAlpha_On': True})
                layer['uv_index'] = choice(prefix + '_UvNo_Table',
                    {prefix + f'_Uv_{i}': i for i in range(4)})
                layer['decode_semantic'] = named.get(prefix + '_Decode_Table')
                if number == 1:
                    layer.update(color_op='DynamicMul', alpha_op='DynamicMul')
                else:
                    layer['color_op'] = choice(prefix + '_CalculateColor_Table',
                        {prefix + '_CalculateColor_' + value: value
                         for value in ('Mul', 'Add', 'Sub', 'Max', 'Min', 'None')})
                    layer['alpha_op'] = choice(prefix + '_CalculateAlpha_Table',
                        {prefix + '_CalculateAlpha_' + value: value
                         for value in ('Mul', 'Max', 'Min', 'None')})
                # CTA replaces RGB with white. With alpha=None, even an enabled
                # layer can be constant-only and its sampler is optimized away.
                layer['sample_required'] = (number == 1 or
                    (not layer['color_to_alpha'] and layer['color_op'] != 'None') or
                    layer['alpha_op'] != 'None')
                names = {row['name'] for row in program['bindings'].get('textures', [])}
                if layer['sample_required'] and f'g_SamplerColor{number}' not in names:
                    raise PlanError('required color sampler is absent from reviewed layout')
            layers.append(layer)
        signature = equation_signature(layers)
        if signature != reviewed_equation_signature(review['equation_id']):
            raise PlanError('scene-derived equation contradicts reviewed pixel instructions')
        result.update(status='verified_color_stage', layers=layers, pass_index=pass_index,
                      color_equation_sha256=signature,
                      pass_id=shader_pass['id'], vertex_shader=shader_pass['vertex'], pixel_shader=pixel_index,
                      bytecode_sha256=code_hash, bindings_sha256=layout_hash,
                      review_equation=review['equation_id'], unresolved_scene_keys=unknown,
                      color_to_alpha_weights=book.get('color_to_alpha_weights'),
                      requires_model_fresnel=any(row['name'] == 'g_PS_ModelSpecificParameters'
                                                for row in program['bindings'].get('constants', [])),
                      required_inputs=['decoded texture samples', 'CalculateColor', 'CalculateAlpha',
                                       'vertex/document/model factors', 'UV/binding/render-graph context'])
    except (PlanError, KeyError, IndexError, TypeError) as error:
        result['diagnostics'].append(str(error))
    return result

def vector(value):
    if not isinstance(value, (list, tuple)) or len(value) != 4:
        raise PlanError('RGBA value must have four components')
    result = tuple(float(x) for x in value)
    if not all(math.isfinite(x) for x in result):
        raise PlanError('nonfinite RGBA input')
    return result

def luminance(color, weights):
    if not isinstance(weights, (list, tuple)) or len(weights) != 3 or not all(math.isfinite(float(x)) for x in weights):
        raise PlanError('explicit reviewed color-to-alpha weights required')
    return sum(color[i] * weight for i, weight in enumerate(weights))

def operation(previous, sample, mode):
    if mode == 'Mul': return previous * sample
    if mode == 'Add': return previous + sample
    if mode == 'Sub': return previous - sample
    if mode == 'Max': return max(previous, sample)
    if mode == 'Min': return min(previous, sample)
    if mode == 'None': return previous
    raise PlanError('unknown color-combiner operation')

def evaluate(plan, samples, *, calculate_color, calculate_alpha):
    """Evaluate reviewed real-valued texture equations (not GPU-bitwise); do not invent host controls."""
    if plan.get('status') != 'verified_color_stage':
        raise PlanError('cannot execute unsupported color plan')
    if not isinstance(samples, (list, tuple)) or len(samples) != 4:
        raise PlanError('provide four explicit decoded sample slots')
    if not isinstance(plan.get('layers'), list) or [layer.get('number') for layer in plan['layers']] != [1,2,3,4]:
        raise PlanError('color plan must contain exactly four ordered layers')
    if equation_signature(plan['layers']) != plan.get('color_equation_sha256'):
        raise PlanError('color layers changed after instruction-equation verification')
    controls = float(calculate_color), float(calculate_alpha)
    if not all(math.isfinite(value) for value in controls):
        raise PlanError('nonfinite dynamic color control')
    result = (1.0, 1.0, 1.0, 1.0)
    for layer in plan['layers']:
        if not layer['enabled']: continue
        required = (layer['number'] == 1 or
                    (not layer['color_to_alpha'] and layer['color_op'] != 'None') or
                    layer['alpha_op'] != 'None')
        if layer.get('sample_required') is not required:
            raise PlanError('color sampling dependency changed after compilation')
        sample = vector(samples[layer['number'] - 1]) if layer.get('sample_required') else (1., 1., 1., 1.)
        if layer['color_to_alpha']:
            sample = (1.0, 1.0, 1.0, luminance(sample, plan.get('color_to_alpha_weights')) if layer.get('sample_required') else 1.)
        if layer['number'] == 1:
            result = tuple(1 + (sample[i] - 1) * controls[0 if i < 3 else 1] for i in range(4))
        else:
            result = tuple(operation(result[i], sample[i], layer['color_op'] if i < 3 else layer['alpha_op'])
                           for i in range(4))
    if not all(math.isfinite(value) for value in result):
        raise PlanError('nonfinite combiner result')
    return result

def shade_before_postprocess(plan, samples, *, calculate_color, calculate_alpha, common_factor):
    """Explicit common factor includes vertex/document/Fresnel as appropriate."""
    color = evaluate(plan, samples, calculate_color=calculate_color, calculate_alpha=calculate_alpha)
    factor = vector(common_factor)
    color = tuple(color[i] * factor[i] for i in range(4))
    if not all(math.isfinite(value) for value in color):
        raise PlanError('nonfinite common-factor result')
    color = tuple(max(0.0, color[i]) if i < 3 else min(1.0, max(0.0, color[i])) for i in range(4))
    return {'rgba': color, 'discard': color[3] < 1 / 255, 'rendering_complete': False}
