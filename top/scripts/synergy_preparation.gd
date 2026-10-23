# SPDX-License-Identifier: MIT
extends RefCounted
## Source-specific initial queues and public, remembered glyph assignment.
## LPDU THMR source: Toolbox502396712985961 steps3/4 (actual jobs, not object keys).
## Later weapon/new-North presentation is outside this correction's acceptance.
const A=preload("res://scripts/synergy_assignment.gd")
const R=preload("res://scripts/rules.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
const Conga=preload("res://scripts/aether_conga.gd")
const KEY="synergy_preparation"
const LEFT=[2,0,4,6]
const RIGHT=[3,1,5,7]
const PHASES=["cast","remember","appear","dodge","fire","laser","knock","stack","blades","expiry","finish"]
## Aether Toolbox steps3/5: independent recommended default line H1,R1,M1,MT,ST,M2,R2,H2.
## Never derived from ctx.order/future pairs; actual same-symbol left/right decides groups.
const AETHER_ORDER=[2,6,4,0,1,5,7,3]
const AETHER_LINE_Z=0.0
const CONGA_KEYS=["mode","default_order"]
static func config(profile_id:String="elemental")->Dictionary:
 if profile_id=="lpdu":return {"profile_id":"lpdu","left":[0,2,4,6],"right":[1,3,5,7],"shape_order":["cross","square","circle","triangle"]}
 if profile_id=="aether":return {"profile_id":"aether","mode":"conga","default_order":AETHER_ORDER.duplicate(),"shape_order":["cross","square","circle","triangle"]}
 if profile_id!="elemental":return {}
 return {"profile_id":"elemental","left":LEFT.duplicate(),"right":RIGHT.duplicate(),"shape_order":["circle","cross","triangle","square"]}
static func is_conga(profile_id:Variant)->bool:
 return profile_id is String and str(config(profile_id).get("mode",""))=="conga"
static func selection(beat:Dictionary)->Dictionary:
 var raw:Variant=beat.get("synergy_public",null)
 if not raw is Dictionary or not raw.get("profile_id",null) is String or raw.get("phase","") not in PHASES:return {}
 var cfg:Dictionary=config(raw.profile_id)
 if cfg.is_empty():return {}
 if not raw.get("remote",null) is bool or not number(raw.get("eye_angle",null)) or not number(raw.get("north",null)):return {}
 for key in cfg:
  if raw.get(key,null)!=cfg[key]:return {}
 for key in ["left","right"]+CONGA_KEYS:
  if raw.has(key) and not cfg.has(key):return {}
 return raw
## Training default spawn only (1.8m slots); not a server/guide position certificate.
static func aether_spawn()->Array:
 var slots:Array=Conga.initial_slots(1.8,AETHER_LINE_Z)
 var result:Array=[];result.resize(8)
 for k in 8:result[AETHER_ORDER[k]]=slots[k]
 return result
static func pose_snapshot(poses:Variant)->Array:
 if not poses is Array or poses.size()!=8:return []
 var result:Array=[]
 for item in poses:
  var p:Variant=item.get("pos",null) if item is Dictionary else item
  if p is Array and p.size()==2 and number(p[0]) and number(p[1]):p=Vector2(float(p[0]),float(p[1]))
  if not p is Vector2 or not is_finite(p.x) or not is_finite(p.y):return []
  result.append(p)
 return result
static func frozen_vectors(raw:Variant)->Array:
 if not raw is Array or raw.size()!=8:return []
 var result:Array=[]
 for p in raw:
  if not p is Array or p.size()!=2 or not number(p[0]) or not number(p[1]):return []
  result.append(Vector2(float(p[0]),float(p[1])))
 return pose_snapshot(result)
static func assignment_of(glyphs:Variant,seen:Dictionary,profile_id:String)->Dictionary:
 if not glyphs is Array:return {}
 if not is_conga(profile_id):return A.assign(glyphs,config(profile_id))
 var frozen:Array=frozen_vectors(seen.get("positions",null))
 if frozen.is_empty():return {}
 return Conga.assign(glyphs,frozen,config(profile_id).shape_order)
static func number(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value))
static func queue_goal(actor:int,assignment:Dictionary={},profile_id:String="elemental")->Vector2:
 if not assignment.is_empty():profile_id=str(assignment.get("profile_id",profile_id))
 var cfg:Dictionary=config(profile_id)
 if cfg.is_empty():return Vector2.ZERO
 # Conga: builder/demo default line only; ordinary NPCs never read this route.
 if cfg.has("mode"):return aether_spawn()[actor] if actor>=0 and actor<8 else Vector2.ZERO
 var queue:Array=cfg.left if actor in cfg.left else cfg.right
 var side:int=0 if actor in cfg.left else 1
 if not assignment.is_empty():side=int(assignment.actor_sides[actor])
 return Vector2(-3.0 if side==0 else 3.0,-5.0+queue.find(actor)*3.0)
