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
	if shape.has("direction"): return v(shape.direction).normalized()
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
	# Godot JSON restores numbers as floats, while Array membership is type-sensitive.
	# Normalize discrete state at the judgment boundary, never times/positions.
	for key in ["dynamis","dead","spent","defense_victims","blaster_victims","tether_holders"]:
		if state.has(key):state[key]=state[key].map(func(value):return int(value))
	var failures: Array = []
	if beat.has("program_loop"):
		ensure_loop_state(beat, state)
		tick_loop_state(state)
	for i in actors.size():
		if v(actors[i].pos).length() >= 20.0: failures.append("%s: death wall" % actors[i].role)
	for shape in beat.get("shapes", []):
		if shape.get("decorative", false): continue
		var caught = hits(shape, actors)
		var name: String = shape.get("name", "AoE")
		if shape.has("hit_status") and state.has("statuses"):
			for actor in caught:load("res://scripts/statuses.gd").give(state,int(actor),str(shape.hit_status),float(shape.get("hit_status_duration",2.0)))
		match shape.get("rule", "avoid"):
			"avoid":
				for i in caught: failures.append("%s: %s" % [actors[i].role, name])
			"count":
				if caught.size() != int(shape.get("count", 1)): failures.append("%s: %d / %d players" % [name, caught.size(), int(shape.get("count", 1))])
				if shape.has("required") and not same_members(caught, shape.required): failures.append("%s: wrong players / wrong debuff" % name)
				if shape.has("rot_colour") and state.has("statuses"):
					for actor in caught:
						load("res://scripts/statuses.gd").give(state, actor, "latent_" + shape.rot_colour, float(load("res://scripts/statuses.gd").parameter("latent_duration")))
				if shape.get("looper_tower", false) and caught.size() == 1:
					var actor: int = caught[0]
					if bool(state.loop_cleansed[actor]) or float(state.get("sim_time",0))>=float(state.loop_deadlines[actor]): failures.append("Storage Violation Obliteration: %s has no Looper" % actors[actor].role)
					else:
						state.loop_cleansed[actor] = true
						if state.has("statuses"):
							state.statuses[actor].erase("looper")
							var key: String=["first_in_line","second_in_line","third_in_line","fourth_in_line"][int(state.loop_numbers[actor])-1]
							state.statuses[actor].erase(key)
							loop_event(state,"status_remove",{"actor":actor,"status":key,"cause":"Storage Violation"})
						loop_event(state,"status_remove",{"actor":actor,"status":"looper","cause":"Storage Violation"})
						if loop_hp_active(actor,state): failures.append("%s: tower damage while HP Penalty active" % actors[actor].role)
						apply_loop_ruin(actor, state, actors, failures, "Storage Violation")
			"tankbuster":
				for actor in caught:
					if actor >= 2: failures.append("%s: %s hit a non-tank" % [actors[actor].role, name])
			"beyond_defense":
				state.defense_victims=caught.duplicate()
				if caught.size()!=1:failures.append("Beyond Defense clipped another player")
				var status=load("res://scripts/statuses.gd");status.ensure(state);status.event(state,"beyond_defense",{"victims":caught})
			"pile_pitch":
				if caught.size()<int(shape.get("min_count",3)):failures.append("Pile Pitch: insufficient stack members")
				for actor in caught:
					if actor in state.get("defense_victims",[]):failures.append("%s: Beyond Defense victim clipped by Pile Pitch" % actors[actor].role)
				var status=load("res://scripts/statuses.gd");status.ensure(state);status.event(state,"pile_pitch",{"hits":caught,"excluded":state.get("defense_victims",[]).duplicate()})
				state.defense_victims=[]
			"omega_blaster":
				if not state.has("blaster_victims"): state.blaster_victims = []
				for actor in caught:
					if actor not in state.blaster_victims: state.blaster_victims.append(actor)
				if caught.size() != 1: failures.append("Omega Blaster clipped another player")
				if state.has("statuses"):
					for actor in caught:
						var status=load("res://scripts/statuses.gd")
						status.give(state,actor,"hp_penalty",float(status.parameter("omega_hp_penalty_duration")))
						status.give(state,actor,"magic_vulnerability",5.0)
						status.give(state,actor,"twice_come_ruin",11.0)
			"blaster":
				for actor in caught:
					apply_loop_ruin(actor, state, actors, failures, "Blaster")
					queue_loop_hp(actor,state)
	for check in beat.get("checks", []):
		var name: String = check.get("name", check.kind)
		match check.kind:
			"distance":
				var distance = v(actors[int(check.a)].pos).distance_to(v(actors[int(check.b)].pos))
				if distance < float(check.get("min", 0)) or distance > float(check.get("max", INF)): failures.append("%s: %.1fy" % [name, distance])
			"monitors":
				var status=load("res://scripts/statuses.gd");status.ensure(state)
				var coverage:Array=[];coverage.resize(actors.size());coverage.fill(0)
				var resolutions:Array=[]
				for source in check.sources:
					var candidates=hits(source,actors).filter(func(i):return i not in state.dead)
					var targets=monitor_targets(candidates,source,actors.size(),state)
					if targets.size()!=2:failures.append(name+": not enough living monitor targets")
					for target in targets:
						for actor in hits({"actor":target,"radius":float(check.get("splash_radius",7.0))},actors):
							if actor not in state.dead:coverage[actor]+=1
					resolutions.append({"source_actor":source.get("actor",-1),"origin":[point(source,actors).x,point(source,actors).y],"candidates":candidates,"targets":targets,"target_positions":targets.map(func(target):return [v(actors[int(target)].pos).x,v(actors[int(target)].pos).y])})
				for i in actors.size():
					if i not in state.dead and coverage[i]!=1:failures.append("%s: %s hit %d times (targeting + radius7 splash)"%[name,actors[i].role,coverage[i]])
				for i in actors.size():
					if coverage[i]>0:
						status.give(state,i,"magic_vulnerability",5.0)
						status.give(state,i,"twice_come_ruin",7.0)
					for key in ["monitor_left","monitor_right"]:
						state.statuses[i][key]={"expires":float(state.get("sim_time",0))}
				status.event(state,"monitor_resolution",{"sources":resolutions,"coverage":coverage})
			"regressions_resolved":
				for tether in state.get("paired_tethers",[]):
					if tether.id.begins_with(check.prefix) and not tether.broken: failures.append("Unresolved paired tether: " + tether.id)
			"blaster_eligible":
				# Three-stack holders are a strategy allocation, not a server ownership gate.
				# Real HP Penalty / World damage and final Dynamis determine success.
				pass
			"world_pulse":
				resolve_world_pulse(check,actors,state,failures)
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
						if check.get("exclude_blaster", false) and receiver in state.get("blaster_victims", state.get("tether_holders", [])): failures.append("World hit live Blaster holder")
						var blast = {"actor": receiver, "radius": float(check.get("holder_radius", 8)) if j == 0 else float(check.get("jump_radius", 4))}
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
		tick_loop_state(state)
		for actor in state.get("loop_memory_loss",[]): failures.append("%s: Looper expired → Memory Loss" % actors[int(actor)].role)
	if beat.has("sigma_config"):failures.append_array(load("res://scripts/p5_sigma_runtime.gd").snapshot(beat,actors,state))
	if beat.has("omega_config"):failures.append_array(load("res://scripts/p5_omega_runtime.gd").snapshot(beat,actors,state))
	for raw in beat.get("consume_party_signals",[]):
		if not state.has("consumed_party_signals"):state.consumed_party_signals={}
		var actor:=str(int(raw.actor))
		if not state.consumed_party_signals.has(actor):state.consumed_party_signals[actor]=[]
		if str(raw.key) not in state.consumed_party_signals[actor]:state.consumed_party_signals[actor].append(str(raw.key))
	return failures

