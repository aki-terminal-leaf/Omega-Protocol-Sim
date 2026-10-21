# SPDX-License-Identifier: MIT
extends RefCounted
## Runtime contacts, not a solution-position validator. Pickup radius is configurable.
const Statuses = preload("res://scripts/statuses.gd")
const PICKUP_RADIUS := 0.65
const NAV_CLEARANCE := 1.0

static func begin(beat: Dictionary, actors: Array, state: Dictionary) -> void:
	state.loop_refuges = {}
	Statuses.begin(beat, state)
	Statuses.sync(beat, state)
	sync_followups(beat,state)
	if not beat.has("transfers"): return
	var config: Dictionary = beat.transfers
	if state.get("tether_group", "") != config.group:
		state.tether_group = config.group
		state.tether_holders = config.initial.duplicate()
		state.tether_contacts = [[], []]
		state.tether_events = state.get("tether_events", [])
		state.tether_routes = {}
	sync(beat, state)
	# A new wave does not assign a new owner: previous owners keep their lines.

static func sync(beat: Dictionary, state: Dictionary) -> void:
	Statuses.sync(beat, state)
	sync_followups(beat,state)
	if not beat.has("transfers"): return
	beat.transfers.holders = state.tether_holders.duplicate()
	if beat.transfers.group == "limitless":
		for k in state.tether_holders.size():
			var carrier: int = state.tether_holders[k]
			if carrier < 2:
				var source: Vector2 = beat.transfers.sources[k]
				beat.positions[carrier] = Vector2(-16 if source.x < 0 else 16, -5)
	if beat.has("program_loop"): beat.program_loop.holders = state.tether_holders.duplicate()
	for shape in beat.get("shapes", []):
		if shape.has("tether_index"):
			var holder: int = state.tether_holders[int(shape.tether_index)]
			if shape.get("kind", "circle") == "cone": shape.target = holder
			else: shape.actor = holder
	beat.tethers = []
	for k in state.tether_holders.size():
		beat.tethers.append({"a": state.tether_holders[k], "b": -1, "source": beat.transfers.sources[k]})

static func sync_followups(beat: Dictionary,state: Dictionary) -> void:
	if not beat.get("defense_followup",false):return
	for actor in beat.positions.size():
		beat.positions[actor]=Vector2(-12,-10) if actor in state.get("defense_victims",[]) else Vector2(-9,3)+Vector2(actor*0.1,0)

static func tick(beat: Dictionary, actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	state.sim_time = float(state.get("sim_time", 0.0)) + dt
	Statuses.tick(actors, previous, state, dt)
	Statuses.sync(beat, state)
	sync_followups(beat,state)
	if not beat.has("transfers"): return
	if not state.has("tether_holders"): begin(beat, actors, state)
	var old_holders: Array = state.tether_holders.duplicate()
	var policy: String = beat.transfers.get("ownership_policy", Statuses.parameter("double_line_policy"))
	var pickup_radius := float(beat.transfers.get("pickup_radius", Statuses.parameter("pickup_radius")))
	for k in old_holders.size():
		var holder: int = old_holders[k]
		var source: Vector2 = beat.transfers.sources[k]
		var old_holder: Vector2 = previous[holder].pos
		var new_holder: Vector2 = actors[holder].pos
		var winner := -1
		var first := INF
		for i in actors.size():
			if i == holder or (policy == "unverified_exclusive" and i in state.tether_holders): continue
			var old_pos: Vector2 = previous[i].pos
			var new_pos: Vector2 = actors[i].pos
			# Swept moving-point / moving-segment contacts: fast crossings cannot tunnel.
			var steps: int = maxi(1, ceili((old_pos.distance_to(new_pos) + old_holder.distance_to(new_holder)) / 0.15))
			var was_inside: bool = i in state.tether_contacts[k]
			for sample in range(steps + 1):
				var t := float(sample) / steps
				var p := old_pos.lerp(new_pos, t)
				var q := old_holder.lerp(new_holder, t)
				var inside := p.distance_to(Geometry2D.get_closest_point_to_segment(p, source, q)) <= pickup_radius
				if inside and not was_inside and t < first:
					winner = i; first = t; break
				was_inside = inside
		if winner >= 0:
			state.tether_holders[k] = winner
			state.tether_events.append({"kind": "tether_pickup", "line": k, "from": holder, "to": winner, "time": snappedf(float(state.sim_time) - dt + first * dt, 0.001)})
			Statuses.event(state,"tether_pickup",state.tether_events[-1])
			state.tether_routes.clear()
		var endpoint: Vector2 = actors[int(state.tether_holders[k])].pos
		state.tether_contacts[k] = []
		for i in actors.size():
			var p: Vector2 = actors[i].pos
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, source, endpoint)) <= pickup_radius:
				state.tether_contacts[k].append(i)
	sync(beat, state)

