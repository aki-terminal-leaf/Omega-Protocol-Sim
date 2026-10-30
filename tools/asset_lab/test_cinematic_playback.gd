extends SceneTree
const Player = preload("res://scripts/cinematic_player.gd")
const Source = preload("res://scripts/source_animation.gd")
var report := {"status":"BLOCKED", "case_ids":[], "seeks":[], "resident":[], "lifecycle":[]}
var destination := ""
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): check(false, "internal test deadline"))
	call_deferred("run")
func check(ok: bool, message: String) -> bool:
	if not ok:
		report["blocker"] = message
		finish(false)
	return ok
func finish(ok: bool) -> void:
	report.status = "PASS" if ok else "BLOCKED"
	FileAccess.open(destination, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	quit(0 if ok else 1)
func trs(row: Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(row[8],row[9],row[10],row[11]).normalized()) * Basis.from_scale(Vector3(row[4],row[5],row[6])),Vector3(row[0],row[1],row[2]))
func matrix_error(a: Transform3D,b: Transform3D) -> float:
	var error := 0.0
	for v in [a.origin-b.origin,a.basis.x-b.basis.x,a.basis.y-b.basis.y,a.basis.z-b.basis.z]:
		error=maxf(error,maxf(absf(v.x),maxf(absf(v.y),absf(v.z))))
	return error
func skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := skeleton(child)
		if found != null: return found
	return null
func snap(p: AnimationPlayer, s: Skeleton3D) -> Dictionary:
	return {"active":p.active,"playing":p.is_playing(),"clip":str(p.current_animation),"position":p.current_animation_position if p.current_animation != "" else 0.0,"speed":p.get_playing_speed(),"scale":p.speed_scale,"pose":s.get_bone_pose_position(0).x}
func resident(c: Node3D, sk: Skeleton3D, model_id: int) -> bool:
	var ap := AnimationPlayer.new()
	ap.name = "EngineControlFixture"
	c.model.add_child(ap)
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 2.0
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath(str(c.model.get_path_to(sk))+":"+sk.get_bone_name(0)))
	animation.position_track_insert_key(track,0.0,Vector3(0,0,0))
	animation.position_track_insert_key(track,2.0,Vector3(2,0,0))
	library.add_animation("control",animation)
	library.add_animation("newer",animation)
	ap.add_animation_library("",library)
	for mode in ["playing","paused","stopped","disabled","reverse","zero_scale","newer"]:
		c.release()
		ap.active = true
		ap.speed_scale = 1.5
		ap.play("control",-1,-0.5 if mode == "reverse" else 0.75, mode == "reverse")
		ap.seek(1.0,true)
		ap.advance(0.1)
		if mode == "paused": ap.pause()
		if mode == "stopped": ap.stop()
		if mode == "disabled": ap.active = false
		if mode == "zero_scale": ap.speed_scale = 0.0
		var before := snap(ap,sk)
		if not check(c.select_clip(int(c.raw.clips[0].index)),"fixture bind"): return false
		var owned := snap(ap,sk)
		if not check(not ap.active,"resident disabled while source owns"): return false
		var stale: Dictionary = c.binding
		if mode == "newer":
			# Explicit handoff: release BEFORE issuing any newer request, including same clip.
			c.release()
			ap.active = true
			ap.play("control",-1,0.4)
			ap.seek(0.3,true)
		c.release()
		Source.clear(stale)
		sk.force_update_all_bone_transforms()
		var global_restored_error := matrix_error(sk.get_bone_global_pose(0),sk.get_bone_global_pose_no_override(0))
		if not check(global_restored_error < 0.0002,"resident global override release"): return false
		var after := snap(ap,sk)
		ap.advance(0.1)
		var advanced := snap(ap,sk)
		var rec := {"model":model_id,"mode":mode,"fixture":"engine control on actual original rig, not original resident animation","global_restored_error":global_restored_error,"before":before,"owned":owned,"after":after,"advanced":advanced}
		report.resident.append(rec)
		if mode != "newer":
			if not check(before.active == after.active and before.playing == after.playing and before.clip == after.clip and absf(before.position-after.position)<0.0001 and absf(before.speed-after.speed)<0.0001 and absf(before.pose-after.pose)<0.0001,"resident restoration: "+mode): return false
			if before.playing and before.active:
				if not check(absf(advanced.position-(before.position+0.1*before.speed))<0.0001 and absf(advanced.pose-advanced.position)<0.0001,"resident frame advance: "+mode): return false
		else:
			if not check(absf(after.position-0.3)<0.0001 and absf(advanced.position-0.36)<0.0001,"explicit newer same-clip handoff"): return false
	ap.free()
	return true
