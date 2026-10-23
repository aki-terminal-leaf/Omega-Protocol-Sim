# SPDX-License-Identifier: MIT
extends SceneTree
## Scripted physical-key practice; never player autopilot or manual/native proof.
const Main=preload("res://scenes/main.tscn")
const P=preload("res://scripts/p3_transition_patterns.gd")
const R=preload("res://scripts/rules.gd")
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
var checks:=0
var failures:=0
var rows:Array=[]
var held:Dictionary={}
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<30:print("P3 PLAYER FAIL ",label)
func keys(wanted:Array)->void:
 for code in KEYS:
  var down:bool=code in wanted
  if bool(held.get(code,false))==down:continue
  var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down
  Input.parse_input_event(event);held[code]=down
 Input.flush_buffered_events()
func public_marks(app)->Dictionary:
 var purple:Array=[];var white:Array=[]
 for a in 8:
  for key in ["sniper_cannon_fodder","high_powered_sniper_cannon_fodder"]:
   if not app.state.get("statuses",[])[a].has(key):continue
   if float(app.state.statuses[a][key].expires)<=float(app.state.sim_time):continue
   if key=="sniper_cannon_fodder":purple.append(a)
   else:white.append(a)
 return {"purple":purple,"white":white} if purple.size()==4 and white.size()==2 else {}
func nominal_slot(human:int,marks:Dictionary,route:Dictionary,wrong:=false)->Dictionary:
 var empty:Array=range(8).filter(func(a):return a not in marks.purple and a not in marks.white)
 var group:Array=marks.purple.duplicate() if human in marks.purple else (marks.white.duplicate() if human in marks.white else empty)
 var priority:Array=route.priority.map(func(a):return int(a))
 group.sort_custom(func(a,b):return priority.find(a)<priority.find(b))
 var rank:int=group.find(human)
 var degrees:float=float(route.purple_angles[rank] if human in marks.purple else route.white_angles[rank])
 return {"angle":degrees+(180.0 if wrong else 0.0),"class":"purple" if human in marks.purple else ("white" if human in marks.white else "unmarked"),"rank":rank}
func public_first(app)->int:
 # Read actual scene-node receipts, never the solved observation cache/family.
 var sources:Array=app.arena.p3_displayed_arms
 if sources.size()!=3:return -1
 for source in sources:
  var pos:Vector2=R.v(source.pos)
  if absf(pos.x)<.04 and absf(pos.y)>13.9:return 0 if pos.y<0 else 1
 return -1
func waypoint(nominal:float,first:int,phase:String)->Vector2:
 if first<0:return R.direction(nominal)*19.0
 # Independent numerical construction from the documented legal training path;
 # not a call to courses.pocket/observation.goal and not official guide angles.
 var axis:=float(first)*60.0
 var best_delta:=1000.0;var best_axis:=0.0;var side:=0.0
 for triangle in 3:
  for sign_value in [-1.0,1.0]:
   var center:float=axis+120.0*triangle
   var difference:float=absf(wrapf(nominal-(center+sign_value*16.0),-180.0,180.0))
   if difference<best_delta:best_delta=difference;best_axis=center;side=sign_value
 return R.direction(best_axis+side*(16.0 if phase=="pocket" else 46.0))*(19.0 if phase in ["outer","outer_return"] else 16.5)
func steer(app,target:Vector2)->void:
 var offset:Vector2=target-R.v(app.actors[app.player].pos)
 if offset.length()<.12:keys([]);return
 var local:Vector2=offset.rotated(app.arena.camera_yaw);var wanted:Array=[]
 if absf(local.x)>absf(local.y)*.4142:wanted.append(KEY_D if local.x>0 else KEY_A)
 if absf(local.y)>absf(local.x)*.4142:wanted.append(KEY_S if local.y>0 else KEY_W)
 keys(wanted)
func choose(app,method:int,human:int,seed_value:int)->void:
 keys([]);check(KEYS.all(func(code):return not Input.is_physical_key_pressed(code)),"released prior physical input")
 app.return_to_selection();app.role_select.select(human)
 for index in app.filtered.size():
  if app.filtered[index].id=="p3_transition":app.choose_mechanic(index);app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text=str(seed_value);app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false;app.reset_camera()
 var focus=app.get_viewport().gui_get_focus_owner()
 if focus:focus.release_focus()
 check(app.get_viewport().gui_get_focus_owner()==null and absf(app.arena.camera_yaw)<.00001,"input focus and camera basis")
 check(not app.demo and not app.checkpoint_assisted and int(app.state.human_actor)==human,"fresh human practice")
