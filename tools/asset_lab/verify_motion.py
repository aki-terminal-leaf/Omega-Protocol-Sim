#!/usr/bin/env python3
"""Independent source-channel -> Godot complete-bone differential (numpy/scipy)."""
import argparse,json,struct
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation,Slerp
def source(path):
 b=path.read_bytes();size=struct.unpack_from("<I",b,12)[0];d=json.loads(b[20:20+size]);base=28+size
 def accessor(index):
  a=d["accessors"][index];v=d["bufferViews"][a["bufferView"]];width={"SCALAR":1,"VEC3":3,"VEC4":4}[a["type"]]
  assert a["componentType"]==5126 and "sparse" not in a
  off=base+v.get("byteOffset",0)+a.get("byteOffset",0);stride=v.get("byteStride",width*4)
  return np.array([struct.unpack_from("<"+"f"*width,b,off+i*stride) for i in range(a["count"])])
 return d,accessor
def expected(doc,read,clip,t,supplement):
 rest={i:dict(translation=n.get("translation",[0,0,0]),rotation=n.get("rotation",[0,0,0,1]),scale=n.get("scale",[1,1,1])) for i,n in enumerate(doc["nodes"])}
 channels=[]
 if clip==supplement["name"]:
  byname={n.get("name"):i for i,n in enumerate(doc["nodes"])}
  times=np.array(supplement["times"]);keep=np.r_[np.diff(times)>0,True]
  for bone in supplement["bones"]:
   if bone["name"] not in byname:continue
   for path in ("translation","rotation","scale"):
    width=4 if path=="rotation" else 3
    channels.append((byname[bone["name"]],path,times[keep],np.array(bone[path]).reshape((-1,width))[keep],"LINEAR"))
 elif clip:
  anim=next(x for x in doc.get("animations",[]) if x["name"]==clip)
  for ch in anim["channels"]:
   s=anim["samplers"][ch["sampler"]];channels.append((ch["target"]["node"],ch["target"]["path"],read(s["input"])[:,0],read(s["output"]),s.get("interpolation","LINEAR")))
 for node,path,times,values,interp in channels:
  at=np.clip(t,times[0],times[-1]);j=int(np.clip(np.searchsorted(times,at,side="right")-1,0,len(times)-1))
  if interp=="STEP" or j==len(times)-1:value=values[j]
  elif path=="rotation":
   value=Slerp(times[j:j+2],Rotation.from_quat(values[j:j+2]))([at]).as_quat()[0]
  else:
   value=np.array([np.interp(at,times,values[:,k]) for k in range(values.shape[1])])
  rest[node][path]=value
 local={}
 for i,v in rest.items():
  mat=np.eye(4);mat[:3,:3]=Rotation.from_quat(v["rotation"]).as_matrix()@np.diag(v["scale"]);mat[:3,3]=v["translation"];local[i]=mat
 parents={child:i for i,n in enumerate(doc["nodes"]) for child in n.get("children",[])}
 world={}
 def global_pose(i):
  if i not in world:world[i]=global_pose(parents[i])@local[i] if i in parents else local[i]
  return world[i]
 return {str(n.get("name","")):local[i] if clip.startswith("action_") else global_pose(i) for i,n in enumerate(doc["nodes"])}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("--data",type=Path,required=True);p.add_argument("--states",type=Path,required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
 cat=json.loads((a.data/"catalog.json").read_text());supp=json.loads((a.data/"leg-motion.json").read_text());states=json.loads(a.states.read_text());cache={};fail=[];maximum=0;count=0;cases=0
 for row in states:
  if row.get("kind")!="model":continue
  _,asset,clip,_=row["key"].split("|")
  if asset not in cache:cache[asset]=source(a.data/cat["assets"][asset]["file"])
  doc,reader=cache[asset]
  for frame in row["frames"]:
   if not frame.get("pose"):continue
   values=expected(doc,reader,clip,frame["time"],supp);cases+=1
   for skeleton in frame["pose"]["skeletons"]:
    for name,raw in skeleton.items():
     actual=np.array(raw).reshape((4,4),order="F")
     if name not in values:fail.append({"bone":name,"reason":"missing_source"});continue
     error=float(np.max(np.abs(actual-values[name])));maximum=max(maximum,error);count+=1
     if error>0.0002:fail.append({"key":row["key"],"bone":name,"time":frame["time"],"error":error})
 result={"status":"PASS" if not fail else "FAIL","cases":cases,"joints":count,"max_matrix_error":maximum,"failures":fail[:50],"failure_count":len(fail),"source_game_fidelity":False}
 a.out.write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(bool(fail))
if __name__=="__main__":main()

