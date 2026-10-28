from pathlib import Path
import sys,os,json,hashlib,struct,collections,shutil,csv
if len(sys.argv)!=2:raise SystemExit('Usage: compile_resources.py FRESH_PRIVATE_WORKSPACE_WITH_bundle_DIRECTORY')
P=Path(sys.argv[1]).resolve();R=Path(__file__).resolve().parents[2]
if any((P/n).exists() for n in ['packs.json','timelines.json','compile-proof.json']):raise FileExistsError('Use a fresh workspace; accepted compiler evidence is immutable')
sys.path.insert(0,str(R/'tools'));import avfx_preview_pack as pack,avfx_meshes as mesh,avfx_curves as curves
# Source fields preserved and parsed, never relabel unsupported renderer capabilities.
pack.DATA_CURVES.update({'Wd','WdR','WdB','WdBR','WdC','WdCR','WdE','WdER','Len','LenR','CF','CFR','Sft','SftR','PnDs','Wdt','WdtR'})
pack.DATA_COLORS.update({'ColC','CoEB','CoEC','CoEE'})
m=json.loads((P/'bundle/manifest.json').read_text());packs={};fail=[];timelines={}
for path,row in m['resources'].items():
 b=(P/'bundle/raw'/path).read_bytes();assert hashlib.sha256(b).hexdigest()==row['sha256']
 if path.endswith('.avfx'):
  try:
   doc=pack.compile_pack(b);doc.pop('raw_avfx_base64',None)
   roots=mesh.blocks(mesh.blocks(b)[0][1]);binders=[v for t,v in roots if t=='Bind']
   for node,payload in zip(doc['groups']['Bind'],binders):
    properties={}
    for tag,payload in mesh.blocks(payload):
     if tag not in ('PrpS','PrpG'):continue
     prop={}
     for t,v in mesh.blocks(payload):
      if t=='Pos':prop[t]=pack.strip_raw(curves.decode_axes(v))
      elif t in ('RnPX','RnPY','RnPZ','RnRd'):prop[t]=struct.unpack('<f',v)[0]
      elif t=='Name':prop[t]={'raw':v.hex()}
      elif len(v) in (1,2,4):prop[t]=pack.literal(v)
      else:prop[t]={'raw':v.hex()}
     properties[tag]=prop
    node['properties']=properties
   packs[path]=doc
  except Exception as e:fail.append({'path':path,'error':str(e)})
 if not path.endswith('.tmb'):continue
 assert b[:4]==b'TMLB';size,count=struct.unpack_from('<II',b,4);assert size==len(b);off=12;nodes=[]
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
  if tag=='C063':row.update(loop_and_duration=struct.unpack_from('<i',b,d+4)[0],path=st(12),sound_index=struct.unpack_from('<i',b,d+16)[0],position_flags=b[d+20],bind_id=b[d+21])
  if tag=='C012':
   assert n==0x48;row.update(duration=struct.unpack_from('<i',b,d+4)[0],path=st(12))
   for k,fp in [(1,16),(2,20)]:
    origin,typ,ident=struct.unpack_from('<bbh',b,d+fp);row['bind_'+str(k)]={'origin':origin,'type':typ,'id':ident}
   for name,fp,dim in [('scale',24,3),('rotation_radians',32,3),('position',40,3),('rgba',48,4)]:
    ptr,dims=struct.unpack_from('<ii',b,d+fp);assert dims==dim and 0<=d+ptr<len(b)-dim*4+1;row[name]=list(struct.unpack_from('<'+str(dim)+'f',b,d+ptr))
  nodes.append(row);off+=n
 assert off<=len(b)
 ids={n['id']:n for n in nodes if 'id' in n}
 for actor in [n for n in nodes if n['tag']=='TMAC']:
  for tid in actor['track_ids']:
   for eid in ids[tid]['entry_ids']:
    if eid in ids:ids[eid]['owner']={'actor_id':actor['id'],'actor_time':actor['time'],'ability_delay':actor['ability_delay'],'track_id':tid,'track_time':ids[tid]['time']}
 timelines[path]={'sha256':m['resources'][path]['sha256'],'nodes':nodes}
(P/'packs.json').write_text(json.dumps(packs,separators=(',',':'),allow_nan=False));(P/'timelines.json').write_text(json.dumps(timelines,indent=2,allow_nan=False))
summary={'packs':len(packs),'failed_packs':fail,'timelines':len(timelines),'particle_types':dict(collections.Counter(str(n['values'].get('PrVT')) for doc in packs.values() for n in doc['groups']['Ptcl'])),'binder_source_types':dict(collections.Counter(str(n.get('properties',{}).get('PrpS',{}).get('BPTP')) for doc in packs.values() for n in doc['groups']['Bind'])),'C012_binding_combinations':dict(collections.Counter(json.dumps(n['bind_1']) for t in timelines.values() for n in t['nodes'] if n['tag']=='C012')),'unsupported_reasons':dict(collections.Counter(v['reason'] for doc in packs.values() for v in doc['unsupported'])),'rendering_complete':False}
(P/'compile-proof.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