func course(app,negative:String="")->Dictionary:
 var human:int=app.player;var route:Dictionary=P.data().routes[str(app.current.p3_transition_public.profile_id)]
 var slot:Dictionary={};var first:=-1;var frames:=0;var pressed:=false;var max_speed:=0.0;var pocket_reached_at:Variant=null;var last_target:=Vector2.ZERO;var release_pose:=Vector2.ZERO;var release_at:Variant=null;var release_drift:=0.0
 while app.running and frames<1400:
  if slot.is_empty():
   var marks:Dictionary=public_marks(app)
   if not marks.is_empty():slot=nominal_slot(human,marks,route,negative=="wrong")
  if first<0:first=public_first(app)
  var phase:String=str(app.current.p3_transition_public.phase)
  if slot.is_empty() or negative=="stationary":keys([])
  elif negative=="release" and phase=="pocket":
   keys([])
   if release_at==null:release_at=float(app.state.sim_time);release_pose=R.v(app.actors[human].pos)
  else:
   last_target=waypoint(float(slot.angle),first,phase);steer(app,last_target)
  if KEYS.any(func(code):return Input.is_physical_key_pressed(code)):pressed=true
  var before:Vector2=R.v(app.actors[human].pos);app._process(.025);app.arena._process(.025)
  max_speed=maxf(max_speed,before.distance_to(R.v(app.actors[human].pos))/.025)
  if release_at!=null:release_drift=maxf(release_drift,R.v(app.actors[human].pos).distance_to(release_pose))
  if negative!="release" and phase=="pocket" and pocket_reached_at==null and R.v(app.actors[human].pos).distance_to(last_target)<.16:pocket_reached_at=float(app.state.sim_time)
  frames+=1
 keys([])
 var history:Array=app.state.p3_transition.history;var packets:Array=app.state.p3_transition.packets
 var failed:bool=not app.all_errors.is_empty() or not app.state.runtime_failures.is_empty()
 check(not app.running and frames<1400,"actual full practice course terminates")
 check(history.filter(func(e):return e.kind=="ring").size()==8 and history.filter(func(e):return e.kind=="arm_hit").size()==6 and history.filter(func(e):return e.kind=="sniper").size()==1 and (packets.size()==6 if negative.is_empty() else packets.size()<=6),"all actual concurrent judgments")
 check(app.report().mode=="practice" and not app.report().checkpoint_assisted and int(app.state.human_actor)==human,"never demo/checkpoint credit")
 check(max_speed<6.0001 and float(app.sprint_left)==0 and float(app.dash_left)==0,"walking speed6 without sprint/teleport")
 check(KEYS.all(func(code):return not Input.is_physical_key_pressed(code)),"actual physical keys released")
 if negative.is_empty():
  check(pressed and not slot.is_empty() and first>=0,"observed marks/arms and physical key readback")
  check(not failed,"actual input-driven positive method%d human%d seed%d %s"%[app.strategy_select.selected,human,app.encounter.seed,str(app.all_errors.slice(0,3))])
  check(pocket_reached_at!=null and R.v(app.actors[human].pos).distance_to(last_target)<.16,"independently calculated correct slot reached")
  check(packets.filter(func(packet):return human in packet.hits).size()==1,"exactly one actual magic packet at interpolated snapshot")
 else:
  check(failed,"intentionally wrong/missing input sticky physical failure: "+negative)
  if negative=="release":check(release_at!=null and release_drift<.00001,"released-input human never rescued by NPC")
 var sniper_at:float=-1.0
 if not packets.is_empty():sniper_at=float(packets[0].get("at",-1.0))
 var result:Dictionary={"method":app.strategy_select.selected,"profile":app.encounter.profile,"human":human,"seed":app.encounter.seed,"negative":negative,"observed_first":first,"public_slot":slot,"frames":frames,"max_speed":max_speed,"pocket_reached_at":pocket_reached_at,"sniper_at":sniper_at,"sniper_margin":null if pocket_reached_at==null else sniper_at-float(pocket_reached_at),"physical_failures":app.all_errors.duplicate(),"final_distance":R.v(app.actors[human].pos).distance_to(last_target)}
 rows.append(result);print("P3_PLAYER_COURSE ",JSON.stringify(result));return result
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var smoke:bool="--smoke" in OS.get_cmdline_user_args()
 var seed_value:=17391
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--seed="):seed_value=int(arg.trim_prefix("--seed="))
 for method in ([1] if smoke else [1,2,3,4,5]):
  for human in ([0] if smoke else range(8)):
   choose(app,method,human,seed_value);course(app);await process_frame
 if not smoke:
  for negative in ["stationary","release","wrong"]:choose(app,1,0,seed_value);course(app,negative)
 keys([]);app.queue_free();await process_frame
 print("P3_PUBLIC_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows.size(),"rows":rows,"scope":"scripted physical-key input in actual Main headless; independent public-status/scene-source controller; not manual/native/GPU/full-guide proof"}))
 quit(1 if failures else 0)
