import hashlib, json, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1]))
from shader_pair_abi import AbiError, adapt

def h(b):
    return hashlib.sha256(b).hexdigest()

def asm(sec, sem='TEXCOORD', idx=0, mask='xyzw', reg=0, used='xyzw'):
    return f'// {sec} signature:\n// Name Index Mask Register SysValue Format Used\n// {sem} {idx} {mask} {reg} NONE float {used}\n'

class ShaderPairAbiTests(unittest.TestCase):

    def make(self, bad=None):
        td = tempfile.TemporaryDirectory()
        r = Path(td.name)
        m = {'schema': 1, 'stages': {}, 'reviewed_ubos': []}
        for s, n in [('vertex', 4), ('fragment', 2)]:
            io = 'out' if s == 'vertex' else 'in'
            vn = 'o1' if s == 'vertex' else 'v1'
            body = 'gl_Position=bi.d[0]; o1=bi.d[0];' if s == 'vertex' else 'c0=v1+bi.d[0];'
            target = '' if s == 'vertex' else 'layout(location=0) out highp vec4 c0;\n'
            src = (f'#version 300 es\nprecision highp float;\n{io} highp vec4 {vn};\n'
                   f'layout(std140) uniform B {{ vec4 d[{n}]; }} bi;\n'
                   + target + f'void main(){{{body}}} // layout(location=9) out vec4 evil; uniform Fake {{ vec4 x[9]; }} nope; {vn} B\n')
            dis = asm('Output') + asm('Input', 'POSITION') if s == 'vertex' else asm('Input') + asm('Output', 'SV_TARGET')
            rf = {'types': {'T': {'name': 'R', 'members': [{'name': 'd', 'type': 'vec4', 'array': [n], 'offset': 0, 'array_stride': 16}]}}, 'outputs' if s == 'vertex' else 'inputs': [{'name': vn, 'location': 0, 'type': 'vec4'}], 'ubos': [{'name': 'R', 'type': 'T', 'set': 0, 'binding': 1, 'block_size': n * 16}]}
            m['stages'][s] = {}
            for k, b in [('glsl', src.encode()), ('reflection', json.dumps(rf).encode()), ('disassembly', dis.encode())]:
                p = r / (s + k)
                p.write_bytes(b)
                m['stages'][s][k] = {'path': p.name, 'sha256': h(b)}
            m['reviewed_ubos'].append({'stage': s, 'name': 'R', 'type': 'T', 'set': 0, 'binding': 1, 'block_size': n * 16, 'gl_block': 'B', 'gl_instance': 'bi'})
        if bad:
            bad(m, r)
        p = r / 'm'
        p.write_text(json.dumps(m))
        return (td, p, r / 'o')

    def test_success_crossed_and_comment(self):
        td, m, o = self.make()
        x = adapt(m, o)
        self.assertEqual(x['varyings'][0]['semantic'], 'TEXCOORD')
        self.assertIn('nope; o1 B', (o / 'pair.vert').read_text())
        td.cleanup()

    def test_negatives(self):
        changes = [lambda m, r: m['reviewed_ubos'].append(dict(m['reviewed_ubos'][0])), lambda m, r: m['reviewed_ubos'][0].update(adapted_block='main'), lambda m, r: m['reviewed_ubos'][0].update(adapted_block='bad-name')]
        for c in changes:
            td, m, o = self.make(c)
            self.assertRaises(AbiError, adapt, m, o)
            td.cleanup()
        td, m, o = self.make()
        x = json.loads(m.read_text())
        x['stages']['vertex']['glsl']['sha256'] = '0' * 64
        m.write_text(json.dumps(x))
        self.assertRaises(AbiError, adapt, m, o)
        self.assertFalse(o.exists())
        td.cleanup()

    def test_missing_signature_section(self):

        def c(m, r):
            p = r / 'fragmentdisassembly'
            p.write_text('// Input signature:\n// malformed\n')
            m['stages']['fragment']['disassembly']['sha256'] = h(p.read_bytes())
        td, m, o = self.make(c)
        self.assertRaises(AbiError, adapt, m, o)
        td.cleanup()

    def test_signature_negatives(self):
        for kw in [dict(sem='COLOR'), dict(idx=1), dict(mask='xy', used='xyzw'), dict(reg=2)]:

            def c(m, r, kw=kw):
                p = r / 'fragmentdisassembly'
                p.write_text(asm('Input', **kw) + asm('Output', 'SV_TARGET'))
                m['stages']['fragment']['disassembly']['sha256'] = h(p.read_bytes())
            td, m, o = self.make(c)
            self.assertRaises(AbiError, adapt, m, o)
            td.cleanup()

    def mutate_file(self, manifest, root, stage, kind, change):
        path = root / manifest['stages'][stage][kind]['path']
        path.write_text(change(path.read_text()))
        manifest['stages'][stage][kind]['sha256'] = h(path.read_bytes())

    def assert_rejected(self, change):
        td, manifest, output = self.make(change)
        self.addCleanup(td.cleanup)
        with self.assertRaises(AbiError):
            adapt(manifest, output)
        self.assertFalse(output.exists())

    def test_malformed_row_beside_valid_row(self):
        def change(m, r):
            self.mutate_file(m, r, 'fragment', 'disassembly', lambda s: s.replace('// Output signature:', '// COLOR nope xyzw 2 NONE float xyzw\n// Output signature:'))
        self.assert_rejected(change)

    def test_signature_numeric_type_not_only_stage_agreement(self):
        def change(m, r):
            for stage in ('vertex', 'fragment'):
                self.mutate_file(m, r, stage, 'disassembly', lambda s: s.replace('NONE float', 'NONE int'))
        self.assert_rejected(change)

    def test_signature_mask_width_matches_glsl(self):
        def change(m, r):
            for stage in ('vertex', 'fragment'):
                self.mutate_file(m, r, stage, 'disassembly', lambda s: s.replace('xyzw', 'xy'))
        self.assert_rejected(change)

    def test_reflected_ubos_are_exhaustive(self):
        def change(m, r):
            def extra(text):
                reflection = json.loads(text)
                reflection['ubos'].append(dict(reflection['ubos'][0], binding=7))
                return json.dumps(reflection)
            self.mutate_file(m, r, 'vertex', 'reflection', extra)
        self.assert_rejected(change)

    def test_ubo_member_identity_and_layout(self):
        for key, value in [('name', 'wrong_member'), ('offset', 16), ('array_stride', 32), ('array_size_is_literal', [False])]:
            with self.subTest(key=key):
                def change(m, r, key=key, value=value):
                    def corrupt(text):
                        reflection = json.loads(text)
                        reflection['types']['T']['members'][0][key] = value
                        return json.dumps(reflection)
                    self.mutate_file(m, r, 'vertex', 'reflection', corrupt)
                self.assert_rejected(change)

    def test_optional_location_must_match_reflection(self):
        def change(m, r):
            self.mutate_file(m, r, 'vertex', 'glsl', lambda s: s.replace('out highp vec4 o1;', 'layout(location=8) flat out highp vec4 o1;'))
        self.assert_rejected(change)

    def test_stale_output_and_dangling_symlink_are_not_replaced(self):
        td, manifest, output = self.make()
        self.addCleanup(td.cleanup)
        output.mkdir()
        sentinel = output / 'sentinel'
        sentinel.write_text('preserve')
        with self.assertRaises(AbiError):
            adapt(manifest, output)
        self.assertEqual(sentinel.read_text(), 'preserve')
        link = output.parent / 'dangling'
        missing = output.parent / 'missing'
        link.symlink_to(missing, target_is_directory=True)
        with self.assertRaises(AbiError):
            adapt(manifest, link)
        self.assertTrue(link.is_symlink())
        self.assertFalse(missing.exists())

    def test_cross_stage_ubo_targets_do_not_alias(self):
        self.assert_rejected(lambda m, r: m['reviewed_ubos'][1].update(adapted_block='VS_B'))

    def test_comment_and_math_bytes_are_preserved(self):
        td, manifest, output = self.make()
        self.addCleanup(td.cleanup)
        original = (Path(td.name) / 'vertexglsl').read_text()
        report = adapt(manifest, output)
        adapted = (output / 'pair.vert').read_text()
        self.assertIn('gl_Position=VS_bi.d[0]; ABI_TEXCOORD_0=VS_bi.d[0];', adapted)
        self.assertEqual(original.split('// layout', 1)[1], adapted.split('// layout', 1)[1])
        self.assertEqual(report['sources']['vertex']['glsl']['sha256'], h(original.encode()))

if __name__ == '__main__':
    unittest.main()
