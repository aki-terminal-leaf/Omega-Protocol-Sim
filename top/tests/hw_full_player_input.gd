# SPDX-License-Identifier: MIT
extends "res://tests/hw_firstwave_input.gd"
## Controlled real-player input replay from HW0 through Critical Error.
## No demo/prelude/checkpoint; driver reads public initial debuffs and drawn
## towers, uses independent guide choreography, never bot_goal/public cache.
const FULL_DT:=0.05
const KINDS=["overflow","remote","sync","local"]
func formation_point(kind:String,side:float,r:int)->Vector2:
 match kind:
  "overflow":return Vector2(side*10.960155,-10.960155)
  "sync":return Vector2(side*5.282728,11.328847)
  "remote":return Vector2(side*2.598896,12.226845)
  _:return Vector2(side*1.1,13.0) if r==3 else Vector2(side*14.97185,-4.011695)
func post_point(kind:String,side:float,r:int,age:float,profile:String)->Vector2:
 var p:=formation_point(kind,side,r)
 if r==3:
  if age<1.2:return p
  if kind=="remote":return Vector2(side*7,4.5) if profile in ["elemental","kr_09stop"] else Vector2(side*16.5,10)
  if kind=="sync":return p if profile in ["elemental","cn_moogle"] else Vector2(side*6.5,17)
  if kind=="local" and profile in ["elemental","cn_moogle","kr_09stop"]:return Vector2(side*1.1,3.0)
  return p
 if age<1.05:return p
 if kind in ["overflow","local"]:p=Vector2(side*9.899495,-9.899495)
 if age<2.4:return p
 if kind=="remote":p=Vector2(side*5.282728,11.328847)
 if age<2.95:return p
 if kind=="overflow" and profile not in ["cn_moogle","kr_09stop"]:p=Vector2(side*12.4,-12.4)
 if kind=="sync" and profile not in ["cn_moogle","kr_09stop"]:p=Vector2(side*6.5,17)
 if kind=="remote":p=Vector2(side*5.3,4.5) if profile=="kr_09stop" else Vector2(side*16.5,10)
 if age>=4.0 and kind=="local":p=Vector2(side*1.1,-5)
 return p
func current_kind(app,tower_at:float)->String:
 var b:Dictionary=app.state.statuses[app.player]
 var now:float=float(app.state.sim_time)
 for pair in [["overflow","overflow"],["sync","sync"],["remote_code_smell","remote"],["local_code_smell","local"]]:
  if b.has(pair[0]):
   var expires:float=float(b[pair[0]].expires)
   var expected:float=tower_at-(1.0 if str(pair[0]).ends_with("code_smell") else 0.0)
   if expires>now and absf(expires-expected)<.01:return pair[1]
 return "missing_public_role"
