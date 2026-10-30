extends Node3D
## Small external-clock example; no encounter or target simulation.
const Module = preload("res://scripts/action_module.gd")
const MAX_INSTANCES := 8
var instances: Dictionary = {}
func add_instance(id: String, config: Dictionary, selection: String, start: float, placement := Transform3D.IDENTITY) -> Dictionary:
	if id.is_empty() or instances.has(id) or instances.size() >= MAX_INSTANCES or not is_finite(start) or start < 0:
		return {"ok": false, "error": "Invalid name/start or instance limit"}
	var module = Module.new()
	add_child(module)
	module.transform = placement
	var result: Dictionary = module.configure(config)
	if result.ok: result = module.select(selection)
	if not result.ok:
		module.dispose()
		module.free()
		return result
	instances[id] = {"module": module, "start": start, "active": false}
	module.visible = false
	return result
func seek(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0: return {"ok": false, "error": "Invalid external time"}
	var reports := {}
	var ok := true
	for id in instances:
		var row: Dictionary = instances[id]
		var module = row.module
		module.pause()
		row.active = seconds >= row.start
		var result: Dictionary = module.seek(maxf(0, seconds - row.start))
		module.visible = row.active and module.selected
		reports[id] = {"active": row.active, "report": result}
		ok = ok and result.ok
	return {"ok": ok, "instances": reports}
func reset() -> Dictionary:
	return seek(0.0)
func dispose() -> void:
	for row in instances.values():
		row.module.dispose()
		row.module.free()
	instances.clear()
