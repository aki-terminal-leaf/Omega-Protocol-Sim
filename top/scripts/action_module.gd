extends Node3D
## Caller owns the only clock. Placement transforms local/record space as a whole.
const Unit = preload("res://scripts/asset_lab_unit.gd")
const Cinematic = preload("res://scripts/cinematic_player.gd")
var backend: Node3D
var kind := ""
var identity := ""
var seconds := 0.0
var duration := 0.0
var playing := false
var configured := false
var selected := false
var supported := false
var error := ""
var last_ok := false

func dispose() -> void:
	if is_instance_valid(backend):
		if kind == "unit": backend.dispose()
		else: backend.release()
		backend.free()
	backend = null
	configured = false
	selected = false
	playing = false
	supported = false
	identity = ""
	seconds = 0.0
	duration = 0.0
	visible = false
	last_ok = false

func _result(ok: bool, reason := "") -> Dictionary:
	last_ok = ok
	error = reason
	return report()

func configure(options: Dictionary) -> Dictionary:
	dispose()
	kind = str(options.get("backend", ""))
	if kind not in ["unit", "clip"]: return _result(false, "Unknown backend")
	backend = Unit.new() if kind == "unit" else Cinematic.new()
	add_child(backend)
	backend.set_process(false)
	var ok: bool
	if kind == "unit":
		ok = backend.configure(str(options.get("source_root", "")), options.get("camera"), str(options.get("selections", "res://data/asset_lab/performances.json")), str(options.get("attachments", ""))) == OK
	else:
		ok = backend.configure(str(options.get("manifest", "")))
	if not ok:
		var reason: String = backend.error
		dispose()
		return _result(false, reason)
	configured = true
	return _result(true)

func select(id: String) -> Dictionary:
	selected = false
	playing = false
	supported = false
	visible = false
	seconds = 0.0
	duration = 0.0
	identity = ""
	if not configured: return _result(false, "Not configured")
	var ok := false
	if kind == "unit" and id.begins_with("unit:"):
		ok = backend.select(id.trim_prefix("unit:")) == OK
	elif kind == "clip":
		backend.release()
		var parts := id.split(":")
		if parts.size() == 3 and parts[0] == "clip" and parts[1].is_valid_int() and parts[2].is_valid_int():
			ok = backend.load_model(int(parts[1])) and backend.select_clip(int(parts[2]))
	if not ok: return _result(false, "Selection unavailable: " + id + " " + str(backend.error))
	identity = id
	duration = backend.duration
	selected = true
	visible = true
	return seek(0.0)

func seek(value: float) -> Dictionary:
	if not is_finite(value) or value < 0: return _result(false, "Time must be finite and nonnegative")
	if not selected: return _result(false, "No selection")
	seconds = minf(value, duration)
	supported = backend.seek(seconds)
	if kind == "clip" and not supported:
		playing = false
		selected = false
		visible = false
		backend.release()
		return _result(false, "Source sample failed; select again")
	if seconds >= duration: playing = false
	return _result(true if kind == "unit" else supported, "" if supported or kind == "unit" else "Source sample failed")

func play() -> Dictionary:
	if not selected: return _result(false, "No selection")
	if seconds >= duration:
		var result := seek(0.0)
		if not result.ok: return result
	playing = true
	return _result(true)

func pause() -> Dictionary:
	playing = false
	return _result(selected, "" if selected else "No selection")

func advance(delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0: return _result(false, "Delta must be finite and nonnegative")
	if not selected: return _result(false, "No selection")
	if playing: return seek(minf(seconds + delta, duration))
	return _result(true)

func reset() -> Dictionary:
	playing = false
	return seek(0.0)

func set_target_context(_context: Dictionary) -> Dictionary:
	return _result(false, "NOT_IMPLEMENTED: target context")

func report() -> Dictionary:
	var source: Dictionary = {}
	if is_instance_valid(backend):
		if kind == "unit": source = backend.report()
		else: source = {"clip": backend.clip_index, "time": backend.time, "duration": backend.duration, "error": backend.error, "diagnostics": backend.binding.get("diagnostics", {})}
	return {"ok": last_ok, "error": error, "configured": configured, "selected": selected, "identity": identity, "seconds": seconds, "duration": duration, "playing": playing, "source_sampling_supported": supported, "source": source, "accepted": false}
