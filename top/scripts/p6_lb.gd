# SPDX-License-Identifier: MIT
extends RefCounted
## Explicit, JSON-native LB lifecycle. No legacy state.lb flags are consumed.
const Rules = preload("res://scripts/rules.gd")
# CastType4 XAxisModifier is FULL width; preserve a center-based model until
# independent NPC-hitbox/range-edge evidence supports inflation.
const RANGED_HALF_WIDTH := 4.0
const ACTIONS = {
	"PLD":{"id":199,"kind":"tank","cast":0.0},
	"WAR":{"id":4240,"kind":"tank","cast":0.0},
	"DRK":{"id":4241,"kind":"tank","cast":0.0},
	"GNB":{"id":17105,"kind":"tank","cast":0.0},
	"WHM":{"id":208,"kind":"healer","cast":2.0},
	"SCH":{"id":4247,"kind":"healer","cast":2.0},
	"AST":{"id":4248,"kind":"healer","cast":2.0},
	"SGE":{"id":24859,"kind":"healer","cast":2.0},
	"SMN":{"id":4246,"kind":"caster","cast":4.5},
	"PCT":{"id":34867,"kind":"caster","cast":4.5},
	"BLM":{"id":205,"kind":"caster","cast":4.5},
	"RDM":{"id":7862,"kind":"caster","cast":4.5},
	"BRD":{"id":4244,"kind":"ranged","cast":4.5},
	"MCH":{"id":4245,"kind":"ranged","cast":4.5},
	"DNC":{"id":17106,"kind":"ranged","cast":4.5},
	"MNK":{"id":202,"kind":"melee","cast":4.5},
	"NIN":{"id":4243,"kind":"melee","cast":4.5},
	"DRG":{"id":4242,"kind":"melee","cast":4.5},
	"SAM":{"id":7861,"kind":"melee","cast":4.5},
	"RPR":{"id":24858,"kind":"melee","cast":4.5},
	"VPR":{"id":34866,"kind":"melee","cast":4.5}
}

static func begin(state: Dictionary, actors: Array, config: Dictionary) -> void:
	# Caller supplies actual job identities, gauge, and entry buffs. Never reset
	# these at a beat boundary (or manufacture Brilliant from route progress).
	if state.has("p6_lb"): return
	state.p6_lb={"jobs":config.get("jobs",[]).duplicate(),"gauge":int(config.get("gauge",0)),"brilliant":config.get("brilliant",[]).duplicate(),"casts":[],"effects":[],"history":[],"targets":[],"tank_buffs":[],"doom":[],"next_id":1,"final_melee":false,"animation_seconds":config.get("animation_seconds",{}).duplicate(true)}
	if not state.has("spent"): state.spent=[]
	state.p6_lb.targets=config.get("targets",[]).duplicate(true)
	state.p6_lb.calibration={"cast_clock":"nominal Action.Cast100ms; DPS packets are ~0.53s shorter","damage_clock":"conservative packet envelope from PCT/SMN and BRD/MCH/DNC captures","animation":"unknown unless caller supplies job animation_seconds","ranged_width":"CastType4 XAxisModifier=8 is full width8 / half4 per pinned community conversion; NPC-hitbox and range-edge behavior unmeasured"}
	sync(actors,state)

static func sync(actors: Array, state: Dictionary) -> void:
	if not state.has("p6_lb"): return
	state.p6_lb.actors=[]
	for actor in actors: state.p6_lb.actors.append({"pos":[Rules.v(actor.pos).x,Rules.v(actor.pos).y],"face":float(actor.get("face",0))})

static func entry_ready(state: Dictionary, count := 8) -> bool:
	var stacks: Array=state.get("dynamis",[])
	return stacks.size()==count and stacks.all(func(n): return int(n)==3)

static func emit(state: Dictionary, kind: String, at: float, details: Dictionary = {}) -> void:
	var item := details.duplicate(true); item.kind=kind; item.at=at
	state.p6_lb.history.append(item)
	state.get("timeline",[]).append({"kind":"p6_"+kind,"time":at,"details":item.duplicate(true)})

static func reject(state: Dictionary, actor: int, reason: String) -> Dictionary:
	if state.has("p6_lb"): emit(state,"lb_rejected",float(state.get("sim_time",0)),{"actor":actor,"reason":reason})
	return {"ok":false,"reason":reason}

