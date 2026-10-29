# SPDX-License-Identifier: MIT
extends RefCounted
## Conservative death bound for the decoded scheduling subset, not a host stop.
## Unknown is never a finite timeout. Times are source frames.
static func upper_bound(document:Dictionary,release_frame:float=INF)->Dictionary:
 if not document.get("groups") is Dictionary:return _unknown("invalid groups")
 if is_nan(release_frame) or release_frame<0:return _unknown("invalid host release")
 var state:={"groups":document.groups,"visits":0}
 var latest:=0.0
 for scheduler in document.groups.get("Schd",[]):
  for item in scheduler.get("items",[]):
   var v:Dictionary=item.get("values",{})
   if not _enabled(v,"bEna") or int(v.get("TlNo",-1))<0:continue
   # No recorded trigger does not prove a live host cannot trigger later.
   if item.get("role")=="trigger_timeline":return _unknown("external trigger timeline")
   var birth:=float(v.get("StTm",0))
   if not is_finite(birth):return _unknown("nonfinite scheduler time")
   var result:=_timeline(state,int(v.TlNo),birth,release_frame)
   if not result.finite:return result
   latest=maxf(latest,float(result.frames))
 return _bound(latest)
static func _timeline(s:Dictionary,index:int,birth:float,stop:float)->Dictionary:
 var node:=_node(s,"TmLn",index)
 if node.is_empty():return _unknown("invalid timeline")
 var v:Dictionary=node.get("values",{})
 var ls:=float(v.get("LpSt",0));var le:=float(v.get("LpEd",0))
 if not is_finite(ls) or not is_finite(le):return _unknown("nonfinite timeline loop")
 var latest:=0.0
 for item in node.get("items",[]):
  var value:Dictionary=item.get("values",{})
  if not _enabled(value,"bEna"):continue
  if value.get("ClNo")!=null and int(value.ClNo)>=0:return _unknown("runtime timeline clip")
  if int(value.get("EfNo",-1))>=0:return _unknown("timeline effector semantics")
  var emitter:=int(value.get("EmNo",-1))
  if emitter<0:continue
  var start:=float(value.get("StTm",0));var end:=float(value.get("EdTm",-1))
  if not is_finite(start) or not is_finite(end):return _unknown("nonfinite timeline time")
  if le>ls and start>=ls and start<le:return _unknown("repeating timeline item")
  var result:=_emit(s,emitter,birth+start,minf(stop,birth+end) if end>=0 else stop,[])
  if not result.finite:return result
  latest=maxf(latest,float(result.frames))
 return _bound(latest)
static func _emit(s:Dictionary,index:int,birth:float,stop:float,parents:Array,upper_birth_only:bool=false)->Dictionary:
 s.visits+=1
 if s.visits>8192:return _unknown("analysis complexity limit")
 if index in parents:return _unknown("emitter cycle")
 var node:=_node(s,"Emit",index)
 if node.is_empty():return _unknown("invalid emitter")
 if birth>stop:return _bound(0)
 var v:Dictionary=node.get("values",{})
 if int(v.get("EVT",-1)) not in [0,5]:return _unknown("unsupported emitter type")
 var life:Variant=_life_range(node.get("life",{}))
 if life==null:return _unknown("unsupported emitter life")
 var ls:=float(v.get("LpSt",0));var le:=float(v.get("LpEd",0))
 if not is_finite(ls) or not is_finite(le):return _unknown("nonfinite emitter loop")
 var end:=stop
 # Negative sampled life means some draws can live indefinitely.
 if le<=ls and life.x>=0:end=minf(end,birth+float(life.y))
 if not is_finite(end):return _unknown("unbounded emitter")
 var latest:=0.0
 if int(v.get("EfNo",-1))>=0:
  if int(_node(s,"Efct",int(v.EfNo)).get("values",{}).get("EfVT",-1))!=9:return _unknown("unsupported effector")
  latest=maxf(latest,end)
 if int(v.get("SdNo",-1))>=0:return _unknown("sound tail semantics")
 var chain:=parents.duplicate();chain.append(index)
 for item in node.get("items",[]):
  var value:Dictionary=item.get("values",{})
  if not _enabled(value,"bEnb"):continue
  var target:=int(value.get("TgtB",-1))
  if target<0:continue
  var role:String=item.get("role","")
  if role not in ["child_emitter","child_particle"]:return _unknown("unknown emission role")
  var chance:=float(value.get("CrPr",100));var count:=float(value.get("CrCn",1))
  var first:=float(value.get("CrTm",1));var delay:=float(value.get("GenD",0))
  if not is_finite(chance) or chance<0 or chance>100 or not is_finite(count) or count<0 or count!=floor(count):return _unknown("invalid creation count/probability")
  if not is_finite(first) or not is_finite(delay) or delay<0:return _unknown("invalid creation time/delay")
  if chance==0 or count==0:continue
  # A nested birth is only an upper envelope, not the first actual birth.
  # Using it to reject CrTm can erase earlier children that already emitted.
  if not upper_birth_only and birth+maxf(0,first-1)>end:continue
  var curves:Dictionary=node.get("curves",{})
  var numbers:Variant=_scalar_range(curves.get("CrC",{}),curves.get("CrCR",{}),1)
  var interval:Variant=_scalar_range(curves.get("CrI",{}),curves.get("CrIR",{}),1)
  if numbers==null or interval==null or interval.x<=0 or numbers.x<0:return _unknown("unproven emission curve range")
  var number_max:=floorf(numbers.y)*count
  if number_max==0:continue
  # Last emission <= end. Delayed particles can be born after emission stops.
  var last_birth:float=end+delay*(number_max-1 if _enabled(value,"bGD") else 1)
  if not is_finite(last_birth):return _unknown("nonfinite delayed birth")
  var result:Dictionary
  # A later delayed child may fall beyond stop while an earlier child survives.
  # Bounding a child-emitter birth by stop safely includes that earlier child.
  if role=="child_emitter":
   if _enabled(value,"bOvr"):return _unknown("child emitter life override semantics")
   result=_emit(s,target,minf(last_birth,stop),stop,chain,true)
  else:result=_particle(s,target,last_birth,value)
  if not result.finite:return result
  latest=maxf(latest,float(result.frames))
 return _bound(latest)
