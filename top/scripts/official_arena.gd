# SPDX-License-Identifier: MIT
extends RefCounted
## Static local-game BG geometry and source placements; no collision/gameplay changes.
const PACK := "res://assets/official/arena/"
# The original scene's p7 is TOP's final (P6) arena; p6 is a P5 transition layer.
const LAYERS := {
	1: ["p1_boss", "p1_enkei"],
	2: ["p1_boss", "p2_boss", "p1_enkei"],
	3: ["p3_boss", "p3_enkei"],
	4: ["p4_boss", "p3_enkei"],
	5: ["p5_boss", "p3_enkei"],
	6: ["p7_boss", "p7_enkei"],
}
# These meshes require the original vertical-fog shader; opaque PBR is not a valid substitute.
const DEFERRED_FOG := ["z3oe_a1_vfg01", "z3of_a4_vfog1", "z3of_a4_vfog2"]
static var manifest: Dictionary = {}
static var scenes: Dictionary = {}

static func instantiate(phase: int) -> Node3D:
	if not FileAccess.file_exists(PACK + "manifest.json"): return null
	if manifest.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(PACK + "manifest.json"))
		if not data is Dictionary: return null
		manifest = data
	var selected: Array = []
	for placement in manifest.get("placements", []):
		if placement.layer in LAYERS.get(phase, LAYERS[1]) and not str(placement.path).get_file().get_basename() in DEFERRED_FOG: selected.append(placement)
	if selected.is_empty(): return null
	# Fail the entire optional scene pack back to the known original fallback,
	# never render a silently incomplete floor with missing meshes.
	for placement in selected:
		var name: String = str(placement.path).get_file().get_basename()
		var path: String = PACK + name + ".glb"
		if not ResourceLoader.exists(path): return null
		if not scenes.has(name): scenes[name] = load(path)
		if not scenes[name] is PackedScene: return null
	var root := Node3D.new(); root.name = "OriginalArena"
	root.set_meta("original_arena",true); root.set_meta("phase",phase)
	for placement in selected:
		var name: String = str(placement.path).get_file().get_basename()
		var anchor := Node3D.new(); anchor.name = name
		root.add_child(anchor)
		# Preserve source units/geometry; only move arena origin (100,0,100) to zero.
		anchor.position = Vector3(float(placement.translation[0])-100.0,float(placement.translation[1]),float(placement.translation[2])-100.0)
		anchor.rotation_order = EULER_ORDER_ZYX
		anchor.rotation = Vector3(float(placement.rotation[0]),float(placement.rotation[1]),float(placement.rotation[2]))
		anchor.scale = Vector3(float(placement.scale[0]),float(placement.scale[1]),float(placement.scale[2]))
		anchor.set_meta("source_layer",str(placement.layer)); anchor.set_meta("source_path",str(placement.path))
		var mesh: Node3D = scenes[name].instantiate(); anchor.add_child(mesh)
	return root