static func desired_holders(beat: Dictionary) -> Array:
	return beat.get("transfers", {}).get("wanted", [])

static func bot_goal(actor: int, beat: Dictionary, actors: Array, state: Dictionary) -> Vector2:
	var final: Vector2 = beat.positions[actor]
	# Bots wait out the same raidwide vulnerability that judges player breaks.
	if state.has("statuses") and state.statuses[actor].has("magic_vulnerability"):
		for tether in state.paired_tethers:
			if not tether.broken and actor in [tether.a,tether.b] and float(state.sim_time) >= float(tether.active_at): return actors[actor].pos

	if not beat.has("transfers"): return final
	var holders: Array = state.tether_holders
	var wanted: Array = beat.transfers.wanted
	var pos: Vector2 = actors[actor].pos
	if actor in wanted and actor not in holders:
		var target := Vector2.ZERO
		var best := INF
		for k in holders.size():
			if holders[k] in wanted and holders.count(holders[k]) == 1: continue
			var source: Vector2 = beat.transfers.sources[k]
			var endpoint: Vector2 = actors[int(holders[k])].pos
			# Approach the actual current line, never replace its holder by fiat.
			var t: float = clampf((pos - source).dot(endpoint - source) / maxf(0.01, source.distance_squared_to(endpoint)), 0.2, 0.8)
			var pickup := source.lerp(endpoint, t)
			if actor in state.tether_contacts[k]:
				var normal := (endpoint - source).normalized().orthogonal()
				if normal.length_squared() < 0.1: normal = Vector2.RIGHT
				pickup = pos + normal * 1.5
			if pos.distance_squared_to(pickup) < best: best = pos.distance_squared_to(pickup); target = pickup
		var reserved: Array = []
		for k in holders.size():
			if holders[k] in wanted:
				reserved.append([beat.transfers.sources[k], actors[int(holders[k])].pos])
		if not clear_path(pos,target,reserved):
			return navigate_goal(actor,pos,target,reserved,state)
		return target
	var ready := true
	for h in wanted:
		if h not in holders: ready = false
	# Leave room for collectors to grab and separate before the rest crosses the room.
	if actor not in wanted:
		if not ready:
			for k in holders.size():
				if int(holders[k]) == actor: continue
				var source: Vector2 = beat.transfers.sources[k]
				var end: Vector2 = actors[int(holders[k])].pos
				if pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, source, end)) < 1.1:
					var normal := (end-source).normalized().orthogonal()
					if (pos - Geometry2D.get_closest_point_to_segment(pos,source,end)).dot(normal) < 0: normal = -normal
					return pos + normal * 1.5
			return pos
	# Unassigned Loop players may use ANY safe refuge. Choose a nearby valid refuge,
	# rather than crossing the arena for a particular guide endpoint after releasing a line.
	if ready and beat.has("program_loop") and actor not in wanted and int(beat.program_loop.numbers[actor]) != int(beat.program_loop.round):
		if not state.loop_refuges.has(actor):
			var nearest := INF; var refuge := final
			for x in range(-18,19):
				for y in range(-18,19):
					var candidate := Vector2(x,y)
					if candidate.length() >= 19: continue
					var safe := true
					for h in wanted:
						if candidate.distance_to(beat.positions[h]) < 15.8: safe = false
						if candidate.distance_to(Geometry2D.get_closest_point_to_segment(candidate,Vector2.ZERO,beat.positions[h])) < 1.5: safe = false
					for shape in beat.shapes:
						if shape.get("kind","") == "tower" and candidate.distance_to(shape.pos) < 3.5: safe = false
					if safe and pos.distance_squared_to(candidate) < nearest:
						nearest = pos.distance_squared_to(candidate); refuge = candidate
			state.loop_refuges[actor] = refuge
		final = state.loop_refuges[actor]
	# Navigate around lines not owned by this bot. Contact has the same effect for bots and YOU.
	var obstacles: Array = []
	for k in holders.size():
		if int(holders[k]) == actor: continue
		obstacles.append([beat.transfers.sources[k], actors[int(holders[k])].pos])
	# A carrier must not sweep its live line through stationary players while moving out.
	if actor in holders:
		var owner_index: int = holders.find(actor)
		var source: Vector2 = beat.transfers.sources[owner_index]
		for other in actors.size():
			if other == actor or other in holders: continue
			var other_pos: Vector2 = actors[other].pos
			var radial := (other_pos - source).normalized()
			if radial.length_squared() > 0.1: obstacles.append([other_pos, source + radial * 40.0])
	if clear_path(pos, final, obstacles): return final
	return navigate_goal(actor,pos,final,obstacles,state)

