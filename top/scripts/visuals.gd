# SPDX-License-Identifier: MIT
extends RefCounted
## Optional local original-game bosses, with original procedural fallbacks.
const Official = preload("res://scripts/official_models.gd")
static var materials: Dictionary = {}

static func material(c: Color, glow := false) -> StandardMaterial3D:
	var key = str(c) + str(glow)
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = 0.65
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[key] = m
	return m

static func part(parent: Node3D, mesh: Mesh, p: Vector3, c: Color, glow := false) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh; n.position = p; n.material_override = material(c, glow)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n

static func box(parent: Node3D, p: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var m = BoxMesh.new(); m.size = size
	return part(parent, m, p, c)

static func ball(parent: Node3D, p: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var m = SphereMesh.new(); m.radius = 0.5; m.height = 1; m.radial_segments = 12; m.rings = 6
	var n = part(parent, m, p, c); n.scale = size
	return n

static func rod(parent: Node3D, a: Vector3, b: Vector3, width: float, c: Color) -> MeshInstance3D:
	var m = CylinderMesh.new(); m.top_radius = width; m.bottom_radius = width * 1.15; m.height = a.distance_to(b); m.radial_segments = 6
	var n = part(parent, m, (a + b) / 2, c)
	var up = (b - a).normalized()
	var side = up.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.01: side = up.cross(Vector3.RIGHT).normalized()
	n.basis = Basis(side, up, side.cross(up))
	return n

static func ring(parent: Node3D, p: Vector3, radius: float, width: float, c: Color) -> MeshInstance3D:
	var m = TorusMesh.new(); m.inner_radius = radius - width; m.outer_radius = radius + width; m.rings = 64; m.ring_segments = 6
	return part(parent, m, p, c, true)

static func humanoid(role: int, tint := Color.WHITE, equipped := true) -> Node3D:
	if tint == Color.WHITE and equipped:
		var imported := Official.player(role)
		if imported != null: return imported
	var root = Node3D.new()
	var c = ([Color("559bec"), Color("559bec"), Color("65d6af"), Color("65d6af"), Color("e87879"), Color("e87879"), Color("e9ae64"), Color("ba96ed")][role] if tint == Color.WHITE else tint)
	box(root, Vector3(0, 1.18, 0), Vector3(0.58, 0.65, 0.32), c)
	box(root, Vector3(0, 0.86, 0), Vector3(0.63, 0.15, 0.38), Color("282f46"))
	ball(root, Vector3(0, 1.83, 0), Vector3(0.39, 0.47, 0.37), Color("e9c6aa"))
	ball(root, Vector3(0, 1.98, 0.04), Vector3(0.43, 0.24, 0.4), Color("263449"))
	box(root, Vector3(0, 1.86, -0.19), Vector3(0.26, 0.06, 0.025), Color("9ef5f0"))
	var limbs: Array = []
	for i in 4:
		var pivot = Node3D.new(); root.add_child(pivot)
		var arm = i < 2
		pivot.position = Vector3((-1 if i % 2 == 0 else 1) * (0.4 if arm else 0.18), 1.43 if arm else 0.85, 0)
		rod(pivot, Vector3.ZERO, Vector3(0, -0.34, 0), 0.11, c)
		ball(pivot, Vector3(0, -0.34, 0), Vector3.ONE * 0.18, Color("29354c"))
		rod(pivot, Vector3(0, -0.34, 0), Vector3(0, -0.66, -0.03), 0.085, c.darkened(0.25))
		box(pivot, Vector3(0, -0.67, -0.07), Vector3(0.2, 0.19, 0.3 if not arm else 0.18), Color("253046"))
		limbs.append(pivot)
	if equipped and role < 2:
		box(limbs[0], Vector3(-0.12, -0.42, -0.12), Vector3(0.12, 0.62, 0.48), c.lightened(0.25))
		box(limbs[1], Vector3(0, -0.78, -0.18), Vector3(0.1, 0.9, 0.08), Color("d7e8eb"))
	elif equipped and (role < 4 or role == 7):
		rod(limbs[1], Vector3(0, 0.45, -0.2), Vector3(0, -1.1, -0.2), 0.045, Color("d2b77c"))
		ring(limbs[1], Vector3(0, 0.45, -0.2), 0.2, 0.04, c).rotation_degrees.x = 90
	elif equipped:
		for i in 2: box(limbs[i], Vector3(0, -0.64, -0.36), Vector3(0.08, 0.12, 0.65), Color("d9e7ef"))
	root.set_meta("limbs", limbs)
	return root

static func animate(root: Node3D, time: float, speed: float) -> void:
	if root.get_meta("official_player",false):
		Official.animate_player(root,speed)
		return
	var limbs: Array = root.get_meta("limbs", [])
	var moving = clampf(speed / 6.0, 0, 1)
	for i in limbs.size():
		limbs[i].rotation.x = sin(time * 10 + (PI if i == 1 or i == 2 else 0)) * moving * 0.65 + sin(time * 2) * 0.025

static func floor_model(phase := 1) -> Node3D:
	var root = Node3D.new()
	var m = CylinderMesh.new(); m.top_radius = 20; m.bottom_radius = 20.4; m.height = 0.8; m.radial_segments = 128
	part(root, m, Vector3(0, -0.45, 0), Color("433722") if phase == 6 else Color("172635"))
	for r in [3.8, 8.0, 12.8, 17.8, 19.6]: ring(root, Vector3(0, -0.025, 0), r, 0.035, Color("9b814e") if phase == 6 else Color("375466"))
	for i in 48:
		var a = TAU * i / 48
		var p = Vector3(sin(a), 0, cos(a))
		var plate = box(root, p * 18.7 + Vector3(0, -0.025, 0), Vector3(1.9, 0.05, 1.4), Color("233c4d") if i % 2 == 0 else Color("1d303f"))
		plate.rotation.y = a
		var tick = box(root, p * 19.6, Vector3(0.07, 0.04, 0.45), Color("7aa6ab")); tick.rotation.y = a
		if i % 6 == 0:
			var spoke = box(root, p * 11, Vector3(0.045, 0.025, 14), Color("314859")); spoke.rotation.y = a
	ring(root, Vector3(0, 0.03, 0), 20, 0.075, Color("ff678c"))
	ring(root, Vector3(0, -0.5, 0), 20.25, 0.07, Color("53abbc"))
	return root

static func boss(form: String) -> Node3D:
	var imported := Official.instantiate(form)
	if imported != null:
		ring(imported, Vector3(0, 0.045, 0), 4 if form == "beetle" else 2.5, 0.045, Color("e59074"))
		return imported
	var root = Node3D.new()
	if form not in ["beetle","male","female","final","alpha"]:
		# Unknown/missing auxiliary assets must never become a fake Final Omega.
		root.set_meta("missing_official_form",form)
		return root
	var armor = Color("697886"); var gold = Color("c4a875"); var glow = Color("69e9de")
	if form == "beetle":
		ball(root, Vector3(0, 2.1, 0), Vector3(3.4, 1.7, 4.1), armor)
		for s in [-1, 1]:
			ball(root, Vector3(s * 0.87, 2.65, 0.2), Vector3(1.45, 0.65, 3.1), gold)
			for j in 3:
				var a = Vector3(s * 1.1, 2.1, (j - 1) * 1.3)
				var b = Vector3(s * 2.8, 1.8, (j - 1) * 2.2)
				var c = Vector3(s * 3.5, 0.15, (j - 1) * 2.6)
				rod(root, a, b, 0.22, armor); ball(root, b, Vector3.ONE * 0.5, gold); rod(root, b, c, 0.12, armor)
			rod(root, Vector3(s * 0.7, 2.3, -1.5), Vector3(s * 1.4, 2.8, -3), 0.12, gold)
		ball(root, Vector3(0, 2.1, -2), Vector3(1.4, 0.8, 0.8), Color("273343"))
		for s in [-1, 1]: ball(root, Vector3(s * 0.45, 2.25, -2.38), Vector3(0.3, 0.2, 0.12), glow)
	elif form == "male" or form == "female":
		var body = humanoid(0 if form == "male" else 3, armor if form == "male" else Color("c4cbd4"), false)
		root.add_child(body); body.scale = Vector3.ONE * 1.8
		body.name = "Body"
		for equipment in (["SWORD", "SHIELD"] if form == "male" else ["LEGS", "STAFF"]):
			var gear = Node3D.new(); gear.name = equipment; root.add_child(gear)
			match equipment:
				"SWORD":
					box(gear, Vector3(1, 1.6, -0.8), Vector3(0.22, 2.4, 0.15), gold)
					box(gear, Vector3(1, 1.5, -0.8), Vector3(0.8, 0.15, 0.25), armor)
				"SHIELD": ball(gear, Vector3(-0.9, 1.8, -0.5), Vector3(1.5, 1.9, 0.3), gold)
				"STAFF":
					rod(gear, Vector3(1, 0.1, -0.4), Vector3(1, 4.3, -0.4), 0.08, gold)
					ring(gear, Vector3(1, 4.3, -0.4), 0.5, 0.08, glow).rotation_degrees.x = 90
				"LEGS":
					for side in [-1, 1]:
						rod(gear, Vector3(side * 0.3, 1.7, 0), Vector3(side * 1.8, 0.2, -1), 0.12, gold)
			gear.visible = false
	else:
		var body = humanoid(0, armor); root.add_child(body); body.scale = Vector3(2.2, 2.4, 2.2)
		for s in [-1, 1]:
			ball(root, Vector3(s * 1.4, 3.5, 0), Vector3(1.3, 1.5, 1.2), gold)
			rod(root, Vector3(s * 1.5, 3.5, 0), Vector3(s * 2.5, 1.2, -0.7), 0.3, armor)
			if form == "alpha":
				for j in 5:
					var a = Vector3(s * 0.6, 3.6, 0.5)
					var b = Vector3(s * (4.8 - j * 0.45), 5.6 - j * 0.65, 1.2 + j * 0.22)
					rod(root, a, b, 0.12, gold)
					var feather = box(root, b, Vector3(0.38, 1.6, 0.16), Color("adc6d4")); feather.rotation.z = s * -0.7
			else:
				for j in 3: box(root, Vector3(s * (1.4 + j * 0.35), 4.1 + j * 0.25, 0.5), Vector3(0.3, 1.7, 0.5), armor)
		ball(root, Vector3(0, 3.2, -0.85), Vector3(0.6, 0.6, 0.3), glow)
		ring(root, Vector3(0, 5.2, 0.4), 1.25, 0.06, glow).rotation_degrees.x = 70
	ring(root, Vector3(0, 0.045, 0), 4 if form == "beetle" else 2.5, 0.045, Color("e59074"))
	return root
