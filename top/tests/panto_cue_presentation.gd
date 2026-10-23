# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const I=preload("res://scripts/interactions.gd")
const Late=preload("res://scripts/late_damage_preview.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("PANTO PRESENTATION FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 app.return_to_selection()
 for index in app.filtered.size():
  if app.filtered[index].id=="p1_panto":app.choose_mechanic(index);app.strategy_select.select(4);app.choose_strategy(4);break
 app.seed_edit.text="17391";app.demo=false;app.start_run(0,false)
 var initial:Dictionary=app.state.duplicate(true)
 for hints in [false,true]:
  for restore in [false,true]:
   for t in [2.099998,2.0999995,2.1,2.100002,5.599998,5.6,6.100002,7.599998,7.5999995,7.6,7.600002,8.100002]:
    # Presentation-only clock fixture, never used as physical-course evidence.
    var state:Dictionary=initial.duplicate(true);state.sim_time=t
    if restore:state=JSON.parse_string(JSON.stringify(state))
    var beat:Dictionary=app.current.duplicate(true);I.sync(beat,state)
    var expected:Array=Late.shapes(beat,state,t,hints).filter(func(s):return s.get("p1_preview",false) and s.get("kind","")=="cone")
    app.arena.redraw_elapsed=0.0
    app.arena.update_state(app.actors,beat,0,hints,t,state)
    var displayed:Array=app.arena.visible_damage_shapes.filter(func(s):return s.get("p1_preview",false) and s.get("kind","")=="cone")
    check(JSON.stringify(displayed)==JSON.stringify(expected),"same state cue membership without0.07s delay at%.7f hints%s restore%s"%[t,str(hints),str(restore)])
    check(app.arena.panto_displayed_cues==app.arena.panto_cue_signature(expected),"actual drawn signature current at%.7f"%t)
    if expected.size()>0:check(app.arena.aoe.get_surface_count()>0,"eligible cue emitted geometry, not just a Boolean")
  app.arena.update_state(app.actors,app.current,0,hints,0.0,initial.duplicate(true))
  check(app.arena.panto_displayed_cues.is_empty() and app.arena.visible_damage_shapes.filter(func(s):return s.get("p1_preview",false)).is_empty(),"retry removes future cue immediately")
 app.arena.update_state([],{},0,false,0.0,{})
 check(app.arena.panto_displayed_cues.is_empty() and app.arena.aoe.get_surface_count()==0,"selection removes current cue mesh")
 app.queue_free();await process_frame
 print("PANTO_CUE_PRESENTATION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Arena geometry current-predicate boundary updates, hint variants and JSON fixtures; not OS-rendered screenshot or original-game onset"}))
 quit(1 if failures else 0)
