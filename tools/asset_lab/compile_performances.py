#!/usr/bin/env python3
"""Bind unit review windows to original record events, never to video time.
Review bounds/padding are NOT source host stop commands or acceptance.
Private original media stay in the supplied cache, not in this output.
"""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
# Inclusive source-selection ranges. Every bound must be an actual record event,
# phase marker or record end. Overlapping requirements may share source events.
RANGES={
 'P1':[(0,10066),(11132,29133),(21155,29401),(38260,38348),(47261,47305),(56215,56305),(64409,79515),(81520,86065),(87490,92075),(93500,98089),(99514,101520),(108195,114436),(114436,119471)],
 'P2':[(119471,123659),(131813,131813),(145180,148211),(157790,159884),(158593,158593),(158593,158593),(164070,165362),(163981,168075),(172173,176505),(176548,176638),(189925,206553),(203387,213726),(224600,224822),(227544,227989),(236598,238159),(250734,252205)],
 'P3':[(250734,266114),(265044,271243),(265044,279581),(273204,279581),(279091,279091),(287297,292290),(315432,326661),(336465,347792),(357507,367941),(378552,392148),(400709,400709),(410908,422183),(412199,422272),(426281,434135)],
 'P4':[(441265,453108),(455565,461150),(463243,471280),(473469,487223),(488297,503446)],
 'P5-Delta':[(512831,524088),(532669,537630),(547955,550952),(547955,560831),(559535,563825),(566015,571646),(571066,571691),(580006,584077),(584791,593089)],
 'P5-Sigma':[(603173,619787),(641114,642187),(637187,643396),(650727,654658),(666056,669054),(666056,676664),(678945,680955)],
 'P5-Omega':[(692617,709241),(709241,731733),(726561,727674),(730662,731733),(744371,746381),(760444,764380),(775822,798833)],
 'P6':{'02':(860627,866615),'03':(870770,874702),'04':(875013,884980),'05':(883012,895122),'06':(890162,898206),'07':(909157,924181),'08':(922170,932173),'09':(932306,943558),'10':(951914,965989),'11':(966079,977463),'12':(985797,1008844),'13':(1003937,1011972),'14':(1026157,1035132),'15':(1036339,1043388),'16':(1042359,1043388),'17':(1054423,1055402),'18':(1061524,1066488),'19':(1077655,1082621),'20':(1091786,1109404)}}

