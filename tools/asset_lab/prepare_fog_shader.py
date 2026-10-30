"""Conditional verticalfog VS0/PS0: pinned literal translation and private source decode."""
import argparse, hashlib, importlib.util, json, math, re, sys, struct
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[2]
INPUTS=Path('D:/Dev/OpenClawCodexBridge/probes/top-fog-shader-50879/inputs')
EXPECTED='0779ec4e7741b2ca2e185ccb09e082667367385a469617bfb8e4835446c5129d'
OUTPUT=ROOT/'top/assets/official/top-fog-shader-50879/outputs'
from prepare_scene_shader import RUNTIME, sha, save, rows

def validate():
 if sha(INPUTS/'inputs.json')!=EXPECTED:raise ValueError('manifest hash')
 m=json.loads((INPUTS/'inputs.json').read_bytes())
 for group,base in [('files',INPUTS),('protected_sources',ROOT)]:
  for n,p in m[group].items():
   if sha(base/n)!=p['sha256'] or (base/n).stat().st_size!=p['bytes']:raise ValueError('pin '+n)
 return m

# Exact immediate32 operands recovered from SHA-pinned original DXBC, not rounded ASM.
# VS0: 5426647a8594650dc463f6a62744fc3c6ef42033396fcd5d10179c069b90b2e9
# PS0: ad0b7a4bc6bbf8e18a826626a42c00558b290782c1fd3bb97998bad585e49b6a
LITERAL_BITS = {('vs', 0): {1: [1065353216]}, ('vs', 7): {1: [0]}, ('vs', 8): {2: [0]}, ('vs', 13): {2: [981668463]}, ('vs', 16): {2: [1065353216]}, ('vs', 18): {2: [1065353216]}, ('vs', 24): {2: [1056964608]}, ('ps', 1): {2: [0, 953267991, 953267991, 0]}, ('ps', 3): {2: [1057735829]}, ('ps', 8): {2: [1057735829]}, ('ps', 11): {2: [0]}, ('ps', 14): {2: [841731191]}, ('ps', 16): {3: [1065353216]}, ('ps', 27): {2: [1065353216]}, ('ps', 29): {2: [1065353216]}, ('ps', 31): {2: [0]}, ('ps', 34): {2: [1065353216]}, ('ps', 35): {2: [1065982362], 3: [3180960154]}, ('ps', 36): {2: [1262642592]}, ('ps', 37): {3: [1388180931]}, ('ps', 39): {2: [1262642592]}, ('ps', 40): {2: [3072837036]}, ('ps', 42): {2: [1065353216, 0, 0, 1065353216]}, ('ps', 46): {3: [1065353216]}, ('ps', 48): {2: [0, 1031042629, 1031042629, 1031042629]}, ('ps', 49): {2: [1065353216]}, ('ps', 56): {2: [0, 0, 0, 0]}, ('ps', 58): {1: [1065353216]}, ('ps', 61): {1: [0, 1056964608, 0, 1065353216]}, ('ps', 62): {4: [0]}, ('ps', 64): {4: [0]}, ('ps', 66): {2: [869711765]}, ('ps', 70): {2: [0, 0, 0, 0]}, ('ps', 79): {1: [0]}, ('ps', 80): {2: [0]}, ('ps', 86): {2: [0]}, ('ps', 87): {3: [1065353216]}, ('ps', 89): {1: [1065353216, 1065353216, 1065353216, 1065353216]}}
def instructions(stage):
 rows=json.loads((INPUTS/'shader-instruction-ir.json').read_bytes())['programs']['verticalfog-'+stage+'-0']['instructions']
 for index,row in enumerate(rows):
  operands=args(row['operands'])
  for lane,raw in LITERAL_BITS.get((stage,index),{}).items():
   if not operands[lane].startswith('l('):raise ValueError('DXBC literal operand join')
   operands[lane]='l('+','.join(repr(struct.unpack('<f',struct.pack('<I',x))[0]) for x in raw)+')'
  row['operands']=', '.join(operands)
 return rows

def args(s):return re.split(r',\s*(?![^()]*\))',s)

