# SPDX-License-Identifier: MIT
extends RefCounted
## Pure geometry and encounter rules; never reads the suggested positions.

static func v(p) -> Vector2:
	if p is Vector2: return p
	return Vector2(float(p[0]), float(p[1]))

static func direction(degrees: float) -> Vector2:
	return Vector2(sin(deg_to_rad(degrees)), -cos(deg_to_rad(degrees)))

static func selected_actor(shape: Dictionary, actors: Array) -> int:
	var selection: Dictionary = shape.dynamic_actor
	var origin: Vector2 = v(selection.get("pos", Vector2.ZERO))
	var candidates: Array = range(actors.size())
	candidates.sort_custom(func(a, b): return v(actors[a].pos).distance_squared_to(origin) < v(actors[b].pos).distance_squared_to(origin) if selection.selector == "closest" else v(actors[a].pos).distance_squared_to(origin) > v(actors[b].pos).distance_squared_to(origin))
	return int(candidates[int(selection.get("ordinal", 0))])

static func point(shape: Dictionary, actors: Array) -> Vector2:
	if shape.has("dynamic_actor") and not shape.get("dynamic_aim", false): return v(actors[selected_actor(shape, actors)].pos)
	if shape.has("actor"): return v(actors[int(shape.actor)].pos)
	return v(shape.get("pos", [0, 0]))

static func aim(shape: Dictionary, actors: Array) -> Vector2:
	if shape.has("dynamic_actor") and shape.get("dynamic_aim", false): return (v(actors[selected_actor(shape,actors)].pos) - point(shape,actors)).normalized()
	if shape.has("target"): return (v(actors[int(shape.target)].pos) - point(shape, actors)).normalized()
	if shape.has("face_actor"):
		return direction(float(actors[int(shape.face_actor)].face) + float(shape.get("offset", 0)))
	return direction(float(shape.get("angle", 0)))

static func contains(shape: Dictionary, pos: Vector2, actors: Array) -> bool:
	var delta = pos - point(shape, actors)
	var distance = delta.length()
	match shape.get("kind", "circle"):
		"circle", "tower", "stack", "spread", "flare":
			return distance <= float(shape.get("radius", 3)) + 0.001
		"donut":
			return distance >= float(shape.get("inner", 0)) - 0.001 and distance <= float(shape.get("radius", 20)) + 0.001
		"line":
			var axis = aim(shape, actors)
			var projection = delta.dot(axis)
			return projection >= float(shape.get("start", 0)) and projection <= float(shape.get("length", 45)) and absf(delta.cross(axis)) <= float(shape.get("width", 3)) / 2.0
		"cone", "half":
			var width: float = 180.0 if shape.kind == "half" else float(shape.get("width", 90))
			return distance > 0.01 and distance <= float(shape.get("radius", 45)) and delta.normalized().dot(aim(shape, actors)) > cos(deg_to_rad(width / 2.0)) + 0.00001
	return false

static func hits(shape: Dictionary, actors: Array) -> Array:
	var result: Array = []
	for i in actors.size():
		if i in shape.get("exclude", []): continue
		if contains(shape, v(actors[i].pos), actors): result.append(i)
	return result

static func chain(start: int, far: bool, actors: Array) -> Array:
	# Original holder remains eligible after the first jump (a bounce-back kills).
	var path: Array = [start]
	for jump in 2:
		var candidate = -1
		var best: float = -INF if far else INF
		for i in actors.size():
			if i == int(path[-1]): continue
			var distance = v(actors[i].pos).distance_squared_to(v(actors[int(path[-1])].pos))
			if (far and distance > best) or (not far and distance < best):
				best = distance
				candidate = i
		path.append(candidate)
	return path

