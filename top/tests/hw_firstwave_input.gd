# SPDX-License-Identifier: MIT
extends SceneTree
## Actual Main physical-key first-wave input. Public statuses/drawn towers only.
const Main=preload("res://scenes/main.tscn")
const E=preload("res://scripts/encounters.gd")
const C=preload("res://scripts/hw_courses.gd")
const R=preload("res://scripts/rules.gd")
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
var checks:=0
var failures:=0
var rows:Array=[]
var held:Dictionary={}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("HW INPUT FAIL ",label)
func keys(wanted:Array):
 for code in KEYS:
  var down:bool=code in wanted
  if bool(held.get(code,false))==down:continue
  var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e);held[code]=down
 Input.flush_buffered_events()
func steer(app,target:Vector2):
 var d:Vector2=(target-R.v(app.actors[app.player].pos)).rotated(app.arena.camera_yaw)
 if d.length()<.10:keys([]);return
 var wanted:Array=[]
 if absf(d.x)>absf(d.y)*.4142:wanted.append(KEY_D if d.x>0 else KEY_A)
 if absf(d.y)>absf(d.x)*.4142:wanted.append(KEY_S if d.y>0 else KEY_W)
 keys(wanted)
func choose(app,method:int,human:int,angle:int):
 keys([]);app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 for n in app.filtered.size():
  if app.filtered[n].id=="p3_hello":app.choose_mechanic(n);app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
 # Controlled colour/angle/identity-order family, not a claim that this was RNG generated.
 var ctx=E.new();ctx.profile={"id":str(app.encounter.profile)};ctx.order=range(8);ctx.positions=[];ctx.labels=[]
 for a in 8:ctx.positions.append(R.direction(a*45.0)*5.0);ctx.labels.append("")
 C.append_family(ctx,[angle,0,0,0],"red")
 app.encounter.beats=ctx.beats;app.encounter.assignments=ctx.order;app.index=0;app.state=app.new_state();app.actors=[];app.player=human;app.demo=false;app.running=true;app.paused=false;app.all_errors=[];app.journal=[];app.samples=[];app.retry_history=[];app.beat_passed=0;app.beat_failed=0
 app.begin_beat(true);app.reset_camera();var focus=app.get_viewport().gui_get_focus_owner()
 if focus:focus.release_focus()
 check(not app.demo and int(app.state.human_actor)==human and not app.checkpoint_assisted,"ordinary actual human, no demo/checkpoint")
func assignment(app)->Dictionary:
 # Observe actual initial public debuffs; do not read planned order/courses/goals.
 var groups:Dictionary={"overflow":[],"sync":[],"remote":[],"local":[]}
 var colour:=""
 for a in 8:
  var buffs:Dictionary=app.state.statuses[a]
  if buffs.has("smell_overflow"):
   groups.overflow.append(a);colour="red" if buffs.has("smell_red") else "blue"
  elif buffs.has("smell_sync"):groups.sync.append(a)
  elif buffs.has("remote_code_smell") and buffs.has("local_code_smell"):
   if float(buffs.remote_code_smell.expires)<float(buffs.local_code_smell.expires):groups.remote.append(a)
   else:groups.local.append(a)
 for kind in groups:
  groups[kind].sort()
  if app.player in groups[kind]:return {"kind":kind,"rank":groups[kind].find(app.player),"defamation_colour":colour}
 return {}
func observed_axis(app,colour:String):
 var towers:Array=app.arena.visible_damage_shapes.filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower")
 if towers.size()!=4:return null
 var axis:=Vector2.ZERO
 for tower in towers:
  if str(tower.colour)==colour:axis+=R.v(tower.pos).normalized()
 return angle_difference(Vector2.UP.angle(),axis.angle())
func target(slot:Dictionary,axis:float,alternate:bool,wrong:bool)->Vector2:
 var side:float=-1.0 if int(slot.rank)==0 else 1.0
 if alternate:side=-side
 var point:Vector2
 # Independently written numeric realization of source radial responsibilities;
 # not an observation.goal/base_goal/Bot endpoint lookup. Physical checks below
 # validate effects, not equality to the production waypoint formula.
 match str(slot.kind):
  "overflow":point=Vector2(side*10.960155,-10.960155)
  "sync":point=Vector2(side*5.282728,11.328847)
  "remote":point=Vector2(side*2.598896,12.226845)
  _:point=Vector2(side*14.97185,-4.011695)
 return point.rotated(axis+(PI if wrong else 0.0))