static func fire_goal(actor:int,assignment:Dictionary,remote:bool,eye:float)->Vector2:
 var slot:int=assignment.route_order.find(actor);var rank:int=slot/2
 var z:float=-12.0+rank*8.0
 var x:float=sqrt(18.0*18.0-z*z) if remote else 11.0
 if slot%2==1 and remote and (assignment.profile_id=="lpdu" or rank in [0,3]):z=-z
 return Vector2(-x if slot%2==0 else x,z).rotated(deg_to_rad(eye))
static func knock_goals(assignment:Dictionary,targets:Array,remote:bool,eye:float,north:float,after:bool=false)->Array:
 var left:Array=[];var right:Array=[]
 for slot in 8:
  if slot%2==0:left.append(int(assignment.route_order[slot]))
  else:right.append(int(assignment.route_order[slot]))
 if targets.size()==2 and (int(targets[0]) in left)==(int(targets[1]) in left):
  var candidates:Array=targets.map(func(a):return int(a))
  candidates.sort_custom(func(a,b):return fire_goal(a,assignment,remote,eye).rotated(deg_to_rad(-eye)).y<fire_goal(b,assignment,remote,eye).rotated(deg_to_rad(-eye)).y)
  # Aether keeps its existing north (nearer-eye) flex; other profiles unchanged.
  var chosen:int=candidates[0] if str(assignment.get("profile_id",""))=="aether" else candidates[-1];var slot:int=assignment.route_order.find(chosen)
  var partner:int=int(assignment.route_order[slot+1 if slot%2==0 else slot-1]);var from_left:bool=chosen in left
  left.erase(chosen);right.erase(chosen);left.erase(partner);right.erase(partner)
  if from_left:right.append(chosen);left.append(partner)
  else:left.append(chosen);right.append(partner)
 var goals:Array=[];goals.resize(8)
 for side in 2:
  var group:Array=left if side==0 else right
  var base:Vector2=R.direction(270 if side==0 else (90 if remote else 180))*4.8
  for rank in 4:
   var p:Vector2=(base+Vector2((rank%2)*0.06,(rank/2)*0.06)).rotated(deg_to_rad(north))
   if after:p+=p.normalized()*13.0
   goals[group[rank]]=p
 return goals
static func begin(beat:Dictionary,state:Dictionary,actors:Variant=null)->void:
 var chosen:Dictionary=selection(beat)
 if chosen.is_empty():return
 if chosen.phase=="cast":
  state.erase("synergy_checkpoint_assisted")
  state[KEY]={"version":1,"profile_id":chosen.profile_id,"origin":float(state.get("sim_time",0.0)),"glyphs":[],"at":null,"basis":"","stacks":[],"stacks_at":null,"stacks_basis":"","blocked":false,"invalid":[]}
  # Fresh cast clears frozen positions and the formation cache (Aether only).
  if is_conga(chosen.profile_id):state[KEY].merge({"positions":null,"positions_at":null,"positions_basis":"","positions_profile":""})
 if not state.get("synergy_presentation_required",false):publish_statuses(beat,state,"headless_public_statuses_not_displayed",actors)
