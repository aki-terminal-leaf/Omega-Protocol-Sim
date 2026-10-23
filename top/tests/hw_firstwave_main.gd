# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const E=preload("res://scripts/encounters.gd")
const C=preload("res://scripts/hw_courses.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var full_courses:=0
var privacy_fixtures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("HW MAIN FAIL ",label)
func choose(app,method:int,human:int=0):
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 for n in app.filtered.size():
  if app.filtered[n].id=="p3_hello":app.choose_mechanic(n);app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func install(app,profile:String,colour:String,angle:int,human:int=-1):
 var ctx=E.new();ctx.profile={"id":profile};ctx.order=range(8);ctx.positions=[];ctx.labels=[]
 for a in 8:ctx.positions.append(R.direction(a*45.0)*5.0);ctx.labels.append("")
 C.append_family(ctx,[angle,0,0,0],colour)
 app.encounter.beats=ctx.beats;app.encounter.assignments=ctx.order;app.index=0;app.state=app.new_state();app.actors=[]
 app.demo=human<0;app.player=human if human>=0 else 0;app.running=true;app.paused=false;app.all_errors=[];app.journal=[];app.samples=[];app.retry_history=[];app.beat_passed=0;app.beat_failed=0
 app.begin_beat(true)
func advance(app,until:float,dt:float=.1):
 var n:=0
 while app.running and float(app.state.sim_time)<until-.000001 and n<3000:
  app._process(minf(dt,until-float(app.state.sim_time)));n+=1
 check(float(app.state.sim_time)>=until-.000001,"actual Main reached %.3f"%until)
func drawn(app)->Array:
 return app.arena.visible_damage_shapes.filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower")
func first_observation(app)->Dictionary:
 var receipt=app.state.get("hw",{}).get("first_public",{}).get("receipt",null)
 return receipt if receipt is Dictionary else {}
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for method in [1,2,3,4,5]:
  choose(app,method);var profile:String=str(app.encounter.profile)
  var initial:Array=[];var goals:Array=[]
  for colour in ["red","blue"]:
   for angle in 8:
    install(app,profile,colour,angle)
    var poses:Array=app.actors.map(func(a):return R.v(a.pos))
    var current_goals:Array=[]
    for actor in 8:current_goals.append(I.bot_goal(actor,app.current,app.actors,app.state))
    if initial.is_empty():initial=poses;goals=current_goals
    check(poses==initial,"first actual spawn independent hidden colour/orientation %s/%s/%d"%[profile,colour,angle])
    check(current_goals==goals,"pre-source goals independent hidden colour/orientation")
    check(drawn(app).is_empty(),"no actual drawn tower before reveal")
    check(app.state.get("hw_firstwave_presentation_required",false) and not app.state.get("hw_firstwave_assisted",false),"ordinary Main requires actual presentation, not synthetic fallback")
    privacy_fixtures+=1
  # Ordinary generated full demo exercises the actual app lifecycle, not an injected solved route.
  choose(app,method);app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
  advance(app,130.0)
  check(app.state.runtime_failures.is_empty() and app.all_errors.is_empty() and app.state.dead.is_empty(),"unchanged physical full HW actual Main method%d %s"%[method,str(app.state.runtime_failures.slice(0,5))])
  check(app.state.hw.history.filter(func(e):return e.kind=="hw_tower").size()==16,"all16 tower judgments")
  check(app.state.hw.history.filter(func(e):return e.kind=="hw_blast").size()==32,"all32 bug/rot blasts")
  check(app.state.hw.history.any(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8),"real all8 debugger gate")
  check(not app.state.get("hw_firstwave_assisted",false) and first_observation(app).get("source_kind","")=="arena_presented","actual drawn tower source not synthetic")
  full_courses+=1
 # First source crossing in one Main frame: no substep can consume unrendered towers.
 choose(app,1);install(app,"elemental","red",4)
 advance(app,13.9);var before:Array=app.actors.map(func(a):return R.v(a.pos))
 check(drawn(app).is_empty(),"actual reveal boundary before")
 app._process(.3)
 check(app.actors.map(func(a):return R.v(a.pos))==before,"all ordinary substeps held neutral until actual draw")
 check(drawn(app).size()==4 and first_observation(app).get("source_kind","")=="arena_presented","actual fourtower draw publishes after frame")
 var paused:Dictionary=app.state.duplicate(true);app.paused=true;app._process(.2);check(app.state==paused,"pause cannot alter observation/simulation")
 app.paused=false;app.retry_beat();check(float(app.state.sim_time)==3.0 and drawn(app).is_empty(),"beat retry removes future tower drawing")
 check(not first_observation(app).has("targets") or first_observation(app).get("targets",[]).is_empty(),"beat retry clears future target memory")
 # Actual missing human movement must remain physical failure, not NPC rescue.
 choose(app,1);install(app,"elemental","red",2,0);var human_spawn:Vector2=R.v(app.actors[0].pos)
 advance(app,25.0)
 check(R.v(app.actors[0].pos)==human_spawn,"human never auto-moved before/after reveal")
 check(not app.state.runtime_failures.is_empty(),"omitted real player tower causes true failure")
 check(app.state.hw.history.any(func(e):return e.kind=="hw_tower" and e.hits.size()!=1),"true tower occupancy consequence, not a fabricated preparation penalty")
 choose(app,1);app.start_run(2,false)
 check(app.checkpoint_assisted and app.report().checkpoint_assisted,"checkpoint never earns complete-practice credit")
 check(app.state.get("hw_firstwave_assisted",false) and first_observation(app).get("source_kind","")=="synthetic_runtime_fixture","reconstructed past never upgrades to actual observed source")
 check(app.feedback.text.contains("分段輔助") and app.feedback.text.contains("Hello World"),"HW checkpoint assistance is visible, not only hidden report metadata")
 check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty(),"checkpoint past physically reconstructed without erasing failures")
 app.start_run(0,false)
 check(not app.checkpoint_assisted and not app.state.get("hw_firstwave_assisted",false) and first_observation(app).is_empty() and not app.feedback.text.contains("分段輔助"),"fresh run clears checkpoint source/credit/notice")
 app.return_to_selection();check(drawn(app).is_empty(),"leaving HW clears old rendered towers")
 app.queue_free();await process_frame
 print("HW_FIRSTWAVE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"privacy_fixtures":privacy_fixtures,"full_courses":full_courses,"scope":"controlled differential first-spawn fixtures + actual Main five generated demos/drawn-source/substeps/retry/stationary-human; headless scene, not manual/native/Web/allguide proof"}))
 quit(1 if failures else 0)
