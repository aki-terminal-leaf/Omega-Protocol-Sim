# SPDX-License-Identifier: MIT
extends RefCounted
## Encounter -> timed beats -> bot goals and independent snapshot rules.
## Distances are yard-like training units; windows are intentionally slowed.
const Rules = preload("res://scripts/rules.gd")
const ROLES = ["MT", "ST", "H1", "H2", "D1", "D2", "D3", "D4"]
var rng = RandomNumberGenerator.new()
var order: Array = []
var priority: Array = []
var beats: Array = []
var labels: Array = []
var positions: Array = []
var profile: Dictionary
var angle = 0.0

func build(id: String, seed_value: int, strategy: Dictionary, player := 4, slot := -1) -> Dictionary:
	rng.seed = seed_value
	profile = strategy
	priority = []
	for role in strategy.priority: priority.append(ROLES.find(role))
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
		"p1_loop": program_loop()
		"p1_panto": pantokrator()
		"p1_cannons": p1_cannons()
		"p2_synergy": party_synergy()
		"p2_limitless": limitless()
		"p3_transition": transition()
		"p3_hello": hello_world()
		"p3_monitors": monitors()
		"p4_wave": p4_wave()
		"p5_delta": delta()
		"p5_sigma": sigma()
		"p5_omega": omega()
		"p5_dynamis": dynamis_course()
		"p5_full": solar_ray(); delta(); solar_ray(); sigma(); solar_ray(); omega(intended_stacks()); solar_ray()
		"p5_solar": solar_ray()
		"p6_memory": memory()
		"p6_arrow_dive": cosmo_arrow(false); cosmo_dive()
		"p6_exa_wave": exaflares(); wave_cannon()
		"p6_arrow_wave": cosmo_arrow(true); wave_cannon(false)
		"p6_exa_dive": exaflares(); cosmo_dive()
		"p6_meteors": meteors()
		"p6_magic": magic_number()
	return {"id": id, "seed": seed_value, "beats": beats, "assignments": order.duplicate(), "profile": strategy.id, "initial_dynamis": initial_stacks(id)}

func initial_stacks(id: String) -> Array:
	var result: Array = []; result.resize(8); result.fill(0)
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
	if profile.id != "aether": return ranked(values)
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
	var pattern: Array = []
	var previous: Array = []
	for _turn in 4:
		var pairs: Array = []
		for first in 8:
			for second in range(first + 1, 8):
				if first in previous or second in previous: continue
				if posmod(second - first, 8) in [2, 4, 6]: pairs.append([first, second])
		var chosen: Array = pairs[rng.randi_range(0, pairs.size() - 1)]
		pattern.append(chosen); previous = chosen
	for i in 8: label(i, "In Line %d" % (i / 2 + 1))
	for turn in 4:
		var first: int = pattern[turn][0]
		var second: int = pattern[turn][1]
		var targets = tower_pair([polar(first * 45, 13), polar(second * 45, 13)])
		var soakers = group_pair([at(turn * 2), at(turn * 2 + 1)])
		var tether_group = (turn + 2) % 4
		var tethers = group_pair([at(tether_group * 2), at(tether_group * 2 + 1)])
		var free: Array = []
		for i in 8:
			if i not in [first, second] and polar(i * 45, 17).distance_to(targets[0]) > 11 and polar(i * 45, 17).distance_to(targets[1]) > 11: free.append(polar(i * 45, 17))
		var best_a: Vector2 = free[0]; var best_b: Vector2 = free[-1]; var largest = 0.0
		for a in free:
			for b in free:
				if a.distance_to(b) > largest: largest = a.distance_to(b); best_a = a; best_b = b
		var tether_spots: Array = tower_pair([best_a, best_b])
		best_a = tether_spots[0]; best_b = tether_spots[1]
		for i in 8:
			var refuge = targets[i % 2] * 0.68
			if refuge.distance_to(best_a) < 10.5 or refuge.distance_to(best_b) < 10.5: refuge = targets[1 - i % 2] * 0.68
			positions[i] = refuge
		for i in 2:
			positions[soakers[i]] = targets[i]
			positions[tethers[i]] = best_a if i == 0 else best_b
		var item = beat("Program Loop %d/4 · towers %d / tethers %d" % [turn + 1, turn + 1, tether_group + 1], 16.0 if turn == 0 else 9.0, "線可以被接走。塔消除 Looper；Blaster 打當下持線者。塔 1234／推薦接線 3412，重複受擊會累積 Twice-come Ruin。")
		var numbers: Array = []; numbers.resize(8)
		for n in 8: numbers[at(n)] = n / 2 + 1
		item.program_loop = {"round": turn + 1, "numbers": numbers, "holders": [], "pickup_radius": 0.65}
		var initial: Array = order.slice(0, 2)
		if turn == 0:
			initial = shuffled(range(8)).slice(0, 2)
		item.transfers = {"group": "loop", "sources": [Vector2.ZERO, Vector2.ZERO], "initial": initial, "wanted": tethers.duplicate(), "holders": []}
		if turn == 0:
			item.spawn = []
			for actor in 8: item.spawn.append(Vector2(-3.5 + actor, 6.0))
		for i in 2:
			var storage = tower(targets[i], 2.3, [soakers[i]], "Storage Violation")
			storage.erase("required"); storage.looper_tower = true
			item.shapes.append(storage)
			item.shapes.append({"kind": "circle", "actor": initial[i], "tether_index": i, "radius": 10.0, "rule": "blaster", "name": "Blaster"})
		item.tethers = [{"a": tethers[0], "b": -1}, {"a": tethers[1], "b": -1}]

