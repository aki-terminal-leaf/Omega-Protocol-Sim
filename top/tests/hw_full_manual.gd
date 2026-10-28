# SPDX-License-Identifier: MIT
extends SceneTree
## Ordinary manual actor from t0 through four rounds; controller reads public statuses/towers only.
## Controlled Elemental family; independently encoded training realization, not all-guide certification.
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
 if not ok:failures+=1;print("HW FULL MANUAL FAIL ",label)
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
 C.append_family(ctx,[angle,0,4,6],"red")
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
# Guide role cycle: Overflow -> Remote -> Sync -> Local -> Overflow.
# Fixed numeric realization documents the current training model, not official coordinates.
func role_of(initial:Dictionary,round_index:int)->int:
 var base:int={"overflow":0,"remote":2,"sync":4,"local":6}[str(initial.kind)]
 return posmod(base+round_index*2,8)
func point_for(role:int,side:float,round_index:int)->Vector2:
 match role:
  0:return Vector2(side*10.960155,-10.960155)
  2:return Vector2(side*2.598896,12.226845)
  4:return Vector2(side*5.282728,11.328847)
  _:return Vector2(side*14.97185,-4.011695) if round_index<3 else Vector2(side*1.1,13.0)
func post_tower(role:int,side:float,round_index:int,offset:float)->Vector2:
 var p:Vector2=point_for(role,side,round_index)
 if round_index==3:
  if offset>=1.2:
   if role==2:return Vector2(side*7,4.5)
   if role==6:return Vector2(side*1.1,3.0)
  return p
 if offset<1.05:return p
 if role in [0,6]:p=Vector2(side*9.899495,-9.899495)
 if offset>=2.4 and role==2:p=Vector2(side*5.282728,11.328847)
 if offset>=2.95:
  if role==0:p=Vector2(side*12.4,-12.4)
  if role==4:p=Vector2(side*6.5,17)
  if role==2:p=Vector2(side*16.5,10)
 if offset>=4.0 and role==6:p=Vector2(side*1.1,-5)
 return p
