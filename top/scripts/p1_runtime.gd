# SPDX-License-Identifier: MIT
extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const Patterns = preload("res://scripts/p1_patterns.gd")

static func begin(beat: Dictionary, state: Dictionary) -> void:
	if beat.has("program_loop"): Rules.ensure_loop_state(beat,state)
	if not beat.has("p1_events"): return
	if not state.has("p1"): state.p1={"pending":[],"history":[],"until":0.0}
	var now := float(state.get("sim_time",0))
	state.p1.coaching_origin=now
	for raw in beat.p1_events:
		var event: Dictionary=raw.duplicate(true)
		event.at=now+float(event.at)
		state.p1.pending.append(event)
	state.p1.until=maxf(float(state.p1.until),now+float(beat.get("p1_duration",beat.duration)))
	Patterns.sorted(state.p1.pending)

static func fail(state: Dictionary, reason: String, victims: Array=[]) -> void:
	state.runtime_failures.append(reason)
	for actor in victims:
		if actor not in state.dead: state.dead.append(actor)

static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	Rules.tick_loop_state(state)
	if not state.has("p1") or dt<=0: return
	var finish:=float(state.sim_time); var start:=finish-dt
	if start>=float(state.p1.until) and state.p1.pending.is_empty(): return
	state.dead=state.dead.map(func(i):return int(i))
	for i in actors.size():
		var budget: float=state.motion_allowances[i] if state.get("motion_allowances",[]).size()==actors.size() else 6.0*dt
		if Rules.v(actors[i].pos).distance_to(Rules.v(previous[i].pos))>budget+0.001: fail(state,"P1 movement exceeds authorized walking/Sprint/dash budget: %d" % i,[i])
		if Rules.v(actors[i].pos).length()>=20: fail(state,"P1 death wall: %d" % i,[i])
	while not state.p1.pending.is_empty() and float(state.p1.pending[0].at)<=finish+0.000001:
		var event: Dictionary=state.p1.pending.pop_front()
		if float(event.at)<start-0.00001:
			fail(state,"P1 missed event history; cannot reconstruct bait at %.3f" % event.at)
			continue
		var sample: Array=actors.duplicate(true)
		for i in sample.size(): sample[i].pos=Rules.v(previous[i].pos).lerp(Rules.v(actors[i].pos),clampf((float(event.at)-start)/dt,0,1))
		state.sim_time=float(event.at)
		resolve(event,sample,state)
		state.sim_time=finish
		Patterns.sorted(state.p1.pending)