func pantokrator() -> void:
	var clockwise = 1 if rng.randi_range(0, 1) else -1
	for i in 8: label(i, "Missile %d · G%d" % [i / 2 + 1, i % 2 + 1])
	for turn in 4:
		for step in 3:
			var theta = angle + clockwise * (turn * 54 + step * 18)
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
	var m_sword = bool(rng.randi_range(0, 1)); var f_legs = bool(rng.randi_range(0, 1))
	var shapes = clone_shapes(m_sword, f_legs)
	var safe = find_safe(shapes)
	for i in 8: pos(i, safe + Vector2(i * 0.04, 0))
	var dodge = beat("Party Synergy · M %s / F %s" % ["SWORD" if m_sword else "SHIELD", "LEGS" if f_legs else "STAFF"], 7.0, "Read M and F stances before the eye. Model stances are shown in the cast cue.")
	dodge.shapes = shapes
	var remote = bool(rng.randi_range(0, 1))
	var symbols: Array = profile.shapes
	for i in 4:
		var z = -12.0 + i * 8.0
		var x = sqrt(18.0 * 18.0 - z * z) if remote else 10.0
		pos(i * 2, rotated(Vector2(-x, z), angle))
		var other_z = -z if remote and profile.get("remote_full_cross", true) else z
		if remote and not profile.get("remote_full_cross", true): other_z = -z if i in [0, 3] else z
		pos(i * 2 + 1, rotated(Vector2(x, other_z), angle))
		label(i * 2, "%s · L · %s" % [symbols[i], "REMOTE" if remote else "MID"])
		label(i * 2 + 1, "%s · R · %s" % [symbols[i], "REMOTE" if remote else "MID"])
	var eye = beat("Optical Laser + Fire III · %s Glitch" % ("REMOTE" if remote else "MID"), 8.0, "Eye is relative north. Remember your symbol and left/right side.")
	eye.shapes.append(line(Vector2.ZERO, angle, 12.0, "Optical Laser"))
	spread(eye, range(8), 3.5)
	for i in 4: eye.checks.append(pair(at(i * 2), at(i * 2 + 1), 32.0 if remote else 18.0, 40.0 if remote else 27.0, "Glitch"))
	var left: Array = []; var right: Array = []
	for i in 4: left.append(at(i * 2)); right.append(at(i * 2 + 1))
	var stacks = [at(rng.randi_range(0, 7)), at(rng.randi_range(0, 7))]
	while stacks[1] == stacks[0]: stacks[1] = at(rng.randi_range(0, 7))
	if (stacks[0] in left) == (stacks[1] in left):
		var candidates = stacks.duplicate()
		candidates.sort_custom(func(a, b): return order.find(a) / 2 < order.find(b) / 2)
		var selected = candidates[0] if profile.stack_flex == "north" else candidates[-1]
		var symbol_index = order.find(selected) / 2
		var partner = at(symbol_index * 2 + (1 if selected in left else 0))
		left.erase(selected); right.erase(selected); left.erase(partner); right.erase(partner)
		if order.find(selected) % 2 == 0: right.append(selected); left.append(partner)
		else: left.append(selected); right.append(partner)
	var lp = polar(270, 5); var rp = polar(90 if remote else 180, 5)
	group_goals(left, lp, 0.08); group_goals(right, rp, 0.08)
	var knock = beat("Discharger + Spotlight · %s flex" % profile.stack_flex, 7.0, "Aim knockback into two safe gaps. One stack per group; flex with your symbol partner.")
	knock.knockback = 13.0
	for i in stacks: knock.shapes.append(targeted(i, 4.0, 4, "Spotlight"))
	for deg in [0, 45, 135, 225, 315]: knock.shapes.append(circle(polar(deg, 18), 7.0, "Efficient Bladework"))
	for i in 4: knock.checks.append(pair(at(i * 2), at(i * 2 + 1), 32.0 if remote else 18.0, 40.0 if remote else 29.0, "Glitch after knockback"))
	knock = rotate_beat(knock, angle)

