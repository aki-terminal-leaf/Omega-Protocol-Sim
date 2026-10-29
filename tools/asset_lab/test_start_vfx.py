"""Synthetic ownership/security cases; no native or visual acceptance claims."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from extend_start_vfx import checked_path, extend, sha


class StartVfxTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='start-vfx-unit-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data, self.closure, self.out = (self.root / p for p in ('data', 'closure', 'out'))
        self.sheets, self.catalog = (self.root / p for p in ('sheets.json', 'catalog.json'))
        self.path = 'vfx/common/eff/exact.avfx'
        self.texture = 'vfx/common/texture/exact.atex'
        self.write(self.data / 'manifest.json', {'native_assets': {}})
        self.full = {'cues': [{'key': 'existing', 'start': 123}], 'packs': {}, 'textures': {}}
        self.write(self.data / 'full-data.json', self.full)
        self.record = {'actors': {'7:0': {'id': '7:0', 'player': True}}, 'events': [
            {'type': 'begincast', 'a': 34867, 's': '7:0', 't': 456}]}
        self.write(self.data / 'record.json', self.record)
        self.write(self.data / 'motion-plan.json', {'actors': {}})
        self.metadata = {'actions': [{'id': 34867, 'fields': ['', '', '', '', '', '138']}],
            'cast_timeline': [{'id': 138, 'fields': ['11796', '2208']}],
            'vfx': [{'id': 2208, 'fields': ['exact']}]}
        self.write(self.sheets, self.metadata)
        self.write(self.catalog, {'units': [{'actions': [34867]}]})
        self.write(self.closure / 'bundle/manifest.json', {'missing': [],
            'resources': {self.path: {'sha256': sha(b'avfx')}}})
        self.write(self.closure / 'packs.json', {self.path: {
            'source_sha256': sha(b'avfx'), 'textures': [self.texture]}})
        self.write(self.closure / 'bundle/textures.json', {'textures': [{
            'source': self.texture, 'file': 'textures/exact.png',
            'sha256': sha(b'png'), 'raw_sha256': sha(b'atex')}]})
        for name, payload in [('bundle/raw/' + self.path, b'avfx'),
                              ('bundle/raw/' + self.texture, b'atex'),
                              ('bundle/textures/exact.png', b'png')]:
            p = self.closure / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(payload)

    def write(self, path, doc):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(doc), encoding='utf-8')

    def run_extend(self):
        return extend(self.data, self.closure, self.sheets, self.catalog, self.out)

    def reject(self):
        with self.assertRaises((ValueError, FileNotFoundError)):
            self.run_extend()
        self.assertFalse(self.out.exists())

    def test_player_dependency_survives_missing_pose_without_cue(self):
        before = {p: p.read_bytes() for p in self.data.rglob('*') if p.is_file()}
        proof = self.run_extend()
        dep, = proof['dependencies']
        self.assertEqual((dep['source'], dep['event_index'], dep['original_start_timeline_id']),
                         ('7:0', 0, 11796))
        self.assertEqual(dep['pose_status'], 'UNKNOWN')
        full = json.loads((self.out / 'full-data.json').read_text(encoding='utf-8'))
        self.assertEqual(full['cues'], self.full['cues'])
        self.assertEqual(full['animation_start_dependencies'], proof['dependencies'])
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        self.assertFalse(any(p.is_symlink() for p in self.out.rglob('*')))

    def test_distinct_events_not_collapsed(self):
        self.record['events'].append(copy.deepcopy(self.record['events'][0]))
        self.write(self.data / 'record.json', self.record)
        self.assertEqual([d['event_index'] for d in self.run_extend()['dependencies']], [0, 1])

    def test_zero_reference_is_honest_empty_branch(self):
        self.metadata['cast_timeline'][0]['fields'][1] = '0'
        self.write(self.sheets, self.metadata)
        proof = self.run_extend()
        self.assertEqual(proof['dependencies'], [])
        self.assertEqual(len(proof['zero_start_vfx_references']), 1)
        self.assertFalse(proof['rendering_complete'])

    def test_missing_actor_not_substituted(self):
        self.record['events'][0]['s'] = 'npc'
        self.write(self.data / 'record.json', self.record)
        self.reject()

    def test_raw_texture_required(self):
        (self.closure / 'bundle/raw' / self.texture).unlink()
        self.reject()

    def test_raw_texture_tamper(self):
        (self.closure / 'bundle/raw' / self.texture).write_bytes(b'tampered')
        self.reject()

    def test_avfx_tamper(self):
        (self.closure / 'bundle/raw' / self.path).write_bytes(b'tampered')
        self.reject()

    def test_compiled_source_tamper(self):
        self.write(self.closure / 'packs.json', {self.path: {
            'source_sha256': '0' * 64, 'textures': [self.texture]}})
        self.reject()

    def test_png_tamper(self):
        (self.closure / 'bundle/textures/exact.png').write_bytes(b'tampered')
        self.reject()

    def test_windows_traversal_aliases(self):
        for name in ('../x', '/x', 'C:/x', 'a/../../x', 'a\\x', 'a/./x',
                     'a//x', 'a/x.', 'a/x ', 'a/x:stream', 'CON.png'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                checked_path(self.root, name)


if __name__ == '__main__':
    unittest.main()
