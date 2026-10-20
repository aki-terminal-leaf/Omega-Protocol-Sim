# SPDX-License-Identifier: MIT
extends Node3D
const Rules = preload("res://scripts/rules.gd")
var camera: Camera3D
var actor_nodes: Array = []
var actor_labels: Array = []
var actor_arrows: Array = []
var aoe = ImmediateMesh.new()
var aoe_node = MeshInstance3D.new()
var guide = false
var selected_player = 4
var current: Dictionary = {}
var actors: Array = []
var redraw_elapsed = 0.0
var camera_size = 49.0
var overhead = false

func _ready() -> void:
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080d1b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8c4e4")
	env.ambient_light_energy = 0.9
	environment.environment = env; add_child(environment)
	var light = DirectionalLight3D.new(); light.rotation_degrees = Vector3(-60, -25, 0); light.light_energy = 1.1; add_child(light)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; add_child(camera); update_camera()
	var floor_mesh = CylinderMesh.new(); floor_mesh.top_radius = 20; floor_mesh.bottom_radius = 20; floor_mesh.height = 0.25; floor_mesh.radial_segments = 128
	mesh_node(floor_mesh, Vector3(0, -0.2, 0), Color("142339"))
	for radius in [5.0, 10.0, 13.0, 19.8, 20.2]:
		var ring = TorusMesh.new(); ring.inner_radius = radius - 0.035; ring.outer_radius = radius + 0.035; ring.rings = 96; ring.ring_segments = 8
		mesh_node(ring, Vector3(0, 0.02, 0), Color("ff5477") if radius > 19 else Color("345367"))
	for i in 8:
		var p = Rules.direction(i * 45) * 13
		var text = Label3D.new(); text.text = ["A", "1", "B", "2", "C", "3", "D", "4"][i]; text.font_size = 80; text.pixel_size = 0.025; text.modulate = [Color("ff6e9b"),Color("ffd480"),Color("ffd480"),Color("8cf0bc"),Color("8cf0bc"),Color("a8adff"),Color("a8adff"),Color("ff6e9b")][i]; text.position = Vector3(p.x, 0.08, p.y); text.rotation_degrees.x = -90; add_child(text)
	# Abstract, original geometry; no extracted Square Enix models or images.
	var orb = SphereMesh.new(); orb.radius = 1.7; orb.height = 3.4
	mesh_node(orb, Vector3(0, 2.4, 0), Color("817346"))
	for j in 3:
		var ring = TorusMesh.new(); ring.inner_radius = 2.4; ring.outer_radius = 2.55; ring.rings = 40
		var n = mesh_node(ring, Vector3(0, 2.4, 0), Color("57e6ba")); n.rotation_degrees = Vector3(25 + j * 50, j * 60, 20)
	var shader = Shader.new(); shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; varying vec3 plane_position; void vertex(){ plane_position = VERTEX; } void fragment(){ if(length(plane_position.xz) > 20.05) discard; ALBEDO = COLOR.rgb; ALPHA = COLOR.a; }"
	var material = ShaderMaterial.new(); material.shader = shader
	aoe_node.mesh = aoe; aoe_node.material_override = material; add_child(aoe_node)
	for i in 8:
		var root = Node3D.new(); add_child(root)
		var capsule = CapsuleMesh.new(); capsule.radius = 0.4; capsule.height = 1.35
		var colour = Color("599bff") if i < 2 else (Color("67dfad") if i < 4 else Color("f29391"))
		var body = MeshInstance3D.new(); body.mesh = capsule; body.position.y = 0.7; body.material_override = mat(colour); root.add_child(body)
		var label = Label3D.new(); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.font_size = 34; label.pixel_size = 0.024; label.outline_size = 8; label.position.y = 2.4; label.no_depth_test = true; root.add_child(label)
		var arrow = Node3D.new(); root.add_child(arrow)
		var cone = PrismMesh.new(); cone.size = Vector3(0.5, 0.05, 0.8)
		var facing = MeshInstance3D.new(); facing.mesh = cone; facing.position = Vector3(0, 0.12, -0.85); facing.rotation_degrees.x = 180; facing.material_override = mat(Color("fff3b2")); arrow.add_child(facing)
		actor_nodes.append(root); actor_labels.append(label); actor_arrows.append(arrow)

