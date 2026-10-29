#!/usr/bin/env python3
"""Independent original-channel and record-placement check for Godot composition."""
import argparse,json,math
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation
from verify_motion import source,expected
p=argparse.ArgumentParser();p.add_argument('--data',type=Path,required=True);p.add_argument('--states',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
m=json.loads((a.data/'manifest.json').read_text());r=json.loads((a.data/'record.json').read_text());plan=json.loads((a.data/'motion-plan.json').read_text());w=json.loads((a.data/'weapon-data.json').read_text());states=json.loads(a.states.read_text());cache={};count=0;cases=0;maximum=0;root_max=0;fail=[]
for snap in states['snapshots']:
 t=snap['clock_ms']
 for actor in snap['actors']:
  key,form=actor['id'],actor['form'];binding=plan['actors'][key];motion=next(x for x in reversed(binding['motions']) if x['start']<=t);clip=motion['clip']
  if form not in cache:cache[form]=source(a.data/m['native_assets'][form]['file'])
  doc,reader=cache[form]
  anim=next((x for x in doc.get('animations',[]) if x['name']==clip),None)
  if anim is not None or clip==w['legClip']['name']:
   duration=w['legClip']['duration'] if clip==w['legClip']['name'] else max(reader(s['input'])[-1,0] for s in anim['samplers']);period=motion.get('period',0) or duration;seconds=(t-motion.get('anchor',0))/1000*motion.get('rate',1)+motion.get('offset',0);seconds=np.clip(seconds,0,max(0,duration-.00001)) if motion.get('once') else seconds%period
   oracle=expected(doc,reader,clip,float(seconds),w['legClip']);cases+=1
   for sk in actor['motion']['skeletons']:
    for name,flat in sk.items():
     if name not in oracle:fail.append({'missing_bone':name});continue
     err=float(np.max(np.abs(np.array(flat).reshape(4,4,order='F')-oracle[name])));maximum=max(maximum,err);count+=1
     if err>.0002:fail.append({'actor':key,'form':form,'bone':name,'t':t,'error':err})
  track=np.array(r['tracks'][key]);idx=int(np.searchsorted(track[:,0],t,side='right')-1);recon=snap.get('reconstructed_preparations',{}).get(key)
  if recon and recon['start']<=t<=recon['end']:
   pos=np.array(recon['position'][:2]);heading=recon['position'][2]
  else:
   assert idx>=0;pos=track[idx,1:3].copy();heading=track[idx,3]
   if idx+1<len(track):
    dt=track[idx+1,0]-track[idx,0];dist=np.linalg.norm(track[idx+1,1:3]-pos)
    if 0<dt<=1500 and dist<=12*dt/1000:pos+=(track[idx+1,1:3]-pos)*np.clip((t-track[idx,0])/dt,0,1)
  root=np.eye(4);root[:3,:3]=Rotation.from_euler('y',math.pi/2-heading/100).as_matrix();root[:3,3]=[pos[0],0,pos[1]];err=float(np.max(np.abs(root-np.array(actor['world']).reshape(4,4,order='F'))));root_max=max(root_max,err)
  if err>.00005:fail.append({'actor':key,'root_error':err,'t':t})
result={'status':'PASS' if not fail else 'FAIL','source_pose_cases':cases,'source_joints':count,'max_bone_matrix_error':maximum,'max_original_record_root_error':root_max,'failures':fail[:30],'failure_count':len(fail),'visual_or_all96_acceptance':False};a.out.write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(bool(fail))
