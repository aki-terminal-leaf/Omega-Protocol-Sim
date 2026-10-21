# SPDX-License-Identifier: MIT
extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var arena: Node3D
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CAMERA ASSERTION: " + message)

func settle() -> void:
	# SpringArm updates in physics, not during update_camera().
	for i in 3: await physics_frame
	await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	# Decode the serialized source transform without instantiating its GPL scene.
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../scenes/characters/player.tscn"))
	var pitch_section := source.split('[node name="PitchPivot"')[1].split("[node")[0]
	var transform_text := pitch_section.split("transform = ")[1].strip_edges()
	var source_transform: Transform3D = str_to_var(transform_text)
	check(is_equal_approx(source_transform.basis.get_euler().x, deg_to_rad(-10)), "serialized source pitch is negative ten")
	arena = Arena.new()
	root.add_child(arena)
	arena.set_process(false)
	var actors: Array = []
	for i in 8:
		actors.append({"pos": [float(i * 2 - 8), 3.0], "height": 0.0, "face": 37.0, "role": "P%d" % i, "speed": 6.0, "sprint_speed": 7.5})
	arena.update_state(actors, {"labels": ["1","2","3","4","5","6","7","8"]}, 4, true)
	arena._process(0.016)
	await settle()
	check(arena.follow_player and not arena.overhead, "player follow is default")
	check(arena.camera.get_parent() == arena.spring_arm and arena.spring_arm.get_parent() == arena.pitch_pivot and arena.pitch_pivot.get_parent() == arena.twist_pivot, "native pivot/arm/camera hierarchy")
	check(is_equal_approx(arena.camera_size, 22.0 * 0.44), "source default distance scaled")
	check(is_equal_approx(arena.camera.fov, 75.0) and is_equal_approx(arena.camera.near, 0.05 * 0.44), "native FOV / scaled near")
	check(is_equal_approx(arena.pitch_pivot.rotation.x, deg_to_rad(-10)), "negative native source pitch")
	var target: Vector3 = Vector3(0, 0.02 + 3.5 * 0.44, 3)
	var expected := target + Vector3(0, sin(deg_to_rad(10)), cos(deg_to_rad(10))) * 9.68
	check(arena.camera.global_position.distance_to(expected) < 0.001, "actual initial camera matches scaled source rig")
	for height in [0.1, 1.0, 2.1]:
		var point := Vector3(0, height, 3)
		check(not arena.camera.is_position_behind(point) and Rect2(Vector2.ZERO, Vector2(root.size)).has_point(arena.camera.unproject_position(point)), "selected body sample in default frame")
	var before: Vector3 = arena.camera.global_position
	actors[4].pos = [5.0, -2.0]; actors[4].height = 1.25
	var snapshot := JSON.stringify(actors)
	arena.update_state(actors, arena.current, 4, true)
	check(arena.twist_pivot.position.distance_to(Vector3(5, 2.81, -2)) < 0.001, "follow translation and jump immediate at state update")
	arena._process(0.001); await settle()
	check((arena.camera.global_position - before).distance_to(Vector3(5, 1.25, -5)) < 0.001, "actual camera tracks full translation/jump")
	before = arena.camera.global_position
	for delta in [0.001, 0.2, 0.033]: arena._process(delta)
	await settle()
	check(arena.camera.global_position.distance_to(before) < 0.001, "no delta-dependent drift")
	check(JSON.stringify(actors) == snapshot, "visual processing leaves complete actor JSON unchanged")
	arena.update_state(actors, arena.current, 1, true)
	check(arena.camera_target.distance_to(Vector3(-6, 0.02, 3)) < 0.001, "selection immediately follows correct actor")
	arena.orbit(Vector2(100, 50))
	check(is_equal_approx(arena.camera_yaw, -0.2) and is_equal_approx(arena.camera_pitch, deg_to_rad(10) + 0.1), "mouse axes and sensitivity")
	check(is_equal_approx(arena.pitch_pivot.rotation.x, -arena.camera_pitch), "native pitch sign")
	for yaw in [0.0, PI / 2, -PI / 2, PI]:
		arena.camera_yaw = yaw; arena.update_camera()
		for input in [Vector2(0,-1), Vector2(1,0), Vector2(-1,1).normalized()]:
			var world: Vector3 = arena.twist_pivot.basis * Vector3(input.x, 0, input.y)
			check(arena.movement_vector(input).distance_to(Vector2(world.x, world.z)) < 0.0001, "movement matches native yaw basis")
	arena.reset_camera()
	arena.zoom_steps(-1)
	check(is_equal_approx(arena.camera_size, 9.46), "one inward wheel step = scaled .5")
	arena.zoom_steps(1)
	check(is_equal_approx(arena.camera_size, 9.68), "outward wheel reverses")
	arena.zoom(-100); await settle()
	check(is_equal_approx(arena.camera_size, 0.044) and is_equal_approx(arena.camera.position.z, 0.044), "actual minimum arm")
	arena.zoom(100); await settle()
	check(is_equal_approx(arena.camera_size, 13.2) and is_equal_approx(arena.camera.position.z, 13.2), "actual maximum arm")
	for pitch in [-PI / 2, -PI / 4, PI / 2]:
		arena.camera_pitch = pitch; arena.update_camera(); await settle()
		check(arena.camera.global_transform.is_finite(), "vertical rig remains finite")
		check(arena.camera.global_position.y > 0.022, "camera-only floor avoidance")
		check(is_equal_approx(arena.camera_pitch, pitch), "floor does not restrict pitch")
		if pitch < 0: check(arena.spring_arm.get_hit_length() < arena.camera_size, "native physics shortens arm at floor")
	check(arena.camera_floor.collision_layer == arena.CAMERA_FLOOR_LAYER and arena.camera_floor.collision_mask == 0, "floor isolated on camera-only layer")
	arena.orbit(Vector2(0, -10000))
	check(is_equal_approx(arena.camera_pitch, -PI / 2), "negative 90 pitch allowed")
	arena.orbit(Vector2(0, 10000))
	check(is_equal_approx(arena.camera_pitch, PI / 2), "positive 90 pitch allowed")
	arena.reset_camera(); arena.orbit(Vector2(40, 20)); arena.zoom_steps(2)
	var saved := Vector3(arena.camera_yaw, arena.camera_pitch, arena.camera_size)
	arena.set_overhead(true); await settle()
	check(arena.overhead and not arena.follow_player and arena.camera_target == Vector3.ZERO, "overview explicit arena center")
	check(is_equal_approx(arena.camera.fov,55) and is_equal_approx(arena.camera.global_position.length(),44) and is_equal_approx(arena.camera_pitch,0.91), "overview old high framing")
	arena.zoom_steps(1)
	check(is_equal_approx(arena.camera_size,46), "overview two-unit wheel")
	arena.set_overhead(false); await settle()
	check(arena.follow_player and Vector3(arena.camera_yaw,arena.camera_pitch,arena.camera_size).distance_to(saved)<0.0001, "overview restores third-person settings")
	arena.set_follow(false)
	check(arena.camera_target == Vector3.ZERO, "follow API disables tracking")
	arena.set_overhead(true); arena.reset_camera(); await settle()
	check(arena.follow_player and not arena.overhead and is_equal_approx(arena.camera_size,9.68) and is_equal_approx(arena.camera_pitch,PI/18), "reset always restores source player view")
	arena._process(0.016)
	check(arena.actor_labels[1].pixel_size < 0.028 and arena.actor_labels[1].text == "YOU / P1\n2", "role content retained with compact presentation")
	check(JSON.stringify(actors) == snapshot, "all camera actions preserve actor JSON")
	# Synthetic textures make icon sizing/content checks independent of local media.
	var pixels := Image.create(64,64,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	arena.world_textures[215141] = texture
	arena.world_textures[215917] = texture
	var statuses: Array = [{},{},{},{},{},{},{},{}]
	statuses[1] = {"delta_near_world": {"expires": 30}, "red": {"expires": 20}}
	arena.update_state(actors, arena.current, 1, true, 0, {"statuses": statuses, "sim_time": 1})
	arena._process(0.016)
	check(arena.world_icons[1].visible and arena.world_icons[1].texture == texture and arena.observed_cue(1).icon == 215141, "World icon ID and visibility retained")
	check(arena.debuff_icons[1][0].visible and arena.observed_cue(1).badges[0].icon == 215917 and arena.status_labels[1].text == "19", "status icon ID and countdown retained")
	var compact: float = arena.world_icons[1].pixel_size
	arena.set_overhead(true); await settle(); arena._process(0.016)
	check(arena.world_icons[1].pixel_size > compact and is_equal_approx(arena.actor_labels[1].pixel_size,0.028), "overview cues restore larger readability")
	check(arena.guide and arena.actor_labels[1].text == "YOU / P1\n2", "hints and label text retained across overview")
	check(JSON.stringify(actors) == snapshot, "cue and overview processing preserve actor JSON")
	print("CAMERA_FIDELITY checks=%d failures=%d" % [checks, failures])
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
