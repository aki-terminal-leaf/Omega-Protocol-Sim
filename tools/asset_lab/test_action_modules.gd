extends SceneTree
const Module = preload("res://scripts/action_module.gd")
const Timeline = preload("res://scripts/action_timeline.gd")
const Preview = preload("res://scripts/action_preview.gd")
const Unit = preload("res://scripts/asset_lab_unit.gd")
var failures: Array = []
var cases: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func poses(node: Node) -> Array:
	var result: Array = []
	if node is Node3D: result.append(str(node.transform))
	if node is Skeleton3D:
		for i in node.get_bone_count(): result.append(str(node.get_bone_global_pose(i)))
	for child in node.get_children(): result.append_array(poses(child))
	return result
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var config := {"backend":"clip", "manifest":input.manifest}
	var a = Module.new()
	root.add_child(a)
	var timeline = Timeline.new()
	root.add_child(timeline)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input.manifest))
	for pair in manifest.pairs:
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input.manifest.get_base_dir().path_join(pair.integration_samples)))
		for clip in raw.clips:
			var id := "clip:%d:%d" % [pair.model,clip.index]
			check(a.configure(config).ok and a.select(id).ok,id+" select")
			check(not a.backend.is_processing() and not a.is_processing(),id+" clock")
			check(timeline.add_instance("b",config,id,1.0).ok,id+" external create")
			var b = timeline.instances.b.module
			var samples: Array = []
			for index in [1, int(clip.times.size()/2), clip.times.size()-2]:
				var t: float = clip.times[index]
				a.reset(); a.play(); a.advance(t)
				timeline.seek(t+1)
				var pa := poses(a.backend.model)
				var pb := poses(b.backend.model)
				check(pa == pb and pa.size()>10,id+" pose parity")
				samples.append({"time":t,"standalone":a.report(),"external":b.report(),"pose":pa,"external_pose":pb})
				b.seek(0)
				check(poses(a.backend.model)==pa,id+" isolation")
			a.pause(); var held: float = a.seconds
			a.advance(.1); check(a.seconds==held,id+" pause")
			for bad in [-1.0,INF,NAN]:
				check(not a.advance(bad).ok and a.seconds==held,id+" invalid advance")
				check(not a.seek(bad).ok and a.seconds==held,id+" invalid seek")
			a.play(); a.advance(a.duration+1)
			check(a.seconds==a.duration and not a.playing and a.identity==id,id+" end")
			a.play(); check(a.seconds==0 and a.playing,id+" restart")
			a.reset(); check(a.seconds==0 and not a.playing,id+" reset")
			timeline.seek(100); timeline.seek(.5)
			check(not b.visible and b.seconds==0 and not b.playing,id+" before start")
			timeline.seek(1.1); check(b.visible and not b.playing and abs(b.seconds-.1)<.00001,id+" rewind")
			cases.append({"identity":id,"duration":a.duration,"samples":samples,"end_reset":a.report()})
			timeline.dispose()
	# A source failure cannot leave stale content playing or be cleared by Play.
	a.reset(); a.play(); a.backend.release()
	var rejected_sample: Dictionary = a.seek(0.1)
	check(not rejected_sample.ok and not a.playing and not a.visible and not a.selected,"failed source closed")
	var rejected_play: Dictionary = a.play()
	check(not rejected_play.ok and not a.playing,"failed source cannot replay")
	var source_failure := {"seek":rejected_sample,"play":rejected_play,"visible":a.visible}
	check(a.select("clip:%d:%d" % [manifest.pairs[0].model,manifest.pairs[0].clips[0].index]).ok,"recover by reselect")
	a.seek(a.duration); a.backend.release()
	check(not a.play().ok and not a.playing and not a.visible,"restart seek failure")
	# Distinct simultaneous selections: changes to the second must not touch the first.
	var first: Dictionary = manifest.pairs[0]
	var second: Dictionary = manifest.pairs[1]
	var first_id := "clip:%d:%d" % [first.model,first.clips[0].index]
	var second_id := "clip:%d:%d" % [second.model,second.clips[0].index]
	timeline.add_instance("first",config,first_id,0.0)
	timeline.add_instance("second",config,second_id,0.2,Transform3D(Basis.IDENTITY,Vector3(3,0,0)))
	timeline.seek(.5)
	var first_module = timeline.instances.first.module
	var second_module = timeline.instances.second.module
	var held_pose := poses(first_module.backend.model)
	var simultaneous := {"first":first_module.report(),"second":second_module.report(),"first_pose":held_pose,"second_pose":poses(second_module.backend.model)}
	second_module.seek(.9)
	check(poses(first_module.backend.model)==held_pose and first_module.seconds==.5,"distinct isolation")
	check(first_module.identity!=second_module.identity and second_module.position==Vector3(3,0,0),"distinct identity placement")
	timeline.dispose()
	check(not a.select("clip:999999:0").ok and not a.visible,"missing clip")
	a.dispose(); check(a.get_child_count()==0,"dispose")
	var camera := Camera3D.new()
	root.add_child(camera)
	var unit_config := {"backend":"unit","source_root":input.source_root,"camera":camera}
	var direct = Unit.new()
	root.add_child(direct)
	var unit_samples: Array = []
	check(a.configure(unit_config).ok,"unit configure")
	check(direct.configure(input.source_root,camera,"res://data/asset_lab/performances.json")==OK,"direct configure")
	check(a.select("unit:P1-01").ok and direct.select("P1-01")==OK,"unit selection")
	for t in [.1,1.0]:
		a.seek(t); direct.seek(t)
		check(a.report().source==direct.report(),"unit diagnostic parity")
		check(poses(a.backend)==poses(direct),"unit pose parity")
		unit_samples.append({"time":t,"facade":a.report(),"direct":direct.report(),"pose":poses(direct)})
	check(not a.select("unit:MISSING").ok and not a.visible,"missing unit")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_lab/catalog.json"))
	var selections: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_lab/performances.json"))
	var units: Array = []
	for unit in catalog.units: units.append({"identity":"unit:"+unit.id,"selection":selections.units[unit.id]})
	var ui = Preview.new()
	root.add_child(ui)
	ui.set_process(false)
	ui.setup(config)
	var ui_cases: Array = []
	for i in ui.identities.size():
		ui.selector.select(i); ui.selector.item_selected.emit(i)
		check(ui.module.seconds==0 and not ui.module.playing,"UI selection")
		ui.play_button.pressed.emit(); ui.module.advance(.1)
		ui.pause_button.pressed.emit()
		check(not ui.module.playing and ui.module.seconds>0,"UI pause")
		ui.play_button.pressed.emit(); ui.module.advance(100)
		check(not ui.module.playing and ui.module.seconds==ui.module.duration,"UI end")
		ui_cases.append(ui.module.report())
	var output := {"failures":failures,"clips":cases,"units":units,"unit_samples":unit_samples,"ui":ui_cases,"simultaneous":simultaneous,"source_failure":source_failure}
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify(output)); file.close()
	ui.module.dispose(); ui.free(); a.dispose(); a.free(); direct.dispose(); direct.free(); timeline.dispose(); timeline.free(); camera.free()
	quit(0 if failures.is_empty() else 1)
