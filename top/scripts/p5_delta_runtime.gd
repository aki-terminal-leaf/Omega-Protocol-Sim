# SPDX-License-Identifier: MIT
extends RefCounted
## Opt-in continuous Delta judge. Never reads guide positions or wanted owners.
const R = preload("res://scripts/rules.gd")
const P = preload("res://scripts/p5_delta_patterns.gd")

static func status(): return load("res://scripts/statuses.gd")
static func fail(state: Dictionary, reason: String, victims: Array = []) -> void:
	state.runtime_failures.append("Delta: "+reason)
	for actor in victims:
		if int(actor) not in state.dead: state.dead.append(int(actor))

static func record(state: Dictionary, item: Dictionary) -> void:
	state.delta.history.append(item.duplicate(true))
	state.timeline.append({"kind":"delta_"+str(item.kind),"time":item.at,"details":item.duplicate(true)})

static func grant(state: Dictionary, actor: int, name: String, duration: float, sid := 0) -> void:
	status().give(state,actor,name,duration)
	state.statuses[actor][name].status_id=sid

static func begin(beat: Dictionary, state: Dictionary) -> void:
	if not beat.has("delta_config"): return
	var c: Dictionary=beat.delta_config.duplicate(true)
	if state.has("delta") and str(state.delta.id)==str(c.id): return
	if not P.valid_assignment(c.assignment):
		fail(state,"Invalid initial World/tether assignment")
		return
	var now:=float(state.get("sim_time",0))
	state.delta={"id":c.id,"start":now,"config":c,"pending":[],"history":[],"entities":P.entities(c),"fists":[],"arms":[],"tethers":[],"ended":false,"last_time":now}
	if not state.has("dynamis"): state.dynamis=[0,0,0,0,0,0,0,0]
	for raw in beat.get("delta_events",P.events(c)):
		var e: Dictionary=raw.duplicate(true); e.at=now+float(e.at); state.delta.pending.append(e)
	P.sorted(state.delta.pending)
	for pair in c.assignment.pairs:
		var tether: Dictionary=pair.duplicate(true)
		tether.broken=false; tether.active_at=now+17.976; tether.expires=tether.active_at+(36 if tether.kind=="local" else 12)
		state.delta.tethers.append(tether)
		for a in [pair.a,pair.b]: grant(state,int(a),"delta_local_smell" if pair.kind=="local" else "delta_remote_smell",18.0,3440 if pair.kind=="local" else 3504)
	grant(state,int(c.assignment.near),"delta_near_world",44.0,3442)
	grant(state,int(c.assignment.far),"delta_distant_world",44.0,3443)

static func living(actors: Array, state: Dictionary, origin: Vector2) -> Array:
	var ids: Array=range(actors.size()).filter(func(a):return a not in state.dead)
	ids.sort_custom(func(a,b):
		var da:=R.v(actors[a].pos).distance_squared_to(origin); var db:=R.v(actors[b].pos).distance_squared_to(origin)
		return a<b if is_equal_approx(da,db) else da<db)
	return ids

static func sample(actors: Array, previous: Array, f: float) -> Array:
	var result:=actors.duplicate(true)
	for a in actors.size():
		result[a].pos=R.v(previous[a].pos).lerp(R.v(actors[a].pos),f)
		result[a].face=float(previous[a].get("face",0))+wrapf(float(actors[a].get("face",0))-float(previous[a].get("face",0)),-180,180)*f
	return result