static func request_lb(state: Dictionary, actor: int, kind: String, target_or_position = null) -> Dictionary:
	if not state.has("p6_lb"): return reject(state,actor,"LB state not initialized")
	var lb: Dictionary=state.p6_lb
	state.spent=state.spent.map(func(a):return int(a))
	lb.brilliant=lb.brilliant.map(func(a):return int(a))
	if actor<0 or actor>=lb.jobs.size() or actor>=lb.actors.size(): return reject(state,actor,"Missing actual job/actor")
	var job := str(lb.jobs[actor])
	if not ACTIONS.has(job) or ACTIONS[job].kind!=kind: return reject(state,actor,"Wrong or unsupported job")
	if actor in state.get("dead",[]): return reject(state,actor,"Actor is dead")
	if not entry_ready(state): return reject(state,actor,"Three Dynamis required on entry")
	if is_locked(state,actor) or not lb.casts.is_empty(): return reject(state,actor,"LB already casting or animation locked")
	if int(lb.gauge)<30000: return reject(state,actor,"Insufficient LB3 gauge")
	var brilliant: bool=actor in lb.brilliant and actor not in state.spent
	if not brilliant and not (kind=="tank" and lb.get("memory_entry",false)) and not (kind=="melee" and lb.final_melee): return reject(state,actor,"Brilliant Dynamis absent or already spent")
	var position: Array=[]; var target := ""
	if kind in ["caster","ranged","melee"]:
		if target_or_position is Vector2 and kind=="caster": position=[target_or_position.x,target_or_position.y]
		elif target_or_position is Array and target_or_position.size()==2 and kind=="caster": position=target_or_position.duplicate()
		elif target_or_position is String:
			target=target_or_position
			for npc in lb.targets:
				if npc.id==target and float(npc.hp)>0 and bool(npc.get("targetable",true)): position=npc.pos.duplicate()
		if position.is_empty(): return reject(state,actor,"Invalid, dead or untargetable target")
		for coordinate in position:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)): return reject(state,actor,"Invalid ground position")
		if Rules.v(position).distance_to(Rules.v(lb.actors[actor].pos))>(25.0 if kind=="caster" else (30.0 if kind=="ranged" else 8.0)):
			return reject(state,actor,"Target out of range")
	var now := float(state.get("sim_time",0)); var action: Dictionary=ACTIONS[job]
	var cast := {"id":int(lb.next_id),"actor":actor,"kind":kind,"job":job,"action":action.id,"start":now,"finish":now+float(action.cast),"origin":lb.actors[actor].pos.duplicate(),"position":position,"target":target,"refund":brilliant}
	lb.next_id=int(lb.next_id)+1
	# Reserve the shared gauge at request; consume only on successful cast finish.
	lb.casts.append(cast); emit(state,"lb_begin",now,cast)
	return {"ok":true,"cast":cast.duplicate(true)}

static func is_locked(state: Dictionary, actor: int) -> bool:
	var now := float(state.get("sim_time",0))
	for cast in state.get("p6_lb",{}).get("casts",[]):
		if int(cast.actor)==actor: return true
	for effect in state.get("p6_lb",{}).get("effects",[]):
		if effect.kind=="unlock" and int(effect.actor)==actor and float(effect.at)>now: return true
	return false

static func finish_cast(state: Dictionary, cast: Dictionary) -> void:
	var lb: Dictionary=state.p6_lb; var at := float(cast.finish)
	if cast.kind in ["ranged","melee"]:
		var valid := false
		for npc in lb.targets:
			if npc.id==cast.target and float(npc.hp)>0 and bool(npc.get("targetable",true)):
				cast.position=npc.pos.duplicate(); valid=true
		if not valid:
			emit(state,"lb_interrupted",at,{"actor":cast.actor,"reason":"Target died or became untargetable before completion","cast_id":cast.id}); return
	lb.gauge=0
	emit(state,"lb_finish",at,cast)
	# Damage snapshots at cast completion; delayed HP packets do not retarget.
	var hits: Array=[]
	for npc in lb.targets:
		if float(npc.hp)<=0 or not bool(npc.get("targetable",true)): continue
		if cast.kind=="caster" and Rules.v(npc.pos).distance_to(Rules.v(cast.position))<=15.0: hits.append(npc.id)
		elif cast.kind=="ranged":
			var axis := (Rules.v(cast.position)-Rules.v(cast.origin)).normalized()
			var delta := Rules.v(npc.pos)-Rules.v(cast.origin)
			if axis!=Vector2.ZERO and delta.dot(axis)>=0 and delta.dot(axis)<=30 and absf(delta.cross(axis))<=RANGED_HALF_WIDTH: hits.append(npc.id)
		elif cast.kind=="melee" and npc.id==cast.target: hits.append(npc.id)
	if cast.kind in ["caster","ranged","melee"]:
		lb.effects.append({"kind":"damage","at":at+(5.6 if cast.kind=="caster" else 3.5),"actor":cast.actor,"targets":hits,"amount":273000 if cast.kind=="caster" else (246000 if cast.kind=="ranged" else 450000),"cast_id":cast.id})
	elif cast.kind=="tank":
		# Observed application 1.34..2.28s after action; 8s per recipient.
		lb.effects.append({"kind":"tank_buff","at":at+2.3,"actor":cast.actor})
	elif cast.kind=="healer":
		lb.doom=[] # 3532 removals occur on healer cast packet, before heal packets.
		emit(state,"doom_cleansed",at,{"actor":cast.actor})
	if cast.refund:
		state.spent.append(int(cast.actor))
		lb.effects.append({"kind":"refund","at":at+(6.05 if cast.kind=="healer" else (3.85 if cast.kind=="tank" else 5.05)),"actor":cast.actor,"cast_id":cast.id})
	# Animation duration is an explicit parent calibration, never stationary-log inference.
	var animation := float(lb.animation_seconds.get(cast.job,0.0))
	if animation>0: lb.effects.append({"kind":"unlock","start":at,"at":at+animation,"actor":cast.actor})
	else: emit(state,"lb_unlock",at,{"actor":cast.actor,"animation_verified":false})