static func ensure_loop_state(beat: Dictionary, state: Dictionary) -> void:
	if state.has("loop_cleansed"): return
	state.loop_cleansed = []; state.loop_ruin_expires = []; state.loop_hp_penalty = []
	state.loop_started=float(state.get("sim_time",0)); state.loop_deadlines=[]; state.loop_memory_loss=[]
	state.loop_numbers=beat.program_loop.numbers.duplicate()
	state.loop_hp_starts=[]; state.loop_hp_pending=[]; state.loop_max_hp=[]
	for _i in 8:
		state.loop_cleansed.append(false); state.loop_ruin_expires.append(0.0); state.loop_hp_penalty.append(0.0)
		state.loop_hp_starts.append(0.0); state.loop_max_hp.append(1.0)
		var deadline: float=state.loop_started+[16.0,25.0,34.0,43.0][int(beat.program_loop.numbers[_i])-1]
		state.loop_deadlines.append(deadline)
		if state.has("statuses"):
			state.statuses[_i].looper={"expires":deadline}
			var key: String=["first_in_line","second_in_line","third_in_line","fourth_in_line"][int(state.loop_numbers[_i])-1]
			state.statuses[_i][key]={"expires":1.0e30}
			loop_event(state,"status_gain",{"actor":_i,"status":key})
		loop_event(state,"status_gain",{"actor":_i,"status":"looper","expires":deadline})