func ui_controls(node: Node, buttons: Array, forbidden: Array) -> void:
	if node is BaseButton and not node is OptionButton: buttons.append(node)
	if node is Slider or node is CheckButton or node is CheckBox: forbidden.append(node)
	for child in node.get_children(): ui_controls(child, buttons, forbidden)
func ui_state(ui: Node) -> Dictionary:
	return {"model":ui.models.get_selected_id(), "clip":ui.player.clip_index, "selected_clip":ui.clips.get_selected_id(), "model_instance":ui.player.model.get_instance_id(), "time":ui.player.time, "duration":ui.player.duration, "playing":ui.player.playing, "speed":ui.player.speed, "looping":ui.player.looping}
func ui_checks(ui: Node) -> bool:
	ui.set_process(false)
	ui.player.set_process(false)
	var buttons: Array = []
	var forbidden: Array = []
	ui_controls(ui, buttons, forbidden)
	var names: Array = []
	for button in buttons: names.append(str(button.text))
	if not check(names == ["Play", "Pause"] and forbidden.is_empty(), "only Play/Pause; no loop/slider"): return false
	var evidence := {"buttons":names, "forbidden_controls":forbidden.size(), "initial":ui_state(ui), "selected_case_ids":[], "cases":[]}
	report["ui_controls"] = evidence
	if not check(not ui.player.playing and ui.player.time == 0.0 and ui.player.speed == 1.0 and not ui.player.looping, "initial paused defaults"): return false
	for mi in ui.models.item_count:
		for ci in ui.player.manifest.pairs[mi].clips.size():
			var rec := {"case_id":"%d:%d" % [ui.models.get_item_id(mi), int(ui.player.manifest.pairs[mi].clips[ci].index)], "states":{}}
			evidence.cases.append(rec)
			var states: Dictionary = rec.states
			buttons[0].pressed.emit()
			ui.player.advance(0.01)
			states.model_before = ui_state(ui)
			ui.models.select(mi); ui.models.item_selected.emit(mi)
			states.model_selected = ui_state(ui)
			if not check(not ui.player.playing and ui.player.time == 0.0, "model signal pauses/resets"): return false
			buttons[0].pressed.emit()
			ui.player.advance(0.01)
			states.clip_before = ui_state(ui)
			ui.clips.select(ci); ui.clips.item_selected.emit(ci)
			states.selected = ui_state(ui)
			if not check(not ui.player.playing and ui.player.time == 0.0 and ui.player.clip_index == ui.clips.get_item_id(ci), "clip signal pauses/resets exact ID"): return false
			ui.player.advance(0.1)
			states.selection_idle = ui_state(ui)
			buttons[0].pressed.emit()
			ui.player.advance(0.1)
			states.progress = ui_state(ui)
			buttons[1].pressed.emit()
			ui.player.advance(0.2)
			states.paused = ui_state(ui)
			buttons[0].pressed.emit()
			states.resumed = ui_state(ui)
			ui.player.advance(0.1)
			states.resumed_progress = ui_state(ui)
			ui.player.advance(ui.player.duration + 1.0)
			states.endpoint = ui_state(ui)
			ui.player.advance(ui.player.duration + 1.0)
			states.after_end = ui_state(ui)
			buttons[0].pressed.emit()
			states.restart = ui_state(ui)
			ui.player.advance(0.1)
			states.restart_progress = ui_state(ui)
			for key in ["selected", "selection_idle", "progress", "paused", "resumed", "resumed_progress", "endpoint", "after_end", "restart", "restart_progress"]:
				var st: Dictionary = states[key]
				if not check(st.model == states.selected.model and st.clip == states.selected.clip and st.selected_clip == st.clip and st.model_instance == states.selected.model_instance and st.speed == 1.0 and not st.looping, "identity/defaults: " + key): return false
			if not check(states.selection_idle.time == 0.0 and not states.selection_idle.playing and absf(states.progress.time-0.1)<0.00001 and states.progress.playing and states.paused.time == states.progress.time and not states.paused.playing and states.resumed.time == states.paused.time and states.resumed.playing and absf(states.resumed_progress.time-0.2)<0.00001, "1x pause/resume"): return false
			if not check(states.endpoint.time == ui.player.duration and not states.endpoint.playing and states.after_end == states.endpoint and states.restart.time == 0.0 and states.restart.playing and absf(states.restart_progress.time-0.1)<0.00001, "clamped endpoint and same clip restart"): return false
			evidence.selected_case_ids.append(rec.case_id)
	return true
