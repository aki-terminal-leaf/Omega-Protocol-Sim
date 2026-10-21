# SPDX-License-Identifier: MIT
extends RefCounted
## Serializable runtime state. No route, label, or suggested recipient is read here.
const Rules = preload("res://scripts/rules.gd")

static var parameters: Dictionary = {}

static func parameter(key: String):
	if parameters.is_empty(): parameters = JSON.parse_string(FileAccess.get_file_as_string("res://data/fidelity_parameters.json"))
	return parameters[key].value

static func parameter_snapshot() -> Dictionary:
	if parameters.is_empty():parameters=JSON.parse_string(FileAccess.get_file_as_string("res://data/fidelity_parameters.json"))
	return parameters.duplicate(true)

static func ensure(state: Dictionary, count := 8) -> void:
	if state.has("statuses"): return
	state.statuses = []
	for _i in count: state.statuses.append({})
	state.dead = []; state.timeline = []; state.runtime_failures = []; state.paired_tethers = []; state.streams = []

static func event(state: Dictionary, kind: String, details: Dictionary = {}) -> void:
	var entry := details.duplicate(true)
	entry.kind = kind; entry.time = details.get("time",snappedf(float(state.get("sim_time", 0)), 0.001))
	state.timeline.append(entry)

static func fail(state: Dictionary, reason: String) -> void:
	state.runtime_failures.append(reason)
	event(state, "failure", {"reason": reason})

static func give(state: Dictionary, actor: int, name: String, duration: float, source := -1) -> void:
	ensure(state)
	var buffs: Dictionary = state.statuses[actor]
	if buffs.has(name + "_debugger"):
		if name == "overflow": buffs.erase(name + "_debugger")
		event(state, "debugger_block", {"actor": actor, "status": name, "source": source})
		return
	# Same colour does not extend an existing timer. Opposite rot overwrites it.
	if buffs.has(name):
		if name in ["world_vulnerability","magic_vulnerability"]:
			buffs[name].expires = float(state.get("sim_time",0)) + duration
			event(state,"status_refresh",{"actor":actor,"status":name,"expires":buffs[name].expires,"source":source})
		if name in ["red","blue"] and parameter("same_colour_policy") == "refresh_timer_unverified": buffs[name].expires = float(state.get("sim_time",0)) + duration
		return
	if name in ["red", "blue"]:
		var opposite := "blue" if name == "red" else "red"
		if buffs.has(opposite):
			buffs.erase(opposite)
			event(state, "rot_overwrite", {"actor": actor, "removed": opposite, "source": source})
	buffs[name] = {"expires": float(state.get("sim_time", 0)) + duration, "source": source}
	event(state, "status_gain", {"actor": actor, "status": name, "expires": buffs[name].expires, "source": source})

static func begin(beat: Dictionary, state: Dictionary) -> void:
	ensure(state)
	preload("res://scripts/p6_runtime.gd").begin(beat,state)
	preload("res://scripts/p5_delta_runtime.gd").begin(beat,state)
	preload("res://scripts/p5_sigma_runtime.gd").begin(beat,state)
	preload("res://scripts/p1_runtime.gd").begin(beat,state)
	preload("res://scripts/p5_omega_runtime.gd").begin(beat,state)
	preload("res://scripts/hw_runtime.gd").begin(beat,state)
	state.beat_started = float(state.get("sim_time", 0))
	for grant in beat.get("status_grants", []): give(state, grant.actor, grant.name, grant.duration)
	for raw in beat.get("paired_tethers", []):
		var tether: Dictionary = raw.duplicate(true)
		if state.paired_tethers.any(func(t): return t.id == tether.id): continue
		tether.active_at = float(state.get("sim_time", 0)) + float(tether.get("delay", 0))
		tether.expires = tether.active_at + float(tether.get("duration", 30))
		tether.broken = false
		state.paired_tethers.append(tether)
		event(state, "paired_tether_gain", tether)
	for raw in beat.get("streams", []):
		var stream: Dictionary = raw.duplicate(true)
		stream.next_at = float(state.get("sim_time", 0)) + float(stream.get("delay", 0))
		state.streams.append(stream)

