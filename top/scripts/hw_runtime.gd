# SPDX-License-Identifier: MIT
extends RefCounted
## HW owns its clock while active. No route goals or expected role are read here.
const Rules = preload("res://scripts/rules.gd")
const P = preload("res://scripts/hw_patterns.gd")

static func status(): return load("res://scripts/statuses.gd")

static func begin(beat: Dictionary, state: Dictionary) -> void:
	if not beat.has("hw_events"): return
	var now := float(state.get("sim_time",0.0))
	state.hw={"pending":beat.hw_events.duplicate(true),"history":[],"until":now+float(beat.get("hw_duration",130.0)),"start":now,"policy":{"contact_radius":status().parameter("rot_contact_radius"),"same_colour":status().parameter("same_colour_policy"),"simultaneous":status().parameter("simultaneous_rot_policy"),"local_distance":10.0,"remote_distance":7.0,"threshold_provenance":"inferred, not exact server boundaries: 32 paired P3 removals in four captures; ordinary Local distance7.93..10.45, Remote7.48..8.94, interpolated player samples; old3/30 contradicted"}}
	for item in state.hw.pending: item.at=float(item.at)+now
	record(state,"hw_policy",{"parameters":state.hw.policy.duplicate(true),"tower_radius":P.TOWER_RADIUS,"origin_radius":P.ORIGIN_RADIUS,"timing":"nominal capture-normalized schedule; see hw_routes.json"})
	for grant in beat.get("hw_initial",[]): status().give(state,int(grant.actor),str(grant.name),float(grant.duration))

static func record(state: Dictionary, kind: String, details: Dictionary) -> void:
	var entry := details.duplicate(true); entry.kind=kind; entry.time=snappedf(float(state.sim_time),0.000001)
	state.hw.history.append(entry)
	state.timeline.append(entry.duplicate(true))

static func fail(state: Dictionary, reason: String) -> void:
	status().fail(state,"HW: "+reason)

static func sample(actors: Array, previous: Array, fraction: float) -> Array:
	var result := actors.duplicate(true)
	for i in result.size(): result[i].pos=Rules.v(previous[i].pos).lerp(Rules.v(actors[i].pos),fraction)
	return result

static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> bool:
	if not state.has("hw") or dt<=0: return false
	# Canonical nanosecond clock avoids JSON's decimal roundtrip moving an
	# event across a numerical subdivision boundary on a resumed run.
	var finish := snappedf(float(state.sim_time),0.000000001)
	var start := snappedf(finish-dt,0.000000001)
	if start>=float(state.hw.until): return false
	state.dead=state.dead.map(func(a):return int(a))
	for actor in actors.size():
		var allowance := 6.0*dt
		if state.get("motion_allowances",[]).size()==actors.size(): allowance=minf(7.5*dt,float(state.motion_allowances[actor]))
		if Rules.v(previous[actor].pos).distance_to(Rules.v(actors[actor].pos))>allowance+0.001: fail(state,"walking/Sprint budget exceeded: actor %d" % actor)
	var cursor := start
	var last := sample(actors,previous,0.0)
	while cursor<finish-0.0000001:
		var next := minf(finish,cursor+0.025)
		if not state.hw.pending.is_empty(): next=minf(next,maxf(cursor,float(state.hw.pending[0].at)))
		for buffs in state.statuses:
			for buff in buffs.values():
				if float(buff.expires)>cursor+0.0000001: next=minf(next,float(buff.expires))
		next=snappedf(next,0.000000001)
		state.sim_time=next
		var observed := sample(actors,previous,clampf((next-start)/dt,0.0,1.0))
		expire(observed,state)
		while not state.hw.pending.is_empty() and float(state.hw.pending[0].at)<=next+0.0000001:
			resolve(state.hw.pending.pop_front(),observed,state)
		status().contacts(observed,last,state)
		regressions(observed,state)
		cursor=next; last=observed
	state.sim_time=finish
	return true

