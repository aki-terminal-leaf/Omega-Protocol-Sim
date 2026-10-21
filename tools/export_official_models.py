#!/usr/bin/env python3
"""Read local FFXIV SqPack files and export textured TOP boss GLBs, optionally with original sampled rigs.

Requires separately installed pythonnet/Pillow, Lumina 6.7 and TexTools 3.1.1.7.
Uses only raw READ APIs, never initializes TexTools' game cache/mod transactions.
Game files and converter binaries are not distributed with this source.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import sys

MODELS = {
    'beetle': {'npc':15708,'model_chara':3771,'model':110,'base':1,'variant':1,'scale':0.9},
    'male': {'npc':15712,'model_chara':3772,'model':513,'base':1,'variant':1,'scale':3.0},
    'female': {'npc':15713,'model_chara':3773,'model':514,'base':1,'variant':1,'scale':3.0},
    'final': {'npc':15717,'model_chara':3775,'model':515,'base':1,'variant':1,'scale':1.4},
    'alpha': {'npc':15725,'model_chara':3524,'model':771,'base':1,'variant':1,'scale':0.8},
    'fist_b5': {'npc':15709,'model_chara':2374,'model':114,'base':5,'variant':1,'animation_variant':2,'scale':1.5},
    'fist_b6': {'npc':15710,'model_chara':2375,'model':114,'base':6,'variant':1,'animation_variant':2,'scale':1.5},
    'arm_left': {'npc':15718,'model_chara':2379,'model':524,'base':2,'variant':1,'scale':1.4},
    'arm_right': {'npc':15719,'model_chara':2378,'model':524,'base':1,'variant':1,'scale':1.4},
    'male_p5': {'npc':15720,'model_chara':3802,'model':513,'base':2,'variant':1,'scale':3.0},
    'female_p5': {'npc':15722,'model_chara':3803,'model':514,'base':2,'variant':1,'scale':3.0},
    'rear_unit': {'npc':15723,'model_chara':2380,'model':525,'base':1,'variant':1,'scale':1.4},
    'meteor': {'npc':15726,'model_chara':3417,'model':213,'base':1,'variant':1,'scale':1.0},
    'comet': {'npc':15727,'model_chara':819,'model':213,'base':1,'variant':2,'scale':1.0},
}

class GLB:
    def __init__(self):
        self.data=bytearray()
        self.doc={'asset':{'version':'2.0','generator':'TOP local SqPack exporter'},'scene':0,'scenes':[{'nodes':[]}],
                  'nodes':[],'meshes':[],'accessors':[],'bufferViews':[],'materials':[],
                  'textures':[],'images':[],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]}
    def view(self, data, target=None):
        self.data.extend(b'\x00'*(-len(self.data)%4));offset=len(self.data);self.data.extend(data)
        view={'buffer':0,'byteOffset':offset,'byteLength':len(data)}
        if target: view['target']=target
        self.doc['bufferViews'].append(view);return len(self.doc['bufferViews'])-1
    def accessor(self, values, components, code='f', target=34962, bounds=False):
        flat=[v for row in values for v in row] if components>1 else values
        view=self.view(struct.pack('<'+str(len(flat))+code,*flat),target)
        acc={'bufferView':view,'componentType':{'f':5126,'I':5125,'H':5123,'B':5121}[code],
             'count':len(values),'type':{1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4',16:'MAT4'}[components]}
        if bounds:
            acc['min']=([min(values)] if components==1 else [min(row[i] for row in values) for i in range(components)])
            acc['max']=([max(values)] if components==1 else [max(row[i] for row in values) for i in range(components)])
        self.doc['accessors'].append(acc);return len(self.doc['accessors'])-1
    def image(self,png,name):
        v=self.view(png);self.doc['images'].append({'bufferView':v,'mimeType':'image/png','name':name})
        self.doc['textures'].append({'sampler':0,'source':len(self.doc['images'])-1});return len(self.doc['textures'])-1
    def save(self,path):
        self.doc['buffers']=[{'byteLength':len(self.data)}]
        j=json.dumps(self.doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4)
        b=bytes(self.data);b+=b'\x00'*(-len(b)%4)
        path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(b))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(b),0x004e4942)+b)

def matrix(trs):
    x,y,z,w=trs['rotation'];sx,sy,sz=trs['scale'];tx,ty,tz=trs['translation']
    return [[(1-2*(y*y+z*z))*sx,2*(x*y-z*w)*sy,2*(x*z+y*w)*sz,tx],
            [2*(x*y+z*w)*sx,(1-2*(x*x+z*z))*sy,2*(y*z-x*w)*sz,ty],
            [2*(x*z-y*w)*sx,2*(y*z+x*w)*sy,(1-2*(x*x+y*y))*sz,tz],[0,0,0,1]]
def multiply(a,b):return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def inverse(m):
    # General Gauss-Jordan inversion preserves nonuniform original bone scales.
    a=[row[:]+[float(i==j) for j in range(4)] for i,row in enumerate(m)]
    for i in range(4):
        pivot=max(range(i,4),key=lambda k:abs(a[k][i]));a[i],a[pivot]=a[pivot],a[i]
        if abs(a[i][i])<1e-12:raise ValueError('Singular original bind transform')
        v=a[i][i];a[i]=[x/v for x in a[i]]
        for j in range(4):
            if j!=i:
                f=a[j][i];a[j]=[x-f*y for x,y in zip(a[j],a[i])]
    return [r[4:] for r in a]
def quat_product(a,b):
    x,y,z,w=a;xx,yy,zz,ww=b
    return [w*xx+x*ww+y*zz-z*yy,w*yy-x*zz+y*ww+z*xx,w*zz+x*yy-y*xx+z*ww,w*ww-x*xx-y*yy-z*zz]
def relative_pose(child,parent):
    q=parent['rotation'];norm=sum(v*v for v in q);iq=[-q[0]/norm,-q[1]/norm,-q[2]/norm,q[3]/norm]
    delta=[c-p for c,p in zip(child['translation'],parent['translation'])]
    rotated=quat_product(quat_product(iq,delta+[0]),q)
    return {'translation':[v/scale if abs(scale)>1e-8 else 0 for v,scale in zip(rotated[:3],parent['scale'])],
            'rotation':quat_product(iq,child['rotation']),
            'scale':[c/p if abs(p)>1e-8 else 1 for c,p in zip(child['scale'],parent['scale'])]}
def install_rig(glb,rig):
    # Godbert getReferencePose is local, but getPose returns MODEL-SPACE poses.
    # Convert animation samples before assigning hierarchical glTF channels.
    if rig.get('animation_space','model')=='model':
        for clip in rig['animations']:
            clip['frames']=[[relative_pose(b,frame[rig['bones'][i]['parent']]) if rig['bones'][i]['parent']>=0 else b for i,b in enumerate(frame)] for frame in clip['frames']]
        rig['animation_space']='local'
    bones=rig['bones'];start=len(glb.doc['nodes']);global_matrices={}
    def global_matrix(i):
        if i not in global_matrices:
            local=matrix(bones[i]);parent=bones[i]['parent']
            global_matrices[i]=multiply(global_matrix(parent),local) if parent>=0 else local
        return global_matrices[i]
    for i,b in enumerate(bones):
        node={k:b[k] for k in ['name','translation','rotation','scale']};children=[start+j for j,c in enumerate(bones) if c['parent']==i]
        if children:node['children']=children
        glb.doc['nodes'].append(node)
        if b['parent']<0:glb.doc['scenes'][0]['nodes'].append(start+i)
    inverse_bind=[]
    for i in range(len(bones)):
        inv=inverse(global_matrix(i));inverse_bind.append([inv[row][column] for column in range(4) for row in range(4)])
    glb.doc['skins']=[{'name':'Original_FFXIV_Rig','joints':list(range(start,start+len(bones))),'inverseBindMatrices':glb.accessor(inverse_bind,16,target=None)}]
    animations=[]
    for clip in rig['animations']:
        if clip['duration']<=0 or len(clip['times'])<2:continue
        animation={'name':clip['name'],'samplers':[],'channels':[]}
        for i,b in enumerate(bones):
            for path,components in [('translation',3),('rotation',4),('scale',3)]:
                samples=[frame[i][path] for frame in clip['frames']]
                if all(max(abs(x-y) for x,y in zip(v,b[path]))<2e-6 for v in samples):continue
                if path=='rotation':
                    for j in range(1,len(samples)):
                        if sum(x*y for x,y in zip(samples[j-1],samples[j]))<0:samples[j]=[-v for v in samples[j]]
                constant=all(max(abs(x-y) for x,y in zip(v,samples[0]))<2e-6 for v in samples)
                times=[clip['times'][0],clip['times'][-1]] if constant else clip['times']
                values=[samples[0],samples[-1]] if constant else samples
                ti=glb.accessor(times,1,target=None,bounds=True);vi=glb.accessor(values,components,target=None)
                animation['samplers'].append({'input':ti,'output':vi,'interpolation':'LINEAR'})
                animation['channels'].append({'sampler':len(animation['samplers'])-1,'target':{'node':start+i,'path':path}})
        if animation['channels']:animations.append(animation)
    glb.doc['animations']=animations
    return {b['name']:i for i,b in enumerate(bones)}

def initialize(args):
    if args.pythonnet_dir:sys.path.insert(0,str(args.pythonnet_dir))
    from pythonnet import load
    args.output.mkdir(parents=True,exist_ok=True)
    runtime=args.output/'export.runtimeconfig.json'
    runtime.write_text(json.dumps({'runtimeOptions':{'tfm':'net8.0','framework':{'name':'Microsoft.NETCore.App','version':'8.0.0'}}}))
    load('coreclr',runtime_config=str(runtime))
    import clr
    libs=args.textools_dir/'lib'
    for p in [args.lumina_dir,libs]:
        sys.path.insert(0,str(p))
        if os.name=='nt':os.add_dll_directory(str(p))
    for n in ['CommunityToolkit.HighPerformance','BCnEncoder','Microsoft.Extensions.ObjectPool','Lumina']:
        clr.AddReference(str(args.lumina_dir/(n+'.dll')))
    for n in ['SharpDX','SharpDX.Mathematics','Newtonsoft.Json','HelixToolkit.SharpDX.Core','MathNet.Numerics','xivModdingFramework']:
        clr.AddReference(str(libs/(n+'.dll')))
    from Lumina import GameData,LuminaOptions
    opts=LuminaOptions();opts.LoadMultithreaded=False
    return GameData(str(args.game_dir/'game'/'sqpack'),opts)

def bake_original_colorset(glb,realm,material,gmat,maximum=1024):
    """Bake original legacy color-table diffuse/emission into standard glTF maps.

    Row pairs are selected by the original index image (R /17, G blend).
    This preserves source colours/HDR intensity, not the full game shader.
    """
    from Lumina.Data.Files import TexFile
    from PIL import Image
    bindings={int(t.Sampler.SamplerIdRaw):str(t.Dx11Path) for t in material.Textures}
    base=bindings.get(0x115306BE);index=bindings.get(1449103320)
    if not base or not index or len(material.ColorSetData)<1024:return
    def original(path):
        tex=realm.GetFile[TexFile](path)
        if tex is None:raise RuntimeError('Missing original color-table image: '+path)
        return Image.frombytes('RGBA',(int(tex.Header.Width),int(tex.Header.Height)),bytes(tex.ImageData),'raw','BGRA')
    image=original(base).convert('RGB');image.thumbnail((maximum,maximum),Image.Resampling.LANCZOS);indices=original(index).resize(image.size,Image.Resampling.BILINEAR)
    rows=[float(str(v)) for v in material.ColorSetData]
    def srgb(x):return round(255*(12.92*x if x<=0.0031308 else 1.055*x**(1/2.4)-0.055))
    linear=[(v/255/12.92 if v/255<=0.04045 else ((v/255+0.055)/1.055)**2.4) for v in range(256)]
    strength=max([1.0]+[rows[r*32+c] for r in range(32) for c in [8,9,10]])
    diffuse_table=[];emission_table=[]
    for red in range(256):
        row=min(15,max(0,round(red/17)))*2
        for green in range(256):
            blend=1-green/255
            def value(column):return max(0.0,rows[row*32+column]*(1-blend)+rows[min(31,row+1)*32+column]*blend)
            diffuse_table.append(tuple(value(c) for c in range(3)))
            emission_table.append(tuple(srgb(min(1.0,value(c+8)/strength)) for c in range(3)))
    def pixels(im):return im.get_flattened_data() if hasattr(im,'get_flattened_data') else im.getdata()
    ids=[r*256+g for r,g,_b,_a in pixels(indices)]
    diffuse=Image.new('RGB',image.size);diffuse.putdata([tuple(max(0,min(255,srgb(min(1.0,linear[p[c]]*diffuse_table[i][c])))) for c in range(3)) for p,i in zip(pixels(image),ids)])
    emission=Image.new('RGB',image.size);emission.putdata([emission_table[i] for i in ids])
    def texture(im,name):
        stream=io.BytesIO();im.save(stream,format='PNG');return glb.image(stream.getvalue(),name)
    gmat['pbrMetallicRoughness']['baseColorTexture']={'index':texture(diffuse,base+' [original colorset bake]')}
    if emission.getbbox():
        gmat['emissiveTexture']={'index':texture(emission,index+' [original colorset emission]')};gmat['emissiveFactor']=[1,1,1]
        gmat.setdefault('extensions',{})['KHR_materials_emissive_strength']={'emissiveStrength':strength}
        used=glb.doc.setdefault('extensionsUsed',[])
        if 'KHR_materials_emissive_strength' not in used:used.append('KHR_materials_emissive_strength')
    gmat['extras']['colorset_bake']={'rows':32,'index_source':index,'emissive_strength':strength,'scope':'original diffuse/emission tables; specular, tiling and particle effects remain approximations'}

def export_model(realm,args,form,meta):
    from Lumina.Data import FileResource
    from Lumina.Data.Files import TexFile
    from Lumina.Models.Materials import Material
    from xivModdingFramework.Models.FileTypes import Mdl
    from xivModdingFramework.Materials.FileTypes import Mtrl
    from PIL import Image,ImageOps
    mid,bid=meta.get('model',0),meta.get('base',0)
    path=meta.get('source_path') or f'chara/monster/m{mid:04d}/obj/body/b{bid:04d}/model/m{mid:04d}b{bid:04d}.mdl'
    raw=realm.GetFile[FileResource](path)
    if raw is None:raise RuntimeError('Missing local game asset: '+path)
    model=Mdl.GetTTModel(raw.Data,path).GetAwaiter().GetResult()
    # ModelChara.Variant is an IMC variant, not necessarily material vNNNN.
    # Monster IMC has one6-byte entry per variant after its4-byte header.
    imc_path=f'chara/monster/m{mid:04d}/obj/body/b{bid:04d}/b{bid:04d}.imc'
    imc=realm.GetFile[FileResource](imc_path) if not meta.get('source_path') else None
    material_variant=meta.get('variant',1); variant_details={}
    if imc is not None:
        data=bytes(imc.Data);count,parts=struct.unpack_from('<HH',data)
        if parts!=1:raise RuntimeError('Unexpected multipart monster IMC: '+imc_path)
        if not 0<=meta['variant']<=count:raise RuntimeError('Missing IMC variant: '+imc_path)
        offset=4+6*meta['variant'];material_variant=data[offset]
        variant_details={'source_path':imc_path,'variant':meta['variant'],'material':material_variant,'attribute_mask':struct.unpack_from('<H',data,offset+2)[0]&0x3ff,'vfx':data[offset+4],'material_animation':data[offset+5]&15}
        if material_variant==0:
            # IMC intentionally hides this body. Export its original default
            # geometry only as an inspection/attachment anchor, never label it
            # a reconstruction of the variant's VFX appearance.
            variant_details['body_hidden']=True
            material_variant=data[4]
            variant_details['inspection_material']=material_variant


    glb=GLB();tex_cache={};mat_cache={};mesh_info=[]
    rig_path=args.rig_dir/(form+'.json') if args.rig_dir else None
    rig=json.loads(rig_path.read_text()) if rig_path and rig_path.exists() else None
    bone_map=install_rig(glb,rig) if rig else {}
    for gi,group in enumerate(model.MeshGroups):
        mpath=str(group.Material) if str(group.Material).startswith('bg/') else Material.ResolveRelativeMaterialPath(group.Material,material_variant)
        if mpath not in mat_cache:
            mraw=realm.GetFile[FileResource](mpath)
            mat=Mtrl.GetXivMtrl(mraw.Data,mpath)
            pbr={'metallicFactor':0.25,'roughnessFactor':0.65,'baseColorFactor':[1,1,1,1]}
            gmat={'name':group.Material,'pbrMetallicRoughness':pbr,'doubleSided':True,
                  'extras':{'original_material':mpath,'original_shader':mat.ShaderPackRaw,'shader_fidelity':'PBR approximation, not the game shader'}}
            for tex in mat.Textures:
                usage={0x115306BE:'Diffuse',0x0C5EC1F1:'Normal',510652316:'Diffuse',2863978985:'Normal'}.get(int(tex.Sampler.SamplerIdRaw),'Other')
                if usage not in ['Diffuse','Normal']:continue
                tp=str(tex.Dx11Path)
                key=tp+':'+usage
                if key not in tex_cache:
                    tf=realm.GetFile[TexFile](tp)
                    if tf is None:raise RuntimeError('Missing texture: '+tp)
                    im=Image.frombytes('RGBA',(int(tf.Header.Width),int(tf.Header.Height)),bytes(tf.ImageData),'raw','BGRA')
                    im.thumbnail((getattr(args,'max_texture_size',1024),getattr(args,'max_texture_size',1024)),Image.Resampling.LANCZOS)
                    # Character texture alpha contains shader information, not general opacity.
                    # Preserve opaque game surfaces rather than turning the whole mesh invisible.
                    if usage=='Diffuse':im.putalpha(255)
                    elif meta.get('source_path'):
                        r,g,b,a=im.split();im=Image.merge('RGBA',(r,ImageOps.invert(g),b,a))
                    else:
                        r,g,_b,a=im.split();g=ImageOps.invert(g)
                        # Legacy monster normal B stores opacity, not normal Z.
                        # Reconstruct the positive tangent normal from original XY.
                        pixels=lambda image:image.get_flattened_data() if hasattr(image,'get_flattened_data') else image.getdata()
                        z=Image.new('L',im.size);z.putdata([round(127.5*(1+max(0.0,1-(rr/127.5-1)**2-(gg/127.5-1)**2)**0.5)) for rr,gg in zip(pixels(r),pixels(g))])
                        im=Image.merge('RGBA',(r,g,z,a))
                    data=io.BytesIO();im.save(data,format='PNG');tex_cache[key]=glb.image(data.getvalue(),tp)
                if usage=='Diffuse':pbr['baseColorTexture']={'index':tex_cache[key]}
                else:gmat['normalTexture']={'index':tex_cache[key],'scale':0.65}
            if getattr(args,'bake_colorset',False) and str(mat.ShaderPackRaw)=='characterlegacy.shpk':bake_original_colorset(glb,realm,mat,gmat,getattr(args,'max_texture_size',1024))
            glb.doc['materials'].append(gmat);mat_cache[mpath]=len(glb.doc['materials'])-1
        for pi,part in enumerate(group.Parts):
            if not part.Vertices.Count or not part.TriangleIndices.Count:continue
            attrs=sorted(str(a) for a in part.Attributes)
            if 'atr_lod' in attrs:continue
            vertices=list(part.Vertices)
            positions=[(float(v.Position.X),float(v.Position.Y),float(v.Position.Z)) for v in vertices]
            normals=[(float(v.Normal.X),float(v.Normal.Y),float(v.Normal.Z)) for v in vertices]
            uv=[(float(v.UV1.X),float(v.UV1.Y)) for v in vertices]
            indices=[int(i) for i in part.TriangleIndices]
            if max(indices)>=len(vertices) or len(indices)%3:raise RuntimeError('Invalid triangle indices')
            name=f'{form}_g{gi}_p{pi}'+('_'+'_'.join(attrs) if attrs else '')
            primitive={'attributes':{'POSITION':glb.accessor(positions,3,bounds=True),'NORMAL':glb.accessor(normals,3),'TEXCOORD_0':glb.accessor(uv,2)},'indices':glb.accessor(indices,1,'I',34963),'material':mat_cache[mpath]}
            if rig:
                group_bones=[str(b) for b in group.Bones]
                joint_ids=[];weights=[]
                for vertex in vertices:
                    ids=[];ws=[]
                    for local_id,weight in zip(vertex.BoneIds,vertex.Weights):
                        weight=int(weight);local_id=int(local_id)
                        if weight:
                            if local_id>=len(group_bones) or group_bones[local_id] not in bone_map:raise RuntimeError('Unmapped original bone')
                            ids.append(bone_map[group_bones[local_id]]);ws.append(weight/255)
                        else:ids.append(0);ws.append(0.0)
                    total=sum(ws)
                    if total<=0:ws[0]=1;total=1
                    joint_ids.append(ids);weights.append([w/total for w in ws])
                for index in range(2):
                    primitive['attributes']['JOINTS_'+str(index)]=glb.accessor([v[index*4:index*4+4] for v in joint_ids],4,'H')
                    primitive['attributes']['WEIGHTS_'+str(index)]=glb.accessor([v[index*4:index*4+4] for v in weights],4)
            glb.doc['meshes'].append({'name':name,'primitives':[primitive]})
            glb.doc['nodes'].append({'name':name,'mesh':len(glb.doc['meshes'])-1,'extras':{'ffxiv_attributes':attrs}})
            if rig:glb.doc['nodes'][-1]['skin']=0
            glb.doc['scenes'][0]['nodes'].append(len(glb.doc['nodes'])-1)
            mesh_info.append({'name':name,'vertices':len(vertices),'triangles':len(indices)//3,'attributes':attrs})
    glb.doc['asset']['extras']={'source_game_path':path,'source_sha256':hashlib.sha256(bytes(raw.Data)).hexdigest(),'pose':'original sampled resident animations' if rig else 'unanimated bind pose','copyright':'SQUARE ENIX','source_ids':meta}
    target=args.output/(form+'.glb');glb.save(target)
    return dict(meta,imc=variant_details,form=form,file=target.name,bytes=target.stat().st_size,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),source_path=path,source_sha256=hashlib.sha256(bytes(raw.Data)).hexdigest(),parts=mesh_info,animations=[a['name'] for a in glb.doc.get('animations',[])],bones=len(rig['bones']) if rig else 0,limitations=([] if rig else ['Static bind pose; no official skeleton animation'])+(['Original colorset diffuse/emission baked; specular, tiling and VFX remain approximations'] if getattr(args,'bake_colorset',False) else ['PBR shader approximates original legacy shader; colorset/emission/VFX not reconstructed'])+['Part/stance mapping requires visual calibration'])

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for n in ['game-dir','lumina-dir','textools-dir','output']:parser.add_argument('--'+n,type=Path,required=True)
    parser.add_argument('--pythonnet-dir',type=Path)
    parser.add_argument('--max-texture-size',type=int,default=1024,help='Runtime texture limit; original mesh/rig and source hashes remain unchanged')
    parser.add_argument('--bake-colorset',action='store_true',help='Bake original legacy index/color-table diffuse and HDR emission into glTF')
    parser.add_argument('--extract-rigs-only',action='store_true',help='Read local SKLB and resident PAP files for the 32-bit sampler')
    parser.add_argument('--rig-dir',type=Path,help='Original skeleton/resident animation samples from sample_official_animations.py')
    parser.add_argument('--forms',nargs='+',choices=list(MODELS),default=list(MODELS))
    args=parser.parse_args()
    if args.max_texture_size<1:parser.error('Texture limit must be positive')
    realm=initialize(args)
    if args.extract_rigs_only:
        from Lumina.Data import FileResource
        for form in args.forms:
            mid=MODELS[form]['model']; animation_variant=MODELS[form].get('animation_variant',1)
            for ext,source in [('sklb',f'chara/monster/m{mid:04d}/skeleton/base/b0001/skl_m{mid:04d}b0001.sklb'),('pap',f'chara/monster/m{mid:04d}/animation/a{animation_variant:04d}/bt_common/resident/monster.pap')]:
                raw=realm.GetFile[FileResource](source)
                if raw is None:raise RuntimeError('Missing original rig asset: '+source)
                (args.output/(form+'.'+ext)).write_bytes(bytes(raw.Data))
                print(form,ext,len(raw.Data),flush=True)
        realm.Dispose();return
    manifest={'format':1,'provenance':'locally extracted original game meshes/textures, not procedural replicas','models':{}}
    for form in args.forms:
        result=export_model(realm,args,form,MODELS[form]);manifest['models'][form]=result
        print(json.dumps({'form':form,'bytes':result['bytes'],'parts':len(result['parts']),'sha256':result['sha256']}),flush=True)
        (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    realm.Dispose()
if __name__=='__main__':main()
