# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const O=preload("res://scripts/cannons_observation.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var rows:Array=[]
var held:Dictionary={}
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<=24:print("CANNONS MAIN FAIL ",label)
func keys(wanted:Array)->void:
 for key in KEYS:
  var down:bool=key in wanted
  if bool(held.get(key,false))==down:continue
  var event=InputEventKey.new();event.physical_keycode=key;event.keycode=key;event.pressed=down
  Input.parse_input_event(event);held[key]=down
 Input.flush_buffered_events()
func steer(app,goal:Vector2)->void:
 var delta:Vector2=goal-R.v(app.actors[app.player].pos)
 if delta.length()<.12:keys([]);return
 # Invert the real public camera basis; use only ordinary physical-key input.
 var local:Vector2=delta.rotated(app.arena.camera_yaw);var wanted:Array=[]
 if absf(local.x)>absf(local.y)*.4142:wanted.append(KEY_D if local.x>0 else KEY_A)
 if absf(local.y)>absf(local.x)*.4142:wanted.append(KEY_S if local.y>0 else KEY_W)
 keys(wanted)
func choose(app,method:int,human:int,seed_value:int=17391,checkpoint:int=0)->void:
 keys([]);app.return_to_selection();app.role_select.select(human)
 for index in app.filtered.size():
  if app.filtered[index].id=="p1_cannons":app.choose_mechanic(index);app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text=str(seed_value);app.demo=false;app.start_run(checkpoint,false);app.stop_failure.button_pressed=false;app.reset_camera()
 var focus=app.get_viewport().gui_get_focus_owner()
 if focus:focus.release_focus()
func advance_course(app,negative:bool=false,alternative:bool=false)->Dictionary:
 var human:int=app.player;var start:Vector2=R.v(app.actors[human].pos);var freeze:Vector2=start;var frozen:=false;var drift:=false;var frames:=0
 while app.running and frames<1000:
  var now:float=float(app.state.sim_time)
  if negative:
   if human<2:keys([])
   elif now<4.7:steer(app,Vector2(0,-18))
   else:
    keys([])
    if not frozen:freeze=R.v(app.actors[human].pos);frozen=true;check(freeze.length()>17.4,"negative input really moved non-tank farther than tanks")
  else:
   # Replay agent sees only the publicly selected method and actual published
   # heads. It is not an NPC driving YOU or a hidden beat.positions oracle.
   var goal:Vector2=O.goal(human,app.current,app.actors,app.state)
   if alternative:goal=goal.normalized()*10.0
   steer(app,goal)
  app._process(.025);app.arena._process(.025);frames+=1
  if negative and (human<2 or frozen):
   var expected:Vector2=start if human<2 else freeze
   if R.v(app.actors[human].pos).distance_to(expected)>.001:drift=true
 keys([])
 check(not app.running and absf(float(app.state.sim_time)-15.1)<.03,"actual Main reaches full15.1s without autochanging mechanism")
 check(int(app.state.human_actor)==human and not app.demo,"actual selected human remains human in practice")
 var history:Array=app.state.p1.history
 check(history.filter(func(e):return e.kind=="cleaves").size()==5 and history.filter(func(e):return e.kind=="proteans").size()==2,"all five real cleaves and two real target waves")
 var failed:bool=not app.all_errors.is_empty() or not app.state.runtime_failures.is_empty()
 if negative:
  check(failed,"actual intentionally wrong human route causes sticky physical failure")
  check(not drift,"NPCs never rescue or move released-input human")
  if human>=2:check(history.filter(func(e):return e.kind=="cleaves").any(func(e):return human in e.targets),"actual farthest retarget includes misplaced non-tank")
 else:
  check(not failed,"input-driven human physical course "+str(app.strategy_select.selected)+"/"+str(human)+": "+str(app.all_errors.slice(0,2)))
  if alternative:check(R.v(app.actors[human].pos).distance_to(O.goal(human,app.current,app.actors,app.state))>1.8,"legal radial alternative not forced to exact suggested endpoint")
 return {"method":app.strategy_select.selected,"profile":app.encounter.profile,"human":human,"seed":app.encounter.seed,"negative":negative,"alternative":alternative,"checkpoint_assisted":app.checkpoint_assisted,"frames":frames,"physical_failures":app.all_errors.duplicate(),"first_ids":app.state.cannons_observation.first_ids.duplicate(),"second_ids":app.state.cannons_observation.second_ids.duplicate()}
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var fast:bool="--fast" in OS.get_cmdline_user_args();var methods:Array=[1,2] if fast else [1,2,3,4,5,6,7]
 for method in methods:
  for human in 8:
   choose(app,method,human)
   check(app.encounter.id=="p1_cannons" and app.actors.size()==8,"actual mechanic and party selected")
   check(range(8).all(func(a):return R.v(app.actors[a].pos)==O.neutral(a)),"subset-independent actual neutral entry")
   rows.append(advance_course(app));await process_frame
 if not fast:
  for method in methods:
   for pair in [[0,7],[4,43]]:
    choose(app,method,int(pair[0]),int(pair[1]));rows.append(advance_course(app));await process_frame
 for human in 8:
  choose(app,2,human);rows.append(advance_course(app,true));await process_frame
 choose(app,4,5);rows.append(advance_course(app,false,true));await process_frame
 # Synthetic checkpoints stay explicitly assisted. They must not fabricate an
 # actual first-head receipt or carry failed prehistory into the chosen point.
 for checkpoint in [1,2]:
  choose(app,2,0,17391,checkpoint)
  check(app.checkpoint_assisted and app.state.get("cannons_checkpoint_assisted",false),"checkpoint explicitly assisted")
  check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty(),"checkpoint prehistory valid without erasing a real live attempt")
  check(app.state.cannons_observation.first_ids.is_empty() and app.state.cannons_observation.first_at==null,"synthetic fixture never pretends actual first observation")
  check(app.state.cannons_observation.checkpoint_fixture.basis=="assisted_checkpoint_fixture_not_observed","separate assisted fixture provenance")
  rows.append(advance_course(app));await process_frame
 choose(app,2,0);app._process(.5);app.arena._process(.5);var first:Array=app.state.cannons_observation.first_ids.duplicate()
 app.paused=true;var before:Dictionary=app.state.duplicate(true);app._process(.3);check(app.state==before,"pause cannot manufacture head observations")
 app.paused=false;app.retry_beat();check(app.state.cannons_observation.first_ids==first and app.state.cannons_observation.checkpoint_fixture.is_empty(),"live retry regenerates real current first heads without assisted fixture")
 app.start_run(0,false);check(not app.checkpoint_assisted and not app.state.get("cannons_checkpoint_assisted",false) and app.state.cannons_observation.checkpoint_fixture.is_empty(),"fresh R/start clears checkpoint grant")
 keys([]);app.queue_free();await process_frame
 var result:Dictionary={"checks":checks,"failures":failures,"courses":rows,"scope":"actual Main physical W/A/S/D replay from published public observations; seven methods/eight human roles, no NPC rescue, deliberate physical negatives, legal radial alternative and labelled checkpoints; not native真人/manual full-guide proof"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):
   var file=FileAccess.open(arg.substr(6),FileAccess.WRITE)
   if file:file.store_string(JSON.stringify(result,"  "))
 print("CANNONS_MAIN_OBSERVATION courses=",rows.size()," ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(1 if failures else 0)