func exercise(app,method:int,human:int,alternate:bool=false,negative:String="",step_dt:float=.025):
 var orientation:=0 if alternate else 2
 choose(app,method,human,orientation)
 var slot:Dictionary=assignment(app);check(not slot.is_empty(),"initial public responsibility observed")
 var spawn:Vector2=R.v(app.actors[human].pos);var seen:=-1.0;var axis:Variant=null;var lane_phase:="out";var pressed:=false;var speed:=0.0;var max_walk_excess:=0.0;var release_pose:=Vector2.ZERO;var released:=false;var release_drift:=0.0;var frames:=0
 while float(app.state.sim_time)<24.05-.000001 and app.running and frames<20000:
  var now:float=float(app.state.sim_time)
  if axis==null:
   axis=observed_axis(app,str(slot.defamation_colour))
   if axis!=null:seen=now
  if axis==null or negative in ["omitted","hold_legal"] or (negative=="late" and now<23.0) or (negative=="release" and now>=15.0):
   keys([])
   if negative=="release" and now>=15.0 and not released:released=true;release_pose=R.v(app.actors[human].pos)
  else:
   var point:Vector2=target(slot,float(axis),alternate,negative=="wrong")
   if str(slot.kind) in ["remote","local"]:
    if now<seen+6.0:keys([])
    else:steer(app,point)
   else:
    var here:Vector2=R.v(app.actors[human].pos);var radius:float=18.0 if str(slot.kind)=="overflow" else 12.5
    if lane_phase=="out" and absf(here.length()-radius)<.17:lane_phase="around"
    if lane_phase=="around" and absf(angle_difference(here.angle(),point.angle()))<.035:lane_phase="in"
    if lane_phase=="out":steer(app,here.normalized()*radius)
    elif lane_phase=="around":steer(app,Vector2.from_angle(here.angle()+clampf(angle_difference(here.angle(),point.angle()),-.12,.12))*radius)
    else:steer(app,point)
  pressed=pressed or KEYS.any(func(k):return Input.is_physical_key_pressed(k))
  var before:Vector2=R.v(app.actors[human].pos);var dt:=minf(step_dt,24.05-now);app._process(dt)
  speed=maxf(speed,before.distance_to(R.v(app.actors[human].pos))/dt)
  max_walk_excess=maxf(max_walk_excess,before.distance_to(R.v(app.actors[human].pos))-6.0*dt)
  if released:release_drift=maxf(release_drift,R.v(app.actors[human].pos).distance_to(release_pose))
  frames+=1
 keys([])
 var actual_failure:bool=not app.state.runtime_failures.is_empty() or not app.all_errors.is_empty()
 var tower_events:Array=app.state.hw.history.filter(func(e):return e.kind=="hw_tower")
 check(frames<20000 and float(app.state.sim_time)>=24.05-.000001,"first real tower phase ends")
 check(tower_events.size()==4,"four actual tower judgments")
 check(max_walk_excess<=0.000004 and float(app.sprint_left)==0 and float(app.dash_left)==0,"actual physical keys obey speed6, no skill/teleport")
 check(KEYS.all(func(k):return not Input.is_physical_key_pressed(k)),"all physical keys released")
 check(not app.state.get("hw_firstwave_assisted",false),"actual Main publication, never synthetic assistance")
 if negative.is_empty() or negative=="hold_legal":
  check(not actual_failure and app.state.dead.is_empty(),"real player/NPC firstwave success method%d human%d alternate%s %s"%[method,human,alternate,str(app.state.runtime_failures.slice(0,4))])
  check((pressed or negative=="hold_legal") and seen>=14.0 and tower_events.all(func(e):return e.hits.size()==1),"real input after public towers and actual one-person occupancy")
  if alternate:check(app.state.hw.has("hw_tower_choice_0_%d"%(0 if human<2 else 4)),"NPC reacted to actual alternative, not scripted same ending")
 else:
  check(actual_failure,"actual consequence for "+negative)
  if negative=="omitted":check(R.v(app.actors[human].pos)==spawn,"omitted human never moved by NPC")
  if negative=="release":check(released and release_drift<.000001,"released player never rescued")
 var row:Dictionary={"method":method,"human":human,"role":slot,"orientation":orientation,"alternate":alternate,"negative":negative,"source_at":seen,"step_dt":step_dt,"max_speed":speed,"max_walk_excess":max_walk_excess,"failures":app.state.runtime_failures.duplicate(),"tower_hits":tower_events.map(func(e):return e.hits),"release_drift":release_drift}
 rows.append(row);print("HW_INPUT_COURSE ",JSON.stringify(row))
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var smoke:bool="--smoke" in OS.get_cmdline_user_args()
 if "--fine-only" in OS.get_cmdline_user_args():
  exercise(app,1,1,false,"",1.0/480.0)
  exercise(app,1,1,false,"hold_legal",1.0/480.0)
 elif "--focused" in OS.get_cmdline_user_args():
  for human in [1,4]:exercise(app,1,human)
  exercise(app,1,1,false,"hold_legal")
  exercise(app,1,0,true)
  exercise(app,1,0,false,"omitted")
 else:
  for method in ([1] if smoke else [1,2,3,4,5]):
   for human in ([0] if smoke else range(8)):exercise(app,method,human)
   for human in ([0] if smoke else [0,1,4,5]):exercise(app,method,human,true)
  for negative in (["omitted"] if smoke else ["omitted","wrong","late","release"]):exercise(app,1,0,false,negative)
  if not smoke:
   exercise(app,1,1,false,"hold_legal")
   exercise(app,1,1,false,"",1.0/480.0)
   exercise(app,1,1,false,"hold_legal",1.0/480.0)
 keys([]);app.queue_free();await process_frame
 print("HW_FIRSTWAVE_INPUT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows.size(),"rows":rows,"scope":"actual Main physical WASD from public initial statuses/drawn tower geometry; controlled firstwave families, not fullfourround/manual/native/Web/allguide conformance"}))
 quit(1 if failures else 0)
