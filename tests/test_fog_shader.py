import sys,unittest,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/asset_lab'))
import prepare_fog_shader as f
def factored_ps(c,world,sv,depth,sky,lut):
 m=c['material_cb'];fog=c['fog_cb'];camera=c['camera_cb'];param=c['parameter_cb'];common=c['common_cb']
 sat=lambda x:max(0,min(1,x))
 dot=lambda a,b:sum(x*y for x,y in zip(a,b))
 density=2**(-max(fog[4][3],0.0001)*(world[1]-fog[4][2])*0.5459683537483215)*fog[4][1]+2**(-max(fog[4][0],0.0001)*(world[1]-fog[3][3])*0.5459683537483215)*fog[3][2]
 ray=[world[k]-fog[7][k] for k in range(3)];distance=math.sqrt(dot(ray,ray));direction=[v/distance for v in ray]
 travel=distance-max(fog[3][0],0)
 angle=sat((fog[9][0]-direction[1])*fog[9][1])*fog[9][2]
 opacity=sat((1-max(min(2**(-travel*density),1),fog[3][1]))*fog[5][3])
 directional_opacity=1-min(2**(-max(travel-fog[5][0],0)*density),1)
 atmosphere=direction[1]*1.075-0.075
 atmosphere=1-2**((-atmosphere*12740000+math.sqrt((atmosphere*12740000)**2+407936008192))*-0.000010)
 cosine=dot(direction,fog[8][:3]);phase=atmosphere*(cosine*cosine+1)
 sunlight=sat(cosine)**max(fog[5][2],1)*fog[6][3]**2
 height_rgb=[max(0,fog[0][k]+phase*0.05968310311436653+sunlight*fog[6][k]*directional_opacity) for k in range(3)]
 lookup=lut([fog[2][2]-fog[2][3]*dot(camera[2],world+[1]),0.5])
 screen=[sv[k]*common[0][k]+common[0][k+2] for k in range(2)]
 sky_value=sky(screen);depth_value=max(depth(screen)[0],1.0000000116860974e-07)
 sky_rgb=[max(0,(sky_value[k]-fog[0][k])*lookup[1]+fog[0][k])*(1-angle) for k in range(3)]
 env=[sky_rgb[k]+opacity*(height_rgb[k]-sky_rgb[k]) for k in range(3)]
 reconstruction=[sv[k]*common[1][k]+common[1][k+2] for k in range(2)]+[depth_value,1]
 reconstructed_y=dot(camera[11],reconstruction)/dot(camera[13],reconstruction)
 sign=(m[3][1]>0)-(m[3][1]<0)
 thickness=max(0,(world[1]-reconstructed_y)*sign*param[1][3]*abs(m[3][1]))
 weight=1/(1+m[3][2]*thickness)
 base=[m[0][k]*(param[2][k]+weight*(param[1][k]-param[2][k])) for k in range(3)]
 return [base[k]+max(opacity,lookup[0])*(env[k]-base[k]) for k in range(3)]+[min(thickness,m[0][3])]

