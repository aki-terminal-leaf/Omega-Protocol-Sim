#!/usr/bin/env python3
"""Rebuild private M/F cues from original TMBs resolved by current appearance."""
from pathlib import Path
import argparse,json,gzip,base64,hashlib,shutil
p=argparse.ArgumentParser(description=__doc__)
for n in ['input','context','audio-prior','out']:p.add_argument('--'+n,type=Path,required=True)
a=p.parse_args();I=a.input.resolve();C=a.context.resolve();O=a.out.resolve()
if O.exists():raise FileExistsError('Use a fresh output; accepted input/evidence must not be overwritten')
def readjs(path,name):
 s=path.read_text();prefix='window.'+name+'='
 if not s.startswith(prefix):raise ValueError('Unexpected data prefix '+str(path))
 return json.loads(s[len(prefix):].rstrip(';\r\n '))
def sha(b):return hashlib.sha256(b).hexdigest()
M=readjs(I/'manifest.js','TOP_MANIFEST');F=readjs(I/'full-data.js','TOP_FULL');R=readjs(I/'record.js','TOP_RECORD');T=json.loads((C/'timelines.json').read_text());packs=json.loads((C/'packs.json').read_text());events=json.loads((C/'events.json').read_text());raw=json.loads((C/'bundle/manifest.json').read_text());textures=json.loads((C/'bundle/textures.json').read_text());prior=json.loads(a.audio_prior.read_text());extra=json.loads((C/'selected-audio-proof.json').read_text());shutil.copytree(I,O)
def add(key,b,kind):
 z=gzip.compress(b,mtime=0);(O/'assets'/(key+'.js')).write_text('window.TOP_ASSETS['+json.dumps(key)+']='+json.dumps(base64.b64encode(z).decode())+';');M['assets'][key]={'file':'assets/'+key+'.js','bytes':len(b),'compressed_bytes':len(z),'sha256':sha(b),'kind':kind}
for row in textures['textures']:
 b=(C/'bundle'/row['file']).read_bytes();assert sha(b)==row['sha256'];key='full_tex_'+Path(row['file']).stem;add(key,b,'png');F['textures'][row['source']]=key
for path,doc in packs.items():
 assert path in raw['resources'];key='full_fx_'+sha(path.encode())[:20];add(key,json.dumps(doc,separators=(',',':'),allow_nan=False).encode(),'json');F['packs'][path]=key
streams={}
for row in prior['decoded']+extra['decoded']:
 key='audio_'+Path(row['file']).stem;streams[(row['source'],row['sound_index'])]={'asset':key,'seconds':row['seconds']}
for row in extra['decoded']:
 b=(C/'selected-audio'/row['file']).read_bytes();assert sha(b)==row['sha256'];assert row['source_sha256']==raw['resources'][row['source']]['sha256'];add('audio_'+Path(row['file']).stem,b,'encoded_audio')
indexes={e['event_index'] for e in events};anchors={(e['anchor'],e['source'],e['ability']) for e in events};old_cues=[c for c in F['cues'] if c['event_index'] in indexes];F['cues']=[c for c in F['cues'] if c['event_index'] not in indexes]
def old_audio(c):
 parts=c['key'].split('|',3)
 try:return (int(parts[0]),parts[1],int(parts[2])) in anchors
 except (ValueError,IndexError):return False
