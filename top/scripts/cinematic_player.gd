extends Node3D
const Source = preload("res://scripts/source_animation.gd")
const Adapter = preload("res://scripts/cinematic_sample_adapter.gd")
var manifest: Dictionary = {}
var base_dir := ""
var model: Node3D
var raw: Dictionary = {}
var binding: Dictionary = {}
var clip_index := -1
var time := 0.0
var duration := 0.0
var speed := 1.0
var looping := false
var playing := false
var error := ""

func configure(path: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("pairs") is Array:
		error = "Provide --manifest=PATH to the staged source manifest."
		return false
	manifest = data
	base_dir = path.get_base_dir()
	return true

# Failed loads/selections preserve the valid scene; selection failure pauses/releases it.
func load_model(id: int) -> bool:
	var pair: Dictionary = {}
	for entry in manifest.get("pairs", []):
		if int(entry.model) == id: pair = entry
	if pair.is_empty():
		release()
		error = "Unknown source model"
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(base_dir.path_join(pair.integration_samples)))
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	if not data is Dictionary or document.append_from_file(base_dir.path_join(pair.glb), state) != OK:
		release()
		error = "Source model or sample could not load"
		return false
	var candidate = document.generate_scene(state)
	if candidate == null:
		release()
		return false
	release()
	if is_instance_valid(model): model.free()
	model = candidate
	add_child(model)
	raw = data
	return true

func select_clip(id: int) -> bool:
	release()
	if not is_instance_valid(model): return false
	var sample := Adapter.convert(raw, id)
	if sample.has("error"):
		error = str(sample.error)
		return false
	binding = Source.configure(self, sample)
	if not binding.get("ok", false):
		error = str(binding.get("error"))
		return false
	clip_index = id
	duration = float(binding.source.duration)
	return seek(0.0)

func seek(seconds: float) -> bool:
	if not is_finite(seconds) or not binding.get("ok", false): return false
	time = clampf(seconds, 0.0, duration)
	return Source.seek(binding, time)
func play() -> void:
	playing = binding.get("ok", false)
func pause() -> void:
	playing = false
func set_speed(value: float) -> void:
	if is_finite(value): speed = value
func set_loop(value: bool) -> void:
	looping = value
func replay() -> void:
	if seek(duration if speed < 0 else 0.0): play()
func advance(delta: float) -> void:
	if not playing or speed == 0 or not is_finite(delta) or delta < 0: return
	var next := time + delta * speed
	if looping and duration > 0: next = fposmod(next, duration)
	elif next <= 0 or next >= duration: pause()
	seek(next)
func _process(delta: float) -> void:
	advance(delta)
func release() -> void:
	pause()
	Source.clear(binding)
	binding = {}
	clip_index = -1
func _exit_tree() -> void:
	release()
