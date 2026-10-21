# SPDX-License-Identifier: MIT
extends RefCounted
## Encounter -> timed beats -> bot goals and independent snapshot rules.
## Distances are yard-like training units; windows are intentionally slowed.
const Params = preload("res://scripts/statuses.gd")
const Rules = preload("res://scripts/rules.gd")
const Clones = preload("res://scripts/clone_patterns.gd")
const Routes = preload("res://scripts/strategy_routes.gd")
const P6Courses = preload("res://scripts/p6_courses.gd")
const P1Courses = preload("res://scripts/p1_courses.gd")
const DeltaCourses = preload("res://scripts/p5_delta_courses.gd")
const OmegaCourses = preload("res://scripts/p5_omega_courses.gd")
const SigmaCourses = preload("res://scripts/p5_sigma_courses.gd")
const HWCourses = preload("res://scripts/hw_courses.gd")
const LimitlessCourses = preload("res://scripts/p2_limitless_courses.gd")
const ROLES = ["MT", "ST", "H1", "H2", "D1", "D2", "D3", "D4"]
var rng = RandomNumberGenerator.new()
var order: Array = []
var priority: Array = []
var beats: Array = []
var labels: Array = []
var positions: Array = []
var profile: Dictionary
var angle = 0.0
var mechanic_id := ""