static func loop_event(state: Dictionary, kind: String, details: Dictionary) -> void:
	if not state.has("timeline"): state.timeline=[]
	var entry:=details.duplicate(true); entry.kind=kind; entry.time=details.get("time",float(state.get("sim_time",0)))
	state.timeline.append(entry)
static func loop_hp_active(actor: int,state: Dictionary) -> bool:
	var now:=float(state.get("sim_time",0))
	return now>=float(state.loop_hp_starts[actor]) and now<float(state.loop_hp_penalty[actor])
static func queue_loop_hp(actor: int,state: Dictionary) -> void:
	var at:=float(state.get("sim_time",0))+0.65
	state.loop_hp_starts[actor]=at; state.loop_hp_penalty[actor]=at+9.0
	state.loop_hp_pending.append({"actor":actor,"at":at,"expires":at+9.0})
static func tick_loop_state(state: Dictionary) -> void:
	if not state.has("loop_cleansed"): return
	var now:=float(state.get("sim_time",0))
	if not state.has("dead"): state.dead=[]
	if not state.has("runtime_failures"): state.runtime_failures=[]
	state.loop_memory_loss=state.loop_memory_loss.map(func(i):return int(i))
	state.dead=state.dead.map(func(i):return int(i))
	for raw in state.loop_hp_pending.duplicate():
		if float(raw.at)>now: continue
		var actor:=int(raw.actor)
		state.loop_max_hp[actor]=0.01
		if state.has("statuses"): state.statuses[actor].p1_hp_penalty={"expires":raw.expires}
		loop_event(state,"status_gain",{"actor":actor,"status":"p1_hp_penalty","time":raw.at,"expires":raw.expires,"max_hp_fraction":0.01})
		state.loop_hp_pending.erase(raw)
	for actor in 8:
		if not bool(state.loop_cleansed[actor]) and now>=float(state.loop_deadlines[actor]) and not state.loop_memory_loss.has(actor):
			state.loop_memory_loss.append(actor)
			if actor not in state.dead: state.dead.append(actor)
			state.runtime_failures.append("Actor %d: Looper expired → Memory Loss" % actor)
			if state.has("statuses"): state.statuses[actor].erase("looper")
			loop_event(state,"status_expire",{"actor":actor,"status":"looper","time":state.loop_deadlines[actor]})
			loop_event(state,"memory_loss",{"actor":actor,"time":state.loop_deadlines[actor]})
		if float(state.loop_max_hp[actor])<1.0 and now>=float(state.loop_hp_penalty[actor]):
			state.loop_max_hp[actor]=1.0
			if state.has("statuses"): state.statuses[actor].erase("p1_hp_penalty")
			loop_event(state,"status_expire",{"actor":actor,"status":"p1_hp_penalty","time":state.loop_hp_penalty[actor]})
static func apply_loop_ruin(actor: int, state: Dictionary, actors: Array, failures: Array, cause: String) -> void:
	var now := float(state.get("sim_time", 0.0))
	if float(state.loop_ruin_expires[actor]) > now:
		failures.append("%s: Twice-come Ruin ×2 → Doom (%s)" % [actors[actor].role, cause])
		if not state.has("dead"): state.dead=[]
		if actor not in state.dead: state.dead.append(actor)
		loop_event(state,"doom",{"actor":actor,"cause":cause})
	state.loop_ruin_expires[actor] = now + 11.0
	if state.has("statuses"): state.statuses[actor].p1_ruin={"expires":now+11.0,"stacks":2 if actor in state.get("dead",[]) else 1}
	loop_event(state,"status_gain",{"actor":actor,"status":"p1_ruin","expires":now+11.0,"cause":cause})


