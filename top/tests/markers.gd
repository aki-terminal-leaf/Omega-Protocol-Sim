# SPDX-License-Identifier: MIT
extends SceneTree
const Markers=preload("res://scripts/markers.gd")
const Wall=preload("res://scripts/death_wall.gd")
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
func check(ok:bool,title:String)->void:
	checks+=1
	if not ok:failures+=1;print("MARKERS FAIL ",title)
func choose(app,id:String)->void:
	for i in app.filtered.size():
		if app.filtered[i].id==id:app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1);app.seed_edit.text="17391";return
func key(app,code:int,ctrl:=false)->void:
	var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=code;event.ctrl_pressed=ctrl;app._unhandled_key_input(event)
func _initialize()->void:call_deferred("run")
func run()->void:
	var state:Dictionary={"sim_time":5.0,"statuses":[{"red":{"expires":99}}]}
	for i in Markers.IDS.size():
		var name:String=Markers.IDS[i];check(Markers.assign(state,i%8,name,0).ok,"all17 markers supported "+name)
		check(Markers.icon_id(name)>0,"original UI mapping "+name)
	check(state.statuses[0].has("red"),"manual signs do not erase combat effects")
	Markers.assign(state,1,"attack1",0);Markers.assign(state,2,"attack1",0)
	check(Markers.marker_for(state,1)=="" and Markers.marker_for(state,2)=="attack1","same sign physically transfers to another target")
	var n:int=state.target_markers.sequence;Markers.assign(state,2,"attack1",0);check(int(state.target_markers.sequence)==n,"repeating same command is idempotent")
	check(not Markers.assign(state,8,"attack1",0).ok and not Markers.assign(state,0,"secret",0).ok,"invalid targets/signs rejected")
	for i in 8:Markers.assign(state,i,"attack%d"%(i+1),0)
	var before:=JSON.stringify(state);check(not Markers.next_attack(state,0).ok and before==JSON.stringify(state),"all eight numbers occupied does not steal or mutate")
	Markers.assign(state,7,"",0);check(Markers.next_attack(state,0).ok and Markers.marker_for(state,0)=="attack8","next uses real free set, not hidden answers")
	var restored:Dictionary=JSON.parse_string(JSON.stringify(state));check(Markers.marker_for(restored,0)=="attack8" and restored.target_markers.events.size()==state.target_markers.events.size(),"full event sequence and owner survive JSON")
	var layout:=Markers.default_layout();check(Markers.validate_layout(layout).ok,"generic layout valid")
	for invalid in [null,{"schema":2,"marks":[]},{"schema":1,"marks":[{"id":"A","pos":[20,0]}]},{"schema":1,"marks":[{"id":"A","pos":[INF,0]}]},{"schema":1,"marks":[{"id":"A","pos":[0,0]},{"id":"A","pos":[1,1]}]}]:
		check(not Markers.validate_layout(invalid).ok,"malformed/nonfinite/duplicate/outside layout rejected")
	for phase in 6:
		var wall:=Wall.create(phase+1);check(wall.get_meta("radius")==20.0,"visible wall matches lethal radius")
		check(wall.find_children("*","CollisionObject3D",true,false).is_empty(),"death wall is lethal boundary visual, not a solid barrier")
		wall.free()
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
	choose(app,"p1_loop");app.start_run();app.stop_failure.button_pressed=false
	var combat:=JSON.stringify(app.state.statuses);var lb_target:int=app.lb_target.selected;key(app,KEY_M)
	check(Markers.marker_for(app.state,app.player)=="attack1" and JSON.stringify(app.state.statuses)==combat,"actual M input self-marks without changing numbered debuffs")
	check(app.lb_target.selected==lb_target,"self-mark does not change Boss/LB selection")
	app.arena.update_state(app.actors,app.current,app.player,false,0,app.state);app.arena._process(0.01)
	check(app.arena.target_signs[app.player].visible and app.hud_party_rows[app.player].marker.visible,"actual party + independent overhead sign rendered")
	key(app,KEY_4,true);check(Markers.marker_for(app.state,app.player)=="attack4","Ctrl+4 does not activate ordinary action")
	key(app,KEY_BACKSPACE);check(Markers.marker_for(app.state,app.player)=="","actual clear hotkey")
	key(app,KEY_N);check(Markers.marker_for(app.state,app.player)=="attack1","actual next free hotkey")
	app.toggle_pause();key(app,KEY_BACKSPACE);check(Markers.marker_for(app.state,app.player)=="attack1","pause/review cannot rewrite mark history")
	app.toggle_pause();app.retry_beat();check(Markers.marker_for(app.state,app.player)=="","retry restores entry marker snapshot")
	key(app,KEY_M);app.start_run();check(Markers.marker_for(app.state,app.player)=="","same seed restart clears run-owned signs")
	var positions:=JSON.stringify(app.actors);var before_current:=JSON.stringify(app.current);app.arena.set_waymarks({"schema":1,"marks":[]})
	check(app.arena.waymarks.get_child_count()==0 and positions==JSON.stringify(app.actors) and before_current==JSON.stringify(app.current),"hiding waymarks does not alter battle geometry")
	app.arena.set_waymarks(layout);check(app.arena.waymarks.get_child_count()==8,"restore full original-colour eight-waymark rendering")
	var report:Dictionary=app.report();check(report.has("waymarks") and report.target_markers.mode=="manual","report records actual independent layout and manual mode")
	app.queue_free();await process_frame
	print("MARKERS checks=",checks," failures=",failures);quit(1 if failures else 0)
