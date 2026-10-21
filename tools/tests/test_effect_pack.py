# SPDX-License-Identifier: MIT
"""Synthetic inventory fixtures only; no game, .NET, or imaging dependencies."""
import copy
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import effect_pack as pack
import export_official_effects as exporter


def sha(data):
    return hashlib.sha256(data).hexdigest()


def png(width=2, height=1):
    def chunk(kind, payload):
        return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress((b'\0' + b'\xff\0\0\xff' * width) * height))
            + chunk(b'IEND', b''))


class EffectPackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'input'
        self.root.mkdir()
        self.avfx = b'synthetic AVFX bytes\x00'
        self.image = png()
        self.path = 'meteor/textures/vfx/shared/ele017bm.tex.png'
        self.manifest = {
            'schema': 1, 'scope': 'synthetic inventory',
            'effects': {'meteor': {
                'source_path': 'chara/monster/example.avfx', 'sha256': sha(self.avfx),
                'rendering_complete': False, 'npc': 123,
                'textures': [{'source': 'vfx/shared/ele017bm.tex', 'file': self.path,
                              'width': 2, 'height': 1, 'raw_sha256': sha(b'original TEX metadata'),
                              'sha256': sha(self.image)}]}}}
        self.write_asset('meteor/effect.avfx', self.avfx)
        self.write_asset(self.path, self.image)
        self.save()

    @property
    def texture(self):
        return self.manifest['effects']['meteor']['textures'][0]

    def write_asset(self, name, data):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    def save(self):
        (self.root / 'effects-manifest.json').write_text(json.dumps(self.manifest), encoding='utf-8')

    def test_canonical_inventory_and_preserved_metadata(self):
        self.assertEqual(pack.validate_pack(self.root), self.manifest)
        output = self.base / 'output'
        result = pack.migrate_pack(self.root, output)
        self.assertEqual(result, self.manifest)
        self.assertEqual((output / self.path).read_bytes(), self.image)
        self.assertEqual((output / 'meteor/effect.avfx').read_bytes(), self.avfx)
        self.assertEqual(pack.validate_pack(self.root), self.manifest)
        self.assertIs(result['effects']['meteor']['rendering_complete'], False)

    def test_export_names_preserve_hierarchy_extension_and_are_stable(self):
        names = [pack.texture_output_path('meteor', name) for name in
                 ('vfx/a/same.tex', 'vfx/b/same.tex', 'vfx/a/same.atex')]
        self.assertEqual(len(set(names)), 3)
        self.assertEqual(names[0], 'meteor/textures/vfx/a/same.tex.png')
        self.assertEqual(names[0], pack.texture_output_path('meteor', 'vfx/a/same.tex'))
        self.assertTrue(all('\\' not in name for name in names))

    def test_actual_exporter_with_synthetic_dependencies(self):
        references = ['vfx/a/same.tex', 'vfx/b/same.tex', 'vfx/a/same.atex']
        raw = (' '.join(references)).encode('ascii')
        texture = types.SimpleNamespace(Data=b'raw TEX', ImageData=b'pixels', Header=types.SimpleNamespace(Width=2, Height=1))
        class Getter:
            def __getitem__(self, kind):
                return lambda name: types.SimpleNamespace(Data=raw) if name.endswith('.avfx') else texture
        realm = types.SimpleNamespace(GetFile=Getter(), Dispose=lambda: None)
        image = types.SimpleNamespace(width=2, height=1, save=lambda target: target.write_bytes(png()))
        modules = {
            'export_official_models': types.SimpleNamespace(initialize=lambda args: realm),
            'Lumina.Data': types.SimpleNamespace(FileResource=object),
            'Lumina.Data.Files': types.SimpleNamespace(TexFile=object),
            'PIL': types.SimpleNamespace(Image=types.SimpleNamespace(frombytes=lambda *args: image)),
        }
        output = self.base / 'exported'
        argv = ['export_official_effects', '--game-dir', '.', '--lumina-dir', '.', '--textools-dir', '.', '--output', str(output), '--forms', 'meteor']
        with patch.dict(sys.modules, modules), patch.object(sys, 'argv', argv):
            exporter.main()
        manifest = pack.validate_pack(output)
        entry = manifest['effects']['meteor']
        self.assertEqual(entry['sha256'], sha(raw))
        self.assertEqual({t['file'] for t in entry['textures']}, {pack.texture_output_path('meteor', ref) for ref in references})
        self.assertTrue(all(t['raw_sha256'] == sha(b'raw TEX') for t in entry['textures']))

    def test_legacy_backslash_manifest_nested_files(self):
        self.texture['file'] = self.path.replace('/', '\\')
        self.save()
        before = (self.root / 'effects-manifest.json').read_bytes()
        with self.assertRaises(pack.PackError):
            pack.validate_pack(self.root)
        output = self.base / 'normalized'
        result = pack.migrate_pack(self.root, output)
        self.assertEqual(result['effects']['meteor']['textures'][0]['file'], self.path)
        self.assertEqual((self.root / 'effects-manifest.json').read_bytes(), before)
        self.assertEqual((output / self.path).read_bytes(), self.image)
        self.assertEqual(result['effects']['meteor']['textures'][0]['raw_sha256'], self.texture['raw_sha256'])

    def test_explicit_legacy_avfx_path_and_mixed_separators(self):
        self.manifest['effects']['meteor']['file'] = 'meteor\\effect.avfx'
        self.texture['file'] = self.path.replace('/textures/', '\\textures/')
        self.save()
        result = pack.migrate_pack(self.root, self.base / 'output')
        self.assertEqual(result['effects']['meteor']['file'], 'meteor/effect.avfx')
        self.assertEqual(result['effects']['meteor']['textures'][0]['file'], self.path)

    @unittest.skipIf(os.name == 'nt', 'Literal backslash filenames require a POSIX filesystem')
    def test_literal_backslash_files_and_implicit_avfx(self):
        for name in [self.path, 'meteor/effect.avfx']:
            (self.root / name).rename(self.root / name.replace('/', '\\'))
        self.texture['file'] = self.path.replace('/', '\\')
        self.save()
        output = self.base / 'normalized'
        pack.migrate_pack(self.root, output)
        self.assertEqual((output / self.path).read_bytes(), self.image)
        self.assertTrue((self.root / self.path.replace('/', '\\')).is_file())
        self.assertEqual((output / 'meteor/effect.avfx').read_bytes(), self.avfx)

    @unittest.skipIf(os.name == 'nt', 'Distinct literal and nested paths require POSIX')
    def test_ambiguous_literal_and_nested_rejected(self):
        self.write_asset(self.path.replace('/', '\\'), self.image)
        self.texture['file'] = self.path.replace('/', '\\')
        self.save()
        with self.assertRaisesRegex(pack.PackError, 'Ambiguous'):
            pack.migrate_pack(self.root, self.base / 'output')

    @unittest.skipIf(os.name == 'nt', 'Literal backslash filenames require POSIX')
    def test_canonical_manifest_with_literal_legacy_file(self):
        (self.root / self.path).rename(self.root / self.path.replace('/', '\\'))
        with self.assertRaises(pack.PackError):
            pack.validate_pack(self.root)
        pack.migrate_pack(self.root, self.base / 'output')
        self.assertEqual((self.base / 'output' / self.path).read_bytes(), self.image)

    def test_missing_and_tampered_assets(self):
        for name, original in [('meteor/effect.avfx', self.avfx), (self.path, self.image)]:
            for damage in ('missing', 'tampered'):
                with self.subTest(name=name, damage=damage):
                    target = self.root / name
                    target.unlink()
                    if damage == 'tampered':
                        target.write_bytes(original + b'changed')
                    with self.assertRaises(pack.PackError):
                        pack.validate_pack(self.root)
                    with self.assertRaises(pack.PackError):
                        pack.migrate_pack(self.root, self.base / 'output')
                    self.assertFalse((self.base / 'output').exists())
                    target.write_bytes(original)

    def test_corrupt_png_and_wrong_dimensions_even_with_matching_hash(self):
        for data in (b'not a PNG', self.image[:30], self.image[:-1] + b'x', self.image + b'trailing'):
            with self.subTest(data=data[:12]):
                (self.root / self.path).write_bytes(data)
                self.texture['sha256'] = sha(data)
                self.save()
                with self.assertRaises(pack.PackError):
                    pack.validate_pack(self.root)
        (self.root / self.path).write_bytes(self.image)
        self.texture.update(sha256=sha(self.image), width=3)
        self.save()
        with self.assertRaisesRegex(pack.PackError, 'dimensions'):
            pack.validate_pack(self.root)

    def test_unsafe_paths_cannot_be_normalized(self):
        for name in ('../escape.png', '/absolute.png', 'C:/escape.png', 'C:escape.png',
                     '\\\\server\\share.png', 'meteor\\..\\escape.png', 'a//b', 'a/./b',
                     'a/CON.png', 'a/name. ', 'a/file:stream', ''):
            with self.subTest(name=name):
                self.texture['file'] = name
                self.save()
                with self.assertRaises(pack.PackError):
                    pack.migrate_pack(self.root, self.base / 'output')
                self.assertFalse((self.base / 'output').exists())

    def test_duplicate_output_references_including_case_and_separator_aliases(self):
        for duplicate in (self.path, self.path.upper(), self.path.replace('/', '\\')):
            second = copy.deepcopy(self.texture)
            second.update(source='vfx/other/texture.tex', file=duplicate)
            self.manifest['effects']['meteor']['textures'] = [self.texture, second]
            self.save()
            with self.assertRaisesRegex(pack.PackError, 'Duplicate output'):
                pack.migrate_pack(self.root, self.base / 'output')

    def test_schema_metadata_and_false_claims(self):
        original = copy.deepcopy(self.manifest)
        mutations = [lambda m: m.update(schema=2), lambda m: m.update(schema=True),
                     lambda m: m.update(rendering_complete=True),
                     lambda m: m['effects']['meteor'].update(rendering_complete=True),
                     lambda m: m['effects']['meteor'].pop('rendering_complete'),
                     lambda m: m['effects']['meteor'].update(sha256='invalid'),
                     lambda m: m['effects']['meteor']['textures'][0].update(raw_sha256='bad'),
                     lambda m: m.update(effects=[])]
        for mutation in mutations:
            self.manifest = copy.deepcopy(original)
            mutation(self.manifest)
            self.save()
            with self.assertRaises(pack.PackError):
                pack.validate_pack(self.root)

    def test_duplicate_json_keys_rejected(self):
        (self.root / 'effects-manifest.json').write_text('{"schema":1,"schema":1}', encoding='utf-8')
        with self.assertRaisesRegex(pack.PackError, 'Duplicate JSON'):
            pack.validate_pack(self.root)

    def test_output_must_be_new_and_disjoint(self):
        for output in (self.root, self.root / 'nested', self.base):
            with self.subTest(output=output), self.assertRaises(pack.PackError):
                pack.migrate_pack(self.root, output)
        self.assertEqual(pack.validate_pack(self.root), self.manifest)

    def test_symlink_escape_rejected(self):
        external = self.base / 'outside.png'
        external.write_bytes(self.image)
        target = self.root / self.path
        target.unlink()
        try:
            target.symlink_to(external)
        except OSError as exc:
            self.skipTest('Symlink creation unavailable: ' + str(exc))
        with self.assertRaises(pack.PackError):
            pack.validate_pack(self.root)
        with self.assertRaises(pack.PackError):
            pack.migrate_pack(self.root, self.base / 'output')

    def test_link_detection_without_os_symlink_privilege(self):
        # Exercise rejection independently of Windows Developer Mode privileges.
        original = Path.is_symlink
        for link in (self.root / 'meteor', self.root / self.path,
                     self.root / 'effects-manifest.json'):
            with self.subTest(link=link):
                with patch.object(Path, 'is_symlink', lambda path: path == link or original(path)):
                    with self.assertRaisesRegex(pack.PackError, 'Symlinks'):
                        pack.validate_pack(self.root)
                    with self.assertRaisesRegex(pack.PackError, 'Symlinks'):
                        pack.migrate_pack(self.root, self.base / 'output')

    def test_cli_help_validate_and_failure_status(self):
        script = str(Path(pack.__file__))
        for args in (['--help'], ['validate', str(self.root)]):
            result = subprocess.run([sys.executable, '-X', 'utf8', script, *args], capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
        (self.root / self.path).unlink()
        result = subprocess.run([sys.executable, '-X', 'utf8', script, 'validate', str(self.root)], capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Missing asset', result.stderr)


if __name__ == '__main__':
    unittest.main()
