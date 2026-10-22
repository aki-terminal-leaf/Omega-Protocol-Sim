# SPDX-License-Identifier: MIT
extends Node3D
const UI_FONT = preload("res://fonts/ui.tres")
const Visuals = preload("res://scripts/visuals.gd")
const Rules = preload("res://scripts/rules.gd")
const Markers=preload("res://scripts/markers.gd")
const DeathWall=preload("res://scripts/death_wall.gd")
const FacingRing=preload("res://scripts/facing_ring.gd")
const EnemyRings=preload("res://scripts/enemy_rings.gd")
const SynergySigns=preload("res://scripts/synergy_signs.gd")
const LateDamagePreview=preload("res://scripts/late_damage_preview.gd")
var upcoming_beats:Array=[]
var visible_damage_shapes:Array=[]
const P3Effects=preload("res://scripts/p3_effects.gd")
var p3_fx_root:Node3D
var p3_loading:Array=[]
var p3_pulses:Array=[]
var p3_clock:=0.0
var p3_event_cursor:=0
var p3_last_time:=-1.0
var p3_signature:=""
var p3_resolved:=false
var camera: Camera3D
var actor_nodes: Array = []
var actor_labels: Array = []
var actor_arrows: Array = []
var aoe = ImmediateMesh.new()
var aoe_vertex_count:=0
var aoe_node = MeshInstance3D.new()
var signs = ImmediateMesh.new()
var signs_node = MeshInstance3D.new()
var guide = false
var selected_player = 4
var current: Dictionary = {}
var actors: Array = []
var redraw_elapsed = 0.0
# Source lengths scaled by TOP/original character scale: 0.55 / 1.25.
const PLAYER_DISTANCE := 9.68
const PLAYER_MIN_DISTANCE := 0.044
const PLAYER_MAX_DISTANCE := 13.2
const PLAYER_PIVOT_HEIGHT := 1.54
const PLAYER_PITCH := PI / 18.0
const CAMERA_FLOOR_LAYER := 1 << 19
var twist_pivot: Node3D
var pitch_pivot: Node3D
var spring_arm: SpringArm3D
var camera_floor: StaticBody3D
var player_view: Dictionary = {}
var camera_size = PLAYER_DISTANCE
var overhead = false
var camera_yaw = 0.0
var camera_pitch = PLAYER_PITCH
var follow_player = true
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
var observed_state:Dictionary={}
var status_labels:Array=[]
var world_icons:Array=[]
var world_textures:Dictionary={}
var debuff_icons:Array=[]
var waymarks:Node3D
var waymark_signature:=""
var target_signs:Array=[]
var mechanic_signs:Array=[]
var secondary_mechanic_signs:Array=[]
var sigma_capacity_labels:Array=[]
var omega_source_loading:Dictionary={}
var death_wall:Node3D

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
	camera.fov = 75; camera.near = 0.022; camera.far = 5000; camera.current = true
	twist_pivot = Node3D.new(); twist_pivot.name = "TwistPivot"; add_child(twist_pivot)
	pitch_pivot = Node3D.new(); pitch_pivot.name = "PitchPivot"; twist_pivot.add_child(pitch_pivot)
	spring_arm = SpringArm3D.new(); spring_arm.name = "SpringArm3D"; pitch_pivot.add_child(spring_arm)
	# Explicit sweep protects the near plane, including at vertical pitch.
	var probe := SphereShape3D.new(); probe.radius = 0.04
	spring_arm.shape = probe; spring_arm.margin = 0.025
	spring_arm.collision_mask = CAMERA_FLOOR_LAYER
	spring_arm.add_child(camera)
	camera_floor = StaticBody3D.new(); camera_floor.name = "CameraOnlyFloor"
	camera_floor.collision_layer = CAMERA_FLOOR_LAYER; camera_floor.collision_mask = 0
	var floor_shape := CollisionShape3D.new(); floor_shape.shape = WorldBoundaryShape3D.new()
	camera_floor.add_child(floor_shape); add_child(camera_floor)
	camera.position.z = camera_size
	update_camera()
	waymarks=Node3D.new();waymarks.name="Waymarks";add_child(waymarks)
	set_waymarks(Markers.default_layout())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): encounter_id = arg.trim_prefix("--scenario=")
	set_encounter(encounter_id)
	var shader = Shader.new(); shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; varying vec3 plane_position; void vertex(){ plane_position = VERTEX; } void fragment(){ if(length(plane_position.xz) > 20.05) discard; ALBEDO = COLOR.rgb; ALPHA = COLOR.a; }"
	var material = ShaderMaterial.new(); material.shader = shader
	aoe_node.mesh = aoe; aoe_node.material_override = material; add_child(aoe_node)
	signs_node.mesh = signs; signs_node.material_override = material; add_child(signs_node)
	var icon_sources:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/status_icons.json"))
	for source_row in icon_sources.rows:
		var icon_id:int=int(source_row.fields.Icon.id)
		var texture:=original_icon(icon_id)
		if texture!=null:world_textures[icon_id]=texture
	for id in Markers.ICONS:
		var texture:=original_icon(int(id))
		if texture!=null:world_textures[int(id)]=texture
	for i in 8:
		var root = Node3D.new(); add_child(root)
		var body = Visuals.humanoid(i); root.add_child(body); actor_models.append(body)
		var label = Label3D.new(); label.font = UI_FONT; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.font_size = 34; label.pixel_size = 0.028; label.outline_size = 8; label.position.y = 2.3; label.no_depth_test = true; root.add_child(label)
		var arrow = Node3D.new(); root.add_child(arrow)
		arrow.add_child(FacingRing.create(0.8,Color("8fb6d7")))
		var effects:=Label3D.new(); effects.font = UI_FONT;effects.billboard=BaseMaterial3D.BILLBOARD_ENABLED;effects.font_size=29;effects.pixel_size=0.026;effects.outline_size=8;effects.position.y=3.1;effects.no_depth_test=true;root.add_child(effects);status_labels.append(effects)
		var icon:=Sprite3D.new();icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED;icon.no_depth_test=true;icon.pixel_size=0.034;icon.position.y=4.5;icon.visible=false;root.add_child(icon);world_icons.append(icon)
		var badges:Array=[]
		for slot in 3:
			var badge:=Sprite3D.new();badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED;badge.no_depth_test=true;badge.position=Vector3((slot-1)*1.15,4.0,0);badge.visible=false;root.add_child(badge);badges.append(badge)
		debuff_icons.append(badges)
		var sign:=Sprite3D.new();sign.name="ManualTargetSign";sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.no_depth_test=true;sign.visible=false;sign.position.y=5.0;root.add_child(sign)
		var fallback:=Label3D.new(); fallback.font = UI_FONT;fallback.name="Fallback";fallback.billboard=BaseMaterial3D.BILLBOARD_ENABLED;fallback.font_size=42;fallback.pixel_size=0.02;fallback.outline_size=8;sign.add_child(fallback)
		target_signs.append(sign)
		var mechanic:=Sprite3D.new();mechanic.name="MechanicSign";mechanic.billboard=BaseMaterial3D.BILLBOARD_ENABLED;mechanic.no_depth_test=true;mechanic.visible=false;mechanic.position.y=5.6;root.add_child(mechanic);mechanic_signs.append(mechanic)
		var secondary:=Sprite3D.new();secondary.name="AdditionalMechanicSign";secondary.billboard=BaseMaterial3D.BILLBOARD_ENABLED;secondary.no_depth_test=true;secondary.visible=false;root.add_child(secondary);secondary_mechanic_signs.append(secondary)
		actor_nodes.append(root); actor_labels.append(label); actor_arrows.append(arrow)

	# Six pooled source-capacity numerals; these never display assignments.
	for i in 6:
		var capacity:=Label3D.new();capacity.name="SigmaTowerCapacity%d"%i;capacity.font=UI_FONT;capacity.billboard=BaseMaterial3D.BILLBOARD_ENABLED;capacity.font_size=56;capacity.pixel_size=0.028;capacity.outline_size=10;capacity.no_depth_test=true;capacity.visible=false;add_child(capacity);sigma_capacity_labels.append(capacity)

	p3_fx_root=Node3D.new();p3_fx_root.name="P3ObservedEffects";add_child(p3_fx_root)

