extends SceneTree
const MainScene=preload("res://scenes/main.tscn")
const Observer=preload("res://tests/hw_later_observer_diagnostic.gd")
const E=preload("res://scripts/encounters.gd")
const C=preload("res://scripts/hw_courses.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:Array=[]
var rows:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);print("HW_LATER_OBSERVATION_FAIL ",label)
func clean(value):
 if value is Vector2:return [value.x,value.y]
 if value is Array:return value.map(func(x):return clean(x))
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[str(key)]=clean(value[key])
  return result
 return value
func select_hw(app):
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(0)
 for n in app.filtered.size():
  if app.filtered[n].id=="p3_hello":app.choose_mechanic(n);app.strategy_select.select(1);app.choose_strategy(1);break
 app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
func install(app,round_index:int,mode:String,angle:int):
 var ctx=E.new();ctx.profile={"id":"elemental"};ctx.order=range(8);ctx.positions=[];ctx.labels=[]
 for actor in 8:ctx.positions.append(R.direction(actor*45.0)*5.0);ctx.labels.append("")
 var orientations:Array=[0,0,0,0];orientations[round_index]=angle
 C.append_family(ctx,orientations,"red")
 app.encounter.beats=ctx.beats;app.encounter.assignments=ctx.order;app.index=0;app.demo=true;app.player=0
 app.state=app.new_state();app.actors=[];app.running=true;app.paused=false;app.all_errors=[];app.journal=[];app.samples=[];app.retry_history=[];app.beat_passed=0;app.beat_failed=0
 app.observation_mode=mode;app.diagnostic_round=round_index;app.delivered_frames=0;app.altered_frames=0;app.last_publication={}
 app.speed_select.select(2);check(app.speed_select.selected==2,"fixed1x diagnostic speed")
 app.begin_beat(true)
func advance(app,until:float):
 var count:=0
 while app.running and float(app.state.sim_time)<until-0.000001 and count<4000:
  app._process(minf(0.1,until-float(app.state.sim_time)));count+=1
 check(absf(float(app.state.sim_time)-until)<0.00001,"actual Main reached %.3f"%until)
func advance_with_public_trace(app,until:float,from_time:float)->Array:
 var count:=0;var trace:Array=[]
 while app.running and float(app.state.sim_time)<until-0.000001 and count<4000:
  app._process(minf(0.1,until-float(app.state.sim_time)));count+=1
  if float(app.state.sim_time)>=from_time-0.000001:
   var shadow:Dictionary=app.state.duplicate(true);var goals:Array=[]
   for actor in 8:goals.append(I.bot_goal(actor,app.current.duplicate(true),app.actors.duplicate(true),shadow))
   trace.append(clean({"at":app.state.sim_time,"actors":app.actors.map(func(a):return a.pos),"goals":goals}))
 check(absf(float(app.state.sim_time)-until)<0.00001,"traced actual Main reached %.3f"%until)
 return trace
