# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const R=preload("res://scripts/rules.gd")
const I=preload("res://scripts/interactions.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("PANTO MAIN FAIL ",label)
func choose(app,human:int,method:int=4)->void:
 app.return_to_selection();app.role_select.select(human)
 for index in app.filtered.size():
  if app.filtered[index].id=="p1_panto":
   app.choose_mechanic(index);app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func advance(app,until:float)->void:
 var frames:=0
 while float(app.state.sim_time)<until-.00001 and app.running and frames<1000:
  app._process(minf(.05,until-float(app.state.sim_time)));frames+=1
 check(float(app.state.sim_time)>=until-.00001,"actual Main reached requested simulator time %.3f"%until)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
 for human in 8:
  choose(app,human)
  check(app.encounter.id=="p1_panto" and int(app.state.human_actor)==human,"actual selected practice/human %d"%human)
  var spawn:Vector2=R.v(app.actors[human].pos)
  check(spawn==Vector2(-3.5+human,6),"neutral public spawn, not future missile endpoint")
  var baseline:Array=[]
  for actor in 8:baseline.append(I.bot_goal(actor,app.current,app.actors,app.state))
  var hidden:Dictionary=app.current.p1_path.duplicate(true)
  app.current.p1_path.base=float(hidden.base)+123.0;app.current.p1_path.direction=-int(hidden.direction)
  check(range(8).all(func(actor):return I.bot_goal(actor,app.current,app.actors,app.state)==baseline[actor]),"Main initial planner independent of hidden base/sign")
  app.current.p1_path=hidden
  advance(app,2.0)
  check(R.v(app.actors[human].pos)==spawn,"actual Main never moves human before cue")
  check(range(8).all(func(actor):return R.v(app.actors[actor].pos)==Vector2(-3.5+actor,6)),"actual bots hold neutral before displayed axis")
  app.paused=true;var frozen:Dictionary=app.state.duplicate(true);app._process(.3)
  check(app.state==frozen,"pause cannot reveal elapsed cues")
  app.paused=false;advance(app,8.0)
  check(R.v(app.actors[human].pos)==spawn,"actual human remains stationary through revealed direction")
  var report:Dictionary=app.report()
  check(report.mode=="practice" and report.role==["MT","ST","H1","H2","D1","D2","D3","D4"][human],"report preserves actual practice role")
  app.retry_beat()
  check(float(app.state.sim_time)==0.0 and R.v(app.actors[human].pos)==spawn,"real retry restores original epoch and neutral spawn")
  check(range(8).all(func(actor):return I.bot_goal(actor,app.current,app.actors,app.state)==Vector2(-3.5+actor,6)),"retry drops future observation before cue")
  advance(app,13.0)
  check(R.v(app.actors[human].pos)==spawn,"stationary human is not rescued after actual damage")
  check(not app.state.runtime_failures.is_empty(),"actual unperformed mechanic can fail, not silently repaired")
  app.start_run(0,false)
  check(int(app.encounter.seed)==17391 and float(app.state.sim_time)==0.0 and app.state.runtime_failures.is_empty(),"same-seed restart clears attempt failures")
  check(range(8).all(func(actor):return I.bot_goal(actor,app.current,app.actors,app.state)==Vector2(-3.5+actor,6)),"new attempt cannot inherit future cue knowledge")
 # One Main call can contain many internal50ms steps. Only its final actual
 # displayed set may reveal cues to the NEXT call, never an unseen substep.
 choose(app,0);advance(app,7.5)
 check(int(app.state.panto_observation.direction)==0,"no sign before rotated tell")
 app._process(.7)
 check(float(app.state.sim_time)>8.19 and int(app.state.panto_observation.direction)==0,"entire rotated tell skipped inside frame cannot steer NPCs")
 check(app.arena.panto_displayed_cues.is_empty(),"skipped current tell was not published as stale mesh")
 advance(app,9.7)
 check(int(app.state.panto_observation.direction)==0,"nonconsecutive cone reanchors without false sign")
 advance(app,11.7)
 check(int(app.state.panto_observation.direction)==int(app.current.p1_path.direction),"next two actually displayed consecutive cones reveal correct sign")
 for method in [1,2,3,4,5]:
  choose(app,0,method);app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
  advance(app,32.3)
  check(app.state.runtime_failures.is_empty() and app.all_errors.is_empty(),"actual Main demo physical course method%d"%method)
  check(app.state.p1.history.filter(func(e):return e.kind=="hazard").size()==108,"actual Main all108 physical hazards")
  check(app.report().mode=="demo","demo never counted manual practice")
 choose(app,0);app.start_run(2,false)
 check(app.checkpoint_assisted and int(app.state.human_actor)==0,"synthetic checkpoint explicitly assisted and real human retained")
 app.return_to_selection();choose(app,0)
 check(range(8).all(func(actor):return I.bot_goal(actor,app.current,app.actors,app.state)==Vector2(-3.5+actor,6)),"selection/newrun clears earlier source observations")
 app.queue_free();await process_frame
 print("PANTO_MAIN_OBSERVATION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Main humans/neutral spawn/hidden metadata/pause/retry/restart/demo/checkpoint lifecycle; not original-game cue timing or platform acceptance"}))
 quit(1 if failures else 0)
