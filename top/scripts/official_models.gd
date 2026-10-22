# SPDX-License-Identifier: MIT
extends RefCounted
## Optional original local-game meshes and resident animations. No game assets are embedded in source.
const PACK := "res://assets/official/"
const SCALES := {"beetle": 0.9, "male": 3.0, "female": 3.0, "final": 1.4, "alpha":0.8,"fist_b5":1.5,"fist_b6":1.5,"arm_left":1.4,"arm_right":1.4,"male_p5":3.0,"female_p5":3.0,"rear_unit":1.4}
const PLAYERS := ["pc_war_miq", "pc_war_miq", "pc_whm_aur", "pc_sch_hyr", "pc_drg_miq", "pc_sam_miq", "pc_brd_vra", "pc_blm_miq"]
static var scenes: Dictionary = {}

static func available(form: String) -> bool:
	return SCALES.has(form) and ResourceLoader.exists(PACK + form + ".glb")

static func instantiate(form: String) -> Node3D:
	if not available(form): return null
	if not scenes.has(form): scenes[form] = load(PACK + form + ".glb")
	var packed = scenes[form]
	if not packed is PackedScene: return null
	var root := Node3D.new()
	root.name = "Official_" + form
	var model: Node3D = packed.instantiate()
	model.name = "GameMesh"
	# Original SqPack meshes face +Z (eye/jaw landmarks); scene/Rules forward is -Z.
	# Correct only the mesh child once so ring, root heading and AoE axes agree.
	model.rotation_degrees.y = 180.0
	model.scale = Vector3.ONE * float(SCALES[form])
	root.add_child(model)
	root.set_meta("official_model", true)
	root.set_meta("model_form", form)
	var animation: AnimationPlayer = find_animation(model)
	if animation != null:
		for clip in animation.get_animation_list():
			if str(clip).ends_with("cbbm_id0"):
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animation.autoplay = clip
				animation.play(clip)
				root.set_meta("original_idle", clip)
				break
	root.set_meta("pose_fidelity", "original resident animation sampled at 30fps" if root.has_meta("original_idle") else "static bind pose")
	# Keep the same cue API as the procedural fallback. These nodes deliberately
	# do not invent original weapon animation or an uncalibrated part mapping.
	for cue in (["SWORD", "SHIELD"] if form.begins_with("male") else (["LEGS", "STAFF"] if form.begins_with("female") else [])):
		var marker := Node3D.new(); marker.name = cue; root.add_child(marker)
	set_stance(root, "SWORD" if form.begins_with("male") else ("STAFF" if form.begins_with("female") else ""))
	return root

static func player(role: int) -> Node3D:
	var form: String = PLAYERS[clampi(role,0,7)]
	var path := PACK + form + ".glb"
	if not ResourceLoader.exists(path): return null
	if not scenes.has(form): scenes[form] = load(path)
	if not scenes[form] is PackedScene: return null
	var root := Node3D.new(); root.name = form
	var model: Node3D = scenes[form].instantiate(); model.scale *= 0.55; root.add_child(model)
	root.set_meta("official_player", true)
	root.set_meta("source", "existing local DSR equipped model preset")
	var animation := find_animation(model)
	if animation != null:
		root.set_meta("animator", animation)
		for clip in animation.get_animation_list():
			if str(clip).ends_with("cbnm_id0"): root.set_meta("idle_clip",clip)
			if str(clip).ends_with("cbnm_02f_lp0"): root.set_meta("run_clip",clip)
			if str(clip).ends_with("cbnm_sprint_lp0"): root.set_meta("sprint_clip",clip)
		animate_player(root,0.0)
	return root

static func animate_player(root: Node3D, speed: float) -> void:
	var animation: AnimationPlayer = root.get_meta("animator",null)
	if not is_instance_valid(animation): return
	var clip: StringName = root.get_meta("idle_clip", "")
	if speed > 0.4: clip = root.get_meta("sprint_clip" if speed > 7 else "run_clip",clip)
	if not clip.is_empty() and animation.current_animation != clip:
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		animation.play(clip,0.15)

static func set_stance(root: Node3D, active: String) -> void:
	if not root.get_meta("official_model",false): return
	var form: String = root.get_meta("model_form","")
	if not form.begins_with("male") and not form.begins_with("female"): return
	set_parts(root,form,active)

static func set_parts(node: Node, form: String, active: String) -> void:
	if node is MeshInstance3D:
		var part := str(node.name)
		if part.contains("atr_parts_a"): node.visible = active == ("SHIELD" if form.begins_with("male") else "LEGS")
		elif part.contains("atr_parts_b"): node.visible = active != "NEUTRAL" and active != ("SHIELD" if form.begins_with("male") else "LEGS")
		elif form.begins_with("female") and part.contains("atr_bv_c"): node.visible = active != "LEGS"
	for child in node.get_children(): set_parts(child,form,active)

static func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_animation(child)
		if found != null: return found
	return null

static func summary() -> String:
	var count := 0
	for form in SCALES:
		if available(form): count += 1
	return "原版遊戲模型 %d/%d" % [count,SCALES.size()] if count > 0 else "訓練模型（未安裝本機遊戲素材包）"
