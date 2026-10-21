# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const FX=preload("res://scripts/p3_effects.gd")
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
 checks+=1
 if not ok:failures+=1;print("P3_EFFECTS FAIL ",text)
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.hints.button_pressed=false
 for i in app.filtered.size():
  if app.filtered[i].id=="p3_monitors":app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1)
 app.seed_edit.text="17391";app.demo=true;app.start_run();app.stop_failure.button_pressed=false;app.arena.set_process(false)
 app.arena.update_state(app.actors,app.current,app.player,false,0,app.state);app.arena._process(0.01)
 check(app.arena.p3_loading.size()==4 and app.arena.p3_loading.all(func(n):return n.visible),"boss + three real monitor holders have loading effects")
 if "--require-original" in OS.get_cmdline_user_args():
  for node in app.arena.p3_loading:
   for model in node.get_children():check(bool(model.get_meta("original_geometry",false)),"actual imported original left/right mesh, not fallback")
 var holder:int=app.current.monitors[1].actor;var saved:=JSON.stringify(app.state);var before_pos:Vector3=app.arena.p3_loading[1].global_position
 app.actors[holder].face+=90;app.arena._process(0.01)
 check(app.arena.p3_loading[1].global_position.distance_to(before_pos)>0.3,"left/right projector follows actual model facing, not a suggested solution")
 check(JSON.stringify(app.state)==saved,"facing visual cannot mutate statuses/timers/judgment")
 app.actors[holder].face-=90
 while app.running:app._process(0.1)
 check(app.all_errors.is_empty(),"actual monitor course passes before effects read its recorded hits")
 app.arena._process(0.001)
 check(app.arena.p3_pulses.size()==8 and app.arena.p3_loading.all(func(n):return not n.visible),"actual resolution emits eight hit effects and consumes loading")
 var record:Dictionary=app.state.timeline.filter(func(e):return e.kind=="monitor_resolution")[0]
 var observed:Array=[]
 for source in record.sources:
  for point in source.target_positions:observed.append(Vector2(float(point[0]),float(point[1])))
 for pulse in app.arena.p3_pulses:check(pulse.get_meta("target") in observed,"impact comes from actual recorded hit, not guide positions")
 app.arena._process(0.01);check(app.arena.p3_pulses.size()==8,"rendering another frame does not replay damage/duplicate effects")
 app.arena._process(1.0);check(app.arena.p3_pulses.is_empty(),"impact visual has bounded lifetime")
 app.retry_beat();app.arena.update_state(app.actors,app.current,app.player,false,0,app.state);app.arena._process(0.01)
 check(not app.arena.p3_resolved and app.arena.p3_pulses.is_empty() and app.arena.p3_loading.size()==4,"retry restores loading, not stale explosions")
 app.queue_free();await process_frame;print("P3_EFFECTS checks=",checks," failures=",failures);quit(1 if failures else 0)
