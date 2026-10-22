#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Strict hash-gated identifier-only ES300 shader-pair ABI adapter.

Schema 1: stages.{vertex,fragment}.{glsl,reflection,disassembly}={path,sha256},
plus reviewed_ubos entries. API: adapt(manifest,new_output_directory).
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

class AbiError(ValueError):
    pass
V = re.compile(r'^[ \t]*(?:layout\s*\(([^)]*)\)\s*)?(?:(?:flat|smooth|noperspective|centroid|sample|invariant)\s+)*(in|out)\s+(?:(?:lowp|mediump|highp)\s+)?(\w+)\s+(\w+)\s*;', re.M)
U = re.compile('layout\\s*\\(([^)]*)\\)\\s*uniform\\s+(\\w+)\\s*\\{([^{}]*)\\}\\s*(\\w+)\\s*;', re.S)
M = re.compile('^\\s*(?:(?:lowp|mediump|highp)\\s+)?vec4\\s+(\\w+)\\s*\\[\\s*(\\d+)\\s*\\]\\s*;\\s*$', re.S)
R = re.compile('^// *([A-Za-z_][A-Za-z0-9_]*) +([0-9]+) +([xyzw]+) +([0-9]+) +[A-Za-z0-9_]+ +([A-Za-z_][A-Za-z0-9_]*)(?: +([A-Za-z_][A-Za-z0-9_]*))? *$', re.M)
I = re.compile('//[^\\n]*|/\\*.*?\\*/|"(?:\\\\.|[^"\\\\])*"|\\b[A-Za-z_]\\w*\\b', re.S)
GLSL_RESERVED = frozenset('attribute const uniform varying buffer shared coherent volatile restrict readonly writeonly layout centroid flat smooth noperspective patch sample break continue do for while switch case default if else in out inout float double int void bool true false invariant precise discard return vec2 vec3 vec4 ivec2 ivec3 ivec4 bvec2 bvec3 bvec4 uint uvec2 uvec3 uvec4 lowp mediump highp precision struct'.split())

def sha(b):
    return hashlib.sha256(b).hexdigest()

def valid_target_identifier(value):
    return bool(re.fullmatch('[A-Za-z_][A-Za-z0-9_]*', value or '')) and value not in GLSL_RESERVED and (not value.startswith('gl_')) and ('__' not in value)

def sig(source, name):
    """Read exactly one bounded DXBC signature section; never skip bad rows."""
    marker = re.compile('^//\\s*' + re.escape(name) + ' signature:\\s*$', re.M)
    headers = list(marker.finditer(source))
    if len(headers) != 1:
        raise AbiError('missing or ambiguous signature section')
    section = source[headers[0].end():]
    boundary = re.search('^//\\s*(?:(?:Input|Output|Patch Constant) signature|Resource Bindings|Buffer Definitions|Pipeline Runtime Information|shader hash):|^[A-Za-z_]', section, re.M | re.I)
    if boundary:
        section = section[:boundary.start()]
    rows = []
    for line in section.splitlines():
        if not line.strip():
            continue
        if not line.startswith('//'):
            raise AbiError('malformed signature section')
        body = line[2:].strip()
        if not body or body.startswith('Name ') or re.fullmatch('[- ]+', body):
            continue
        match = R.fullmatch(line)
        if not match:
            raise AbiError('malformed signature row')
        semantic, index, mask, register, fmt, used = match.groups()
        used = '' if not used or used.lower() == 'none' else used
        if fmt not in ('float', 'int', 'uint') or mask != ''.join((c for c in 'xyzw' if c in mask)):
            raise AbiError('unsupported signature format or mask')
        if used != ''.join((c for c in 'xyzw' if c in used)) or not set(used) <= set(mask):
            raise AbiError('invalid signature Used channels')
        rows.append(dict(semantic=semantic.upper(), index=int(index), mask=mask, register=int(register), format=fmt, used=used))
    if not rows:
        raise AbiError('empty signature')
    if len({r['register'] for r in rows}) != len(rows) or len({(r['semantic'], r['index']) for r in rows}) != len(rows):
        raise AbiError('ambiguous signature register or semantic')
    return rows

def signature_type(row):
    width = len(row['mask'])
    return row['format'] if width == 1 else {'float': 'vec', 'int': 'ivec', 'uint': 'uvec'}[row['format']] + str(width)

def code_only(source):
    return re.sub('//[^\\n]*|/\\*.*?\\*/|"(?:\\\\.|[^"\\\\])*"', lambda m: ' ' * len(m.group()), source, flags=re.S)

