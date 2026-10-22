# SPDX-License-Identifier: MIT
extends RefCounted
## Judges only observed positions and actual contact ownership, after contacts.
const R=preload("res://scripts/rules.gd")
const P=preload("res://scripts/p2_limitless_patterns.gd")
static func status():return load("res://scripts/statuses.gd")
static func fail(state:Dictionary,reason:String,victims:Array=[])->void:
	status().fail(state,"Limitless: "+reason)
	for actor in victims:
		if int(actor) not in state.dead:state.dead.append(int(actor))
static func begin(beat:Dictionary,state:Dictionary)->void:
	if not beat.has("limitless_config"):return
	var now:=float(state.get("sim_time",0))
	state.limitless={"start":now,"until":now+38.2,"config":beat.limitless_config.duplicate(true),"pending":beat.limitless_events.duplicate(true),"history":[],"arrow":{},"defense_victim":-1,"shield_current":beat.limitless_config.shield_source.duplicate(),"followup_at":-1.0,"victim_origin":[],"flare_marked":false}
	for event in state.limitless.pending:event.at=float(event.at)+now
static func record(state:Dictionary,event:Dictionary)->void:
	state.limitless.history.append(event.duplicate(true))
	state.timeline.append({"kind":"limitless_"+str(event.kind),"time":event.at,"details":event.duplicate(true)})
static func closest(actors:Array,state:Dictionary,origin:Vector2)->Array:
	var result:Array=range(actors.size()).filter(func(i):return i not in state.dead)
	result.sort_custom(func(a,b):
		var x:=R.v(actors[a].pos).distance_squared_to(origin);var y:=R.v(actors[b].pos).distance_squared_to(origin)
		return a<b if is_equal_approx(x,y) else x<y)
	return result
static func ruin(state:Dictionary,victims:Array)->void:
	for raw in victims:
		var actor:=int(raw)
		if float(state.statuses[actor].get("limitless_ruin",{}).get("expires",0))>float(state.sim_time):fail(state,"Twice-come Ruin -> Doom",[actor])
		status().give(state,actor,"limitless_ruin",7.0)
static func tick(actors:Array,previous:Array,state:Dictionary,dt:float)->void:
	if not state.has("limitless") or dt<=0:return
	var finish:=float(state.sim_time);var start:=finish-dt
	if start>float(state.limitless.until):return
	state.dead=state.dead.map(func(i):return int(i))
	for actor in actors.size():
		var budget:=6.0*dt
		if state.get("motion_allowances",[]).size()==actors.size():budget=float(state.motion_allowances[actor])
		if R.v(actors[actor].pos).distance_to(R.v(previous[actor].pos))>budget+0.001:fail(state,"movement exceeds authorized budget",[actor])
		if R.v(actors[actor].pos).length()>=20.0:fail(state,"death wall",[actor])
	while not state.limitless.pending.is_empty() and float(state.limitless.pending[0].at)<=finish+0.000001:
		var event:Dictionary=state.limitless.pending.pop_front()
		if float(event.at)<start-0.00001:fail(state,"missing historical event");continue
		var observed:Array=actors.duplicate(true)
		for actor in actors.size():observed[actor].pos=R.v(previous[actor].pos).lerp(R.v(actors[actor].pos),clampf((float(event.at)-start)/dt,0,1))
		state.sim_time=float(event.at);resolve(event,observed,state)
	state.sim_time=finish
static func resolve(event:Dictionary,actors:Array,state:Dictionary)->void:
	var c:Dictionary=state.limitless.config;var item:=event.duplicate(true)
	item.observed_positions=actors.map(func(a):return P.xy(R.v(a.pos)))
	match str(event.kind):
		"arrow_lock":
			var target:=int(c.arrow_target)
			state.limitless.arrow=P.arrow(R.v(c.arrow_source),R.v(actors[target].pos))
			item.target=target;item.locked_position=P.xy(R.v(actors[target].pos));item.shape=state.limitless.arrow.duplicate(true)
		"arrow":
			item.hits=R.hits(state.limitless.arrow,actors)
			if not item.hits.is_empty():fail(state,"locked Sagittarius Arrow hit "+str(item.hits),item.hits)
		"bladedance":
			item.holders=state.get("tether_holders",[]).map(func(i):return int(i));item.hits=[]
			if item.holders.size()!=2:fail(state,"missing actual live tethers")
			for k in item.holders.size():
				var holder:=int(item.holders[k]);var caught:=R.hits(P.cone(R.v(c.sources[k]),holder),actors);item.hits.append(caught)
				for actor in caught:status().give(state,actor,"physical_vulnerability",2.0)
				if holder>=2:fail(state,"actual tether holder is not a tank",[holder])
				for actor in caught:
					if actor>=2:fail(state,"Bladedance clipped non-tank",[actor])
		"flare_markers":
			state.limitless.flare_marked=true;item.targets=c.flare_targets.duplicate()
			for actor in c.flare_targets:status().give(state,int(actor),"prey",8.0)
		"defense":
			var ranked:=closest(actors,state,R.v(c.shield_source))
			if ranked.size()<2:fail(state,"insufficient living Defense candidates")
			else:
				var target:=int(ranked[int(c.defense_rank)]);var caught:=R.hits({"actor":target,"radius":5.0},actors)
				item.target=target;item.closest_two=ranked.slice(0,2);item.hits=caught
				state.limitless.defense_victim=target;state.limitless.followup_at=float(event.at);state.limitless.victim_origin=P.xy(R.v(actors[target].pos))
				state.limitless.shield_current=P.xy(P.jump_source(R.v(c.shield_source),R.v(actors[target].pos)))
				item.jumped_source=state.limitless.shield_current.duplicate()
				if caught!=[target]:fail(state,"Beyond Defense collateral/knockback",caught.filter(func(a):return a!=target))
				ruin(state,caught)
		"flares":
			item.origins=[];item.distances=[];item.hits=[]
			for target in c.flare_targets:
				var origin:=R.v(actors[int(target)].pos);item.origins.append(P.xy(origin))
				item.distances.append(actors.map(func(a):return origin.distance_to(R.v(a.pos))))
				item.hits.append(R.hits({"pos":P.xy(origin),"radius":100.0},actors))
			item.damage_model="Falloff distances and actual100y coverage recorded; HP/shield/mitigation survival unmodeled, not a fake11y avoid circle"
		"pitch":
			var origin:=R.v(state.limitless.shield_current);var ranked:=closest(actors,state,origin)
			if ranked.size()<2:fail(state,"insufficient living Pitch candidates")
			else:
				var target:=int(ranked[0 if c.pitch_policy=="closest_reference" else int(c.pitch_rank)]);var caught:=R.hits({"actor":target,"radius":6.0},actors)
				item.target=target;item.closest_two=ranked.slice(0,2);item.source=P.xy(origin);item.hits=caught;item.selection_policy=c.pitch_policy
				if caught.size()<3:fail(state,"Pile Pitch requires at least three actual recipients",caught)
				ruin(state,caught)
		"raidwide":item.hits=range(actors.size());item.damage_model="untargetable Optical Unit; HP/mitigation unmodeled"
		_:fail(state,"unknown event "+str(event.kind))
	record(state,item)
