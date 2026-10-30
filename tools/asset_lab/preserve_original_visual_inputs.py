"""Private read-only SqPack preservation. No native shader interpretation."""
import argparse, copy, hashlib, importlib.util, json, math, re, struct, sys
from pathlib import Path
from types import SimpleNamespace
from audit_cinematic_mesh_fidelity import read_glb, accessor, compare_rows, metadata, sha
ROOT=Path(__file__).resolve().parents[2]
PREPARED_SHA256='ceea5ef4d9c449aa91e4e60081250805da8e33d904e1502711886ae445824ad4'
EXPECTED='52d925afa2ad82f1e00323a851896980c6da371b1bf457cb6c6d5d696064c20e'
PREPARED=Path('D:/Dev/OpenClawCodexBridge/probes/top-visual-50859-prepared.json')
OUTPUT=ROOT/'top/assets/official/top-original-visual-inputs-50859/outputs'
def write_json(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
def digest(b): return hashlib.sha256(b).hexdigest()
def validate(path, expected):
    if expected!=EXPECTED or sha(path)!=expected: raise ValueError('manifest SHA mismatch')
    if sha(PREPARED)!=PREPARED_SHA256: raise ValueError('prepared 40-source manifest SHA mismatch')
    m=json.loads(path.read_text(encoding='utf-8')); prepared=json.loads(PREPARED.read_text(encoding='utf-8'))
    if len(prepared['protected_sources'])!=40: raise ValueError('protected 40-source inventory')
    if len(m['seed_pins'])!=30 or len(m['inputs'])!=140 or len(m['runtime_pins'])!=12: raise ValueError('pin inventory')
    if [(x['model'],x['base']) for x in m['pairs']]!=[(110,1),(424,2),(8277,1),(771,1)]: raise ValueError('pair identities')
    for pins,base in [(prepared['protected_sources'],ROOT),(m['inputs'],path.parent),(m['runtime_pins'],ROOT)]:
        for n,p in pins.items():
            f=base/n
            if f.stat().st_size!=p['bytes'] or sha(f)!=p['sha256']: raise ValueError('pin mismatch '+str(f))
    m['seed_comparison']={n:{'old':p,'current_sha256':sha(ROOT/n),'exact':sha(ROOT/n)==p['sha256']} for n,p in m['seed_pins'].items()}
    return m

def append_attribute(d,b,rows,code,kind,normalized=False):
    if not rows or any(len(r)!=len(rows[0]) or any(not math.isfinite(v) for v in r) for r in rows): raise ValueError('missing/nonfinite rows')
    b.extend(b'\0'*(-len(b)%4)); off=len(b)
    b.extend(struct.pack('<'+code*(len(rows)*len(rows[0])),*(v for r in rows for v in r)))
    d['bufferViews'].append(dict(buffer=0,byteOffset=off,byteLength=len(b)-off,target=34962))
    a=dict(bufferView=len(d['bufferViews'])-1,componentType={'B':5121,'f':5126}[code],count=len(rows),type=kind)
    if normalized:a['normalized']=True
    d['accessors'].append(a); return len(d['accessors'])-1

def save_glb(path,d,b):
    d['buffers'][0]['byteLength']=len(b); j=json.dumps(d,separators=(',',':')).encode('utf-8'); j+=b' '*(-len(j)%4)
    binary=bytes(b)+b'\0'*(-len(b)%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(j)+len(binary))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(binary),0x004e4942)+binary)

def exact_parts(d,mid):
    found={}
    for node in d['nodes']:
        if 'mesh' not in node:continue
        mesh=d['meshes'][node['mesh']]; match=re.fullmatch(r'm'+f'{mid:04d}'+r'_g(\d+)_p(\d+)(?:_.*)?',mesh['name'])
        if not match or mesh['name']!=node['name'] or node.get('skin')!=0 or len(mesh['primitives'])!=1: raise ValueError('part mapping')
        key=tuple(map(int,match.groups()))
        if key in found: raise ValueError('duplicate part mapping')
        found[key]=(node,mesh['primitives'][0])
    return found

