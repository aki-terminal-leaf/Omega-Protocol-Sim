# SPDX-License-Identifier: MIT
extends SceneTree
## Convert only equipped model presets from an existing local DSR reference pack.
## Run with a matching Godot editor binary (reference 1.1.0 uses pack format 4).
const PRESETS: Array[String] = ["war_miq","whm_aur","sch_hyr","drg_miq","sam_miq","brd_vra","blm_miq"]
func _initialize() -> void: call_deferred("run")
func strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children(): strip_scripts(child)
func bind_skins(node: Node, skeleton: Skeleton3D = null) -> void:
	if node is Skeleton3D: skeleton = node
	if node is MeshInstance3D and node.skin != null and skeleton != null:
		# These model-only presets leave skeleton paths to their DSR controller.
		# Resolve the local rig without copying any controller code.
		if node.skeleton.is_empty() or node.get_node_or_null(node.skeleton) == null:
			node.skeleton = node.get_path_to(skeleton)
	for child in node.get_children(): bind_skins(child,skeleton)
func run() -> void:
	var pack := ""; var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference-pack="): pack = arg.trim_prefix("--reference-pack=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if pack.is_empty() or output.is_empty():
		print("Usage: godot --headless --script reuse_local_players.gd -- --reference-pack=<existing DSR pck> --output=<local assets directory>")
		quit(2); return
	if not ProjectSettings.load_resource_pack(pack,false): push_error("Cannot read existing local reference pack"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var manifest := {"source":"existing local Dragonsong-Sim equipped player presets","source_pack_sha256":FileAccess.get_sha256(pack),"models":{}}
	for name in PRESETS:
		var path: String = "res://scenes/common/player_characters/models/"+name+".tscn"
		var packed = load(path)
		if not packed is PackedScene: push_error("Missing local preset "+path); quit(1); return
		var model: Node = packed.instantiate()
		strip_scripts(model)
		root.add_child(model)
		bind_skins(model)
		await process_frame # Register SkinReferences before glTF export.
		var state := GLTFState.new(); var doc := GLTFDocument.new()
		var err := doc.append_from_scene(model,state)
		var target := output.path_join("pc_"+name+".glb")
		if err == OK: err = doc.write_to_filesystem(state,target)
		print("PLAYER_EXPORT ",name," error=",err," meshes=",state.get_meshes().size()," animations=",state.get_animations().size())
		model.free()
		if err != OK: quit(1); return
		manifest.models["pc_"+name] = {"file":target.get_file(),"source_scene":path,"sha256":FileAccess.get_sha256(target)}
	var file := FileAccess.open(output.path_join("players.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"));file.close()
	quit()