def emit(stage):
 mapping={'vs':['material_cb','camera_cb','parameter_cb','instance_cb'],'ps':['material_cb','common_cb','camera_cb','fog_cb','parameter_cb']}[stage]
 def val(s,k):
  if s.startswith('-'):return '(-'+val(s[1:],k)+')'
  if s.startswith('|'):return 'abs('+val(s[1:-1],k)+')'
  if s.startswith('l('):
   a=s[2:-1].split(',');return repr(float(a[0 if len(a)==1 else k]))
  name,_,sw=s.partition('.');sw=sw or 'xyzw';c=sw[0 if len(sw)==1 else k]
  if name.startswith('cb'):
   j=int(name[2:name.index('[')]);name=mapping[j]+name[name.index('['):]
  return name+'.'+c
 lines=['vec4 r0; vec4 r1; vec4 r2; vec4 r3; vec4 o0; vec4 o1; vec4 o2; vec4 tmp;']
 for idx,ins in enumerate(instructions(stage)):
  op=ins['op'];a=args(ins['operands'])
  if op=='ret':continue
  d,_,mask=a[0].partition('.');mask=mask or 'xyzw';src=a[1:];base=op.removesuffix('_sat');lines.append('// %d %s %s'%(idx,op,ins['operands']))
  for c in mask:
   k='xyzw'.index(c);v=[val(s,k) for s in src if not s.startswith(('t','s'))];e=''
   if base in ('mov','itof'):e=v[0]
   elif base in ('add','iadd'):e='('+v[0]+' + '+v[1]+')'
   elif base=='mul':e='('+v[0]+' * '+v[1]+')'
   elif base=='mad':e='('+v[0]+' * '+v[1]+' + '+v[2]+')'
   elif base in ('min','max'):e=base+'('+','.join(v)+')'
   elif base=='div':e='native_div('+','.join(v)+')'
   elif base=='lt':e='(('+v[0]+' < '+v[1]+') ? -1.0 : 0.0)'
   elif base=='movc':e='(('+v[0]+' != 0.0) ? '+v[1]+' : '+v[2]+')'
   elif base in ('exp','log','sqrt','rsq','round_ne'):e={'exp':'exp2','log':'log2','sqrt':'sqrt','rsq':'native_rsq','round_ne':'ties_even'}[base]+'('+v[0]+')'
   elif base.startswith('dp'):e='('+' + '.join('('+val(src[0],j)+' * '+val(src[1],j)+')' for j in range(int(base[-1])))+')'
   elif base.startswith('sample'):
    tex=src[1];name,_,sw=tex.partition('.');sw=sw or 'xyzw';e='textureLod(sampler'+name[1:]+', vec2('+val(src[0],0)+','+val(src[0],1)+'), 0.0).'+sw[k]
   else:raise ValueError(op)
   if op.endswith('_sat'):e='clamp('+e+',0.0,1.0)'
   lines.append('tmp.'+c+' = '+e+';')
  lines.append(d+'.'+mask+' = tmp.'+mask+';')
 return '\n'.join(lines)

def shader():
 return '''shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Conditional AddLayer0 0x5D82881C, Color, VS0/PS0. NOT live guard/index evidence.
uniform vec4 material_cb[5];
uniform vec4 camera_cb[59];
uniform vec4 parameter_cb[3];
uniform vec4 instance_cb[1];
uniform vec4 common_cb[4];
uniform vec4 fog_cb[10];
uniform float source_clock;
uniform vec3 render_origin;
uniform vec4 native_sv_position;
uniform float inspection_exposure;
uniform sampler2D sampler0 : filter_linear, repeat_disable;
uniform sampler2D sampler1 : filter_linear, repeat_disable;
uniform sampler2D sampler2 : filter_linear, repeat_disable;
varying vec4 source_texcoord1;
varying vec4 source_world;
varying vec4 source_clip;
float ties_even(float x) { float f=floor(x); float t=x-f; return t<0.5 ? f : (t>0.5 ? f+1.0 : (mod(abs(f),2.0)==0.0 ? f : f+1.0)); }
// Undefined-domain safety policy only; not an assertion of native NaN/Inf behavior.
float native_div(float a,float b) { return b==0.0 ? 0.0 : a/b; }
float native_rsq(float a) { return a<=0.0 ? 0.0 : inversesqrt(a); }
void vertex() {
vec4 v0=vec4(VERTEX,1.0);
'''+emit('vs').replace('parameter_cb[0].w','source_clock')+'''
source_texcoord1=o1; source_world=o2; source_clip=o0;
// Chosen Godot camera projection, separate from retained native clip equations.
VERTEX=o2.xyz-render_origin;
}
void fragment() {
vec4 v0=native_sv_position; vec4 v1=source_texcoord1; vec4 v2=source_world;
'''+emit('ps')+'''
ALBEDO=o0.rgb*inspection_exposure; ALPHA=o0.a;
}
'''

