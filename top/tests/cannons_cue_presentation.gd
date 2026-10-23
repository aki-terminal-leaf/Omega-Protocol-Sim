# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const I=preload("res://scripts/interactions.gd")
const O=preload("res://scripts/cannons_observation.gd")
const S=preload("res://scripts/synergy_signs.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("CANNON CUE FAIL ",label)
func ids(values:Array)->Array:
 var result:Array=values.map(func(x):return int(x));result.sort();return result
func choose(app,method:int=2)->void:
 app.return_to_selection();app.role_select.select(0)
 for index in app.filtered.size():
  if app.filtered[index].id=="p1_cannons":app.choose_mechanic(index);app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func fixture(app,initial:Dictionary,t:float,restored:bool,hints:bool)->void:
 var state:Dictionary=initial.duplicate(true);state.sim_time=t
 if restored:state=JSON.parse_string(JSON.stringify(state))
 var index:int=0 if t<6.0 else (1 if t<7.8 else 2)
 var beat:Dictionary=app.encounter.beats[index].duplicate(true);I.sync(beat,state)
 app.state=state;app.current=beat;app.elapsed=t-[0.0,6.0,7.8][index]
 app.arena.update_state(app.actors,beat,0,hints,app.elapsed,state)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for method in [2,7]:
  choose(app,method)
  var initial:Dictionary=app.before_state.duplicate(true)
  var events:Array=initial.p1.pending.filter(func(e):return e.kind=="proteans")
  var first:Array=ids(events[0].targets);var second:Array=ids(events[1].targets)
  for restored in [false,true]:
   for hints in [false,true]:
    for t in [0.0,5.999998,6.0,7.8,9.899998,9.8999995,9.9,14.999998,15.0]:
     fixture(app,initial,t,restored,hints)
     var expected:Array=first if t<6.0 else (second if t+0.000001>=9.9 and t<15.0 else [])
     check(ids(app.arena.cannon_displayed_actors)==expected,"actual textured head IDs method%d t%.7f json%s hint%s"%[method,t,str(restored),str(hints)])
     check(app.state.cannons_observation.first_ids.is_empty() and app.state.cannons_observation.second_ids.is_empty(),"drawing alone is not planner publication")
     var visible:Array=[]
     for actor in 8:
      var marker:Sprite3D=app.arena.mechanic_signs[actor]
      if marker.is_visible_in_tree() and marker.texture!=null:visible.append(actor)
     check(ids(visible)==expected,"actual Sprite3D visibility and non-null texture")
     app.publish_observed_cues()
     var observed:Array=app.state.cannons_observation.first_ids if t<6.0 else app.state.cannons_observation.second_ids
     check(ids(observed)==expected,"only actually displayed IDs enter observation")
  # Simulate unavailable texture before publication, not a fabricated receipt.
  fixture(app,initial,0.0,false,false);var texture=S.texture("cannon");S.textures.cannon=null
  fixture(app,initial,0.0,false,false);app.publish_observed_cues()
  check(app.arena.cannon_displayed_actors.is_empty() and app.state.cannons_observation.first_ids.is_empty(),"null textured sprites cannot reveal hidden targets")
  if method==2:check(range(2,8).all(func(a):return I.bot_goal(a,app.current,app.actors,app.state)==O.neutral(a)),"dynamic NPCs hold without displayed receipt")
  S.textures.cannon=texture;app.arena.update_state(app.actors,app.current,0,false,0.0,app.state);app.publish_observed_cues()
  check(ids(app.state.cannons_observation.first_ids)==first,"valid later texture can establish observed first trio")
 choose(app,2);app.start_run(2,false)
 check(app.checkpoint_assisted and app.state.cannons_observation.first_ids.is_empty() and app.state.cannons_observation.second_ids.is_empty(),"synthetic checkpoint retains assistance without fabricating unseen first heads")
 check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty(),"assisted checkpoint synthesizes a valid past without clearing live failures")
 check(app.state.get("cannons_checkpoint_assisted",false) and app.state.cannons_observation.checkpoint_fixture.basis=="assisted_checkpoint_fixture_not_observed","checkpoint fixture explicitly assisted, never displayed credit")
 check(app.report().checkpoint_assisted and app.feedback.text.contains("分段輔助"),"checkpoint assistance visible and report-separated")
 app.start_run(0,false)
 check(not app.state.get("cannons_checkpoint_assisted",false) and app.state.cannons_observation.checkpoint_fixture.is_empty(),"fresh run cannot inherit assisted fixture")
 app.return_to_selection();check(app.arena.cannon_displayed_actors.is_empty(),"selection clears Cannon receipt")
 app.queue_free();await process_frame
 print("CANNONS_CUE_PRESENTATION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual textured Sprite3D/current-publication identity, hints, JSON, texture absence and checkpoint fixtures; not physical courses or OS/GPU pixels"}))
 quit(1 if failures else 0)
