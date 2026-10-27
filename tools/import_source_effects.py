#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Import a hash-verified private Lumina bundle into the optional Godot source pack.
No game assets are embedded in source. Reads public-format TMB/AVFX fields only;
compiled documents retain unsupported flags and never claim complete playback.
"""
from pathlib import Path, PurePosixPath
import argparse,json,hashlib,shutil,csv,struct,os,re
import avfx_preview_pack,avfx_resources
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--bundle',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--action-index',type=Path)
parser.add_argument('--proof',type=Path,required=True)
a=parser.parse_args();bundle=a.bundle;out=a.output
out.mkdir(parents=True,exist_ok=True)
for name in ['packs','textures']:(out/name).mkdir(exist_ok=True)
catalog=json.loads((out/'catalog.json').read_text()) if (out/'catalog.json').exists() else {'schema':1,'video':'https://www.youtube.com/watch?v=5P8VnTECmO4','rendering_complete':False}
def publish_json(path,value):
 tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(value,separators=(',',':'),allow_nan=False));os.replace(tmp,path)
m=json.loads((bundle/'manifest.json').read_text());tex=dict(catalog.get('textures',{}));packs=dict(catalog.get('packs',{}));fail=[];closure=[]
assert not catalog.get('game_version') or catalog['game_version']==m['game_version']
for path,row in m['resources'].items():
 assert re.fullmatch(r'[a-zA-Z0-9_./-]+',path) and not PurePosixPath(path).is_absolute() and '..' not in PurePosixPath(path).parts
 assert hashlib.sha256((bundle/'raw'/path).read_bytes()).hexdigest()==row['sha256'],path
for row in m['textures']:
 assert hashlib.sha256((bundle/row['file']).read_bytes()).hexdigest()==row['sha256'],row['file']
for row in m['textures']:
 name=Path(row['file']).name;shutil.copy2(bundle/row['file'],out/'textures'/name);tex[row['source']]='res://assets/official/source/textures/'+name
for path,row in m['resources'].items():
 if not path.endswith('.avfx'):continue
 raw=(bundle/'raw'/path).read_bytes()
 for ref in avfx_resources.texture_references(raw):
  assert ref in tex,(path,ref)
  closure.append([path,ref])
 try:
  name=hashlib.sha256(path.encode()).hexdigest()[:20]+'.json'
  if (out/'packs'/name).exists():
   doc=json.loads((out/'packs'/name).read_text());assert doc['source_sha256']==row['sha256']
  else:
   doc=avfx_preview_pack.compile_pack(raw);doc.pop('raw_avfx_base64',None);publish_json(out/'packs'/name,doc)
  packs[path]={'file':'res://assets/official/source/packs/'+name,'sha256':row['sha256'],'groups':{g:len(v) for g,v in doc['groups'].items()},'unsupported':len(doc['unsupported'])}
 except Exception as e:fail.append({'path':path,'error':str(e)})
# Parse established public TMB node structures. Unknown node types retained, never guessed.
timelines=dict(catalog.get('timelines',{}))
for path in m['resources']:
 if not path.endswith('.tmb'):continue
 b=(bundle/'raw'/path).read_bytes();assert b[:4]==b'TMLB';size,count=struct.unpack_from('<II',b,4);assert size==len(b);off=12;nodes=[]
 for _ in range(count):
  tag=b[off:off+4].decode();n=struct.unpack_from('<I',b,off+4)[0];assert n>=8 and off+n<=len(b);d=off+8;row={'tag':tag}
  def st(field):
   ptr=struct.unpack_from('<i',b,d+field)[0];pos=d+ptr;assert 0<=pos<len(b);return b[pos:b.index(0,pos)].decode()
  def li(field):
   ptr,num=struct.unpack_from('<ii',b,d+field);assert 0<=num<1000 and 0<=d+ptr<=len(b)-2*num;return list(struct.unpack_from('<'+str(num)+'h',b,d+ptr))
  if tag in ['TMAC','TMTR','C010','C012','C063']:row.update(zip(['id','time'],struct.unpack_from('<hh',b,d)))
  if tag=='TMAC':row.update(ability_delay=struct.unpack_from('<i',b,d+4)[0],track_ids=li(12))
  if tag=='TMTR':row['entry_ids']=li(4)
  if tag=='C010':row.update(zip(['duration','unknown_1','flags','animation_start','animation_end'],struct.unpack_from('<iiiff',b,d+4)));row['path']=st(24)
  if tag=='C063':row.update(loop_and_duration=struct.unpack_from('<i',b,d+4)[0],path=st(12))
  if tag=='C012':
   assert n==0x48;row.update(duration=struct.unpack_from('<i',b,d+4)[0],path=st(12))
   for k,fp in [(1,16),(2,20)]:
    origin,typ,ident=struct.unpack_from('<bbh',b,d+fp);row['bind_'+str(k)]={'origin':origin,'type':typ,'id':ident}
   for name,fp,dim in [('scale',24,3),('rotation_radians',32,3),('position',40,3),('rgba',48,4)]:
    ptr,dims=struct.unpack_from('<ii',b,d+fp);assert dims==dim and 0<=d+ptr<len(b)-dim*4+1;row[name]=list(struct.unpack_from('<'+str(dim)+'f',b,d+ptr))
  nodes.append(row);off+=n
 ids={n['id']:n for n in nodes if 'id' in n}
 for actor in [n for n in nodes if n['tag']=='TMAC']:
  for tid in actor['track_ids']:
   for eid in ids[tid]['entry_ids']:
    if eid in ids:ids[eid]['owner']={'actor_id':actor['id'],'actor_time':actor['time'],'ability_delay':actor['ability_delay'],'track_id':tid,'track_time':ids[tid]['time']}
 timelines[path]={'sha256':m['resources'][path]['sha256'],'nodes':nodes}

actions=dict(catalog.get('actions',{}))
if a.action_index:
 with a.action_index.open(encoding='utf-8-sig') as f:
  for row in csv.DictReader(f):
   row['ability_id']=int(row['ability_id']);row['phase']=int(row['phase']);row['tmbs']={}
   for val in row['source_tmbs'].split(';'):
    if val:
     kind,path=val.split(':',1);row['tmbs'][kind]=path
   entries=actions.setdefault(str(row['ability_id']),[])
   if row not in entries:entries.append(row)
catalog.update(game_version=m['game_version'],textures=tex,packs=packs,timelines=timelines,actions=actions)
publish_json(out/'catalog.json',catalog)
proof={'packs':len(packs),'failures':fail,'texture_edges_verified':len(closure),'textures':len(tex),'timelines':len(timelines),'abilities':len(actions),'bundle_sha256':hashlib.sha256((bundle/'manifest.json').read_bytes()).hexdigest(),'catalog_sha256':hashlib.sha256((out/'catalog.json').read_bytes()).hexdigest(),'rendering_complete':False}
publish_json(a.proof,proof);print(json.dumps(proof))
raise SystemExit(1 if fail else 0)