class FogTests(unittest.TestCase):
 def test_pins_and_literal_shader(self):
  self.assertEqual(len(f.validate()['protected_sources']),55)
  self.assertEqual((f.ROOT/'top/materials/original_verticalfog.gdshader').read_text(encoding='utf-8-sig'),f.shader())
  self.assertEqual(len(f.instructions('vs')),29);self.assertEqual(len(f.instructions('ps')),96)
 def test_exact_dxbc_protective_literals(self):
  self.assertIn('9.99999993922529e-09',f.instructions('ps')[14]['operands'])
  self.assertIn('1.0000000116860974e-07',f.instructions('ps')[66]['operands'])
  self.assertIn('0.5459683537483215',f.instructions('ps')[3]['operands'])
 def test_uninitialized_rejected(self):
  with self.assertRaises(KeyError):f.oracle('vs',{'v0':[1,2,3,None]})
 def test_signed_ties_translation(self):
  self.assertEqual([round(x) for x in [-3.5,-2.5,-1.5,-0.5,0.5,1.5,2.5,3.5]],[-4,-2,-2,0,0,2,2,4])
  self.assertIn('mod(abs(f),2.0)',f.shader());self.assertNotIn('TIME',f.shader())
 def test_source_all_vertices(self):
  import json
  runs=sorted(f.OUTPUT.glob('run-*/scene.json'),key=lambda p:p.stat().st_mtime)
  self.assertTrue(runs);s=json.loads(runs[-1].read_bytes());c=s['fixture'];self.assertEqual(c['instance_cb'][0][:3],[100,-325.1846923828125,100])
  for clock in [-0.002,0,0.003]:
   c['parameter_cb'][0][3]=clock
   for surface in s['surfaces']:
    for p in surface['position']:
     r={'v0':p+[None]}
     for i,key in enumerate(['material_cb','camera_cb','parameter_cb','instance_cb']):
      for j,row in enumerate(c[key]):r[f'cb{i}[{j}]']=row
     out=f.oracle('vs',r);world=[p[k]+c['instance_cb'][0][k] for k in range(3)]
     self.assertEqual(out['o2'],world+[1]);self.assertAlmostEqual(out['o1'][3],math.hypot(p[0],p[2]))
     # Independently factored VS formula, including signed ties-even time scroll.
     m=c['material_cb'];eye=c['parameter_cb'][0];dy=world[1]-eye[1];sign=(m[3][1]<0)-(m[3][1]>0);scale=m[4][0]/max(0.0010000000474974513,sign*dy)
     for lane,axis,mi in [(0,0,0),(2,2,1)]:self.assertAlmostEqual(out['o1'][lane],m[4][2]*(world[axis]+scale*(world[axis]-eye[axis]))-round(m[2][mi])*clock,places=7)
     ps={'v0':c['native_sv_position'],'v1':out['o1'],'v2':out['o2']}
     for i,key in enumerate(['material_cb','common_cb','camera_cb','fog_cb','parameter_cb']):
      for j,row in enumerate(c[key]):ps[f'cb{i}[{j}]']=row
     rgba=f.oracle('ps',ps,{f't{i}':lambda uv:[0.3,0.4,0.5,1] for i in range(3)})['o0']
     self.assertTrue(all(math.isfinite(x) for x in rgba));self.assertGreaterEqual(rgba[3],0)
     expected=factored_ps(c,world,c['native_sv_position'],lambda uv:[0.3,0.4,0.5,1],lambda uv:[0.3,0.4,0.5,1],lambda uv:[0.3,0.4,0.5,1])
     for a,b in zip(rgba,expected):self.assertAlmostEqual(a,b,places=7)
 def test_ps_environment_lookup_and_signed_density(self):
  import json,copy
  material=next(v for v in json.loads((f.INPUTS/'package-mapping.json').read_bytes())['materials'] if 'vfg' in v['path'])['material_float4s']
  samplers={'t0':lambda uv:[0.1+uv[0]*0.3,0.8,0.7,0.6],'t1':lambda uv:[0.2+uv[0]*0.1,0.4+uv[1]*0.2,0.6,1],'t2':lambda uv:[max(0,min(1,uv[0])),0.25+uv[1]*0.5,0.3,0.8]}
  for sign in [-1,0,1]:
   for height in [-340,-325,-290]:
    for opacity in [0,0.4,1]:
     c=f.fixture(copy.deepcopy(material));c['material_cb'][3][1]*=sign;c['fog_cb'][5][3]=opacity
     c['camera_cb'][11]=[0.1,0.2,2,-330];c['camera_cb'][13]=[0,0,0.1,1]
     world=[108,height,95];sv=[123,321,0.4,1];r={'v0':sv,'v1':[None,height,None,None],'v2':world+[None]}
     for i,key in enumerate(['material_cb','common_cb','camera_cb','fog_cb','parameter_cb']):
      for j,row in enumerate(c[key]):r[f'cb{i}[{j}]']=row
     actual=f.oracle('ps',r,samplers)['o0'];expected=factored_ps(c,world,sv,samplers['t0'],samplers['t1'],samplers['t2'])
     for a,b in zip(actual,expected):self.assertAlmostEqual(a,b,places=7)
 def test_nontrivial_vs_ties_and_translation(self):
  import json
  m=next(v for v in json.loads((f.INPUTS/'package-mapping.json').read_bytes())['materials'] if 'vfg' in v['path'])['material_float4s']
  for direction in [-0.01,0,0.01]:
   for speed in [-3.5,-2.5,-0.5,0.5,1.5,2.5]:
    c=f.fixture(m);c['material_cb'][3][1]=direction;c['material_cb'][4][0]=10;c['material_cb'][2][:2]=[speed,-speed];c['parameter_cb'][0][3]=-0.013
    r={'v0':[3,5,-7,None]}
    for i,key in enumerate(['material_cb','camera_cb','parameter_cb','instance_cb']):
     for j,row in enumerate(c[key]):r[f'cb{i}[{j}]']=row
    o=f.oracle('vs',r);w=o['o2'];eye=c['parameter_cb'][0];scale=10/max(0.0010000000474974513,((direction<0)-(direction>0))*(w[1]-eye[1]))
    for lane,axis,rate in [(0,0,speed),(2,2,-speed)]:self.assertAlmostEqual(o['o1'][lane],m[4][2]*(w[axis]+scale*(w[axis]-eye[axis]))-round(rate)*eye[3],places=7)
if __name__=='__main__':unittest.main()