func clone_shapes(sword: bool, legs: bool) -> Array:
	var shapes: Array = []
	shapes.append(circle(Vector2(-11, 0), 10, "Efficient Bladework") if sword else {"kind": "donut", "pos": Vector2(-11, 0), "inner": 7, "radius": 45, "name": "Beyond Strength"})
	if legs:
		shapes.append(line(Vector2(1, 0), 0, 13, "Superliminal Steel")); shapes.append(line(Vector2(21, 0), 0, 13, "Superliminal Steel"))
	else:
		shapes.append(line(Vector2(11, 0), 0, 7, "Optimized Blizzard III")); shapes.append(line(Vector2(11, 0), 90, 7, "Optimized Blizzard III"))
	return shapes
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
	positions[0] = Vector2(-16, -5); positions[1] = Vector2(16, -5)
	for i in range(2, 8): positions[i] = Vector2(0, 9 + (i - 2) * 0.15)
	var b = beat("Limitless Synergy · tanks intercept tethers", 7.0, "Tanks take Bladedance away from the baited arrow and the party.")
	b.transfers = {"group": "limitless", "sources": [Vector2(-12, -16), Vector2(12, -16)], "initial": [at(2), at(3)], "wanted": [0, 1], "holders": []}
	b.spawn = []
	for i in 8: b.spawn.append(Vector2(-8 if i == 0 else 8, 0) if i < 2 else Vector2(-1.25 + (i - 2) * 0.5, 9))
	for i in 2: b.shapes.append({"kind": "cone", "pos": b.transfers.sources[i], "target": b.transfers.initial[i], "tether_index": i, "width": 60, "radius": 40, "rule": "count", "count": 1, "name": "Optimized Bladedance"})
	b.checks.append({"kind": "tether_tanks", "name": "Optimized Bladedance holders"})
	b.tethers = [{"a": 0, "b": -1}, {"a": 1, "b": -1}]
	var flare_actors = [at(2), at(3), at(4)]
	for i in 8: positions[i] = Vector2(0, -7)
	for i in 3: positions[flare_actors[i]] = polar(90 + i * 90, 18)
	b = beat("Optimized Meteor · separate flares", 7.0, "Training variation: spread flares to the wall; no mitigation cheese is assumed.")
	for i in flare_actors: b.shapes.append(targeted(i, 11, 1, "Optimized Meteor"))
	var defense = rng.randi_range(0, 1)
	positions[0] = Vector2(-10, -4); positions[1] = Vector2(-10, 4)
	for i in range(2, 8): positions[i] = Vector2(5, 3)
	b = beat("Beyond Defense · tanks bait closest two", 6.0)
	b.shapes.append(targeted(defense, 4, 1, "Beyond Defense"))
	b.checks.append({"kind": "closest", "pos": Vector2(-16, 0), "members": [0, 1], "count": 2, "name": "Beyond Defense bait"})
	positions[defense] = Vector2(-12, -10)
	for i in 8:
		if i != defense: positions[i] = Vector2(-9, 3) + Vector2(0.1 * i, 0)
	b = beat("Pile Pitch · exclude Beyond Defense victim", 6.0)
	b.shapes.append(targeted(1 - defense, 4, 7, "Pile Pitch"))

func transition() -> void:
	for i in 4: label(i, "PURPLE · spread")
	for i in [4, 5]: label(i, "WHITE · pair stack")
	for i in [6, 7]: label(i, "NONE · join white")
	for step in 3:
		var radius: float = [12.0, 6.0, 12.0][step]
		for i in 4: pos(i, polar(-90 + i * 60, radius))
		pos(4, polar(150, radius)); pos(6, positions[at(4)] + Vector2(0.5, 0))
		pos(5, polar(210, radius)); pos(7, positions[at(5)] + Vector2(-0.5, 0))
		var b = beat("Reconfiguration · Wave Repeater %d/3" % (step + 1), 5.0, "Purple spread; white pair with no-debuff. Move through the resolved ring.")
		b.shapes.append({"kind": "donut", "inner": 0 if step == 0 else (9 if step == 1 else 15), "radius": 9 if step == 0 else (15 if step == 1 else 22), "name": "Wave Repeater"})
		# Colossal Blow is represented by six arm circles alternating between waves.
		for deg in [0, 120, 240]: b.shapes.append(circle(polar(deg + (60 if step % 2 == 0 else 0), 26), 8.0, "Colossal Blow"))
		if step == 2:
			spread(b, [at(0), at(1), at(2), at(3)], 3.5)
			b.shapes.append(targeted(at(4), 3, 2, "High-powered Sniper Cannon")); b.shapes.append(targeted(at(5), 3, 2, "High-powered Sniper Cannon"))