def parse_glsl(s, stage):
    v = {}
    u = {}
    clean = code_only(s)
    if not re.match('\\s*#version[ \\t]+300[ \\t]+es(?:[ \\t]*\\n|[ \\t]*$)', clean):
        raise AbiError('ES300 source required')
    for lay, d, t, n in V.findall(clean):
        if d == ('out' if stage == 'vertex' else 'in'):
            x = re.search('\\blocation\\s*=\\s*(\\d+)', lay or '')
            location = None if x is None else int(x.group(1))
            if n in v:
                raise AbiError('duplicate varying declaration')
            v[n] = (t, location)
    for lay, b, body, i in U.findall(clean):
        x = re.search('\\bbinding\\s*=\\s*(\\d+)', lay)
        m = M.fullmatch(body)
        if not re.search('\\bstd140\\b', lay) or not m:
            raise AbiError('unsupported UBO')
        if (b, i) in u:
            raise AbiError('duplicate UBO declaration')
        u[b, i] = (None if x is None else int(x.group(1)), int(m.group(2)), m.group(1))
    if len(re.findall('\\buniform\\s+\\w+\\s*\\{', clean)) != len(u):
        raise AbiError('unsupported uniform block declaration')
    return (v, u)

def adapt(manifest, output):
    mp = Path(manifest).resolve()
    o = Path(output).absolute()
    m = json.loads(mp.read_text())
    if m.get('schema') != 1:
        raise AbiError('schema must be 1')
    f = {}
    for s in ('vertex', 'fragment'):
        for k in ('glsl', 'reflection', 'disassembly'):
            x = m.get('stages', {}).get(s, {}).get(k, {})
            if set(x) != set(('path', 'sha256')):
                raise AbiError('bad file reference')
            p = (mp.parent / x['path']).resolve()
            b = p.read_bytes()
            if sha(b) != x['sha256']:
                raise AbiError('hash mismatch')
            f[s, k] = (p, b)
    if o.exists() or o.is_symlink():
        raise AbiError('output exists')
    src = {s: f[s, 'glsl'][1].decode() for s in ('vertex', 'fragment')}
    g = {s: parse_glsl(src[s], s) for s in src}
    rf = {}
    ru = {}
    types = {}
    for s in src:
        reflection = json.loads(f[s, 'reflection'][1])
        types[s] = reflection.get('types', {})
        rf[s] = {}
        for z in reflection.get('outputs' if s == 'vertex' else 'inputs', []):
            if z['location'] in rf[s]:
                raise AbiError('duplicate reflection location')
            rf[s][z['location']] = (z['name'], z['type'])
        ru[s] = {}
        for z in reflection.get('ubos', []):
            k = (z.get('name'), z.get('type'), z.get('set', 0), z.get('binding'), z.get('block_size'))
            if k in ru[s]:
                raise AbiError('duplicate reflected UBO')
            ru[s][k] = z
    ren = {s: {} for s in src}
    um = []
    seen = set()
    mapped_reflection = {s: set() for s in src}
    for x in m.get('reviewed_ubos', []):
        s = x.get('stage')
        key = (x.get('gl_block'), x.get('gl_instance'))
        if s not in src or (s, key) in seen:
            raise AbiError('duplicate UBO mapping')
        seen.add((s, key))
        declaration = g[s][1].get(key)
        reflected = (x.get('name'), x.get('type'), x.get('set', 0), x.get('binding'), x.get('block_size'))
        type_info = types[s].get(x.get('type'), {})
        members = type_info.get('members', [])
        valid_member = len(members) == 1 and members[0].get('type') == 'vec4' and (members[0].get('name') == (declaration[2] if declaration else None)) and (members[0].get('array_size_is_literal', [True]) == [True]) and (members[0].get('offset') == 0) and (members[0].get('array_stride') == 16) and (members[0].get('array') == [x.get('block_size', 0) // 16])
        if not declaration or reflected not in ru[s] or reflected in mapped_reflection[s] or x.get('block_size', 0) % 16 or (declaration[1] != x.get('block_size') // 16) or (declaration[0] is not None and declaration[0] != x.get('binding')) or (not valid_member):
            raise AbiError('UBO mismatch')
        mapped_reflection[s].add(reflected)
        prefix = 'VS_' if s == 'vertex' else 'PS_'
        adapted = (x.get('adapted_block', prefix + key[0]), x.get('adapted_instance', prefix + key[1]))
        if not all((valid_target_identifier(z) and z.startswith(prefix) for z in adapted)):
            raise AbiError('invalid target identifier')
        for old, new_name in zip(key, adapted):
            if old in ren[s] and ren[s][old] != new_name:
                raise AbiError('source-key conflict')
            ren[s][old] = new_name
        um.append({**x, 'adapted_block': adapted[0], 'adapted_instance': adapted[1]})
    if seen != {(s, key) for s in src for key in g[s][1]}:
        raise AbiError('explicit mapping required')
    if any((mapped_reflection[s] != set(ru[s]) for s in src)):
        raise AbiError('all reflected UBOs must be mapped exactly once')
    all_targets = [value for stage in ren.values() for value in stage.values()]
    if len(all_targets) != len(set(all_targets)):
        raise AbiError('cross-stage target collision')
    vertex_sig = sig(f['vertex', 'disassembly'][1].decode(), 'Output')
    fragment_sig = sig(f['fragment', 'disassembly'][1].decode(), 'Input')
    vs = {x['register']: x for x in vertex_sig}
    ps = [x for x in fragment_sig if x['used']]
    if len(vs) != len(vertex_sig) or len({x['register'] for x in ps}) != len(ps):
        raise AbiError('duplicate register')
    vm = []
    for stage, signature in (('vertex', vs), ('fragment', {row['register']: row for row in fragment_sig})):
        declarations = g[stage][0]
        if set(declarations) != {row[0] for row in rf[stage].values()}:
            raise AbiError('varying declaration/reflection coverage mismatch')
        for location, (name, type_name) in rf[stage].items():
            row = signature.get(location)
            declared = declarations.get(name)
            if not row or not declared or type_name != signature_type(row) or (declared[0] != type_name):
                raise AbiError('signature/reflection type mismatch')
            if declared[1] is not None and declared[1] != location:
                raise AbiError('GLSL location mismatch')
    if {row['register'] for row in ps} != set(rf['fragment']):
        raise AbiError('fragment signature/reflection coverage mismatch')
    for p in ps:
        location = p['register']
        v = vs.get(location)
        vr = rf['vertex'].get(location)
        pr = rf['fragment'].get(location)
        if not all((v, vr, pr)):
            raise AbiError('missing varying')
        vg = g['vertex'][0].get(vr[0])
        pg = g['fragment'][0].get(pr[0])
        if not all((vg, pg)):
            raise AbiError('missing varying declaration')
        if (v['semantic'], v['index'], v['format']) != (p['semantic'], p['index'], p['format']) or not set(p['used']) <= set(v['mask']) or (not set(p['used']) <= set(v['used'])) or (not set(p['used']) <= set(p['mask'])):
            raise AbiError('signature mismatch')
        if vg[0] != pg[0] or vg[0] != vr[1] or pg[0] != pr[1]:
            raise AbiError('type/reflection mismatch')
        if vg[1] is not None and vg[1] != location or (pg[1] is not None and pg[1] != location):
            raise AbiError('GLSL location mismatch')
        adapted = 'ABI_{}_{}'.format(p['semantic'], p['index'])
        if not valid_target_identifier(adapted):
            raise AbiError('invalid varying target identifier')
        for stage, old in (('vertex', vr[0]), ('fragment', pr[0])):
            if old in ren[stage] and ren[stage][old] != adapted:
                raise AbiError('source-key conflict')
            ren[stage][old] = adapted
        vm.append({**p, 'type': vg[0], 'adapted': adapted})
    out = {}
    for s in src:
        if len(set(ren[s].values())) != len(ren[s]):
            raise AbiError('target collision')
        tokens = {z for z in I.findall(src[s]) if re.fullmatch('[A-Za-z_]\\w*', z)}
        if tokens - set(ren[s]) & set(ren[s].values()):
            raise AbiError('target collision')
        out[s] = I.sub(lambda z: z.group() if z.group().startswith(('/', '"')) else ren[s].get(z.group(), z.group()), src[s])
    o.mkdir()
    names = {'vertex': 'pair.vert', 'fragment': 'pair.frag'}
    for s in src:
        (o / names[s]).write_text(out[s])
    report = {'schema': 1, 'reviewed_ubos': um, 'varyings': vm, 'sources': {}, 'outputs': {}}
    for s in src:
        report['sources'][s] = {k: {'path': str(f[s, k][0]), 'sha256': sha(f[s, k][1])} for k in ('glsl', 'reflection', 'disassembly')}
        report['outputs'][s] = {'path': names[s], 'sha256': sha(out[s].encode()), 'renames': ren[s]}
    (o / 'abi.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    return report

def main():
    p = argparse.ArgumentParser(description=__doc__, epilog='Limits: ES300; one vec4-array std140 member; identifier substitutions only; unused vertex outputs unchanged.')
    p.add_argument('--input', required=True)
    p.add_argument('--output', required=True)
    a = p.parse_args()
    try:
        adapt(a.input, a.output)
    except (AbiError, OSError, KeyError, TypeError, json.JSONDecodeError) as e:
        p.error(str(e))
if __name__ == '__main__':
    main()
