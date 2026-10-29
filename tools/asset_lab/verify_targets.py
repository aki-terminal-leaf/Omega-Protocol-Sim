#!/usr/bin/env python3
"""Independent original skeleton hierarchy + EID + recorded-placement oracle."""
import argparse,json,math
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation
p=argparse.ArgumentParser();p.add_argument('--data',type=Path,required=True);p.add_argument('--eid',type=Path,required=True);p.add_argument('--states',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
record=json.loads((a.data/'record.json').read_text());eid=json.loads(a.eid.read_text());states=json.loads(a.states.read_text());reference=eid['families']['c0101']['reference_skeleton'];bones=reference['bones'];world={};fail=[];maximum=0;count=0

def source_pose(index):
 if index not in world:
  b=bones[index];m=np.eye(4);m[:3,:3]=Rotation.from_quat(b['rotation']).as_matrix()@np.diag(b['scale']);m[:3,3]=b['translation'];world[index]=source_pose(b['parent'])@m if b['parent']>=0 else m
 return world[index]
for row in states['samples']:
 proof=row['provenance'];t=row['t'];track=np.array(record['tracks'][row['id']]);idx=int(np.searchsorted(track[:,0],t,side='right')-1);assert idx>=0
 pos=track[idx,1:3].copy();heading=track[idx,3]
 if idx+1<len(track):
  dt=track[idx+1,0]-track[idx,0]
  if 0<dt<=1500 and np.linalg.norm(track[idx+1,1:3]-pos)<=12*dt/1000:pos+=(track[idx+1,1:3]-pos)*np.clip((t-track[idx,0])/dt,0,1)
 root=np.eye(4);root[:3,:3]=Rotation.from_euler('y',math.pi/2-heading/100).as_matrix();root[:3,3]=[pos[0],0,pos[1]]
 for point in row['points']:
  bind=next(x for x in eid['families']['c0101']['rows'] if x['id']==point['eid']);bone_index=next(i for i,b in enumerate(bones) if b['name']==bind['bone']);offset=np.eye(4);offset[:3,:3]=Rotation.from_euler('YXZ',[bind['rotation_radians'][1],bind['rotation_radians'][0],bind['rotation_radians'][2]]).as_matrix();offset[:3,3]=bind['position']
  oracle=root@source_pose(bone_index)@offset;actual=np.array(point['matrix']).reshape(4,4,order='F');err=float(np.max(np.abs(oracle-actual)));count+=1;maximum=max(maximum,err)
  if err>.0001:fail.append({'id':row['id'],'eid':point['eid'],'t':t,'error':err})
 if proof['recorded_race_known'] or proof['recorded_pose_known'] or proof['rendered_body'] or proof['extra_scale']!=1 or proof['source_sha256']!=reference['source_sha256']:fail.append({'false_source_provenance':proof})
result={'status':'PASS' if not fail else 'FAIL','samples':len(states['samples']),'original_reference_bones':len(bones),'source_eid_world_matrices':count,'maximum_matrix_error':maximum,'failure_count':len(fail),'failures':fail[:30],'recorded_player_pose_or_all96_acceptance':False};a.out.write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(bool(fail))