def oracle(stage,registers,samplers=None):
 """Literal interpreter: undefined register lanes raise, never default to zero."""
 r={k:list(v) for k,v in registers.items()}
 def value(s,k):
  if s.startswith('-'):return -value(s[1:],k)
  if s.startswith('|'):return abs(value(s[1:-1],k))
  if s.startswith('l('):
   a=[float(x) for x in s[2:-1].split(',')];return a[0 if len(a)==1 else k]
  n,_,sw=s.partition('.');sw=sw or 'xyzw';v=r[n]['xyzw'.index(sw[0 if len(sw)==1 else k])]
  if v is None:raise ValueError('uninitialized '+s)
  return v
 for ins in instructions(stage):
  op=ins['op'];base=op.removesuffix('_sat')
  if op=='ret':break
  a=args(ins['operands']);n,_,mask=a[0].partition('.');mask=mask or 'xyzw';updates={}
  for c in mask:
   k='xyzw'.index(c)
   if base.startswith('sample'):
    tex,_,sw=a[2].partition('.');sw=sw or 'xyzw';z=samplers[tex]([value(a[1],0),value(a[1],1)])['xyzw'.index(sw[k])]
   elif base.startswith('dp'):z=sum(value(a[1],j)*value(a[2],j) for j in range(int(base[-1])))
   else:
    v=[value(s,k) for s in a[1:]]
    if base in ('mov','itof'):z=v[0]
    elif base in ('add','iadd'):z=v[0]+v[1]
    elif base=='mul':z=v[0]*v[1]
    elif base=='mad':z=v[0]*v[1]+v[2]
    elif base=='div':
     if v[1]==0:raise ValueError('undefined div')
     z=v[0]/v[1]
    elif base=='lt':z=-1 if v[0]<v[1] else 0
    elif base=='movc':z=v[1] if v[0]!=0 else v[2]
    elif base=='min':z=min(v)
    elif base=='max':z=max(v)
    elif base=='exp':z=2**v[0]
    elif base=='log':z=math.log2(v[0]) if v[0]>0 else -math.inf
    elif base=='sqrt':z=math.sqrt(v[0])
    elif base=='rsq':
     if v[0]<=0:raise ValueError('undefined rsq')
     z=1/math.sqrt(v[0])
    elif base=='round_ne':z=round(v[0])
    else:raise ValueError(op)
   if op.endswith('_sat'):z=max(0,min(1,z))
   updates[k]=z
  r.setdefault(n,[None]*4)
  for k,z in updates.items():r[n][k]=z
 return {k:v for k,v in r.items() if k.startswith('o')}

def fixture(m):
 camera=[[0.0]*4 for _ in range(59)]
 for j in range(4):camera[6+j][j]=1.0
 camera[2]=[0,0,1,0];camera[11]=[0,0,0,-350];camera[13]=[0,0,0,1]
 return dict(material_cb=m,camera_cb=camera,parameter_cb=[[100,-300,100,0],[1,0.9,0.8,1],[0.4,0.5,0.7,0]],instance_cb=[[100,-325.1846923828125,100,0]],common_cb=[[1/640,1/480,0,0],[2/640,2/480,-1,-1],[0,0,0,0],[1,0,0,0]],fog_cb=[[0.12,0.18,0.25,0],[0,0,0,0],[0,0,0.5,0.001],[0,0.1,0.002,-325],[0.001,0.001,-330,0.001],[0,0,2,1],[0.4,0.5,0.6,0.3],[100,-280,200,0],[0,1,0,0],[0.5,1,0.2,0]],source_clock=0.0,render_origin=[100,-325.1846923828125,100],native_sv_position=[320,240,0.5,1],inspection_exposure=1.0,provenance='INSPECTION_FIXTURE',branch='CONDITIONAL_AddLayer0_VS0_PS0',sampler_provenance='INSPECTION_FIXTURE procedural native-depth/sky/LUT; not original environmental assets')