static func expire(actors: Array, state: Dictionary) -> void:
	var due: Array=[]
	for actor in state.statuses.size():
		for name in state.statuses[actor]:
			if float(state.statuses[actor][name].expires)<=float(state.sim_time)+0.0000001: due.append([actor,name])
	# Capture all due entries first: actual blasts may grant the next bug, but
	# cannot make that new bug expire in this batch.
	# JSON sorts dictionary keys. Use an explicit stable event order rather
	# than allowing insertion order to change replay history after restore.
	due.sort_custom(func(a,b):return int(a[0])<int(b[0]) if a[0]!=b[0] else str(a[1])<str(b[1]))
	for entry in due: state.statuses[int(entry[0])].erase(str(entry[1]))
	for entry in due:
		var actor: int=entry[0]; var name: String=entry[1]
		record(state,"hw_status_expire",{"actor":actor,"status":name})
		if name.begins_with("smell_"):
			status().give(state,actor,name.trim_prefix("smell_"),P.ROT_DURATION if name in ["smell_red","smell_blue"] else P.BUG_DURATION)
		elif name.begins_with("latent_"):
			fail(state,"actor %d: %s expired" % [actor,name])
		elif name in ["red","blue","overflow","sync"]:
			if actor in state.dead: continue
			state.statuses[actor][name+"_debugger"]={"expires":float(state.sim_time)+9999.0}
			var radius := 5.0 if name!="overflow" else 20.0
			var hits := Rules.hits({"actor":actor,"radius":radius},actors)
			record(state,"hw_blast",{"actor":actor,"status":name,"hits":hits})
			if name in ["red","blue"]:
				if actor not in state.dead: state.statuses[actor].erase("latent_"+name)
				for other in hits:
					if other!=actor:
						fail(state,"rot expiry blast %d -> %d" % [actor,other])
						if other not in state.dead:
							state.dead.append(other)
							state.statuses[other].clear()
			else:
				if name=="sync" and hits.size()<2: fail(state,"unshared Synchronization: actor %d" % actor)
				for other in hits:
					state.statuses[other].erase("latent_"+name)
					if other!=actor: status().give(state,other,name,P.BUG_DURATION,actor)
				for other in hits:
					if state.statuses[other].has("magic_vulnerability"): fail(state,"overlapping HW magic damage: actor %d" % other)
					# Four captures: status2941 960..1000ms on all eight from bugs.
					status().give(state,other,"magic_vulnerability",1.0)

static func resolve(event: Dictionary, actors: Array, state: Dictionary) -> void:
	match event.kind:
		"regression":
			state.paired_tethers.append({"id":event.id,"kind":event.regression,"a":int(event.a),"b":int(event.b),"active_at":event.at,"expires":float(event.at)+float(event.duration),"broken":false,"status_id":event.status_id})
		"towers":
			for tower in event.towers:
				var hits := Rules.hits({"pos":tower.pos,"radius":tower.radius},actors)
				record(state,"hw_tower",{"round":event.round,"pos":tower.pos,"radius":tower.radius,"colour":tower.colour,"hits":hits})
				if hits.size()!=1: fail(state,"tower requires one soaker, got %s" % str(hits))
				for actor in hits: status().give(state,actor,"latent_"+str(tower.colour),10.0)
		"critical_error":
			var blocked: Array=[]
			for actor in actors.size():
				if state.statuses[actor].has("overflow_debugger"): blocked.append(actor)
				else: fail(state,"Critical Error lacks Overflow Debugger: actor %d" % actor)
				status().give(state,actor,"overflow",P.BUG_DURATION)
			record(state,"hw_critical_error",{"blocked":blocked})
		_: fail(state,"unknown event "+str(event.kind))

static func regressions(actors: Array, state: Dictionary) -> void:
	for tether in state.paired_tethers:
		if not str(tether.id).begins_with("hw_") or tether.broken or float(state.sim_time)<float(tether.active_at)-0.0000001: continue
		var distance := Rules.v(actors[int(tether.a)].pos).distance_to(Rules.v(actors[int(tether.b)].pos))
		var threshold := float(state.hw.policy.local_distance if tether.kind=="local" else state.hw.policy.remote_distance)
		if float(state.sim_time)>=float(tether.expires)-0.0000001:
			tether.broken=true; fail(state,"Regression expired: "+str(tether.id))
		elif (distance<=threshold if tether.kind=="local" else distance>=threshold):
			tether.broken=true; tether.broken_at=float(state.sim_time)
			record(state,"hw_patch",{"id":tether.id,"distance":distance})
			for actor in actors.size():
				var stacks := int(state.statuses[actor].get("thrice_come_ruin",{}).get("stacks",0))+2
				state.statuses[actor].thrice_come_ruin={"expires":float(state.sim_time)+1.0,"stacks":stacks}
				if stacks>=3: fail(state,"Thrice-come Ruin: actor %d" % actor)
			# Both endpoints are one paired Patch packet group, not two separate
			# vulnerability checks against each other.
			status().magic_hit(state,range(actors.size()),"HW Patch "+str(tether.id))

static func sync(beat: Dictionary, state: Dictionary) -> void:
	if not state.has("hw"): return
	if not beat.has("shapes"): beat.shapes=[]
	beat.shapes=beat.shapes.filter(func(s):return not s.get("hw_preview",false))
	var now := float(state.get("sim_time",0.0))
	for event in state.hw.pending:
		if event.kind!="towers" or float(event.at)-now>10.0: continue
		for tower in event.towers:
			beat.shapes.append({"kind":"tower","pos":Rules.v(tower.pos),"radius":tower.radius,"name":"HW "+str(tower.colour),"decorative":true,"hw_preview":true})
