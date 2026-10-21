# SPDX-License-Identifier: MIT
extends Node3D
const Visuals = preload("res://scripts/visuals.gd")
const Rules = preload("res://scripts/rules.gd")
var camera: Camera3D
var actor_nodes: Array = []
var actor_labels: Array = []
var actor_arrows: Array = []
var aoe = ImmediateMesh.new()
var aoe_node = MeshInstance3D.new()
var signs = ImmediateMesh.new()
var signs_node = MeshInstance3D.new()
var guide = false
var selected_player = 4
var current: Dictionary = {}
var actors: Array = []
var redraw_elapsed = 0.0
var camera_size = 44.0
var overhead = false
var camera_yaw = 0.0
var camera_pitch = 0.91
var follow_player = false
var follow_target = Vector3.ZERO
var camera_target = Vector3.ZERO
var encounter_id = "p1_loop"
var bosses: Array = []
var floor_node: Node3D
var actor_models: Array = []
var animation_time = 0.0
var positions_initialized = false
var last_clone_cue = ""
var stage_nodes: Array=[]
var stage_signature := ""
var beat_elapsed := 0.0

func _ready() -> void:
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080d1b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8c4e4")
	env.ambient_light_energy = 0.65
	environment.environment = env; add_child(environment)
	var light = DirectionalLight3D.new(); light.rotation_degrees = Vector3(-60, -25, 0); light.light_energy = 1.1; add_child(light)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55; camera.near = 0.1; camera.far = 250; camera.current = true
	add_child(camera); update_camera()
	for i in 8:
		var p = Rules.direction(i * 45) * 13
		Visuals.ring(self, Vector3(p.x, 0.04, p.y), 0.8, 0.035, Color("6f99ac"))
		var text = Label3D.new(); text.text = ["A", "1", "B", "2", "C", "3", "D", "4"][i]; text.font_size = 80; text.pixel_size = 0.025; text.modulate = [Color("ff6e9b"),Color("ffd480"),Color("ffd480"),Color("8cf0bc"),Color("8cf0bc"),Color("a8adff"),Color("a8adff"),Color("ff6e9b")][i]; text.position = Vector3(p.x, 0.08, p.y); text.rotation_degrees.x = -90; add_child(text)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): encounter_id = arg.trim_prefix("--scenario=")
	set_encounter(encounter_id)
	var shader = Shader.new(); shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; varying vec3 plane_position; void vertex(){ plane_position = VERTEX; } void fragment(){ if(length(plane_position.xz) > 20.05) discard; ALBEDO = COLOR.rgb; ALPHA = COLOR.a; }"
	var material = ShaderMaterial.new(); material.shader = shader
	aoe_node.mesh = aoe; aoe_node.material_override = material; add_child(aoe_node)
	signs_node.mesh = signs; signs_node.material_override = material; add_child(signs_node)
	for i in 8:
		var root = Node3D.new(); add_child(root)
		var body = Visuals.humanoid(i); root.add_child(body); actor_models.append(body)
		var label = Label3D.new(); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.font_size = 34; label.pixel_size = 0.017; label.outline_size = 8; label.position.y = 2.7; label.no_depth_test = true; root.add_child(label)
		var arrow = Node3D.new(); root.add_child(arrow)
		var cone = PrismMesh.new(); cone.size = Vector3(0.5, 0.05, 0.8)
		var facing = MeshInstance3D.new(); facing.mesh = cone; facing.position = Vector3(0, 0.12, -0.85); facing.rotation_degrees.x = 180; facing.material_override = mat(Color("fff3b2")); arrow.add_child(facing)
		actor_nodes.append(root); actor_labels.append(label); actor_arrows.append(arrow)

