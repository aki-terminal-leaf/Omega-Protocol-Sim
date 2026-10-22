# SPDX-License-Identifier: MIT
extends SceneTree
const Visuals = preload("res://scripts/visuals.gd")
const EnemyRings = preload("res://scripts/enemy_rings.gd")
const Rules = preload("res://scripts/rules.gd")
const Arena = preload("res://scripts/arena.gd")
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1; print("ENEMY RING FAIL ", title)
func front(ring: MeshInstance3D) -> Vector3:
	var vertices: PackedVector3Array = ring.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tip: Vector3 = vertices[-1]
	return (ring.global_transform * tip - ring.global_position).normalized()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var expected := {"beetle":12.006,"male":5.010,"female":5.010,"final":12.502,"alpha":13.0,"male_p5":5.010,"female_p5":5.010,"fist_b5":1.5,"fist_b6":1.5,"arm_left":1.68,"arm_right":1.68,"rear_unit":6.72}
	for form in expected:
		var boss := Visuals.boss(form); root.add_child(boss)
		var ring: MeshInstance3D = boss.get_node("FacingRing")
		check(is_equal_approx(float(ring.get_meta("display_radius")), float(expected[form])), form + " captured actor radius")
		var vertices: PackedVector3Array = ring.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var actual_radius := 0.0
		for i in vertices.size()-3: actual_radius = maxf(actual_radius, Vector2(vertices[i].x,vertices[i].z).length())
		check(is_equal_approx(actual_radius,float(expected[form])), form + " geometry is radius in world units, not diameter/model scale")
		for heading in [0.0,45.0,90.0,135.0,180.0,225.0,270.0,315.0]:
			EnemyRings.configure(boss,{"facing":heading})
			var aim: Vector2 = Rules.direction(heading)
			var wanted := Vector3(aim.x,0,aim.y)
			check(front(ring).dot(wanted)>0.999, form + " front triangle follows authoritative heading " + str(heading))
			if boss.has_node("GameMesh"):
				var mesh: Node3D = boss.get_node("GameMesh")
				var model_front := (mesh.global_basis * Vector3.BACK).normalized()
				check(model_front.dot(wanted)>0.999, form + " source +Z anatomy faces same way as front triangle")
				check(is_equal_approx(mesh.scale.x,float(Visuals.Official.SCALES[form])), form + " original visual scale unchanged")
		EnemyRings.configure(boss,{"face":180.0})
		check(front(ring).dot(Vector3.BACK)>0.999, form + " legacy P4 face is not ignored")
		boss.queue_free(); await process_frame
	# Source-only procedural builds follow the same radius and north convention.
	for form in ["beetle","male","female","final","alpha"]:
		var boss := Visuals.boss(form,false); root.add_child(boss)
		var ring: MeshInstance3D = boss.get_node("FacingRing")
		check(not boss.get_meta("official_model",false) and is_equal_approx(float(ring.get_meta("display_radius")),float(expected[form])), form + " procedural fallback radius")
		EnemyRings.configure(boss,{"facing":270.0})
		check(front(ring).dot(Vector3.LEFT)>0.999, form + " fallback facing")
		boss.queue_free(); await process_frame
	var actors: Array = []
	for i in 8: actors.append({"role":str(i),"pos":Vector2(i-4,15),"face":0.0})
	var arena := Arena.new(); root.add_child(arena); await process_frame; arena.set_process(false)
	arena.set_encounter("p1_pantokrator")
	arena.update_state(actors,{"p1_route":{"boss_facing":270.0}},4,false)
	check(front(arena.bosses[0].get_node("FacingRing")).dot(Vector3.LEFT)>0.999,"live P1 main boss consumes course facing")
	arena.set_encounter("p2_party")
	check(front(arena.bosses[0].get_node("FacingRing")).dot(Vector3.RIGHT)>0.999 and front(arena.bosses[1].get_node("FacingRing")).dot(Vector3.LEFT)>0.999,"initial M/F face inward after mesh-axis correction")
	var beat := {"hide_main_boss":true,"stage_entities":[{"form":"male","pos":[4,0],"facing":90.0,"hitbox_radius":3.0}]}
	var before := JSON.stringify(beat)
	arena.update_state(actors,beat,4,false)
	var entity: Node3D = arena.stage_nodes[0]
	check(front(entity.get_node("FacingRing")).dot(Vector3.RIGHT)>0.999,"live stage entity has no extra 180 degree turn")
	check(is_equal_approx(float(entity.get_node("FacingRing").get_meta("display_radius")),3.0),"explicit small P2 captured state overrides full-scale radius")
	check(JSON.stringify(beat)==before,"presentation does not mutate source gameplay geometry")
	beat={"hide_main_boss":true,"stage_entities":[{"form":"final","pos":[0,0],"face":180.0}]}
	arena.update_state(actors,beat,4,false)
	check(front(arena.stage_nodes[0].get_node("FacingRing")).dot(Vector3.BACK)>0.999,"production P4 face alias points south")
	arena.queue_free(); await process_frame
	print("ENEMY RING checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
