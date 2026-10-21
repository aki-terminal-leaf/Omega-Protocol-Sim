#!/usr/bin/env python3
"""Verify full captures and derive anonymous TOP timing/pattern observations.

Input is collect_fflogs.py output. Reported durations are log observations, not
proof of server collision rules. Proxy NPC sourceResources can be stale/default;
only explicitly validated coordinates enter the finite pattern observations.
"""
import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
import json
import math
from pathlib import Path
from statistics import median


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    result={'schema':1,'scope':'public FFLogs observations; no player names, credentials, or gear; not exhaustive server proof',
            'coordinate_units':'(logged x/y - 10000) / 100; north negative y',
            'position_caution':'FFLogs proxy/helper coordinates may be stale or default; validated geometric families only, not all cast locations',
            'sources':[],'status_durations':{},'loop':[],'hello_world':[],'world_pulses':[],'exaflares':[],'arrows':[]}
    statuses=defaultdict(lambda:{'names':set(),'samples':Counter(),'phases':defaultdict(Counter),'count':0})
    for path in sorted(a.input.glob('*/*/manifest.json')):
        m=json.loads(path.read_text());d=path.parent
        if not m.get('complete'):raise ValueError('Incomplete capture: '+str(path))
        data={}
        for f in m['files']:
            raw=gzip.decompress((d/f['file']).read_bytes())
            if hashlib.sha256(raw).hexdigest()!=f['sha256']:raise ValueError('Checksum mismatch: '+f['file'])
            data[f['file']]=json.loads(raw)
        segments=m['replay_segments'];fight=m['fight_metadata'];t0=fight['start_time'];end=fight['end_time']
        if segments[0]['start']!=t0 or segments[-1]['end']!=end or any(y['start']!=x['end']+1 for x,y in zip(segments,segments[1:])):raise ValueError('Replay coverage gap')
        ev=sorted((e for s in segments for e in data[s['file']]['events']),key=lambda e:e['timestamp'])
        castpages=data['enemy-casts.json.gz']['pages']
        if castpages[-1].get('next'):raise ValueError('Unfinished casts pagination')
        source={'report':m['report'],'fight':m['fight'],'url':m['source_url'],'retrieved_utc':m['retrieved_utc'],'boss':fight['boss'],
                'kill':fight['kill'],'start':t0,'end':end,'phases':fight.get('phases',[]),'casts':m['cast_events'],'replay_events':m['replay_events'],
                'replay_segments':len(segments),'casts_pages':len(castpages),'verified_sha256_files':len(m['files'])}
        result['sources'].append(source)
        def phase(e):
            return max((s['id'] for s in fight.get('phases',[]) if s['startTime']<=e['timestamp']),default=1)
        def ref():return {'report':m['report'],'fight':m['fight']}
        def pos(e):
            r=e.get('sourceResources',{})
            return [(r['x']-10000)/100,(r['y']-10000)/100] if 'x' in r and 'y' in r else None
        def cast(id):return [e for e in ev if e['type']=='cast' and e.get('ability',{}).get('guid')==id]
        def groups(xs,gap):
            out=[]
            for e in xs:
                if not out or e['timestamp']-out[-1][-1]['timestamp']>gap:out.append([])
                out[-1].append(e)
            return out
        for e in ev:
            if e['type']!='applydebuff' or not e.get('targetIsFriendly') or e.get('sourceIsFriendly') or not e.get('duration'):continue
            id=str(e['ability']['guid']);s=statuses[id];s['names'].add(e['ability']['name']);s['samples'][e['duration']]+=1;s['phases'][phase(e)][e['duration']]+=1;s['count']+=1
        towers=[e for e in cast(31492) if phase(e)==1]
        loops=[]
        for g in groups(towers,500):
            pts=[pos(e) for e in g]
            valid=all(v and sorted(abs(x) for x in v)==[3.0,12.0] for v in pts)
            loops.append({'seconds':round((g[0]['timestamp']-t0)/1000,3),'slots':pts,'valid_slot_observation':valid})
        result['loop'].append({**ref(),'tower_waves':loops})
        smells=[e for e in ev if e['type']=='applydebuff' and e.get('ability',{}).get('guid')==1003434]
        if smells:
            hw0=smells[0]['timestamp'];tower_times=sorted(set(e['timestamp'] for e in cast(31583)+cast(31584)))
            result['hello_world'].append({**ref(),'initial_status_seconds':round((hw0-t0)/1000,3),'latent_sync_targets':len(set(e['targetID'] for e in smells)),
               'tower_seconds_from_initial_smells':sorted(set(round((t-hw0)/1000,3) for t in tower_times))})
        for g in groups(sorted(cast(31625)+cast(31626)+cast(33040)+cast(33041),key=lambda e:e['timestamp']),5000):
            first=g[0]['timestamp']
            result['world_pulses'].append({**ref(),'first_seconds':round((first-t0)/1000,3),'events':[{'offset':round((e['timestamp']-first)/1000,3),'ability':e['ability']['guid'],'target':e.get('targetID')} for e in g]})
        for g in groups(cast(31661),1500):
            pts=[pos(e) for e in g]
            angles=[(math.degrees(math.atan2(v[0],-v[1]))+360)%360 if v else None for v in pts]
            valid=len(g)==4 and all(v and abs(math.hypot(*v)-24)<0.03 for v in pts) and all(abs(x/45-round(x/45))<0.001 for x in angles)
            steps=[((b-a+180)%360)-180 for a,b in zip(angles,angles[1:])] if valid else []
            valid=valid and all(abs(x-steps[0])<0.01 for x in steps) and abs(abs(steps[0])-45)<0.01
            first=g[0]['timestamp']
            result['exaflares'].append({**ref(),'first_seconds':round((first-t0)/1000,3),'origins':pts,'angles_north_cw':angles,
               'first_offsets':[round((e['timestamp']-first)/1000,3) for e in g],'validated_adjacent45_radius24':valid,'direction':1 if valid and steps[0]>0 else -1 if valid else None})
        for g in groups(cast(31651),3000):
            first=g[0]['timestamp'];first_count=sum(e['timestamp']-first<300 for e in g);last=first+18000
            rest=[e for e in cast(31652) if first<=e['timestamp']<last]
            result['arrows'].append({**ref(),'first_seconds':round((first-t0)/1000,3),'family':'center_first' if first_count==2 else 'sides_first' if first_count==4 else 'unknown',
               'initial_casts':len(g),'rest_casts':len(rest),'delayed_group_seconds':round((g[first_count]['timestamp']-first)/1000,3) if first_count<len(g) else None,
               'first_origins':[pos(e) for e in g], 'first_offsets':[round((e['timestamp']-first)/1000,3) for e in g]})
    for id,s in sorted(statuses.items(),key=lambda x:int(x[0])):
        result['status_durations'][id]={'names':sorted(s['names']),'count':s['count'],'reported_duration_ms':dict(sorted(s['samples'].items())),
                                     'by_phase':{str(k):dict(sorted(v.items())) for k,v in sorted(s['phases'].items())}}
    result['totals']={'complete_fights':len(result['sources']),'enemy_casts':sum(s['casts'] for s in result['sources']),'replay_events':sum(s['replay_events'] for s in result['sources'])}
    if not result['sources']:raise ValueError('No complete capture found')
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result['totals']));print('Exaflare observations',sum(x['validated_adjacent45_radius24'] for x in result['exaflares']));print('Arrow families',dict(Counter(x['family'] for x in result['arrows'])))

if __name__=='__main__':main()