def decode(out):
 from audit_cinematic_mesh_fidelity import metadata
 validate();cfg=json.loads(RUNTIME.read_bytes());paths=cfg['paths']
 if sha(RUNTIME)!='52d925afa2ad82f1e00323a851896980c6da371b1bf457cb6c6d5d696064c20e':raise ValueError('runtime manifest')
 for n,pin in cfg['runtime_pins'].items():
  if sha(ROOT/n)!=pin['sha256']:raise ValueError('runtime pin '+n)
 helper=RUNTIME.parent/'references/official_export_helpers.py'
 if sha(helper)!=cfg['inputs']['references/official_export_helpers.py']['sha256']:raise ValueError('initializer pin')
 sys.path[:0]=[paths['pythonnet_dir'],paths['pillow_dir']]
 spec=importlib.util.spec_from_file_location('source_initializer',helper);h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
 realm=h.initialize(SimpleNamespace(**{k:Path(v) for k,v in paths.items()},output=out))
 from Lumina.Data import FileResource
 from xivModdingFramework.Models.FileTypes import Mdl
 from xivModdingFramework.Materials.FileTypes import Mtrl
 from PIL import Image
 mapping=json.loads((INPUTS/'package-mapping.json').read_bytes());result={'pins':{},'surfaces':[]}
 def raw(path,name):
  f=realm.GetFile[FileResource](path)
  if f is None:raise ValueError('missing '+path)
  b=bytes(f.Data);(out/name).write_bytes(b);result['pins'][path]={'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'file':name};return f
 try:
  sp='shader/sm5/shpk/verticalfog.shpk';raw(sp,'verticalfog.shpk')
  assert result['pins'][sp]['sha256']==mapping['packages'][sp]['source_sha256']
  path='bg/ex2/05_zon_z3/ome/z3oe/bgparts/z3oe_a1_vfg01.mdl';f=raw(path,'fog.mdl');mdl=Mdl.GetXivMdl(f.Data,path);tt=Mdl.GetTTModel(f.Data,path).GetAwaiter().GetResult()
  mp='bg/ex2/05_zon_z3/ome/z3oe/material/z3oe_a1_vfg01a.mtrl';mat=Mtrl.GetXivMtrl(raw(mp,'fog.mtrl').Data,mp);mm=next(v for v in mapping['materials'] if v['path']==mp)
  assert {int(c.ConstantId):[float(x) for x in c.Values] for c in mat.ShaderConstants}=={c['id']:c['values'] for c in mm['constants'] if c['value_origin']=='MTRL'}
  assert str(mat.ShaderPackRaw)=='verticalfog.shpk'
  assert result['pins'][path]['sha256']=='8ad22a117c9630ce300008c7fb5134e24d55c759ed3cc3b6632d65f64c8b8bfc'
  assert result['pins'][mp]['sha256']=='30e81f756851800a4951547bd8a83d5112658cb1de1ebae141cead346daa076c'
  result.update(material=mm,material_metadata=metadata(mat),fixture=fixture(mm['material_float4s']),source_path=path,source_y=-325.1846923828125,source_xz=100,clock={'duration':10,'epoch':0,'rate':0.001,'provenance':'INSPECTION_FIXTURE; native unit/epoch unknown'})
  for gi,mesh in enumerate(mdl.LoDList[0].MeshDataList):
   actual=str(tt.MeshGroups[gi].Material)
   assert actual.lstrip('/') in (mp,'z3oe_a1_vfg01a.mtrl'),actual
   pos=[[float(getattr(v,a)) for a in 'XYZ'] for v in mesh.VertexData.Positions];indices=[int(v) for v in mesh.VertexData.Indices]
   assert pos and indices and len(indices)%3==0 and all(0<=i<len(pos) for i in indices) and all(math.isfinite(x) for v in pos for x in v)
   result['surfaces'].append(dict(position=pos,indices=indices,declaration=metadata(mesh.VertexDataStructList),mesh_info=metadata(mesh.MeshInfo)))
  result['fixture_textures']=[]
  for j in range(3):
   im=Image.new('RGBA',(16,16));im.putdata([(int(255*(0.2+0.6*x/15)),int(255*(0.1+0.5*y/15)),int(255*(0.15+0.3*j)),255) for y in range(16) for x in range(16)])
   name=f'fixture-{j}.png.bin';im.save(out/name,format='PNG');result['fixture_textures'].append(dict(file=name,sha256=sha(out/name),provenance='INSPECTION_FIXTURE procedural, NOT original'))
  save(out/'scene.json',result);validate()
 finally:realm.Dispose()

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path);p.add_argument('--emit-shader',action='store_true');a=p.parse_args();validate()
 if a.emit_shader:(ROOT/'top/materials/original_verticalfog.gdshader').write_text(shader(),encoding='utf-8')
 else:
  out=a.output.resolve()
  if not out.is_relative_to(OUTPUT) or not out.name.startswith('run-'):raise ValueError('private output root')
  try:decode(out)
  except Exception as e:save(out/'decode-failure.json',{'error':repr(e)});raise