removed_audio=sum(old_audio(c) for c in F['audioCues']);F['audioCues']=[c for c in F['audioCues'] if not old_audio(c)]
new_cues=[];new_audio=[];missing=[];skipped_audio=[];seen=set();source_roots=[]
for ctx in events:
 e=R['events'][ctx['event_index']];assert e['s']==ctx['source'] and e['a']==ctx['ability'] and e['t']==ctx['anchor'];tl=T.get(ctx['path'])
 if not tl:missing.append(ctx);continue
 assert tl['sha256']==raw['resources'][ctx['path']]['sha256'];source_roots.append({'event_index':ctx['event_index'],'path':ctx['path'],'sha256':tl['sha256'],'form':ctx['form']})
 for n in tl['nodes']:
  if n['tag'] not in ['C012','C063']:continue
  key='ctx|'+str(ctx['event_index'])+'|'+ctx['kind']+'|'+str(n['id'])+'|'+n['path'];assert key not in seen;seen.add(key);start=e['t']+n['time']/30*1000
  if n['tag']=='C012':
   if n['path'] not in F['packs']:missing.append({**ctx,'missing_effect':n['path']});continue
   envelope=max(6000,min(30000,max(0,n['duration'])/30*1000+3000))
   c={'key':key,'start':start,'end':min(R['duration_ms'],start+envelope),'anchor':e['t'],'source':e['s'],'target':e.get('d'),'ability':e['a'],'phase':e['phase'],'kind':ctx['kind'],'node':n,'event_index':ctx['event_index'],'source_pos':e.get('source_pos'),'target_pos':e.get('target_pos'),'lifecycle_basis':'source graph inside bounded preview; original host-stop semantics OPEN','path':n['path'],'sourceForm':ctx['form'],'sourceTimeline':ctx['path']};new_cues.append(c)
  else:
   ref=streams.get((n['path'],n['sound_index']))
   if not ref:skipped_audio.append({**ctx,'path':n['path'],'sound_index':n['sound_index']});continue
   new_audio.append({'key':key,'start':start,'end':min(R['duration_ms'],start+ref['seconds']*1000),'asset':ref['asset'],'source':e['s'],'target':e.get('d'),'positionFlags':n['position_flags'],'soundIndex':n['sound_index'],'phase':e['phase'],'loop_and_duration':n['loop_and_duration'],'sourceForm':ctx['form'],'sourceTimeline':ctx['path'],'lifecycle_basis':'exact selected stream; original host loop/mix OPEN'})
F['cues']=sorted(F['cues']+new_cues,key=lambda c:c['start']);F['audioCues']=sorted(F['audioCues']+new_audio,key=lambda c:c['start']);assert len({c['key'] for c in F['cues']})==len(F['cues'])
for c in new_cues:
 ids=set(F['phase_assets'][str(c['phase'])]);ids.add(F['packs'][c['path']]);doc=packs.get(c['path'])
 if doc:ids.update(F['textures'][t] for t in doc['textures'])
 else:
  # Existing pack may be reused; its declared textures already belong to its phase cache.
  raise RuntimeError('Correct-context effect must be in this verified closure: '+c['path'])
 F['phase_assets'][str(c['phase'])]=sorted(ids)
proof={'events_resolved':len(events),'old_MF_effect_cues_removed':len(old_cues),'new_actual_form_effect_cues':len(new_cues),'old_MF_audio_cues_removed':removed_audio,'new_actual_form_audio_cues':len(new_audio),'new_exact_audio_streams':len(extra['decoded']),'unresolved_timelines_or_effects':missing,'unresolved_audio':skipped_audio,'source_roots':source_roots,'rendering_complete':False,'host_stop_and_parent_track_semantics':'OPEN','specialized_four_weapon_path':'unchanged'};F['audio_skipped']=[c for c in F.get('audio_skipped',[]) if c.get('event_index') not in indexes]+skipped_audio;F['contextCorrection']={k:v for k,v in proof.items() if k!='source_roots'}
(O/'manifest.js').write_text('window.TOP_MANIFEST='+json.dumps(M,separators=(',',':'))+';');(O/'full-data.js').write_text('window.TOP_FULL='+json.dumps(F,separators=(',',':'),allow_nan=False)+';');(O/'action-context-proof.json').write_text(json.dumps(proof,indent=2));print(json.dumps({k:v for k,v in proof.items() if k not in ['source_roots','unresolved_timelines_or_effects']},indent=2))