def compile_units(data,catalog,attachment_sha256="",catalog_sha256=""):
 raw={n:(data/(n+'.json')).read_bytes() for n in ['record','full-data','motion-plan','manifest','scene-data','weapon-data']}
 record=json.loads(raw['record']);full=json.loads(raw['full-data']);weapons=json.loads(raw['weapon-data']);events=record['events'];bounds={}
 for i,e in enumerate(events):bounds.setdefault(e['t'],[]).append(i)
 phases={x['t']:x for x in record['phase_markers']};duration=int(record['duration_ms'])
 result={'schema':1,'status':'SOURCE_SELECTIONS_NOT_PERFORMANCE_ACCEPTANCE','all96_accepted':False,'source_hashes':{},'attachment_sha256':attachment_sha256,'catalog_sha256':catalog_sha256,'compiler_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'units':{}}
 for name in ['record','full-data','motion-plan','manifest','scene-data','weapon-data']:result['source_hashes'][name+'.json']=hashlib.sha256(raw[name]).hexdigest()
 for unit in catalog['units']:
  uid=unit['id'];group,number=uid.rsplit('-',1);ranges=RANGES.get(group,{})
  if isinstance(ranges,list):
   if not number.isdecimal() or not 1<=int(number)<=len(ranges):raise ValueError('Invalid source unit ordinal: '+uid)
   first,last=ranges[int(number)-1]
  elif number in ranges:first,last=ranges[number]
  else:result['units'][uid]={'status':'MISSING_CINEMATIC_DIRECTOR','accepted':False};continue
  proof=[]
  for t in [first,last]:
   if not (t in bounds or t in phases or t==duration):raise ValueError(str((uid,t,'unproven review boundary')))
   proof.append({'time_ms':t,'event_indexes':bounds.get(t,[]),'phase_marker':phases.get(t),'record_end':t==duration})
  actions=set(unit['actions']);indexes=[i for i,e in enumerate(events) if first<=e['t']<=last and e.get('a') in actions and e['type'] in ['cast','begincast']]
  # Include only proven preparation packets for the selected same-source cast.
  resolve={(events[i]['t'],events[i].get('s'),events[i]['a']) for i in indexes if events[i]['type']=='cast'}
  for i,e in enumerate(events):
   if e['type']=='begincast' and e.get('castSuccessful') and (e['t']+e.get('castDuration',-1),e.get('s'),e.get('a')) in resolve:indexes.append(i)
  indexes=sorted(set(indexes))
  if not indexes:
   result['units'][uid]={'status':'NO_ORIGINAL_TRANSITION_EVIDENCE','accepted':False,'boundary_proof':proof};continue
  anchors={(events[i]['t'],str(events[i].get('s','')),events[i]['a']) for i in indexes}
  keys=[c['key'] for c in full['cues'] if (c['anchor'],str(c['source']),c['ability']) in anchors]
  for i in indexes:
   event=events[i]
   if event['type']!='cast':continue
   for node in weapons.get('actions',{}).get(str(event['a']),{}).get('nodes',[]):keys.append('weapon/'+str(int(event['t']))+'/'+str(event['s'])+'/'+str(int(node['id'])))
  action_keys=sorted(set(keys));context_keys=[]
  for cue in full.get('bodyCues',[]):
   if first<=cue['start']<=last:keys.append(cue['key']);context_keys.append(cue['key'])
  tethers=[]
  for event in full.get('tether_events',[]):
   if first<=event['t']<=last:key='tether/'+str(int(event['event_index']));keys.append(key);tethers.append(key);context_keys.append(key)
  start=max(0,min([first]+[events[i]['t'] for i in indexes])-1000);end=min(duration+1,last+6000)
  phase=int(unit['phase'][1]);prior_tethers=[{'key':'tether/'+str(int(e['event_index'])),'start_ms':e['t'],'state':'UNKNOWN_IF_STILL_ACTIVE_NOT_RENDERED_AS_ZERO'} for e in full.get('tether_events',[]) if e.get('phase')==phase and e['t']<first and e.get('end') is None]
  limits=['Body/tether selections are temporal context, not proven action ownership.','Review boundaries are not source spawn/despawn or host-stop events.','Unrecorded branches, precast FX, player pose, audio and cinematic gates remain open.','Tethers without removal events remain unresolved; review selection does not verify lifetime.']
  if not indexes:limits.append('No requested cast/begincast recorded in this selection.')
  result['units'][uid]={'status':'COMPOSITE_SOURCE_SELECTION_OPEN','accepted':False,'source_selection_ms':[first,last],'review_window_ms':[start,end],'boundary_proof':proof,'event_indexes':indexes,'cue_keys':sorted(set(keys)),'action_cue_keys':action_keys,'context_cue_keys':sorted(set(context_keys)),'unresolved_prior_tethers':prior_tethers,'tether_keys':tethers,'verified_stops':{},'actions':sorted(actions),'review_padding_ms':[first-start,end-last],'limitations':limits}
 if len(result['units'])!=96:raise ValueError('Expected all96 inventory entries')
 return result

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--data',type=Path,required=True);ap.add_argument('--catalog',type=Path,default=ROOT/'top/data/asset_lab/catalog.json');ap.add_argument('--out',type=Path,required=True);ap.add_argument('--attachments',type=Path,required=True);a=ap.parse_args()
 if a.out.exists():raise SystemExit('Fresh output required')
 catbytes=a.catalog.read_bytes();result=compile_units(a.data,json.loads(catbytes),hashlib.sha256(a.attachments.read_bytes()).hexdigest(),hashlib.sha256(catbytes).hexdigest());a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n');print(json.dumps({'units':len(result['units']),'source_selections':sum('review_window_ms' in u for u in result['units'].values()),'all96_accepted':False}))
if __name__=='__main__':main()
