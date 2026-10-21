# SPDX-License-Identifier: MIT
extends RefCounted
## Durable state contains only JSON-native values. No suggested positions used.
const P = preload("res://scripts/p4_wave_patterns.gd")
const Rules = preload("res://scripts/rules.gd")
static func begin(beat: Dictionary, state: Dictionary) -> void:
	if not beat.has("p4_wave_events"): return
	if not state.has("p4_wave"):
		state.p4_wave={"pending":[],"history":[],"markers":[],"until":0.0}
	for key in ["runtime_failures","timeline","dead"]:
		if not state.has(key): state[key]=[]
	var now := float(state.get("sim_time",0.0))
	for raw in beat.p4_wave_events:
		var event: Dictionary=raw.duplicate(true)
		event.at=float(event.at)+now
		if event.has("repeat_at"): event.repeat_at=float(event.repeat_at)+now
		state.p4_wave.pending.append(event)
	P.sorted(state.p4_wave.pending)
	state.p4_wave.until=now+float(beat.p4_wave_duration)
static func fail(state: Dictionary, message: String, victims: Array=[]) -> void:
	state.runtime_failures.append("P4 Wave: "+message)
	for actor in victims:
		if actor not in state.dead: state.dead.append(actor)
static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	if not state.has("p4_wave") or dt<=0: return
	var finish := float(state.sim_time)
	var start := finish-dt
	if start>=float(state.p4_wave.until) and state.p4_wave.pending.is_empty(): return
	state.dead=state.dead.map(func(i):return int(i))
	for i in actors.size():
		var allowed := 6.0*dt
		if state.get("motion_allowances",[]).size()==actors.size(): allowed=minf(float(state.motion_allowances[i]),7.5*dt)
		if Rules.v(previous[i].pos).distance_to(Rules.v(actors[i].pos))>allowed+0.001:
			fail(state,"movement exceeded authorized walking/Sprint budget",[i])
		# A straight segment in a convex arena cannot leave and reenter with
		# both endpoints inside; parent must call tick for each motion segment.
		if maxf(Rules.v(previous[i].pos).length(),Rules.v(actors[i].pos).length())>=20.0:
			fail(state,"death wall",[i])
	while not state.p4_wave.pending.is_empty() and float(state.p4_wave.pending[0].at)<=finish+0.000001:
		var event: Dictionary=state.p4_wave.pending.pop_front()
		if float(event.at)<start-0.00001:
			fail(state,"missed event history; cannot reconstruct old positions")
			continue
		var observed: Array=actors.duplicate(true)
		var fraction := clampf((float(event.at)-start)/dt,0,1)
		for i in observed.size(): observed[i].pos=Rules.v(previous[i].pos).lerp(Rules.v(actors[i].pos),fraction)
		state.sim_time=float(event.at)
		resolve(event,observed,state)
		state.sim_time=finish
		P.sorted(state.p4_wave.pending)
static func living_hits(shape: Dictionary, actors: Array, state: Dictionary) -> Array:
	return Rules.hits(shape,actors).filter(func(i):return i not in state.dead)
static func resolve(event: Dictionary, actors: Array, state: Dictionary) -> void:
	var record: Dictionary=event.duplicate(true)
	match str(event.kind):
		"markers":
			state.p4_wave.markers=event.targets.map(func(i):return int(i))
			if state.p4_wave.markers.size()!=2 or state.p4_wave.markers[0]==state.p4_wave.markers[1]: fail(state,"invalid stack target event")
		"protean":
			record.beams=[]; record.hits=[]
			# Snapshot the whole raid before applying deaths: simultaneous beams.
			var victims: Array=[]
			for target in actors.size():
				if target in state.dead: continue
				var shape := P.beam(Rules.v(event.origin),Rules.v(actors[target].pos))
				var caught := living_hits(shape,actors,state)
				record.beams.append(shape.duplicate(true)); record.hits.append(caught)
				for actor in caught:load("res://scripts/statuses.gd").give(state,actor,"magic_vulnerability",2.0)
				if caught != [target]: victims.append_array(caught)
				state.p4_wave.pending.append({"kind":"repeat","at":event.repeat_at,"locked_at":event.at,"cycle":event.cycle,"owner":target,"shape":shape})
			if not victims.is_empty(): fail(state,"protean overlap",victims)
		"repeat", "ring":
			var caught := living_hits(event.shape,actors,state)
			record.hits=caught
			if not caught.is_empty(): fail(state,str(event.kind)+" hit "+str(caught),caught)
		"stack":
			var targets: Array=state.p4_wave.markers.map(func(i):return int(i))
			var coverage: Array=[]; coverage.resize(actors.size()); coverage.fill(0)
			record.lines=[]; record.hits=[]
			var bad := targets.size()!=2
			for target in targets:
				if target<0 or target>=actors.size() or target in state.dead:
					bad=true
					continue
				var shape := P.beam(Rules.v(event.origin),Rules.v(actors[target].pos))
				var caught := living_hits(shape,actors,state)
				record.lines.append(shape); record.hits.append(caught)
				for actor in caught:load("res://scripts/statuses.gd").give(state,actor,"magic_vulnerability",2.0)
				if caught.size()!=4: bad=true
				for actor in caught: coverage[actor]+=1
			for actor in actors.size():
				if actor in state.dead or coverage[actor]!=1: bad=true
			record.coverage=coverage
			if bad: fail(state,"two line shares require four living players each and exactly one line per player",range(actors.size()))
			state.p4_wave.markers=[]
		_: fail(state,"unknown event "+str(event.kind))
	state.p4_wave.history.append(record)
	state.timeline.append({"kind":"p4_wave_"+str(event.kind),"time":event.at,"details":record.duplicate(true)})
static func sync(beat: Dictionary, state: Dictionary) -> void:
	if not state.has("p4_wave"): return
	if not beat.has("shapes"): beat.shapes=[]
	beat.shapes=beat.shapes.filter(func(s):return not s.get("p4_wave_preview",false))
	for target in state.p4_wave.markers:
		beat.shapes.append({"kind":"circle","actor":int(target),"radius":1.0,"name":"Line stack marker","decorative":true,"p4_wave_preview":true})
	var now := float(state.get("sim_time",0))
	for event in state.p4_wave.pending:
		if event.kind not in ["repeat","ring"]: continue
		if event.kind=="ring" and float(event.at)>now+2.1: continue
		var shape: Dictionary=event.shape.duplicate(true)
		shape.pos=Rules.v(shape.pos); shape.decorative=true; shape.p4_wave_preview=true
		beat.shapes.append(shape)
