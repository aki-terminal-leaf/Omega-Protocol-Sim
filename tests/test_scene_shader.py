import unittest,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/asset_lab'))
from prepare_scene_shader import rows,sample,validate,instruction_oracle
class SourceTests(unittest.TestCase):
 def test_pins(self):validate()
 def test_bad_buffers(self):
  for b in [[],[[0]*4]*4,[[0]*3]*5,[[float('nan')]*4]*5,[[True]*4]*5]:
   with self.assertRaises(ValueError):rows(b,5)
 def test_literal_ir_case(self):
  m=[[0]*4,[1,0,0,0],[0,1,0,2],[2,3,4,0.25],[2.5,-1.5,0,0]]
  i=[[0,-2,0,100],[3,0,0,20],[0,0,4,100],[0,-2,0,0],[3,0,0,0],[0,0,4,0],[0,0,0,1],[0.5,1,2,0],[0]*4,[0]*4]
  r=sample(m,i,[0,0,0.5],2,0.25,[1,2,3],[0,0,2],[0.2,0.7],0.5,[0.2,0.4,0.8],[0.5,0.25,1])
  self.assertEqual(r['world'],[96,23,112]);self.assertEqual(r['uv'],[0.2,0.7,69.5,-192.5])
  self.assertEqual(r['color'],[12.25,36.75,98]);self.assertEqual(r['rgba'],[1.225,3.6750000000000003,78.4,0])
 def test_translated_camera_and_world(self):
  # Independent affine reference: translating both camera and world preserves view.
  source=[107,29,113];camera=[110,40,150];offset=[100,0,100]
  relative=[a-b for a,b in zip(source,camera)]
  recentered=[(a-o)-(b-o) for a,b,o in zip(source,camera,offset)]
  self.assertEqual(relative,recentered)
  self.assertEqual(sum(a*b for a,b in zip([2,3,4],source)),753)
  self.assertNotEqual(sum(a*b for a,b in zip([2,3,4],[7,29,13])),753)
 def test_ir_nonidentity(self):
  m=[[0]*4,[1,0,0,0],[0,1,0,2],[2,3,4,0.25],[-2.5,1.5,0,0]]
  i=[[0,-2,0,100],[3,0,0,20],[0,0,4,100],[0,-2,0,0],[3,0,0,0],[0,0,4,0],[0,0,0,1],[0.5,1,2,0],[0]*4,[0]*4]
  ir=instruction_oracle(m,i,[0,0,0.5],2,0.25,[1,2,3],[0,0,2],[0.2,0.7],0.5)
  self.assertEqual(ir['uv'],[0.2,0.7,68.5,-191.5]);self.assertEqual(ir['color'],[12.25,36.75,98])
 def test_nonfinite(self):
  with self.assertRaises(ValueError):sample([[0]*4]*5,[[0]*4]*10,[0,0,1],1,math.inf,[0]*3,[0]*3,[0]*2,1,[1]*3,[1]*3)
if __name__=='__main__':unittest.main()
