"""Pinned read-only original MDL conversion. No proprietary geometry parsing."""
import argparse, hashlib, importlib.util, json, math, struct, sys
from pathlib import Path
from types import SimpleNamespace
EXPECTED = '7ad8d152163dc1985e8c067d390a58b4b16ff5acc8b71075f9bc5a6bc0dc810d'
ROOT = Path(__file__).resolve().parents[2]
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def validate_manifest(path, expected):
    path = Path(path).resolve()
    if expected != EXPECTED or sha(path) != EXPECTED: raise ValueError('manifest SHA mismatch')
    m = json.loads(path.read_text())
    if m.get('schema')!=1 or m.get('source_base')!='6e11e44c4009f095148e0c15520d25a8b8aeccd2' or len(m['seed_pins'])!=11: raise ValueError('manifest schema/base/seeds')
    for group, base in [('seed_pins', ROOT), ('inputs', path.parent), ('runtime_pins', ROOT)]:
        for name, pin in m[group].items():
            p = base / name
            if p.stat().st_size != pin['bytes'] or sha(p) != pin['sha256']: raise ValueError('pin mismatch: '+str(p))
    return m

def validate_sample(s):
    if s.get('layout') != 'Translation4 Scale4 Rotation4' or s.get('pose_space') != 'model (upstream convention)': raise ValueError('schema/space')
    names, parents = s['names'], s['parents']; n = len(names)
    if not n or n != s['bone_count'] or len(set(names)) != n or any(not isinstance(x,str) or not x for x in names) or len(parents)!=n: raise ValueError('names/dimensions')
    for i,p in enumerate(parents):
        if type(p)!=int or p < -1 or p >= n: raise ValueError('parent range')
        seen=set(); j=i
        while j!=-1:
            if j in seen: raise ValueError('parent cycle')
            seen.add(j); j=parents[j]
    def frame(f):
        if len(f)!=n: raise ValueError('frame bone dimension')
        for row in f:
            if len(row)!=12 or any(type(v) not in (int,float) or not math.isfinite(v) for v in row): raise ValueError('TRS dimension/finite')
            if sum(v*v for v in row[8:12]) < 1e-16: raise ValueError('zero quaternion')
    frame(s['reference_local']); ids=set()
    for c in s['clips']:
        if type(c['index'])!=int or c['index'] in ids: raise ValueError('clip index')
        ids.add(c['index']); t=c['times']; q=c['native_query_times']; d=c['duration']
        if not math.isfinite(d) or d<=0 or len(t)!=len(q) or len(t)!=len(c['frames']) or len(t)<2 or c['bone_count']!=n: raise ValueError('clip dimensions')
        for seq in (t,q):
            if any(not math.isfinite(v) for v in seq) or seq[0]!=0 or seq[-1]!=d or any(a>=b for a,b in zip(seq,seq[1:])): raise ValueError('strict times/endpoint')
        if [struct.unpack('<f',struct.pack('<f',v))[0] for v in t]!=q: raise ValueError('native float32 times')
        for f in c['frames']: frame(f)
    return s

def read_glb(path):
    b=Path(path).read_bytes(); magic,version,total=struct.unpack_from('<III',b)
    if (magic,version,total)!=(0x46546c67,2,len(b)): raise ValueError('GLB header')
    size,kind=struct.unpack_from('<II',b,12)
    if kind!=0x4e4f534a: raise ValueError('GLB JSON')
    d=json.loads(b[20:20+size]); off=20+size; size,kind=struct.unpack_from('<II',b,off)
    return d,b[off+8:off+8+size]