func mat(colour: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = 0.75; return material
func mesh_node(mesh: Mesh, position_value: Vector3, colour: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new(); n.mesh = mesh; n.position = position_value; n.material_override = mat(colour); add_child(n); return n
func update_camera() -> void:
	if not is_instance_valid(camera): return
	if selected_player >= 0 and selected_player < actors.size():
		var p := Rules.v(actors[selected_player].pos)
		follow_target = Vector3(p.x, 0.02 + float(actors[selected_player].get("height", 0.0)), p.y)
	camera_target = follow_target if follow_player and not overhead else Vector3.ZERO
	twist_pivot.position = camera_target + (Vector3.UP * PLAYER_PIVOT_HEIGHT if not overhead else Vector3.ZERO)
	twist_pivot.rotation.y = camera_yaw
	# Public pitch is elevation; native local X rotation has the opposite sign.
	pitch_pivot.rotation.x = -camera_pitch
	spring_arm.collision_mask = 0 if overhead else CAMERA_FLOOR_LAYER
	spring_arm.spring_length = camera_size
	camera.fov = 55.0 if overhead else 75.0
	camera.near = 0.1 if overhead else 0.022
	camera.size = camera_size

func zoom(amount: float) -> void:
	camera_size = clampf(camera_size + amount, 14.0 if overhead else PLAYER_MIN_DISTANCE, 80.0 if overhead else PLAYER_MAX_DISTANCE)
	update_camera()

func zoom_steps(steps: float) -> void:
	zoom(steps * (2.0 if overhead else 0.22))

func orbit(relative: Vector2) -> void:
	camera_yaw = wrapf(camera_yaw - relative.x * 0.002, -PI, PI)
	camera_pitch = clampf(camera_pitch + relative.y * 0.002, -PI / 2, PI / 2)
	update_camera()

func movement_vector(input: Vector2) -> Vector2:
	return Vector2(input.x * cos(camera_yaw) + input.y * sin(camera_yaw), -input.x * sin(camera_yaw) + input.y * cos(camera_yaw)).limit_length(1.0)

func reset_camera() -> void:
	camera_yaw = 0; camera_pitch = PLAYER_PITCH; camera_size = PLAYER_DISTANCE
	overhead = false; follow_player = true; player_view.clear(); update_camera()

func set_follow(enabled: bool) -> void:
	follow_player = enabled
	update_camera()

func set_overhead(enabled: bool) -> void:
	if enabled == overhead: return
	if enabled:
		player_view = {"yaw": camera_yaw, "pitch": camera_pitch, "distance": camera_size, "follow": follow_player}
		overhead = true; camera_yaw = 0; camera_pitch = 0.91; camera_size = 44
		follow_player = false
	else:
		overhead = false
		camera_yaw = float(player_view.get("yaw", 0.0))
		camera_pitch = float(player_view.get("pitch", PLAYER_PITCH))
		camera_size = float(player_view.get("distance", PLAYER_DISTANCE))
		follow_player = bool(player_view.get("follow", true))
	update_camera()

# Presentation only: preserve cue content, with bounded distance compensation.
func cue_scale(node: Node3D) -> float:
	if overhead: return 1.0
	return clampf(camera.global_position.distance_to(node.global_position) / 30.0, 0.35, 1.0)

func update_cue_presentation() -> void:
	for i in actor_nodes.size():
		var factor := cue_scale(actor_nodes[i])
		var height := float(actors[i].get("height", 0.0)) if i < actors.size() else 0.0
		actor_labels[i].pixel_size = 0.028 * factor
		status_labels[i].pixel_size = 0.026 * factor
		status_labels[i].position.y = (3.1 if overhead else 2.8) + height
		world_icons[i].position.y = (5.5 if overhead else 3.9) + height
		if world_icons[i].texture != null:
			world_icons[i].pixel_size = (2.0 * factor) / float(world_icons[i].texture.get_width())
		for slot in debuff_icons[i].size():
			var badge: Sprite3D = debuff_icons[i][slot]
			badge.position.x *= factor
			badge.position.y = (4.0 if overhead else 3.3) + height
			if badge.texture != null: badge.pixel_size = factor / float(badge.texture.get_width())
	for node in stage_nodes:
		node.get_node("EntityLabel").pixel_size = 0.025 * cue_scale(node)
	for boss in bosses:
		if boss.has_node("Cue"): boss.get_node("Cue").pixel_size = 0.025 * cue_scale(boss)

func set_encounter(id: String) -> void:
	encounter_id = id
	if not is_inside_tree(): return
	for boss in bosses:
		remove_child(boss); boss.queue_free()
	bosses.clear()
	last_clone_cue = ""
	if is_instance_valid(death_wall):remove_child(death_wall);death_wall.queue_free()
	death_wall=DeathWall.create(int(id.substr(1,1)));add_child(death_wall)
	if is_instance_valid(floor_node): remove_child(floor_node); floor_node.queue_free()
	floor_node = Visuals.floor_model(int(id.substr(1,1))); add_child(floor_node)
	var forms: Array = ["beetle"]
	if id.begins_with("p2_") or id.begins_with("p5_"): forms = ["male", "female"]
	elif id.begins_with("p3_") or id.begins_with("p4_"): forms = ["final"]
	elif id.begins_with("p6_"): forms = ["alpha"]
	for form in forms:
		var boss = Visuals.boss(form); add_child(boss); bosses.append(boss)
		if forms.size() == 2:
			boss.position.x = -11 if form == "male" else 11
			boss.rotation_degrees.y = -90 if form == "male" else 90
			var label = Label3D.new(); label.font = UI_FONT; label.name = "Cue"
			label.text = "OMEGA " + ("M" if form == "male" else "F")
			label.position.y = 4.8; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 28; label.pixel_size = 0.025; boss.add_child(label)
func screen_to_world(screen: Vector2) -> Vector2:
	var origin = camera.project_ray_origin(screen)
	var direction = camera.project_ray_normal(screen)
	if absf(direction.y) < 0.01: return Vector2.ZERO
	var point = origin + direction * (-origin.y / direction.y)
	return Vector2(point.x, point.z)
func update_state(new_actors: Array, beat_value: Dictionary, player: int, hints: bool, elapsed := 0.0, runtime:Dictionary={}) -> void:
	# A restored/new run can have the same clock and timeline length. Reset
	# visual-only state by dictionary identity, without mutating game state.
	if not is_same(observed_state,runtime):clear_p3_effects()
	observed_state=runtime
	if runtime.has("waymark_layout"):set_waymarks(runtime.waymark_layout)
	beat_elapsed = elapsed
	actors = new_actors; current = beat_value; selected_player = player; guide = hints
	for node in actor_nodes: node.visible = actors.size() == 8
	for sign in target_signs:sign.visible=false
	if actors.size() != 8:
		aoe.clear_surfaces(); signs.clear_surfaces(); positions_initialized = false
		clear_p3_effects()
	update_stage_entities()
	update_clone_cues()
	update_camera()
	update_sigma_capacity_labels()
	update_omega_source_cue()
func update_sigma_capacity_labels()->void:
	for label in sigma_capacity_labels:label.visible=false
	if actors.size()!=8:return
	var slot:=0
	for shape in current.get("shapes",[]):
		if not shape.get("sigma_capacity",false) or not LateDamagePreview.visible(shape,current,observed_state,beat_elapsed,guide):continue
		if slot>=sigma_capacity_labels.size():break
		var capacity:Label3D=sigma_capacity_labels[slot];var point:=Rules.v(shape.pos)
		capacity.text=str(int(shape.count));capacity.position=Vector3(point.x,3.6,point.y);capacity.modulate=Color("6be7e0") if int(shape.count)>1 else Color("ffcf70");capacity.visible=true;slot+=1
func update_omega_source_cue()->void:
	for node in omega_source_loading.values():node.visible=false
	# The current source phase begins at its existing reveal, never from
	# upcoming beats. This is a boss loading tell, not an early damage floor.
	if actors.size()!=8 or current.get("omega_phase","")!="first" or not current.has("omega_config"):return
	if observed_state.get("omega",{}).get("monitor_resolved",false):return
	var angle:=wrapf(float(current.omega_config.monitor_angle),-180.0,180.0)
	var side:=-1 if angle<0 else 1
	if not omega_source_loading.has(side):
		var loading:=P3Effects.loading(side);loading.name="OmegaObservedMonitorLoading";add_child(loading);omega_source_loading[side]=loading
	var node:Node3D=omega_source_loading[side];var axis:=Rules.direction(angle)
	# Reconstructed display attachment: keep the original loading geometry outside
	# the large caster silhouette. This is not a recovered official bone/socket.
	var display_offset:=float(EnemyRings.profile("final").get("radius",12.502))+0.75
	node.position=Vector3(axis.x*display_offset,5.0,axis.y*display_offset);node.rotation_degrees.y=-angle;node.scale=Vector3.ONE*1.2;node.visible=true
func _process(delta: float) -> void:
	animation_time += delta
	update_camera()
	if actors.size() != 8: return
	for i in 8:
		var p = Rules.v(actors[i].pos)
		var next_position = Vector3(p.x, 0.02, p.y)
		var velocity = (next_position - actor_nodes[i].position) / maxf(delta, 0.001) if positions_initialized else Vector3.ZERO
		actor_nodes[i].position = next_position
		actor_models[i].position.y = float(actors[i].get("height", 0.0))
		actor_labels[i].position.y = 2.3 + float(actors[i].get("height", 0.0))
		Visuals.animate(actor_models[i], animation_time + i * 0.5, velocity.length())
		actor_models[i].rotation.y = -deg_to_rad(float(actors[i].face))
		actor_arrows[i].rotation_degrees.y = -float(actors[i].face)
		FacingRing.tint(actor_arrows[i].get_child(0),Color("fff3b2") if i==selected_player else Color("8fb6d7"))
		actor_labels[i].text = ("YOU / " if i == selected_player else "") + actors[i].role + (("\n" + str(current.get("labels", ["", "", "", "", "", "", "", ""])[i])) if guide else "")
		actor_labels[i].modulate = Color("fff3b2") if i == selected_player else Color("c5d8ee")
		var marker:=Markers.marker_for(observed_state,i)
		var target_sign:Sprite3D=target_signs[i];var target_icon:=Markers.icon_id(marker)
		target_sign.visible=marker!="";target_sign.texture=world_textures.get(target_icon)
		var fallback:Label3D=target_sign.get_node("Fallback");fallback.text=Markers.title(marker) if target_sign.texture==null else ""
		target_sign.position.y=(6.7 if overhead else 4.8)+float(actors[i].get("height",0.0))
		if target_sign.texture!=null:target_sign.pixel_size=(1.45*cue_scale(actor_nodes[i]))/float(target_sign.texture.get_width())
		var observed_signs:=SynergySigns.observed_all(i,current,observed_state)
		var symbol:=str(observed_signs[0]) if not observed_signs.is_empty() else ""
		var mechanic:Sprite3D=mechanic_signs[i];mechanic.visible=not symbol.is_empty();mechanic.texture=SynergySigns.texture(symbol)
		mechanic.position.y=(6.0 if overhead else 5.6)+float(actors[i].get("height",0.0))
		if mechanic.texture!=null:mechanic.pixel_size=2.0*cue_scale(actor_nodes[i])/float(mechanic.texture.get_width())
		var secondary:Sprite3D=secondary_mechanic_signs[i];secondary.visible=observed_signs.size()>1;secondary.texture=SynergySigns.texture(str(observed_signs[1])) if secondary.visible else null
		secondary.position.y=mechanic.position.y+1.4*cue_scale(actor_nodes[i])
		if secondary.texture!=null:secondary.pixel_size=1.7*cue_scale(actor_nodes[i])/float(secondary.texture.get_width())
		var cue:=observed_cue(i)
		status_labels[i].text=cue.text;status_labels[i].modulate=cue.colour;status_labels[i].position.y=3.1+float(actors[i].get("height",0.0))
		var icon_id:=int(cue.icon)
		world_icons[i].visible=world_textures.has(icon_id)
		if world_icons[i].visible:world_icons[i].texture=world_textures[icon_id]
		world_icons[i].position.y=5.5+float(actors[i].get("height",0.0))
		for slot in 3:
			var badge:Sprite3D=debuff_icons[i][slot]
			var effect_id:int=int(cue.badges[slot].icon) if slot<cue.badges.size() else 0
			badge.visible=world_textures.has(effect_id)
			if badge.visible:
				badge.texture=world_textures[effect_id];badge.pixel_size=1.0/float(badge.texture.get_width())
			badge.position=Vector3((slot-(cue.badges.size()-1)*0.5)*1.15,4.0+float(actors[i].get("height",0.0)),0)
	update_waymark_presentation()
	update_p3_effects(delta)
	update_cue_presentation()
	positions_initialized = true
	redraw_elapsed += delta
	if redraw_elapsed < 0.07: return
	redraw_elapsed = 0
	draw_indicators()
func vertex(p: Vector2, colour: Color, height := 0.08) -> void:
	if aoe_vertex_count==0:aoe.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	aoe_vertex_count+=1
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
	aoe.clear_surfaces(); aoe_vertex_count=0
	visible_damage_shapes=LateDamagePreview.shapes(current,observed_state,beat_elapsed,guide,upcoming_beats,actors)
	for shape in visible_damage_shapes:
		var source_tell := LateDamagePreview.is_telegraph(shape) and not LateDamagePreview.in_window(float(shape.damage_at)-float(observed_state.get("sim_time",0)))
		draw_shape(shape,Color(1.0,0.68,0.12,0.26) if source_tell else Color.TRANSPARENT)
	for impact in observed_state.get("visual_impacts",[]):
		var age:=float(observed_state.get("sim_time",0))-float(impact.at)
		if age>=0 and age<0.35:
			for shape in impact.shapes:draw_shape(shape,Color(1.0,0.45,0.2,0.55*(1.0-age/0.35)))
	if guide and LateDamagePreview.in_window(float(current.get("duration",0))-beat_elapsed):
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
		rectangle(p, (q - p).normalized(), 0, p.distance_to(q), 0.12, Color("79e49c") if tether.get("kind","")=="local" else Color("8edbff"))
	if current.has("world"):
		if LateDamagePreview.in_window(float(current.get("duration",0))-beat_elapsed):
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
	if aoe_vertex_count>0:aoe.surface_end()
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
		sign_line(p, q, Color("79e49c") if tether.get("kind","")=="local" else Color("8edbff"))
		sign_ring(p + Vector3(0, 0.65, 0), 0.42, Color("ffcc76"))
		sign_line(p + Vector3(0, 0.7, 0), p + Vector3(0, 1.25, 0), Color("ffcc76"))
	for shape in current.get("shapes", []):
		if current.get("hide_predictive_aoes",false) and not guide:continue
		var p2 = Rules.point(shape, actors)
		var p = Vector3(p2.x, 0, p2.y)
		var kind = shape.get("kind", "")
		if kind == "tower":
			var radius = float(shape.get("radius", 3))
			# HW colour is a visible source cue, independent from damage previews.
			var c = Color("ff6b78") if shape.get("colour", "")=="red" else (Color("68aaff") if shape.get("colour", "")=="blue" else Color("ffcf70"))
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
		boss.get_node("Cue").text = "Omega M" if i == 0 else "Omega F"
		# P5's combined sector drill does not supply genuine clone spawn locations.
		# Keep its display pair on the north rim so these do not imply AoE origins.
		if encounter_id.begins_with("p5_"):
			if current.has("clone_pattern"):
				var pattern: Dictionary = current.clone_pattern
				var rotation := float(pattern.orientation) + (90.0 if pattern.second else 0.0)
				var source := Vector2(-8 if i == 0 else 8,0).rotated(deg_to_rad(rotation))
				boss.position = Vector3(source.x,0,source.y)
				boss.rotation_degrees.y = (-90 if i == 0 else 90)-rotation
			else: boss.position = Vector3(-5 if i == 0 else 5,0,-15)
			boss.visible = not active.is_empty()

func update_stage_entities() -> void:
	var entities:Array=current.get("stage_entities",[]).duplicate(true)
	for transition in current.get("entity_transitions",[]):
		if beat_elapsed>=float(transition.at):
			for entity in entities:
				if str(entity.get("id",""))==str(transition.id):entity.merge(transition,true)
	var keys:Array=[]
	for i in entities.size():keys.append([str(entities[i].get("id",i)),str(entities[i].form)])
	var signature:=JSON.stringify(keys)
	if signature!=stage_signature:
		for node in stage_nodes:remove_child(node);node.queue_free()
		stage_nodes=[];stage_signature=signature
		for entity in entities:
			var node:Node3D=Visuals.boss(entity.form);add_child(node);stage_nodes.append(node)
			var label:=Label3D.new(); label.font = UI_FONT;label.name="EntityLabel";label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position.y=4.8;label.font_size=28;label.pixel_size=0.025;node.add_child(label)
	for i in stage_nodes.size():
		var node:Node3D=stage_nodes[i];var entity:Dictionary=entities[i]
		var p:Vector2=Rules.v(entity.pos);node.position=Vector3(p.x,float(entity.get("height",0)),p.y)
		EnemyRings.configure(node, entity)
		var stance:String=entity.get("stance","")
		if node.get_meta("last_stance","__unset__")!=stance:
			Visuals.Official.set_stance(node,stance);node.set_meta("last_stance",stance)
			for option in ["SWORD","SHIELD","LEGS","STAFF"]:
				if node.has_node(option):node.get_node(option).visible=option==stance
		var display_names:Dictionary={"beetle":"Omega","male":"Omega M","female":"Omega F","male_p5":"Omega M","female_p5":"Omega F","final":"Omega Reconfigured","alpha":"Alpha Omega","fist_b5":"拳 A","fist_b6":"拳 B","arm_left":"","arm_right":"","rear_unit":"Rear Power Unit","optical_unit":"Optical Unit"}
		node.get_node("EntityLabel").text=("↻" if float(entity.turn)>0 else "↺") if entity.has("turn") else str(entity.get("label",display_names.get(entity.form,entity.form)))
		node.visible=actors.size()==8 and stance!="RESOLVED" and bool(entity.get("visible",true)) and beat_elapsed+0.000001>=float(entity.get("spawn_delay",0))
	for node in bosses:node.visible=not bool(current.get("hide_main_boss",false))
	if bosses.size() == 1:
		var face := float(current.get("boss_facing", current.get("p1_route", {}).get("boss_facing", 0.0)))
		EnemyRings.configure(bosses[0], {"facing":face})

func original_icon(id:int)->Texture2D:
	var path:="res://assets/official/icons/%d.png"%id
	if (not FileAccess.file_exists(path) or FileAccess.file_exists(path+".import")) and ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var pixels:=Image.load_from_file(path)
		if pixels!=null and not pixels.is_empty():return ImageTexture.create_from_image(pixels)
	return null

func observed_cue(actor:int)->Dictionary:
	var result:Dictionary={"text":"","colour":Color("fff3b2"),"icon":0,"badges":[]}
	if observed_state.is_empty():return result
	if observed_state.get("dead",[]).any(func(a):return int(a)==actor):
		result.text="×";result.colour=Color("ff6e84");return result
	var buffs:Dictionary=observed_state.get("statuses",[{}, {}, {}, {}, {}, {}, {}, {}])[actor]
	var now:=float(observed_state.get("sim_time",0))
	for spec in [["red",215917,"紅"],["blue",215131,"藍"],["overflow",215916,"大圈"],["sync",215915,"分攤"],["latent_red",215922,"待紅"],["latent_blue",215134,"待藍"]]:
		add_status_badge(result,buffs,str(spec[0]),int(spec[1]),str(spec[2]),now)
	for tether in observed_state.get("paired_tethers",[]):
		if not tether.broken and now>=float(tether.active_at) and actor in [int(tether.a),int(tether.b)] and result.badges.size()<3:
			result.badges.append({"icon":215923 if tether.kind=="local" else 215924,"label":"近線" if tether.kind=="local" else "遠線","remaining":float(tether.expires)-now})
	var first_smell:=""
	for key in ["local_code_smell","remote_code_smell"]:
		if buffs.has(key) and float(buffs[key].expires)>now and (first_smell=="" or float(buffs[key].expires)<float(buffs[first_smell].expires)):first_smell=key
	if first_smell!="":add_status_badge(result,buffs,first_smell,215139 if first_smell=="local_code_smell" else 215140,"近" if first_smell=="local_code_smell" else "遠",now)
	for spec in [["smell_red","紅氣味"],["smell_blue","藍氣味"],["smell_overflow","大圈氣味"],["smell_sync","分攤氣味"]]:add_status_badge(result,buffs,str(spec[0]),0,str(spec[1]),now)
	var titles:PackedStringArray=[]
	for badge in result.badges:titles.append(("" if world_textures.has(int(badge.icon)) else str(badge.label))+"%.0f"%ceilf(maxf(0.0,float(badge.remaining))))
	for key in ["delta_near_world","omega_near_world"]:
		if buffs.has(key) and float(buffs[key].expires)>now:result.icon=215141
	for key in ["delta_distant_world","omega_distant_world"]:
		if buffs.has(key) and float(buffs[key].expires)>now:result.icon=215142
	if current.has("world"):
		if actor==int(current.world.near):result.icon=215141
		elif actor==int(current.world.far):result.icon=215142

	if int(result.icon)!=0 and not world_textures.has(int(result.icon)):titles.append("近世界" if result.icon==215141 else "遠世界")
	for item in current.get("party_statuses",[]):
		if int(item.actor)==actor and item.get("marker",false) and not item.has("symbol"): titles.append(str(item.name))
	result.text="  ".join(titles)
	return result

func add_status_badge(result:Dictionary,buffs:Dictionary,key:String,icon_id:int,title:String,now:float)->void:
	if result.badges.size()>=3 or not buffs.has(key) or float(buffs[key].expires)<=now:return
	result.badges.append({"icon":icon_id,"label":title,"remaining":float(buffs[key].expires)-now})

func set_waymarks(layout:Dictionary)->void:
	var signature:=JSON.stringify(layout)
	if signature==waymark_signature or not is_instance_valid(waymarks):return
	var checked:=Markers.validate_layout(layout)
	if not checked.ok:return
	waymark_signature=signature
	for node in waymarks.get_children():waymarks.remove_child(node);node.queue_free()
	for mark in checked.layout.marks:
		if not mark.enabled:continue
		var index:=Markers.WAYMARK_IDS.find(str(mark.id));var colour:=Color(Markers.COLOURS[index])
		var anchor:=Node3D.new();anchor.name="Waymark"+str(mark.id);anchor.position=Vector3(float(mark.pos[0]),0.06,float(mark.pos[1]));waymarks.add_child(anchor)
		Visuals.ring(anchor,Vector3.ZERO,0.8,0.035,colour)
		var path:="res://assets/official/markers/"+str(Markers.GLYPHS[index])+".png"
		var texture:Texture2D
		if ResourceLoader.exists(path):texture=load(path) as Texture2D
		elif FileAccess.file_exists(path):texture=ImageTexture.create_from_image(Image.load_from_file(path))
		if texture!=null:
			var glyph:=Sprite3D.new();glyph.name="OriginalGlyph";glyph.texture=texture;glyph.billboard=BaseMaterial3D.BILLBOARD_ENABLED;glyph.pixel_size=0.008;glyph.position.y=1.02;anchor.add_child(glyph)
		else:
			var text:=Label3D.new(); text.font = UI_FONT;text.text=str(mark.id);text.font_size=80;text.pixel_size=0.025;text.modulate=colour;text.position.y=0.03;text.rotation_degrees.x=-90;anchor.add_child(text)

func clear_p3_effects()->void:
	if is_instance_valid(p3_fx_root):
		for child in p3_fx_root.get_children():p3_fx_root.remove_child(child);child.queue_free()
	p3_loading=[];p3_pulses=[];p3_signature="";p3_event_cursor=0;p3_last_time=-1.0;p3_resolved=false
func update_p3_effects(delta:float)->void:
	if not is_instance_valid(p3_fx_root):return
	p3_clock+=delta
	if encounter_id!="p3_monitors" or actors.size()!=8:
		if p3_loading.size()+p3_pulses.size()>0:clear_p3_effects()
		return
	var now:=float(observed_state.get("sim_time",0))
	if now<p3_last_time-0.001:clear_p3_effects()
	p3_last_time=now
	var timeline:Array=observed_state.get("timeline",[])
	if p3_event_cursor>timeline.size():clear_p3_effects()
	for entry in timeline.slice(p3_event_cursor):
		if str(entry.get("kind",""))!="monitor_resolution":continue
		p3_resolved=true
		for source in entry.get("sources",[]):
			for j in source.get("target_positions",[]).size():
				var effect:=P3Effects.pulse(Rules.v(source.origin),Rules.v(source.target_positions[j]),int(source.source_actor))
				effect.set_meta("born",p3_clock);p3_fx_root.add_child(effect);p3_pulses.append(effect)
	p3_event_cursor=timeline.size()
	var sources:Array=current.get("monitors",[])
	var signature:=JSON.stringify(sources.map(func(source):return [source.get("actor",-1),source.get("offset",source.get("angle",0))]))
	if signature!=p3_signature:
		for node in p3_loading:p3_fx_root.remove_child(node);node.queue_free()
		p3_loading=[];p3_signature=signature
		for source in sources:
			var angle:float=float(source.get("offset",wrapf(float(source.get("angle",0)),-180,180)))
			var node:=P3Effects.loading(-1 if angle<0 else 1);p3_fx_root.add_child(node);p3_loading.append(node)
	for i in sources.size():
		var source:Dictionary=sources[i];var point:=Rules.point(source,actors);var axis:=Rules.aim(source,actors);var actor:=int(source.get("actor",-1))
		var node:Node3D=p3_loading[i];node.visible=not p3_resolved and actor not in observed_state.get("dead",[])
		node.position=Vector3(point.x,3.0 if actor<0 else 1.4+float(actors[actor].get("height",0)),point.y)+Vector3(axis.x,0,axis.y)*0.35
		node.rotation_degrees.y=-rad_to_deg(atan2(axis.x,-axis.y));node.scale=Vector3.ONE*(1.2 if actor<0 else 0.65)
	for node in p3_pulses.duplicate():
		if not P3Effects.envelope(node,p3_clock-float(node.get_meta("born"))):
			p3_pulses.erase(node);p3_fx_root.remove_child(node);node.queue_free()

func update_waymark_presentation()->void:
	if not is_instance_valid(waymarks) or not is_instance_valid(camera):return
	for anchor in waymarks.get_children():
		for glyph in anchor.get_children():
			if glyph is Sprite3D:
				var distance:float=camera.global_position.distance_to(glyph.global_position)
				glyph.modulate=Color(1,1,1,clampf((distance-2.7)/2.0,0,1)*0.85)
