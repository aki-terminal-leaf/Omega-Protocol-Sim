# SPDX-License-Identifier: MIT
extends SceneTree
const Official = preload("res://scripts/official_arena.gd")
var checks := 0
var failures := 0
func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok: failures += 1; print("ORIGINAL_ARENA FAIL: ",what)
func inspect(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance3D:
		counts.meshes += 1
		check(node.mesh != null and node.mesh.get_aabb().size.length() > 0,"nonempty source geometry")
	if node is CollisionObject3D: counts.colliders += 1
	for child in node.get_children(): inspect(child,counts)
func _initialize() -> void:
	if not FileAccess.file_exists(Official.PACK + "manifest.json"):
		print("ORIGINAL_ARENA SKIP: optional local game pack absent"); quit(0); return
	for phase in range(1,7):
		var scene := Official.instantiate(phase)
		check(scene != null,"phase has a complete local original scene")
		if scene == null: continue
		root.add_child(scene)
		var counts := {"meshes":0,"colliders":0}
		inspect(scene,counts)
		check(counts.meshes>0 and counts.colliders==0,"visual scene cannot change collision judgments")
		for anchor in scene.get_children():
			var path: String = anchor.get_meta("source_path", "")
			var placements: Array = Official.manifest.placements.filter(func(p):return p.path==path and p.layer==anchor.get_meta("source_layer"))
			check(not placements.is_empty(),"rendered asset has source placement provenance")
			if anchor.get_meta("source_layer").ends_with("boss"):
				check(anchor.position.length()<1.0,"original floor origin recentered without rescaling")
		check(not scene.get_children().any(func(n):return str(n.get_meta("source_layer")).begins_with("cut_")),"cutscene-only geometry excluded")
		if phase == 6: check(scene.get_children().any(func(n):return n.get_meta("source_layer")=="p7_boss"),"final TOP phase uses source final arena")
		scene.free()
	print("ORIGINAL_ARENA checks=",checks," failures=",failures);quit(1 if failures else 0)
