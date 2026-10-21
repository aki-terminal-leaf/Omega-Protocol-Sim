# SPDX-License-Identifier: MIT
extends SceneTree
var failures: Array = []
var passed := 0
var meshes := 0
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected extracted AVFX directory argument (meteor/comet/fist_b6)")
		quit(1)
		return
	var folder := args[0]
	for form in ["meteor", "comet", "fist_b6"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(form).path_join("graph.json")))
		for model in doc.models:
			if not model.has("glb"): continue
			var state := GLTFState.new()
			var loader := GLTFDocument.new()
			var error := loader.append_from_file(folder.path_join(form).path_join(model.glb), state, GLTFDocument.IMPORT_FLAG_FORCE_DISABLE_MESH_COMPRESSION)
			if error != OK:
				failures.append("Import failed: " + form + "/" + model.glb)
				continue
			var root := loader.generate_scene(state)
			var nodes := root.find_children("*", "MeshInstance3D", true, false)
			if nodes.size() != 1:
				failures.append("Mesh node count wrong: " + form + "/" + model.glb)
				root.free()
				continue
			var surface: Array = nodes[0].mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = surface[Mesh.ARRAY_INDEX]
			meshes += 1
			if vertices.size() != model.vertices.size() or indices.size() != model.triangles.size() * 3:
				failures.append("Buffer counts changed: " + form + "/" + model.glb)
			else:
				passed += 2
				for i in vertices.size():
					var p: Array = model.vertices[i].position
					if vertices[i].distance_to(Vector3(p[0], p[1], p[2])) > 0.000001:
						failures.append("Position changed: " + form + "/" + model.glb)
						break
					passed += 1
			root.free()
	var out := {"engine": Engine.get_version_info().string, "meshes": meshes, "passed": passed, "failures": failures, "scope": "Actual glTF import and vertex/triangle preservation, not material/particle playback"}
	print(JSON.stringify(out))
	quit(0 if failures.is_empty() and meshes == 13 else 1)
