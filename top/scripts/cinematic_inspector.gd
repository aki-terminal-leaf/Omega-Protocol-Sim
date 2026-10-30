extends Node3D
const Player = preload("res://scripts/cinematic_player.gd")
var player = Player.new()
var models := OptionButton.new()
var clips := OptionButton.new()
var label := Label.new()
var camera := Camera3D.new()
var elapsed_label := Label.new()

func _ready() -> void:
	add_child(player)
	add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size.x = 650
	canvas.add_child(panel)
	label.text = "Source clips are not final cinematic timing. Imported PBR is not the original shader."
	panel.add_child(label)
	panel.add_child(models)
	panel.add_child(clips)
	var row := HBoxContainer.new()
	panel.add_child(row)
	for title in ["Play", "Pause"]:
		var button := Button.new()
		button.text = title
		row.add_child(button)
		button.pressed.connect(_action.bind(title))
	row.add_child(elapsed_label)
	models.item_selected.connect(_model_selected)
	clips.item_selected.connect(_clip_selected)
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="): path = arg.trim_prefix("--manifest=")
	if path.is_empty() or not player.configure(path):
		label.text = "Launch with --manifest=PATH to the staged source manifest."
		return
	for pair in player.manifest.pairs: models.add_item("Source model %04d / body %04d" % [pair.model, pair.base], int(pair.model))
	_model_selected(0)

func _model_selected(index: int) -> void:
	if not player.load_model(models.get_item_id(index)):
		label.text = player.error
		return
	clips.clear()
	for clip in player.raw.clips: clips.add_item("Clip %d · %s" % [clip.index, clip.name], int(clip.index))
	_clip_selected(0)
	var bounds: Array = []
	_collect_bounds(player.model, bounds)
	if bounds.is_empty(): return
	var box: AABB = bounds[0]
	for b in bounds: box = box.merge(b)
	var center := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.01)
	camera.near = maxf(radius / 1000, 0.001)
	camera.far = radius * 20
	camera.position = center + Vector3(0, radius * 0.3, radius / sin(deg_to_rad(camera.fov * 0.5)) * 1.3)
	camera.look_at(center)
func _collect_bounds(node: Node, boxes: Array) -> void:
	if node is MeshInstance3D: boxes.append(node.global_transform * node.get_aabb())
	for child in node.get_children(): _collect_bounds(child, boxes)
func _clip_selected(index: int) -> void:
	if not player.select_clip(clips.get_item_id(index)):
		label.text = player.error
func _process(_delta: float) -> void:
	elapsed_label.text = "%.3f / %.3f s" % [player.time, player.duration]

func _action(title: String) -> void:
	match title:
		"Play":
			if player.time >= player.duration:
				player.seek(0.0)
			player.play()
		"Pause": player.pause()
