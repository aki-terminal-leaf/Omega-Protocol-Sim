# SPDX-License-Identifier: MIT
extends RefCounted
## Public debuff + actually presented arm-node memory. Never reads pending events,
## family metadata, solved positions or encounter RNG. Source onset remains unknown.
const P=preload("res://scripts/p3_transition_patterns.gd")
const C=preload("res://scripts/p3_transition_courses.gd")
const R=preload("res://scripts/rules.gd")
const KEY="p3_transition_observation"
const PROFILES=["elemental","aether","lpdu","cn_moogle","kr_09stop"]
const PHASES=["outer","inner","outer_return","pocket"]
static func selection(beat:Dictionary)->Dictionary:
 var raw:Variant=beat.get("p3_transition_public",null)
 if not raw is Dictionary or str(raw.get("profile_id","")) not in PROFILES or str(raw.get("phase","")) not in PHASES:return {}
 return raw
static func begin(beat:Dictionary,state:Dictionary)->void:
 state[KEY]={"version":1,"origin":float(state.get("sim_time",0.0)),"profile_id":str(selection(beat).get("profile_id","")),"purple":[],"white":[],"marks_at":null,"sources":{},"first":null,"first_at":null,"basis":"","blocked":false,"invalid":[],"source_onset":"source_unknown"}
static func number(v:Variant)->bool:
 return (v is int or v is float) and is_finite(float(v))
static func partition(p:Variant,w:Variant)->bool:
 if not p is Array or not w is Array or p.size()!=4 or w.size()!=2:return false
 var ids:Array=[]
 for value in p+w:
  if not number(value) or float(value)!=floorf(float(value)) or int(value)<0 or int(value)>7 or int(value) in ids:return false
  ids.append(int(value))
 return true
static func memory(beat:Dictionary,state:Dictionary)->Dictionary:
 var raw:Variant=state.get(KEY,null);var selected:Dictionary=selection(beat)
 if selected.is_empty() or not raw is Dictionary:return {}
 if raw.get("version",0)!=1 or raw.get("blocked",true)!=false or raw.get("profile_id","")!=selected.profile_id:return {}
 if not number(raw.get("origin",null)) or not number(state.get("sim_time",null)) or float(state.sim_time)<float(raw.origin):return {}
 if not raw.get("sources",null) is Dictionary or not raw.get("invalid",null) is Array or not raw.invalid.is_empty():return {}
 for field in ["marks_at","first_at"]:
  if raw.get(field)!=null and (not number(raw[field]) or float(raw[field])<float(raw.origin) or float(raw[field])>float(state.sim_time)+0.000001):return {}
 if not raw.get("purple",null) is Array or not raw.get("white",null) is Array:return {}
 if raw.purple.is_empty():
  if not raw.white.is_empty() or raw.marks_at!=null:return {}
 elif not partition(raw.purple,raw.white) or raw.marks_at==null:return {}
 var counts:Array=[0,0];var points:Array=[];var witness:Array=[0,0]
 for id in raw.sources:
  var source:Variant=raw.sources[id]
  if not id is String or str(id).is_empty() or not source is Dictionary:return {}
  var xy:Variant=source.get("pos",null)
  if not xy is Array or xy.size()!=2 or not number(xy[0]) or not number(xy[1]):return {}
  var pos:Vector2=R.v(xy);var group:int=arm_class(pos)
  if group<0 or not number(source.get("group",null)) or float(source.group)!=float(group) or not number(source.get("at",null)):return {}
  if float(source.at)<float(raw.origin) or float(source.at)>float(state.sim_time)+0.000001:return {}
  for previous in points:
   if R.v(previous).distance_to(pos)<0.01:return {}
  points.append(xy);counts[group]+=1
  if raw.get("first_at")!=null and float(source.at)<=float(raw.first_at):witness[group]+=1
 if counts[0]>3 or counts[1]>3:return {}
 if raw.get("first")!=null:
  if not number(raw.first) or float(raw.first) not in [0.0,1.0] or raw.first_at==null or str(raw.get("basis","")) not in ["displayed_model_nodes","assisted_checkpoint_not_observed"]:return {}
  if raw.basis=="assisted_checkpoint_not_observed" and not state.get("p3_checkpoint_assisted",false):return {}
  if witness[int(raw.first)]!=3 or witness[1-int(raw.first)]!=0:return {}
 elif raw.get("first_at")!=null or raw.get("basis","")!="" or (counts[0]>0 and counts[1]>0):return {}
 return raw
static func reject(state:Dictionary,reason:String)->void:
 if not state.get(KEY,null) is Dictionary:return
 state[KEY].blocked=true
 state[KEY].invalid.append({"at":float(state.get("sim_time",0)),"reason":reason})