static func resolve(event: Dictionary, actors: Array, state: Dictionary) -> void:
	var record:=event.duplicate(true)
	var status=load("res://scripts/statuses.gd")
	record.observed_positions=[]
	for actor in actors: record.observed_positions.append(Patterns.xy(Rules.v(actor.pos)))
	match str(event.kind):
		"bait":
			record.positions=[]
			for i in actors.size():
				var p:=Patterns.xy(Rules.v(actors[i].pos)); record.positions.append(p)
				state.p1.pending.append({"kind":"hazard","ability_id":31500,"at":float(event.at)+float(event.delay),"locked_at":event.at,"owner":i,"bait":event.bait,"shape":{"kind":"circle","pos":p,"radius":5.0,"name":"Ballistic Missile"}})
		"hazard":
			record.hits=Rules.hits(event.shape,actors)
			if not record.hits.is_empty(): fail(state,"P1 %s at %.3f hit %s" % [event.shape.name,event.at,str(record.hits)],record.hits)
		"missile_beam":
			record.missile_hits=[]; record.beam_hits=[]; record.aims=[]
			var coverage: Array=[]; coverage.resize(actors.size()); coverage.fill(0)
			for raw in event.missiles:
				var target:=int(raw); var caught:=Rules.hits({"actor":target,"radius":5.0},actors)
				record.missile_hits.append(caught)
				if state.has("statuses"):
					for key in ["first_in_line","second_in_line","third_in_line","fourth_in_line"]:
						if state.statuses[target].has(key):
							state.statuses[target].erase(key);status.event(state,"status_remove",{"actor":target,"status":key,"time":event.at,"cause":"Guided Missile Kyrios"})
				for actor in caught: status.give(state,actor,"magic_vulnerability",2.0)
				for actor in caught: coverage[actor]+=1
				if caught!=[target]: fail(state,"P1 Guided Missile %d overlaps at %.3f" % [target,event.at],caught)
			for raw in event.beams:
				var target:=int(raw); var shape:=Patterns.beam(target); var caught:=Rules.hits(shape,actors)
				for actor in caught: status.give(state,actor,"magic_vulnerability",2.0)
				record.beam_hits.append(caught); record.aims.append(Patterns.xy(Rules.aim(shape,actors)))
				for actor in caught: coverage[actor]+=1
				if caught.size()!=3: fail(state,"P1 Condensed Wave target %d requires three, hit %s at %.3f" % [target,str(caught),event.at],caught)
			for actor in coverage.size():
				if int(coverage[actor])!=1: fail(state,"P1 missile/beam coverage must hit each actor exactly once: %d" % actor,[actor])
		"proteans":
			record.hits=[]
			for raw in event.targets:
				var target:=int(raw); var caught:=Rules.hits(Patterns.beam(target),actors)
				record.hits.append(caught)
				for actor in caught: status.give(state,actor,"magic_vulnerability",10.0)
				if caught!=[target]: fail(state,"P1 Wave Cannon %d clips %s" % [target,str(caught)],caught)
		"cleaves":
			var ranked:=range(actors.size())
			ranked.sort_custom(func(a,b):return Rules.v(actors[a].pos).length_squared()>Rules.v(actors[b].pos).length_squared())
			record.targets=ranked.slice(0,2); record.hits=[]; record.aims=[]
			if not (0 in record.targets and 1 in record.targets): fail(state,"P1 Diffuse Wave actual furthest targets are not both tanks",record.targets)
			for target in record.targets:
				var shape: Dictionary={"kind":"cone","pos":[0,0],"target":target,"width":120.0,"radius":60.0}
				var caught:=Rules.hits(shape,actors); record.hits.append(caught); record.aims.append(Patterns.xy(Rules.aim(shape,actors)))
				for actor in caught: status.give(state,actor,"magic_vulnerability",2.0)
				for actor in caught:
					if actor>=2: fail(state,"P1 tank cleave hit non-tank %d" % actor,[actor])
			record.damage_model="role and geometry only; invulnerability/mitigation HP unmodeled"
		_: fail(state,"Unknown P1 event: "+str(event.kind))
	state.p1.history.append(record)
	state.timeline.append({"kind":"p1_"+str(event.kind),"time":event.at,"details":record.duplicate(true)})

static func sync(beat: Dictionary, state: Dictionary) -> void:
	if not state.has("p1"): return
	if not beat.has("shapes"): beat.shapes=[]
	beat.shapes=beat.shapes.filter(func(s):return not s.get("p1_preview",false))
	var now:=float(state.get("sim_time",0))
	for event in state.p1.pending:
		if event.kind!="hazard": continue
		if not event.has("locked_at") and float(event.at)>now+(4.0 if int(event.get("ability_id",0)) in [31501,32368] else 2.0): continue
		var shape: Dictionary=event.shape.duplicate(true)
		shape.pos=Rules.v(shape.get("pos",[0,0])); shape.decorative=true; shape.p1_preview=true
		beat.shapes.append(shape)

static func coaching_goal(actor: int, beat: Dictionary, state: Dictionary) -> Vector2:
	var c:Dictionary=beat.p1_path
	# Preserve the validated0.1s waypoint cadence without creating323 UI checkpoints.
	var now:=float(state.get("sim_time",0))-float(state.p1.coaching_origin)
	var target_time:=clampf((floorf((now+0.000001)*10.0)+1)*0.1,0.1,32.3)
	return load("res://scripts/p1_courses.gd").panto_point(target_time,int(c.numbers[actor]),float(c.base)+int(c.groups[actor])*180,int(c.direction),bool(c.outer))
