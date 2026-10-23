# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const O=preload("res://scripts/p3_transition_observation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("P3 MAIN FAIL ",label)
func choose(app,human:int=0,method:int=1)->void:
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 for index in app.filtered.size():
  if app.filtered[index].id=="p3_transition":app.choose_mechanic(index);app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func advance(app,until:float,frame:=.05)->void:
 var frames:=0
 while float(app.state.sim_time)<until-.00001 and app.running and frames<1000:
  app._process(minf(frame,until-float(app.state.sim_time)));frames+=1
 check(float(app.state.sim_time)>=until-.00001,"actual Main reached %.3f"%until)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for human in 8:
  choose(app,human)
  check(app.encounter.id=="p3_transition" and int(app.state.human_actor)==human,"actual practice/human role")
  var spawn:Vector2=R.v(app.actors[human].pos)
  check(app.state.p3_transition_observation.first==null and app.state.p3_transition_observation.purple.is_empty(),"fresh before first marks tick")
  advance(app,3.3)
  check(R.v(app.actors[human].pos)==spawn,"human not auto staged")
  check(app.arena.p3_displayed_arms.is_empty() and app.state.p3_transition_observation.first==null,"no pre-cue arm nodes/receipt")
  advance(app,4.2)
  check(R.v(app.actors[human].pos)==spawn,"human not moved after cue")
  check(app.arena.p3_displayed_arms.size()==3 and app.state.p3_transition_observation.first!=null,"actual three official visible arm nodes establish orientation")
  check(app.state.p3_transition_observation.basis=="displayed_model_nodes","ordinary scene-node basis")
  app.paused=true;var before:Dictionary=app.state.duplicate(true);app._process(.3);check(app.state==before,"paused state cannot reveal future")
  app.paused=false;app.retry_beat()
  check(float(app.state.sim_time)==0 and app.state.p3_transition_observation.first==null,"retry drops future source memory")
  check(app.arena.p3_displayed_arms.is_empty(),"retry clears old scene-node receipt")
  advance(app,8)
  check(R.v(app.actors[human].pos)==spawn and not app.state.runtime_failures.is_empty(),"unperformed human route really fails without rescue")
  app.start_run(0,false)
  check(app.state.runtime_failures.is_empty() and app.state.p3_transition_observation.first==null,"same-seed restart clean")
 for method in [1,2,3,4,5]:
  choose(app,0,method);app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
  var total:float=0.0
  for beat in app.encounter.beats:total+=float(beat.duration)
  advance(app,total,.1)
  check(app.state.runtime_failures.is_empty() and app.all_errors.is_empty(),"actual Main full P3 demo method%d"%method)
  check(app.state.p3_transition.history.filter(func(e):return e.kind=="ring").size()==8 and app.state.p3_transition.packets.size()==6,"all ring/sniper judgments actual Main")
  check(app.report().mode=="demo" and not app.report().checkpoint_assisted,"demo not manual credit")
 # A single ordinary frame contains substeps across the first source onset.
 choose(app);advance(app,3.3)
 var expected:Array=[]
 for a in 8:expected.append(R.v(app.actors[a].pos).move_toward(I.bot_goal(a,app.current,app.actors,app.state),6.0*.6))
 app._process(.6)
 check(range(1,8).all(func(a):return R.v(app.actors[a].pos).distance_to(expected[a])<.00001),"unpresented internal cues cannot influence same-frame substeps")
 check(app.state.p3_transition_observation.first!=null,"ordinary frame publishes only after movement")
 # Simulate unavailable model asset through actual scene nodes, not a forged receipt.
 choose(app);advance(app,3.3)
 app._process(.6)
 var initial:Dictionary=app.state.duplicate(true);O.begin(app.current,initial);app.state=initial
 for node in app.arena.stage_nodes:
  if node.get_meta("model_form","") in ["arm_left","arm_right"]:node.set_meta("official_model",false)
 app.arena.update_state(app.actors,app.current,0,false,app.elapsed,app.state);app.publish_observed_cues()
 check(app.arena.p3_displayed_arms.is_empty() and app.state.p3_transition_observation.first==null,"missing official model cannot publish dictionary-only cue")
 choose(app);app.start_run(2,false)
 check(app.checkpoint_assisted and app.state.get("p3_checkpoint_assisted",false),"checkpoint explicitly assisted")
 check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty(),"assisted past physically valid without clearing failures")
 check(app.state.p3_transition_observation.basis=="assisted_checkpoint_not_observed" and app.report().checkpoint_assisted,"synthetic past never upgrades to observed/manual")
 check(app.feedback.text.contains("分段輔助"),"checkpoint assistance visible")
 app.start_run(0,false);check(not app.state.get("p3_checkpoint_assisted",false) and app.state.p3_transition_observation.first==null,"fresh run clears assistance")
 app.return_to_selection();check(app.arena.p3_displayed_arms.is_empty(),"selection clears P3 receipt")
 app.queue_free();await process_frame
 print("P3_PUBLIC_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Main human ownership, actual official scene-node receipt, pause/retry/restart/demo/substeps/checkpoint; headless scene not GPU/native pixels/manual guide certification"}))
 quit(1 if failures else 0)