## Headless observation with actual same-tick poses (Interactions.tick). Aether only;
## Elemental/LPDU publication timing stays in begin/sync exactly as before.
static func observe(beat:Dictionary,actors:Array,state:Dictionary)->void:
 if not is_conga(selection(beat).get("profile_id",null)) or state.get("synergy_presentation_required",false):return
 publish_statuses(beat,state,"headless_public_statuses_not_displayed",actors)
static func memory(beat:Dictionary,state:Dictionary)->Dictionary:
 var chosen:Dictionary=selection(beat)
 if chosen.is_empty():return {}
 var raw:Variant=state.get(KEY,null)
 if not raw is Dictionary or raw.get("version",0)!=1 or raw.get("profile_id","")!=chosen.profile_id or raw.get("blocked",null)!=false or not raw.get("invalid",null) is Array or not raw.invalid.is_empty():return {}
 if not number(raw.get("origin",null)) or not number(state.get("sim_time",null)) or float(state.sim_time)<float(raw.origin):return {}
 if not raw.get("glyphs",null) is Array or not raw.get("stacks",null) is Array:return {}
 var conga:bool=is_conga(chosen.profile_id)
 if raw.glyphs.is_empty():
  if raw.get("at")!=null or raw.get("basis","")!="":return {}
  if conga and (raw.get("positions",null)!=null or raw.get("positions_at",null)!=null):return {}
 else:
  if assignment_of(raw.glyphs,raw,chosen.profile_id).is_empty() or not number(raw.get("at",null)):return {}
  var relative:float=float(raw.at)-float(raw.origin)
  if relative+0.000001<3.0 or relative>=6.1 or float(raw.at)>float(state.sim_time)+0.000001:return {}
  if not valid_basis(raw.get("basis",""),state):return {}
  if conga and (not number(raw.get("positions_at",null)) or float(raw.positions_at)!=float(raw.at) or raw.get("positions_basis","")!=raw.basis or raw.get("positions_profile","")!=chosen.profile_id):return {}
 if not raw.stacks.is_empty():
  if raw.stacks.size()!=2 or not number(raw.get("stacks_at",null)) or not valid_basis(raw.get("stacks_basis",""),state):return {}
  if float(raw.stacks_at)+0.000001<float(raw.origin)+20.8 or float(raw.stacks_at)>float(state.sim_time)+0.000001:return {}
  var ids:Array=[]
  for value in raw.stacks:
   if not number(value) or float(value)!=floorf(float(value)) or int(value)<0 or int(value)>7 or int(value) in ids:return {}
   ids.append(int(value))
 elif raw.get("stacks_at")!=null or raw.get("stacks_basis","")!="":return {}
 return raw
static func valid_basis(value:Variant,state:Dictionary)->bool:
 return value=="displayed_textured_glyphs" or (value=="headless_public_statuses_not_displayed" and not state.get("synergy_presentation_required",false)) or (value=="assisted_checkpoint_not_observed" and state.get("synergy_checkpoint_assisted",false)==true)
static func reject(state:Dictionary,reason:String)->void:
 if not state.get(KEY,null) is Dictionary:return
 state[KEY].blocked=true;state[KEY].invalid.append({"at":float(state.get("sim_time",0)),"reason":reason})