static func contacts(actors: Array, previous: Array, state: Dictionary) -> void:
	var before: Array = state.statuses.duplicate(true)
	var incoming: Dictionary = {}
	var radius := float(parameter("rot_contact_radius"))
	for a in actors.size():
		for b in range(a + 1, actors.size()):
			if a in state.dead or b in state.dead: continue
			var relative_start: Vector2 = previous[a].pos - previous[b].pos
			var relative_end: Vector2 = actors[a].pos - actors[b].pos
			if Geometry2D.get_closest_point_to_segment(Vector2.ZERO, relative_start, relative_end).length() > radius: continue
			var opposite_active: bool = (before[a].has("red") and before[b].has("blue") and not before[a].has("blue_debugger") and not before[b].has("red_debugger")) or (before[a].has("blue") and before[b].has("red") and not before[a].has("red_debugger") and not before[b].has("blue_debugger"))
			if opposite_active and parameter("simultaneous_rot_policy") == "reject_ambiguous":
				var reason := "Simultaneous opposite-carrier collision %d/%d (unverified server order)" % [a,b]
				if reason not in state.runtime_failures: fail(state,reason)
				continue
			for edge in [[a,b], [b,a]]:
				for colour in ["red", "blue"]:
					if not before[edge[0]].has(colour) or before[edge[1]].has(colour) or before[edge[1]].has(colour + "_debugger"): continue
					if not incoming.has(edge[1]): incoming[edge[1]] = {}
					incoming[edge[1]][colour] = edge[0]
	# Batch from pre-contact state: a newly infected actor cannot spread again in this tick.
	for actor in incoming:
		if incoming[actor].size() > 1:
			var reason := "Ambiguous simultaneous opposite rot contacts: actor %d (unverified policy)" % actor
			if reason not in state.runtime_failures: fail(state,reason)
			continue
		for colour in incoming[actor]: give(state, actor, colour, float(parameter("rot_duration")), incoming[actor][colour])

static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	ensure(state, actors.size())
	preload("res://scripts/p6_runtime.gd").tick(actors,previous,state,dt)
	preload("res://scripts/p5_delta_runtime.gd").tick(actors,previous,state,dt)
	preload("res://scripts/p5_sigma_runtime.gd").tick(actors,previous,state,dt)
	preload("res://scripts/p1_runtime.gd").tick(actors,previous,state,dt)
	preload("res://scripts/p5_omega_runtime.gd").tick(actors,previous,state,dt)
	if preload("res://scripts/hw_runtime.gd").tick(actors,previous,state,dt): return
	if state.paired_tethers.is_empty() and state.streams.is_empty() and state.statuses.all(func(s): return s.is_empty()): return
	# Subdivide movement and time together so expiry cannot be bypassed by a large frame.
	var finish := float(state.get("sim_time", 0))
	var steps := maxi(1, ceili(dt / float(parameter("contact_step"))))
	var last: Array = previous.duplicate(true)
	for step in steps:
		state.sim_time = finish - dt + dt * float(step + 1) / steps
		var sample: Array = actors.duplicate(true)
		for i in actors.size(): sample[i].pos = (previous[i].pos as Vector2).lerp(actors[i].pos, float(step + 1) / steps)
		expire(sample, state)
		contacts(sample, last, state)
		regressions(sample, state)
		streams(sample, state)
		last = sample
	state.sim_time = finish