func mat(colour: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = 0.75; return material
func mesh_node(mesh: Mesh, position_value: Vector3, colour: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new(); n.mesh = mesh; n.position = position_value; n.material_override = mat(colour); add_child(n); return n
func update_camera() -> void:
	camera.size = camera_size
	camera.position = Vector3(0, 42, 0.01) if overhead else Vector3(0, 34, 24)
	camera.look_at(Vector3.ZERO)
func zoom(amount: float) -> void:
	camera_size = clampf(camera_size + amount, 38, 64); update_camera()
func screen_to_world(screen: Vector2) -> Vector2:
	var origin = camera.project_ray_origin(screen)
	var direction = camera.project_ray_normal(screen)
	if absf(direction.y) < 0.01: return Vector2.ZERO
	var point = origin + direction * (-origin.y / direction.y)
	return Vector2(point.x, point.z)
func update_state(new_actors: Array, beat_value: Dictionary, player: int, hints: bool) -> void:
	actors = new_actors; current = beat_value; selected_player = player; guide = hints
func _process(delta: float) -> void:
	if actors.size() != 8: return
	for i in 8:
		var p = Rules.v(actors[i].pos)
		actor_nodes[i].position = Vector3(p.x, 0.02, p.y)
		actor_arrows[i].rotation_degrees.y = -float(actors[i].face)
		actor_labels[i].text = ("YOU · " if i == selected_player else "") + actors[i].role + "\n" + str(current.get("labels", ["", "", "", "", "", "", "", ""])[i])
		actor_labels[i].modulate = Color("fff3b2") if i == selected_player else Color("c5d8ee")
	redraw_elapsed += delta
	if redraw_elapsed < 0.07: return
	redraw_elapsed = 0
	draw_indicators()
func vertex(p: Vector2, colour: Color, height := 0.08) -> void:
	aoe.surface_set_color(colour); aoe.surface_add_vertex(Vector3(p.x, height, p.y))
func tri(a: Vector2, b: Vector2, c: Vector2, colour: Color) -> void:
	vertex(a, colour); vertex(b, colour); vertex(c, colour)
func disk(p: Vector2, inner: float, outer: float, colour: Color, start := 0.0, span := 360.0) -> void:
	var segments = maxi(6, int(span / 6.0))
	for i in segments:
		var d1 = Rules.direction(start + span * i / segments); var d2 = Rules.direction(start + span * (i + 1) / segments)
		tri(p + d1 * inner, p + d1 * outer, p + d2 * outer, colour)
		if inner > 0: tri(p + d1 * inner, p + d2 * outer, p + d2 * inner, colour)
func rectangle(p: Vector2, axis: Vector2, start: float, length: float, width: float, colour: Color) -> void:
	var normal = axis.orthogonal() * width / 2.0
	var a = p + axis * start - normal; var b = p + axis * length - normal; var c = p + axis * length + normal; var d = p + axis * start + normal
	tri(a, b, c, colour); tri(a, c, d, colour)
func draw_shape(shape: Dictionary, override := Color.TRANSPARENT) -> void:
	var colour = Color(1, 0.30, 0.23, 0.24)
	if shape.get("rule", "avoid") == "count": colour = Color(0.18, 0.8, 0.78, 0.28) if shape.get("count", 1) > 1 else Color(0.97, 0.71, 0.29, 0.3)
	if override != Color.TRANSPARENT: colour = override
	var p = Rules.point(shape, actors)
	match shape.get("kind", "circle"):
		"circle", "spread", "stack", "tower", "flare":
			disk(p, 0, float(shape.get("radius", 3)), colour)
			disk(p, float(shape.get("radius", 3)) - 0.09, float(shape.get("radius", 3)), Color(colour, 0.85))
		"donut": disk(p, float(shape.get("inner", 0)), float(shape.get("radius", 20)), colour)
		"line": rectangle(p, Rules.aim(shape, actors), float(shape.get("start", 0)), float(shape.get("length", 45)), float(shape.get("width", 3)), colour)
		"cone", "half":
			var axis = Rules.aim(shape, actors); var degrees = rad_to_deg(atan2(axis.x, -axis.y)); var span = 180.0 if shape.kind == "half" else float(shape.get("width", 90))
			disk(p, 0, float(shape.get("radius", 40)), colour, degrees - span / 2, span)
func draw_indicators() -> void:
	aoe.clear_surfaces(); aoe.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for shape in current.get("shapes", []): draw_shape(shape)
	for source in current.get("monitors", []): draw_shape(source, Color(0.25, 0.55, 1, 0.13))
	for tether in current.get("tethers", []):
		var p = Rules.v(actors[int(tether.a)].pos)
		var q = Rules.v(actors[int(tether.b)].pos) if int(tether.b) >= 0 else Vector2.ZERO
		rectangle(p, (q - p).normalized(), 0, p.distance_to(q), 0.12, Color("8edbff"))
	if current.has("world"):
		for key in ["near", "far"]:
			var i = int(current.world[key]); disk(Rules.v(actors[i].pos), 4.85, 5.0, Color(0.75, 0.45, 1, 0.8))
		if guide:
			for path in [current.world.near_path, current.world.far_path]:
				for j in 2:
					var p = Rules.v(actors[int(path[j])].pos); var q = Rules.v(actors[int(path[j + 1])].pos)
					rectangle(p, (q - p).normalized(), 0, p.distance_to(q), 0.10, Color(0.8, 0.6, 1, 0.9))
	if guide and current.has("positions"):
		var goal = Rules.v(current.positions[selected_player])
		disk(goal, 0, 0.8, Color(0.25, 1, 0.72, 0.8)); disk(goal, 1.05, 1.2, Color(0.25, 1, 0.72, 0.8))
	var player_pos = Rules.v(actors[selected_player].pos)
	disk(player_pos, 0.65, 0.8, Color(1, 0.92, 0.55, 0.9))
	aoe.surface_end()