func snapshot(app)->Dictionary:
 var goals:Array=[]
 # Probe goals on a copy: observing this diagnostic must not mutate actual
 # cooperation choices/lane caches or change subsequent real movement.
 var shadow:Dictionary=app.state.duplicate(true)
 for actor in 8:goals.append(I.bot_goal(actor,app.current.duplicate(true),app.actors.duplicate(true),shadow))
 return clean({"time":app.state.sim_time,"beat":app.index,"actors":app.actors.duplicate(true),"goals":goals,"statuses":app.state.get("statuses",[]).duplicate(true),"dead":app.state.get("dead",[]).duplicate(true),"failures":app.state.get("runtime_failures",[]).duplicate(true),"history":app.state.get("hw",{}).get("history",[]).duplicate(true),"first_public":app.state.get("hw",{}).get("first_public",{}).duplicate(true),"hw_keys":app.state.get("hw",{}).keys(),"publication":app.last_publication.duplicate(true),"actual_towers":app.arena.visible_damage_shapes.filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower"),"status_events":app.state.get("status_events",[]).duplicate(true),"all_errors":app.all_errors.duplicate(true),"human_actor":app.state.get("human_actor",-2)})
func physical(row:Dictionary)->Dictionary:
 var result:Dictionary={}
 for key in ["actors","statuses","dead","failures","history","status_events","all_errors"]:result[key]=row.finish[key]
 return result
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 for round_index in [1,2,3]:
  var controls:Dictionary={}
  for mode in ["normal","withheld","contradictory","future_angle_pre_reveal"]:
   var app=MainScene.instantiate();app.set_script(Observer)
   check(app.get_script()==Observer,"observer bound")
   var st=MainScene.get_state();var restored_scene_properties:Array=[]
   for k in st.get_node_property_count(0):
    var property_name=st.get_node_property_name(0,k)
    if property_name!="script":
     app.set(property_name,st.get_node_property_value(0,k));restored_scene_properties.append(str(property_name))
   root.add_child(app);await process_frame
   app.set_process(false);app.arena.set_process(false);select_hw(app)
   var angle:=2 if mode=="future_angle_pre_reveal" else 0
   install(app,round_index,"normal" if mode=="future_angle_pre_reveal" else mode,angle)
   var at:float=24.0+21.0*float(round_index)
   var pre_trace:Array=advance_with_public_trace(app,at-10.1,at-21.0);var before:=snapshot(app)
   check(before.actual_towers.is_empty(),"no actual current tower before reveal round%d %s"%[round_index,mode])
   var row:Dictionary={"round":round_index,"mode":mode,"controlled_orientations":[0,0,0,0],"target_angle":angle,"scene_properties_restored":restored_scene_properties,"before":before,"pre_trace":pre_trace,"scope":"SYNTHETIC controlled all-NPC actual Main; observer-only intervention, never ordinary/manual/player/Web/native proof"}
   if mode=="future_angle_pre_reveal":
    row.pre_reveal_note="continuous 0.1s actual Main pose/goal differential from previous tower judgment through current pre-reveal interval; controlled target orientations0vs2 only"
    check(not pre_trace.is_empty() and pre_trace==controls.normal.pre_trace,"whole pre-reveal trajectory independent of future orientation round%d"%round_index)
    row.pre_reveal_goals_equal_normal=before.goals==controls.normal.before.goals
    row.pre_reveal_actors_equal_normal=before.actors==controls.normal.before.actors
   else:
    advance(app,at-8.0);row.after_reveal=snapshot(app)
    check(row.after_reveal.actual_towers.size()==4,"actual Arena still draws all4 %s round%d"%[mode,round_index])
    var delivered:Array=row.after_reveal.publication.get("delivered",[]).filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower")
    check(delivered.size()==(0 if mode=="withheld" else 4),"NPC publication channel intervention %s round%d"%[mode,round_index])
    if mode=="contradictory":check(delivered!=row.after_reveal.actual_towers,"contradiction differs only in delivered channel")
    advance(app,at+0.05);row.finish=snapshot(app);row.delivered_frames=app.delivered_frames;row.altered_frames=app.altered_frames
    row.towers=row.finish.history.filter(func(e):return e.get("kind","")=="hw_tower" and int(e.get("round",-1))==round_index)
    check(row.towers.size()==4,"four real tower judgments %s round%d"%[mode,round_index])
    if mode=="normal":check(row.towers.all(func(e):return e.hits.size()==1),"normal four one-soaker judgments round%d"%round_index)
    if mode=="normal":check(row.finish.failures.is_empty() and row.finish.dead.is_empty() and row.finish.all_errors.is_empty(),"normal actual NPC outcomes clean round%d"%round_index)
    check(int(row.finish.human_actor)==-1,"all-NPC provenance explicit")
    if mode!="normal":
     row.physical_equal_normal=physical(row)==physical(controls.normal)
     row.goals_after_reveal_equal_normal=row.after_reveal.goals==controls.normal.after_reveal.goals
     check(not row.physical_equal_normal,"actual public channel changes physical outcome %s round%d"%[mode,round_index])
     check(not row.goals_after_reveal_equal_normal,"actual public channel changes goals %s round%d"%[mode,round_index])
   controls[mode]=row;rows.append(row);print("HW_LATER_OBSERVATION_COURSE ",JSON.stringify(row))
   app.queue_free();await process_frame
 print("HW_LATER_OBSERVATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows.size(),"full_judgment_courses":9,"pre_reveal_only_courses":3,"classification":"Changed-source public channel dependence plus continuous controlled pre-reveal0vs2 orientation trajectories; not exhaustive privacy proof","scope":"Elemental fixed family/allNPC controlled actual Main; changed source but no manual/Web/native/fullguide credit"}))
 quit(0 if failures.is_empty() else 1)
