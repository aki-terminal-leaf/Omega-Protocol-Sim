extends Node3D
const Module = preload("res://scripts/action_module.gd")
var module = Module.new()
var selector := OptionButton.new()
var play_button := Button.new()
var pause_button := Button.new()
var status := Label.new()
var camera := Camera3D.new()
var identities: Array[String] = []
func _ready() -> void:
	add_child(module)
	add_child(camera)
	camera.current = true
	camera.fov = 45
	camera.near = 0.01
	camera.far = 2000
	camera.position = Vector3(sin(.65)*cos(.45), sin(.45), cos(.65)*cos(.45))*24
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var box := VBoxContainer.new()
	box.position = Vector2(16,16)
	canvas.add_child(box)
	box.add_child(selector)
	play_button.text = "Play"
	pause_button.text = "Pause"
	box.add_child(play_button)
	box.add_child(pause_button)
	box.add_child(status)
	play_button.pressed.connect(func(): module.play(); refresh())
	pause_button.pressed.connect(func(): module.pause(); refresh())
	selector.item_selected.connect(_select)
	var config := {"backend": "clip", "camera": camera}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--backend="): config.backend = arg.trim_prefix("--backend=")
		if arg.begins_with("--manifest="): config.manifest = arg.trim_prefix("--manifest=")
		if arg.begins_with("--source-root="): config.source_root = arg.trim_prefix("--source-root=")
	if config.has("manifest") or config.has("source_root"):
		setup(config)
	else:
		status.text = "Provide a source manifest or unit source root."
		play_button.disabled = true
func setup(config: Dictionary) -> void:
	identities.clear()
	selector.clear()
	if not module.configure(config).ok:
		refresh()
		return
	if module.kind == "clip":
		for pair in module.backend.manifest.pairs:
			for clip in pair.clips: identities.append("clip:%d:%d" % [pair.model, clip.index])
	else:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_lab/catalog.json"))
		for unit in catalog.units: identities.append("unit:" + unit.id)
	for id in identities: selector.add_item(id)
	if not identities.is_empty(): _select(0)
func _select(index: int) -> void:
	if index < 0 or index >= identities.size(): return
	module.select(identities[index])
	if module.selected and module.kind == "clip":
		var boxes: Array = []
		_bounds(module.backend.model, boxes)
		if not boxes.is_empty():
			var box: AABB = boxes[0]
			for b in boxes: box = box.merge(b)
			var radius := maxf(box.size.length()*.5,.01)
			camera.near = maxf(radius/1000,.001)
			camera.far = radius*20
			camera.position = box.get_center()+Vector3(0,radius*.3,radius/sin(deg_to_rad(camera.fov*.5))*1.3)
			camera.look_at(box.get_center())
	refresh()
func _bounds(node: Node, boxes: Array) -> void:
	if node is MeshInstance3D: boxes.append(node.global_transform*node.get_aabb())
	for child in node.get_children(): _bounds(child,boxes)
func refresh() -> void:
	var r: Dictionary = module.report()
	status.text = "%s  %.3f / %.3f s  %s" % [r.identity,r.seconds,r.duration,"Playing" if r.playing else "Paused"]
	if not r.error.is_empty(): status.text += "\n" + r.error
	elif r.selected and not r.source_sampling_supported: status.text += "\nSource sampling unsupported; performance incomplete."
	play_button.disabled = not r.selected
func _process(delta: float) -> void:
	if module.playing: module.advance(delta)
	refresh()
