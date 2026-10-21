#!/usr/bin/env python3
"""Generate legal Sigma coaching paths, NOT attack or pass/fail geometry.

Public-guide role zones + independently observed static damage times define
constraints. Runtime judges actual player movement independently. Coordinates
are a geometric realization of qualitative diagrams, not official coordinates.
"""
import argparse,json,math
from pathlib import Path
import numpy as np

ROLES=['near','far','near1','near2','far1','far2','arm_left','arm_right']
def polar(angle,radius):
 a=math.radians(angle);return np.array([math.sin(a)*radius,-math.cos(a)*radius])
def final_goals(family,sign):
 side=180+sign*90
 if family=='cn':
  angles=[180-sign*2,side,180-sign*9,180+sign*9,side+180,side,-45,45]
 elif family=='kr':
  angles=[side+sign*2,0,180+sign*60,180+sign*30,180,0,-45,45]
 else:angles=[side-sign*2,180,side-sign*9,side+sign*9,0,180,-45,45]
 return [polar(a,19 if family=='kr' and i==0 else (10 if i<2 else 19)) for i,a in enumerate(angles)]
def hazards(points,time,sign,legs):
 bad=np.zeros(len(points),dtype=bool)
 for j in range(14):
  t=46.2+(0 if j==0 else .625+(j-1)*.58)
  if abs(time-t)<1e-5:
   a=math.radians(sign*j*9);bad|=np.abs(points[:,0]*math.cos(a)+points[:,1]*math.sin(a))<=6.001
 if abs(time-49.3)<1e-5:
  if legs:bad|=np.abs(points[:,0])>=3.999
  else:bad|=(np.abs(points[:,0])<=5.001)|(np.abs(points[:,1]+10)<=5.001)
 return bad

def validate_layout(family,sign,goals):
 p=np.array(goals);paths=[]
 for start,far in [(0,False),(1,True)]:
  path=[start]
  for _ in range(2):
   ds=np.linalg.norm(p-p[path[-1]],axis=1);ds[path[-1]]=-1 if far else 1e10
   path.append(int(np.argmax(ds) if far else np.argmin(ds)))
  paths.append(path)
 assert paths==[[0,2,3],[1,4,5]],(family,sign,paths)
 for path in paths:
  for j,a in enumerate(path):
   caught=list(np.where(np.linalg.norm(p-p[a],axis=1)<= (8.001 if j==0 else 4.001))[0]);assert caught==[a],(family,sign,'splash',a,caught)
 for source in [polar(135,20),polar(225,20)]:
  ds=np.linalg.norm(p-source,axis=1);a=int(np.argmax(ds));assert a in [6,7],(family,sign,'arm',a)
  axis=(p[a]-source)/ds[a];caught=list(np.where((np.abs((p[:,0]-source[0])*axis[1]-(p[:,1]-source[1])*axis[0])<=3.001)&((p-source)@axis>=0))[0]);assert caught==[a],(family,sign,'line',a,caught)

def solve(family,sign,legs):
 goals=final_goals(family,sign);validate_layout(family,sign,goals)
 fside={4,6,7} if family!='kr' else {1,5,6,7}
 starts=[polar(-sign*30,19) if i in fside else polar(180-sign*40,13) for i in range(8)]
 wait_role=6 if sign==1 else 7
 nodes=np.array([polar(a,r) for r in [8,10,12,13,14,16,18,19] for a in range(0,360,5)]+starts+goals)
 n=len(nodes);start_indices=list(range(n-16,n-8));goal_indices=list(range(n-8,n))
 distances=np.linalg.norm(nodes[:,None,:]-nodes[None,:,:],axis=2)
 times=sorted([46.2+(0 if j==0 else .625+(j-1)*.58) for j in range(14)]+[49.3,56.1])
 invalid=[hazards(nodes,t,sign,legs) for t in times]
 result=[]
 for actor in range(8):
  costs=np.full(n,np.inf);costs[start_indices[actor]]=0;parents=[]
  if invalid[0][start_indices[actor]]:raise ValueError('Invalid guide start')
  for k in range(1,len(times)):
   delta=times[k]-times[k-1]
   allowed=distances<=6.0*delta+1e-7
   bad=invalid[k].copy()
   if k<len(times)-1:bad|=np.linalg.norm(nodes,axis=1)<11.999
   if (not legs and times[k]<=49.3+1e-5) or (actor==wait_role and not legs and k<len(times)-1) or (actor==wait_role and k==len(times)-2):
    bad[:]=True;bad[start_indices[actor]]=False
   if k==len(times)-1:bad[:]=True;bad[goal_indices[actor]]=False
   matrix=np.where(allowed,costs[:,None]+distances,np.inf)
   prev=np.argmin(matrix,axis=0);next_cost=matrix[prev,np.arange(n)];next_cost[bad]=np.inf
   parents.append(prev);costs=next_cost
  current=goal_indices[actor]
  if not np.isfinite(costs[current]):raise ValueError(f'No six-unit route {family=} {sign=} {legs=} {ROLES[actor]}')
  indices=[current]
  for prev in reversed(parents):current=int(prev[current]);indices.append(current)
  indices.reverse();route=[{'at':round(t,6),'pos':[round(float(x),6) for x in nodes[i]]} for t,i in zip(times,indices)]
  for a,b in zip(route,route[1:]):assert math.dist(a['pos'],b['pos'])<=6*(b['at']-a['at'])+1e-4
  result.append(route)
 return {'family':family,'direction':sign,'legs':legs,'role_order':ROLES,'kind':'guide-zone coaching realization, not official numeric coordinates','roles':result,'final_goals':[p.tolist() for p in goals]}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out={'schema':1,'speed':6.0,'sources':['Saus Sigma steps25-39','LPDU P5 steps34-45','CN fullposter panels09-11','09STOP Sigma final figure'],'routes':{}}
 for family in ['western','cn','kr']:
  for sign in [-1,1]:
   for legs in [False,True]:
    key=f'{family}_{sign}_{int(legs)}';out['routes'][key]=solve(family,sign,legs);print(key,'PASS',flush=True)
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(out,separators=(',',':'))+'\n')
if __name__=='__main__':main()
