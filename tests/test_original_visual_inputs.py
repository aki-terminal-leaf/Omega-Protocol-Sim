"""Behavioral malformed input, exact mapping and binary corruption checks."""
import copy, importlib.util, json, pathlib, struct, sys, tempfile, unittest, uuid
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/asset_lab'))
from preserve_original_visual_inputs import append_attribute,save_glb,read_glb,accessor,compare_rows,exact_parts,verify_identities,validate
class PreservationTests(unittest.TestCase):
 def test_missing_manifest(self):
  with self.assertRaises((ValueError,FileNotFoundError)):validate(ROOT/'absent-input.json','invalid')
 def test_ambiguous_part_rejected(self):
  d={'nodes':[{'mesh':0,'name':'m0110_g0_p0','skin':0}]*2,'meshes':[{'name':'m0110_g0_p0','primitives':[{}]}]}
  with self.assertRaisesRegex(ValueError,'duplicate'):exact_parts(d,110)
 def test_wrong_model_rejected(self):
  d={'nodes':[{'mesh':0,'name':'m0110_g0_p0','skin':0}],'meshes':[{'name':'m0110_g0_p0','primitives':[{}]}]}
  with self.assertRaises(ValueError):exact_parts(d,771)
 def test_color_roundtrip_and_corruption(self):
  d={'asset':{'version':'2.0'},'buffers':[{'byteLength':0}],'bufferViews':[],'accessors':[]};b=bytearray()
  rows=[(0,17,129,3),(255,1,72,254)];i=append_attribute(d,b,rows,'B','VEC4',True)
  # Independent known bytes, including nonopaque alpha; no implementation-generated expectation.
  self.assertEqual(bytes(b),bytes([0,17,129,3,255,1,72,254]))
  with self.subTest('private roundtrip'):
   tmp=ROOT/'top/assets/official/top-original-visual-inputs-50859/outputs'/('run-'+str(uuid.uuid4()));tmp.mkdir()
   p=pathlib.Path(tmp)/'test.glb';save_glb(p,d,b);rd,rb=read_glb(p.read_bytes())
   compare_rows([(0,17/255,129/255,3/255),(1,1/255,72/255,254/255)],accessor(rd,rb,i))
   corrupt=bytearray(rb);corrupt[3]=255
   with self.assertRaises(ValueError):compare_rows(accessor(rd,rb,i),accessor(rd,corrupt,i))
   malformed=p.read_bytes()[:-1]
   with self.assertRaises(ValueError):read_glb(malformed)
 def test_no_missing_or_nonfinite_vertices(self):
  for rows in [[],[(float('nan'),0)]]:
   with self.assertRaises(ValueError):append_attribute({'accessors':[],'bufferViews':[]},bytearray(),rows,'f','VEC2')
 def test_binding_identity_not_just_count(self):
  t={'path':'a.tex','sampler_id':1,'sha256':'a','bytes':5}
  m={'model':771,'parts':[{'group':0,'part':0,'vertices':1,'material':'a.mtrl'}],'materials':[{'path':'a.mtrl','sha256':'b','bytes':3,'textures':[t]}]}
  wrong=copy.deepcopy(m);wrong['materials'][0]['textures'][0]['sampler_id']=2
  with self.assertRaisesRegex(ValueError,'binding identities'):verify_identities([wrong],[m])
if __name__=='__main__':unittest.main()
