# SPDX-License-Identifier: MIT
extends RefCounted
## All durable P6 state is JSON-native. Pending events survive beat boundaries.
const Rules = preload("res://scripts/rules.gd")
const Patterns = preload("res://scripts/p6_patterns.gd")
const LB = preload("res://scripts/p6_lb.gd")

static func begin(beat: Dictionary, state: Dictionary) -> void:
	if not beat.has("p6_events"): return
	if not state.has("p6"): state.p6={"pending":[],"history":[],"locks":[],"until":0.0,"speed":6.0}
	var now := float(state.get("sim_time",0.0))
	for raw in beat.p6_events:
		var item: Dictionary=raw.duplicate(true)
		item.at=float(item.at)+now
		if item.has("telegraph_at"): item.telegraph_at=float(item.telegraph_at)+now
		state.p6.pending.append(item)
	state.p6.until=maxf(float(state.p6.until),now+float(beat.get("p6_duration",beat.duration)))
	Patterns.sorted(state.p6.pending)

static func failure(state: Dictionary, reason: String, victims: Array = []) -> void:
	state.runtime_failures.append(reason)
	for actor in victims:
		if actor not in state.dead: state.dead.append(actor)

static func sample(actors: Array, previous: Array, fraction: float) -> Array:
	var result: Array=actors.duplicate(true)
	for i in result.size(): result[i].pos=Rules.v(previous[i].pos).lerp(Rules.v(actors[i].pos),fraction)
	return result

static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	if not state.has("p6") or dt <= 0: return
	var finish := float(state.sim_time)
	var start := finish-dt
	if start >= float(state.p6.until)-0.00001 and state.p6.pending.is_empty() and state.p6.locks.all(func(lock):return float(lock.end)<=start) and not state.has("p6_lb"): return
	state.dead=state.dead.map(func(actor):return int(actor))
	for actor in actors.size():
		if Rules.v(previous[actor].pos).distance_to(Rules.v(actors[actor].pos)) > float(state.get("motion_allowances",[])[actor] if state.get("motion_allowances",[]).size()==actors.size() else 6.0*dt)+0.001:
			failure(state,"P6 movement exceeded authorized walking/Sprint/dash budget: actor %d" % actor,[actor])
	var lb_previous := previous
	var lb_at := start
	while not state.p6.pending.is_empty() and float(state.p6.pending[0].at)<=finish+0.000001:
		var event: Dictionary=state.p6.pending.pop_front()
		var at := float(event.at)
		if at < start-0.00001:
			failure(state,"P6 missed event history at %.3f; cannot reconstruct old bait" % at)
			continue
		var observed := sample(actors,previous,clampf((at-start)/dt,0,1))
		state.sim_time=at
		LB.tick(observed,lb_previous,state,at-lb_at)
		lb_previous=observed; lb_at=at
		resolve(event,observed,state)
		Patterns.sorted(state.p6.pending)
	state.sim_time=finish
	LB.tick(actors,lb_previous,state,finish-lb_at)
	for lock in state.p6.locks:
		var actor := int(lock.actor)
		var lo := maxf(start,float(lock.start)); var hi := minf(finish,float(lock.end))
		if hi>lo and Rules.v(previous[actor].pos).distance_to(Rules.v(actors[actor].pos))*(hi-lo)/dt>0.001:
			failure(state,"P6 LB animation lock moved: actor %d" % actor,[actor])
	state.p6.locks=state.p6.locks.filter(func(lock):return float(lock.end)>finish)

static func animation_lock(state: Dictionary, actor: int, duration: float) -> void:
	assert(state.has("p6") and duration>=0)
	state.p6.locks.append({"actor":actor,"start":float(state.get("sim_time",0.0)),"end":float(state.get("sim_time",0.0))+duration})