def convert(m,manifest,pair,out):
    out.mkdir(parents=True,exist_ok=False); result=dict(status='BLOCKED',model=pair['model'],base=pair['base'],parts=[],materials=[],excluded_parts=[])
    realm=None
    try:
        sys.path[:0]=[m['paths']['pythonnet_dir'],m['paths']['pillow_dir']]
        spec=importlib.util.spec_from_file_location('preservation_initializer',manifest.parent/'references/official_export_helpers.py'); h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
        realm=h.initialize(SimpleNamespace(**{k:Path(v) for k,v in m['paths'].items()},output=out))
        from Lumina.Data import FileResource
        from Lumina.Data.Files import TexFile
        from Lumina.Models.Materials import Material
        from xivModdingFramework.Models.FileTypes import Mdl
        from xivModdingFramework.Materials.FileTypes import Mtrl
        from PIL import Image
        pin=pair['files']['mdl']; raw=realm.GetFile[FileResource](pin['source'])
        if raw is None: raise ValueError('source MDL absent '+pin['source'])
        data=bytes(raw.Data)
        if len(data)!=pin['bytes'] or digest(data)!=pin['sha256']:raise ValueError('source MDL pin')
        (out/'original.mdl').write_bytes(data);result['mdl']=pin
        model=Mdl.GetTTModel(raw.Data,pin['source']).GetAwaiter().GetResult()
        raw_model=Mdl.GetXivMdl(raw.Data,pin['source'])
        result['decoder_module_mvid']=str(model.GetType().Module.ModuleVersionId)
        d,original=read_glb((manifest.parent/pair['glb']).read_bytes()); before=copy.deepcopy(d); b=bytearray(original); exported=exact_parts(d,pair['model']); seen=set(); materials={}
        for gi,group in enumerate(model.MeshGroups):
            for pi,part in enumerate(group.Parts):
                key=(gi,pi); vs=list(part.Vertices); ids=[int(v) for v in part.TriangleIndices]; attrs=sorted(str(v) for v in part.Attributes)
                if not vs or not ids or 'atr_lod' in attrs:
                    if key in exported:raise ValueError('excluded part exported')
                    result['excluded_parts'].append(dict(group=gi,part=pi,reason='atr_lod' if 'atr_lod' in attrs else 'empty'));continue
                if key not in exported:raise ValueError('missing source part')
                node,p=exported[key];seen.add(key);name=f'm{pair["model"]:04d}_g{gi}_p{pi}'+('_'+'_'.join(attrs) if attrs else '')
                if node['name']!=name or node.get('extras',{}).get('ffxiv_attributes')!=attrs:raise ValueError('exact name/attributes')
                for semantic,field,axes in [('POSITION','Position','XYZ'),('NORMAL','Normal','XYZ'),('TEXCOORD_0','UV1','XY')]:
                    compare_rows([tuple(float(getattr(getattr(v,field),a)) for a in axes) for v in vs],accessor(d,original,p['attributes'][semantic]),1e-7)
                compare_rows([(i,) for i in ids],accessor(d,original,p['indices']))
                fields={str(f.Name):str(f.FieldType) for f in vs[0].GetType().GetFields() if not f.IsStatic}
                result['vertex_fields']=fields
                if fields.get('VertexColor')!='System.Byte[]' or 'UV2' not in fields:raise ValueError('unsupported reflected source color/UV2 fields '+str(fields))
                colors=[tuple(int(x) for x in v.VertexColor) for v in vs]
                if any(len(c)!=4 for c in colors):raise ValueError('color cardinality')
                uv=[(float(v.UV2.X),float(v.UV2.Y)) for v in vs]
                raw_mesh=raw_model.LoDList[0].MeshDataList[gi]; raw_part=raw_mesh.MeshPartList[pi]
                declaration=list(raw_mesh.VertexDataStructList)
                declared_color=[v for v in declaration if str(v.DataUsage)=='Color' and int(v.Count)==0]
                declared_uv=[v for v in declaration if str(v.DataUsage)=='TextureCoordinate' and int(v.Count)==0]
                if len(declared_color)!=1 or str(declared_color[0].DataType)!='Ubyte4n' or len(declared_uv)!=1 or str(declared_uv[0].DataType)!='Half4':raise ValueError('unproved original packed COLOR/UV2 declaration')
                if 'COLOR_0' in p['attributes'] or 'TEXCOORD_1' in p['attributes']:raise ValueError('baseline attributes must not be overwritten')
                start=int(raw_part.IndexOffset)-int(raw_mesh.MeshInfo.IndexDataOffset)
                raw_indices=[int(x) for x in raw_mesh.VertexData.Indices][start:start+int(raw_part.IndexCount)]
                raw_ids=sorted(set(raw_indices)); remap={v:i for i,v in enumerate(raw_ids)}
                if len(raw_ids)!=len(vs) or [remap[i] for i in raw_indices]!=ids:raise ValueError('raw group/part remap mismatch')
                vc=raw_mesh.VertexData.Colors; vu=raw_mesh.VertexData.TextureCoordinates1
                if any(i>=len(vc) or i>=len(vu) for i in raw_ids):raise ValueError('original COLOR/UV2 absent; TT defaults forbidden')
                raw_colors=[tuple(int(getattr(vc[i],a)) for a in 'RGBA') for i in raw_ids]
                raw_uv=[(float(vu[i].X),float(vu[i].Y)) for i in raw_ids]
                compare_rows(raw_colors,colors);compare_rows(raw_uv,uv)
                colors=raw_colors;uv=raw_uv
                p['attributes']['COLOR_0']=append_attribute(d,b,colors,'B','VEC4',True)
                p['attributes']['TEXCOORD_1']=append_attribute(d,b,uv,'f','VEC2')
                compare_rows([[x/255 for x in c] for c in colors],accessor(d,b,p['attributes']['COLOR_0']))
                mp=str(Material.ResolveRelativeMaterialPath(group.Material,1)); gm=d['materials'][p['material']]
                if gm['name']!=str(group.Material) or gm.get('extras',{}).get('original_material')!=mp:raise ValueError('material identity')
                materials[mp]=True; gm.setdefault('extras',{}).update(source_binding=mp,shader_status='APPROXIMATE_DATA_ONLY')
                oracle=bytearray()
                for v,c,u in zip(vs,colors,uv):
                    oracle.extend(bytes(c));oracle.extend(struct.pack('<2f',*u))
                oracle_name=name+'.oracle';(out/oracle_name).write_bytes(oracle)
                omitted={}
                for field in fields:
                    if field not in ['Position','Normal','UV1','UV2','VertexColor','BoneIds','Weights']:
                        omitted[field]=[metadata(getattr(v,field)) for v in vs]
                import gzip
                side=name+'.fields.json.gz';(out/side).write_bytes(gzip.compress(json.dumps(omitted,separators=(',',':')).encode('utf-8'),mtime=0))
                result['parts'].append(dict(name=name,group=gi,part=pi,vertices=len(vs),material=mp,oracle=oracle_name,oracle_sha256=digest(oracle),other_fields=side,original_vertex_declaration=metadata(raw_mesh.VertexDataStructList),color_distinct=len(set(colors)),uv2_distinct=len(set(uv)),color_min=[min(c[i] for c in colors) for i in range(4)],color_max=[max(c[i] for c in colors) for i in range(4)]))
        if seen!=set(exported):raise ValueError('extra exported parts')
        for mi,mp in enumerate(materials):
            mr=realm.GetFile[FileResource](mp)
            if mr is None:raise ValueError('source MTRL absent '+mp)
            data=bytes(mr.Data);(out/f'material-{mi}.mtrl').write_bytes(data); mat=Mtrl.GetXivMtrl(mr.Data,mp)
            item=dict(path=mp,sha256=digest(data),bytes=len(data),metadata=metadata(mat),colorset_raw_words=[int(x.RawValue) for x in mat.ColorSetData],additional_data_bytes=[int(x) for x in mat.AdditionalData],textures=[]);result['materials'].append(item)
            for ti,tex in enumerate(mat.Textures):
                tp=str(tex.Dx11Path);tr=realm.GetFile[FileResource](tp);tf=realm.GetFile[TexFile](tp)
                if tr is None or tf is None:raise ValueError('source TEX absent '+tp)
                td=bytes(tr.Data);stem=f'material-{mi}-binding-{ti}';(out/(stem+'.tex')).write_bytes(td)
                bgra=bytes(tf.ImageData);w=int(tf.Header.Width);height=int(tf.Header.Height)
                if len(bgra)!=w*height*4:raise ValueError('unsupported texture extent')
                im=Image.frombytes('RGBA',(w,height),bgra,'raw','BGRA');rgba=im.tobytes();im.save(out/(stem+'.png'))
                if Image.open(out/(stem+'.png')).convert('RGBA').tobytes()!=rgba:raise ValueError('PNG roundtrip corruption')
                (out/(stem+'.rgba')).write_bytes(rgba)
                item['textures'].append(dict(path=tp,sampler_id=int(tex.Sampler.SamplerIdRaw),metadata=metadata(tex),header=metadata(tf.Header),sha256=digest(td),bytes=len(td),png=stem+'.png',rgba=stem+'.rgba',rgba_sha256=digest(rgba),width=w,height=height,nonopaque_alpha=sum(x!=255 for x in rgba[3::4])))
        for k in ['nodes','skins','animations']:
            if d.get(k)!=before.get(k):raise ValueError('existing structure changed '+k)
        if bytes(b[:len(original)])!=original or d['accessors'][:len(before['accessors'])]!=before['accessors'] or d['bufferViews'][:len(before['bufferViews'])]!=before['bufferViews']:raise ValueError('original buffer/accessor mutation')
        path=out/f'm{pair["model"]:04d}.glb';save_glb(path,d,b);rd,rb=read_glb(path.read_bytes())
        if rb[:len(original)]!=original:raise ValueError('roundtrip original corruption')
        result.update(status='PRESERVED_SHADER_OPEN',glb=str(path),glb_sha256=sha(path),original_bin_sha256=digest(original),original_bin_bytes=len(original),baseline_glb=str(manifest.parent/pair['glb']),bone_names=[d['nodes'][i]['name'] for i in d['skins'][0]['joints']],animation_names=[x['name'] for x in d.get('animations',[])])
    except Exception as e:result['blocker']=str(e)
    finally:
        if realm is not None:realm.Dispose()
        write_json(out/'result.json',result)
    return result