func hello_world() -> void:
	var red_defam = bool(rng.randi_range(0, 1))
	for turn in 4:
		var defam = posmod(-turn * 2, 8); var blue = posmod(2 - turn * 2, 8); var stacker = posmod(4 - turn * 2, 8); var green = posmod(6 - turn * 2, 8)
		for side in 2:
			var sign_x = -1 if side == 0 else 1
			pos(defam + side, Vector2(sign_x * 11, -9)); label(defam + side, "DEFAM · %s rot" % ("RED" if red_defam else "BLUE"))
			pos(green + side, Vector2(sign_x * 17, -8)); label(green + side, "GREEN tether → Defam")
			pos(stacker + side, Vector2(sign_x * 11, 10)); label(stacker + side, "STACK · %s rot" % ("BLUE" if red_defam else "RED"))
			pos(blue + side, Vector2(sign_x * 12, 12)); label(blue + side, "BLUE tether → Stack")
			if turn == 3: pos(green + side, Vector2(sign_x * 6, 12))
		var b = beat("Hello World %d/4 · Latent Defect + towers" % (turn + 1), 8.0, "Cycle: Defam → Blue tether → Stack → Green tether. Rot colours remain tied to stack/defam for the whole pull.")
		for side in 2:
			b.shapes.append(tower(positions[at(defam + side)], 2.5, [at(defam + side)], "Rot tower (%s)" % ("RED" if red_defam else "BLUE")))
			b.shapes.append(tower(positions[at(stacker + side)], 1.8, [at(stacker + side)], "Rot tower (%s)" % ("BLUE" if red_defam else "RED")))
			b.shapes.append(targeted(at(defam + side), 7.5, 1 if turn == 3 else 2, "Critical Overflow Bug"))
			b.shapes.append(targeted(at(stacker + side), 3.0, 2, "Critical Synchronization Bug"))
		if turn < 3:
			for side in 2:
				pos(blue + side, positions[at(stacker + side)] + Vector2(0, 0.5))
				pos(green + side, positions[at(defam + side)] + Vector2(0, 0.5))
			b = beat("Hello World %d/4 · collect rot" % (turn + 1), 5.0, "Touch only your correct rot source, then separate before the expiry AoEs.")
			for side in 2:
				b.checks.append(pair(at(blue + side), at(stacker + side), 0, 1.2, "Transfer stack rot"))
				b.checks.append(pair(at(green + side), at(defam + side), 0, 1.2, "Transfer defam rot"))
			preview_blue_break(blue, stacker, turn)
			preview_green_break(green, defam, turn)
		else:
			# Final iteration reverses the order. Debugger prevents fresh Nisi;
			# never teach an unnecessary fourth contact-transfer step.
			preview_green_break(green, defam, turn)
			preview_blue_break(blue, stacker, turn)

func preview_blue_break(blue: int, stacker: int, turn: int) -> void:
	for side in 2: pos(blue + side, Vector2(-17 if side == 0 else 17, 7))
	for side in 2: pos(stacker + side, Vector2(-10 if side == 0 else 10, 14))
	var b = beat("Hello World %d/4 · break BLUE %s" % [turn + 1, "LAST" if turn == 3 else "first"], 5.0)
	b.checks.append(pair(at(blue), at(blue + 1), 30, 40, "Remote Regression"))
	for side in 2: b.shapes.append(targeted(at(stacker + side), 4, 1, "Rot expiry"))
func preview_green_break(green: int, defam: int, turn: int) -> void:
	for side in 2: pos(green + side, Vector2(-1 if side == 0 else 1, -4))
	for side in 2: pos(defam + side, Vector2(-12 if side == 0 else 12, -12))
	var b = beat("Hello World %d/4 · break GREEN %s" % [turn + 1, "FIRST (final iteration)" if turn == 3 else "after vulnerability"], 5.0, "Final iteration: Local first, then Remote; do not pass Nisi. Other iterations: Blue before Green.")
	b.checks.append(pair(at(green), at(green + 1), 0, 3, "Local Regression"))
	for side in 2: b.shapes.append(targeted(at(defam + side), 4, 1, "Rot expiry"))

func monitors() -> void:
	var saved_order: Array = order.duplicate()
	var p3_roles: Array = profile.get("p3_priority", profile.priority)
	var m_holders: Array = order.slice(0, 3)
	var non_holders: Array = order.slice(3, 8)
	m_holders.sort_custom(func(a, b): return p3_roles.find(ROLES[a]) < p3_roles.find(ROLES[b]))
	non_holders.sort_custom(func(a, b): return p3_roles.find(ROLES[a]) < p3_roles.find(ROLES[b]))
	order = m_holders + non_holders
	var sign_x = 1 if rng.randi_range(0, 1) else -1
	var canonical = [Vector2(-7, -11), Vector2(-13, -3), Vector2(-13, 3), Vector2(0, -16), Vector2(3, 0), Vector2(15, 0), Vector2(0, 10), Vector2(0, 16)]
	for i in 8:
		pos(i, Vector2(canonical[i].x * sign_x, canonical[i].y))
		label(i, "MONITOR %d" % (i + 1) if i < 3 else "No monitor %d" % (i - 2))
	var b = beat("Oversampled Wave Cannon · %s" % ("EAST" if sign_x == 1 else "WEST"), 10.0, "Astoh geometry drill: each of four monitor sources must see exactly two people. Face with Q/E or right-click.")
	var sources: Array = [{"kind": "half", "angle": 90 * sign_x, "radius": 45, "name": "Boss monitor"}]
	var goals = [270.0 * sign_x, 0.0, 180.0]
	for i in 3:
		var offset = 90.0 if rng.randi_range(0, 1) else -90.0
		b.facing[at(i)] = goals[i] - offset
		sources.append({"kind": "half", "actor": at(i), "face_actor": at(i), "offset": offset, "radius": 45, "exclude": [at(i)], "name": "Player monitor"})
	b.checks.append({"kind": "monitors", "sources": sources, "name": "Oversampled Wave Cannon"})
	b.monitors = sources
	order = saved_order