func mat(colour: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = 0.75; return material
func mesh_node(mesh: Mesh, position_value: Vector3, colour: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new(); n.mesh = mesh; n.position = position_value; n.material_override = mat(colour); add_child(n); return n
func update_camera() -> void:
	if not is_instance_valid(camera): return
	camera.size = camera_size
	var pitch = PI / 2 - 0.001 if overhead else camera_pitch
	var offset = Vector3(sin(camera_yaw) * cos(pitch), sin(pitch), cos(camera_yaw) * cos(pitch))
	camera.position = camera_target + offset * camera_size
	camera.look_at(camera_target)
func zoom(amount: float) -> void:
	camera_size = clampf(camera_size + amount, 14, 80); update_camera()
func orbit(relative: Vector2) -> void:
	camera_yaw = wrapf(camera_yaw - relative.x * 0.002, -PI, PI)
	camera_pitch = clampf(camera_pitch + relative.y * 0.002, 0.25, 1.45)
	update_camera()
func movement_vector(input: Vector2) -> Vector2:
	return Vector2(input.x * cos(camera_yaw) + input.y * sin(camera_yaw), -input.x * sin(camera_yaw) + input.y * cos(camera_yaw)).limit_length(1.0)
func reset_camera() -> void:
	camera_yaw = 0; camera_pitch = 0.91; camera_size = 44; overhead = false
	follow_player = false; camera_target = Vector3.ZERO; update_camera()
func set_follow(enabled: bool) -> void:
	follow_player = enabled
func set_encounter(id: String) -> void:
	encounter_id = id
	if not is_inside_tree(): return
	for boss in bosses:
		remove_child(boss); boss.queue_free()
	bosses.clear()
	last_clone_cue = ""
	if is_instance_valid(floor_node): remove_child(floor_node); floor_node.queue_free()
	floor_node = Visuals.floor_model(6 if id.begins_with("p6_") else 1); add_child(floor_node)
	var forms: Array = ["beetle"]
	if id.begins_with("p2_") or id.begins_with("p5_"): forms = ["male", "female"]
	elif id.begins_with("p3_") or id.begins_with("p4_"): forms = ["final"]
	elif id.begins_with("p6_"): forms = ["alpha"]
	for form in forms:
		var boss = Visuals.boss(form); add_child(boss); bosses.append(boss)
		if forms.size() == 2:
			boss.position.x = -11 if form == "male" else 11
			boss.rotation_degrees.y = 90 if form == "male" else -90
			var label = Label3D.new(); label.name = "Cue"
			label.text = "OMEGA " + ("M" if form == "male" else "F")
			label.position.y = 4.8; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 28; label.pixel_size = 0.025; boss.add_child(label)
func screen_to_world(screen: Vector2) -> Vector2:
	var origin = camera.project_ray_origin(screen)
	var direction = camera.project_ray_normal(screen)
	if absf(direction.y) < 0.01: return Vector2.ZERO
	var point = origin + direction * (-origin.y / direction.y)
	return Vector2(point.x, point.z)
func update_state(new_actors: Array, beat_value: Dictionary, player: int, hints: bool, elapsed := 0.0) -> void:
	beat_elapsed = elapsed
	actors = new_actors; current = beat_value; selected_player = player; guide = hints
	for node in actor_nodes: node.visible = actors.size() == 8
	if actors.size() != 8:
		aoe.clear_surfaces(); signs.clear_surfaces(); positions_initialized = false
	update_stage_entities()
	update_clone_cues()
	if player >= 0 and player < actors.size():
		var p = Rules.v(actors[player].pos)
		follow_target = Vector3(p.x, 0, p.y)
func _process(delta: float) -> void:
	animation_time += delta
	camera_target = camera_target.lerp(follow_target if follow_player else Vector3.ZERO, 1.0 - exp(-delta * 6))
	update_camera()
	if actors.size() != 8: return
	for i in 8:
		var p = Rules.v(actors[i].pos)
		var next_position = Vector3(p.x, 0.02, p.y)
		var velocity = (next_position - actor_nodes[i].position) / maxf(delta, 0.001) if positions_initialized else Vector3.ZERO
		actor_nodes[i].position = next_position
		actor_models[i].position.y = float(actors[i].get("height", 0.0))
		actor_labels[i].position.y = 2.7 + float(actors[i].get("height", 0.0))
		Visuals.animate(actor_models[i], animation_time + i * 0.5, velocity.length())
		actor_models[i].rotation.y = lerp_angle(actor_models[i].rotation.y, -deg_to_rad(float(actors[i].face)), 1.0 - exp(-delta * 15))
		actor_arrows[i].rotation_degrees.y = -float(actors[i].face)
		actor_labels[i].text = ("YOU / " if i == selected_player else "") + actors[i].role + "\n" + str(current.get("labels", ["", "", "", "", "", "", "", ""])[i])
		actor_labels[i].modulate = Color("fff3b2") if i == selected_player else Color("c5d8ee")
	positions_initialized = true
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
	var tethers: Array = current.get("tethers", [])
	if current.get("program_loop", {}) is Dictionary and current.get("program_loop", {}).has("holders"):
		tethers = [] # Live ownership supersedes the legacy preset list for Program Loop.
		for holder in current.program_loop.holders:
			if int(holder) >= 0 and int(holder) < actors.size(): tethers.append({"a": int(holder), "b": -1})
	for tether in tethers:
		if int(tether.a) < 0 or int(tether.a) >= actors.size() or int(tether.b) >= actors.size(): continue
		var p = Rules.v(actors[int(tether.a)].pos)
		var q = Rules.v(actors[int(tether.b)].pos) if int(tether.b) >= 0 else Rules.v(tether.get("source", Vector2.ZERO))
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
	draw_signs(tethers)

# Thin world-space lines avoid transparent cylinder overdraw in Compatibility.
func sign_line(a: Vector3, b: Vector3, c: Color) -> void:
	signs.surface_set_color(c); signs.surface_add_vertex(a)
	signs.surface_set_color(c); signs.surface_add_vertex(b)
func sign_ring(p: Vector3, radius: float, c: Color) -> void:
	for i in 48:
		var a = TAU * i / 48; var b = TAU * (i + 1) / 48
		sign_line(p + Vector3(cos(a), 0, sin(a)) * radius, p + Vector3(cos(b), 0, sin(b)) * radius, c)
func draw_signs(tethers: Array) -> void:
	signs.clear_surfaces(); signs.surface_begin(Mesh.PRIMITIVE_LINES)
	# Always add a center source halo, keeping the surface valid even on empty beats.
	sign_ring(Vector3(0, 0.2, 0), 0.3, Color("78dfdf"))
	for tether in tethers:
		var a = int(tether.a); var b = int(tether.b)
		if a < 0 or a >= actors.size() or b >= actors.size(): continue
		var p = actor_nodes[a].position + Vector3(0, 1.8, 0)
		var q = actor_nodes[b].position + Vector3(0, 1.8, 0) if b >= 0 else Vector3(Rules.v(tether.get("source", Vector2.ZERO)).x, 1.8, Rules.v(tether.get("source", Vector2.ZERO)).y)
		sign_line(p, q, Color("ffba67"))
		sign_ring(p + Vector3(0, 0.65, 0), 0.42, Color("ffcc76"))
		sign_line(p + Vector3(0, 0.7, 0), p + Vector3(0, 1.25, 0), Color("ffcc76"))
	for shape in current.get("shapes", []):
		var p2 = Rules.point(shape, actors)
		var p = Vector3(p2.x, 0, p2.y)
		var kind = shape.get("kind", "")
		if kind == "tower":
			var radius = float(shape.get("radius", 3))
			var c = Color("ffcf70")
			sign_ring(p + Vector3(0, 0.15, 0), radius, c)
			sign_ring(p + Vector3(0, 2.8, 0), radius, c)
			for i in 8:
				var d = Vector3(cos(i * PI / 4), 0, sin(i * PI / 4)) * radius
				sign_line(p + d, p + d + Vector3(0, 2.8, 0), Color(c, 0.7))
		elif kind == "stack" or kind == "spread" or kind == "flare":
			var c = Color("ffe28c") if kind == "stack" else Color("ff7e94")
			p.y = 3.5
			sign_ring(p, 0.45, c)
			for i in 4:
				var d = Vector3(cos(i * PI / 2), 0, sin(i * PI / 2))
				var tip = p + d * (0.55 if kind == "stack" else 1.2)
				var tail = p + d * (1.2 if kind == "stack" else 0.55)
				var side = Vector3(-d.z, 0, d.x) * 0.2
				sign_line(tip, tail, c)
				sign_line(tip, tip.lerp(tail, 0.45) + side, c)
				sign_line(tip, tip.lerp(tail, 0.45) - side, c)
	signs.surface_end()

func update_clone_cues() -> void:
	if not current.get("stage_entities",[]).is_empty(): return
	if bosses.size() != 2: return
	var title = str(current.get("title", "")).to_upper()
	if title == last_clone_cue: return
	last_clone_cue = title
	for i in 2:
		var boss: Node3D = bosses[i]
		var options = ["SWORD", "SHIELD"] if i == 0 else ["LEGS", "STAFF"]
		var active = ""
		for option in options:
			var shown = title.contains(option)
			if boss.has_node(option): boss.get_node(option).visible = shown
			if shown: active = option
		if current.has("clone_pattern"):
			active = ("SWORD" if current.clone_pattern.sword else "SHIELD") if i == 0 else ("LEGS" if current.clone_pattern.legs else "STAFF")
		Visuals.Official.set_stance(boss,active)
		boss.get_node("Cue").text = ("M" if i == 0 else "F") + (" / " + active if not active.is_empty() else "")
		# P5's combined sector drill does not supply genuine clone spawn locations.
		# Keep its display pair on the north rim so these do not imply AoE origins.
		if encounter_id.begins_with("p5_"):
			if current.has("clone_pattern"):
				var pattern: Dictionary = current.clone_pattern
				var rotation := float(pattern.orientation) + (90.0 if pattern.second else 0.0)
				var source := Vector2(-8 if i == 0 else 8,0).rotated(deg_to_rad(rotation))
				boss.position = Vector3(source.x,0,source.y)
				boss.rotation_degrees.y = (90 if i == 0 else -90)-rotation
			else: boss.position = Vector3(-5 if i == 0 else 5,0,-15)
			boss.visible = not active.is_empty()

func update_stage_entities() -> void:
	var entities: Array=current.get("stage_entities",[])
	var signature:=str(entities)
	if signature!=stage_signature:
		for node in stage_nodes:remove_child(node);node.queue_free()
		stage_nodes=[];stage_signature=signature
		for entity in entities:
			var node:Node3D=Visuals.boss(entity.form);add_child(node);stage_nodes.append(node)
			var p:Vector2=entity.pos;node.position=Vector3(p.x,0,p.y)
			node.rotation_degrees.y=180.0-float(entity.get("facing",0))
			var stance:String=entity.get("stance","")
			Visuals.Official.set_stance(node,stance)
			for option in ["SWORD","SHIELD","LEGS","STAFF"]:
				if node.has_node(option):node.get_node(option).visible=option==stance
			var label:=Label3D.new();label.text=entity.form.to_upper()+(" / "+stance if not stance.is_empty() else "")
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position.y=4.8;label.font_size=28;label.pixel_size=0.025;node.add_child(label)
	for node in bosses:node.visible=not bool(current.get("hide_main_boss",false))
	for i in stage_nodes.size():stage_nodes[i].visible=actors.size()==8 and beat_elapsed>=float(entities[i].get("spawn_delay",0))
