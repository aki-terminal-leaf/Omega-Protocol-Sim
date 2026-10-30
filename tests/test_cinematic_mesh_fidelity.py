"""Pure corruption counterexamples; no native/model execution."""
import importlib.util
import json
from pathlib import Path
import struct
import unittest

spec=importlib.util.spec_from_file_location('audit',Path(__file__).resolve().parents[1]/'tools/asset_lab/audit_cinematic_mesh_fidelity.py')
a=importlib.util.module_from_spec(spec); spec.loader.exec_module(a)

class FidelityTests(unittest.TestCase):
    def test_positive_joint_corruption(self):
        with self.assertRaisesRegex(ValueError,'joint identity'):
            a.compare_weights([0]*8,[255]+[0]*7,['hip'],['hip','head'],[1]+[0]*7,[1]+[0]*7)

    def test_normalized_but_changed_weights(self):
        with self.assertRaises(ValueError):
            a.compare_weights([0,1]+[0]*6,[128,127]+[0]*6,['a','b'],['a','b'],[0,1]+[0]*6,[.25,.75]+[0]*6)

    def test_source_zero_not_synthetic_success(self):
        r=a.compare_weights([0]*8,[0]*8,['root'],['root'],[0]*8,[1]+[0]*7)
        self.assertEqual(r['status'],'BLOCKED'); self.assertTrue(r['zero'])

    def test_position_index_and_omission(self):
        for source,actual in [([(1,2,3)],[(1,2,4)]), ([(0,),(1,),(2,)],[(0,),(2,),(1,)]), ([(1,2,3)],[])]:
            with self.assertRaises(ValueError): a.compare_rows(source,actual)

    def test_stride_offset_normalization_and_overrun(self):
        d={'bufferViews':[{'buffer':0,'byteOffset':4,'byteLength':8,'byteStride':4}], 'accessors':[{'bufferView':0,'componentType':5121,'count':2,'type':'VEC2','normalized':True,'byteOffset':1}]}
        b=b'xxxx'+bytes([9,0,255,9,9,255,0,9])
        self.assertEqual(a.accessor(d,b,0),[(0,1),(1,0)])
        d['accessors'][0]['count']=3
        with self.assertRaises(ValueError): a.accessor(d,b,0)

    def test_chunk_truncation_and_false_length(self):
        j=json.dumps({'buffers':[{'byteLength':4}]}).encode(); j+=b' '*(-len(j)%4)
        body=struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',4,0x004e4942)+b'1234'
        valid=struct.pack('<III',0x46546c67,2,len(body)+12)+body
        self.assertEqual(a.read_glb(valid)[1],b'1234')
        for bad in [valid[:-1],valid+b'junk',valid[:12]+struct.pack('<I',len(j)+100)+valid[16:]]:
            with self.assertRaises(ValueError): a.read_glb(bad)

    def test_nonfinite_and_sparse_fail_closed(self):
        with self.assertRaises(ValueError): a.compare_rows([(float('nan'),)],[(0,)])
        with self.assertRaises(ValueError): a.accessor({'accessors':[{'sparse':{}}]},b'',0)

class AggregationTests(unittest.TestCase):
    def run_aggregation(self, result, receipt_ok=True, write_result=True):
        import tempfile, types, sys
        from unittest import mock
        with tempfile.TemporaryDirectory() as tmp:
            manifest=Path(tmp)/'inputs.json';manifest.write_text('{}')
            fake=types.ModuleType('run_cinematic_integration')
            def run(out,label,argv,*unused):
                modelout=out/label;modelout.mkdir()
                if write_result:(modelout/'result.json').write_text(json.dumps(result))
                return {'ok':receipt_ok}
            fake.run=run
            m={'seed_pins':{},'inputs':{},'runtime_pins':{},'paths':{'python':sys.executable},'pairs':[{'model':110}]}
            with mock.patch.object(a,'os',types.SimpleNamespace(name='nt')), mock.patch.object(a,'validate_manifest',return_value=m), mock.patch.dict(sys.modules,{'run_cinematic_integration':fake}), mock.patch.object(sys,'argv',['audit','--manifest',str(manifest),'--manifest-sha256',a.EXPECTED]):
                code=a.main()
            summary=json.loads(next(Path(tmp).glob('outputs/*/summary.json')).read_text())
            return code,summary

    def good(self):
        return {'model':110,'status':'DECODED_MESH_PASS_SHADER_OPEN','zero_counterexamples':[],'weight_counts':{'zero':0,'outofrange':0,'missingbone':0,'not255':0,'duplicates':0}}

    def test_zero_weights_propagate_despite_guard_exit_zero(self):
        result=self.good();result.update(status='WEIGHTS_BLOCKED',zero_counterexamples=[{'vertex':0}]);result['weight_counts']['zero']=1
        code,summary=self.run_aggregation(result)
        self.assertEqual(code,1);self.assertEqual(summary['status'],'BLOCKED');self.assertIn('110',summary['blocker'])
        self.assertEqual(summary['models'][0],result)

    def test_missing_status_and_false_pass_counters_fail_closed(self):
        for change in ['missing_status','missingbone','outofrange','zero']:
            result=self.good()
            if change=='missing_status':del result['status']
            else:result['weight_counts'][change]=1
            code,summary=self.run_aggregation(result)
            self.assertEqual(code,1);self.assertEqual(summary['status'],'BLOCKED')

    def test_valid_source_keeps_shader_and_visual_open(self):
        code,summary=self.run_aggregation(self.good())
        self.assertEqual(code,0);self.assertEqual(summary['status'],'SOURCE_AUDIT_COMPLETE_VISUAL_OPEN')
        self.assertFalse(summary['all96_accepted']);self.assertFalse(summary['visual_acceptance'])
        self.assertEqual(summary['shader_reconstruction'],'OPEN')

    def test_real_nonzero_child_retains_blocked_result(self):
        result=self.good();result['status']='WEIGHTS_BLOCKED';result['zero_counterexamples']=[{'vertex':7}];result['weight_counts']['zero']=1
        code,summary=self.run_aggregation(result,receipt_ok=False)
        self.assertEqual(code,1);self.assertEqual(summary['status'],'BLOCKED');self.assertEqual(summary['models'],[result])
        self.assertIn('WEIGHTS_BLOCKED',summary['blocker']);self.assertIn('110',summary['blocker']);self.assertIn('zero',summary['blocker'])

    def test_failed_receipt_never_promoted_by_passing_json(self):
        code,summary=self.run_aggregation(self.good(),receipt_ok=False)
        self.assertEqual(code,1);self.assertEqual(summary['status'],'BLOCKED');self.assertEqual(summary['models'],[self.good()])
        self.assertIn('m0110',summary['blocker'])

    def test_missing_result_is_blocked_for_both_receipts(self):
        for ok in (True,False):
            code,summary=self.run_aggregation(self.good(),receipt_ok=ok,write_result=False)
            self.assertEqual(code,1);self.assertEqual(summary['status'],'BLOCKED');self.assertEqual(summary['models'],[])
            self.assertIn('m0110',summary['blocker'])

if __name__=='__main__': unittest.main()