func p4_wave() -> void:
	var left = [0, 6, 2, 4]; var right = [1, 7, 3, 5]
	for turn in 3:
		var marked = [rng.randi_range(0, 7), rng.randi_range(0, 7)]
		while marked[0] == marked[1]: marked[1] = rng.randi_range(0, 7)
		for i in 4:
			positions[left[i]] = polar(250 + i * -14, 13 if turn != 1 else 17)
			positions[right[i]] = polar(110 + i * 14, 13 if turn != 1 else 17)
		var b = beat("Blue Screen · proteans %d/3" % (turn + 1), 6.0, "TRHM north→south. Remember both stack targets; dodge the old beams before stacking.")
		spread(b, range(8), 1.8)
		var old_shapes: Array = []
		for i in 8:
			var echo = line(Vector2.ZERO, rad_to_deg(atan2(positions[i].x, -positions[i].y)), 2.3, "Wave Cannon echo")
			echo.snapshot_direction_actor = i
			old_shapes.append(echo)
		var a = left.duplicate(); var c = right.duplicate()
		if (marked[0] in a) == (marked[1] in a):
			var from: Array = a if marked[0] in a else c
			var to: Array = c if marked[0] in a else a
			var selected: int = marked[0] if from.find(marked[0]) > from.find(marked[1]) else marked[1]
			var flex = 5 if to == right else 4
			from.erase(selected); to.erase(flex); from.append(flex); to.append(selected)
		group_goals(a, polar(270, 9 if turn == 1 else 16), 0.15)
		group_goals(c, polar(90, 9 if turn == 1 else 16), 0.15)
		b = beat("Blue Screen · stack/flex %d/3" % (turn + 1), 7.0, "Lowest stack crosses; opposite melee flexes. Wave Repeater timing changes between sets.")
		b.shapes = old_shapes
		for i in marked: b.shapes.append(targeted(i, 3, 4, "Condensed Wave Cannon"))
		if turn > 0: b.shapes.append({"kind": "donut", "inner": 12 if turn == 1 else 0, "radius": 22 if turn == 1 else 12, "name": "Wave Repeater"})

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
	for i in [0, 1, 4, 5]:
		var outer: Vector2 = positions[at(i)]
		var needs_swap: bool = colours[(i / 4) * 4] == colours[(i / 4) * 4 + 2]
		var destination: int = (i + 1 if i % 2 == 0 else i - 1) if needs_swap else i
		pos(i + 2, positions[at(destination)] + Vector2(0.5, 0))
	b = beat("Delta · Rocket Punch pair bait", 6.0, "Each blue fist must meet one yellow fist. Record these bait locations before moving.")
	b.checks.append({"kind": "fists", "colours": actor_colours, "name": "Rocket Punch"})
	var fists: Array = []
	for i in [0, 1, 4, 5]:
		b.shapes.append(targeted(at(i), 2, 2, "Rocket Punch · opposite colours"))
		var fist = circle(positions[at(i)], 5, "Rocket Punch snapshot"); fist.snapshot_position_actor = at(i)
		fists.append(fist)
	for i in 8: pos(i, polar(22.5 + i * 45, 17))
	pos(2, Vector2(-2, -2)); pos(3, Vector2(2, 2))
	b = beat("Delta · leave fists / bait spinning arm lasers", 7.0)
	b.shapes = fists
	b.checks.append(pair(at(2), at(3), 4, 40, "Inner BLUE now breaks"))
	var arm_shapes: Array = []; var rotated_shapes: Array = []; var rotation_sources: Array = []
	var bait_slots := [0, 1, 4, 5, 6, 7]
	for j in 6:
		var radial := polar(30 + j * 60, 1)
		var rotation_sign: int = 1 if rng.randi_range(0, 1) else -1
		var tangent := radial.rotated(PI / 2)
		var origin: Vector2 = radial * 24
		pos(bait_slots[j], radial * 17 - tangent * rotation_sign * 6)
		var bait_actor: int = at(bait_slots[j])
		var axis: Vector2 = (positions[bait_actor] - origin).normalized()
		var base_angle: float = rad_to_deg(atan2(axis.x, -axis.y))
		arm_shapes.append({"kind": "line", "decorative": true, "pos": origin, "target": bait_actor, "width": 2.5, "length": 45, "rule": "count", "count": 1, "required": [bait_actor], "name": "Arm bait " + ("CW" if rotation_sign > 0 else "CCW")})
		rotated_shapes.append({"kind": "line", "pos": origin, "angle": base_angle + rotation_sign * 90, "width": 2.5, "length": 45, "name": "Rotating Hyper Pulse"})
		rotation_sources.append({"pos": origin, "target": bait_actor, "turn": rotation_sign * 90})
		labels[bait_actor] += " · ARM " + ("CW" if rotation_sign > 0 else "CCW")
	pos(2, Vector2(-2, -2)); pos(3, Vector2(2, 2))
	b = beat("Delta · bait six rotating arms", 8.0, "Read each CW/CCW arrow. Bait on the side that makes the rotating laser sweep outward.")
	b.shapes = arm_shapes
	for j in 6: b.checks.append({"kind": "closest", "pos": arm_shapes[j].pos, "members": [at(bait_slots[j])], "count": 1, "name": "Nearest arm bait"})
	b = beat("Delta · arms rotate outward", 3.0)
	b.shapes = rotated_shapes
	b.rotation_sources = rotation_sources
	# A single monitor and the boss monitor each choose two green-tether players.
	for i in 8: pos(i, Vector2(-1 + (i % 3) * 0.25, 3))
	pos(0, Vector2(-10, 0)); pos(1, Vector2(-2, 5)); pos(2, Vector2(-1, 5)); pos(3, Vector2(0, 5))
	pos(4, Vector2(-13, -10)); pos(5, Vector2(13, -10)); pos(6, Vector2(-13, 12)); pos(7, Vector2(13, 12))
	b = beat("Delta · monitors + Beyond Defense exclusion", 9.0, "Beyond Defense victim stays out of Pile Pitch. Player monitor points away from the boss monitor.")
	b.facing[at(1)] = 90.0
	b.shapes.append(targeted(at(0), 4, 1, "Beyond Defense")); b.shapes.append(targeted(at(2), 3, 3, "Pile Pitch"))
	b.shapes.append({"kind": "half", "angle": 0, "radius": 45, "rule": "count", "count": 2, "required": [at(4), at(5)], "name": "Final Omega monitor"})
	b.shapes.append({"kind": "half", "actor": at(1), "face_actor": at(1), "offset": 90, "radius": 45, "exclude": [at(1)], "rule": "count", "count": 2, "required": [at(6), at(7)], "name": "Player monitor"})
	# Training snapshot makes the GREEN break order explicit.
	world_snapshot([at(0), at(1), at(4), at(5), at(6), at(7), at(2), at(3)], "Delta · Near/Far + first GREEN break", true, 0)
	b = beats[-1]
	b.shapes.append({"kind": "half", "angle": 0, "radius": 45, "name": "Diffuse Wave Cannon · safe half"})
	b.note = "First green pair breaks before worlds; last pair waits for vulnerability to wear off. No early double patch."
	pos(6, Vector2(-1, 12)); pos(7, Vector2(1, 12))
	b = beat("Delta · last GREEN breaks after vulnerability", 6.0)
	b.checks.append(pair(at(6), at(7), 0, 3, "Last Local Regression"))

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
	for i in 4: b.checks.append(pair(at(i * 2), at(i * 2 + 1), 32 if remote else 18, 40 if remote else 27, "Sigma Glitch"))
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
	for i in 4: b.checks.append(pair(at(i * 2), at(i * 2 + 1), 32 if remote else 18, 40 if remote else 29, "Sigma landing Glitch"))
	if rng.randi_range(0, 1): rotate_beat(b, 180)
	var rotate_direction = 1 if rng.randi_range(0, 1) else -1
	for j in 7:
		for i in 8: pos(i, polar(20 + rotate_direction * j * 20 + (0 if i < 3 else 180), 13))
		b = beat("Sigma · rotating Rear Power Unit %d/7" % (j + 1), 2.6, "Follow the rotating laser; training groups the fourteen shots into seven movement checkpoints.")
		b.shapes.append(line(Vector2.ZERO, rotate_direction * j * 20, 4, "Rear Power Unit"))
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
	world_snapshot(assignment, "Omega · first World + two-stack monitors", false, 0)
	var b: Dictionary = beats[-1]
	b.shapes.append({"kind": "half", "angle": 90, "radius": 45, "rule": "count", "count": 2, "required": monitors_pair, "name": "Omega monitors"})
	for i in assignment.slice(0, 6): stacks[i] = mini(3, int(stacks[i]) + 1)
	var three: Array = []
	for i in 8:
		if stacks[i] == 3: three.append(i)
	others = []
	for i in 8:
		if i not in second_holders and i not in three: others.append(i)
	assignment = [second_holders[0], second_holders[1], others[0], others[1], others[2], others[3], three[0], three[1]]
	world_snapshot(assignment, "Omega · second World + three-stack tethers", false, 0)
	b = beats[-1]
	b.checks.append({"kind": "dynamis", "value": [3, 3, 3, 3, 3, 3, 3, 3], "name": "P6 entry"})
	b.note = "Players already at three stacks take beetle tethers; everyone else gets the final World. Snapshot model omits the earlier Blaster explosion."

