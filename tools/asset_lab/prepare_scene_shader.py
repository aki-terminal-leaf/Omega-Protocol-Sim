"""Private original lightshaft decode; source equations are conditional, never runtime evidence."""
import argparse, hashlib, importlib.util, json, math, sys, re
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[2]
INPUTS=Path('D:/Dev/OpenClawCodexBridge/probes/top-scene-shader-implementation-50871/inputs')
EXPECTED='333eb3f9aa23cec8c63e31c436619488d0b3a4f5ed5318d695a7ba67fb36c649'
RUNTIME=Path('D:/Dev/OpenClawCodexBridge/worktrees/top-material-inputs-50830/top/assets/official/top-material-inputs-50830/inputs.json')
OUTPUT=ROOT/'top/assets/official/top-scene-shader-50871/outputs'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,indent=2,allow_nan=False),encoding='utf-8')
def validate():
 if sha(INPUTS/'inputs.json')!=EXPECTED:raise ValueError('input manifest hash')
 m=json.loads((INPUTS/'inputs.json').read_bytes())
 for group,base in [('files',INPUTS),('protected_sources',ROOT)]:
  for n,p in m[group].items():
   if sha(base/n)!=p['sha256'] or (base/n).stat().st_size!=p['bytes']:raise ValueError('pin '+n)
 return m

def rows(v,n):
 if not isinstance(v,list) or len(v)!=n or any(not isinstance(r,list) or len(r)!=4 or any(type(x) not in (float,int) or not math.isfinite(x) for x in r) for r in v):raise ValueError('finite float4 buffer')
 return v

def sample(m,i,camera,common,clock,p,n,uv,alpha,t0,t1):
 rows(m,5);rows(i,10)
 if any(not math.isfinite(x) for x in [*camera,common,clock,*p,*n,*uv,alpha,*t0,*t1]):raise ValueError('finite inputs')
 dot=lambda a,b:sum(x*y for x,y in zip(a,b))
 world=[dot(r,p+[1]) for r in i[:3]]
 rotate=lambda v:[dot(r[:3],v) for r in i[3:6]]
 tex=uv+[dot(rotate(m[k][:3]),world)+round(m[4][k-1])*clock for k in [1,2]]
 angular=abs(dot(camera,rotate(n)))**2*(1-m[3][3])+m[3][3]
 color=[m[3][k]*i[7][k]*alpha*angular*max(0,min(1,m[2][3]*i[6][3]-1))*common for k in range(3)]
 return dict(world=world,uv=tex,color=color,rgba=[t0[k]*color[k]*t1[k] for k in range(3)]+[0])

def instruction_oracle(m,i,camera,common,clock,p,n,uv,alpha):
 """Execute pinned literal VS0 IR independently of the factored CPU function."""
 programs=json.loads((INPUTS/'shader-instruction-ir.json').read_bytes())['programs']
 registers={'v0':p+[0], 'v1':n+[0], 'v2':uv+[0,0], 'v3':[0,0,0,alpha]}
 for name,values in [('cb0',m),('cb1',[[0]*4]*3+[[common,0,0,0]]),('cb2',[[0]*4,[0]*4,camera+[0]]+[[0]*4]*7),('cb3',[[0,0,0,clock]]),('cb4',i)]:
  for j,row in enumerate(values):registers[f'{name}[{j}]']=list(row)
 def value(text):
  negative=text.startswith('-');text=text.lstrip('-');absolute=text.startswith('|');text=text.strip('|')
  if text.startswith('l('):
   v=[float(x) for x in text[2:-1].split(',')];v=v*4 if len(v)==1 else v
  else:
   name,_,swizzle=text.partition('.');v=registers.get(name,[0]*4);v=[v['xyzw'.index(x)] for x in (swizzle or 'xyzw')]
  if len(v)==1:v=v*4
  if absolute:v=[abs(x) for x in v]
  return [-x for x in v] if negative else v
 for instruction in programs['lightshaft-vs-0']['instructions']:
  op=instruction['op']
  if op=='ret':break
  args=re.split(r',\s*(?![^()]*\))',instruction['operands']);dest=args[0];v=[value(x) for x in args[1:]]
  if op=='mov':result=v[0]
  elif op.startswith('dp'):result=[sum(a*b for a,b in zip(v[0][:int(op[-1])],v[1][:int(op[-1])]))]*4
  elif op=='round_ne':result=[round(x) for x in v[0]]
  elif op=='add':result=[a+b for a,b in zip(*v)]
  elif op=='mul':result=[a*b for a,b in zip(*v)]
  elif op in ('mad','mad_sat'):result=[a*b+c for a,b,c in zip(*v)]
  else:raise ValueError('unsupported IR '+op)
  if op.endswith('_sat'):result=[max(0,min(1,x)) for x in result]
  name,_,mask=dest.partition('.');old=registers.setdefault(name,[0]*4)
  for component in mask or 'xyzw':old['xyzw'.index(component)]=result['xyzw'.index(component)]
 return {'uv':registers['o1'],'color':registers['o2'][:3]}

