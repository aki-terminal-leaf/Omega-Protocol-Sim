extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Preview=preload("res://scripts/late_damage_preview.gd")
const Timing=preload("res://tests/timeline_observations.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("LATE_PREVIEW FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var beat:Dictionary={"duration":10.0,"shapes":[{"kind":"circle","radius":8.0}]}
 var state:Dictionary={"sim_time":109.0,"pending":[{"at":110.0}]}
 for guide in [false,true]:
  for remaining in [0.5001,0.5,0.25,0.0,-0.001]:
   check(Preview.visible(beat.shapes[0],beat,state,10.0-remaining,guide)==(remaining>=0 and remaining<=0.5),"snapshot boundary guide%s remaining%s"%[guide,remaining])
 var event:Dictionary={"kind":"donut","radius":20.0,"inner":5.0,"decorative":true,"damage_at":110.0}
 check(not Preview.visible(event,beat,state,9.75,true),"event time wins over unrelated checkpoint, including teaching mode")
 state.sim_time=109.5;check(Preview.visible(event,beat,state,0.0),"absolute event boundary at last0.5")
 state.sim_time=110.01;check(not Preview.visible(event,beat,state,0.0),"resolved event not predictive")
 for cue in [{"kind":"tower"},{"kind":"circle","selectable":true},{"kind":"circle","cue_type":"marker"},{"kind":"circle","cue_type":"persistent"}]:check(Preview.visible(cue,beat,state,0.0),"non-range cue unchanged "+str(cue))
 check(not Preview.visible({"kind":"circle","decorative":true},beat,state,9.8,true),"orphan event cannot use false checkpoint deadline")
 var tell:Dictionary={"kind":"line","cue_type":"telegraph","telegraph_at":102.0,"damage_at":110.0}
 for guide in [false,true]:
  for at in [101.999,102.0,105.0,109.5,110.0,110.001]:
   state.sim_time=at
   check(Preview.visible(tell,beat,state,0.0,guide)==(at>=102.0 and at<=110.0),"source tell onset/expiry independent of checkpoint, guide%s at%s"%[guide,at])
 check(not Preview.visible({"cue_type":"telegraph"},beat,state,0.0),"unbounded telegraph rejected")
 var future:Array=[{"duration":0.1,"shapes":[{"kind":"circle","radius":10.0}]}]
 check(Preview.shapes(beat,state,9.59,false,future).size()==1,"next0.1s beat still hidden at0.51s")
 check(Preview.shapes(beat,state,9.6,false,future).size()==2,"next0.1s snapshot visible across checkpoint at0.5s")
 var before:=var_to_str([beat,state,future]);Preview.shapes(beat,state,9.8,true,future);check(before==var_to_str([beat,state,future]),"pure preview does not mutate judged geometry, queue or clock")
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var summaries:Array=[];var courses:=0;var timing_checks:=0
 for i in app.filtered.size():
  app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1);app.seed_edit.text="17391";app.demo=true;app.hints.button_pressed=false;app.speed_select.select(2);app.start_run(0,false);app.stop_failure.button_pressed=false
  var samples:=0;var shown:=0;var annotated:=0;var untagged:Array=[];var early:=0
  while app.running and samples<10000:
   app._process(0.1);samples+=1
   var shapes:Array=Preview.shapes(app.current,app.state,app.elapsed,false,app.arena.upcoming_beats,app.actors)
   shown+=shapes.size()
   for shape in app.current.get("shapes",[]):
    if Preview.is_cue(shape):continue
    if shape.get("decorative",false):
     if shape.has("damage_at"):annotated+=1
     elif not str(shape.get("name","")) in untagged:untagged.append(str(shape.get("name","")))
    if Preview.visible(shape,app.current,app.state,app.elapsed,true):
     var remaining:float=float(shape.damage_at)-float(app.state.sim_time) if shape.has("damage_at") else float(app.current.duration)-app.elapsed
     if not Preview.in_window(remaining):early+=1
  courses+=1
  check(untagged.is_empty(),app.encounter.id+" all event previews identify actual deadlines "+str(untagged))
  check(early==0,app.encounter.id+" no early footprints in ordinary or teaching mode")
  check(not app.running and app.all_errors.is_empty(),app.encounter.id+" complete unchanged actual moving outcome "+str(app.all_errors))
  var timing:Dictionary=Timing.validate(app);timing_checks+=int(timing.checks)
  check(timing.failures.is_empty(),app.encounter.id+" independent source timing "+str(timing.failures))
  summaries.append({"id":app.encounter.id,"samples":samples,"shown_shapes":shown,"event_samples":annotated,"untagged":untagged,"early":early,"timing_checks":timing.checks,"failures":app.all_errors.duplicate()})
  print("LATE_PREVIEW COURSE ",JSON.stringify(summaries[-1]));await process_frame
 # Production renderer and the short PT beat boundary use the same filter.
 for i in app.filtered.size():
  if app.filtered[i].id!="p2_synergy":continue
  app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1);app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
 for t in [12.89,12.9,13.0,19.69,19.7,20.0,30.99,31.0,31.3]:
  while float(app.state.sim_time)<t-0.000001:app._process(minf(0.05,t-float(app.state.sim_time)))
  app.arena.draw_indicators()
  var visible:Array=app.arena.visible_damage_shapes
  if t==12.89:check(visible.is_empty(),"PT actual renderer hidden before last0.5")
  if t==12.9:check(not visible.is_empty(),"PT actual renderer visible at0.5")
  if t==19.69:check(not visible.any(func(s):return s.get("name","")=="Optical Laser"),"laser hidden at0.51 across Fire checkpoint")
  if t==19.7:check(visible.any(func(s):return s.get("name","")=="Optical Laser"),"laser full0.5 across Fire checkpoint")
  if t==30.99:check(not visible.any(func(s):return s.get("name","")=="Efficient Bladework"),"five M circles hidden at0.51")
  if t==31.0:check(visible.filter(func(s):return s.get("name","")=="Efficient Bladework").size()==5,"all five M circles full0.5 across Spotlight checkpoint")
 # Inspect the actual renderer, not just runtime shapes (the original regression).
 for id in ["p6_arrow_dive","p6_arrow_wave","p6_exa_wave","p6_exa_dive","p1_panto"]:
  for i in app.filtered.size():
   if app.filtered[i].id==id:app.choose_mechanic(i)
  app.strategy_select.select(1);app.choose_strategy(1);app.fresh_seed.set_pressed_no_signal(false);app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
  check(app.encounter.id==id,"named tell drill exists "+id)
  var times:Array=[0.0,1.999,2.0,7.49,7.5,8.01] if id.begins_with("p6_arrow") else ([0.0,0.999,1.0,1.999,2.0,2.999,3.0,10.01,11.49,11.5,12.01] if id.begins_with("p6_exa") else [2.099,2.1,3.0,5.59,5.6,6.11,9.71])
  for at in times:
   while float(app.state.sim_time)<float(at)-0.000001:app._process(minf(0.01,float(at)-float(app.state.sim_time)))
   app.arena.update_state(app.actors,app.current,app.player,false,app.elapsed,app.state);app.arena.draw_indicators()
   var shown:Array=app.arena.visible_damage_shapes
   var tells:Array=shown.filter(func(s):return Preview.is_telegraph(s))
   var expected:Array=[]
   var pending:Array=app.state.get("p6",app.state.get("p1",{})).get("pending",[])
   for e in pending:
    if e.kind!="hazard":continue
    var onset:float=float(e.get("telegraph_at",e.get("locked_at",INF)))
    if id=="p1_panto" and int(e.get("pulse",-1))==0 and int(e.get("ability_id",0))==31501:onset=float(e.at)-4.0
    if onset<=float(at)+0.000001 and float(e.at)>=float(at)-0.000001:expected.append(e)
   check(tells.size()==expected.size(),"production tells %s at%.3f: %d expected%d"%[id,at,tells.size(),expected.size()])
   check(shown.all(func(s):return Preview.is_cue(s) or Preview.in_window(float(s.get("damage_at",INF))-float(app.state.sim_time))),"no future propagation footprints "+id+" at"+str(at))
   if id.begins_with("p6_arrow") and at==0.0:check(tells.size() in [2,4],"initial Arrow branch readable eight seconds before damage")
   if id.begins_with("p6_arrow") and at==2.0:check(tells.size()==6,"second Arrow source group appears atT2")
   if id.begins_with("p6_exa") and at==3.0:check(tells.size()==4,"all four staggered Exaflare starting sources")
   if id=="p1_panto" and at==3.0:check(tells.size()==2,"initial opposite Flamethrowers readable before damage")
  var frozen:float=app.state.sim_time;app.paused=true;app._process(5.0);check(is_equal_approx(frozen,float(app.state.sim_time)),"source tell pauses "+id);app.paused=false
  # Re-entering the same seed restores original source onset, not later pulses.
  app.start_run(0,false);app.arena.update_state(app.actors,app.current,app.player,false,app.elapsed,app.state);app.arena.draw_indicators()
  check(app.arena.visible_damage_shapes.filter(func(s):return Preview.is_telegraph(s)).size()==(0 if id=="p1_panto" else (1 if id.begins_with("p6_exa") else app.state.p6.pending.filter(func(e):return e.kind=="hazard" and e.has("telegraph_at") and float(e.telegraph_at)<=0.000001).size())),"restart restores tell onset "+id)
 for id in ["p3_transition","p4_wave"]:
  for i in app.filtered.size():
   if app.filtered[i].id==id:app.choose_mechanic(i)
  app.strategy_select.select(1);app.choose_strategy(1);app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
  var at:float=1.0 if id=="p3_transition" else 9.0
  while float(app.state.sim_time)<at-0.000001:app._process(minf(0.05,at-float(app.state.sim_time)))
  app.arena.draw_indicators()
  check(app.arena.visible_damage_shapes.any(func(s):return Preview.is_telegraph(s) and str(s.get("name","")).begins_with("Wave Repeater")),"initial five-second ring is rendered "+id)
 var paused_time:float=app.state.sim_time;app.paused=true;app._process(5.0);app.arena.draw_indicators();check(is_equal_approx(paused_time,float(app.state.sim_time)),"pause holds preview simulation clock")
 app.retry_beat();app.arena.update_state(app.actors,app.current,app.player,false,app.elapsed,app.state);app.arena.draw_indicators();check(app.arena.visible_damage_shapes.all(func(s):return Preview.is_cue(s)),"retry clears damage-only previews, retaining valid source tells")
 check(courses==20,"all20 independent drills covered")
 var result:Dictionary={"window_seconds":Preview.WINDOW_SECONDS,"checks":checks,"failures":failures,"courses":courses,"timing_checks":timing_checks,"drills":summaries,"scope":"all20 actual moving Main courses; early explicit tells and late-only damage footprints; production renderer boundaries; no browser claim"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--proof="):
   var f=FileAccess.open(arg.trim_prefix("--proof="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ")+"\n")
 print("LATE_PREVIEW_RESULT ",JSON.stringify(result));app.queue_free();await process_frame;quit(1 if failures else 0)