static func resolve(event: Dictionary, actors: Array, state: Dictionary) -> void:
	var record := event.duplicate(true)
	# Godot JSON parses numbers as floats; Array membership is type-sensitive.
	# Normalize IDs at the runtime boundary so restored flare eligibility agrees.
	var targets: Array=[]
	for target in event.get("targets",[]): targets.append(int(target))
	if event.has("targets"): record.targets=targets.duplicate()
	match event.kind:
		"lb_request":
			if state.get("p6_auto_lb",false) and int(event.actor)!=int(state.get("human_actor",-1)):
				record.result=LB.request_lb(state,int(event.actor),str(event.ability_kind),event.get("target"))
		"meteor_spawn":
			if state.has("p6_lb"): LB.spawn_meteors(state)
			else: failure(state,"P6 LB state must be initialized explicitly")
		"meteor_deadline":
			var alive: Array=[]
			var count := 0
			for npc in state.get("p6_lb",{}).get("targets",[]):
				if int(npc.npc_id)==int(event.npc_id):
					count+=1
					if float(npc.hp)>0: alive.append(npc.id)
			record.alive=alive
			if count!=(6 if int(event.npc_id)==15727 else 2) or not alive.is_empty(): failure(state,"P6 missing/late meteor LB kills: "+str(alive),range(8))
		"memory", "magic_number":
			if not LB.entry_ready(state): failure(state,"P6 entry requires three Dynamis on all eight actors",range(8))
			if not LB.tank_active(state,float(event.at)): failure(state,"P6 %s requires applied Tank LB3 before snapshot" % event.kind,range(8))
			if state.has("p6_lb"):
				if event.kind=="memory":
					if state.dead.is_empty(): state.p6_lb.brilliant=range(8)
					state.p6_lb.memory_entry=false
				else: state.p6.pending.append({"kind":"doom_apply","at":float(event.at)+2.0})
		"doom_apply":
			if state.has("p6_lb"): state.p6_lb.doom.append({"expires":float(event.at)+6.0,"targets":range(8)})
		"bait":
			record.positions=[]
			for actor in actors.size():
				var p := Patterns.xy(Rules.v(actors[actor].pos))
				record.positions.append(p)
				state.p6.pending.append({"at":float(event.at)+float(event.delay),"telegraph_at":event.at,"kind":"hazard","bait":event.get("bait",-1),"owner":actor,"locked_at":event.at,"shape":{"kind":"circle","pos":p,"radius":event.radius,"name":event.get("name","Puddle")}})
		"hazard":
			var caught := Rules.hits(event.shape,actors)
			record.hits=caught
			if not caught.is_empty(): failure(state,"P6 %s at %.3f hit %s" % [event.shape.name,event.at,str(caught)],caught)
		"proteans":
			record.hits=[]
			for target in targets:
				var caught := Rules.hits(Patterns.beam(int(target)),actors)
				record.hits.append(caught)
				if caught != [int(target)]: failure(state,"P6 8-wide protean clipped: target %d hits %s" % [target,str(caught)],caught)
		"charge":
			var beam := Patterns.beam(int(event.target))
			var caught := Rules.hits(beam,actors)
			var axis := Rules.aim(beam,actors)
			caught.sort_custom(func(a,b):return Rules.v(actors[a].pos).dot(axis)<Rules.v(actors[b].pos).dot(axis))
			record.hits=caught; record.aim=Patterns.xy(axis)
			if caught.size()!=8 or not (caught[0] in [0,1] and caught[1] in [0,1]): failure(state,"P6 wild charge requires all eight and BOTH front tanks",caught)
		"dive":
			var nearest := range(actors.size())
			nearest.sort_custom(func(a,b):return Rules.v(actors[a].pos).length_squared()<Rules.v(actors[b].pos).length_squared())
			record.tanks=nearest.slice(0,2); record.stack_target=nearest[-1]
			if not (nearest[0] in [0,1] and nearest[1] in [0,1]): failure(state,"P6 Dive closest two are not tanks",nearest.slice(0,2))
			for target in nearest.slice(0,2):
				var caught := Rules.hits({"actor":target,"radius":8.0},actors)
				if caught != [target]: failure(state,"P6 Dive radius-8 overlap",caught)
			var stack := Rules.hits({"actor":nearest[-1],"radius":6.0},actors)
			if stack.size()!=6 or 0 in stack or 1 in stack: failure(state,"P6 Dive radius-6 party stack",stack)
		"spread":
			for target in targets:
				var caught := Rules.hits({"actor":target,"radius":5.0},actors)
				if caught != [int(target)]: failure(state,"P6 Meteor radius-5 spread overlap",caught)
		"flare_markers":
			state.p6.flare_targets=targets.duplicate()
		"flares":
			state.p6.flare_targets=[]
			var caught := Rules.hits({"actor":event.stack_target,"radius":6.0},actors)
			var required: Array=[]
			for actor in actors.size():
				if actor not in targets: required.append(actor)
			if caught!=required: failure(state,"P6 Meteor radius-6 five-player stack",caught)
			# Range is 100, NOT a radius-12 no-damage circle. Preserve distances
			# for inspection; no unverified damage curve / mitigation verdict.
			record.falloff="unmodeled"; record.distances=[]
			if state.has("p6_lb"):
				record.damage_packets=preload("res://scripts/p6_damage.gd").flares(actors,targets,state)
				record.falloff="empirical bounds; interior unresolved"
			for target in targets:
				var distances: Array=[]
				for actor in actors: distances.append(Rules.v(actor.pos).distance_to(Rules.v(actors[target].pos)))
				record.distances.append(distances)
		"lock":
			state.p6.locks.append({"actor":event.actor,"start":event.at,"end":float(event.at)+float(event.duration)})
		_:
			failure(state,"Unknown P6 event: "+str(event.kind))
	state.p6.history.append(record)
	# Existing report() exports the common timeline; keep observed P6 outcomes
	# visible there too. The pending queue/locks remain in state.p6 for retries.
	state.timeline.append({"kind":"p6_"+str(event.kind),"time":event.at,"details":record.duplicate(true)})

