#!/usr/bin/env python3
"""Private replay cache -> native data; extracted media must never enter Git."""
import argparse,base64,hashlib,io,json,re,struct,gzip,copy
from pathlib import Path
from PIL import Image

def read_js(path):
 s=path.read_text(encoding='utf-8');return json.loads(s[s.index('=')+1:].strip().removesuffix(';'))

def native_glb(data,fixes=None):
 magic,version,length=struct.unpack_from('<III',data);assert (magic,version,length)==(0x46546c67,2,len(data))
 size,tag=struct.unpack_from('<II',data,12);doc=json.loads(data[20:20+size]);off=20+size
 bsize,btag=struct.unpack_from('<II',data,off);binary=bytearray(data[off+8:off+8+bsize])
 for im in doc.get('images',[]):
  if im.get('mimeType')!='image/webp':continue
  view=doc['bufferViews'][im['bufferView']];start=view.get('byteOffset',0)
  b=binary[start:start+view['byteLength']];out=io.BytesIO();Image.open(io.BytesIO(b)).save(out,format='PNG')
  binary.extend(b'\0'*(-len(binary)%4));im['bufferView']=len(doc['bufferViews']);im['mimeType']='image/png'
  doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(out.getvalue())});binary.extend(out.getvalue())
 # glTF requires strictly increasing key times. The source sampler duplicates its
 # endpoint after float32 packing; collapse ONLY exactly equal times/values.
 def packed(accessor):
  a=doc['accessors'][accessor];v=doc['bufferViews'][a['bufferView']]
  assert a['componentType']==5126 and 'sparse' not in a
  width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]*4
  stride=v.get('byteStride',width);start=v.get('byteOffset',0)+a.get('byteOffset',0)
  return a,width,[bytes(binary[start+i*stride:start+i*stride+width]) for i in range(a['count'])]
 def append_accessor(prior,width,rows):
  binary.extend(b'\0'*(-len(binary)%4));off=len(binary);binary.extend(b''.join(rows))
  view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(rows)*width})
  a=copy.deepcopy(prior);a['bufferView']=view;a['byteOffset']=0;a['count']=len(rows)
  index=len(doc['accessors']);doc['accessors'].append(a);return index
 for animation in doc.get('animations',[]):
  for si,sampler in enumerate(animation['samplers']):
   ac,width,rows=packed(sampler['input']);times=[struct.unpack('<f',v)[0] for v in rows]
   if all(times[i]>times[i-1] for i in range(1,len(times))):continue
   assert all(times[i]>=times[i-1] for i in range(1,len(times))), 'Decreasing source animation time'
   assert sampler.get('interpolation','LINEAR') in ['LINEAR','STEP'], 'Unsupported duplicate cubic keys'
   out,ow,values=packed(sampler['output']);assert len(values)==len(times)
   keep=[]
   for i,t in enumerate(times):
    if i and t==times[i-1]:
     assert values[i]==values[i-1], 'Equal-time source keys have DIFFERENT values; needs source investigation'
    else:keep.append(i)
   sampler['input']=append_accessor(ac,width,[rows[i] for i in keep]);sampler['output']=append_accessor(out,ow,[values[i] for i in keep])
   if fixes is not None:fixes.append({'animation':animation['name'],'sampler':si,'removed':len(times)-len(keep),'basis':'exact float32 time AND value identity'})
 for texture in doc.get('textures',[]):
  ext=texture.get('extensions',{}).pop('EXT_texture_webp',None)
  if ext:texture['source']=ext['source']
 for key in ('extensionsUsed','extensionsRequired'):
  if key in doc:doc[key]=[x for x in doc[key] if x!='EXT_texture_webp']
 binary.extend(b'\0'*(-len(binary)%4));doc['buffers'][0]['byteLength']=len(binary)
 j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4)
 return struct.pack('<III',magic,version,12+8+len(j)+8+len(binary))+struct.pack('<II',len(j),tag)+j+struct.pack('<II',len(binary),btag)+binary

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--data',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
 args.out.mkdir(parents=True,exist_ok=False);(args.out/'assets').mkdir();m=read_js(args.data/'manifest.js');hashes={};kinds={};time_fixes={}
 for key,spec in m['assets'].items():
  s=(args.data/spec['file']).read_text();match=re.search(r'\]\s*=\s*"([A-Za-z0-9+/=]+)"',s)
  if not match:raise ValueError('Unsupported wrapper: '+key)
  b=gzip.decompress(base64.b64decode(match[1]));assert len(b)==spec['bytes'],key
  assert hashlib.sha256(b).hexdigest()==spec['sha256'],key
  kind=spec.get('kind','glb');ext={'glb':'glb','png':'png','json':'json','encoded_audio':'ogg'}[kind]
  if kind=='glb':
   fixes=[];b=native_glb(b,fixes)
   if fixes:time_fixes[key]=fixes
  rel='assets/'+key+'.'+ext;(args.out/rel).write_bytes(b);hashes[rel]=hashlib.sha256(b).hexdigest();kinds[key]={'file':rel,'kind':kind}
 for name in ('manifest','record','scene-data','weapon-data','full-data'):
  d=read_js(args.data/(name+'.js'))
  if name=='manifest':d['native_assets']=kinds
  if name=='weapon-data' and d.get('legClip'):
   clip=d['legClip'];ft=lambda v:struct.unpack('<f',struct.pack('<f',v))[0];keep=[]
   for i,t in enumerate(clip['times']):
    if i and ft(t)==ft(clip['times'][i-1]):
     for bone in clip['bones']:
      for field,width in [('translation',3),('rotation',4),('scale',3)]:
       assert all(ft(bone[field][i*width+j])==ft(bone[field][(i-1)*width+j]) for j in range(width)), 'Duplicate supplemental leg key differs'
    else:keep.append(i)
   if len(keep)!=len(clip['times']):
    for bone in clip['bones']:
     for field,width in [('translation',3),('rotation',4),('scale',3)]:bone[field]=[bone[field][i*width+j] for i in keep for j in range(width)]
    clip['times']=[clip['times'][i] for i in keep]

  (args.out/(name+'.json')).write_text(json.dumps(d,separators=(',',':')),encoding='utf-8')
 proof={'input':str(args.data),'assets':len(kinds),'hashes':hashes,'rendering_complete':False,'native_validation':'NOT_RUN','animation_time_fixes':time_fixes,'conversion':'WebP to PNG; retain original accessor bytes, collapse only value-identical duplicate float32 animation times; original shaders NOT reproduced'}
 (args.out/'conversion-proof.json').write_text(json.dumps(proof,indent=2));print(json.dumps({'assets':len(kinds),'output':str(args.out)}))
if __name__=='__main__':main()