static func evaluate(beat: Dictionary, actors: Array, state: Dictionary) -> Array:
	var failures: Array = []
	if beat.has("program_loop"): ensure_loop_state(beat, state)
	for i in actors.size():
		if v(actors[i].pos).length() >= 20.0: failures.append("%s: death wall" % actors[i].role)
	for shape in beat.get("shapes", []):
		if shape.get("decorative", false): continue
		var caught = hits(shape, actors)
		var name: String = shape.get("name", "AoE")
		match shape.get("rule", "avoid"):
			"avoid":
				for i in caught: failures.append("%s: %s" % [actors[i].role, name])
			"count":
				if caught.size() != int(shape.get("count", 1)): failures.append("%s: %d / %d players" % [name, caught.size(), int(shape.get("count", 1))])
				if shape.has("required") and not same_members(caught, shape.required): failures.append("%s: wrong players / wrong debuff" % name)
				if shape.get("looper_tower", false) and caught.size() == 1:
					var actor: int = caught[0]
					if bool(state.loop_cleansed[actor]): failures.append("Storage Violation Obliteration: %s has no Looper" % actors[actor].role)
					else:
						state.loop_cleansed[actor] = true
						if float(state.loop_hp_penalty[actor]) > float(state.get("sim_time", 0.0)): failures.append("%s: tower damage while HP Penalty active" % actors[actor].role)
						apply_loop_ruin(actor, state, actors, failures, "Storage Violation")
			"tankbuster":
				for actor in caught:
					if actor >= 2: failures.append("%s: %s hit a non-tank" % [actors[actor].role, name])
			"blaster":
				for actor in caught:
					apply_loop_ruin(actor, state, actors, failures, "Blaster")
					state.loop_hp_penalty[actor] = float(state.get("sim_time", 0.0)) + 16.0
	for check in beat.get("checks", []):
		var name: String = check.get("name", check.kind)
		match check.kind:
			"distance":
				var distance = v(actors[int(check.a)].pos).distance_to(v(actors[int(check.b)].pos))
				if distance < float(check.get("min", 0)) or distance > float(check.get("max", INF)): failures.append("%s: %.1fy" % [name, distance])
			"monitors":
				var coverage = []
				coverage.resize(8)
				coverage.fill(0)
				for source in check.sources:
					var caught = hits(source, actors)
					if caught.size() != 2: failures.append("%s: monitor needs exactly 2 targets (got %d)" % [name, caught.size()])
					for i in caught: coverage[i] += 1
				for i in 8:
					if coverage[i] != 1: failures.append("%s: %s targeted %d times" % [name, actors[i].role, coverage[i]])
			"world":
				var near_path = chain(int(check.near), false, actors)
				var far_path = chain(int(check.far), true, actors)
				# Actual jumps need not match a guide's suggested assignment. Repeated hits,
				# splash overlaps and the resulting Dynamis state determine failure.
				var touched: Array = []
				for path in [near_path, far_path]:
					for j in 3:
						var receiver: int = path[j]
						if receiver in touched: failures.append("Hello World: double-hit / bounce back")
						touched.append(receiver)
						var blast = {"actor": receiver, "radius": float(check.get("holder_radius", 5)) if j == 0 else float(check.get("jump_radius", 2.5))}
						if hits(blast, actors).size() != 1: failures.append("Hello World: AoE clipped another player")
				if failures.is_empty():
					for i in touched: state.dynamis[i] = mini(3, int(state.dynamis[i]) + 1)
			"dynamis":
				if state.dynamis != check.value: failures.append("Dynamis: expected %s; got %s" % [str(check.value), str(state.dynamis)])
			"closest_tanks":
				var ordered = range(8)
				ordered.sort_custom(func(a, b): return v(actors[a].pos).length_squared() < v(actors[b].pos).length_squared())
				if not same_members(ordered.slice(0, 2), [0, 1]): failures.append("Cosmo Dive: two closest players must be tanks")
			"furthest_tanks":
				var ordered = range(8)
				ordered.sort_custom(func(a, b): return v(actors[a].pos).length_squared() > v(actors[b].pos).length_squared())
				if not same_members(ordered.slice(0, 2), [0, 1]): failures.append("Diffuse Wave Cannon: tanks must be furthest")
			"closest", "furthest":
				var origin = v(check.pos)
				var ordered = range(8)
				ordered.sort_custom(func(a, b): return (v(actors[a].pos).distance_squared_to(origin) < v(actors[b].pos).distance_squared_to(origin)) if check.kind == "closest" else (v(actors[a].pos).distance_squared_to(origin) > v(actors[b].pos).distance_squared_to(origin)))
				if not same_members(ordered.slice(0, int(check.count)), check.members): failures.append(name + ": wrong closest players")
			"aggro":
				if int(state.get("aggro", 0)) != int(check.actor): failures.append(name + ": wrong tank holding aggro")
			"front_tanks":
				var axis = direction(float(check.get("angle", 90)))
				var ordered = range(8)
				ordered.sort_custom(func(a, b): return v(actors[a].pos).dot(axis) < v(actors[b].pos).dot(axis))
				if not same_members(ordered.slice(0, 2), [0, 1]): failures.append("Wave Cannon: both tanks must be in front")
			"lb":
				var requested: String = check.type
				if state.get("lb", "") != requested or int(state.get("lb_actor", -1)) not in check.eligible: failures.append("%s: missing/wrong-role Limit Break" % name)
				else:
					var actor: int = state.lb_actor
					if actor in state.get("spent", []): failures.append("Limit Break: Brilliant Dynamis already spent")
					else: state.spent.append(actor)
				state.lb = ""
			"fists":
				for i in actors.size():
					var neighbours: Array = []
					for j in actors.size():
						if i != j and v(actors[i].pos).distance_to(v(actors[j].pos)) <= 1.5: neighbours.append(j)
					if neighbours.size() != 1: failures.append("Rocket Punch: must pair with exactly one fist")
					elif check.colours[i] == check.colours[neighbours[0]]: failures.append("Rocket Punch: same-colour fists / inner pair must swap")
			"tether_tanks":
				if not same_members(state.get("tether_holders", []), [0, 1]): failures.append("Optimized Bladedance: non-tank holds a tankbuster tether")
			"facing":
				var delta = wrapf(float(actors[int(check.actor)].face) - float(check.angle), -180, 180)
				if absf(delta) > float(check.get("tolerance", 15)): failures.append("%s: wrong facing" % name)
	if beat.has("program_loop"):
		for actor in actors.size():
			if int(beat.program_loop.numbers[actor]) <= int(beat.program_loop.round) and not bool(state.loop_cleansed[actor]):
				failures.append("%s: Looper expired → Memory Loss / death wall" % actors[actor].role)
	return failures

static func ensure_loop_state(beat: Dictionary, state: Dictionary) -> void:
	if state.has("loop_cleansed"): return
	state.loop_cleansed = []; state.loop_ruin_expires = []; state.loop_hp_penalty = []
	for _i in 8:
		state.loop_cleansed.append(false); state.loop_ruin_expires.append(0.0); state.loop_hp_penalty.append(0.0)
static func apply_loop_ruin(actor: int, state: Dictionary, actors: Array, failures: Array, cause: String) -> void:
	var now := float(state.get("sim_time", 0.0))
	if float(state.loop_ruin_expires[actor]) > now: failures.append("%s: Twice-come Ruin ×2 → Doom (%s)" % [actors[actor].role, cause])
	state.loop_ruin_expires[actor] = now + 16.0

static func same_members(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for value in a:
		if a.count(value) != b.count(value): return false
	return true