static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	if not state.has("p6_lb"): return
	var lb: Dictionary=state.p6_lb; var now := float(state.sim_time); var start := now-dt
	state.dead=state.get("dead",[]).map(func(a):return int(a))
	lb.brilliant=lb.brilliant.filter(func(a):return int(a) not in state.dead)
	for effect in lb.effects:
		if effect.kind=="unlock" and minf(now,float(effect.at))>maxf(start,float(effect.start)):
			var actor := int(effect.actor)
			if Rules.v(previous[actor].pos).distance_to(Rules.v(actors[actor].pos))>0.001:
				state.runtime_failures.append("P6 LB animation lock moved: actor %d" % actor)
	for cast in lb.casts.duplicate():
		var actor := int(cast.actor)
		# Expiry wins ties: a heal finishing at/after six seconds cannot cleanse
		# a Doom which already killed its recipient, even in a single long tick.
		expire_doom(state,minf(now,float(cast.finish)))
		var locked_fraction := clampf((minf(now,float(cast.finish))-start)/maxf(dt,0.000001),0,1)
		if actor in state.get("dead",[]) or Rules.v(previous[actor].pos).distance_to(Rules.v(actors[actor].pos))*locked_fraction>0.001:
			lb.casts.erase(cast); emit(state,"lb_interrupted",minf(now,float(cast.finish)),{"actor":actor,"cast_id":cast.id,"gauge_consumed":false}); continue
		if float(cast.finish)<=now+0.000001:
			lb.casts.erase(cast); finish_cast(state,cast)
	lb.effects.sort_custom(func(a,b):return float(a.at)<float(b.at))
	while not lb.effects.is_empty() and float(lb.effects[0].at)<=now+0.000001:
		var effect: Dictionary=lb.effects.pop_front()
		match effect.kind:
			"refund":
				if int(effect.actor) not in state.dead: lb.gauge=30000
				else: effect.cancelled="Dynamis lost on death"
				lb.brilliant=lb.brilliant.filter(func(a):return int(a)!=int(effect.actor))
			"tank_buff": lb.tank_buffs.append({"start":effect.at,"end":float(effect.at)+8.0,"actor":effect.actor})
			"damage":
				for npc in lb.targets:
					if npc.id in effect.targets and float(npc.hp)>0:
						npc.hp=maxf(0,float(npc.hp)-float(effect.amount))
						if npc.hp==0: emit(state,"npc_killed",float(effect.at),{"target":npc.id,"actor":effect.actor,"cast_id":effect.cast_id})
		emit(state,"lb_"+str(effect.kind),float(effect.at),effect)
	expire_doom(state,now)
	sync(actors,state)

static func expire_doom(state: Dictionary, at: float) -> void:
	for doom in state.p6_lb.doom.duplicate():
		if float(doom.expires)<=at+0.000001:
			state.runtime_failures.append("P6 Magic Number Doom expired")
			for actor in doom.targets:
				if int(actor) not in state.dead: state.dead.append(int(actor))
			state.p6_lb.doom.erase(doom)

static func tank_active(state: Dictionary, at: float) -> bool:
	for buff in state.get("p6_lb",{}).get("tank_buffs",[]):
		if float(buff.start)<=at and at<float(buff.end): return true
	return false

static func spawn_meteors(state: Dictionary) -> void:
	var lb: Dictionary=state.p6_lb
	lb.targets=lb.targets.filter(func(n):return int(n.get("npc_id",0)) not in [15726,15727])
	for i in 6:
		var p := Rules.direction(30.0+i*60)*13.0
		lb.targets.append({"id":"comet_%d" % i,"npc_id":15727,"pos":[p.x,p.y],"hp":228360,"max_hp":228360,"targetable":true})
	for i in 2: lb.targets.append({"id":"meteor_%d" % i,"npc_id":15726,"pos":[0,-10 if i==0 else 10],"hp":482324,"max_hp":482324,"targetable":true})