static func sync(beat:Dictionary,state:Dictionary)->void:
	if not state.has("limitless") or not beat.has("limitless_route"):return
	var c:Dictionary=state.limitless.config;var now:=float(state.get("sim_time",0));var phase:=str(beat.limitless_route.phase)
	if phase=="tethers":
		var assignment:=P.tank_sources(c.sources,str(c.route.tank_order))
		if not state.limitless.has("coaching_tanks"):state.limitless.coaching_tanks=c.sources.map(func(source):return P.xy(P.tank_goal(R.v(source),0,c.route,state.limitless.arrow)))
		for role in 2:
			var actual:int=state.get("tether_holders",[]).find(role)
			var source:=R.v(c.sources[actual if actual>=0 else int(assignment[role])])
			beat.positions[role]=R.v(state.limitless.coaching_tanks[actual if actual>=0 else int(assignment[role])])
		if not state.limitless.arrow.is_empty():
			if not state.limitless.has("coaching_party"):state.limitless.coaching_party=P.xy(P.party_goal(c,state.limitless.arrow))
			var goal:=R.v(state.limitless.coaching_party)
			for actor in range(2,8):beat.positions[actor]=goal
	if phase=="followup":
		var victim:=int(state.limitless.defense_victim)
		for actor in 8:beat.positions[actor]=Vector2.ZERO
		if victim>=0:
			var first:=R.v(state.limitless.victim_origin);var source:=R.v(c.shield_source);var axis:=source.normalized()
			var side:=1.0 if first.dot(axis.orthogonal())>=0 else -1.0
			var target_angle:=axis.angle()+side*deg_to_rad(110.0)
			var delta:=angle_difference(first.angle(),target_angle)
			var elapsed:=maxf(0,now-float(state.limitless.followup_at))
			var target_time:float=(floorf((elapsed+0.000001)*10.0)+1.0)*0.1
			beat.positions[victim]=Vector2.from_angle(first.angle()+signf(delta)*minf(absf(delta),6.0*target_time/maxf(first.length(),1.0)))*first.length()
	beat.shapes=beat.get("shapes",[]).filter(func(s):return not s.get("limitless_preview",false))
	if not state.limitless.arrow.is_empty() and now<float(state.limitless.start)+13.45:
		var shape:Dictionary=state.limitless.arrow.duplicate(true);shape.decorative=true;shape.limitless_preview=true;shape.damage_at=float(state.limitless.start)+13.45;beat.shapes.append(shape)
	if state.limitless.flare_marked and now<float(state.limitless.start)+27.45:
		for target in c.flare_targets:beat.shapes.append({"kind":"circle","actor":int(target),"radius":0.5,"cue_type":"marker","name":"Optimized Meteor","decorative":true,"limitless_preview":true})
	beat.stage_entities=[{"id":"limitless_main_m","form":"male","pos":Vector2.ZERO,"facing":180.0,"stance":"SHIELD"},{"id":"limitless_main_f","form":"female","pos":Vector2(0,-22),"facing":180.0,"stance":"STAFF"}]
	beat.stage_entities.append({"id":"limitless_optical","form":"optical_unit","pos":Vector2(0,-45),"facing":180.0,"height":4.0,"label":""})
	if now>=float(state.limitless.start)+5.3 and now<float(state.limitless.start)+13.6:
		for k in 2:beat.stage_entities.append({"id":"limitless_tether_"+str(k),"form":"male" if k==0 else "female","pos":R.v(c.sources[k]),"facing":0.0,"stance":"SWORD"})
		beat.stage_entities.append({"id":"limitless_arrow","form":"male","pos":R.v(c.arrow_source),"facing":float(state.limitless.arrow.get("angle",rad_to_deg((R.v(c.route.bait)-R.v(c.arrow_source)).angle())+90.0)),"stance":"SWORD"})
	if now>=float(state.limitless.start)+5.3:
		beat.stage_entities.append({"id":"limitless_shield","form":"male","pos":R.v(state.limitless.shield_current),"facing":0.0,"stance":"SHIELD"})
		beat.stage_entities.append({"id":"limitless_flare","form":"female","pos":R.v(c.flare_source),"facing":0.0,"stance":"STAFF"})
