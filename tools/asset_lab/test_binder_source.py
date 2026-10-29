# SPDX-License-Identifier: MIT
"""Synthetic byte oracles only; no original media or renderer execution."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import types
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import avfx_preview_pack as preview


def block(tag, payload, padding=b'\xa5'):
    return (tag[::-1].encode('ascii').ljust(4, b'\0') +
            struct.pack('<I', len(payload)) + payload + padding * (-len(payload) % 4))


def number(tag, value):
    return block(tag, struct.pack('<I', value))


def document(*nodes):
    # Same valid version/count layout as tools/tests/test_avfx_meshes.py.
    counts = {'ScCn': 'Schd', 'TlCn': 'TmLn', 'EmCn': 'Emit', 'PrCn': 'Ptcl',
              'EfCn': 'Efct', 'BdCn': 'Bind', 'TxCn': 'Tex', 'MdCn': 'Modl'}
    payload = number('Ver', 0x20110913)
    payload += b''.join(number(k, sum(t == v for t, _ in nodes)) for k, v in counts.items())
    return block('AVFX', payload + b''.join(block(t, v) for t, v in nodes))


class BinderSourceTests(unittest.TestCase):
    def assert_bytes(self, record, expected):
        self.assertEqual(base64.b64decode(record['payload_base64'], validate=True), expected)
        self.assertEqual(record['sha256'], hashlib.sha256(expected).hexdigest())

    def test_exact_payload_order_duplicates_opaque_and_padding(self):
        nested = block('CoUF', b'\x01') + block('CoUF', b'\x02\x03') + block('ZZ', b'not nested')
        fields = [('Data', nested), ('PrpS', b'opaque property'), ('XXXX', b'\xff\x00\x80'),
                  ('Data', block('Scal', b'\x99')), ('PrpG', b'also opaque'), ('XXXX', b'last!')]
        payload = b''.join(block(t, v) for t, v in fields)
        result = preview.compile_pack(document(('Bind', payload)))
        source = result['groups']['Bind'][0]['binder_source']
        self.assertEqual(set(source), {'schema', 'payload_base64', 'sha256', 'blocks'})
        self.assertEqual(source['schema'], 1)
        self.assert_bytes(source, payload)
        self.assertEqual([r['tag'] for r in source['blocks']], [t for t, _ in fields])
        for row, (tag, value) in zip(source['blocks'], fields):
            self.assert_bytes(row, value)
            self.assertEqual(set(row), {'tag', 'payload_base64', 'sha256'} |
                             ({'child_tags'} if tag == 'Data' else set()))
        self.assertEqual(source['blocks'][0]['child_tags'], ['CoUF', 'CoUF', 'ZZ'])
        self.assertEqual(source['blocks'][3]['child_tags'], ['Scal'])
        self.assertEqual(result['groups']['Bind'][0]['data'], {})

    def test_json_strip_raw_and_full_avfx_removal(self):
        payload = block('Data', block('X', b'\xff')) + block('PrpS', b'opaque!')
        result = preview.compile_pack(document(('Bind', payload)))
        expected = result['groups']['Bind'][0]['binder_source']
        result.pop('raw_avfx_base64')  # full_replay's removal must not lose binder source.
        actual = preview.strip_raw(json.loads(json.dumps(result)))['groups']['Bind'][0]['binder_source']
        self.assertEqual(actual, expected)
        self.assert_bytes(actual, payload)

    def test_empty_data_has_empty_child_tags_and_diagnostic(self):
        result = preview.compile_pack(document(('Bind', block('Data', b''))))
        source = result['groups']['Bind'][0]['binder_source']
        self.assertEqual(source['blocks'][0]['child_tags'], [])
        self.assert_bytes(source['blocks'][0], b'')
        self.assertIn({'path': 'Bind[0]/Data', 'reason': 'binder_data_semantics_unverified'}, result['unsupported'])
        self.assertIn({'path': 'Bind[0]', 'reason': 'external_attachment'}, result['unsupported'])

    def test_malformed_data_bounds_rejected(self):
        malformed = [b'x', b'X\0\0\0' + struct.pack('<I', 100) + b'abcd',
                     b'X\0\0\0' + struct.pack('<I', 1) + b'a']
        for value in malformed:
            with self.subTest(value=value), self.assertRaises(ValueError):
                preview.compile_pack(document(('Bind', block('Data', value))))

    def test_no_binder(self):
        result = preview.compile_pack(document())
        self.assertEqual(result['groups']['Bind'], [])
        self.assertEqual(result['unsupported'], [])
        self.assertEqual(result['compiler_revision'], 3)

    def test_no_data_and_empty_binder(self):
        result = preview.compile_pack(document(('Bind', b''), ('Bind', number('Life', 17))))
        for node, payload in zip(result['groups']['Bind'], [b'', number('Life', 17)]):
            self.assert_bytes(node['binder_source'], payload)
        self.assertEqual(result['groups']['Bind'][0]['binder_source']['blocks'], [])
        self.assertEqual(result['groups']['Bind'][1]['values']['Life'], 17)
        self.assertEqual(result['unsupported'], [
            {'path': 'Bind[0]', 'reason': 'external_attachment'},
            {'path': 'Bind[1]', 'reason': 'external_attachment'}])

    def test_diagnostic_uses_actual_binder_index(self):
        result = preview.compile_pack(document(('Bind', b''), ('Bind', block('Data', b''))))
        diagnostics = [r for r in result['unsupported'] if r['reason'] == 'binder_data_semantics_unverified']
        self.assertEqual(diagnostics, [{'path': 'Bind[1]/Data', 'reason': 'binder_data_semantics_unverified'}])

    def test_interpreted_output_and_previous_diagnostics_equal_accepted_baseline(self):
        root = Path(__file__).resolve().parents[2]
        code = subprocess.check_output(['git', 'show', '1398183:tools/avfx_preview_pack.py'],
                                       cwd=root, timeout=10).decode('utf-8')
        baseline = types.ModuleType('binder_baseline')
        baseline.__package__ = ''
        exec(compile(code, '<accepted-1398183>', 'exec'), baseline.__dict__)
        particle = number('PrVT', 6) + number('RMT', 2) + number('RBDT', 10)
        particle += block('TC2', number('bEna', 1))
        binder = number('Life', 17) + block('bVSb', struct.pack('<f', 0.25))
        binder += block('Data', block('CoUF', b'\x01')) + block('PrpS', b'opaque property')
        for raw in [document(), document(('Bind', binder), ('Ptcl', particle), ('Bind', b''))]:
            with self.subTest(source_sha256=hashlib.sha256(raw).hexdigest()):
                actual = preview.compile_pack(raw)
                actual['compiler_revision'] = 2
                for node in actual['groups']['Bind']:
                    node.pop('binder_source')
                actual['unsupported'] = [r for r in actual['unsupported']
                                         if r['reason'] != 'binder_data_semantics_unverified']
                self.assertEqual(actual, baseline.compile_pack(raw))
                self.assertFalse(actual['rendering_complete'])
                self.assertFalse(actual['gameplay_eligible'])


if __name__ == '__main__':
    unittest.main()