static func select_monitors(stacks: Array, first: Array, second: Array) -> Array:
	var result: Array = []
	for i in second:
		if stacks[i] == 2 and i not in first: result.append(i)
	for i in 8:
		if result.size() >= 2: break
		if stacks[i] == 2 and i not in first and i not in result: result.append(i)
	return result

func omega_dodges() -> void:
	var first_angle = float(rng.randi_range(0, 3) * 90)
	var turn = 90 if rng.randi_range(0, 1) else -90
	for step in 2:
		var sword = bool(rng.randi_range(0, 1)); var legs = bool(rng.randi_range(0, 1))
		var radius = 5.0 if legs else (17.0 if sword else 11.5)
		var deg = first_angle + step * turn
		for i in 8: pos(i, polar(deg, radius) + Vector2(i * 0.03, 0))
		var b = beat("Omega dodge %d/2 · %s + %s" % [step + 1, "SWORD" if sword else "SHIELD", "LEGS" if legs else "STAFF"], 7.0, "Legs: near, away from sword / towards shield. Staff: toward M, far for sword / middle for shield. Second safe cardinal is ±90°.")
		# This drill encodes the resulting cardinal/radial safe sectors, not misleading clone hitboxes.
		b.shapes.append({"kind": "cone", "angle": deg + 180, "width": 320, "radius": 40, "name": "M/F + Diffuse Wave Cannon (safe cardinal gap)"})
		b.shapes.append({"kind": "donut", "inner": radius + 2.5, "radius": 40, "name": "Wrong distance band"})
		if radius > 3: b.shapes.append(circle(Vector2.ZERO, radius - 2.5, "Wrong distance band"))