static func navigate_goal(actor: int, start: Vector2, goal: Vector2, obstacles: Array, state: Dictionary) -> Vector2:
	var cached: Dictionary = state.tether_routes.get(actor, {})
	if not cached.is_empty() and (cached.goal as Vector2).distance_to(goal) < 1.5:
		while not cached.points.is_empty() and start.distance_to(cached.points[0]) < 0.2: cached.points.pop_front()
		if not cached.points.is_empty() and clear_path(start,cached.points[0],obstacles): return cached.points[0]
	var path := navigation_route(start,goal,obstacles)
	if path.size() > 1:
		state.tether_routes[actor] = {"goal":goal,"points":path.slice(1)}
		return path[1]
	return start

static func segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null: return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a,c,d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b,c,d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c,a,b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d,a,b))))
static func clear_path(a: Vector2, b: Vector2, obstacles: Array) -> bool:
	for line in obstacles:
		# An already overlapping bot must be able to leave the capsule.
		var start_distance := a.distance_to(Geometry2D.get_closest_point_to_segment(a,line[0],line[1]))
		var limit := minf(NAV_CLEARANCE, start_distance - 0.01)
		if segment_distance(a,b,line[0],line[1]) < limit: return false
	return true
static func navigation_route(start: Vector2, goal: Vector2, obstacles: Array) -> Array:
	var nodes: Array = [start, goal]
	for line in obstacles:
		for point in line:
			for i in 12:
				var p: Vector2 = point + Vector2.from_angle(i * TAU / 12) * 1.8
				if p.length() < 19.2: nodes.append(p)
	var distance: Array = []; distance.resize(nodes.size()); distance.fill(INF); distance[0] = 0.0
	var parent: Array = []; parent.resize(nodes.size()); parent.fill(-1)
	var visited: Array = []; visited.resize(nodes.size()); visited.fill(false)
	for _iteration in nodes.size():
		var current := -1; var best := INF
		for i in nodes.size():
			if not visited[i] and float(distance[i]) < best: best = distance[i]; current = i
		if current < 0: break
		if current == 1:
			var route: Array = [goal]
			while current != 0:
				current = parent[current]; route.push_front(nodes[current])
			return route
		visited[current] = true
		for i in nodes.size():
			if visited[i]: continue
			var cost: float = distance[current] + (nodes[current] as Vector2).distance_to(nodes[i])
			if cost < float(distance[i]) and clear_path(nodes[current], nodes[i], obstacles): distance[i] = cost; parent[i] = current
	return []
