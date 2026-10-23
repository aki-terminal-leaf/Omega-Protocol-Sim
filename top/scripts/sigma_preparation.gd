# SPDX-License-Identifier: MIT
## Pure CN observed-marker policy. No clock, planner, NPC action or combat mutation.
extends RefCounted
const A=["attack1","attack2","attack3","attack4"]
const S=["ignore1","ignore2"]
const K=["","attack1","attack2","attack3","attack4","attack5","attack6","attack7","attack8","bind1","bind2","bind3","ignore1","ignore2","square","circle","plus","triangle"]
const N=["near","far","stop1","stop2","attack1","attack4","attack2","attack3"]
static func whole(v,lo:int,hi:int)->bool:return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v)) and float(v)>=lo and float(v)<=hi
static func issue(o:Dictionary,c:String,a:int=-1,m:String="")->void:o.errors.append({"code":c,"actor":a,"marker":m})
static func expected(profile:String,dynamis:Variant,near:Variant,far:Variant)->Dictionary:
 var o={"supported":profile=="cn_moogle","valid":false,"errors":[],"eligible":[],"world":[],"nonworld":[],"source_precision":"CN poster panels 10-12; lock boundary and idle Stop ordering are implementation policy"}
 if not o.supported:issue(o,"unsupported_source_pending");return o
 if not dynamis is Array or dynamis.size()!=8:issue(o,"invalid_observation");return o
 for v in dynamis:
  if not whole(v,0,3):issue(o,"invalid_observation");return o
 var stacks:Array=dynamis.map(func(v):return int(v))
 if stacks.count(1)!=6 or stacks.count(0)!=2:issue(o,"invalid_entry_dynamis");return o
 if not whole(near,0,7) or not whole(far,0,7) or int(near)==int(far):issue(o,"invalid_observation");return o
 o.world=[int(near),int(far)]
 for actor in 8:
  if actor not in o.world:
   o.nonworld.append(actor)
   if int(dynamis[actor])==1:o.eligible.append(actor)
 o.valid=true;return o
static func resolve(profile:String,dynamis:Variant,near:Variant,far:Variant,owners:Variant,events:Variant,human:Variant,phase_start_sequence:Variant=0)->Dictionary:
 var o=expected(profile,dynamis,near,far);o.merge({"raw":[],"normalized":{},"roles":[-1,-1,-1,-1,-1,-1,-1,-1],"allocation":[],"unresolved":[],"displaced":[],"self_action":{"observed":false,"current":false,"events":[]},"complete":false,"observations_valid":false},true)
 if not o.valid:return o
 if not whole(human,0,7) or not whole(phase_start_sequence,0,2147483647) or not owners is Array or owners.size()!=8 or not events is Array:issue(o,"invalid_observation");return o
 for m in owners:
  if not m is String or m not in K:issue(o,"invalid_observation");return o
 o.raw=owners.duplicate(true);o.roles[0]=int(near);o.roles[1]=int(far)
 var dup=[]
 for actor in 8:
  if owners[actor]!="" and owners.count(owners[actor])>1:dup.append(actor);issue(o,"duplicate_marker",actor,owners[actor])
 var missing=[]
 for sign in A:
  var actor:int=owners.find(sign)
  if actor<0:missing.append(sign)
  elif actor not in dup:
   if actor not in o.eligible:issue(o,"ineligible_actor",actor,sign)
   else:o.normalized[sign]=actor
 var a5=[]
 for actor in 8:
  if owners[actor]=="attack5":a5.append(actor)
 if not a5.is_empty():
  if a5.size()==1 and missing.size()==1 and a5[0] in o.eligible and a5[0] not in dup:o.normalized[missing[0]]=a5[0];o.normalized["attack5_raw"]=a5[0]
  else:
   issue(o,"ambiguous_attack5",a5[0],"attack5")
   if a5.any(func(x):return x not in o.eligible):issue(o,"ineligible_actor",a5[0],"attack5")
 for i in S.size():
  var actor:int=owners.find(S[i])
  if actor>=0 and actor not in dup:
   if actor in o.world:issue(o,"world_must_be_unmarked",actor,S[i])
   else:o.roles[2+i]=actor
 for actor in o.world:
  if owners[actor]!="":issue(o,"world_must_be_unmarked",actor,owners[actor])
 for actor in o.nonworld:
  var m:String=owners[actor]
  if m=="":issue(o,"missing_required_marker",actor)
  elif m in A or m=="attack5":
   if actor not in o.eligible:issue(o,"ineligible_actor",actor,m)
  elif m not in S:issue(o,"wrong_marker_id",actor,m)
 for sign in A:
  if not o.normalized.has(sign):issue(o,"missing_required_marker",-1,sign)
 var slots={"attack1":4,"attack4":5,"attack2":6,"attack3":7}
 for sign in A:
  if o.normalized.has(sign):o.roles[slots[sign]]=o.normalized[sign]
 receipts(o,owners,events,int(human),int(phase_start_sequence))
 o.observations_valid=not o.errors.any(func(e):return e.code in ["invalid_observation","invalid_marker_event"])
 for slot in 8:
  if o.roles[slot]<0:o.unresolved.append(N[slot])
  else:o.allocation.append({"role":N[slot],"actor":o.roles[slot]})
 if int(human) in o.nonworld and not o.self_action.current:issue(o,"missing_required_marker",int(human),owners[int(human)])
 o.complete=o.errors.is_empty() and o.unresolved.is_empty();return o
static func receipts(o:Dictionary,owners:Array,events:Array,human:int,after:int)->void:
 var latest=-1;var previous=-1
 for raw in events:
  if not raw is Dictionary or not whole(raw.get("sequence"),1,2147483647) or not whole(raw.get("actor"),0,7) or not whole(raw.get("target"),0,7) or not whole(raw.get("displaced",-1),-1,7) or not raw.get("marker") is String or raw.marker not in K or raw.get("operation") != ("clear" if raw.marker=="" else "assign") or not raw.get("source") is String:issue(o,"invalid_marker_event");continue
  var seq=int(raw.sequence)
  if seq<=previous:issue(o,"invalid_marker_event")
  previous=seq
  if seq<=after:continue
  var target=int(raw.target);var displaced=int(raw.get("displaced",-1))
  if displaced>=0:o.displaced.append({"actor":displaced,"by":target,"marker":raw.marker,"sequence":seq})
  if target==human or displaced==human:latest=seq
  if int(raw.actor)==human and target==human and raw.source=="player":o.self_action.observed=true;o.self_action.events.append(raw.duplicate(true))
 if not o.self_action.events.is_empty():
  var last=o.self_action.events.back();o.self_action.current=int(last.sequence)==latest and owners[human]==last.marker