func intended_stacks() -> Array:
	var values: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	for item in beats:
		for check in item.checks:
			if check.kind == "world":
				for actor in check.near_path + check.far_path: values[int(actor)] = mini(3, values[int(actor)] + 1)
	return values

func world_snapshot(assignment: Array, title: String, safe_half: bool, rotation: float) -> void:
	# Six intended world recipients, then two non-participants. Nearest/furthest
	# selections and clipping are recomputed from actual positions by Rules.
	var points = [Vector2(-10, -1), Vector2(0, 8), Vector2(-18, 0), Vector2(-17, 7), Vector2(0, -18), Vector2(0, 18), Vector2(12, -6), Vector2(12, 6)]
	if safe_half: points = [Vector2(-7, 6), Vector2(-2, 16), Vector2(-14, 8), Vector2(-12, 14), Vector2(18, 1), Vector2(-18, 1), Vector2(4, 7), Vector2(9, 11)]
	for i in 8:
		positions[int(assignment[i])] = rotated(points[i], rotation)
		labels[int(assignment[i])] = ["HELLO NEAR", "HELLO DISTANT", "NEAR jump 1", "NEAR jump 2", "FAR jump 1", "FAR jump 2", "NO World / utility 1", "NO World / utility 2"][i]
	var b = beat(title, 10.0, "Near jumps to nearest → nearest; Far jumps to furthest → furthest. Original holder remains eligible: avoid bounce-back and clipping.")
	b.checks.append({"kind": "world", "near": assignment[0], "far": assignment[1], "near_path": [assignment[0], assignment[2], assignment[3]], "far_path": [assignment[1], assignment[4], assignment[5]], "holder_radius": 5, "jump_radius": 2.5})
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
		b.shapes.append(targeted(turn, 4, 1, "Solar Ray"))
		b.checks.append({"kind": "aggro", "actor": turn, "name": "Solar Ray swap"})

func lb_check(item: Dictionary, type: String, actor: int, name: String) -> void:
	item.checks.append({"kind": "lb", "type": type, "eligible": [actor], "name": name})
	item.note += " LB: %s (%s), press F during this window. Other roles are handled by bots." % [ROLES[actor], type]

func memory() -> void:
	group_goals(range(8), Vector2(0, 5))
	var b = beat("Cosmo Memory · Tank LB3", 8.0, "All eight players need three Dynamis stacks. This is an LB timing drill, not an HP/shield simulation.")
	b.checks.append({"kind": "dynamis", "value": [3, 3, 3, 3, 3, 3, 3, 3]})
	lb_check(b, "tank", 0, "Cosmo Memory")

func cosmo_arrow(with_waves: bool) -> void:
	var inside_first = bool(rng.randi_range(0, 1))
	# Schematic strips preserve the in/wait/out cadence. Real arrows travel as
	# crossing orthogonal strips; do not represent them as circular rings.
	var radii: Array = [5.0, 5.0, 11.0, 11.0, 16.0, 6.0] if inside_first else [16.0, 16.0, 7.0, 16.0, 6.0]
	for j in radii.size():
		var r: float = radii[j]
		for i in 8:
			positions[i] = polar(45, r) if not with_waves or j < radii.size() - 2 else polar(i * 45, r)
		var b = beat("Cosmo Arrow · %s-first · dodge %d/%d" % ["IN" if inside_first else "OUT", j + 1, radii.size()], 4.5, "Watch the crossing line strips, not an invented circle AoE. Training cadence is slowed.")
		var lane = r / sqrt(2.0)
		for axis in [0, 90]:
			for offset in [-18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0]:
				# Keep the currently required band open on both x and z.
				if absf(absf(offset) - lane) < 3.5: continue
				b.shapes.append(line(Vector2(offset, 0) if axis == 0 else Vector2(0, offset), axis, 2.2, "Cosmo Arrow travelling strip"))
		if with_waves and j >= radii.size() - 2:
			# Role clock positions avoid overlap while still respecting both strip axes.
			b.shapes = []
			for i in 8:
				var a = 22.5 + i * 45
				positions[i] = polar(a, r)
			b.positions = positions.duplicate()
			var targets = [0, 2, 4, 6] if j == radii.size() - 2 else [1, 3, 5, 7]
			for actor in targets: b.shapes.append({"kind": "line", "pos": Vector2.ZERO, "target": actor, "width": 2.0, "length": 40, "rule": "count", "count": 1, "name": "Wave Cannon spread"})
			# All eight clock positions have two shared absolute x/z lane values.
			# Keep those lanes safe while retaining simultaneous crossing strips.
			var safe_x: float = absf(positions[0].x)
			var safe_y: float = absf(positions[0].y)
			for axis in [0, 90]:
				for offset in [-18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0]:
					if minf(absf(absf(offset) - safe_x), absf(absf(offset) - safe_y)) < 1.7: continue
					b.shapes.append(line(Vector2(offset, 0) if axis == 0 else Vector2(0, offset), axis, 2.2, "Concurrent Cosmo Arrow"))