static func tick(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	if not state.has("delta") or dt<=0 or bool(state.delta.ended): return
	state.dead=state.dead.map(func(a):return int(a))
	if state.has("defense_victims"): state.defense_victims=state.defense_victims.map(func(a):return int(a))
	var finish:=float(state.sim_time); var start:=finish-dt
	if absf(float(state.delta.last_time)-start)>0.001:
		fail(state,"Discontinuous clock; restore a complete checkpoint before retry")
		return
	for a in actors.size():
		var allowance:=6.0*dt
		if state.get("motion_allowances",[]).size()==actors.size(): allowance=float(state.motion_allowances[a])
		if R.v(previous[a].pos).distance_to(R.v(actors[a].pos))>allowance+0.001: fail(state,"Movement exceeds authorized walking/Sprint/dash budget",[a])
	var cursor:=start
	while cursor<finish-0.0000001:
		var next:=minf(finish,cursor+float(state.delta.config.parameters.contact_step))
		if not state.delta.pending.is_empty(): next=minf(next,maxf(cursor,float(state.delta.pending[0].at)))
		var observed:=sample(actors,previous,clampf((next-start)/dt,0,1))
		state.sim_time=next
		for actor in observed.size():
			if actor not in state.dead and R.v(observed[actor].pos).length()>=20.0: fail(state,"Death wall",[actor])
		advance_fists(observed,state,next-cursor)
		# Continuous distance tests are evaluated before TTL at the same instant.
		patches(observed,state)
		while not state.delta.pending.is_empty() and float(state.delta.pending[0].at)<=next+0.0000001:
			var e: Dictionary=state.delta.pending.pop_front()
			if float(e.at)<start-0.001: fail(state,"Missed event; cannot reconstruct historical bait")
			else: resolve(e,observed,state)
		cursor=next
	state.delta.last_time=finish
	state.sim_time=finish

static func advance_fists(actors: Array, state: Dictionary, dt: float) -> void:
	for fist in state.delta.fists:
		if fist.stance!="CHASE": continue
		var before:=R.v(fist.pos); var target:=R.v(actors[int(fist.owner)].pos)
		var after:=before.move_toward(target,float(state.delta.config.parameters.fist_chase_speed)*dt)
		fist.pos=P.xy(after)
		if after.distance_to(before)>0.00001: fist.facing=rad_to_deg((after-before).angle())+90

static func active(state: Dictionary, actor: int, name: String) -> bool:
	return float(state.statuses[actor].get(name,{}).get("expires",-1))>float(state.sim_time)+0.000001

static func magic(state: Dictionary, victims: Array, cause: String, duration: float) -> void:
	for value in victims:
		var actor:=int(value)
		if active(state,actor,"magic_vulnerability") or active(state,actor,"world_vulnerability"):
			fail(state,cause+" during vulnerability",[actor])
		grant(state,actor,"magic_vulnerability",duration,3516)

static func twice_ruin(state: Dictionary, victims: Array, cause: String) -> void:
	for value in victims:
		var actor:=int(value)
		if active(state,actor,"delta_twice_ruin"): fail(state,cause+" during Twice-come Ruin",[actor])
		# This status is distinct from Patch's Thrice-come Ruin and expires
		# seven seconds after Defense / monitor / Pile Pitch in the captures.
		state.statuses[actor].delta_twice_ruin={"expires":float(state.sim_time)+float(state.delta.config.parameters.twice_ruin),"status_id":2534}

static func patches(actors: Array, state: Dictionary) -> void:
	var now:=float(state.sim_time); var params: Dictionary=state.delta.config.parameters
	for tether in state.delta.tethers:
		if tether.broken or now<float(tether.active_at)-0.000001: continue
		var a:=int(tether.a); var b:=int(tether.b)
		var distance:=R.v(actors[a].pos).distance_to(R.v(actors[b].pos))
		var breaks: bool=distance<=float(params.local_distance) if tether.kind=="local" else distance>=float(params.remote_distance)
		if breaks:
			tether.broken=true; tether.broken_at=now
			for actor in [a,b]: state.statuses[actor].erase("delta_"+str(tether.kind))
			var victims:=range(actors.size()).filter(func(actor):return actor not in state.dead)
			for actor in victims:
				var stacks:=int(state.statuses[actor].get("thrice_come_ruin",{}).get("stacks",0)) if active(state,actor,"thrice_come_ruin") else 0
				state.statuses[actor].thrice_come_ruin={"expires":now+float(params.patch_ruin),"stacks":stacks+1,"status_id":2530}
				if stacks+1>=3: fail(state,"Thrice-come Ruin",[actor])
			magic(state,victims,"Patch",float(params.patch_magic))
			record(state,{"at":now,"kind":"patch","pair":tether.id,"distance":distance,"hits":victims})
		elif now>=float(tether.expires)-0.000001:
			tether.broken=true; tether.expired=true
			fail(state,"Live "+str(tether.kind)+" tether expired",range(actors.size()))

static func resolve(e: Dictionary, actors: Array, state: Dictionary) -> void:
	var c: Dictionary=state.delta.config; var rec:=e.duplicate(true)
	match str(e.kind):
		"monitor_loading":
			grant(state,int(c.monitor),"delta_monitor",10.147,3452 if int(c.monitor_hand)==1 else 3453)
		"tethers_live":
			for pair in state.delta.tethers:
				for a in [pair.a,pair.b]:
					state.statuses[int(a)].erase("delta_"+str(pair.kind)+"_smell")
					if not pair.broken: grant(state,int(a),"delta_"+str(pair.kind),36.0 if pair.kind=="local" else 12.0,int(pair.status_id))
		"fists_spawn":
			for slot in 8:
				var owner:=int(c.assignment.order[slot])
				var fist: Dictionary={"id":"delta_fist_%d"%slot,"form":"fist_b5" if int(c.colours[slot])==0 else "fist_b6","colour":int(c.colours[slot]),"owner":owner,"pos":P.xy(R.v(actors[owner].pos)),"facing":0.0,"stance":"CHASE","spawn_delay":7.244,"asset_status":"optional model; NPC chase speed unmeasured"}
				state.delta.fists.append(fist)
		"fists_lock":
			rec.baits=[]
			for fist in state.delta.fists:
				# The cast location is captured at cast start; entity chase position
				# remains separate and never becomes a future endpoint puddle.
				fist.lock_pos=P.xy(R.v(actors[int(fist.owner)].pos)); fist.lock_at=e.at; fist.stance="CAST"
				rec.baits.append({"id":fist.id,"pos":fist.lock_pos,"entity_pos":fist.pos,"owner":fist.owner,"colour":fist.colour})
			for fist in state.delta.fists:
				var nearby: Array=state.delta.fists.filter(func(other):return other.id!=fist.id and R.v(other.lock_pos).distance_to(R.v(fist.lock_pos))<=float(c.parameters.fist_overlap_distance))
				fist.valid_pair=nearby.size()==1 and int(nearby[0].colour)!=int(fist.colour)
		"fists_resolve":
			rec.hits=[]
			for fist in state.delta.fists:
				if not fist.get("valid_pair",false): fail(state,"Unmitigated Explosion 31483: incorrect fist overlap",R.hits({"pos":fist.get("lock_pos",fist.pos),"radius":100.0},actors))
				var caught:=R.hits({"pos":fist.get("lock_pos",fist.pos),"radius":3.0},actors)
				rec.hits.append({"id":fist.id,"hits":caught})
				if not caught.is_empty(): fail(state,"Explosion 31482 at old fist bait",caught)
				fist.stance="RESOLVED"
		"arms_spawn":
			for index in 6:
				state.delta.arms.append({"id":"delta_arm_%d"%index,"form":c.get("arm_forms",["arm_left","arm_left","arm_left","arm_right","arm_right","arm_right"])[index],"pos":P.xy(R.direction(float(c.eye)-index*60)*20),"facing":0.0,"turn":c.arm_turns[index],"stance":"BAIT","spawn_delay":10.241,"asset_status":"optional model"})
		"arms_lock":
			rec.locks=[]
			for arm in state.delta.arms:
				var pool:=living(actors,state,R.v(arm.pos))
				if pool.is_empty(): continue
				arm.target=int(pool[0]); arm.lock_at=e.at; arm.stance="CAST"
				arm.angle=rad_to_deg((R.v(actors[int(arm.target)].pos)-R.v(arm.pos)).angle())+90
				arm.facing=arm.angle
				rec.locks.append({"id":arm.id,"target":arm.target,"angle":arm.angle,"pos":arm.pos})
		"arms_fire":
			rec.hits=[]
			rec.positions=actors.map(func(a):return P.xy(R.v(a.pos)))
			for arm in state.delta.arms:
				if not arm.has("angle"): fail(state,"Arm fired without cast-start lock"); continue
				arm.facing=float(arm.angle)+int(e.pulse)*float(arm.turn); arm.stance="FIRE" if int(e.pulse)<5 else "RESOLVED"
				var shape: Dictionary={"kind":"line","pos":arm.pos,"angle":arm.facing,"width":8.0,"length":100.0}
				var caught:=R.hits(shape,actors); rec.hits.append({"id":arm.id,"hits":caught,"angle":arm.facing})
				if not caught.is_empty(): fail(state,"Hyper Pulse %d"%int(e.pulse),caught)
		"defense":
			var pool:=living(actors,state,Vector2.ZERO)
			if pool.size()<2: fail(state,"Beyond Defense needs living targets")
			else:
				var target:=int(pool[int(c.defense_choice)%2]); rec.closest_two=pool.slice(0,2); rec.target=target
				var caught:=R.hits({"actor":target,"radius":5.0},actors)
				state.defense_victims=caught.duplicate(); state.delta.defense_target=target; rec.hits=caught
				if caught.size()!=1: fail(state,"Beyond Defense radius-5 clip",caught)
				twice_ruin(state,caught,"Beyond Defense")
		"pile_pitch":
			var pool:=living(actors,state,Vector2.ZERO)
			if pool.is_empty(): fail(state,"Pile Pitch has no living target")
			else:
				var caught:=R.hits({"actor":int(pool[0]),"radius":6.0},actors)
				rec.target=int(pool[0]); rec.hits=caught; rec.excluded=state.get("defense_victims",[]).duplicate()
				if caught.size()<3: fail(state,"Pile Pitch needs at least three",caught)
				for actor in caught:
					if actor in rec.excluded: fail(state,"Beyond Defense victim in Pile Pitch",[actor])
				twice_ruin(state,caught,"Pile Pitch")
		"monitors":
			rec.sources=[]; rec.coverage=[0,0,0,0,0,0,0,0]
			var m:=int(c.monitor); var side:=int(c.monitor_side)
			var sources: Array=[{"kind":"half","pos":c.final,"angle":float(c.eye)+(0 if side==1 else 180),"radius":100.0},{"kind":"half","actor":m,"face_actor":m,"offset":90.0*int(c.monitor_hand),"radius":100.0,"exclude":[m]}]
			for source in sources:
				var candidates:=R.hits(source,actors).filter(func(a):return a not in state.dead)
				var targets:=R.monitor_targets(candidates,source,actors.size(),state)
				var observed: Dictionary={"candidates":candidates,"targets":targets,"source":source}
				if targets.size()!=2: fail(state,"Monitor missing living targets")
				for target in targets:
					for actor in R.hits({"actor":int(target),"radius":7.0},actors):
						if actor not in state.dead: rec.coverage[actor]+=1
				rec.sources.append(observed)
			for actor in actors.size():
				if int(rec.coverage[actor])>1: fail(state,"Monitor double-hit / radius-7 splash",[actor])
				if int(rec.coverage[actor])>0:
					twice_ruin(state,[actor],"Monitor")
					magic(state,[actor],"Monitor",float(c.parameters.monitor_magic))
					state.statuses[actor].magic_vulnerability.status_id=2941
			state.statuses[m].erase("delta_monitor")
		"swivel_cast":
			state.delta.swivel_active=true
			state.delta.entities[0].facing=c.swivel.angle
			state.delta.entities[0].stance="SWIVEL_GLOW"
		"hazard":
			var caught:=R.hits(e.shape,actors); rec.hits=caught
			if not caught.is_empty(): fail(state,str(e.shape.name),caught)
			if e.shape.name=="Swivel Cannon": state.delta.swivel_active=false
		"world":
			var errors: Array=[]
			# Normalize restored numeric actor IDs for the parent chain API.
			for chain in state.get("world_chains",{}).values(): chain.holders=chain.holders.map(func(a):return int(a))
			var previous_count: int=state.get("world_chains",{}).get(str(state.delta.id),{}).get("history",[]).size()
			R.resolve_world_pulse({"chain_id":str(state.delta.id),"pulse":int(e.pulse),"near":int(c.assignment.near),"far":int(c.assignment.far),"holder_radius":8.0,"jump_radius":4.0},actors,state,errors)
			for pulse in state.get("world_chains",{}).get(str(state.delta.id),{}).get("history",[]).slice(previous_count):
				for actor in pulse.hits:
					if active(state,int(actor),"magic_vulnerability"): fail(state,"World during Magic Vulnerability",[int(actor)])
			for error in errors: fail(state,str(error))
		"finish":
			patches(actors,state)
			state.delta.ended=true
		_:
			fail(state,"Unknown event "+str(e.kind))
	record(state,rec)

static func sync(beat: Dictionary, state: Dictionary) -> void:
	if not state.has("delta") or state.delta.ended: return
	load("res://scripts/p5_delta_courses.gd").guide(beat,state)
	if not beat.has("shapes"): beat.shapes=[]
	beat.shapes=beat.shapes.filter(func(s):return not s.get("delta_preview",false))
	beat.stage_entities=state.delta.entities.duplicate(true)+state.delta.fists.duplicate(true)+state.delta.arms.duplicate(true)
	for entity in beat.stage_entities:
		entity.pos=R.v(entity.pos)
		# The queue already controls actual spawns. Arena's spawn_delay is
		# beat-relative, so do not hide existing entities at each new beat.
		entity.spawn_at=float(state.delta.start)+float(entity.spawn_delay)
		entity.spawn_delay=0.0
	beat.tethers=[]
	for tether in state.delta.tethers:
		if not tether.broken: beat.tethers.append({"a":int(tether.a),"b":int(tether.b),"delta":true,"kind":tether.kind})
	for fist in state.delta.fists:
		if fist.stance=="CAST": beat.shapes.append({"kind":"circle","pos":R.v(fist.lock_pos),"radius":3.0,"name":"Locked fist puddle","decorative":true,"delta_preview":true})
	if state.delta.get("swivel_active",false):
		var shape: Dictionary=state.delta.config.swivel.duplicate(true)
		shape.pos=R.v(shape.pos); shape.decorative=true; shape.delta_preview=true; beat.shapes.append(shape)
