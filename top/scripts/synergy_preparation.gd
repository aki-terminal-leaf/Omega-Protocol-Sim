# SPDX-License-Identifier: MIT
extends RefCounted
## Elemental initial role queues and public, remembered glyph assignment.
## Later weapon/new-North presentation is outside this correction's acceptance.
const A=preload("res://scripts/synergy_assignment.gd")
const R=preload("res://scripts/rules.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
const KEY="synergy_preparation"
const LEFT=[2,0,4,6]
const RIGHT=[3,1,5,7]
const PHASES=["cast","remember","appear","dodge","fire","laser","knock","stack","blades","expiry","finish"]
static func config()->Dictionary:
 return {"profile_id":"elemental","left":LEFT.duplicate(),"right":RIGHT.duplicate(),"shape_order":["circle","cross","triangle","square"]}
static func selection(beat:Dictionary)->Dictionary:
 var raw:Variant=beat.get("synergy_public",null)
 if not raw is Dictionary or raw.get("profile_id","")!="elemental" or raw.get("phase","") not in PHASES:return {}
 if not raw.get("remote",null) is bool or not number(raw.get("eye_angle",null)) or not number(raw.get("north",null)):return {}
 if raw.get("left",[])!=LEFT or raw.get("right",[])!=RIGHT or raw.get("shape_order",[])!=config().shape_order:return {}
 return raw
static func number(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value))
static func queue_goal(actor:int,assignment:Dictionary={})->Vector2:
 var queue:Array=LEFT if actor in LEFT else RIGHT
 var side:int=0 if actor in LEFT else 1
 if not assignment.is_empty():side=int(assignment.actor_sides[actor])
 return Vector2(-3.0 if side==0 else 3.0,-5.0+queue.find(actor)*3.0)
static func fire_goal(actor:int,assignment:Dictionary,remote:bool,eye:float)->Vector2:
 var slot:int=assignment.route_order.find(actor);var rank:int=slot/2
 var z:float=-12.0+rank*8.0
 var x:float=sqrt(18.0*18.0-z*z) if remote else 11.0
 if slot%2==1 and remote and rank in [0,3]:z=-z
 return Vector2(-x if slot%2==0 else x,z).rotated(deg_to_rad(eye))
static func knock_goals(assignment:Dictionary,targets:Array,remote:bool,eye:float,north:float,after:bool=false)->Array:
 var left:Array=[];var right:Array=[]
 for slot in 8:
  if slot%2==0:left.append(int(assignment.route_order[slot]))
  else:right.append(int(assignment.route_order[slot]))
 if targets.size()==2 and (int(targets[0]) in left)==(int(targets[1]) in left):
  var candidates:Array=targets.map(func(a):return int(a))
  candidates.sort_custom(func(a,b):return fire_goal(a,assignment,remote,eye).rotated(deg_to_rad(-eye)).y<fire_goal(b,assignment,remote,eye).rotated(deg_to_rad(-eye)).y)
  var chosen:int=candidates[-1];var slot:int=assignment.route_order.find(chosen)
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
static func begin(beat:Dictionary,state:Dictionary)->void:
 var chosen:Dictionary=selection(beat)
 if chosen.is_empty():return
 if chosen.phase=="cast":
  state.erase("synergy_checkpoint_assisted")
  state[KEY]={"version":1,"origin":float(state.get("sim_time",0.0)),"glyphs":[],"at":null,"basis":"","stacks":[],"stacks_at":null,"stacks_basis":"","blocked":false,"invalid":[]}
 if not state.get("synergy_presentation_required",false):publish_statuses(beat,state)
static func memory(beat:Dictionary,state:Dictionary)->Dictionary:
 if selection(beat).is_empty():return {}
 var raw:Variant=state.get(KEY,null)
 if not raw is Dictionary or raw.get("version",0)!=1 or raw.get("blocked",null)!=false or not raw.get("invalid",null) is Array or not raw.invalid.is_empty():return {}
 if not number(raw.get("origin",null)) or not number(state.get("sim_time",null)) or float(state.sim_time)<float(raw.origin):return {}
 if not raw.get("glyphs",null) is Array or not raw.get("stacks",null) is Array:return {}
 if raw.glyphs.is_empty():
  if raw.get("at")!=null or raw.get("basis","")!="":return {}
 else:
  if A.assign(raw.glyphs,config()).is_empty() or not number(raw.get("at",null)):return {}
  var relative:float=float(raw.at)-float(raw.origin)
  if relative+0.000001<3.0 or relative>=6.1 or float(raw.at)>float(state.sim_time)+0.000001:return {}
  if not valid_basis(raw.get("basis",""),state):return {}
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
static func publish(beat:Dictionary,state:Dictionary,displayed:Array,basis:String="displayed_textured_glyphs")->void:
 var chosen:Dictionary=selection(beat);var seen:Dictionary=memory(beat,state)
 if chosen.is_empty() or seen.is_empty():return
 if not valid_basis(basis,state):reject(state,"invalid_basis");return
 if displayed.is_empty():return
 if chosen.phase=="remember":
  var assignment:Dictionary=A.assign(displayed,config())
  if assignment.is_empty():reject(state,"incomplete_or_invalid_glyphs");return
  # A current beat can remain at its exact closing snapshot for one frame.
  # Matching repeated sprites cannot revoke an already witnessed public past.
  if not seen.glyphs.is_empty():
   if A.assign(seen.glyphs,config())!=assignment:reject(state,"contradictory_glyphs")
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
static func publish_statuses(beat:Dictionary,state:Dictionary,basis:String="headless_public_statuses_not_displayed")->void:
 if str(selection(beat).get("phase","")) not in ["remember","knock","stack"]:return
 var displayed:Array=[]
 for actor in 8:
  for symbol in Signs.observed_all(actor,beat,state):
   if Signs.symbol_name(symbol) in A.SHAPES or symbol=="stack":displayed.append({"actor":actor,"symbol":symbol})
 publish(beat,state,displayed,basis)
static func tick(beat:Dictionary,state:Dictionary)->void:
 if not state.get("synergy_presentation_required",false):publish_statuses(beat,state)
static func goal(actor:int,beat:Dictionary,actors:Array,state:Dictionary)->Vector2:
 var chosen:Dictionary=selection(beat)
 if chosen.is_empty():return R.v(actors[actor].pos)
 var phase:String=chosen.phase
 if phase=="cast":return queue_goal(actor)
 # Existing clone/weapon path remains unchanged, not certified by this fix.
 if phase=="dodge":return R.v(beat.positions[actor])
 var seen:Dictionary=memory(beat,state)
 var assignment:Dictionary=A.assign(seen.get("glyphs",[]),config())
 if assignment.is_empty():return queue_goal(actor)
 if phase in ["remember","appear"]:return queue_goal(actor,assignment)
 if phase in ["fire","laser"]:return fire_goal(actor,assignment,bool(chosen.remote),float(chosen.eye_angle))
 if phase in ["knock","stack","blades","expiry","finish"]:
  if seen.stacks.is_empty():return Vector2.ZERO
  return R.v(knock_goals(assignment,seen.stacks,bool(chosen.remote),float(chosen.eye_angle),float(chosen.north),phase!="knock")[actor])
 return R.v(actors[actor].pos)
