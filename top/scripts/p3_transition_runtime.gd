# SPDX-License-Identifier: MIT
extends RefCounted
## Actual positions and encounter events only. No guide grants, goal snapping or immunity.
const P = preload("res://scripts/p3_transition_patterns.gd")
const Rules = preload("res://scripts/rules.gd")
static func fail(state: Dictionary, reason: String, victims: Array=[]) -> void:
	var message: String="P3 transition: "+reason
	if message not in state.runtime_failures: state.runtime_failures.append(message)
	for a in victims:
		if int(a) not in state.dead: state.dead.append(int(a))
static func begin(beat: Dictionary, state: Dictionary) -> void:
	if not beat.has("p3_transition_events"): return
	var now:=float(state.get("sim_time",0))
	if state.has("p3_transition") and now<float(state.p3_transition.until):
		fail(state,"duplicate/overlapping course begin"); return
	var zone: Dictionary=beat.p3_transition_void.duplicate(true)
	zone.start=float(zone.start)+now; zone.end=float(zone.end)+now
	state.p3_transition={"pending":[],"history":[],"arms":{},"origin":now,"until":now+float(beat.p3_transition_duration),"void":zone,"purple":[],"white":[],"packets":[],"last_time":now}
	for raw in beat.p3_transition_events:
		var e: Dictionary=raw.duplicate(true); e.at=float(e.at)+now
		if e.kind=="marks": e.expires=float(e.expires)+now
		if e.kind=="arm_cue":
			e.entity.at=float(e.entity.at)+now; e.entity.cue_at=float(e.entity.cue_at)+now
			if e.entity.has("cast_at"): e.entity.cast_at=float(e.entity.cast_at)+now
		state.p3_transition.pending.append(e)
	P.sort_events(state.p3_transition.pending)
static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	if not state.has("p3_transition") or dt<=0: return
	var r: Dictionary=state.p3_transition
	var finish:=float(state.sim_time); var start:=finish-dt
	if start>=float(r.until) and r.pending.is_empty(): return
	state.dead=state.dead.map(func(a):return int(a))
	if absf(start-float(r.last_time))>0.0001: fail(state,"non-contiguous time; checkpoint cannot reconstruct missing positions")
	r.last_time=finish
	for a in actors.size():
		var from:=Rules.v(previous[a].pos); var to:=Rules.v(actors[a].pos)
		var budget: float=float(state.motion_allowances[a]) if state.get("motion_allowances",[]).size()==actors.size() else 6.0*dt
		if from.distance_to(to)>budget+0.001: fail(state,"movement exceeds walking / explicit parent allowance actor %d"%a,[a])
		if maxf(from.length(),to.length())>=20.0: fail(state,"death wall actor %d"%a,[a])
		var lo:=maxf(start,float(r.void.start)); var hi:=minf(finish,float(r.void.end))
		if lo<hi:
			var p:=from.lerp(to,(lo-start)/dt); var q:=from.lerp(to,(hi-start)/dt)
			if Geometry2D.get_closest_point_to_segment(Vector2.ZERO,p,q).length()<=float(r.void.radius): fail(state,"central voidzone swept contact actor %d"%a,[a])
	while not r.pending.is_empty() and float(r.pending[0].at)<=finish+0.000001:
		var e: Dictionary=r.pending.pop_front()
		if float(e.at)<start-0.0001:
			fail(state,"missed event at %.3f"%float(e.at)); continue
		var sample: Array=actors.duplicate(true)
		for a in actors.size(): sample[a].pos=Rules.v(previous[a].pos).lerp(Rules.v(actors[a].pos),clampf((float(e.at)-start)/dt,0,1))
		resolve(e,sample,state)
static func resolve(e: Dictionary, actors: Array, state: Dictionary) -> void:
	var r: Dictionary=state.p3_transition
	var record: Dictionary=e.duplicate(true)
	record.positions=actors.map(func(a):return P.xy(Rules.v(a.pos)))
	match str(e.kind):
		"marks":
			r.purple=e.purple.duplicate(); r.white=e.white.duplicate()
			for a in r.purple: state.statuses[int(a)].sniper_cannon_fodder={"expires":e.expires,"source":"p3_transition_encounter"}
			for a in r.white: state.statuses[int(a)].high_powered_sniper_cannon_fodder={"expires":e.expires,"source":"p3_transition_encounter"}
		"ring":
			record.hits=Rules.hits(e.shape,actors)
			if not record.hits.is_empty(): fail(state,"Wave Repeater %d hits %s at %.3f"%[int(e.ring)+1,str(record.hits),float(e.at)],record.hits)
		"arm_cue":
			var arm: Dictionary=e.entity.duplicate(true)
			arm.locked_pos=arm.pos.duplicate(); arm.locked_at=e.at; arm.casting=false; arm.resolved=false
			r.arms[arm.id]=arm
		"arm_cast":
			if not r.arms.has(e.id): fail(state,"arm cast without source cue: "+str(e.id))
			else: r.arms[e.id].casting=true
		"arm_hit":
			if not r.arms.has(e.id): fail(state,"arm hit without locked source: "+str(e.id))
			else:
				var arm: Dictionary=r.arms[e.id]
				record.origin=arm.locked_pos.duplicate(); record.hits=Rules.hits({"pos":arm.locked_pos,"radius":11.0},actors)
				if not record.hits.is_empty(): fail(state,"Colossal Blow %s hits %s"%[str(e.id),str(record.hits)],record.hits)
				arm.resolved=true
		"sniper": resolve_snipers(e,actors,state,record)
		_: fail(state,"unknown event "+str(e.kind))
	r.history.append(record)
	state.timeline.append({"kind":"p3_transition_"+str(e.kind),"time":e.at,"details":record.duplicate(true)})