func build(id: String, seed_value: int, strategy: Dictionary, player := 4, slot := -1) -> Dictionary:
	mechanic_id = id
	rng.seed = seed_value
	profile = Routes.apply(strategy,id)
	priority = []
	for role in profile.priority: priority.append(ROLES.find(role))
	order = range(8)
	for i in range(7, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	if slot >= 0:
		var old = order.find(player)
		var tmp = order[slot]; order[slot] = player; order[old] = tmp
	beats = []; labels = []; positions = []
	for i in 8:
		labels.append("")
		positions.append(Rules.direction(i * 45) * 5)
	angle = float(rng.randi_range(0, 7) * 45)
	match id:
		"p1_loop": P1Courses.append_loop(self)
		"p1_panto": P1Courses.append_panto(self)
		"p1_cannons": P1Courses.append_cannons(self)
		"p2_synergy": party_synergy()
		"p2_limitless": limitless()
		"p3_transition": transition()
		"p3_hello": hello_world()
		"p3_monitors": monitors()
		"p4_wave": p4_wave()
		"p5_delta": DeltaCourses.append_delta(self)
		"p5_sigma": SigmaCourses.append_sigma(self)
		"p5_omega": OmegaCourses.append_omega(self)
		"p5_dynamis": dynamis_course()
		"p5_full": solar_ray(); DeltaCourses.append_delta(self); solar_ray(); SigmaCourses.append_sigma(self); solar_ray(); OmegaCourses.append_omega(self); solar_ray()
		"p5_solar": solar_ray()
		"p6_memory": memory()
		"p6_arrow_dive": P6Courses.append_arrow(self,false)
		"p6_exa_wave": P6Courses.append_exaflares(self,false)
		"p6_arrow_wave": P6Courses.append_arrow(self,true)
		"p6_exa_dive": P6Courses.append_exaflares(self,true)
		"p6_meteors": meteors()
		"p6_magic": magic_number()
	return {"id": id, "seed": seed_value, "beats": beats, "assignments": order.duplicate(), "profile": strategy.id, "initial_dynamis": initial_stacks(id)}

func initial_stacks(id: String) -> Array:
	var result: Array = []; result.resize(8); result.fill(0)
	if id=="p5_sigma":
		for i in 8:result[at(i)]=1 if i<6 else 0
	if id == "p5_omega":
		for i in 8: result[at(i)] = 2 if i < 4 else 1
	if id.begins_with("p6_"): result.fill(3)
	return result

func at(slot: int) -> int: return int(order[slot])
func pos(slot: int, p: Vector2) -> void: positions[at(slot)] = p
func label(slot: int, text: String) -> void: labels[at(slot)] = text
func polar(degrees: float, radius: float) -> Vector2: return Rules.direction(degrees) * radius
func rotated(p: Vector2, degrees: float) -> Vector2: return p.rotated(deg_to_rad(degrees))
func ranked(values: Array) -> Array:
	var result = values.duplicate()
	result.sort_custom(func(a, b): return priority.find(a) < priority.find(b))
	return result
func beat(title: String, duration := 6.0, note := "") -> Dictionary:
	var item = {"title": title, "duration": duration, "note": note, "positions": positions.duplicate(), "labels": labels.duplicate(), "shapes": [], "checks": [], "facing": {}}
	beats.append(item)
	return item
func circle(p: Vector2, radius: float, name: String) -> Dictionary: return {"kind": "circle", "pos": p, "radius": radius, "name": name}
func targeted(actor: int, radius: float, count: int, name: String) -> Dictionary: return {"kind": "stack" if count > 1 else "spread", "actor": actor, "radius": radius, "rule": "count", "count": count, "name": name}
func tower(p: Vector2, radius: float, members: Array, name: String) -> Dictionary: return {"kind": "tower", "pos": p, "radius": radius, "rule": "count", "count": members.size(), "required": members, "name": name}
func line(p: Vector2, degrees: float, width: float, name: String) -> Dictionary: return {"kind": "line", "pos": p, "angle": degrees, "width": width, "start": -40, "length": 80, "name": name}
func pair(a: int, b: int, minimum: float, maximum: float, name: String) -> Dictionary: return {"kind": "distance", "a": a, "b": b, "min": minimum, "max": maximum, "name": name}
func spread(item: Dictionary, actors: Array, radius := 3.0) -> void:
	for actor in actors: item.shapes.append(targeted(actor, radius, 1, "Spread"))
func group_goals(members: Array, p: Vector2, spacing := 0.55) -> void:
	for i in members.size(): positions[int(members[i])] = p + Vector2((i % 2) * spacing, (i / 2) * spacing)

func group_pair(values: Array) -> Array:
	if profile.id != "aether" and not (profile.id == "lpdu" and mechanic_id == "p1_panto"): return ranked(values)
	var g1 := [0, 2, 4, 6]
	var first: int = values[0]; var second: int = values[1]
	if (first in g1) != (second in g1): return [first, second] if first in g1 else [second, first]
	var flex_priority := [0, 1, 4, 5, 6, 7, 2, 3]
	var flex: int = first if flex_priority.find(first) < flex_priority.find(second) else second
	var stays: int = second if flex == first else first
	return [stays, flex] if first in g1 else [flex, stays]

func tower_pair(values: Array) -> Array:
	var result := values.duplicate()
	if profile.id == "aether":
		result.sort_custom(func(a, b): return fposmod(315 - rad_to_deg(atan2(a.x, -a.y)), 360) < fposmod(315 - rad_to_deg(atan2(b.x, -b.y)), 360))
	else:
		result.sort_custom(func(a, b): return fposmod(rad_to_deg(atan2(a.x, -a.y)) - float(profile.get("loop_start_angle", 315)), 360) < fposmod(rad_to_deg(atan2(b.x, -b.y)) - float(profile.get("loop_start_angle", 315)), 360))
	return result

func shuffled(values: Array) -> Array:
	var result: Array = values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp = result[i]; result[i] = result[j]; result[j] = temp
	return result

func program_loop() -> void:
	# Each wave chooses two of four right-angle slots in one +/-3 offset family.
	# Actual FFLogs slots are (+/-3,+/-12)/(+/-12,+/-3), not an octagonal ring.
	# Consecutive identical pairs are present in independent EU/CN clears.
	var pattern: Array = []
	for _turn in 4:
		var offset := 3.0 if rng.randi_range(0,1) else -3.0
		var first := rng.randi_range(0,3)
		var second := posmod(first+rng.randi_range(1,3),4)
		pattern.append([Vector2(offset,-12).rotated(first*PI/2),Vector2(offset,-12).rotated(second*PI/2)])
	for i in 8: label(i, "In Line %d" % (i / 2 + 1))
	for turn in 4:
		var targets = tower_pair(pattern[turn])
		var soakers = group_pair([at(turn * 2), at(turn * 2 + 1)])
		var tether_group = (turn + 2) % 4
		var tethers = group_pair([at(tether_group * 2), at(tether_group * 2 + 1)])
		var free: Array = []
		for i in [0,2,4,6]:
			if polar(i * 45, 17).distance_to(targets[0]) > 15.5 and polar(i * 45, 17).distance_to(targets[1]) > 15.5: free.append(polar(i * 45, 17))
		var best_a: Vector2 = free[0]; var best_b: Vector2 = free[-1]; var largest = 0.0
		for a in free:
			for b in free:
				if a.distance_to(b) > largest: largest = a.distance_to(b); best_a = a; best_b = b
		var tether_spots: Array = tower_pair([best_a, best_b])
		best_a = tether_spots[0]; best_b = tether_spots[1]
		for i in 8:
			var refuge = targets[i % 2] * 0.68
			if refuge.distance_to(best_a) < 15.5 or refuge.distance_to(best_b) < 15.5: refuge = targets[1 - i % 2] * 0.68
			if refuge.distance_to(best_a) < 15.5 or refuge.distance_to(best_b) < 15.5:
				var best_score := -INF
				for x in range(-18, 19):
					for y in range(-18, 19):
						var candidate := Vector2(x, y)
						if candidate.length() >= 19 or candidate.distance_to(targets[0]) < 3.5 or candidate.distance_to(targets[1]) < 3.5: continue
						var score := minf(candidate.distance_to(best_a), candidate.distance_to(best_b))
						if score > best_score: best_score = score; refuge = candidate
			positions[i] = refuge
		for i in 2:
			positions[soakers[i]] = targets[i]
			positions[tethers[i]] = best_a if i == 0 else best_b
		var item = beat("Program Loop %d/4 · towers %d / tethers %d" % [turn + 1, turn + 1, tether_group + 1], float(Params.parameter("loop_first_snapshot" if turn==0 else "loop_snapshot_interval")), "線可以被接走。塔消除 Looper；Blaster 打當下持線者。塔 1234／推薦接線 3412，重複受擊會累積 Twice-come Ruin。")
		var numbers: Array = []; numbers.resize(8)
		for n in 8: numbers[at(n)] = n / 2 + 1
		item.program_loop = {"round": turn + 1, "numbers": numbers, "holders": [], "pickup_radius": float(Params.parameter("pickup_radius"))}
		var initial: Array = order.slice(0, 2)
		if turn == 0:
			initial = shuffled(range(8)).slice(0, 2)
		item.transfers = {"group": "loop", "sources": [Vector2.ZERO, Vector2.ZERO], "initial": initial, "wanted": tethers.duplicate(), "holders": []}
		if turn == 0:
			item.spawn = []
			for actor in 8: item.spawn.append(Vector2(-3.5 + actor, 6.0))
		for i in 2:
			var storage = tower(targets[i], 3.0, [soakers[i]], "Storage Violation")
			storage.erase("required"); storage.looper_tower = true
			item.shapes.append(storage)
			item.shapes.append({"kind": "circle", "actor": initial[i], "tether_index": i, "radius": 15.0, "rule": "blaster", "name": "Blaster"})
		item.tethers = [{"a": tethers[0], "b": -1}, {"a": tethers[1], "b": -1}]

func pantokrator() -> void:
	var clockwise = 1 if rng.randi_range(0, 1) else -1
	for i in 8:
		var pairing := group_pair([at((i / 2) * 2), at((i / 2) * 2 + 1)])
		label(i, "Missile %d · G%d" % [i / 2 + 1, pairing.find(at(i)) + 1])
	for turn in 4:
		for step in 3:
			var theta = float(profile.get("panto_reference_angle",315.0)) + clockwise * (turn * 54 + step * 18)
			for i in 8:
				var pairing: Array = group_pair([at((i / 2) * 2), at((i / 2) * 2 + 1)])
				var group_angle = theta + pairing.find(at(i)) * 180
				pos(i, polar(group_angle, 10))
				if i / 2 == turn: pos(i, polar(group_angle + clockwise * 38, 12))
			var item = beat("Pantokrator · %s · missile %d (%d/3)" % ["CW" if clockwise == 1 else "CCW", turn + 1, step + 1], 3.2, "Missile goes ahead; other three share the wave. Keep rotating away from puddles.")
			for g in 2:
				var missile: int = group_pair([at(turn * 2), at(turn * 2 + 1)])[g]
				item.shapes.append(targeted(missile, 5.5, 1, "Guided Missile Kyrios"))
				var stacker: int = group_pair([at(((turn + 1) % 4) * 2), at(((turn + 1) % 4) * 2 + 1)])[g]
				var wave = {"kind": "line", "pos": Vector2.ZERO, "target": stacker, "width": 3.5, "length": 35, "rule": "count", "count": 3, "name": "Condensed Wave Cannon (3)"}
				item.shapes.append(wave)
				item.shapes.append(circle(polar(theta + g * 180 - clockwise * 28, 10), 4.0, "Ballistic Missile (previous bait)"))
				item.shapes.append({"kind": "cone", "angle": theta + g * 180 - clockwise * 68, "width": 60, "radius": 30, "name": "Flamethrower"})

func p1_cannons() -> void:
	var party = [2, 3, 4, 5, 6, 7]
	for turn in 2:
		positions[0] = Vector2(-5, -12); positions[1] = Vector2(5, -12)
		var marked = party.slice(turn * 3, turn * 3 + 3)
		var idle: Array = []
		for i in party:
			if i not in marked: idle.append(i)
		for j in 3:
			positions[marked[j]] = polar(110 + j * 70, 12)
			positions[idle[j]] = polar([140, 155, 215][j], 8)
		var item = beat("Diffuse Wave Cannon Kyrios + proteans %d/2" % (turn + 1), 6.0, "Tanks bait the two furthest cleaves. Marked non-tanks spread E/S/W.")
		for i in [0, 1]: item.shapes.append({"kind": "cone", "pos": Vector2.ZERO, "dynamic_actor": {"selector": "furthest", "ordinal": i}, "dynamic_aim": true, "width": 120, "radius": 40, "rule": "tankbuster", "name": "Tank cleave"})
		for i in marked: item.shapes.append({"kind": "line", "pos": Vector2.ZERO, "target": i, "width": 3.0, "length": 40, "rule": "count", "count": 1, "name": "Wave Cannon Kyrios"})
		item.checks.append({"kind": "furthest_tanks", "name": "Diffuse Wave Cannon"})

func party_synergy() -> void:
	var m_sword = bool(profile.get("p2_sword",rng.randi_range(0,1)));var f_legs = bool(profile.get("p2_legs",rng.randi_range(0,1)))
	var clone_angle := float(profile.get("p2_clone_angle",22.5+rng.randi_range(0,7)*45.0))
	var shapes = clone_shapes(m_sword, f_legs,clone_angle)
	var safe = find_safe(shapes)
	for i in 8: pos(i, safe)
	var dodge = beat("Party Synergy · M %s / F %s" % ["SWORD" if m_sword else "SHIELD", "LEGS" if f_legs else "STAFF"], 5.1, "M/F 克隆在半徑10的22.5°斜角相對出現；先讀武器姿態，再看眼睛。")
	dodge.shapes = shapes
	dodge.stage_entities=Clones.pair_entities(clone_angle,m_sword,f_legs);dodge.hide_main_boss=true
	dodge.spawn=[]
	for i in 8:dodge.spawn.append(Vector2((i-3.5)*0.25,0))
	var remote = bool(rng.randi_range(0, 1))
	var symbols: Array = profile.shapes
	for i in 4:
		var z = -12.0 + i * 8.0
		var x = sqrt(18.0 * 18.0 - z * z) if remote else 11.0
		pos(i * 2, rotated(Vector2(-x, z), angle))
		var other_z = -z if remote and profile.get("remote_full_cross", true) else z
		if remote and not profile.get("remote_full_cross", true): other_z = -z if i in [0, 3] else z
		pos(i * 2 + 1, rotated(Vector2(x, other_z), angle))
		label(i * 2, "%s · L · %s" % [symbols[i], "REMOTE" if remote else "MID"])
		label(i * 2 + 1, "%s · R · %s" % [symbols[i], "REMOTE" if remote else "MID"])
	var eye = beat("Optimized Fire III · %s Glitch" % ("REMOTE" if remote else "MID"),6.4,"以眼睛為北，分散火圈與搭檔距離各自判定。")
	eye.hide_main_boss=true
	spread(eye,range(8),float(Params.parameter("p2_fire_radius")))
	for shape in eye.shapes:shape.hit_status="magic_vulnerability";shape.hit_status_duration=2.0
	for i in 4:eye.checks.append(glitch_pair(at(i*2),at(i*2+1),remote,"Glitch"))
	var optical=beat("Optical Laser · after Fire III",0.35,"火圈先結算，接著眼睛雷射；不是同一個快照。")
	optical.hide_main_boss=true
	optical.shapes.append({"kind":"line","pos":polar(angle,45),"angle":angle+180,"width":float(Params.parameter("p2_optical_width")),"start":0.0,"length":100.0,"name":"Optical Laser"})
	var left: Array = []; var right: Array = []
	for i in 4: left.append(at(i * 2)); right.append(at(i * 2 + 1))
	var stacks = [at(rng.randi_range(0, 7)), at(rng.randi_range(0, 7))]
	while stacks[1] == stacks[0]: stacks[1] = at(rng.randi_range(0, 7))
	if (stacks[0] in left) == (stacks[1] in left):
		var candidates = stacks.duplicate()
		candidates.sort_custom(func(a,b): return rotated(positions[a],-angle).y < rotated(positions[b],-angle).y)
		var selected = candidates[0] if profile.stack_flex == "north" else candidates[-1]
		var symbol_index = order.find(selected) / 2
		var partner = at(symbol_index * 2 + (1 if selected in left else 0))
		left.erase(selected); right.erase(selected); left.erase(partner); right.erase(partner)
		if order.find(selected) % 2 == 0: right.append(selected); left.append(partner)
		else: left.append(selected); right.append(partner)
	var f_angle:=float(profile.get("p2_late_f_angle",rng.randi_range(0,7)*45.0))
	var lp=polar(270,4.8);var rp=polar(90 if remote else 180,4.8)
	group_goals(left,lp,0.06);group_goals(right,rp,0.06)
	var knock=beat("Discharger · prepare two safe gaps",6.8,"以新F／三男中間為北，左組向西；右組近線向南、遠線向東。擊退後仍可移動。")
	knock.knockback=13.0;knock=rotate_beat(knock,f_angle)
	var clones:Array=[{"form":"female","pos":polar(f_angle,13),"facing":f_angle+180,"stance":"SWORD"}]
	for k in 4:clones.append({"form":"male","pos":polar(f_angle+45+k*90,13),"facing":f_angle+225+k*90,"stance":"SWORD"})
	knock.stage_entities=clones;knock.hide_main_boss=true
	# Set guidance to the actual post-knockback locations, without teleporting actors.
	for i in 8:positions[i]=knock.positions[i]+knock.positions[i].normalized()*13.0
	var stacks_beat=beat("Spotlight + five clone circles · %s flex" % profile.stack_flex,4.3,"原始五個半徑10的克隆圓：F與另四個M，來源半徑13。距離與分攤在此時依實際位置結算。")
	for i in stacks:
		var share:=targeted(i,float(Params.parameter("p2_spotlight_radius")),4,"Spotlight")
		share.hit_status="magic_vulnerability";share.hit_status_duration=2.0;stacks_beat.shapes.append(share)
	for clone in clones:stacks_beat.shapes.append(circle(clone.pos,10.0,"Efficient Bladework"))
	for i in 4:stacks_beat.checks.append(glitch_pair(at(i*2),at(i*2+1),remote,"Glitch at Spotlight"))
	stacks_beat.stage_entities=clones;stacks_beat.hide_main_boss=true
	# Actual assigned markers/status, independent of left/right route labels.
	var party_effects:Array=[]
	for pair_index in 4:
		for member in [at(pair_index*2),at(pair_index*2+1)]:
			party_effects.append({"actor":member,"key":"remote_glitch" if remote else "mid_glitch","remaining":-1})
			party_effects.append({"actor":member,"key":"synergy_marker","name":str(symbols[pair_index]),"status_id":0,"icon":0,"remaining":-1,"marker":true})
	for active_beat in [eye,optical,knock,stacks_beat]: active_beat.party_statuses=party_effects.duplicate(true)

func clone_shapes(sword: bool,legs: bool,m_angle:=270.0) -> Array:
	return Clones.pair_shapes(m_angle,sword,legs)

func glitch_pair(a: int,b: int,remote: bool,name: String) -> Dictionary:
	return pair(a,b,float(Params.parameter("glitch_remote_min" if remote else "glitch_mid_min")),float(Params.parameter("glitch_remote_max" if remote else "glitch_mid_max")),name)

func find_safe(shapes: Array) -> Vector2:
	for y in range(-16, 17):
		for x in range(-16, 17):
			var p = Vector2(x, y)
			if p.length() > 17: continue
			var valid = true
			for shape in shapes:
				if Rules.contains(shape, p, []): valid = false
			if valid: return p
	return Vector2.ZERO
func rotate_beat(item: Dictionary, degrees: float) -> Dictionary:
	for i in 8: item.positions[i] = rotated(item.positions[i], degrees)
	for shape in item.shapes:
		if shape.has("pos"): shape.pos = rotated(shape.pos, degrees)
		if shape.has("angle"): shape.angle += degrees
	return item

func limitless() -> void:
	LimitlessCourses.append_limitless(self)

func transition() -> void:
	preload("res://scripts/p3_transition_courses.gd").append_transition(self)

func hello_world() -> void:
	HWCourses.append_hw(self)

func monitors() -> void:
	var saved_order: Array = order.duplicate()
	var p3_roles: Array = profile.get("p3_priority", profile.priority)
	var m_holders: Array = order.slice(0, 3)
	var non_holders: Array = order.slice(3, 8)
	m_holders.sort_custom(func(a, b): return p3_roles.find(ROLES[a]) < p3_roles.find(ROLES[b]))
	non_holders.sort_custom(func(a, b): return p3_roles.find(ROLES[a]) < p3_roles.find(ROLES[b]))
	order = m_holders + non_holders
	var sign_x = 1 if rng.randi_range(0, 1) else -1
	var canonical = [Vector2(-7,-11),Vector2(-13,-5),Vector2(-13,5),Vector2(0,-16),Vector2(3,0),Vector2(15,0),Vector2(0,9),Vector2(0,18)]
	var layout: String = profile.get("monitor_layout",profile.id if profile.id in ["aether","lpdu"] else "astoh")
	if layout == "aether": canonical = [Vector2(-11,-9),Vector2(-11,9),Vector2(10,11),Vector2(1,-15),Vector2(10,-11),Vector2(15,-4),Vector2(15,4),Vector2(1,15)]
	elif layout == "lpdu": canonical = [Vector2(10,-11),Vector2(-11,-9),Vector2(-11,9),Vector2(1,-15),Vector2(15,-4),Vector2(15,4),Vector2(10,11),Vector2(1,15)]
	if layout=="cn_mirror":canonical=[Vector2(-7,-13),Vector2(-13,-5),Vector2(-13,5),Vector2(0,-9),Vector2(3,0),Vector2(16,0),Vector2(0,9),Vector2(0,18)]
	elif layout=="kr_astoh":canonical=[Vector2(-7,-11),Vector2(-13,-5),Vector2(-13,5),Vector2(-0.7,-16),Vector2(3,0),Vector2(15,0),Vector2(-0.7,9),Vector2(-0.7,18)]
	elif layout=="cn_fixed":canonical=[Vector2(-8 if sign_x==1 else 8,-17),Vector2(-11,-5.5),Vector2(-11,5.5),Vector2(-sign_x,-8),Vector2(6,0),Vector2(18,0),Vector2(-sign_x,8),Vector2(-sign_x,18)]
	for i in 8:
		pos(i,canonical[i] if layout=="cn_fixed" else Vector2(canonical[i].x*sign_x,canonical[i].y))
		label(i, "MONITOR %d" % (i + 1) if i < 3 else "No monitor %d" % (i - 2))
	var layout_name: String={"astoh":"Astoh","aether":"Aether · 第三檢知南側","lpdu":"LPDU · 第一檢知北側","cn_fixed":"莫古力 · 固定左側","cn_mirror":"莫古力 · 鏡像換邊","kr_astoh":"09STOP"}.get(layout,layout)
	var b = beat("Oversampled Wave Cannon · %s · %s" % [layout_name,"EAST" if (sign_x == 1) == (layout not in ["aether","lpdu"]) else "WEST"],10.0,"每個檢知隨機命中其半場兩人，不足時補選其他人；還要避開半徑7的受擊小圓。Q/E 或右鍵調整朝向。")
	b.monitor_layout = layout
	var sources: Array = [{"kind": "half", "angle": (270 if layout in ["aether","lpdu"] else 90) * sign_x, "radius": 45, "name": "Boss monitor"}]
	var goals = [270.0 * sign_x, 0.0, 180.0]
	if layout=="cn_fixed":goals=[270.0 if sign_x==1 else 98.5,0.0,180.0]
	if layout == "aether": goals = [0.0,180.0,90.0 * sign_x]
	elif layout == "lpdu": goals = [90.0 * sign_x,0.0,180.0]
	for i in 3:
		var offset = 90.0 if rng.randi_range(0, 1) else -90.0
		b.facing[at(i)] = goals[i] - offset
		sources.append({"kind": "half", "actor": at(i), "face_actor": at(i), "offset": offset, "radius": 45, "exclude": [at(i)], "name": "Player monitor"})
	b.checks.append({"kind": "monitors", "sources": sources, "splash_radius":7.0,"name": "Oversampled Wave Cannon"})
	b.monitors = sources
	b.party_statuses=[]
	for source in sources:
		if source.has("actor"): b.party_statuses.append({"actor":int(source.actor),"key":"monitor_right" if float(source.offset)>0 else "monitor_left","remaining":-1})
	order = saved_order

func p4_wave() -> void:
	preload("res://scripts/p4_wave_courses.gd").append_wave(self)

func delta() -> void:
	var colours: Array = [0, 1, 1, 0, 0, 0, 1, 1]
	# Four blue players are mixed/mixed; green players are same/same, or vice versa.
	if rng.randi_range(0, 1): colours = [0, 0, 1, 1, 0, 1, 1, 0]
	var swap_group: int = rng.randi_range(-1, 1)
	if swap_group >= 0:
		var base: int = swap_group * 4
		var temp = colours[base + 2]; colours[base + 2] = colours[base + 3]; colours[base + 3] = temp
	var actor_colours: Array = []; actor_colours.resize(8)
	for i in 8: actor_colours[at(i)] = colours[i]
	# Like tethers together (Saus / Kinda Awk family), then split responsibilities.
	for i in 8:
		var blue = i < 4
		var x = -10.0 if blue else 10.0
		var y = -12.0 if i % 2 == 0 else 12.0
		if i % 4 >= 2: x = -6.0 if blue else 6.0; y *= 0.4
		pos(i, Vector2(x, y)); label(i, "%s · %s · fist %s" % ["BLUE" if blue else "GREEN", "OUTER" if i % 4 < 2 else "INNER", "YELLOW" if colours[i] == 1 else "BLUE"])
	var b = beat("Delta · tethers activate / colour pairs", 7.0, "Blue to beetle; green to Final Omega. Outer blue breaks immediately; inner swaps if fists have the same colour.")
	b.checks.append(pair(at(0), at(1), 22, 40, "Outer BLUE break")); b.checks.append(pair(at(2), at(3), 0, 16, "Inner BLUE hold"))
	b.checks.append(pair(at(4), at(5), 18, 40, "GREEN hold")); b.checks.append(pair(at(6), at(7), 8, 40, "GREEN hold"))
	b.tethers = [{"a": at(0), "b": at(1)}, {"a": at(2), "b": at(3)}, {"a": at(4), "b": at(5)}, {"a": at(6), "b": at(7)}]
	b.paired_tethers = []
	for pair_index in 4:
		b.paired_tethers.append({"id":"delta_%d" % pair_index,"kind":"remote" if pair_index < 2 else "local","a":at(pair_index*2),"b":at(pair_index*2+1),"delay":float(Params.parameter("delta_activation_delay")),"duration":float(Params.parameter("delta_regression_duration")),"threshold":float(Params.parameter("delta_remote_distance" if pair_index < 2 else "delta_local_distance"))})
	var blue_inner: Array = [positions[at(2)],positions[at(3)]]
	for i in [0, 1, 4, 5]:
		var outer: Vector2 = positions[at(i)]
		var needs_swap: bool = colours[(i / 4) * 4] == colours[(i / 4) * 4 + 2]
		var destination: int = (i + 1 if i % 2 == 0 else i - 1) if needs_swap else i
		if i < 2:
			pos(i+2,blue_inner[destination])
			pos(i,blue_inner[i]+Vector2(0.5,0))
		else: pos(i + 2, positions[at(destination)] + Vector2(0.5, 0))
	b = beat("Delta · Rocket Punch pair bait", 6.0, "Each blue fist must meet one yellow fist. Record these bait locations before moving.")
	b.checks.append({"kind": "fists", "colours": actor_colours, "name": "Rocket Punch"})
	var fists: Array = []
	for i in [0, 1, 4, 5]:
		b.shapes.append(targeted(at(i), 2, 2, "Rocket Punch · opposite colours"))
		var fist = circle(positions[at(i)], 5, "Rocket Punch snapshot"); fist.snapshot_position_actor = at(i)
		fists.append(fist)
	for i in 8: pos(i, polar(22.5 + i * 45, 17))
	pos(2, Vector2(-17, -4)); pos(3, Vector2(17, 4))
	b = beat("Delta · leave fists / bait spinning arm lasers", 7.0)
	b.shapes = fists
	b.checks.append(pair(at(2), at(3), float(Params.parameter("delta_remote_distance")), 40, "Inner BLUE now breaks"))
	var arm_shapes: Array = []; var arm_sources: Array = []
	var bait_slots := [0,1,4,5,6,7]
	for j in 6:
		var degrees := float(j*60)
		var rotation_sign := 1 if rng.randi_range(0,1) else -1
		var origin := polar(degrees,20.0)
		pos(bait_slots[j],polar(degrees-rotation_sign*3.0,19.0))
		var target: int = at(bait_slots[j])
		var axis: Vector2 = positions[target]-origin
		var base_angle := rad_to_deg(atan2(axis.x,-axis.y))
		arm_shapes.append({"kind":"line","decorative":true,"pos":origin,"target":target,"width":8.0,"length":100.0,"name":"Hyper Pulse bait"})
		arm_sources.append({"pos":origin,"target":target,"angle":base_angle,"sign":rotation_sign})
		labels[target] += " · ARM " + ("CW" if rotation_sign>0 else "CCW")
	pos(2,Vector2(-2,-2));pos(3,Vector2(2,2))
	b=beat("Delta · bait six rotating arms",8.0,"先引導六手臂，再往內離開鎖定線。六發每次轉 20°、間隔 0.6 秒；手臂距中心 20、雷射寬 8。")
	b.shapes=arm_shapes
	for j in 6:b.checks.append({"kind":"closest","pos":arm_sources[j].pos,"members":[at(bait_slots[j])],"count":1,"name":"Nearest arm bait"})
	for pulse in 6:
		for j in 6:pos(bait_slots[j],polar(j*60,5.0))
		b=beat("Delta · Hyper Pulse %d/6" % (pulse+1),2.5 if pulse==0 else 0.6,"角度只在第一發前鎖定一次，之後六發不會重新追蹤玩家。")
		b.rotation_group="delta_arms";b.rotation_sources=[]
		for source in arm_sources:
			var turn := float(source.sign)*20.0*pulse
			b.shapes.append({"kind":"line","pos":source.pos,"angle":float(source.angle)+turn,"width":8.0,"length":100.0,"name":"Rotating Hyper Pulse"})
			b.rotation_sources.append({"pos":source.pos,"target":source.target,"turn":turn})
	# A single monitor and the boss monitor each choose two green-tether players.
	for i in 8: pos(i, Vector2(-1 + (i % 3) * 0.25, 3))
	pos(0, Vector2(-10, 0)); pos(1, Vector2(-2, 5)); pos(2, Vector2(-1, 5)); pos(3, Vector2(0, 5))
	pos(4, Vector2(-13, -10)); pos(5, Vector2(13, -10)); pos(6, Vector2(-13, 12)); pos(7, Vector2(13, 12))
	b = beat("Delta · monitors + Beyond Defense exclusion", 9.0, "Beyond Defense victim stays out of Pile Pitch. Player monitor points away from the boss monitor.")
	b.facing[at(1)] = 90.0
	b.shapes.append(targeted(at(0), 4, 1, "Beyond Defense")); b.shapes.append(targeted(at(2), 3, 3, "Pile Pitch"))
	b.shapes.append({"kind": "half", "angle": 0, "radius": 45, "rule": "count", "count": 2, "required": [at(4), at(5)], "name": "Final Omega monitor"})
	b.shapes.append({"kind": "half", "actor": at(1), "face_actor": at(1), "offset": 90, "radius": 45, "exclude": [at(1)], "rule": "count", "count": 2, "required": [at(6), at(7)], "name": "Player monitor"})
	pos(4, Vector2(-1,-12)); pos(5, Vector2(1,-12))
	b = beat("Delta · first Local contact", 4.0, "Break this paired line by contact after the earlier raidwide vulnerability. It cannot transfer to another player.")
	# Training snapshot makes the GREEN break order explicit.
	world_snapshot([at(0), at(1), at(4), at(5), at(6), at(7), at(2), at(3)], "Delta · Near/Far + first GREEN break", true, 0)
	b = beats[-1]
	b.shapes.append({"kind": "half", "angle": 0, "radius": 45, "name": "Diffuse Wave Cannon · safe half"})
	b.note = "First green pair breaks before worlds; last pair waits for vulnerability to wear off. No early double patch."
	pos(6, Vector2(-1, 12)); pos(7, Vector2(1, 12))
	b = beat("Delta · last GREEN breaks after vulnerability", 6.0)
	b.checks.append(pair(at(6), at(7), 0, 3, "Last Local Regression"))
	b.checks.append({"kind":"regressions_resolved","prefix":"delta_"})

func sigma() -> void:
	var remote = bool(rng.randi_range(0, 1))
	var marked_pairs = [0, 1, 2, 3]
	var pick = rng.randi_range(0, 3); var pick2 = (pick + 1 + rng.randi_range(0, 2)) % 4
	var doubles: Array = []; var singles: Array = []
	for p in marked_pairs:
		if p in [pick, pick2]: doubles.append(p)
		else: singles.append(p)
	var directions = {}
	for j in 2:
		var p: int = doubles[j]
		directions[p * 2] = 0.0 if j == 0 else 270.0
		directions[p * 2 + 1] = 180.0 if j == 0 else 90.0
		p = singles[j]
		directions[p * 2] = 315.0 if j == 0 else 45.0
		directions[p * 2 + 1] = 135.0 if j == 0 else 225.0
	for i in 8:
		pos(i, polar(directions[i], 18 if remote else 12))
		var symbol: String = profile.shapes[i / 2]
		label(i, "%s · %s · %s" % [symbol, "2 marks" if i / 2 in doubles else ("NO MARK" if i % 2 == 0 else "1 mark"), "REMOTE" if remote else "MID"])
	var b = beat("Sigma · six marks / eight-way spread", 9.0, "Two double-mark pairs and two single-mark pairs. Remember the waymark beside your spread position.")
	for i in 8:
		if i / 2 in doubles or i % 2 == 1: b.shapes.append({"kind": "line", "pos": Vector2.ZERO, "target": at(i), "width": 2.5, "length": 40, "rule": "count", "count": 1, "name": "Wave Cannon marker"})
	for j in 2:
		var arm_pos: Vector2 = polar(135 if j == 0 else 225, 9)
		var target_actor: int = at(singles[j] * 2)
		b.shapes.append({"kind": "line", "pos": arm_pos, "target": target_actor, "width": 2.5, "length": 45, "rule": "count", "count": 1, "required": [target_actor], "name": "Furthest-player Hyper Pulse"})
		b.checks.append({"kind": "furthest", "pos": arm_pos, "members": [target_actor], "count": 1, "name": "Hyper Pulse bait"})
	for i in 4: b.checks.append(glitch_pair(at(i*2),at(i*2+1),remote,"Sigma Glitch"))
	# Waymark routing is a consequence of the previous spread, not role order.
	var by_mark = {}
	for i in 8: by_mark[int(round(float(directions[i]) / 45.0)) % 8] = at(i)
	var routes: Dictionary
	if remote: routes = {1: 0.0, 3: 0.0, 0: 288.0, 2: 216.0, 5: 216.0, 4: 144.0, 7: 144.0, 6: 72.0}
	else: routes = {1: 337.5, 3: 22.5, 0: 247.5, 5: 247.5, 2: 202.5, 4: 157.5, 6: 112.5, 7: 112.5}
	# Use documented pairs A+3/D+4 (mid) and B+3/C+4 (far).
	var group_by_tower = {}
	for mark in routes:
		var deg: float = routes[mark]
		if not group_by_tower.has(deg): group_by_tower[deg] = []
		group_by_tower[deg].append(by_mark[mark])
	var final_goals = positions.duplicate()
	for deg in group_by_tower:
		var members: Array = group_by_tower[deg]
		for j in members.size():
			var offset = (float(j) - (members.size() - 1) / 2.0) * 0.7
			final_goals[members[j]] = polar(float(deg) + offset * 3, 18)
			positions[members[j]] = final_goals[members[j]].normalized() * 5
	b = beat("Sigma · knockback towers · %s" % ("REMOTE (5 towers)" if remote else "MID (6 towers)"), 10.0, "Use your previous waymark. Tower capacities are enforced after the radial knockback.")
	b.knockback = 13.0
	for deg in group_by_tower: b.shapes.append(tower(polar(deg, 18), 2.5, group_by_tower[deg], "Sigma tower"))
	for i in 4: b.checks.append(glitch_pair(at(i*2),at(i*2+1),remote,"Sigma landing Glitch"))
	if rng.randi_range(0, 1): rotate_beat(b, 180)
	var rotate_direction = 1 if rng.randi_range(0, 1) else -1
	for j in 14:
		for i in 8: pos(i, polar(40 + rotate_direction * j * float(Params.parameter("sigma_step_degrees")) + (0 if i < 3 else 180), 13))
		b = beat("Sigma · rotating Rear Power Unit %d/14" % (j + 1), 5.0 if j == 0 else float(Params.parameter("sigma_shot_interval")), "十四發獨立判定，寬 12、每 0.6 秒旋轉 9°；可用速度選項放慢。")
		b.shapes.append(line(Vector2.ZERO, rotate_direction * j * float(Params.parameter("sigma_step_degrees")), 12, "Rear Power Unit"))
	world_snapshot(order.duplicate(), "Sigma · Hello Near / Distant World", false, 0)

func omega(entry_stacks: Array = []) -> void:
	omega_dodges()
	# A valid P5 entry is 4×2 + 4×1; choose eligible monitors, prioritising second-in-line.
	var stacks: Array = initial_stacks("p5_omega") if entry_stacks.is_empty() else entry_stacks.duplicate()
	var first_holders = [at(4), at(5)]; var second_holders = [at(0), at(6)]
	var monitors_pair = select_monitors(stacks, first_holders, second_holders)
	var others: Array = []
	for i in 8:
		if i not in first_holders and i not in monitors_pair: others.append(i)
	var assignment = [first_holders[0], first_holders[1], others[0], others[1], others[2], others[3], monitors_pair[0], monitors_pair[1]]
	var first_start := beats.size()
	world_snapshot(assignment, "Omega · first World + two-stack monitors", false, 0)
	var b: Dictionary = beats[first_start]
	b.shapes.append({"kind": "half", "angle": 90, "radius": 45, "rule": "count", "count": 2, "required": monitors_pair, "name": "Omega monitors"})
	# Monitors land between the initial World and its first jump, not at jump2.
	var monitor_beat: Dictionary = b.duplicate(true)
	monitor_beat.title = "Omega · monitor snapshot between World pulses"
	monitor_beat.duration = 0.5; monitor_beat.checks = []
	b.shapes = []; beats[first_start+1].duration = 0.5
	beats.insert(first_start+1,monitor_beat)
	for world_beat in beats.slice(first_start):
		world_beat.stage_entities=[{"form":"final","pos":Vector2.ZERO,"facing":0.0}];world_beat.hide_main_boss=true
	for i in assignment.slice(0, 6): stacks[i] = mini(3, int(stacks[i]) + 1)
	var three: Array = []
	for i in 8:
		if stacks[i] == 3: three.append(i)
	others = []
	for i in 8:
		if i not in second_holders and i not in three: others.append(i)
	assignment = [second_holders[0], second_holders[1], others[0], others[1], others[2], others[3], three[0], three[1]]
	var second_start := beats.size()
	world_snapshot(assignment, "Omega · second World + three-stack tethers", false, 0)
	b = beats[second_start]
	beats[-1].checks.append({"kind": "dynamis", "value": [3, 3, 3, 3, 3, 3, 3, 3], "name": "P6 entry"})
	b.note = "Blaster follows the actual transferred line holders. Only three-stack non-World players are eligible."
	for pulse_beat in beats.slice(second_start):
		pulse_beat.positions[three[0]] = Vector2(16,-10); pulse_beat.positions[three[1]] = Vector2(16,10)
		pulse_beat.stage_entities=[{"form":"beetle","pos":Vector2(19,0),"facing":270.0}];pulse_beat.hide_main_boss=true
	b.transfers = {"group":"omega_blaster","sources":[Vector2(19,0),Vector2(19,0)],"initial":shuffled(range(8)).slice(0,2),"wanted":three.duplicate(),"holders":[]}
	b.checks.push_front({"kind":"blaster_eligible","world_holders":second_holders})
	b.duration = float(Params.parameter("omega_blaster_to_world"))
	# Separate explosion from World while preserving the actual line owners.
	var pickup: Dictionary = b.duplicate(true)
	pickup.title = "Omega · collect beetle Blaster / explosion"
	pickup.duration = 12.2
	pickup.checks = [{"kind":"blaster_eligible","world_holders":second_holders}]
	pickup.shapes = []
	for k in 2: pickup.shapes.append({"actor":three[k],"tether_index":k,"radius":15.0,"rule":"omega_blaster","name":"Omega Blaster"})
	beats.insert(second_start,pickup)
	b.erase("transfers") # Blaster has exploded; there is no line left to steal during World.


static func select_monitors(stacks: Array, first: Array, second: Array) -> Array:
	var result: Array = []
	for i in second:
		if stacks[i] == 2 and i not in first: result.append(i)
	for i in 8:
		if result.size() >= 2: break
		if stacks[i] == 2 and i not in first and i not in result: result.append(i)
	return result

static func omega_shapes(sword: bool, legs: bool, orientation: float, second: bool, diffuse_axis := -999.0, second_offset := 90.0) -> Array:
	var m_angle := orientation+45.0+(second_offset if second else 0.0)
	var shapes := Clones.pair_shapes(m_angle,sword,legs)
	var axis: float = (orientation if diffuse_axis == -999.0 else diffuse_axis)+(90.0 if second else 0.0)
	for side in [0,180]:shapes.append({"kind":"cone","pos":Vector2.ZERO,"angle":axis+side,"width":120.0,"radius":100.0,"name":"Omega Diffuse Wave Cannon"})
	return shapes

func omega_dodges() -> void:
	var orientation := float(profile.get("omega_orientation",rng.randi_range(0,3)*90))
	var second_offset := float(profile.get("omega_second_offset",90 if rng.randi_range(0,1) else -90))
	var diffuse_axis := float(profile.get("omega_diffuse_axis",rng.randi_range(0,1)*90))
	var patterns: Array=[]
	for step in 2:
		var sword := bool(profile.get("omega_sword",rng.randi_range(0,1)))
		var legs := bool(profile.get("omega_legs",rng.randi_range(0,1)))
		if profile.has("omega_stances"):sword=profile.omega_stances[step][0];legs=profile.omega_stances[step][1]
		if step==1 and not profile.has("omega_stances") and sword==patterns[0].sword and legs==patterns[0].legs:
			#09STOP explicitly excludes both clones repeating the same combination.
			var choices:Array=[]
			for combo in [[false,false],[false,true],[true,false],[true,true]]:
				if combo!=[patterns[0].sword,patterns[0].legs]:choices.append(combo)
			var next:Array=choices[rng.randi_range(0,2)];sword=next[0];legs=next[1]
		patterns.append({"sword":sword,"legs":legs,"m_angle":orientation+45.0+(second_offset if step else 0.0)})
	for step in 2:
		var pattern: Dictionary=patterns[step]
		var shapes := omega_shapes(pattern.sword,pattern.legs,orientation,step==1,diffuse_axis,second_offset)
		var radius := 3.0 if pattern.legs else (float(profile.get("omega_far_radius",16.5)) if pattern.sword else 10.0)
		var safe: Array=[]
		for cardinal in [0,90,180,270]:
			var point := polar(cardinal,radius)
			if shapes.all(func(shape):return not Rules.contains(shape,point,[])):safe.append(point)
		assert(safe.size()==1,"Omega source family must produce one guide cardinal")
		for i in 8:pos(i,safe[0])
		var b:=beat("Omega clones %d/2 · %s / %s" % [step+1,"sword" if pattern.sword else "shield","legs" if pattern.legs else "staff"],13.2 if step==0 else 4.0,"兩對克隆相對出現在半徑10的四個斜角；第二組可順／逆90°。遠點移動可使用疾跑1。")
		if step==1 and positions[0].distance_to(beats[-2].positions[0])>24.0:b.bot_sprint=range(8)
		b.shapes=shapes
		b.clone_pattern={"sword":pattern.sword,"legs":pattern.legs,"orientation":orientation,"second":step==1,"m_angle":pattern.m_angle,"diffuse_axis":diffuse_axis+(90 if step else 0),"status":"fflogs_observed_intercardinal_family"}
		b.stage_entities=[{"form":"final","pos":Vector2.ZERO,"facing":0.0}]
		b.stage_entities.append_array(Clones.pair_entities(pattern.m_angle,pattern.sword,pattern.legs,0.0,true))
		if step==0:b.stage_entities.append_array(Clones.pair_entities(patterns[1].m_angle,patterns[1].sword,patterns[1].legs,4.0,true))
		b.hide_main_boss=true

func intended_stacks() -> Array:
	var values: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	for item in beats:
		for check in item.checks:
			if check.kind == "world" or (check.kind == "world_pulse" and int(check.pulse)==0):
				for actor in check.near_path + check.far_path: values[int(actor)] = mini(3, values[int(actor)] + 1)
	return values

func world_snapshot(assignment: Array, title: String, safe_half: bool, rotation: float) -> void:
	# Six intended world recipients, then two non-participants. Nearest/furthest
	# selections and clipping are recomputed from actual positions by Rules.
	var points = [Vector2(-10, -1), Vector2(0, 8), Vector2(-18, 0), Vector2(-17, 7), Vector2(0, -18), Vector2(0, 18), Vector2(12, -6), Vector2(12, 6)]
	if safe_half: points = [Vector2(-6, 6), Vector2(-2, 16), Vector2(-14, 8), Vector2(-12, 14), Vector2(18, 1), Vector2(-18, 1), Vector2(4, 7), Vector2(9, 11)]
	for i in 8:
		positions[int(assignment[i])] = rotated(points[i], rotation)
		labels[int(assignment[i])] = ["HELLO NEAR", "HELLO DISTANT", "NEAR jump 1", "NEAR jump 2", "FAR jump 1", "FAR jump 2", "NO World / utility 1", "NO World / utility 2"][i]
	var chain_id := "world_%d" % beats.size()
	for pulse in 3:
		var b = beat(title + (" · holders" if pulse==0 else " · jump %d/2" % pulse),10.0 if pulse==0 else float(Params.parameter("world_pulse_interval")),"每一跳讀取當下位置；原持有者仍可被跳回。提示分工不限定實際收線者。")
		b.checks.append({"kind":"world_pulse","chain_id":chain_id,"pulse":pulse,"near":assignment[0],"far":assignment[1],"near_path":[assignment[0],assignment[2],assignment[3]],"far_path":[assignment[1],assignment[4],assignment[5]],"holder_radius":float(Params.parameter("world_holder_radius")),"jump_radius":float(Params.parameter("world_jump_radius"))})
		b.world = b.checks[0]

func dynamis_course() -> void:
	# 24 total hits across four worlds must result in exactly 3 stacks per player.
	# Delta skips 6/7, Sigma skips 4/5, Omega1 skips 2/3, Omega2 skips 0/1.
	var stages = [
		[at(0), at(1), at(2), at(3), at(4), at(5), at(6), at(7)],
		[at(6), at(7), at(0), at(1), at(2), at(3), at(4), at(5)],
		[at(4), at(5), at(6), at(7), at(0), at(1), at(2), at(3)],
		[at(2), at(3), at(4), at(5), at(6), at(7), at(0), at(1)]
	]
	for i in 4:
		world_snapshot(stages[i], ["Delta World", "Sigma World", "Omega first World", "Omega final World"][i], i == 0, 0)
		if i == 3: beats[-1].checks.append({"kind": "dynamis", "value": [3, 3, 3, 3, 3, 3, 3, 3]})

func solar_ray() -> void:
	for turn in 2:
		positions[0] = Vector2(-6, -8); positions[1] = Vector2(6, -8)
		for i in range(2, 8): positions[i] = Vector2(0, 8)
		var b = beat("Solar Ray · hit %d/2 · %s" % [turn + 1, ROLES[turn]], 6.0, "Two hits with Magic Vulnerability: swap with V between hits (invuln/HP model not simulated).")
		b.p5_solar=true
		b.shapes.append(targeted(turn, 4, 1, "Solar Ray"))
		b.checks.append({"kind": "aggro", "actor": turn, "name": "Solar Ray swap"})

func lb_check(item: Dictionary, type: String, actor: int, name: String) -> void:
	item.checks.append({"kind": "lb", "type": type, "eligible": [actor], "name": name})
	item.note += " LB: %s (%s), press F during this window. Other roles are handled by bots." % [ROLES[actor], type]

func memory() -> void:
	P6Courses.append_memory(self)

static func arrow_shapes(inside_out: bool, pulse: int, concurrent := false) -> Array:
	var offsets: Array
	if inside_out: offsets = [0.0] if pulse == 0 else [-7.5-5.0*(pulse-1),7.5+5.0*(pulse-1)]
	else:
		var start := float(Params.parameter("arrow_side_start"))
		offsets = [-start,start] if pulse == 0 else [-start+7.5+5.0*(pulse-1),start-7.5-5.0*(pulse-1)]
	var result: Array = []
	for axis in [0,90]:
		for offset in offsets:
			result.append({"kind":"line","pos":Vector2(offset,0) if axis==0 else Vector2(0,offset),"angle":axis,"start":-50.0,"length":50.0,"width":10.0 if pulse==0 else 5.0,"name":"Concurrent Cosmo Arrow" if concurrent else "Cosmo Arrow translation"})
	return result

func cosmo_arrow(with_waves: bool) -> void:
	var inside_out := bool(profile.get("arrow_inside_out",rng.randi_range(0,1)))
	var pulses := 4 if inside_out else 7
	for j in pulses:
		var concurrent := with_waves and j >= pulses-2
		var shapes := arrow_shapes(inside_out,j,concurrent)
		if with_waves:
			# Choose safe radial positions for each role ray against the real translated strips.
			for i in 8:
				for r in range(19,2,-1):
					var candidate := polar(22.5+i*45,r)
					if shapes.all(func(shape): return not Rules.contains(shape,candidate,[])):
						positions[i] = candidate; break
		else:
			var safe := find_safe(shapes)
			for i in 8: positions[i] = safe
		var b := beat("Cosmo Arrow · %s · pulse %d/%d" % ["center-out" if inside_out else "sides-in",j+1,pulses],8.0 if j==0 else 2.0,"Orthogonal strips: first width 10, first translation 7.5, subsequent translation 5. Community geometry; starting topology remains training data.")
		b.shapes = shapes
		if concurrent:
			for actor in ([0,2,4,6] if j==pulses-2 else [1,3,5,7]): b.shapes.append({"kind":"line","pos":Vector2.ZERO,"target":actor,"width":2.0,"length":40,"rule":"count","count":1,"name":"Wave Cannon spread"})

func cosmo_dive() -> void:
	positions[0] = Vector2(-4, -4); positions[1] = Vector2(4, -4)
	group_goals([2, 3, 4, 5, 6, 7], Vector2(0, 14), 0.25)
	var b = beat("Cosmo Dive · nearest two tanks / furthest six-stack", 7.0)
	b.checks.append({"kind": "closest_tanks"})
	for ordinal in 2:
		var hit = targeted(ordinal, 5, 1, "Cosmo Dive tank"); hit.dynamic_actor = {"selector": "closest", "ordinal": ordinal}; b.shapes.append(hit)
	var stack = targeted(7, 4, 6, "Cosmo Dive party"); stack.dynamic_actor = {"selector": "furthest", "ordinal": 0}; b.shapes.append(stack)

static func exaflare_streams(orientation: float) -> Array:
	var result: Array = []
	var params = preload("res://scripts/statuses.gd")
	for i in 4:
		var axis := Rules.direction(orientation+i*90)
		result.append({"id":"exa_%d" % i,"pos":axis*float(params.parameter("exaflare_origin_radius")),"advance":-axis*float(params.parameter("exaflare_step")),"radius":float(params.parameter("exaflare_radius")),"delay":float(params.parameter("exaflare_first_delay"))+i*float(params.parameter("exaflare_stream_stagger")),"interval":float(params.parameter("exaflare_interval")),"remaining":int(params.parameter("exaflare_explosions")),"source_status":"unverified_origin_family"})
	return result

func exaflares() -> void:
	# This explicit origin family is a training fixture, not claimed to enumerate live spawns.
	for j in 6:
		var p := Vector2(9,9) if j%2==0 else Vector2(13.6,13.6)
		p = p.rotated(deg_to_rad(angle))
		for i in 8: positions[i] = p
		var b := beat("Unlimited Wave Cannon · moving streams / bait %d/6" % (j+1),3.0,"Moving straight streams; radius 8 from community events. 每條推進 8、間隔 1.1 秒、共七次爆炸；起點分布仍是待校準訓練族群。")
		if j == 0: b.streams = exaflare_streams(angle)
		if j > 0:
			for actor in 8:
				var puddle := circle((Vector2(9,9) if j%2==1 else Vector2(13.6,13.6)).rotated(deg_to_rad(angle)),6.0,"Baited wave (previous snapshot)")
				puddle.snapshot_position_actor = actor; b.shapes.append(puddle)

func wave_cannon(with_spreads := true) -> void:
	if with_spreads:
		for turn in 2:
			for i in 8: positions[i] = polar(22.5 + i * 45, 13)
			var b = beat("Wave Cannon · spread %d/2" % (turn + 1), 6.0)
			for i in [0, 2, 4, 6] if turn == 0 else [1, 3, 5, 7]: b.shapes.append({"kind": "line", "pos": Vector2.ZERO, "target": i, "width": 3.0, "length": 40, "rule": "count", "count": 1, "name": "Wave Cannon spread"})
	var stack_angle: float = profile.get("p6_stack_angle", 90)
	var axis = polar(stack_angle, 1)
	positions[0] = axis * 8; positions[1] = axis * 9
	for i in range(2, 8): positions[i] = axis * (11 + (i - 2) * 0.2)
	var b = beat("Wave Cannon · eight-stack / tanks in front", 8.0, "Both tanks intercept the front of the heavy beam. Damage mitigation is outside this movement drill.")
	b.shapes.append({"kind": "line", "pos": Vector2.ZERO, "angle": stack_angle, "width": 4.0, "length": 40, "rule": "count", "count": 8, "name": "Wave Cannon party stack"})
	b.checks.append({"kind": "front_tanks", "angle": stack_angle})

func meteors() -> void:
	P6Courses.append_meteors(self)

func magic_number() -> void:
	P6Courses.append_magic(self)