static func _particle(s:Dictionary,index:int,birth:float,influence:Dictionary)->Dictionary:
 var node:=_node(s,"Ptcl",index)
 if node.is_empty():return _unknown("invalid particle")
 var v:Dictionary=node.get("values",{})
 if int(v.get("PrVT",-1)) not in [1,2,5,6,8,10,12,13]:return _unknown("unsupported particle type")
 var start:=float(v.get("LpSt",0));var end:=float(v.get("LpEd",0))
 if not is_finite(start) or not is_finite(end) or end>start:return _unknown("looping/invalid particle")
 var life:Variant=_life_range(node.get("life",{}))
 if _enabled(influence,"bOvr"):
  var base:=float(influence.get("OvrV",0));var amplitude:=float(influence.get("OvrR",0))
  life=_range(minf(base,base+amplitude),maxf(base,base+amplitude))
 if life==null or not is_finite(life.x) or not is_finite(life.y) or life.x<0:return _unknown("unbounded/unsupported particle life")
 var initial:=float(influence.get("StFr",0))
 if not is_finite(initial):return _unknown("nonfinite particle initial age")
 return _bound(birth+float(life.y)-initial)
static func _life_range(data:Dictionary)->Variant:
 if not data.get("unknown_fields",[]).is_empty():return null
 if data.is_empty() or not data.get("enabled",true):return _range(-1,-1)
 if data.get("Val")==null or data.get("ValR")==null:return null
 var base:=float(data.Val);var amplitude:=float(data.ValR)
 if not is_finite(base) or not is_finite(amplitude):return null
 if amplitude==0:return _range(base,base)
 var random:Variant=_random_range(int(data.get("Type",-1)))
 if random==null:return null
 return _range(base+minf(amplitude*random.x,amplitude*random.y),base+maxf(amplitude*random.x,amplitude*random.y))
static func _random_range(mode:int)->Variant:
 if mode<0 or mode>5:return null
 return [_range(-1,1),_range(0,1),_range(-1,0)][mode%3]
static func _curve_range(curve:Dictionary,fallback:float)->Variant:
 if curve.is_empty():return _range(fallback,fallback)
 if curve.get("kind","scalar")!="scalar" or not curve.get("unknown_fields",[]).is_empty():return null
 var keys:Array=curve.get("keys",[])
 if keys.is_empty():return null
 var low:=INF;var high:=-INF;var previous:=-INF
 for key in keys:
  var t:=float(key.get("time",NAN));var data:Array=key.get("data",[])
  if not is_finite(t) or t<=previous or int(key.get("type",-1)) not in [1,2] or data.size()!=3:return null
  for x in data:
   if not is_finite(float(x)):return null
  previous=t;low=minf(low,float(data[2]));high=maxf(high,float(data[2]))
 for field in ["BvPr","BvPo"]:
  if int(curve.get(field,-1)) not in [0,1] and not (int(curve.get(field,-1))==2 and low==high):return null
 return _range(low,high)
static func _scalar_range(curve:Dictionary,random_curve:Dictionary,fallback:float)->Variant:
 var base:Variant=_curve_range(curve,fallback)
 var amplitude:Variant=_curve_range(random_curve,0)
 if base==null or amplitude==null:return null
 if amplitude.x==0 and amplitude.y==0:return base
 var random:Variant=_random_range(int(curve.get("RanT",random_curve.get("RanT",-1))))
 if random==null:return null
 var products:=[amplitude.x*random.x,amplitude.x*random.y,amplitude.y*random.x,amplitude.y*random.y]
 return _range(base.x+products.min(),base.y+products.max())
static func _node(s:Dictionary,group:String,index:int)->Dictionary:
 var nodes:Array=s.groups.get(group,[])
 return nodes[index] if index>=0 and index<nodes.size() else {}
static func _enabled(values:Dictionary,key:String)->bool:
 var x:Variant=values.get(key)
 if x is Dictionary:x=x.get("value")
 return x==true or (x is int or x is float) and float(x)==1
static func _bound(frames:float)->Dictionary:
 if not is_finite(frames):return _unknown("nonfinite bound")
 return {"finite":true,"frames":maxf(0,frames),"reason":"reachable decoded source deaths bounded; not host completion"}
static func _unknown(reason:String)->Dictionary:
 return {"finite":false,"frames":0.0,"reason":reason}

static func _range(x:float,y:float)->Dictionary:
 return {"x":x,"y":y}
