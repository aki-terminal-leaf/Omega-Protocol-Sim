"""Read-only decoded-source audit. Pure GLB/comparison helpers need only stdlib.

Weights use original byte / original eight-byte sum, absolute float32 tolerance
1e-7. Zero sums are BLOCKED, never interpreted as original root influence.
TexTools is a shared maintained parser, not independent native renderer proof.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import struct
import sys
import time
import uuid
from types import SimpleNamespace

EXPECTED = '385131d58687249ffcb8fb9b8ac215446f9ca9a4bdd8306ad892bc50ce5aa8a2'
ROOT = Path(__file__).resolve().parents[2]
TOL = 1e-7

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(1024*1024), b''): h.update(b)
    return h.hexdigest()

def validate_manifest(path, expected):
    if expected != EXPECTED or sha(path) != EXPECTED: raise ValueError('manifest SHA mismatch')
    m = json.loads(Path(path).read_text())
    if len(m['seed_pins']) != 18 or len(m['pairs']) != 4: raise ValueError('seed/pair count')
    for group, base in [('seed_pins', ROOT), ('inputs', Path(path).parent), ('runtime_pins', ROOT)]:
        for name, pin in m[group].items():
            p = base / name
            if p.stat().st_size != pin['bytes'] or sha(p) != pin['sha256']: raise ValueError('pin mismatch: '+str(p))
    return m

def read_glb(data):
    if len(data)<12 or struct.unpack_from('<III',data)!=(0x46546c67,2,len(data)): raise ValueError('GLB header/length')
    chunks=[]; off=12
    while off<len(data):
        if off+8>len(data): raise ValueError('chunk header')
        size,kind=struct.unpack_from('<II',data,off); off+=8
        if size%4 or off+size>len(data): raise ValueError('chunk boundary')
        chunks.append((kind,data[off:off+size])); off+=size
    if [x[0] for x in chunks]!=[0x4e4f534a,0x004e4942]: raise ValueError('unsupported chunk layout')
    d=json.loads(chunks[0][1]); b=chunks[1][1]
    if len(d.get('buffers',[]))!=1 or 'uri' in d['buffers'][0]: raise ValueError('external buffers')
    size=d['buffers'][0]['byteLength']
    if size<0 or not size<=len(b)<=size+3 or any(b[size:]): raise ValueError('BIN length/padding')
    for v in d.get('bufferViews',[]):
        if v.get('buffer')!=0 or v.get('byteOffset',0)<0 or v['byteLength']<0 or v.get('byteOffset',0)+v['byteLength']>size: raise ValueError('view bounds')
    return d,b[:size]

def accessor(d,b,index):
    a=d['accessors'][index]
    if 'sparse' in a: raise ValueError('sparse accessor unsupported')
    codes={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
    sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    if a['type'] not in sizes or a['componentType'] not in codes: raise ValueError('unsupported accessor type')
    code,width=codes[a['componentType']]; n=sizes[a['type']]; packed=n*width
    v=d['bufferViews'][a['bufferView']]; start=a.get('byteOffset',0); stride=v.get('byteStride',packed); count=a['count']
    if count<1 or start<0 or start%width or (v.get('byteOffset',0)+start)%width or stride<packed or stride%width or ('byteStride' in v and (stride>252 or stride%4)) or start+(count-1)*stride+packed>v['byteLength']: raise ValueError('accessor bounds/stride/alignment')
    if v.get('byteOffset',0)+v['byteLength']>len(b): raise ValueError('buffer bounds')
    norm=a.get('normalized',False)
    if norm and a['componentType'] not in (5120,5121,5122,5123): raise ValueError('invalid normalization')
    rows=[]
    for i in range(count):
        row=struct.unpack_from('<'+code*n,b,v.get('byteOffset',0)+start+i*stride)
        if norm:
            divisor={5120:127,5121:255,5122:32767,5123:65535}[a['componentType']]
            row=tuple(max(-1,x/divisor) for x in row)
        if any(not math.isfinite(x) for x in row): raise ValueError('nonfinite accessor')
        rows.append(row)
    return rows

def compare_rows(source, actual, tolerance=0):
    if len(source)!=len(actual): raise ValueError('row omission/count mismatch')
    maximum=0.0
    for i,(s,a) in enumerate(zip(source,actual)):
        if len(s)!=len(a): raise ValueError('component omission')
        for x,y in zip(s,a):
            if not math.isfinite(x) or not math.isfinite(y): raise ValueError('nonfinite comparison')
            error=abs(x-y); maximum=max(maximum,error)
            if error>tolerance: raise ValueError('value mismatch at row '+str(i))
    return maximum

def compare_weights(ids, weights, bones, names, actual_ids, actual_weights):
    if any(len(x)!=8 for x in [ids,weights,actual_ids,actual_weights]): raise ValueError('eight influences required')
    total=sum(weights)
    if any(w<0 or w>255 for w in weights): raise ValueError('byte weight range')
    positive=[ids[i] for i,w in enumerate(weights) if w]
    out=sum(i<0 or i>=len(bones) for i in positive)
    missing=sum(bones[i] not in names for i in positive if 0<=i<len(bones))
    result=dict(sum=total,zero=total==0,not255=total!=255,outofrange=out,missingbone=missing,duplicates=len(positive)-len(set(positive)),max_error=0.0,status='PASS')
    if total==0 or out or missing:
        result['status']='BLOCKED'; return result
    expected=[w/total for w in weights]
    result['max_error']=compare_rows([expected],[actual_weights],TOL)
    for i,w in enumerate(weights):
        if w and (not 0<=actual_ids[i]<len(names) or names[actual_ids[i]]!=bones[ids[i]]): raise ValueError('positive joint identity mismatch')
    return result

def require_mesh_pass(result):
    """Fail closed on a blocked child; exit 0/guard OK is not mesh acceptance."""
    if result.get('status') != 'DECODED_MESH_PASS_SHADER_OPEN' or result.get('zero_counterexamples') != []:
        raise ValueError('mesh fidelity blocked for model '+str(result.get('model'))+': '+str(result.get('status'))+' '+str(result.get('weight_counts')))
    counts=result.get('weight_counts',{})
    if any(counts.get(k) != 0 for k in ('zero','outofrange','missingbone')):
        raise ValueError('mesh fidelity blocked counters for model '+str(result.get('model'))+': '+str(counts))
    return result

def metadata(value, depth=0):
    """Bounded reflection of an already decoded material object; no file discovery."""
    if value is None or isinstance(value,(str,int,float,bool)): return value
    if depth>5: return {'unsupported_depth':str(value.GetType()) if hasattr(value,'GetType') else type(value).__name__}
    if hasattr(value,'GetType'):
        t=value.GetType()
        if t.IsEnum: return {'name':str(value),'value':int(value)}
        if str(t.FullName).startswith('System.') and not hasattr(value,'__iter__'):
            return str(value)
    try: return [metadata(v,depth+1) for v in value]
    except TypeError: pass
    result={}
    if hasattr(value,'GetType'):
        t=value.GetType()
        for f in t.GetFields():
            if not f.IsStatic:
                try: result[str(f.Name)]=metadata(f.GetValue(value),depth+1)
                except Exception as e: result[str(f.Name)]={'unsupported':str(e)}
        for p in t.GetProperties():
            if p.CanRead and len(p.GetIndexParameters())==0:
                try: result[str(p.Name)]=metadata(p.GetValue(value),depth+1)
                except Exception as e: result[str(p.Name)]={'unsupported':str(e)}
    return result or {'unsupported_type':str(type(value))}

def child(m, manifest, pair, out):
    out.mkdir(exist_ok=False)
    sys.path[:0]=[m['paths']['pythonnet_dir'],m['paths']['pillow_dir']]
    spec=importlib.util.spec_from_file_location('audit_read_initializer',manifest.parent/'references/official_export_helpers.py')
    h=importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
    realm=h.initialize(SimpleNamespace(**{k:Path(v) for k,v in m['paths'].items()},output=out))
    result=dict(model=pair['model'],status='OPEN',parts=[],excluded_parts=[],materials=[],zero_counterexamples=[],weight_counts=dict(zero=0,not255=0,outofrange=0,missingbone=0,duplicates=0),vertices=0,triangles=0,max_errors={})
    try:
        from Lumina.Data import FileResource
        from Lumina.Data.Files import TexFile
        from Lumina.Models.Materials import Material
        from xivModdingFramework.Models.FileTypes import Mdl
        from xivModdingFramework.Materials.FileTypes import Mtrl
        pin=pair['files']['mdl']; raw=realm.GetFile[FileResource](pin['source']); data=bytes(raw.Data)
        if len(data)!=pin['bytes'] or hashlib.sha256(data).hexdigest()!=pin['sha256']: raise ValueError('original MDL hash mismatch')
        result['mdl']=pin
        model=Mdl.GetTTModel(raw.Data,pin['source']).GetAwaiter().GetResult()
        glb=manifest.parent/pair['glb']; d,b=read_glb(glb.read_bytes()); result['glb']=dict(path=pair['glb'],sha256=sha(glb),bytes=glb.stat().st_size)
        sample=json.loads((manifest.parent/pair['integration_samples']).read_text()); names=sample['names']
        joints=d['skins'][0]['joints']
        if [d['nodes'][j]['name'] for j in joints]!=names: raise ValueError('sample skeleton identity')
        exported={}
        for node in d['nodes']:
            if 'mesh' not in node: continue
            mesh=d['meshes'][node['mesh']]; match=re.fullmatch(r'm\d+_g(\d+)_p(\d+)(?:_.*)?',mesh['name'])
            if not match or node['name']!=mesh['name'] or node.get('skin')!=0 or len(mesh['primitives'])!=1: raise ValueError('part mapping')
            key=tuple(map(int,match.groups()))
            if key in exported: raise ValueError('duplicate part')
            exported[key]=(node,mesh['primitives'][0])
        materials={}; seen=set()
        for gi,group in enumerate(model.MeshGroups):
            bones=[str(x) for x in group.Bones]
            for pi,part in enumerate(group.Parts):
                attrs=sorted(str(x) for x in part.Attributes); key=(gi,pi); vertices=list(part.Vertices); indices=[int(x) for x in part.TriangleIndices]
                info=dict(group=gi,part=pi,attributes=attrs,vertices=len(vertices),triangles=len(indices)//3)
                if not vertices or not indices or 'atr_lod' in attrs:
                    if key in exported: raise ValueError('unexpected excluded part present')
                    info['reason']='atr_lod' if 'atr_lod' in attrs else 'empty'; result['excluded_parts'].append(info); continue
                if key not in exported: raise ValueError('source part omitted '+str(key))
                seen.add(key); node,p=exported[key]
                expected_name=f'm{pair["model"]:04d}_g{gi}_p{pi}'+('_'+'_'.join(attrs) if attrs else '')
                if node['name']!=expected_name or node.get('extras',{}).get('ffxiv_attributes')!=attrs: raise ValueError('attribute/name mapping')
                if p.get('mode',4)!=4 or len(indices)%3 or any(i<0 or i>=len(vertices) for i in indices): raise ValueError('triangle topology')
                a=p['attributes']; actual={k:accessor(d,b,v) for k,v in a.items()}
                info['attribute_exclusions']=['UV2','vertex color','tangent','binormal','shape/morph data (not audited)']
                info['max_errors']={}
                for name,field,axes in [('POSITION','Position','XYZ'),('NORMAL','Normal','XYZ'),('TEXCOORD_0','UV1','XY')]:
                    src=[tuple(float(getattr(getattr(v,field),axis)) for axis in axes) for v in vertices]
                    info['max_errors'][name]=compare_rows(src,actual[name],TOL)
                compare_rows([(i,) for i in indices],accessor(d,b,p['indices']))
                for k in ['JOINTS_0','JOINTS_1','WEIGHTS_0','WEIGHTS_1']:
                    if len(actual[k])!=len(vertices): raise ValueError('influence omission')
                for vi,v in enumerate(vertices):
                    ids=[int(x) for x in v.BoneIds]; ws=[int(x) for x in v.Weights]
                    r=compare_weights(ids,ws,bones,names,actual['JOINTS_0'][vi]+actual['JOINTS_1'][vi],actual['WEIGHTS_0'][vi]+actual['WEIGHTS_1'][vi])
                    for k in result['weight_counts']: result['weight_counts'][k]+=int(r[k])
                    result['max_errors']['weights']=max(result['max_errors'].get('weights',0),r['max_error'])
                    if r['status']=='BLOCKED': result['zero_counterexamples'].append(dict(group=gi,part=pi,vertex=vi,source_ids=ids,source_weights=ws,actual_ids=actual['JOINTS_0'][vi]+actual['JOINTS_1'][vi],actual_weights=actual['WEIGHTS_0'][vi]+actual['WEIGHTS_1'][vi],reason=r))
                mp=str(Material.ResolveRelativeMaterialPath(group.Material,1)); gm=d['materials'][p['material']]
                if gm['name']!=str(group.Material) or gm.get('extras',{}).get('original_material')!=mp: raise ValueError('material mapping')
                info['material']=mp; info['final_material_index']=p['material']; materials[mp]=gm
                result['parts'].append(info); result['vertices']+=len(vertices); result['triangles']+=len(indices)//3
        if seen!=set(exported): raise ValueError('extra exported part')
        for mi,(mp,gm) in enumerate(materials.items()):
            mr=realm.GetFile[FileResource](mp); data=bytes(mr.Data); (out/f'material-{mi}.mtrl').write_bytes(data)
            mat=Mtrl.GetXivMtrl(mr.Data,mp)
            item=dict(path=mp,sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),raw_snapshot=f'material-{mi}.mtrl',shader_pack=str(mat.ShaderPackRaw),metadata=metadata(mat),final_material=gm,textures=[],shader_reconstruction='OPEN',colorset_semantics='OPEN')
            for tex in mat.Textures:
                tp=str(tex.Dx11Path); tr=realm.GetFile[FileResource](tp)
                entry=dict(path=tp,sampler_id=int(tex.Sampler.SamplerIdRaw),metadata=metadata(tex))
                if tr is None: entry['status']='MISSING'
                else:
                    td=bytes(tr.Data); entry.update(sha256=hashlib.sha256(td).hexdigest(),bytes=len(td))
                    tf=realm.GetFile[TexFile](tp)
                    entry['header']=metadata(tf.Header) if tf is not None else {'status':'UNSUPPORTED'}
                sid=entry['sampler_id']; entry['converter_action']={0x115306BE:'diffuse: alpha forced 255; PNG encoding',0x0C5EC1F1:'normal: green inverted; PNG encoding; material scale 0.65'}.get(sid,'OMITTED from exported material')
                entry['final_image_indices']=[i for i,x in enumerate(d.get('images',[])) if x.get('name')==tp]
                item['textures'].append(entry)
            result['materials'].append(item)
        result['status']='WEIGHTS_BLOCKED' if result['zero_counterexamples'] else 'DECODED_MESH_PASS_SHADER_OPEN'
    finally:
        realm.Dispose()
        (out/'result.json').write_text(json.dumps(result,indent=2))
    return result

def main():
    p=argparse.ArgumentParser(); p.add_argument('--manifest',type=Path,required=True); p.add_argument('--manifest-sha256',required=True); p.add_argument('--model',type=int); p.add_argument('--output',type=Path); a=p.parse_args()
    a.manifest=a.manifest.resolve(); m=validate_manifest(a.manifest,a.manifest_sha256)
    implementation={str(Path(__file__).relative_to(ROOT)):sha(__file__)}
    if a.model is not None:
        if not a.output or not a.output.resolve().is_relative_to(a.manifest.parent/'outputs'): raise ValueError('private output required')
        try: require_mesh_pass(child(m,a.manifest,next(x for x in m['pairs'] if x['model']==a.model),a.output))
        finally:
            validate_manifest(a.manifest,EXPECTED)
            if sha(__file__)!=next(iter(implementation.values())): raise ValueError('implementation changed')
        return 0
    if os.name!='nt': raise RuntimeError('guard requires Windows; pure helpers are portable')
    out=a.manifest.parent/'outputs'/('fidelity-'+str(time.time_ns())+'-'+uuid.uuid4().hex[:8]); out.mkdir(parents=True,exist_ok=False)
    summary=dict(status='OPEN',manifest_sha256=EXPECTED,seed_pins=m['seed_pins'],private_pins=m['inputs'],runtime_pins=m['runtime_pins'],implementation=implementation,models=[],receipts=[],all96_accepted=False,visual_acceptance=False,raster_acceptance=False,export_acceptance=False,shader_reconstruction='OPEN',colorset_semantics='OPEN')
    print(out,flush=True)
    try:
        sys.path.insert(0,str(Path(__file__).parent))
        from run_cinematic_integration import run
        for pair in m['pairs']:
            validate_manifest(a.manifest,EXPECTED)
            if sha(__file__)!=next(iter(implementation.values())): raise ValueError('implementation changed before run')
            label=f'm{pair["model"]:04d}'; argv=[m['paths']['python'],'-B',str(Path(__file__).resolve()),'--manifest',str(a.manifest),'--manifest-sha256',EXPECTED,'--model',str(pair['model']),'--output',str(out/label)]
            (out/(label+'-argv.json')).write_text(json.dumps(argv,indent=2))
            receipt=run(out,label,argv,60,out); summary['receipts'].append(receipt)
            result_path=out/label/'result.json'
            if result_path.is_file():
                result=json.loads(result_path.read_text())
                summary['models'].append(result)
                require_mesh_pass(result)
            if not receipt['ok']: raise RuntimeError('child failed; no retry: '+label)
            if not result_path.is_file(): raise RuntimeError('child result missing: '+label)
        summary['status']='SOURCE_AUDIT_COMPLETE_VISUAL_OPEN'
    except Exception as e: summary.update(status='BLOCKED',blocker=str(e))
    finally:
        try: validate_manifest(a.manifest,EXPECTED); summary['protected_pins_unchanged']=True
        except Exception as e: summary.update(status='BLOCKED',end_pin_error=str(e))
        summary['implementation_unchanged']=sha(__file__)==next(iter(implementation.values()))
        summary['output_hashes']={str(f.relative_to(out)):sha(f) for f in out.rglob('*') if f.is_file()}
        (out/'summary.json').write_text(json.dumps(summary,indent=2)); print(summary['status'],summary.get('blocker',''),flush=True)
    return 1 if summary['status']=='BLOCKED' else 0

if __name__=='__main__': sys.exit(main())
