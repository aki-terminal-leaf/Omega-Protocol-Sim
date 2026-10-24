# SPDX-License-Identifier: MIT
extends RefCounted
## Runtime contacts, not a solution-position validator. Pickup radius is configurable.
const Rules = preload("res://scripts/rules.gd")
const Statuses = preload("res://scripts/statuses.gd")
const PICKUP_RADIUS := 0.65
const NAV_CLEARANCE := 1.0

static func begin(beat: Dictionary, actors: Array, state: Dictionary) -> void:
	state.erase("monitor_preparation_observed")
	state.loop_refuges = {}
	state.loop_released = false
	state.loop_departure_order=[]
	state.loop_deadline=float(state.get("sim_time",0))+float(beat.get("duration",0))
	Statuses.begin(beat, state)
	Statuses.sync(beat, state)
	preload("res://scripts/synergy_weapons.gd").begin(beat,state)
	if beat.has("synergy_public"):preload("res://scripts/synergy_preparation.gd").begin(beat,state,actors)
	# Per-cast public new-North lifecycle; headless observation happens in tick
	# (actual clock, spawn/transition-filtered) only when not presenting.
	preload("res://scripts/synergy_north.gd").begin(beat,state)
	load("res://scripts/hw_firstwave_observation.gd").begin(beat,actors,state)
	sync_followups(beat,state)
	if not beat.has("transfers"): return
	var config: Dictionary = beat.transfers
	if state.get("tether_group", "") != config.group:
		state.tether_group = config.group
		state.tether_holders = config.initial.duplicate()
		state.tether_contacts = [[], []]
		state.tether_events = state.get("tether_events", [])
		state.tether_routes = {}
		state.blaster_retire_goals = {}
		state.tether_active_at = float(state.get("sim_time",0))+float(config.get("activation_delay",0))
	sync(beat, state)
	# A new wave does not assign a new owner: previous owners keep their lines.

static func sync(beat: Dictionary, state: Dictionary) -> void:
	Statuses.sync(beat, state)
	if beat.has("synergy_public"):preload("res://scripts/synergy_preparation.gd").tick(beat,state)
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
	# Hide future transfer-target previews as well as lines. Restore the exact
	# complete shapes at activation; no radius or active damage rule is altered.
	if beat.transfers.has("activation_delay"):
		if not beat.transfers.has("activation_shapes"):
			beat.transfers.activation_shapes=beat.get("shapes",[]).filter(func(s):return s.has("tether_index")).duplicate(true)
		beat.shapes=beat.get("shapes",[]).filter(func(s):return not s.has("tether_index"))
		if float(state.get("sim_time",0))>=float(state.get("tether_active_at",0)):
			beat.shapes.append_array(beat.transfers.activation_shapes.duplicate(true))
	for shape in beat.get("shapes", []):
		if shape.has("tether_index"):
			var holder: int = state.tether_holders[int(shape.tether_index)]
			if shape.get("kind", "circle") == "cone": shape.target = holder
			else: shape.actor = holder
	beat.tethers = []
	beat.transfers.active = float(state.get("sim_time",0))>=float(state.get("tether_active_at",0))
	if not beat.transfers.active:
		if beat.has("program_loop"): beat.program_loop.holders=[]
		return
	for k in state.tether_holders.size():
		beat.tethers.append({"a": state.tether_holders[k], "b": -1, "source": beat.transfers.sources[k]})

static func sync_followups(beat: Dictionary,state: Dictionary) -> void:
	if not beat.get("defense_followup",false):return
	for actor in beat.positions.size():
		beat.positions[actor]=Vector2(-12,-10) if actor in state.get("defense_victims",[]) else Vector2(-9,3)+Vector2(actor*0.1,0)