static func monitor_targets(candidates: Array, source: Dictionary, count: int, state: Dictionary) -> Array:
	var pool:=candidates.duplicate();var targets:Array=[]
	while targets.size()<2:
		if pool.is_empty():
			for actor in count:
				if actor not in targets and actor not in state.get("dead",[]) and actor!=int(source.get("actor",-1)):pool.append(actor)
			if pool.is_empty():break
		var seed_value:int=int(state.get("monitor_rng",state.get("seed",1)))
		seed_value=posmod(seed_value*1103515245+12345,2147483647);state.monitor_rng=seed_value
		var choice:int=seed_value%pool.size();targets.append(pool[choice]);pool.remove_at(choice)
	return targets

static func resolve_world_pulse(check: Dictionary, actors: Array, state: Dictionary, failures: Array) -> void:
	var statuses = load("res://scripts/statuses.gd")
	statuses.ensure(state)
	if not state.has("world_chains"): state.world_chains = {}
	var id: String = check.chain_id
	var pulse := int(check.pulse)
	if pulse==0:
		for actor in [int(check.near),int(check.far)]:
			for key in ["near_world","distant_world","delta_near_world","delta_distant_world","omega_near_world","omega_distant_world","first_in_line","second_in_line"]:
				if state.statuses[actor].has(key):
					state.statuses[actor].erase(key)
					statuses.event(state,"status_remove",{"actor":actor,"status":key,"cause":"World resolution"})
		state.world_chains[id] = {"holders":[int(check.near),int(check.far)],"next_pulse":0,"touched":[],"history":[]}
	if not state.world_chains.has(id) or int(state.world_chains[id].next_pulse)!=pulse:
		failures.append("World pulse missing/out of order: " + id)
		return
	var chain: Dictionary = state.world_chains[id]
	var receivers: Array = chain.holders.duplicate()
	if pulse>0:
		for side in 2:
			var holder: int = chain.holders[side]
			var best := INF if side==0 else -INF
			var receiver := -1
			for actor in actors.size():
				if actor==holder or actor in state.dead: continue
				var distance := v(actors[holder].pos).distance_squared_to(v(actors[actor].pos))
				if distance<best if side==0 else distance>best:
					best=distance;receiver=actor
			if receiver<0: failures.append("World: no living jump target");return
			receivers[side]=receiver
	var now := float(state.get("sim_time",0))
	for side in 2:
		var receiver: int = receivers[side]
		if receiver in state.dead:
			failures.append("World holder died before resolution")
			continue
		var radius := float(check.holder_radius) if pulse==0 else float(check.jump_radius)
		var caught := hits({"actor":receiver,"radius":radius},actors).filter(func(a):return a not in state.dead)
		if caught.size()!=1: failures.append("Hello World: AoE clipped another player")
		for actor in caught:
			if float(state.statuses[actor].get("world_vulnerability",{}).get("expires",0))>now:
				failures.append("Hello World: double-hit / bounce back during vulnerability")
				state.dead.append(actor)
			if float(state.statuses[actor].get("magic_vulnerability",{}).get("expires",0))>now:
				failures.append("Hello World: hit during prior Magic Vulnerability")
				if actor not in state.dead:state.dead.append(actor)
			if float(state.statuses[actor].get("hp_penalty",{}).get("expires",0))>now:
				failures.append("World hit live Blaster holder while HP Penalty active")
				if actor not in state.dead:state.dead.append(actor)
			statuses.give(state,actor,"world_vulnerability",float(statuses.parameter("world_vulnerability_duration")))
			state.dynamis[actor]=mini(3,int(state.dynamis[actor])+1)
			chain.touched.append(actor)
		var record := {"chain":id,"pulse":pulse,"side":"near" if side==0 else "far","from":chain.holders[side],"receiver":receiver,"hits":caught,"time":now}
		chain.history.append(record)
		statuses.event(state,"world_pulse",record)
	chain.holders=receivers;chain.next_pulse=pulse+1

static func same_members(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for value in a:
		if a.count(value) != b.count(value): return false
	return true