static func sync(beat: Dictionary, state: Dictionary) -> void:
	if not state.has("p6"): return
	if not beat.has("shapes"): beat.shapes=[]
	beat.shapes=beat.shapes.filter(func(s):return not s.get("p6_preview",false))
	beat.p6_lb_targets=state.get("p6_lb",{}).get("targets",[]).duplicate(true)
	for npc in beat.p6_lb_targets:
		if float(npc.hp)>0: beat.shapes.append({"kind":"circle","pos":Rules.v(npc.pos),"radius":3.0 if int(npc.npc_id)==15726 else 1.0,"decorative":true,"p6_preview":true,"target_id":npc.id,"selectable":true,"name":npc.id})
	for target in state.p6.get("flare_targets",[]):
		beat.shapes.append({"kind":"circle","actor":int(target),"radius":1.0,"decorative":true,"p6_preview":true,"name":"Flare MARKER only; damage falloff unresolved"})
	var now := float(state.get("sim_time",0.0))
	for event in state.p6.pending:
		if event.kind!="hazard": continue
		if event.has("telegraph_at"):
			if float(event.telegraph_at)>now+0.000001: continue
		elif float(event.at)>now+2.1: continue
		var shape: Dictionary=event.shape.duplicate(true)
		shape.pos=Rules.v(shape.get("pos",[0,0])); shape.decorative=true; shape.p6_preview=true
		beat.shapes.append(shape)

static func is_locked(state: Dictionary,actor: int) -> bool:
	if LB.is_locked(state,actor): return true
	var now:=float(state.get("sim_time",0))
	for lock in state.get("p6",{}).get("locks",[]):
		if int(lock.actor)==actor and float(lock.start)<=now and float(lock.end)>now:return true
	return false

static func request_lb(state: Dictionary, actor: int, kind: String, target_or_position = null) -> Dictionary:
	return LB.request_lb(state,actor,kind,target_or_position)