func run() -> void:
	var args := OS.get_cmdline_user_args()
	destination = args[1]
	if args[2] == "ui":
		var packed = load("res://scenes/cinematic_inspector.tscn")
		if not check(packed != null,"scene load"): return
		var ui = packed.instantiate()
		root.add_child(ui)
		if not check(ui.player.model != null and ui.models.item_count == 4 and ui.clips.item_count > 0,"UI construct actual model/selectors"): return
		report["constructed"] = true
		if not ui_checks(ui): return
		ui.free()
		finish(true)
		return
	var baseline_nodes := get_node_count()
	var c = Player.new()
	root.add_child(c)
	c.set_process(false)
	if not check(c.configure(args[0]),"configure"): return
	c.transform = Transform3D(Basis.from_euler(Vector3(.2,.4,.1))*Basis.from_scale(Vector3(1.2,.8,1.4)),Vector3(8,3,-4))
	var prior_id := 0
	for pair in c.manifest.pairs:
		if not check(c.load_model(int(pair.model)),"load actual original"): return
		if prior_id != 0 and not check(not is_instance_id_valid(prior_id),"old model destroyed"): return
		prior_id = c.model.get_instance_id()
		c.model.transform = Transform3D(Basis.from_euler(Vector3(0,.7,0))*Basis.from_scale(Vector3(.7,1.3,1.1)),Vector3(2,1,3))
		var sk := skeleton(c.model)
		var relative := Transform3D.IDENTITY
		var cursor: Node3D = sk
		while cursor != c.model:
			relative = cursor.transform * relative
			cursor = cursor.get_parent()
		for clip in c.raw.clips:
			var old: Dictionary = c.binding
			if not check(c.select_clip(int(clip.index)),"select exact index"): return
			Source.clear(old)
			if not check(sk.get_meta(Source.OWNER_META) == c.binding.id,"stale clear preserves replacement"): return
			var rec := {"model":pair.model,"clip":clip.index,"records":[],"max_error":0.0}
			report.case_ids.append("%d:%d" % [pair.model,clip.index])
			report.seeks.append(rec)
			for fi in [0,int(clip.times.size()/2),clip.times.size()-1,int(clip.times.size()/2),0]:
				if not check(c.seek(clip.times[fi]),"seek"): return
				for bi in c.raw.names.size():
					var actual := sk.get_bone_global_pose(sk.find_bone(c.raw.names[bi]))
					var expected := relative.affine_inverse()*trs(clip.frames[fi][bi])
					rec.max_error = maxf(rec.max_error,matrix_error(actual,expected))
				rec.records.append({"frame":fi,"time":clip.times[fi],"error":rec.max_error})
			if not check(rec.max_error<0.0002,"independent raw pose matrices"): return
			c.set_speed(1); c.seek(0); c.play(); c.advance(0.1)
			if not check(absf(c.time-0.1)<0.00001,"forward"): return
			c.pause(); c.advance(0.1)
			if not check(absf(c.time-0.1)<0.00001,"pause"): return
			c.set_speed(-1); c.play(); c.advance(0.05)
			if not check(absf(c.time-0.05)<0.00001,"reverse"): return
			c.set_speed(0); c.advance(1)
			if not check(absf(c.time-0.05)<0.00001,"zero speed"): return
			c.set_speed(-1); c.set_loop(true); c.seek(0); c.advance(0.1)
			if not check(absf(c.time-(c.duration-0.1))<0.00001,"reverse loop"): return
			c.set_loop(false); c.replay()
			if not check(c.time==c.duration,"reverse replay"): return
			c.advance(c.duration+1)
			if not check(c.time==0 and not c.playing,"endpoint"): return
		c.release()
		if not check(not sk.has_meta(Source.OWNER_META),"released ownership"): return
		if not resident(c,sk,int(pair.model)): return
		c.select_clip(int(c.raw.clips[0].index))
		if not check(not c.select_clip(-999) and not sk.has_meta(Source.OWNER_META) and is_instance_valid(c.model),"failed selection releases, preserves scene"): return
		c.select_clip(int(c.raw.clips[0].index))
		if not check(not c.load_model(-999) and not sk.has_meta(Source.OWNER_META) and is_instance_valid(c.model),"failed load releases, preserves scene"): return
		report.lifecycle.append({"model":pair.model,"failed_operations_release":true,"replacement_frees_previous":true})
	c.free()
	if not check(not is_instance_id_valid(prior_id),"final model freed"): return
	report["node_counts"] = {"before":baseline_nodes,"after":get_node_count()}
	if not check(baseline_nodes == get_node_count(),"node lifecycle count"): return
	finish(true)