func exercise_full(app,method:int,human:int,negative:String=""):
 choose(app,method,human,2)
 var initial:Dictionary=assignment(app);var initial_kind:=KINDS.find(str(initial.kind));var side:float=-1.0 if int(initial.rank)==0 else 1.0
 var r:=0;var axis:Variant=null;var seen:=-1.0;var lane_phase:="out";var source_times:Array=[];var trace:Array=[];var frames:=0;var pressed:=false;var max_excess:=0.0;var first_failure:Variant=null
 var profile:String=str(app.encounter.profile)
 var staging:Variant=null;var role_seen:Dictionary={};var pre_ce_debuggers:Variant=null
 var stop_at:=130.0 if negative=="" else 45.05
 while app.running and float(app.state.sim_time)<stop_at-0.000001 and frames<6000:
  var now:float=float(app.state.sim_time)
  var desired_round:=0 if now<34.0-0.000001 else (1 if now<55.0-0.000001 else (2 if now<76.0-0.000001 else 3))
  if desired_round!=r:r=desired_round;axis=null;seen=-1.0;lane_phase="out";staging=null
  var kind:String=KINDS[posmod(initial_kind+r,4)]
  var tower_at:=24.0+21.0*float(r)
  var here:Vector2=R.v(app.actors[human].pos)
  if not role_seen.has(str(r)):
   var actual_kind:=str(initial.kind) if r==0 else current_kind(app,tower_at)
   check(actual_kind==kind,"current public role agrees with guide cycle r%d human%d"%[r,human])
   role_seen[str(r)]=actual_kind
  kind=str(role_seen[str(r)])
  if staging==null:
   var radial:float=18.0 if kind=="overflow" else (12.5 if kind=="sync" else 3.0)
   staging=here.normalized()*radial
  if now>=108.1 and pre_ce_debuggers==null:pre_ce_debuggers=app.state.statuses.map(func(b):return b.has("overflow_debugger"))
  if axis==null:
   axis=observed_axis(app,str(initial.defamation_colour))
   if axis!=null:seen=now;source_times.append({"round":r,"at":now,"axis":axis})
  if negative=="omit" and r==1:keys([])
  elif axis==null:
   if r==0:keys([])
   else:
    steer(app,staging)
  elif now<tower_at:
   var point:Vector2=formation_point(kind,side,r).rotated(float(axis))
   if kind in ["remote","local"]:
    if now<minf(seen+6.0,tower_at-3.0):steer(app,staging) if r>0 else keys([])
    else:steer(app,point)
   else:
    var radius:float=18.0 if kind=="overflow" else 12.5
    if lane_phase=="out" and absf(here.length()-radius)<.2:lane_phase="around"
    if lane_phase=="around" and absf(angle_difference(here.angle(),point.angle()))<.035:lane_phase="in"
    if lane_phase=="out":steer(app,here.normalized()*radius)
    elif lane_phase=="around":steer(app,Vector2.from_angle(here.angle()+clampf(angle_difference(here.angle(),point.angle()),-.12,.12))*radius)
    else:steer(app,point)
  else:steer(app,post_point(kind,side,r,now-tower_at,profile).rotated(float(axis)))
  pressed=pressed or KEYS.any(func(k):return Input.is_physical_key_pressed(k))
  var dt:=minf(FULL_DT,stop_at-now);app._process(dt);frames+=1
  max_excess=maxf(max_excess,here.distance_to(R.v(app.actors[human].pos))-6.0*dt)
  if first_failure==null and not app.state.runtime_failures.is_empty():first_failure={"at":app.state.sim_time,"failures":app.state.runtime_failures.duplicate(),"human":app.actors[human].pos,"statuses":app.state.statuses[human].duplicate(true)}
  if frames%20==0:trace.append({"at":app.state.sim_time,"kind":kind,"pos":app.actors[human].pos})
 keys([])
 var physical_ok:bool=app.state.runtime_failures.is_empty() and app.state.dead.is_empty() and app.all_errors.is_empty()
 var towers:Array=app.state.hw.history.filter(func(e):return e.kind=="hw_tower")
 check(physical_ok if negative=="" else not physical_ok,"full real-player flow method%d human%d negative%s: %s"%[method,human,negative,str(first_failure)])
 check(towers.size()==(16 if negative=="" else 8) and frames<6000,"all intended real tower judgments reached")
 check(pressed and max_excess<0.00001 and not app.demo and not app.checkpoint_assisted and int(app.state.human_actor)==human,"real input from start, speed6, no demo/checkpoint")
 check(not app.state.get("hw_firstwave_assisted",false) and not app.state.get("hw_later_assisted",false),"no synthetic presentation assistance")
 check(float(app.sprint_left)==0.0 and float(app.dash_left)==0.0,"no Sprint or dash shortcut")
 if negative=="":
  check(towers.all(func(e):return e.hits.size()==1),"all16 tower judgments have exactly one actual occupant")
  check(pre_ce_debuggers is Array and pre_ce_debuggers.size()==8 and pre_ce_debuggers.all(func(x):return x),"all8 real Overflow Debuggers existed before CE")
  check(app.state.hw.history.any(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8),"actual all8 Critical Error immunity")
  for round_index in 4:
   var patches:Array=app.state.hw.history.filter(func(e):return e.kind=="hw_patch" and str(e.id).ends_with("_%d"%round_index))
   check(patches.size()==2,"two real tether breaks in round%d"%round_index)
   if patches.size()==2:
    var expected_first:="local" if round_index==3 else "remote"
    check(expected_first in str(patches[0].id) and float(patches[1].time)-float(patches[0].time)>=.999,"guide break order and actual vulnerability separation round%d"%round_index)
 else:
  check(first_failure is Dictionary and absf(float(first_failure.at)-45.0)<.1,"omission's first actual failure is the second tower deadline")
  check(towers.any(func(e):return int(e.round)==1 and e.hits.is_empty()),"omission has a real empty second-wave tower")
  check(not towers.any(func(e):return int(e.round)==1 and human in e.hits),"omitted player did not occupy any second-wave tower")
 var row:Dictionary={"method":method,"profile":profile,"human":human,"negative":negative,"physical_ok":physical_ok,"first_failure":first_failure,"all_failures":app.state.runtime_failures.duplicate(),"dead":app.state.dead.duplicate(),"towers":towers,"sources":source_times,"max_walk_excess":max_excess,"frames":frames,"trace":trace,"public_roles":role_seen,"pre_ce_debuggers":pre_ce_debuggers,"stop_at":stop_at,"controlled_family":{"order":range(8),"colour":"red","orientations":[2,0,0,0],"nominal_timeline":true,"manual_Main_stepping":true},"scope":"CONTROLLED_PUBLIC_INPUT_FROM_T0, no synthetic prelude; scripted not manual/native/Web certification"}
 rows.append(row);print("HW_FULL_PLAYER_COURSE ",JSON.stringify(row))
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var args:=OS.get_cmdline_user_args();var method:=1;var full:=false
 for arg in args:
  if arg.begins_with("--method="):method=int(arg.trim_prefix("--method="))
  if arg=="--all-roles":full=true
 if "--negative-only" in args:exercise_full(app,method,6,"omit")
 else:
  for human in (range(8) if full else [0]):exercise_full(app,method,human)
  if full:exercise_full(app,method,6,"omit")
 keys([]);app.queue_free();await process_frame
 print("HW_FULL_PLAYER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows.size(),"roles":rows.map(func(x):return x.human),"stop_times":rows.map(func(x):return x.stop_at),"scope":"actual Main WASD fromHW0 to per-row stop; controlled identity/red/[2,0,0,0], nominal guide timeline and manual scene stepping; current public roles/drawn towers, no synthetic prelude; not native/manual/Web/allguide"}))
 quit(1 if failures else 0)