func array_pos(v:Vector2)->Array:return [snappedf(v.x,.001),snappedf(v.y,.001)]
func course(app,human:int,negative:String="")->Dictionary:
 choose(app,1,human,2);app.speed_select.select(2)
 var initial:Dictionary=assignment(app);check(not initial.is_empty(),"initial public debuff role")
 var observed:Dictionary={};var sides:Dictionary={};var lanes:Dictionary={};var seen:Dictionary={}
 var trace:Array=[];var frames:=0;var key_frames:=0;var max_human:=0.0;var max_npc:=0.0
 var first_failure:Dictionary={};var started:Vector2=R.v(app.actors[human].pos)
 while app.running and float(app.state.sim_time)<130.0-.000001 and frames<3500:
  var now:float=app.state.sim_time
  var round_index:=0
  if now>=76.0:round_index=3
  elif now>=55.0:round_index=2
  elif now>=34.0:round_index=1
  var at:=24.0+21.0*round_index;var role:=role_of(initial,round_index);var key:=str(round_index)
  var here:Vector2=R.v(app.actors[human].pos)
  if not observed.has(key):
   var angle=observed_axis(app,str(initial.defamation_colour))
   if angle!=null:
    observed[key]=float(angle);seen[key]=now;lanes[key]="out"
    # A human chooses the shorter side from currently visible geometry.
    # First wave retains independently tested public rank; later choices are free.
    var side:float=-1.0 if int(initial.rank)==0 else 1.0
    if round_index>0:
     var a:Vector2=point_for(role,-1.0,round_index).rotated(float(angle))
     var b:Vector2=point_for(role,1.0,round_index).rotated(float(angle))
     if absf(here.distance_to(a)-here.distance_to(b))>.05:side=-1.0 if here.distance_to(a)<here.distance_to(b) else 1.0
    sides[key]=side
  if negative=="omit_input" or (negative=="omit_handoff" and round_index==0 and now>=24.0):keys([])
  elif not observed.has(key):
   if round_index==0:keys([])
   else:
    var radius:=18.0 if role==0 else (12.5 if role==4 else 3.0)
    steer(app,(here.normalized() if here.length()>.001 else Vector2.UP)*radius)
  else:
   var side:float=sides[key];var angle:float=observed[key]
   if now>=at:steer(app,post_tower(role,side,round_index,now-at).rotated(angle))
   else:
    var target:Vector2=point_for(role,side,round_index).rotated(angle)
    if role in [2,6]:
     if now<at-(4.0 if round_index==0 else 3.0):steer(app,(here.normalized() if here.length()>.001 else Vector2.UP)*3.0)
     else:steer(app,target)
    else:
     var radius:=18.0 if role==0 else 12.5
     if lanes[key]=="out" and absf(here.length()-radius)<.17:lanes[key]="around"
     if lanes[key]=="around" and absf(angle_difference(here.angle(),target.angle()))<.035:lanes[key]="in"
     if lanes[key]=="out":steer(app,here.normalized()*radius)
     elif lanes[key]=="around":steer(app,Vector2.from_angle(here.angle()+clampf(angle_difference(here.angle(),target.angle()),-.12,.12))*radius)
     else:steer(app,target)
  if KEYS.any(func(k):return Input.is_physical_key_pressed(k)):key_frames+=1
  var before:Array=app.actors.map(func(a):return R.v(a.pos));var dt:=minf(.05,130.0-now)
  app._process(dt);frames+=1
  for actor in 8:
   var excess:float=before[actor].distance_to(R.v(app.actors[actor].pos))-6.0*dt
   if actor==human:max_human=maxf(max_human,excess)
   else:max_npc=maxf(max_npc,excess)
  if first_failure.is_empty() and (not app.state.runtime_failures.is_empty() or not app.all_errors.is_empty()):
   first_failure={"at":app.state.sim_time,"runtime":app.state.runtime_failures.duplicate(),"errors":app.all_errors.duplicate(),"statuses":app.state.statuses.duplicate(true),"positions":app.actors.map(func(a):return array_pos(R.v(a.pos)))}
  if frames%4==0 and trace.size()<700:trace.append({"t":snappedf(float(app.state.sim_time),.001),"round":round_index,"role":role,"side":sides.get(key,null),"human":array_pos(R.v(app.actors[human].pos)),"keys":KEYS.filter(func(k):return Input.is_physical_key_pressed(k)),"statuses":app.state.statuses[human].duplicate(true)})
 keys([])
 var history:Array=app.state.hw.history;var towers:Array=history.filter(func(e):return e.kind=="hw_tower");var blasts:Array=history.filter(func(e):return e.kind=="hw_blast")
 var actual_ok:bool=towers.size()==16 and towers.all(func(e):return e.hits.size()==1) and app.state.dead.is_empty() and app.state.runtime_failures.is_empty() and app.all_errors.is_empty() and history.any(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8)
 check(float(app.state.sim_time)>=129.999 and frames<3500,"bounded actual clock130")
 check(not app.demo and app.state.human_actor==human and not app.checkpoint_assisted,"manual ownership entire course")
 check(max_human<=.000004 and max_npc<=.000004 and app.sprint_left==0 and app.dash_left==0,"all motion speed6 no skills or teleport")
 check(KEYS.all(func(k):return not Input.is_physical_key_pressed(k)),"all keys released")
 check(not app.state.get("hw_firstwave_assisted",false) and not app.state.get("hw_later_assisted",false),"public channel never synthetic")
 if negative.is_empty():
  check(actual_ok,"positive full human%d actual outcomes"%human)
  check(blasts.size()==32 and seen.size()==4 and range(4).all(func(r):return float(seen.get(str(r),-1))>=14.0+21.0*r),"all32 blasts and four real tower revelations")
 else:check(not actual_ok and not first_failure.is_empty(),"negative true attack/status consequence "+negative)
 if negative=="omit_input":check(R.v(app.actors[human].pos)==started,"omitted human never auto-moved")
 var row:Dictionary={"human":human,"negative":negative,"ordinary_manual":true,"synthetic_prelude":false,"controlled_family":[2,0,4,6],"initial_public":initial,"tower_reveal_times":seen,"frames":frames,"key_frames":key_frames,"max_human_excess":max_human,"max_npc_excess":max_npc,"actual_outcome":"PASS" if actual_ok else "FAIL","first_failure":first_failure,"tower_events":towers,"blast_count":blasts.size(),"runtime_failures":app.state.runtime_failures.duplicate(),"errors":app.all_errors.duplicate(),"dead":app.state.dead.duplicate(),"trace":trace,"history":history.duplicate(true)}
 rows.append(row)
 var short:Dictionary=row.duplicate(true);short.erase("trace");short.erase("history")
 print("HW_FULL_MANUAL_COURSE ",JSON.stringify(short))
 return row
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var smoke:bool="--smoke" in OS.get_cmdline_user_args()
 for human in ([0] if smoke else range(8)):course(app,human)
 if not smoke:
  course(app,0,"omit_input");course(app,6,"omit_handoff")
 keys([]);app.queue_free();await process_frame
 var result:Dictionary={"checks":checks,"failures":failures,"courses":rows.size(),"rows":rows,"scope":"controlled Elemental ordinary manual t0..130 physical-key driver from public debuffs/towers; numeric guide realization, not native/Web/fullguide certification"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):
   var file=FileAccess.open(arg.trim_prefix("--output=")+"/hw-full-manual.json",FileAccess.WRITE)
   if file:file.store_string(JSON.stringify(result,"  "))
 result.erase("rows");print("HW_FULL_MANUAL_RESULT ",JSON.stringify(result))
 quit(1 if failures else 0)
