"""Pure malformed-input regression tests; no model/runtime loads."""
import copy, importlib.util, pathlib, struct, unittest
spec=importlib.util.spec_from_file_location('prepare',pathlib.Path(__file__).resolve().parents[1]/'tools/asset_lab/prepare_cinematic_godot.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
def fixture():
 row=[0,0,0,0,1,2,3,0,0,0,0,1]
 return {'layout':'Translation4 Scale4 Rotation4','pose_space':'model (upstream convention)','names':['root','child'],'parents':[-1,0],'bone_count':2,'reference_local':[row[:],row[:]],'clips':[{'index':7,'name':'a','bone_count':2,'duration':1.0,'times':[0.,1.],'native_query_times':[0.,1.],'frames':[[row[:],row[:]],[row[:],row[:]]]}]}
class Validation(unittest.TestCase):
 def test_non_offset_clip_index_and_nonuniform_scale(self): self.assertEqual(p.validate_sample(fixture())['clips'][0]['index'],7)
 def test_schema(self):
  s=fixture();s['layout']='TRS';self.assertRaises(ValueError,p.validate_sample,s)
 def test_cycle(self):
  s=fixture();s['parents']=[1,0];self.assertRaises(ValueError,p.validate_sample,s)
 def test_parent_outside(self):
  s=fixture();s['parents']=[-1,2];self.assertRaises(ValueError,p.validate_sample,s)
 def test_duplicate_names(self):
  s=fixture();s['names']=['root','root'];self.assertRaises(ValueError,p.validate_sample,s)
 def test_dimension(self):
  s=fixture();s['clips'][0]['frames'][1][0].pop();self.assertRaises(ValueError,p.validate_sample,s)
 def test_nan_padding_rejected(self):
  s=fixture();s['reference_local'][0][3]=float('nan');self.assertRaises(ValueError,p.validate_sample,s)
 def test_zero_quaternion(self):
  s=fixture();s['reference_local'][0][11]=0;self.assertRaises(ValueError,p.validate_sample,s)
 def test_float32_endpoint_collision(self):
  s=fixture();c=s['clips'][0];c['times']=[0.,1.-1e-9,1.];c['native_query_times']=[0.,1.,1.];c['frames'].append(copy.deepcopy(c['frames'][0]));self.assertRaises(ValueError,p.validate_sample,s)
 def test_float32_query_mismatch(self):
  s=fixture();s['clips'][0]['native_query_times'][1]=.9;self.assertRaises(ValueError,p.validate_sample,s)
 def test_duplicate_clip_id(self):
  s=fixture();s['clips'].append(copy.deepcopy(s['clips'][0]));self.assertRaises(ValueError,p.validate_sample,s)
 def test_wrong_manifest_digest_rejected_before_parsing(self):
  self.assertRaises(ValueError,p.validate_manifest,__file__,'0'*64)
if __name__=='__main__': unittest.main()