def inspect_glb(d,b,s,helper):
    def acc(i):
        a=d['accessors'][i]; v=d['bufferViews'][a['bufferView']]; count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]; code={5126:'f',5123:'H',5125:'I',5121:'B'}[a['componentType']]
        step=struct.calcsize('<'+code*count); start=v.get('byteOffset',0)+a.get('byteOffset',0)
        rows=[struct.unpack_from('<'+code*count,b,start+j*v.get('byteStride',step)) for j in range(a['count'])]
        if any(not math.isfinite(x) for row in rows for x in row): raise ValueError('nonfinite accessor')
        return rows
    skins=d.get('skins',[])
    if len(skins)!=1 or len(skins[0]['joints'])!=len(s['names']): raise ValueError('skin/joints')
    joints=skins[0]['joints']; mats={}; parents={c:i for i,node in enumerate(d['nodes']) for c in node.get('children',[])}
    def global_matrix(i):
        if i not in mats:
            node=d['nodes'][joints[i]]; m=helper.matrix(node); p=s['parents'][i]; mats[i]=helper.multiply(global_matrix(p),m) if p>=0 else m
        return mats[i]
    ib=acc(skins[0]['inverseBindMatrices']); maxerr=0
    for i,j in enumerate(joints):
        node=d['nodes'][j]; p=s['parents'][i]
        if node['name']!=s['names'][i] or parents.get(j,-1)!=(joints[p] if p>=0 else -1): raise ValueError('joint name/parent mismatch')
        inv=[[ib[i][col*4+row] for col in range(4)] for row in range(4)]
        prod=helper.multiply(global_matrix(i),inv); maxerr=max(maxerr,max(abs(prod[r][c]-(r==c)) for r in range(4) for c in range(4)))
    if maxerr>1e-4: raise ValueError('inverse bind error '+str(maxerr))
    vertices=triangles=0; bounds=[]; maxw=0
    for node in d['nodes']:
        if 'mesh' not in node: continue
        if node.get('skin')!=0: raise ValueError('unskinned mesh')
        for p in d['meshes'][node['mesh']]['primitives']:
            a=p['attributes']; pos=acc(a['POSITION']); ids=acc(p['indices']); vertices+=len(pos); triangles+=len(ids)//3
            if not pos or not ids or any(x[0]>=len(pos) for x in ids): raise ValueError('empty/invalid geometry')
            bounds.append({'min':[min(v[k] for v in pos) for k in range(3)],'max':[max(v[k] for v in pos) for k in range(3)]})
            js=[acc(a['JOINTS_'+str(k)]) for k in range(2)]; ws=[acc(a['WEIGHTS_'+str(k)]) for k in range(2)]
            if any(len(x)!=len(pos) for x in js+ws): raise ValueError('skin dimensions')
            for i in range(len(pos)):
                w=ws[0][i]+ws[1][i]; j=js[0][i]+js[1][i]
                if any(x<0 or x>=len(joints) for x in j) or any(x<0 for x in w): raise ValueError('joint/weight range')
                maxw=max(maxw,abs(sum(w)-1))
    if not vertices or not triangles or maxw>1e-5: raise ValueError('geometry/weights')
    return dict(vertices=vertices,triangles=triangles,meshes=len(d['meshes']),skins=len(skins),joints=len(joints),materials=len(d['materials']),textures=len(d['textures']),bounds=bounds,max_weight_error=maxw,max_inverse_bind_error=maxerr)

def main():
    p=argparse.ArgumentParser(); p.add_argument('--manifest',type=Path,required=True); p.add_argument('--manifest-sha256',required=True); p.add_argument('--model',type=int,required=True); p.add_argument('--output',type=Path,required=True); a=p.parse_args()
    m=validate_manifest(a.manifest,a.manifest_sha256); pair=next(x for x in m['pairs'] if x['model']==a.model); s=validate_sample(json.loads((a.manifest.parent/pair['integration_samples']).read_text()))
    if not a.output.resolve().is_relative_to(a.manifest.resolve().parent/'outputs'): raise ValueError('output must stay in private task outputs')
    if (s['model'],s['base'])!=(pair['model'],pair['base']): raise ValueError('sample model/body mismatch')
    a.output.mkdir(parents=True,exist_ok=False)
    sys.path[:0]=[m['paths']['pillow_dir'],m['paths']['pythonnet_dir']]
    spec=importlib.util.spec_from_file_location('pinned_helper',a.manifest.parent/'references/official_export_helpers.py'); h=importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
    args=SimpleNamespace(**{k:Path(v) for k,v in m['paths'].items()},output=a.output,rig_dir=a.output)
    realm=h.initialize(args)
    try:
        from Lumina.Data import FileResource
        pins=[]
        for pin in pair['files'].values():
            source=pin.get('source',pin.get('path')); raw=realm.GetFile[FileResource](source)
            if raw is None: raise ValueError('missing original '+source)
            data=bytes(raw.Data)
            if len(data)!=pin['bytes'] or hashlib.sha256(data).hexdigest()!=pin['sha256']: raise ValueError('original source pin mismatch '+source)
            pins.append(dict(source=source,sha256=pin['sha256'],bytes=len(data)))
        form='m%04d'%a.model
        bones=[dict(name=n,parent=s['parents'][i],translation=r[:3],scale=r[4:7],rotation=r[8:12]) for i,(n,r) in enumerate(zip(s['names'],s['reference_local']))]
        (a.output/(form+'.json')).write_text(json.dumps(dict(bones=bones,animations=[],animation_space='model')))
        result=h.export_model(realm,args,form,dict(model=pair['model'],base=pair['base'],variant=1))
        target=a.output/result['file']; d,b=read_glb(target); d['asset']['extras']['pose']='unanimated LOCAL bind rig; externally sampled MODEL poses'
        glb=h.GLB(); glb.doc=d; glb.data=bytearray(b); glb.save(target)
        result['sha256']=sha(target); result['bytes']=target.stat().st_size; result['validation']=inspect_glb(d,b,s,h)
        for source in sorted({x['extras']['original_material'] for x in d['materials']}|{x['name'] for x in d['images']}):
            data=bytes(realm.GetFile[FileResource](source).Data); pins.append(dict(source=source,sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
        result['original_pins']=pins; result['sample_sha256']=sha(a.manifest.parent/pair['integration_samples'])
        (a.output/'result.json').write_text(json.dumps(result,indent=2)); print(json.dumps(result['validation']))
    finally: realm.Dispose()
if __name__=='__main__': main()


