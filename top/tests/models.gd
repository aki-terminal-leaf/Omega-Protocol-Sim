# Optional integration test for locally extracted original assets.
extends SceneTree
const Official = preload("res://scripts/official_models.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, text: String) -> void:
	if not condition: failures += 1; print("MODEL FAIL: ",text)
func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null: return found
	return null
func run() -> void:
	var loaded := 0
	for form in Official.SCALES:
		if not Official.available(form):
			check(not "--require-official" in OS.get_cmdline_user_args(),str(form)+" original pack missing")
			continue
		var model := Official.instantiate(form); root.add_child(model)
		check(model.get_meta("official_model",false),str(form)+" incorrectly fell back")
		var animation := Official.find_animation(model)
		var skeleton := find_skeleton(model)
		check(animation != null and skeleton != null,str(form)+" missing imported animation/rig")
		if animation != null and skeleton != null:
			check(skeleton.get_bone_count()>=90,str(form)+" incomplete original rig")
			check(model.has_meta("original_idle"),str(form)+" missing idle clip")
			animation.advance(0.01)
			var before: Array = []
			for i in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(i))
			animation.advance(0.37)
			var moved := false
			for i in skeleton.get_bone_count():
				if not before[i].is_equal_approx(skeleton.get_bone_pose(i)): moved = true
			check(moved,str(form)+" idle clip does not animate actual bones")
			var rest_extent := 0.0; var pose_extent := 0.0
			for i in skeleton.get_bone_count():
				rest_extent = maxf(rest_extent,skeleton.get_bone_global_rest(i).origin.length())
				pose_extent = maxf(pose_extent,skeleton.get_bone_global_pose(i).origin.length())
			check(pose_extent<rest_extent*3+1,str(form)+" malformed hierarchical animation / exploded rig")
			print("MODEL ",form," bones=",skeleton.get_bone_count()," clips=",animation.get_animation_list().size()," actual_motion=",moved)
		loaded += 1
		model.queue_free(); await process_frame
	var players := 0
	for role in [0,2,3,4,5,6,7]:
		var model := Official.player(role)
		if model == null:
			check(not "--require-official" in OS.get_cmdline_user_args(),"equipped player preset missing")
			continue
		root.add_child(model)
		var animation := Official.find_animation(model)
		check(animation != null,"equipped player missing imported clips")
		if animation != null:
			check(animation.get_animation_list().size()>=14,"incomplete equipped player clip set")
			Official.animate_player(model,6.0)
			check(str(animation.current_animation).ends_with("cbnm_02f_lp0"),"movement did not switch to real run animation")
			var skeleton := find_skeleton(model)
			animation.advance(0.01)
			var before: Array = []
			if skeleton != null:
				for bone in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(bone))
			animation.advance(0.37)
			var moved := false
			if skeleton != null:
				for bone in skeleton.get_bone_count():
					if not before[bone].is_equal_approx(skeleton.get_bone_pose(bone)): moved = true
				var head := skeleton.find_bone("j_kao")
				var foot := skeleton.find_bone("j_asi_d_l")
				if foot < 0: foot = skeleton.find_bone("j_asi_c_l")
				check(head>=0 and foot>=0,"equipped model has identifiable head and foot bones")
				if head >= 0 and foot >= 0:
					var head_pos := skeleton.global_transform * skeleton.get_bone_global_pose(head).origin
					var foot_pos := skeleton.global_transform * skeleton.get_bone_global_pose(foot).origin
					check(head_pos.y > foot_pos.y+0.7,"equipped avatar is not upright")
			check(moved,"equipped run clip does not move actual bones")
			check(model.position.is_equal_approx(Vector3.ZERO),"cosmetic animation changed gameplay actor origin")
			Official.animate_player(model,0.0)
			check(str(animation.current_animation).ends_with("cbnm_id0"),"stop did not restore idle animation")
		players += 1
		model.queue_free(); await process_frame
	print("EQUIPPED PLAYER INTEGRATION ",players)
	print("ORIGINAL MODEL INTEGRATION ",loaded," FAILURES ",failures)
	quit(1 if failures else 0)
