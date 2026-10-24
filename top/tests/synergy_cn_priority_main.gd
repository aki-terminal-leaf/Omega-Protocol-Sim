# SPDX-License-Identifier: MIT
extends SceneTree
## Actual Main NPC demo only; not player/manual/Web/native acceptance.
const Main=preload("res://scenes/main.tscn")
const R=preload("res://scripts/rules.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
const ROLES=["MT","ST","H1","H2","D1","D2","D3","D4"]
const PRIORITY=["H1","MT","ST","D1","D2","D3","D4","H2"]
var checks:=0
var failures:Array=[]
var courses:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);print("CN PRIORITY MAIN FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for seed_value in [2,6]:
  app.return_to_selection();app.phase_select.select(0);app.filter_catalog()
  var found:=false
  for n in app.filtered.size():
   if app.filtered[n].id!="p2_synergy":continue
   app.choose_mechanic(n)
   for s in range(1,app.strategy_select.item_count):
    var meta:Variant=app.strategy_select.get_item_metadata(s)
    if meta is Dictionary and str(meta.get("profile",""))=="cn_moogle":app.strategy_select.select(s);app.choose_strategy(s);found=true;break
   break
  check(found,"CN selected seed%d"%seed_value)
  app.seed_edit.text=str(seed_value);app.fresh_seed.set_pressed_no_signal(false);app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
  check(app.demo and str(app.active_profile.get("id",""))=="cn_moogle","actual NPC demo seed%d"%seed_value)
  var max_excess:=0.0;var impulse_frames:=0;var sampled:=false;var pair_rows:Array=[];var frames:=0;var before:Array=[]
  while app.running and frames<1800:
   before.clear()
   for a in app.actors:before.append(R.v(a.pos))
   var old_beat:int=app.index
   var old_time:float=float(app.state.sim_time)
   app._process(0.025)
   # resolve_beat applies a real 13m knockback before pending_advance, while
   # index still names Discharger. Validate the impulse separately from walking.
   var knock_impulse:bool=app.index==old_beat and app.pending_advance and float(app.current.get("knockback",0.0))>0.0
   if knock_impulse:
    impulse_frames+=1
    for actor in 8:check(absf(before[actor].distance_to(R.v(app.actors[actor].pos))-13.0)<=0.15002,"actual13m knockback actor%d seed%d"%[actor,seed_value])
   elif app.index==old_beat:
    for actor in 8:max_excess=maxf(max_excess,before[actor].distance_to(R.v(app.actors[actor].pos))-6.0*0.025)
   if not sampled and old_time<19.65 and float(app.state.sim_time)>=19.65:
    sampled=true
    var glyphs:Dictionary={}
    for m in app.encounter.beats[1].party_statuses:glyphs[int(m.actor)]=Signs.symbol_name(m.symbol)
    var eye:Vector2=Vector2.ZERO
    for entity in app.current.stage_entities:
     if entity.get("form","")=="optical_unit":eye=R.v(entity.pos)
    var theta:float=atan2(eye.x,-eye.y)
    for shape in ["circle","cross","triangle","square"]:
     var pair:Array=[]
     for actor in 8:
      if glyphs[actor]==shape:pair.append(actor)
     pair.sort_custom(func(a,b):return PRIORITY.find(ROLES[a])<PRIORITY.find(ROLES[b]))
     var x0:float=R.v(app.actors[pair[0]].pos).rotated(-theta).x
     var x1:float=R.v(app.actors[pair[1]].pos).rotated(-theta).x
     check(x0<0.0 and x1>0.0,"actual NPC seed%d %s %s>%s"%[seed_value,shape,ROLES[pair[0]],ROLES[pair[1]]])
     pair_rows.append({"shape":shape,"high":ROLES[pair[0]],"low":ROLES[pair[1]],"high_local_x":x0,"low_local_x":x1})
   frames+=1
  check(sampled,"actual Fire phase sampled seed%d"%seed_value)
  check(not app.running and float(app.state.sim_time)>=34.5,"full NPC demo completed seed%d"%seed_value)
  check(app.all_errors.is_empty(),"actual attack/status judgments clean seed%d %s"%[seed_value,str(app.all_errors)])
  check(impulse_frames==1,"one real knockback frame seed%d"%seed_value)
  check(max_excess<0.00002,"ordinary NPC steps <=6m/s seed%d"%seed_value)
  courses.append({"seed":seed_value,"frames":frames,"sim_time":app.state.sim_time,"pairs":pair_rows,"max_movement_excess":max_excess,"knockback_frames":impulse_frames,"all_errors":app.all_errors.duplicate(true)})
  await process_frame
 app.queue_free();await process_frame
 print("CN_PRIORITY_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":courses,"scope":"actual Main full NPC demo only; not manual/native/Web"}))
 quit(1 if not failures.is_empty() else 0)
