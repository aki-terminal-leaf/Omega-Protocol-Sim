"""Dependency-closure tests: synthetic bytes, no installation or network."""
import json
from pathlib import Path
import tempfile
import unittest
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from avfx_resources import collect, virtual_path, ResourceTooLarge
from unittest.mock import patch
from test_avfx_graph import document

class ResourceTests(unittest.TestCase):
    def test_shared_texture_edges_deduplicate_without_basename_collisions(self):
        files = {'vfx/a.avfx': document(('Tex', b'vfx/a/mask.atex\0'), ('Tex', b'vfx/b/mask.atex\0')),
                 'vfx/b.avfx': document(('Tex', b'vfx/a/mask.atex\0')),
                 'vfx/a/mask.atex': b'A', 'vfx/b/mask.atex': b'B'}
        reads = []
        def read(path): reads.append(path); return files.get(path)
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'bundle'
            result = collect([{'path': p} for p in ['vfx/a.avfx', 'vfx/b.avfx']], read, out)
            self.assertEqual(len(reads), 4)
            self.assertEqual(len(result['edges']), 3)
            self.assertTrue(result['collection_complete'])
            self.assertEqual((out/'source/vfx/b/mask.atex').read_bytes(), b'B')
    def test_missing_candidate_upgraded_to_required_by_source_reference(self):
        with tempfile.TemporaryDirectory() as temp:
            result = collect([{'path': 'vfx/missing.atex', 'required': False}, {'path': 'vfx/a.avfx'}],
                             lambda p: document(('Tex', b'vfx/missing.atex\0')) if p.endswith('.avfx') else None,
                             Path(temp)/'bundle')
            self.assertFalse(result['collection_complete'])
            self.assertEqual(result['missing_required'], ['vfx/missing.atex'])
            self.assertEqual(result['missing_candidates'], [])
    def test_invalid_request_has_no_read_or_output_side_effect(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)/'bundle'
            for path in ['../secret.tex', 'vfx/../secret.tex', 'vfx//x.tex', 'vfx/X.tex', '/vfx/x.tex', 'vfx/x.exe']:
                with self.subTest(path=path), self.assertRaises(ValueError):
                    collect([{'path': 'vfx/a.avfx'}, {'path': path}], lambda p: self.fail('read'), out)
                self.assertFalse(out.exists())
    def test_byte_budget_keeps_failed_manifest_not_false_success(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)/'bundle'
            with self.assertRaisesRegex(ValueError, 'Total resource'):
                collect([{'path': 'vfx/a.atex'}], lambda p: b'12345', out, max_bytes=4)
            manifest = json.loads((out/'manifest.json').read_text())
            self.assertFalse(manifest['collection_complete'])
            self.assertEqual(manifest['resources'], [])
    def test_oversized_candidate_does_not_prevent_required_dependency_collection(self):
        with tempfile.TemporaryDirectory() as temp, patch('avfx_resources.mesh.MAX_BYTES', 4096):
            data = {'shader/sm5/shpk/bg.shpk': b'x' * 4097,
                    'vfx/a.avfx': document(('Tex', b'vfx/mask.atex\0')),
                    'vfx/mask.atex': b'123'}
            result = collect([{'path': 'shader/sm5/shpk/bg.shpk', 'required': False},
                              {'path': 'vfx/a.avfx'}], data.get, Path(temp)/'bundle', max_resource_bytes=4096)
            self.assertTrue(result['collection_complete'])
            self.assertEqual(len(result['resources']), 2)
            self.assertEqual(result['rejected_candidates'][0]['bytes'], 4097)

    def test_metadata_limit_stops_before_large_resource_read(self):
        def metadata_read(path): raise ResourceTooLarge(path, 90_101_224)
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)/'bundle'
            result = collect([{'path': 'shader/sm5/shpk/bg.shpk', 'required': False}], metadata_read, out)
            self.assertEqual(result['rejected_candidates'][0]['bytes'], 90_101_224)
            self.assertEqual(result['total_bytes'], 0)
            self.assertTrue(result['collection_complete'])
            with self.assertRaises(ResourceTooLarge):
                collect([{'path': 'shader/sm5/shpk/bg.shpk'}], metadata_read, Path(temp)/'required')

    def test_existing_proof_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(FileExistsError):
                collect([{'path': 'vfx/a.avfx'}], lambda p: self.fail('read'), Path(temp))
    def test_invalid_source_cannot_fall_back_to_regex_texture_matches(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError):
                collect([{'path': 'vfx/a.avfx'}], lambda p: b'vfx/mask.atex\0', Path(temp)/'bundle')
if __name__ == '__main__': unittest.main()
