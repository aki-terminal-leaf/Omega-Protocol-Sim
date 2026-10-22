# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Official=preload("res://scripts/official_models.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("CLONE_VISUAL FAIL ",label)
func parts(n:Node)->Array:
 var found:Array=[]
 if n is MeshInstance3D:found.append(n)
 for child in n.get_children():found.append_array(parts(child))
 return found
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for i in app.filtered.size():
  if app.filtered[i].id=="p2_synergy":app.choose_mechanic(i)
 app.strategy_select.select(1);app.choose_strategy(1);app.fresh_seed.set_pressed_no_signal(false);app.seed_edit.text="42";app.demo=true;app.hints.button_pressed=false
 for sword in [false,true]:
  for legs in [false,true]:
   app.active_profile.p2_sword=sword;app.active_profile.p2_legs=legs;app.start_run(0,false);app.stop_failure.button_pressed=false
   for at in [7.0,9.0]:
    while float(app.state.sim_time)<float(at)-0.000001:app._process(minf(0.05,float(at)-float(app.state.sim_time)))
    for guide in [false,true]:
     app.arena.update_state(app.actors,app.current,app.player,guide,app.elapsed,app.state);app.arena._process(0.01)
     for i in app.current.stage_entities.size():
      var e:Dictionary=app.current.stage_entities[i];var n:Node3D=app.arena.stage_nodes[i]
      var text:String=n.get_node("EntityLabel").text.to_upper()
      check(not ["SWORD","SHIELD","LEGS","STAFF","劍","盾","腳刀","法杖","SAFE"].any(func(word):return word in text),"world label never states solution, guide="+str(guide))
      if not str(e.get("id","")).begins_with("helper_"):continue
      var stance:String="NEUTRAL" if at==7.0 else (("SWORD" if sword else "SHIELD") if e.form=="male" else ("LEGS" if legs else "STAFF"))
      check(e.stance==stance,"source stance at actual T8.3 reveal")
      if "--require-official" in OS.get_cmdline_user_args():check(n.get_meta("official_model",false),"actual original M/F geometry installed")
      if n.get_meta("official_model",false):
       var a:Array=parts(n).filter(func(part):return "atr_parts_a" in str(part.name))
       var b:Array=parts(n).filter(func(part):return "atr_parts_b" in str(part.name))
       check(not a.is_empty() and not b.is_empty(),"both original weapon variants exist")
       check(a.all(func(part):return part.visible==(stance in ["SHIELD","LEGS"])),"A original variant visibility")
       check(b.all(func(part):return part.visible==(stance in ["SWORD","STAFF"])),"B original variant visibility")
      else:
       check(n.has_node(stance) if stance!="NEUTRAL" else true,"source ZIP fallback has physical tell")
     app.arena.draw_indicators()
     check(app.arena.visible_damage_shapes.is_empty(),"T7/T9 do not reveal computed safe area or attack footprint")
   var count:=0
   while app.running and count<1000:app._process(0.1);count+=1
   check(not app.running and app.all_errors.is_empty(),"PT full physical course unchanged "+str(app.all_errors))
 print("CLONE_VISUAL_RESULT checks=",checks," failures=",failures)
 var result:Dictionary={"families":4,"checks":checks,"failures":failures,"original_required":"--require-official" in OS.get_cmdline_user_args(),"scope":"actual Main T7 neutral / T9 physical variants; no world-space answer text in normal or guide rendering; four complete moving PT courses"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--proof="):var f=FileAccess.open(arg.trim_prefix("--proof="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ")+"\n")
 app.queue_free();await process_frame;quit(1 if failures else 0)