static func expire(actors: Array, state: Dictionary) -> void:
	var due: Array = []
	for i in state.statuses.size():
		for name in state.statuses[i]:
			if float(state.statuses[i][name].expires) <= float(state.sim_time): due.append([i, name])
	for entry in due:
		var actor: int = entry[0]; var name: String = entry[1]
		if not state.statuses[actor].has(name): continue
		state.statuses[actor].erase(name)
		event(state, "status_expire", {"actor": actor, "status": name})
		if name.begins_with("smell_"):
			give(state,actor,name.trim_prefix("smell_"),float(parameter("rot_duration" if name in ["smell_red","smell_blue"] else "bug_duration")))
		if name.begins_with("latent_"): fail(state, "Actor %d: %s expired" % [actor, name])
		if name not in ["red", "blue", "overflow", "sync"]: continue
		state.statuses[actor][name + "_debugger"] = {"expires": 1.0e30}
		var radius := float(parameter("rot_radius" if name in ["red", "blue"] else ("overflow_radius" if name == "overflow" else "sync_radius")))
		var caught := Rules.hits({"actor": actor, "radius": radius}, actors)
		event(state, "bug_explosion", {"actor": actor, "status": name, "hits": caught})
		if name in ["red", "blue"]:
			if actor not in state.dead: state.statuses[actor].erase("latent_" + name)
			for other in caught:
				if other != actor:
					fail(state, "Actor %d: %s rot expiry blast from %d" % [other, name, actor])
					if other not in state.dead: state.dead.append(other)
		else:
			if name == "sync" and caught.size() < 2: fail(state, "Actor %d: unshared Synchronization" % actor)
			for other in caught:
				state.statuses[other].erase("latent_" + name)
				if other != actor: give(state, other, name, float(parameter("bug_duration")), actor)
			magic_hit(state, caught, name)

static func magic_hit(state: Dictionary, victims: Array, cause: String) -> void:
	for actor in victims:
		if state.statuses[actor].has("magic_vulnerability"): fail(state, "Actor %d: %s during Magic Vulnerability" % [actor, cause])
		give(state, actor, "magic_vulnerability", float(parameter("regression_vulnerability")))

static func regressions(actors: Array, state: Dictionary) -> void:
	for tether in state.paired_tethers:
		if tether.broken or float(state.sim_time) < float(tether.active_at): continue
		var distance: float = (actors[tether.a].pos as Vector2).distance_to(actors[tether.b].pos)
		var threshold := float(tether.get("threshold", parameter("regression_local_distance" if tether.kind == "local" else "regression_remote_distance")))
		if (distance <= threshold if tether.kind == "local" else distance >= threshold):
			tether.broken = true; tether.broken_at = state.sim_time
			event(state, "paired_tether_break", {"id": tether.id, "a": tether.a, "b": tether.b, "distance": distance})
			for actor in actors.size():
				var stacks := int(state.statuses[actor].get("thrice_come_ruin",{}).get("stacks",0))+1
				state.statuses[actor].thrice_come_ruin = {"expires":float(state.sim_time)+float(parameter("regression_ruin_duration")),"stacks":stacks}
				if stacks>=3: fail(state,"Actor %d: Thrice-come Ruin" % actor)
			magic_hit(state, range(actors.size()), "Regression " + tether.id)
		elif float(state.sim_time) >= float(tether.expires):
			tether.broken = true
			fail(state, "Regression expired: " + tether.id)

static func streams(actors: Array, state: Dictionary) -> void:
	for stream in state.streams:
		while int(stream.remaining) > 0 and float(state.sim_time) >= float(stream.next_at):
			var caught := Rules.hits({"pos": stream.pos, "radius": stream.radius}, actors)
			event(state, "stream_explosion", {"id": stream.id, "pos": stream.pos, "hits": caught, "scheduled": stream.next_at})
			for actor in caught: fail(state, "Actor %d: moving exaflare %s" % [actor, stream.id])
			stream.pos += stream.advance
			stream.next_at += stream.interval
			stream.remaining -= 1

static func sync(beat: Dictionary, state: Dictionary) -> void:
	preload("res://scripts/p6_runtime.gd").sync(beat,state)
	preload("res://scripts/p5_delta_runtime.gd").sync(beat,state)
	preload("res://scripts/p1_runtime.gd").sync(beat,state)
	preload("res://scripts/p5_omega_runtime.gd").sync(beat,state)
	preload("res://scripts/hw_runtime.gd").sync(beat,state)
	if not state.has("statuses"): return
	if beat.has("shapes"):
		beat.shapes = beat.shapes.filter(func(s): return not s.get("runtime_stream",false))
		for stream in state.streams:
			if int(stream.remaining)>0: beat.shapes.append({"kind":"circle","pos":stream.pos,"radius":stream.radius,"decorative":true,"runtime_stream":true,"name":"Next moving exaflare"})
	if not state.paired_tethers.is_empty():
		beat.tethers = []
		for tether in state.paired_tethers:
			if not tether.broken: beat.tethers.append({"a":tether.a,"b":tether.b,"kind":tether.kind})