static func resolve_snipers(e: Dictionary, actors: Array, state: Dictionary, record: Dictionary) -> void:
	var r: Dictionary=state.p3_transition
	var purple: Array=[]; var white: Array=[]
	# Current encounter statuses, never route rank or suggested slot.
	for a in actors.size():
		if state.statuses[a].has("sniper_cannon_fodder"): purple.append(a)
		if state.statuses[a].has("high_powered_sniper_cannon_fodder"): white.append(a)
	if not P.valid_partition(purple,white): fail(state,"missing/invalid current sniper debuffs; early-loss retarget unmodeled")
	var counts: Array=[]; counts.resize(actors.size()); counts.fill(0)
	var dead_before: Array=state.dead.duplicate()
	if not dead_before.is_empty(): fail(state,"party death before sniper resolution; corpses cannot share")
	record.packets=[]
	for owner in purple+white:
		if owner in dead_before:
			fail(state,"dead marked owner; authentic random retarget unresolved",[owner]); continue
		var hits: Array=Rules.hits({"actor":owner,"radius":6.0},actors).filter(func(a):return a not in dead_before)
		var stack: bool=owner in white
		if hits.size()!=(2 if stack else 1): fail(state,"%s owner %d count %d"%["white" if stack else "purple",owner,hits.size()],hits)
		for a in hits:
			counts[a]+=1
			if a!=owner and (a in purple or a in white): fail(state,"collateral marked target %d from %d"%[a,owner],[a])
			var vuln: Dictionary=state.statuses[a].get("magic_vulnerability",{})
			if counts[a]>1 or float(vuln.get("expires",-1))>float(e.at): fail(state,"deadly Magic Vulnerability actor %d"%a,[a])
		var packet: Dictionary={"owner":owner,"ability_id":31572 if stack else 31571,"hits":hits,"at":e.at,"damage_type":"magic","hp_model":"unmodeled: shields/HP required in actual encounter"}
		record.packets.append(packet); r.packets.append(packet.duplicate(true))
	for a in actors.size():
		if counts[a]!=1: fail(state,"expected one magic packet actor %d, got %d"%[a,counts[a]],[a])
		if counts[a]>0: state.statuses[a].magic_vulnerability={"expires":float(e.at)+1.96,"source":"p3_transition_sniper"}
		state.statuses[a].erase("sniper_cannon_fodder"); state.statuses[a].erase("high_powered_sniper_cannon_fodder")
	record.coverage=counts
static func sync(beat: Dictionary, state: Dictionary) -> void:
	if not state.has("p3_transition"): return
	var r: Dictionary=state.p3_transition; var now:=float(state.get("sim_time",0))
	if not beat.has("shapes"): beat.shapes=[]
	if not beat.has("stage_entities"): beat.stage_entities=[]
	beat.shapes=beat.shapes.filter(func(s):return not s.get("p3_transition_preview",false))
	beat.stage_entities=beat.stage_entities.filter(func(s):return not s.get("p3_transition_entity",false))
	if now>=float(r.until): return
	beat.stage_entities.append({"id":"p3_transition_boss","form":"final","pos":[0,0],"name":"Omega Reconfigured","p3_transition_entity":true})
	if now>=float(r.void.start) and now<float(r.void.end): beat.shapes.append({"kind":"circle","pos":Vector2.ZERO,"radius":6.0,"decorative":true,"p3_transition_preview":true,"name":"Central voidzone (window approximate)"})
	# Teaching overlays only. Parent must not present these as original game VFX.
	for e in r.pending:
		if e.kind=="ring" and float(e.at)-now<=(5.0 if int(e.ring)==0 else 2.1):
			var shape: Dictionary=e.shape.duplicate(true)
			shape.pos=Rules.v(shape.pos); shape.decorative=true; shape.p3_transition_preview=true
			shape.name="Wave Repeater"; beat.shapes.append(shape)
	for a in state.statuses.size():
		if state.statuses[a].has("sniper_cannon_fodder") or state.statuses[a].has("high_powered_sniper_cannon_fodder"):
			beat.shapes.append({"kind":"circle","actor":a,"radius":6.0,"decorative":true,"p3_transition_preview":true,"name":"Sniper radius (instructional preview)","instructional":true})
	for arm in r.arms.values():
		if arm.resolved: continue
		beat.stage_entities.append({"id":arm.id,"form":arm.form,"pos":arm.locked_pos.duplicate(),"p3_transition_entity":true,"cue":{"timeline_ids":["1E43","1E44"],"relative_time":float(arm.cue_at)-float(r.origin),"confidence":"hit minus 13.5s reference; timeline ID alternative not measured","rendering":"original model plus instructional cue, not authentic game VFX"},"form_confidence":arm.form_confidence})
		if arm.casting: beat.shapes.append({"kind":"circle","pos":Rules.v(arm.locked_pos),"radius":11.0,"decorative":true,"p3_transition_preview":true,"name":"Colossal Blow"})