static func publish(beat:Dictionary,state:Dictionary,displayed:Array,basis:String="displayed_textured_glyphs",poses:Variant=null)->void:
 var chosen:Dictionary=selection(beat);var seen:Dictionary=memory(beat,state)
 if chosen.is_empty() or seen.is_empty():return
 if not valid_basis(basis,state):reject(state,"invalid_basis");return
 if displayed.is_empty():return
 if chosen.phase=="remember" and is_conga(chosen.profile_id):
  var order:Array=config(chosen.profile_id).shape_order
  if not seen.glyphs.is_empty():
   # Repeats compare against the frozen PAST poses, never current moving poses.
   var past:Dictionary=assignment_of(seen.glyphs,seen,chosen.profile_id)
   var again:Dictionary=Conga.assign(displayed,frozen_vectors(seen.positions),order)
   if again.is_empty() or again!=past:reject(state,"contradictory_glyphs")
   return
  # Position-less callers (Interactions.sync) cannot form a receipt; no reject.
  if poses==null:return
  var actual:Array=pose_snapshot(poses)
  if actual.is_empty():reject(state,"invalid_positions");return
  var conga:Dictionary=Conga.assign(displayed,actual,order)
  if conga.is_empty():reject(state,"incomplete_invalid_or_tied_glyphs");return
  var now_c:float=float(state.sim_time);var relative_c:float=now_c-float(seen.origin)
  if relative_c+0.000001<3.0 or relative_c>=6.1:reject(state,"glyphs_outside_current_window");return
  seen.glyphs=displayed.duplicate(true);seen.at=now_c;seen.basis=basis
  seen.positions=actual.map(func(p):return [float(p.x),float(p.y)])
  seen.positions_at=now_c;seen.positions_basis=basis;seen.positions_profile=chosen.profile_id
  seen.erase("formation")
 elif chosen.phase=="remember":
  var assignment:Dictionary=A.assign(displayed,config(chosen.profile_id))
  if assignment.is_empty():reject(state,"incomplete_or_invalid_glyphs");return
  # A current beat can remain at its exact closing snapshot for one frame.
  # Matching repeated sprites cannot revoke an already witnessed public past.
  if not seen.glyphs.is_empty():
   if A.assign(seen.glyphs,config(chosen.profile_id))!=assignment:reject(state,"contradictory_glyphs")
   return
  var now:float=float(state.sim_time);var relative:float=now-float(seen.origin)
  if relative+0.000001<3.0 or relative>=6.1:reject(state,"glyphs_outside_current_window");return
  seen.glyphs=displayed.duplicate(true);seen.at=now;seen.basis=basis
 elif chosen.phase in ["knock","stack"]:
  var ids:Array=[]
  for raw in displayed:
   if not raw is Dictionary or raw.size()!=2 or raw.get("symbol","")!="stack" or not number(raw.get("actor",null)) or float(raw.actor)!=floorf(float(raw.actor)) or int(raw.actor)<0 or int(raw.actor)>7 or int(raw.actor) in ids:
    reject(state,"invalid_stack_glyphs");return
   ids.append(int(raw.actor))
  if ids.size()!=2:reject(state,"incomplete_stack_glyphs");return
  ids.sort()
  if float(state.sim_time)+0.000001<float(seen.origin)+20.8:reject(state,"stack_before_public_window");return
  if not seen.stacks.is_empty() and seen.stacks.map(func(a):return int(a))!=ids:reject(state,"contradictory_stacks");return
  if seen.stacks.is_empty():seen.stacks=ids;seen.stacks_at=float(state.sim_time);seen.stacks_basis=basis
 else:reject(state,"glyphs_outside_current_phase")
static func publish_statuses(beat:Dictionary,state:Dictionary,basis:String="headless_public_statuses_not_displayed",poses:Variant=null)->void:
 if str(selection(beat).get("phase","")) not in ["remember","knock","stack"]:return
 var displayed:Array=[]
 for actor in 8:
  for symbol in Signs.observed_all(actor,beat,state):
   if Signs.symbol_name(symbol) in A.SHAPES or symbol=="stack":displayed.append({"actor":actor,"symbol":symbol})
 publish(beat,state,displayed,basis,poses)
static func tick(beat:Dictionary,state:Dictionary)->void:
 # Restored/retried state recomputes formation from the actual restored poses.
 if is_conga(selection(beat).get("profile_id",null)) and state.get(KEY,null) is Dictionary:state[KEY].erase("formation")
 if not state.get("synergy_presentation_required",false):publish_statuses(beat,state)
