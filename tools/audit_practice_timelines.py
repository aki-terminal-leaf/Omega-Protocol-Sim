#!/usr/bin/env python3
"""Re-derive anonymous per-drill timing observations from verified TOP captures.

Uses collect_fflogs.py manifests; no credentials/player identities in output.
Origins are explicit. Inferred practice lead-ins are not original spawn evidence.
"""
import argparse,gzip,hashlib,json
from pathlib import Path

def grouped(values):
    groups=[]
    for t in sorted(set(values)):
        if not groups or t-groups[-1][-1]>.2:groups.append([])
        groups[-1].append(t)
    return [round(g[0],3) for g in groups]

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    # phase, anchor type, anchor IDs, normalized clock origin shift, duration, impact IDs
    specs={
      'p1_loop':(1,'applydebuff',[1003004],0,44,{'towers':[31492],'blaster':[31498]}),
      'p1_panto':(1,'cast',[31499],0,33,{'missiles':[31502],'beams':[31503],'flames':[31501,32368],'puddles':[31500]}),
      'p1_cannons':(1,'cast',[31504],-6,16,{'cleaves':[31504],'spreads':[31505]}),
      'p2_synergy':(2,'begincast',[31550],0,34.7,{'double_aoes':[31525,31526,31530,31533],'fire':[31535],'laser':[31521],'discharger':[31534],'spotlight':[31536],'prepare_swap':[31515,31516],'disappear':[31510,31511],'visual_swap':[31517,31518],'reappear':[31519,31520]}),
      'p2_limitless':(2,'cast',[31544],0,39,{'arrow':[31539],'bladedance':[32629],'defense':[31528],'flares':[31538],'pitch':[31529],'raidwide':[31524]}),
      'p3_transition':(3,'applydebuff',[1003425],0,24,{'rings':[31567,31568,31569,31570],'arms':[31566],'sniper':[31571,31572]}),
      'p3_hello':(3,'applydebuff',[1003434],0,110,{'towers':[31583,31584],'critical_error':[31588]}),
      'p3_monitors':(3,'begincast',[31595,31596],0,11,{'monitors':[31597]}),
      'p4_wave':(4,'begincast',[31617],0,45,{'proteans':[31614],'repeats':[31616],'stacks':[31615],'rings':[31567,31568,31569,31570]}),
      'p5_delta':(5,'applydebuff',[1003442],0,54,{'laser':[31521],'fists':[31482],'arms':[31600,31601],'defense':[31528],'pitch':[31529],'monitors':[31597],'swivel':[31636,31637],'world':[31625,33040],'jumps':[31626,33041]}),
      'p5_sigma':(5,'applydebuff',[1003427,1003428],0,59,{'arms':[31602],'cannons':[31604],'discharger':[31534],'towers':[31492,31493],'lasers':[31631,31632],'female_aoe':[31530,31533],'world':[31625,33040],'jumps':[31626,33041]}),
      'p5_omega':(5,'begincast',[32789],0,65,{'clone_aoes':[31525,31526,31530,31533],'diffuse':[31609],'world':[31625,33040],'jumps':[31626,33041],'monitors':[31597],'blaster':[32373]}),
      'p5_solar':(5,'begincast',[33196,33197],0,9,{'first':[33196,33197],'second':[31489,31490]}),
      'p6_memory':(6,'begincast',[31649],0,7,{'memory':[31649]}),
      'p6_arrow_dive':(6,'begincast',[31650],0,24,{'arrows':[31651,31652],'dive':[31655,31656]}),
      'p6_arrow_wave':(6,'begincast',[31650],0,27,{'arrows':[31651,31652],'proteans':[31659],'charge':[31658]}),
      'p6_exa_wave':(6,'begincast',[31660],0,35,{'first_exas':[31661],'exas':[31662],'puddles':[31663],'proteans':[31659],'charge':[31658]}),
      'p6_exa_dive':(6,'begincast',[31660],0,27,{'first_exas':[31661],'exas':[31662],'puddles':[31663],'dive':[31655,31656]}),
      'p6_meteors':(6,'begincast',[31664],0,31,{'puddles':[31666],'spreads':[32699],'flares':[31668],'stack':[31667]}),
      'p6_magic':(6,'begincast',[31670],0,23,{'magic_number':[31670]})}
    out={'schema':1,'scope':'finite four-clear observations, not exhaustive RNG/server-frame certification','clustering_seconds':.2,'mechanics':{k:{'phase':s[0],'anchor_type':s[1],'anchor_ids':s[2],'origin_shift':s[3],'samples':[]} for k,s in specs.items()}}
    for mf in sorted(a.input.glob('*/*/manifest.json')):
        m=json.loads(mf.read_text());assert m.get('complete'),mf
        data={}
        for f in m['files']:
            raw=gzip.decompress((mf.parent/f['file']).read_bytes());assert hashlib.sha256(raw).hexdigest()==f['sha256'];data[f['file']]=json.loads(raw)
        es=sorted([e for seg in m['replay_segments'] for e in data[seg['file']]['events']],key=lambda e:e['timestamp']);fs=m['fight_metadata']['phases']
        def aid(e):return e.get('ability',{}).get('guid',0)
        for key,(phase,kind,anchors,shift,duration,groups) in specs.items():
            start=fs[phase-1]['startTime'];end=fs[phase]['startTime'] if phase<6 else m['fight_metadata']['end_time'];ev=[e for e in es if start<=e['timestamp']<end]
            candidates=[e for e in ev if e['type']==kind and aid(e) in anchors]
            assert candidates,(m['report'],key)
            if key=='p5_solar':selected=candidates
            elif key in ['p6_arrow_wave','p6_exa_dive']:selected=candidates[1:2]
            else:selected=candidates[:1]
            for index,anchor in enumerate(selected):
                base=anchor['timestamp']+shift*1000
                # Omega drill starts at first clone tell, not version cast. Only
                # the relative13.2s source model lead-in is inferred here.
                if key=='p5_omega':
                    hit=next(e for e in ev if e['type']=='cast' and aid(e) in [31525,31526,31530,31533] and e['timestamp']>base+5000)
                    base=hit['timestamp']-13200
                result={name:grouped([(e['timestamp']-base)/1000 for e in ev if e['type']=='cast' and aid(e) in ids and base-1<=e['timestamp']<=base+duration*1000]) for name,ids in groups.items()}
                out['mechanics'][key]['samples'].append({'report':m['report'],'fight':m['fight'],'occurrence':index,'events':result})
    for key,row in out['mechanics'].items():
        row['original_anchor_measured']=key not in ['p1_cannons','p5_omega']
        row['event_ids']=specs[key][5]
        row['unavailable_events']=[name for name in specs[key][5] if not any(s['events'][name] for s in row['samples'])]
        row['ranges']={}
        for event in specs[key][5]:
            arrays=[s['events'][event] for s in row['samples'] if s['events'][event]]
            row['ranges'][event]=[{'min':round(min(arr[i] for arr in arrays if len(arr)>i),3),'max':round(max(arr[i] for arr in arrays if len(arr)>i),3)} for i in range(max(map(len,arrays),default=0))]
        print(key, {k:v for k,v in row['ranges'].items() if k not in ['arrows','exas','puddles','arms','jumps']})
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