static func observe_marks(seen:Dictionary,state:Dictionary)->void:
 if not seen.purple.is_empty():return
 var statuses:Variant=state.get("statuses",null)
 if not statuses is Array or statuses.size()!=8:return
 var purple:Array=[];var white:Array=[]
 for a in 8:
  if not statuses[a] is Dictionary:return
  for key in ["sniper_cannon_fodder","high_powered_sniper_cannon_fodder"]:
   if not statuses[a].has(key):continue
   var status:Variant=statuses[a][key]
   if not status is Dictionary or not number(status.get("expires",null)) or float(status.expires)<=float(state.sim_time):return
   if key=="sniper_cannon_fodder":purple.append(a)
   else:white.append(a)
 if partition(purple,white):
  seen.purple=purple;seen.white=white;seen.marks_at=float(state.sim_time)
static func arm_class(pos:Vector2)->int:
 if not pos.is_finite() or absf(pos.length()-14.0)>0.04:return -1
 var angle:float=fposmod(rad_to_deg(atan2(pos.x,-pos.y)),120.0)
 if minf(angle,120.0-angle)<0.2:return 0
 if absf(angle-60.0)<0.2:return 1
 return -1
static func publish(beat:Dictionary,state:Dictionary,displayed:Array,basis:String="displayed_model_nodes")->void:
 if not state.has(KEY):return
 var seen:Dictionary=memory(beat,state)
 if seen.is_empty():return
 if basis not in ["displayed_model_nodes","assisted_checkpoint_not_observed"] or (basis=="assisted_checkpoint_not_observed" and not state.get("p3_checkpoint_assisted",false)):
  reject(state,"invalid_presentation_basis");return
 observe_marks(seen,state)
 if displayed.is_empty():return
 var incoming:Dictionary={}
 for raw in displayed:
  if not raw is Dictionary or not raw.get("id",null) is String or str(raw.id).is_empty() or incoming.has(raw.id):
   reject(state,"invalid_or_duplicate_source_id");return
  var xy:Variant=raw.get("pos",null)
  if not xy is Array or xy.size()!=2 or not number(xy[0]) or not number(xy[1]):
   reject(state,"invalid_source_position");return
  var pos:Vector2=R.v(xy);var group:int=arm_class(pos)
  if group<0:
   reject(state,"source_outside_public_arm_lattice");return
  if seen.sources.has(raw.id) and R.v(seen.sources[raw.id].pos).distance_to(pos)>0.001:
   reject(state,"contradictory_source_position");return
  incoming[raw.id]={"pos":[pos.x,pos.y],"group":group,"at":float(state.sim_time)}
 if seen.first==null:
  var candidates:Dictionary=seen.sources.duplicate(true);candidates.merge(incoming,false)
  var groups:Array=[];var unique:Array=[]
  for source in candidates.values():
   if int(source.group) not in groups:groups.append(int(source.group))
   for previous in unique:
    if R.v(previous).distance_to(R.v(source.pos))<0.01:
     reject(state,"duplicate_physical_source");return
   unique.append(source.pos)
  if groups.size()>1 or candidates.size()>3:
   reject(state,"first_wave_order_not_observed");return
  if candidates.size()==3:
   seen.first=groups[0];seen.first_at=float(state.sim_time);seen.basis=basis
 for id in incoming:
  if not seen.sources.has(id):seen.sources[id]=incoming[id]
 if memory(beat,state).is_empty():reject(state,"contradictory_or_malformed_source_cache")
static func goal(actor:int,beat:Dictionary,actors:Array,state:Dictionary)->Vector2:
 var hold:Vector2=R.v(actors[actor].pos)
 var seen:Dictionary=memory(beat,state)
 if seen.is_empty() or not partition(seen.purple,seen.white):return hold
 # Normalize restored JSON actor IDs before membership/rank operations.
 var purple:Array=seen.purple.map(func(a):return int(a));var white:Array=seen.white.map(func(a):return int(a))
 var empty:Array=range(8).filter(func(a):return a not in purple and a not in white)
 var route:Dictionary=P.data().routes[str(seen.profile_id)]
 var group:Array=purple if actor in purple else (white if actor in white else empty)
 var rank:int=C.ranked(group,route.priority).find(actor)
 var nominal:float=float(route.purple_angles[rank] if actor in purple else route.white_angles[rank])
 if seen.first==null:return R.direction(nominal)*19.0
 var phase:String=str(selection(beat).phase)
 var angles:Array=C.pocket(nominal,int(seen.first))
 return R.direction(float(angles[0 if phase=="pocket" else 1]))*(19.0 if phase in ["outer","outer_return"] else 16.5)