## One coherent snapshot per actual clock: all 7 NPC goals derive from the same
## observed poses; NPCs reserve the slot nearest the human's ACTUAL x only.
static func formation_goal(actor:int,actors:Array,state:Dictionary,seen:Dictionary)->Vector2:
 var held:Vector2=R.v(actors[actor].pos)
 if not number(state.get("sim_time",null)):return held
 var now:float=float(state.sim_time)
 var cached:Variant=seen.get("formation",null)
 if not cached is Dictionary or cached.get("clock",null)!=now:
  var poses:Array=pose_snapshot(actors)
  if poses.is_empty():return held
  var raw_human:Variant=state.get("human_actor",-1)
  var human:int=int(raw_human) if number(raw_human) and float(raw_human)==floorf(float(raw_human)) and int(raw_human)>=0 and int(raw_human)<8 else -1
  var previous:Array=[]
  if cached is Dictionary and cached.get("order",null) is Array:
   for a in cached.order:
    if number(a) and int(a)>=0 and int(a)<8 and int(a)!=human and int(a) not in previous:previous.append(int(a))
  if not previous.is_empty():
   for a in 8:
    if a not in previous:previous.append(a)
  var out:Dictionary=Conga.npc_line_goals(poses,human,previous)
  if out.is_empty():return held
  var goals:Array=[];goals.resize(8)
  for a in out.goals:goals[int(a)]=[float(out.goals[a].x),float(out.goals[a].y)]
  cached={"clock":now,"goals":goals,"order":out.npc_order.duplicate(),"reserved_slot":int(out.reserved_slot)}
  seen.formation=cached
 var g:Variant=cached.goals[actor]
 return held if g==null else Vector2(float(g[0]),float(g[1]))
static func conga_goal(actor:int,beat:Dictionary,actors:Array,state:Dictionary,chosen:Dictionary)->Vector2:
 var phase:String=chosen.phase
 var held:Vector2=R.v(actors[actor].pos)
 var seen:Dictionary=memory(beat,state)
 # Invalid/contradictory/cross-profile memory: hold actual pose, no builder route.
 if seen.is_empty():return held
 # Legacy weapon baseline is available only with a valid current public cache.
 if phase=="dodge":return preload("res://scripts/synergy_weapons.gd").goal(actor,beat,actors,state)
 if seen.glyphs.is_empty():
  return formation_goal(actor,actors,state,seen) if phase in ["cast","remember"] else held
 var assignment:Dictionary=assignment_of(seen.glyphs,seen,chosen.profile_id)
 if assignment.is_empty():return held
 if phase in ["remember","appear"]:return frozen_vectors(seen.positions)[actor]
 if phase in ["fire","laser"]:return fire_goal(actor,assignment,bool(chosen.remote),float(chosen.eye_angle))
 if phase in ["knock","stack","blades","expiry","finish"]:
  if seen.stacks.is_empty():return Vector2.ZERO
  return R.v(knock_goals(assignment,seen.stacks,bool(chosen.remote),float(chosen.eye_angle),float(chosen.north),phase!="knock")[actor])
 return held
static func goal(actor:int,beat:Dictionary,actors:Array,state:Dictionary)->Vector2:
 var chosen:Dictionary=selection(beat)
 if chosen.is_empty():return R.v(actors[actor].pos)
 if is_conga(chosen.profile_id):return conga_goal(actor,beat,actors,state,chosen)
 var phase:String=chosen.phase
 if phase=="cast":return queue_goal(actor,{},chosen.profile_id)
 # Dodge reads only the public physical-weapon receipt (no beat.positions).
 if phase=="dodge":return preload("res://scripts/synergy_weapons.gd").goal(actor,beat,actors,state)
 var seen:Dictionary=memory(beat,state)
 var assignment:Dictionary=A.assign(seen.get("glyphs",[]),config(chosen.profile_id))
 if assignment.is_empty():return queue_goal(actor,{},chosen.profile_id)
 if phase in ["remember","appear"]:return queue_goal(actor,assignment)
 if phase in ["fire","laser"]:return fire_goal(actor,assignment,bool(chosen.remote),float(chosen.eye_angle))
 if phase in ["knock","stack","blades","expiry","finish"]:
  if seen.stacks.is_empty():return Vector2.ZERO
  return R.v(knock_goals(assignment,seen.stacks,bool(chosen.remote),float(chosen.eye_angle),float(chosen.north),phase!="knock")[actor])
 return R.v(actors[actor].pos)