func cosmo_dive() -> void:
	positions[0] = Vector2(-4, -4); positions[1] = Vector2(4, -4)
	group_goals([2, 3, 4, 5, 6, 7], Vector2(0, 14), 0.25)
	var b = beat("Cosmo Dive · nearest two tanks / furthest six-stack", 7.0)
	b.checks.append({"kind": "closest_tanks"})
	for ordinal in 2:
		var hit = targeted(ordinal, 5, 1, "Cosmo Dive tank"); hit.dynamic_actor = {"selector": "closest", "ordinal": ordinal}; b.shapes.append(hit)
	var stack = targeted(7, 4, 6, "Cosmo Dive party"); stack.dynamic_actor = {"selector": "furthest", "ordinal": 0}; b.shapes.append(stack)

func exaflares() -> void:
	var clockwise = 1 if rng.randi_range(0, 1) else -1
	var start = angle
	for j in 6:
		var deg = start + clockwise * (67.5 + j * 22.5)
		for i in 8: positions[i] = polar(deg, 12) + Vector2(0.04 * i, 0)
		var b = beat("Unlimited Wave Cannon · bait %d/6 · %s" % [j + 1, "CW" if clockwise == 1 else "CCW"], 3.0, "Begin 1.5 waymarks from the first exaflare, then follow the arc. Six baited AoEs.")
		for stream in 4:
			var exa_angle = start + clockwise * (j * 22.5 - stream * 22.5)
			b.shapes.append(circle(polar(exa_angle, 17), 5.0, "Exaflare stream"))
		if j > 0:
			for actor in 8:
				var puddle = circle(polar(deg - clockwise * 22.5, 12), 4.0, "Baited wave (previous snapshot)")
				puddle.snapshot_position_actor = actor; b.shapes.append(puddle)
		b.shapes.append({"kind": "circle", "pos": polar(start, 22), "radius": 2.0, "decorative": true, "name": "First exaflare indicator"})

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
	for turn in 4:
		for i in 8: positions[i] = polar([45, 90, 135, 180, 225, 270, 0, 315][i], 14)
		positions[6] = Vector2(0, -16)
		var b = beat("Cosmo Meteor · spread wave %d/4" % (turn + 1), 6.0, "Caster LB3 destroys comets; ranged LB3 finishes both north/south meteors. Role actions are enforced.")
		spread(b, [0, 2, 4, 6] if turn % 2 == 0 else [1, 3, 5, 7], 3.5)
		if turn == 0: lb_check(b, "caster", 7, "Cosmo Comets")
		if turn == 3: lb_check(b, "ranged", 6, "Cosmo Meteors")
	var prange_flare = bool(rng.randi_range(0, 1))
	var flare_actors: Array = [6, 4, 5] if prange_flare else [2, 4, 5]
	var stack_members: Array = []
	for i in 8:
		if i not in flare_actors: stack_members.append(i)
	group_goals(stack_members, Vector2(0, 14 if prange_flare else -14), 0.2)
	for j in 3: positions[flare_actors[j]] = polar((0 if prange_flare else 180) if j == 0 else (90 if j == 1 else 270), 18)
	var b = beat("Cosmo Meteor · flares + five-stack · D3 %s" % ("HAS flare" if prange_flare else "NO flare"), 9.0, "D3 is animation-locked by LB. Others adjust: stack south if D3 has flare, north otherwise.")
	for actor in flare_actors: b.shapes.append(targeted(actor, 12.0, 1, "Cosmo Meteor flare"))
	b.shapes.append(targeted(stack_members[0], 3, 5, "Cosmo Meteor stack"))

func magic_number() -> void:
	group_goals(range(8), Vector2(0, 5), 0.2)
	for turn in 2:
		var b = beat("Magic Number %d/2 · TANK LB3 before hit" % (turn + 1), 7.0)
		lb_check(b, "tank", turn, "Magic Number mitigation")
		b = beat("Magic Number %d/2 · HEALER LB3 within 6s" % (turn + 1), 6.0, "Only healer LB3 removes Magic Number; ordinary cleanses do not work.")
		lb_check(b, "healer", turn + 2, "Magic Number cleanse")