def verify_identities(models, baseline):
    if [x['model'] for x in models]!=[x['model'] for x in baseline]:raise ValueError('model identities')
    for actual,old in zip(models,baseline):
        part_id=lambda p:(p['group'],p['part'],p['vertices'],p['material'])
        if [part_id(p) for p in actual['parts']]!=[part_id(p) for p in old['parts']]:raise ValueError('part identities')
        if [m['path'] for m in actual['materials']]!=[m['path'] for m in old['materials']]:raise ValueError('material identities')
        for mat,prior in zip(actual['materials'],old['materials']):
            if mat['sha256']!=prior['sha256'] or mat['bytes']!=prior['bytes']:raise ValueError('material snapshot identity')
            binding=lambda t:(t['path'],t['sampler_id'],t['sha256'],t['bytes'])
            if [binding(t) for t in mat['textures']]!=[binding(t) for t in prior['textures']]:raise ValueError('binding identities')

def main():
    p=argparse.ArgumentParser();p.add_argument('--manifest',type=Path,required=True);p.add_argument('--manifest-sha256',required=True);p.add_argument('--model',type=int,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve()
    if not out.is_relative_to(OUTPUT) or not out.parent.name.startswith('run-'):raise ValueError('new private run output required')
    m=validate(a.manifest,a.manifest_sha256);pair=next(x for x in m['pairs'] if x['model']==a.model)
    r=convert(m,a.manifest,pair,out);validate(a.manifest,a.manifest_sha256);print(r['status'],r.get('blocker',''));return int(r['status']!='PRESERVED_SHADER_OPEN')
if __name__=='__main__':sys.exit(main())
