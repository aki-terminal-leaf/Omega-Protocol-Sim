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
	if not ok:failures+=1;print("SIGMA MAIN FAIL ",label)
func choose(app,human:int,method:int=4)->void:
	app.return_to_selection();app.role_select.select(human);app.p5_marking_mode="manual"
	for index in app.filtered.size():
		if app.filtered[index].id=="p5_sigma":
			app.choose_mechanic(index);app.strategy_select.select(method);app.choose_strategy(method);break
	app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
	for human in 8:
		choose(app,human)
		check(app.sigma_marking_supported() and app.p5_marking_supported(),"CN Sigma offers mode explicitly")
		check(app.state.p5_marking_mode=="manual" and app.state.sigma.cooperation.mode=="manual" and int(app.state.human_actor)==human,"actual Main manual actor %d"%human)
		check(app.state.target_markers.mode=="manual","actual marker layer mode")
		check(app.state.target_markers.events.all(func(e):return int(e.target)!=human),"NPC never pre-marks human")
		check(not app.preparation_report().manual_preparation_complete and not app.preparation_report().locked,"no credit before actual route lock")
		var human_position:Vector2=R.v(app.actors[human].pos)
		app.apply_target_marker(human,"attack8");app._process(.05)
		check(Marks.marker_for(app.state,human)=="attack8","wrong explicit self input remains visible")
		check(not app.state.sigma.cooperation.latest.errors.is_empty(),"real input has preparation errors")
		check(app.state.runtime_failures.is_empty(),"wrong mark itself is not synthetic combat damage")
		check(R.v(app.actors[human].pos)==human_position and I.bot_goal(human,app.current,app.actors,app.state)==human_position,"no automatic human movement")
		app.paused=true;var sequence:int=int(app.state.target_markers.sequence);app.apply_target_marker(human,"attack1")
		check(int(app.state.target_markers.sequence)==sequence,"pause blocks marker action")
		app.paused=false;app.retry_beat()
		check(Marks.marker_for(app.state,human)=="" and app.state.sigma.cooperation.mode=="manual","retry restores original actual mark/mode state")
		app.show_target_markers()
		for _frame in 3:await process_frame
		check(app.omega_marking_box.visible,"mode control visible for supported method")
		check(app.marker_popup.position.y>=0 and app.marker_popup.position.y+app.marker_popup.size.y<=root.size.y,"first popup fits viewport")
		app.omega_marking_select.select(1);var seed_value:int=app.encounter.seed
		var prior_files:Array=Array(DirAccess.get_files_at("user://"))
		check(app.state.p5_marking_mode=="manual","draft does not relabel old attempt")
		app.apply_omega_marking_mode()
		check(app.encounter.seed==seed_value and app.state.p5_marking_mode=="assist" and app.state.sigma.cooperation.mode=="assist","apply is fresh same-seed assistance")
		check(app.state.target_markers.mode=="assist" and app.state.target_markers.events.all(func(e):return e.source=="assist"),"assist sources never fabricated player actions")
		check(app.preparation_report().assisted and not app.preparation_report().manual_preparation_complete,"assisted attempt cannot count manual")
		check(float(app.state.bot_sprint_until[human])==0.0,"assistance leaves human abilities to player")
		var archives:Array=Array(DirAccess.get_files_at("user://")).filter(func(name):return str(name).begins_with("before-marking-mode-") and name not in prior_files);archives.sort()
		check(not archives.is_empty(),"old attempt archived")
		if not archives.is_empty():
			var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://"+str(archives.back())))
			check(old.p5_preparation.mode=="manual" and int(old.seed)==seed_value and old.role==["MT","ST","H1","H2","D1","D2","D3","D4"][human],"archive preserves original manual provenance")
		await process_frame
	for method in [1,2,3,5]:
		choose(app,0,method)
		check(not app.p5_marking_supported() and not app.state.has("p5_marking_mode") and app.state.sigma.cooperation.mode=="legacy_coaching","other method never inherits CN markers")
		app.show_target_markers();check(not app.omega_marking_box.visible,"unsupported method hides CN mode");app.marker_popup.hide()
	choose(app,0);app.demo=true;app.start_run(0,false)
	check(app.state.p5_marking_mode=="assist" and app.preparation_report().assisted and not app.preparation_report().manual_preparation_complete,"demo explicitly assisted")
	app.demo=false;app.start_run(3,false)
	check(app.checkpoint_assisted and app.state.p5_marking_mode=="assist" and int(app.state.human_actor)==0 and not app.preparation_report().manual_preparation_complete,"checkpoint assisted and physical human restored")
	app.queue_free();await process_frame
	print("SIGMA_MAIN_PREPARATION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Main input/modes/archive/retry/checkpoint; not rendered platform or manual full clear"}))
	quit(1 if failures else 0)