def decode(out):
 from audit_cinematic_mesh_fidelity import metadata
 validate();cfg=json.loads(RUNTIME.read_bytes());paths=cfg['paths']
 if sha(RUNTIME)!='52d925afa2ad82f1e00323a851896980c6da371b1bf457cb6c6d5d696064c20e':raise ValueError('runtime manifest')
 for name,pin in cfg['runtime_pins'].items():
  if sha(ROOT/name)!=pin['sha256']:raise ValueError('runtime pin '+name)
 helper=RUNTIME.parent/'references/official_export_helpers.py'
 if sha(helper)!=cfg['inputs']['references/official_export_helpers.py']['sha256']:raise ValueError('initializer pin')
 sys.path[:0]=[paths['pythonnet_dir'],paths['pillow_dir']]
 spec=importlib.util.spec_from_file_location('source_initializer',helper);h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
 realm=h.initialize(SimpleNamespace(**{k:Path(v) for k,v in paths.items()},output=out))
 from Lumina.Data import FileResource
 from Lumina.Data.Files import TexFile
 from xivModdingFramework.Models.FileTypes import Mdl
 from xivModdingFramework.Materials.FileTypes import Mtrl
 from PIL import Image
 mapping=json.loads((INPUTS/'package-mapping.json').read_bytes());result={'models':[],'pins':{},'inspection':{'duration':10.0,'clock_origin':0.0,'clock_rate':0.001,'provenance':'INSPECTION_FIXTURE; source clock = origin + relative seconds * rate; native epoch/unit unknown','common3x':1.0,'i6w':5.0,'i7rgb':[1.0,1.0,1.0],'exposure':1.0,'blend':'chosen additive; native blend/depth unknown'}}
 def raw(path,name):
  f=realm.GetFile[FileResource](path)
  if f is None:raise ValueError('missing '+path)
  b=bytes(f.Data);(out/name).write_bytes(b);result['pins'][path]={'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'file':name};return f
 try:
  sh=raw('shader/sm5/shpk/lightshaft.shpk','lightshaft.shpk')
  if result['pins']['shader/sm5/shpk/lightshaft.shpk']['sha256']!=mapping['packages']['shader/sm5/shpk/lightshaft.shpk']['source_sha256']:raise ValueError('shader identity')
  for idx,y in enumerate([225.22450256347656,155.22450256347656,205.22450256347656],1):
   path=f'bg/ex2/05_zon_z3/ome/z3oe/bgparts/z3oe_a0_lsf0{idx}.mdl';f=raw(path,f'lsf{idx}.mdl');mdl=Mdl.GetXivMdl(f.Data,path)
   model={'path':path,'y':y,'surfaces':[],'decoder_mvid':str(mdl.GetType().Module.ModuleVersionId)}
   tt=Mdl.GetTTModel(f.Data,path).GetAwaiter().GetResult()
   for gi,mesh in enumerate(mdl.LoDList[0].MeshDataList):
    vd=mesh.VertexData;decl=metadata(mesh.VertexDataStructList)
    fields=[str(x.Name) for x in vd.GetType().GetProperties()];save(out/f'fields-{idx}-{gi}.json',{'fields':fields,'declaration':decl,'mesh_info':metadata(mesh.MeshInfo)})
    pos=[[float(getattr(v,a)) for a in 'XYZ'] for v in vd.Positions];norm=[[float(getattr(v,a)) for a in 'XYZ'] for v in vd.Normals]
    uv=[[float(v.X),float(v.Y)] for v in vd.TextureCoordinates0];color=[[int(getattr(v,a)) for a in 'RGBA'] for v in vd.Colors];indices=[int(v) for v in vd.Indices]
    if any(not math.isfinite(x) for data in [pos,norm,uv] for row in data for x in row):raise ValueError('nonfinite original geometry')
    if not pos or any(len(a)!=len(pos) for a in [norm,uv,color]) or any(v<0 or v>=len(pos) for v in indices):raise ValueError('source vertex cardinality')
    if not any(str(d.DataUsage)=='Color' and str(d.DataType)=='Ubyte4n' for d in mesh.VertexDataStructList):raise ValueError('original COLOR declaration')
    mp=str(tt.MeshGroups[gi].Material)
    if not mp.startswith('bg/'):mp='bg/ex2/05_zon_z3/ome/z3oe/material/'+mp.lstrip('/')
    expected=f'bg/ex2/05_zon_z3/ome/z3oe/material/z3oe_a0_lsf{idx-1:02d}a.mtrl'
    if mp!=expected:raise ValueError('material identity '+mp)
    mat=Mtrl.GetXivMtrl(raw(mp,f'lsf{idx}-{gi}.mtrl').Data,mp);mm=next(v for v in mapping['materials'] if v['path']==mp);textures={};save(out/f'material-{idx}-{gi}-metadata.json',metadata(mat))
    actual={int(c.ConstantId):[float(x) for x in c.Values] for c in mat.ShaderConstants}
    expected_constants={c['id']:c['values'] for c in mm['constants'] if c['value_origin']=='MTRL'}
    if actual!=expected_constants or str(mat.ShaderPackRaw)!='lightshaft.shpk':raise ValueError('original material constants mismatch')
    for tex in mat.Textures:
     sid=int(tex.Sampler.SamplerIdRaw)
     if sid not in [557626425,1446741167] or str(sid) in textures:raise ValueError('sampler identity')
     tp=str(tex.Dx11Path);stem=f'lsf{idx}-{gi}-{sid}';raw(tp,stem+'.tex');tf=realm.GetFile[TexFile](tp);w=int(tf.Header.Width);height=int(tf.Header.Height);bgra=bytes(tf.ImageData)
     if len(bgra)!=w*height*4:raise ValueError('texture extent')
     im=Image.frombytes('RGBA',(w,height),bgra,'raw','BGRA');rgba=im.tobytes();im.save(out/(stem+'.png'));(out/(stem+'.rgba')).write_bytes(rgba)
     if Image.open(out/(stem+'.png')).tobytes()!=rgba:raise ValueError('PNG roundtrip')
     textures[str(sid)]={'png':stem+'.png','rgba':stem+'.rgba','sha256':sha(out/(stem+'.png')),'rgba_sha256':sha(out/(stem+'.rgba')),'width':w,'height':height,'alpha_min':min(rgba[3::4]),'alpha_max':max(rgba[3::4]),'path':tp}
    if set(textures)!={'557626425','1446741167'}:raise ValueError('missing texture')
    inst=[[1,0,0,100],[0,1,0,y],[0,0,1,100],[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,5],[1,1,1,0],[0]*4,[0]*4]
    for vp,vn,vu,vc in zip(pos,norm,uv,color):
     for clock in [0,0.003,-0.002]:
      cpu=sample(mm['material_float4s'],inst,[0.2,0.3,0.4],1,clock,vp,vn,vu,vc[3]/255,[1]*3,[1]*3)
      ir=instruction_oracle(mm['material_float4s'],inst,[0.2,0.3,0.4],1,clock,vp,vn,vu,vc[3]/255)
      if any(abs(a-b)>1e-9 for key in ['uv','color'] for a,b in zip(cpu[key],ir[key])):raise ValueError('literal IR oracle mismatch')
    model['surfaces'].append(dict(position=pos,normal=norm,uv=uv,color=color,indices=indices,material=mp,M=rows(mm['material_float4s'],5),textures=textures,declaration=decl,uv_provenance='raw XivMdl.TextureCoordinates0; direct native XY, no glTF conversion'))
   model['oracle']={'literal_vs0_ir_all_vertices':True,'clocks':[0,0.003,-0.002],'vertices':sum(len(s['position']) for s in model['surfaces'])};result['models'].append(model)
  save(out/'scene.json',result);validate()
 finally:realm.Dispose()

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve()
 if not out.is_relative_to(OUTPUT) or not out.name.startswith('run-'):raise ValueError('private run root')
 try:decode(out)
 except Exception as e:save(out/'decode-failure.json',{'error':repr(e)});raise
