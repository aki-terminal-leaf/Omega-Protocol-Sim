#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Explicit-input Apricot PS reference; never a host binding or render graph.

Real-valued instruction equations with original float32 immediates. Samplers are
caller-supplied decoded numeric functions, not game texture decoding. No hidden
identity transforms, camera positions, Fresnel factors or exposure defaults.
"""
from functools import lru_cache
import json
import math
from pathlib import Path
import struct
try:
    from .apricot_color_plan import (PlanError, DISCARD_THRESHOLD, evaluate, factor_contract)
except ImportError:
    from apricot_color_plan import (PlanError, DISCARD_THRESHOLD, evaluate, factor_contract)

DATA = Path(__file__).with_name('data') / 'apricot_verified_postprocess_programs.json'

class PostprocessError(ValueError):
    pass

@lru_cache(maxsize=1)
def load_verified():
    return json.loads(DATA.read_text(encoding='utf8'))

def _immediate(bits):
    return struct.unpack('<f', struct.pack('<I', int(bits, 16)))[0]

def _number(value):
    if type(value) not in (int, float):
        raise PostprocessError('finite explicit numeric input required')
    try:
        result = float(value)
    except (ValueError, OverflowError) as error:
        raise PostprocessError('finite explicit numeric input required') from error
    if not math.isfinite(result):
        raise PostprocessError('nonfinite explicit input or intermediate result')
    return result

def _values(value, count):
    if not isinstance(value, (tuple, list)) or len(value) != count:
        raise PostprocessError(f'explicit {count}-component vector required')
    return tuple(_number(x) for x in value)

def _review(plan):
    if not isinstance(plan, dict) or plan.get('status') != 'verified_postprocess':
        raise PostprocessError('verified postprocess identity required')
    rows = [p for p in load_verified()['programs']
            if p['bytecode_sha256'] == plan.get('bytecode_sha256')
            and p['bindings_sha256'] == plan.get('bindings_sha256')]
    if len(rows) != 1:
        raise PostprocessError('pixel bytecode/resource layout not reviewed for postprocess')
    # Never trust mutable plan flags to choose output modes or Fresnel behavior.
    return rows[0]

def compile_postprocess_plan(color_plan):
    try:
        if not isinstance(color_plan, dict) or color_plan.get('status') != 'verified_color_stage':
            raise PostprocessError('reviewed color plan required')
        factor_contract(color_plan)
        result = {'status': 'verified_postprocess', 'rendering_complete': False,
                  'bytecode_sha256': color_plan['bytecode_sha256'],
                  'bindings_sha256': color_plan['bindings_sha256'],
                  'scope': 'explicit decoded-sample PS equations; no host ABI or render graph'}
        row = _review(result)
        if color_plan.get('review_equation') != row['equation_id']:
            raise PostprocessError('color equation and postprocess identities disagree')
        return result
    except (PlanError, KeyError) as error:
        raise PostprocessError(str(error)) from error

def fresnel_factor(plan, *, position, normal, axis_modifier, parameter0, parameter1, parameter2):
    """Consumed PS TEXCOORD3.xyz/TEXCOORD4.xyz and FresnelParameter[0..2].

    `parameter0.xyz` is NOT assumed to be EyePosition; its original byte offset
    is 16, not 0. The host meaning/coordinate spaces remain unproved. Degenerate
    normalization, overflow and nonfinite GPU corner behavior are unsupported.
    """
    row = _review(plan)
    if not row['requires_fresnel']:
        raise PostprocessError('this pixel program does not consume model Fresnel')
    p, n = _values(position, 3), _values(normal, 3)
    a = _number(axis_modifier)
    f0, lo, hi = (_values(x, 4) for x in (parameter0, parameter1, parameter2))
    direction = tuple(_number(f0[i] - p[i] * a) for i in range(3))
    dlen, nlen = math.hypot(*direction), math.hypot(*n)
    if not dlen or not nlen or not math.isfinite(dlen) or not math.isfinite(nlen):
        raise PostprocessError('nondegenerate finite Fresnel direction and normal required')
    cosine = abs(sum(direction[i] / dlen * (n[i] / nlen) for i in range(3)))
    base = max(cosine, _immediate(load_verified()['fresnel_floor_bits']))
    try:
        weight = _number(math.pow(base, f0[3]))
    except OverflowError as error:
        raise PostprocessError('Fresnel exponent exceeds finite reference domain') from error
    return tuple(_number(lo[i] + weight * (hi[i] - lo[i])) for i in range(4))

def postprocess_coordinates(plan, *, depth, lut_start_z, lut_inv_range):
    _review(plan)
    z, start, scale = (_number(x) for x in (depth, lut_start_z, lut_inv_range))
    return {'tone_map': (0.5, 0.5), 'dof_lut': (_number((z - start) * scale), 0.5)}

def evaluate_postprocess(plan, *, rgba, tone_map_parameter, apply_tone_map,
                         blend_state_type, depth, lut_start_z, lut_inv_range, sample):
    """Consume the clamp/alpha-saturated boundary and evaluate both original MRTs.

    `sample(role, uv)` must return an explicit decoded RGBA for tone_map/dof_lut.
    Target blending, attachments, texture formats/filter/address modes and final
    display conversion are outside this function. Discard returns no target
    values: callers must preserve both existing attachments, not write zeros.
    """
    row = _review(plan)
    color, tone = _values(rgba, 4), _values(tone_map_parameter, 4)
    apply, blend = _number(apply_tone_map), _number(blend_state_type)
    coordinates = postprocess_coordinates(plan, depth=depth, lut_start_z=lut_start_z,
                                         lut_inv_range=lut_inv_range)
    if not callable(sample):
        raise PostprocessError('explicit decoded postprocess sampler required')
    if not 0 <= color[3] <= 1:
        raise PostprocessError('postprocess boundary alpha must already be saturated')
    if color[3] < DISCARD_THRESHOLD:
        return {'discard': True, 'mrt0': None, 'mrt1': None, 'rendering_complete': False}
    sampled_tone = _values(sample('tone_map', coordinates['tone_map']), 4)
    # Original t.yzwx destination .w is the ORIGINAL texture .x, not its .w.
    radicand = _number(1 + tone[0] * (sampled_tone[0] - 1))
    if radicand <= 0:
        raise PostprocessError('positive finite tone-map rsq operand required')
    exposure = _number(1 + apply * (1 / math.sqrt(radicand) - 1))
    rgb = tuple(_number((value * tone[3]) * exposure) for value in color[:3])
    if row['rgb_output'] == 'saturate_then_alpha_white':
        rgb = tuple(1 + color[3] * (min(1, max(0, x)) - 1) for x in rgb)
    weights = [_immediate(x) for x in load_verified()['output_luma_weight_bits']]
    luma = _number(sum(x * w for x, w in zip(rgb, weights)))
    selected = 1 - luma if blend < 0 else luma
    coverage = _number(2 * max(_number(1 - blend * blend), selected))
    # model1 uses min(2*max(...),1), NOT add_sat: negative is preserved.
    coverage = min(1, coverage) if row['mrt1_alpha'] == 'upper_min' else min(1, max(0, coverage))
    sampled_dof = _values(sample('dof_lut', coordinates['dof_lut']), 4)
    return {'discard': False, 'mrt0': (*rgb, color[3]),
            'mrt1': (sampled_dof[0], 0.0, 0.0, _number(coverage * color[3])),
            'sample_coordinates': coordinates,
            'decoded_samples': {'tone_map': sampled_tone, 'dof_lut': sampled_dof},
            'rendering_complete': False,
            'scope': 'real-valued explicit PS output reference; not GPU-bitwise or render graph'}

def evaluate_pixel(color_plan, samples, *, calculate_color, calculate_alpha,
                   vertex_factor, document_factor, postprocess, sample,
                   model_context=None):
    """Join reviewed sections with separately supplied original-order factors."""
    plan = compile_postprocess_plan(color_plan)
    row = _review(plan)
    if not isinstance(postprocess, dict):
        raise PostprocessError('explicit postprocess input mapping required')
    needed = {'tone_map_parameter', 'apply_tone_map', 'blend_state_type', 'depth',
              'lut_start_z', 'lut_inv_range'}
    if set(postprocess) != needed:
        raise PostprocessError('exact explicit postprocess controls required')
    try:
        color = evaluate(color_plan, samples, calculate_color=_number(calculate_color),
                         calculate_alpha=_number(calculate_alpha))
        if row['requires_fresnel']:
            if not isinstance(model_context, dict):
                raise PostprocessError('explicit model PS inputs/Fresnel parameters required')
            needed_model = {'position', 'normal', 'axis_modifier', 'parameter0', 'parameter1', 'parameter2'}
            if set(model_context) != needed_model:
                raise PostprocessError('exact consumed Fresnel inputs required')
            factor = fresnel_factor(plan, **model_context)
            color = tuple(_number(x * y) for x, y in zip(color, factor))
        if factor_contract(color_plan) == 'before_common':
            color = tuple(max(0, x) for x in color)
        for factor in (vertex_factor, document_factor):
            color = tuple(_number(x * y) for x, y in zip(color, _values(factor, 4)))
        if factor_contract(color_plan) == 'after_common':
            color = tuple(max(0, x) for x in color)
        color = (*color[:3], min(1, max(0, color[3])))
        return evaluate_postprocess(plan, rgba=color, sample=sample, **postprocess)
    except PlanError as error:
        raise PostprocessError(str(error)) from error
