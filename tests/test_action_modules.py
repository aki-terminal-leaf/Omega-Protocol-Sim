import importlib.util, json, pathlib, unittest, tempfile
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'tools/asset_lab/run_action_modules.py'); runner=importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)
class EvidenceTests(unittest.TestCase):
    def test_missing_evidence_rejected(self):
        for result in [{},{'failures':[]},{'failures':['source failure']}]:
            with self.assertRaises((ValueError,KeyError)): runner.validate_result(result,{'pairs':[]},{'units':{}})
    def test_registry_exact(self):
        registry=runner.read(ROOT/'docs/asset-lab/action-modules.json'); selections=runner.read(ROOT/'top/data/asset_lab/performances.json')
        self.assertEqual({r['id'] for r in registry['units']},set(selections['units']))
        self.assertEqual(len(registry['units']),96)
        for r in registry['units']:
            self.assertFalse(r['accepted']); self.assertEqual(r['selection'],selections['units'][r['id']])
    def test_missing_and_changed_registry_evidence_rejected(self):
        selections=runner.read(ROOT/'top/data/asset_lab/performances.json')
        rows=[{'identity':'unit:'+k,'selection':v} for k,v in selections['units'].items()]
        runner.validate_units(rows,selections)
        with self.assertRaises(ValueError): runner.validate_units(rows[:-1],selections)
        rows[0]={'identity':rows[0]['identity'],'selection':{'status':'PASS','accepted':True}}
        with self.assertRaises(ValueError): runner.validate_units(rows,selections)
class ResourceClosureTests(unittest.TestCase):
    def test_inheritance_shader_and_missing_dependency(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder); source=root/'top'; source.mkdir()
            (source/'child.gd').write_text('extends "res://base.gd"')
            (source/'base.gd').write_text('extends Node3D\nconst S = preload("res://effect.gdshader")')
            (source/'effect.gdshader').write_text('shader_type spatial;')
            with patch.object(runner, 'ROOT', root):
                copied=runner.stage_resources(root/'project', ['child.gd'])
                self.assertEqual(set(copied), {'child.gd','base.gd','effect.gdshader'})
                (source/'effect.gdshader').unlink()
                with self.assertRaisesRegex(ValueError, 'missing resource'):
                    runner.stage_resources(root/'missing', ['child.gd'])
if __name__=='__main__': unittest.main()
