# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const I=preload("res://scripts/interactions.gd")
const Marks=preload("res://scripts/markers.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("OMEGA MAIN FAIL ",label)
func visible_sources(app)->Array:return app.arena.omega_source_loading.values().filter(func(node):return node.visible)
func choose(app,human:int,method:int=4)->void:
	app.return_to_selection();app.role_select.select(human);app.p5_marking_mode="manual"
	for index in app.filtered.size():
		if app.filtered[index].id=="p5_omega":
			app.choose_mechanic(index);app.strategy_select.select(method);app.choose_strategy(method);break
	app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
	for human in 8:
		choose(app,human)
		check(app.state.p5_marking_mode=="manual" and app.state.omega.cooperation.mode=="manual" and int(app.state.human_actor)==human,"actual Main manual actor %d"%human)
		check(app.state.target_markers.mode=="manual","target layer reflects actual mode")
		check(app.state.target_markers.events.all(func(e):return int(e.target)!=human),"NPC never pre-marks actual human")
		check(not app.preparation_report().manual_preparation_complete,"allocation without two real judgments is not manual success")
		check(I.bot_goal(human,app.current,app.actors,app.state)==R.v(app.actors[human].pos),"production guard cannot auto-walk human")
		app.apply_target_marker(human,"attack8");app._process(.05)
		check(Marks.marker_for(app.state,human)=="attack8","actual player wrong sign remains visible")
		check(not app.state.omega.cooperation.latest.errors.is_empty(),"actual input has honest preparation errors")
		check(app.state.runtime_failures.is_empty(),"wrong mark alone is not invented damage")
		var phase:Dictionary=app.encounter.beats.filter(func(b):return b.get("omega_phase","")=="first")[0].duplicate(true)
		I.begin(phase,app.actors,app.state)
		for actor in 8:
			if actor not in app.state.omega.first_roles:
				check(I.bot_goal(actor,phase,app.actors,app.state)==R.v(app.actors[actor].pos),"production unresolved NPC holds without oracle")
		app.retry_beat()
		check(Marks.marker_for(app.state,human)=="" and app.state.omega.cooperation.mode=="manual","real retry restores marks/mode instead of repairing attempt")
		app.show_target_markers()
		for _frame in 3:await process_frame
		check(app.omega_marking_box.visible,"supported guide exposes deliberate mode setting")
		check(app.marker_popup.position.y>=0 and app.marker_popup.position.y+app.marker_popup.size.y<=root.size.y,"mode panel fully onscreen pos%s size%s viewport%s"%[app.marker_popup.position,app.marker_popup.size,root.size])
		app.omega_marking_select.select(1);var before:=JSON.stringify(app.state);var seed_value:int=app.encounter.seed
		check(app.state.p5_marking_mode=="manual","draft alone cannot relabel active attempt")
		app.apply_omega_marking_mode()
		check(app.encounter.seed==seed_value and app.state.p5_marking_mode=="assist" and app.state.omega.cooperation.mode=="assist","mode apply creates fresh same-seed assisted run")
		check(app.state.target_markers.mode=="assist" and app.state.target_markers.events.all(func(e):return e.source=="assist"),"assist provenance is not a human action")
		check(app.preparation_report().assisted and not app.preparation_report().manual_preparation_complete,"assistance cannot count as manual")
		await process_frame
	choose(app,0,1)
	check(not app.state.has("p5_marking_mode") and app.state.omega.cooperation.mode=="legacy_coaching","other profile never inherits CN contract")
	app.show_target_markers();check(not app.omega_marking_box.visible,"unsupported profile is not offered CN mode");app.marker_popup.hide()
	choose(app,0);app.demo=true;app.start_run(0,false)
	check(app.state.p5_marking_mode=="assist" and app.preparation_report().assisted,"demo is explicitly assisted")
	app.demo=false;app.start_run(3,false)
	check(app.checkpoint_assisted and app.state.p5_marking_mode=="assist" and not app.preparation_report().manual_preparation_complete,"synthetic checkpoint has no manual completion credit")
	choose(app,0)
	var wait:Dictionary=app.encounter.beats.filter(func(b):return b.get("omega_wait_phase","")=="first")[0]
	var shown:Dictionary=app.encounter.beats.filter(func(b):return b.get("omega_phase","")=="first")[0].duplicate(true)
	for angle in [90.0,270.0]:
		var live:Dictionary=app.state.duplicate(true);live.omega.monitor_resolved=false;shown.omega_config=shown.omega_config.duplicate(true);shown.omega_config.monitor_angle=angle
		app.arena.update_state(app.actors,wait,0,false,0.0,live)
		check(visible_sources(app).is_empty(),"no hidden monitor side before current reveal")
		app.arena.update_state(app.actors,shown,0,false,0.0,live)
		check(visible_sources(app).size()==1,"actual source loading visible with hints off")
		var source=visible_sources(app)[0]
		check(is_equal_approx(wrapf(float(source.rotation_degrees.y)+angle,-180,180),0),"source cue oriented to actual damage half")
		live.omega.monitor_resolved=true;app.arena.update_state(app.actors,shown,0,false,0.0,live)
		check(visible_sources(app).is_empty(),"real monitor judgment removes loading")
		var restored:Dictionary=live.duplicate(true);restored.omega.monitor_resolved=false
		app.arena.update_state(app.actors,shown,0,false,0.0,restored)
		check(visible_sources(app).size()==1,"retry/new state restores only current source loading")
		app.arena.update_state(app.actors,wait,0,false,0.0,restored)
		check(visible_sources(app).is_empty(),"returning to unrevealed wait never keeps old cue")
	check(app.arena.omega_source_loading.size()<=2,"source geometry pooled across retries and both sides")
	app.return_to_selection();check(visible_sources(app).is_empty(),"selection clears source loading")
	app.queue_free();await process_frame
	print("OMEGA_MAIN_PREPARATION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Main input/modes/retry/provenance and production guard; actual Arena source reveal/reset, not manual full-course proof"}))
	quit(1 if failures else 0)
