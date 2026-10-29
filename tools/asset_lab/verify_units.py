#!/usr/bin/env python3
"""Independent source-event oracle for generated per-unit cue selections.
Checks provenance/isolation, not completeness of the chosen visual requirements.
"""
import argparse,hashlib,json
from pathlib import Path
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--data',type=Path,required=True);ap.add_argument('--selections',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--attachments',type=Path,required=True);a=ap.parse_args()
if a.out.exists():raise SystemExit('Fresh oracle output required')
s=json.loads(a.selections.read_text());r=json.loads((a.data/'record.json').read_text());f=json.loads((a.data/'full-data.json').read_text());w=json.loads((a.data/'weapon-data.json').read_text());events=r['events'];errors=[];known={};cases=0
for cue in f['cues']:known[cue['key']]={'kind':'action','anchor':cue['anchor'],'source':str(cue['source']),'action':cue['ability']}
for e in events:
 if e['type']=='cast':
  for n in w.get('actions',{}).get(str(e['a']),{}).get('nodes',[]):known[f"weapon/{int(e['t'])}/{e['s']}/{int(n['id'])}"]={'kind':'action','anchor':e['t'],'source':str(e['s']),'action':e['a']}
for cue in f['bodyCues']:known[cue['key']]={'kind':'body','anchor':cue['anchor']}
for e in f['tether_events']:known['tether/'+str(int(e['event_index']))]={'kind':'tether','anchor':e['t']}
for file,digest in s['source_hashes'].items():
 if hashlib.sha256((a.data/file).read_bytes()).hexdigest()!=digest:errors.append('source_pin/'+file)
if hashlib.sha256(a.attachments.read_bytes()).hexdigest()!=s['attachment_sha256']:errors.append('attachment_pin')
for uid,u in s['units'].items():
 if 'review_window_ms' not in u:
  if uid not in ['P6-01a','P6-01b','P6-01c','P6-21','P6-22','P6-23','P1-13']:errors.append('unexpected_missing/'+uid)
  continue
 cases+=1;first,last=u['source_selection_ms'];start,end=u['review_window_ms'];indexes=set(u['event_indexes']);anchors=set()
 if not 0<=start<=first<=last<end<=r['duration_ms']+1:errors.append('bad_view_domain/'+uid)
 if u['verified_stops']:errors.append('synthesized_stop/'+uid)
 for p in u['boundary_proof']:
  if any(events[i]['t']!=p['time_ms'] for i in p['event_indexes']):errors.append('invalid_boundary_proof/'+uid)
 for i in indexes:
  e=events[i]
  if e['type'] not in ['cast','begincast'] or e['a'] not in u['actions']:errors.append('unrelated_event/'+uid+'/'+str(i))
  if not first<=e['t']<=last:
   matching=any(events[j]['type']=='cast' and events[j]['s']==e['s'] and events[j]['a']==e['a'] and events[j]['t']==e['t']+e.get('castDuration',-1) for j in indexes)
   if e['type']!='begincast' or not e.get('castSuccessful') or not matching:errors.append('unproven_prepare/'+uid+'/'+str(i))
  anchors.add((e['t'],str(e['s']),e['a']))
 for key in u['cue_keys']:
  cue=known.get(key)
  if cue is None:errors.append('unknown_cue/'+uid+'/'+key);continue
  if cue['kind']=='action':
   if (cue['anchor'],cue['source'],cue['action']) not in anchors:errors.append('unrelated_cue/'+uid+'/'+key)
  elif not first<=cue['anchor']<=last:errors.append('unrelated_context/'+uid+'/'+key)
 for i in indexes:
  e=events[i]
  if not start<=e['t']<end:errors.append('preparation_outside_review/'+uid+'/'+str(i))
 for key,cue in known.items():
  if cue['kind']=='action' and (cue['anchor'],cue['source'],cue['action']) in anchors and key not in u['cue_keys']:errors.append('selected_cast_cue_omitted/'+uid+'/'+key)
for group in [['P1-03','P1-04','P1-05','P1-06'],['P1-08','P1-09','P1-10','P1-11'],['P3-07','P3-08','P3-09','P3-10']]:
 seen=set()
 for uid in group:
  own={k for k in s['units'][uid]['cue_keys'] if known[k]['kind']=='action'}
  if own&seen:errors.append('round_reuses_cast/'+uid)
  seen|=own
result={'status':'PASS' if not errors else 'FAIL','source_selections_checked':cases,'source_units':len(s['units']),'errors':errors,'all96_or_visual_acceptance':False,'source_selection_sha256':hashlib.sha256(a.selections.read_bytes()).hexdigest()};a.out.write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(bool(errors))