static func tick(beat: Dictionary, actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	state.sim_time = float(state.get("sim_time", 0.0)) + dt
	Statuses.tick(actors, previous, state, dt)
	preload("res://scripts/monitor_preparation.gd").observe(beat,actors,state)
	Statuses.sync(beat, state)
	# Aether-only headless receipt from this tick's actual clock/statuses/poses.
	if beat.has("synergy_public"):preload("res://scripts/synergy_preparation.gd").observe(beat,actors,state)
	if beat.has("synergy_weapon_public"):preload("res://scripts/synergy_weapons.gd").observe_headless(beat,state)
	if beat.has("synergy_public"):preload("res://scripts/synergy_north.gd").observe_headless(beat,state)
	sync_followups(beat,state)
	if beat.has("transfers"): tick_transfers(beat,actors,previous,state,dt)
	# Resolve Limitless only after the same physical contact pass used by YOU.
	preload("res://scripts/p2_limitless_runtime.gd").tick(actors,previous,state,dt)
	preload("res://scripts/p2_limitless_runtime.gd").sync(beat,state)

static func tick_transfers(beat: Dictionary, actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	if not state.has("tether_holders"): begin(beat, actors, state)
	if float(state.sim_time)<float(state.get("tether_active_at",0)):
		sync(beat,state)
		return
	state.tether_holders=state.tether_holders.map(func(i):return int(i))
	state.tether_contacts=state.tether_contacts.map(func(ids):return ids.map(func(i):return int(i)))
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
				if float(state.sim_time)-dt+t*dt<float(state.get("tether_active_at",0)): continue
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
	if beat.has("omega_config") and preload("res://scripts/omega_cooperation.gd").holds(actor,beat,state):return Rules.v(actors[actor].pos)
	if beat.has("sigma_config") and preload("res://scripts/sigma_cooperation.gd").holds(actor,beat,state):return Rules.v(actors[actor].pos)
	if beat.has("monitor_preparation"):return preload("res://scripts/monitor_preparation.gd").goal(actor,beat,state).limit_length(19.8)
	# Only AI steering is bounded. Human positions and all wall judgments stay
	# untouched; sidesteps around edge-origin tethers must not steer bots out.
	return raw_bot_goal(actor,beat,actors,state).limit_length(19.8)

static func raw_bot_goal(actor: int, beat: Dictionary, actors: Array, state: Dictionary) -> Vector2:
	if beat.has("synergy_north_reveal") and float(state.get("sim_time",0))+0.000001<float(state.get("beat_started",0))+float(beat.synergy_north_reveal):
		# Return after the eye. Neither stack swaps nor the new north may steer
		# the bots into their final knockback groups before that source appears.
		return Vector2.ZERO
	# All five profiles (CN/KR have no Prep config): public weapon receipt only.
	if beat.has("synergy_weapon_public"):return preload("res://scripts/synergy_weapons.gd").goal(actor,beat,actors,state)
	if beat.has("synergy_public"):return preload("res://scripts/synergy_preparation.gd").goal(actor,beat,actors,state)
	if beat.has("p1_path"):return load("res://scripts/p1_runtime.gd").coaching_goal(actor,beat,state)
	if beat.has("cannons_public"):return preload("res://scripts/cannons_observation.gd").goal(actor,beat,actors,state)
	if beat.has("p3_transition_public"):return preload("res://scripts/p3_transition_observation.gd").goal(actor,beat,actors,state)
	var final: Vector2 = beat.positions[actor]
	# Bots wait out the same raidwide vulnerability that judges player breaks.
	if state.has("statuses") and state.statuses[actor].has("magic_vulnerability"):
		for tether in state.paired_tethers:
			if not tether.broken and actor in [tether.a,tether.b] and float(state.sim_time) >= float(tether.active_at): return actors[actor].pos

	if beat.has("hw_tower_cooperation") or beat.has("hw_path"):
		return load("res://scripts/hw_courses.gd").coaching_goal(actor,beat,actors,state)
	if not beat.has("transfers"): return final
	if float(state.get("sim_time",0))<float(state.get("tether_active_at",0)):
		return beat.transfers.get("preposition",beat.positions)[actor]
	var holders: Array = state.tether_holders
	var wanted: Array = beat.transfers.wanted
	var obey_other_lines:bool=actor not in holders or str(beat.transfers.get("ownership_policy",Statuses.parameter("double_line_policy")))!="unverified_exclusive"
	var pos: Vector2 = actors[actor].pos
	# Loop has three physical phases: collect short rays, let everyone else
	# clear their future corridors, then stagger the outgoing carriers.
	# This reads visible current owners only, after the activation guard above.
	if beat.has("program_loop") and actor in wanted and actor in holders and not state.get("loop_released",false):
		var clear_egress: bool = wanted.all(func(i):return i in holders)
		var future_lines: Array=[]
		for h in wanted: future_lines.append([Vector2.ZERO,beat.positions[h]])
		for i in actors.size():
			if i in wanted:continue
			var destination: Vector2=loop_destination(i,beat,actors,state)
			if Rules.v(actors[i].pos).length()<4.5 or not clear_path(actors[i].pos,destination,future_lines):clear_egress=false
		if clear_egress:
			state.loop_released=true
			state.loop_departure_order=wanted.duplicate()
			state.loop_departure_order.sort_custom(func(a,b):return Rules.v(actors[a].pos).distance_to(beat.positions[a])<Rules.v(actors[b].pos).distance_to(beat.positions[b]))
		else:
			# Hold short physical rays while the retiring carriers and tower
			# players walk around their ends. No owner or position is assigned.
			var hold:=pos.normalized()*minf(pos.length(),3.0)
			# Separate clustered initial rays so the remaining collector has an
			# exposed capsule edge. Keeping both frozen can deadlock the handoff.
			for k in holders.size():
				if holders[k]==actor:continue
				var other:Vector2=actors[int(holders[k])].pos
				if hold.distance_to(Geometry2D.get_closest_point_to_segment(hold,Vector2.ZERO,other))<1.8:
					var normal:=other.normalized().orthogonal()
					if pos.dot(normal)<0:normal=-normal
					hold=(hold+normal*2.0).normalized()*3.0
			return hold
	if beat.has("program_loop") and state.get("loop_released",false) and actor in holders and actor in wanted:
		# A moving endpoint is not a stable visibility-graph obstacle. Let the
		# leading carrier align first instead of chasing each other's endpoints.
		var first:int=state.loop_departure_order[0]
		var lead:Vector2=actors[first].pos
		if actor!=first and (lead.length()<4.5 or lead.normalized().dot(Rules.v(beat.positions[first]).normalized())<0.995):return pos
	if actor in wanted and actor not in holders:
		var reserved: Array = []
		for k in holders.size():
			if holders[k] in wanted:
				reserved.append([beat.transfers.sources[k], actors[int(holders[k])].pos])
		var target := pos
		var best := INF
		var radius := float(beat.transfers.get("pickup_radius",Statuses.parameter("pickup_radius")))
		var available_lines:Array=[]
		for k in holders.size():
			if holders[k] not in wanted or holders.count(holders[k])>1:available_lines.append(k)
		var preferred_line:int=-1
		if beat.has("program_loop") and available_lines.size()==2 and wanted.size()==2 and wanted.all(func(i):return i not in holders):
			# Choose a physical pickup, not an owner assignment. Match the old ray
			# to the outgoing cardinal so two new carriers do not sweep90degrees
			# across the just-released tower player while exchanging directions.
			var costs:Array=[]
			for permutation in [[0,1],[1,0]]:
				var cost:=0.0
				for j in 2:
					var source:Vector2=beat.transfers.sources[permutation[j]]
					cost+=1.0-(Rules.v(actors[int(holders[permutation[j]])].pos)-source).normalized().dot((Rules.v(beat.positions[int(wanted[j])])-source).normalized())
				costs.append(cost)
			preferred_line=([0,1] if costs[0]<=costs[1] else [1,0])[wanted.find(actor)]
		if preferred_line<0 and beat.transfers.has("coaching_assignment"):
			var requested:int=int(beat.transfers.coaching_assignment[wanted.find(actor)])
			if requested in available_lines:preferred_line=requested
		if preferred_line>=0:
			for k in holders.size():
				if k!=preferred_line and holders[k] not in wanted:reserved.append([beat.transfers.sources[k],actors[int(holders[k])].pos])
		for k in holders.size():
			if holders[k] in wanted and holders.count(holders[k]) == 1: continue
			if preferred_line>=0 and k!=preferred_line:continue
			var source: Vector2 = beat.transfers.sources[k]
			var endpoint: Vector2 = actors[int(holders[k])].pos
			var normal := (endpoint-source).normalized().orthogonal()
			if normal.length_squared()<0.1:normal=Vector2.RIGHT
			if actor in state.tether_contacts[k]:
				# Leave the capsule before re-entering, obeying the same edge-trigger rule.
				if (pos-Geometry2D.get_closest_point_to_segment(pos,source,endpoint)).dot(normal)<0:normal=-normal
				var exit_point := pos+normal*1.5
				if pos.distance_squared_to(exit_point)<best:best=pos.distance_squared_to(exit_point);target=exit_point
				continue
			var projection: float = clampf((pos-source).dot(endpoint-source)/maxf(0.01,source.distance_squared_to(endpoint)),0.2,0.95)
			var samples:Array=[projection,0.3,0.5,0.7,0.9,0.95]
			if beat.has("program_loop"):samples=[minf(0.95,2.5/maxf(0.1,source.distance_to(endpoint)))]
			for t in samples:
				for side in [-1,1]:
					# Touch the near EDGE, not necessarily the center of a reserved-line corridor.
					# Two close initial rays can have no centerline route with 1y clearance.
					var contact_offset:float=radius*0.75
					if beat.has("program_loop") and source.distance_to(endpoint)>4.0 and int(holders[k])!=int(state.get("human_actor",-1)):contact_offset=radius+1.0
					var pickup: Vector2=source.lerp(endpoint,t)+normal*side*contact_offset
					if pickup.length()>19.8:continue
					if reserved.any(func(line):return pickup.distance_to(Geometry2D.get_closest_point_to_segment(pickup,line[0],line[1]))<NAV_CLEARANCE):continue
					var score:=pos.distance_squared_to(pickup)
					if score<best:best=score;target=pickup
		if not clear_path(pos,target,reserved):return navigate_goal(actor,pos,target,reserved,state)
		return target
	var ready := true
	for h in wanted:
		if h not in holders: ready = false
	if not ready and actor in wanted and actor in holders and str(beat.transfers.group).ends_with("_blaster"):
		# Keep an already acquired ray short while the other3-stack player
		# approaches. Growing it across the room can fence that collector out.
		var source:Vector2=beat.transfers.sources[holders.find(actor)]
		# Align the short acquired ray to its outgoing side. Two nearly
		# coincident3y rays leave no safe corridor for the remaining collector.
		return source+(final-source).normalized()*3.0
	# Leave room for collectors to grab and separate before the rest crosses the room.
	if actor not in wanted:
		if (beat.has("program_loop") or str(beat.transfers.group).ends_with("_blaster")) and not ready and actor in holders:
			# Retiring carriers walk IN along their own ray for a short handoff.
			# Waiting at the old17y endpoint forces collectors and tower players
			# to circle the arena; shortening a ray cannot sweep it across anyone.
			var source:Vector2=beat.transfers.sources[holders.find(actor)]
			var toward:Vector2=source+(pos-source).limit_length(3.0)
			if not beat.has("program_loop") and holders.size()==2:
				var cache:Dictionary=state.get("blaster_retire_goals",{})
				if not cache.has(str(actor)) and Rules.v(actors[int(holders[0])].pos).distance_to(Rules.v(actors[int(holders[1])].pos))<0.05 and pos.distance_to(source)<4.0:
					# Latch an exposed side only for an actual collapsed endpoint.
					# A one-frame sidestep would immediately chase the short ray back.
					var slot:int=holders.find(actor)
					var side:Vector2=(Rules.v(beat.positions[int(wanted[slot])])-source).normalized()
					var point:=source+side*3.0
					cache[str(actor)]=[point.x,point.y];state.blaster_retire_goals=cache
				if cache.has(str(actor)):toward=Rules.v(cache[str(actor)])
			var other_lines:Array=[]
			for k in holders.size():
				if obey_other_lines and int(holders[k])!=actor:other_lines.append([beat.transfers.sources[k],actors[int(holders[k])].pos])
			return toward if clear_path(pos,toward,other_lines) else navigate_goal(actor,pos,toward,other_lines,state)
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
		final = loop_destination(actor,beat,actors,state)
	# Yield proactively when standing in a carrier's intended sweep corridor.
	# Otherwise a short live line and the waiting carrier can mutually block a
	# retiring player's route; moving to the goal-side of the ray is a legal walk.
	if ready and actor not in holders and not beat.has("program_loop"):
		for k in holders.size():
			var source: Vector2=beat.transfers.sources[k]
			var end: Vector2=beat.positions[int(holders[k])]
			var nearest:=Geometry2D.get_closest_point_to_segment(pos,source,end)
			if pos.distance_to(nearest)<1.5 and actors[int(holders[k])].pos.distance_to(end)>1.0:
				var normal: Vector2=(end-source).normalized().orthogonal()
				if (final-source).dot(normal)<0:normal=-normal
				return pos+normal*2.0
	# Navigate around lines not owned by this bot. Contact has the same effect for bots and YOU.
	var obstacles: Array = []
	for k in holders.size():
		if int(holders[k]) == actor or not obey_other_lines: continue
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

static func loop_destination(actor: int, beat: Dictionary, actors: Array, state: Dictionary) -> Vector2:
	var final:Vector2=beat.positions[actor]
	var wanted:Array=beat.transfers.wanted
	var pos:Vector2=actors[actor].pos
	if actor not in wanted and int(beat.program_loop.numbers[actor]) != int(beat.program_loop.round):
		# Close to the snapshot, safe means clear of the ACTUAL Blaster centers.
		# Earlier evacuation from still-short rays would obstruct their departure.
		var live_refuge:bool=float(state.loop_deadline)-float(state.get("sim_time",0))<0.75
		if live_refuge and state.loop_refuges.has(str(actor)):
			var cached:Vector2=Rules.v(state.loop_refuges[str(actor)])
			for h in state.tether_holders:
				if cached.distance_to(actors[int(h)].pos)<15.5:state.loop_refuges.erase(str(actor));break
		if not state.loop_refuges.has(str(actor)):
			var nearest := INF; var refuge := final
			for x in range(-18,19):
				for y in range(-18,19):
					var candidate := Vector2(x,y)
					if candidate.length() >= 19 or candidate.length()<5.5: continue
					var safe := true
					for h in wanted:
						if candidate.distance_to(beat.positions[h]) < 15.8: safe = false
						if candidate.distance_to(Geometry2D.get_closest_point_to_segment(candidate,Vector2.ZERO,beat.positions[h])) < 1.5: safe = false
					if live_refuge:
						for h in state.tether_holders:
							if candidate.distance_to(actors[int(h)].pos)<15.8:safe=false
					for shape in beat.shapes:
						if shape.get("kind","") == "tower" and candidate.distance_to(shape.pos) < 3.5: safe = false
					if safe and pos.distance_squared_to(candidate) < nearest:
						nearest = pos.distance_squared_to(candidate); refuge = candidate
			state.loop_refuges[str(actor)] = [refuge.x,refuge.y]
		final = Rules.v(state.loop_refuges[str(actor)])
	return final

static func navigate_goal(actor: int, start: Vector2, goal: Vector2, obstacles: Array, state: Dictionary) -> Vector2:
	# Cache coordinates are JSON-native; no Vector2 stringification on restore.
	var cached: Dictionary = state.tether_routes.get(str(actor), {})
	if not cached.is_empty() and Rules.v(cached.goal).distance_to(goal) < 1.5:
		while not cached.points.is_empty() and start.distance_to(Rules.v(cached.points[0])) < 0.2: cached.points.pop_front()
		if not cached.points.is_empty() and clear_path(start,Rules.v(cached.points[0]),obstacles): return Rules.v(cached.points[0])
	var path := navigation_route(start,goal,obstacles)
	if path.size() > 1:
		state.tether_routes[str(actor)] = {"goal":[goal.x,goal.y],"points":path.slice(1).map(func(p):return [p.x,p.y])}
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
