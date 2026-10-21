# SPDX-License-Identifier: MIT
extends RefCounted
const R=preload("res://scripts/rules.gd")
static func status():return load("res://scripts/statuses.gd")
static func choose(c:Dictionary,dynamis:Array,second:bool) -> Array:
	var holders:Array=c.second if second else c.first
	var utility:Array=[]
	if second:
		for raw in c.priority:
			var actor:=int(raw)
			if int(dynamis[actor])==3 and actor not in holders:utility.append(actor)
	else:
		for raw in c.second+c.priority:
			var actor:=int(raw)
			if utility.size()<2 and int(dynamis[actor])==2 and actor not in holders and actor not in utility:utility.append(actor)
	if utility.size()!=2:return []
	var receivers:Array=[]
	for raw in c.priority:
		var actor:=int(raw)
		if actor not in holders and actor not in utility:receivers.append(actor)
	return [int(holders[0]),int(holders[1]),receivers[0],receivers[1],receivers[2],receivers[3],utility[0],utility[1]]
static func goals(c:Dictionary,second:bool) -> Array:
	var far_side:=float(c.get("far_side",90))
	var far_sign:=1.0 if far_side==90 else -1.0
	var points:Array=[Vector2(-1,8),Vector2(far_sign*9,0),Vector2(-5,18),Vector2(5,18),Vector2(-far_sign*18,1 if second else 0),Vector2(far_sign*18,1 if second else 0),Vector2(-10,-16 if second else -14),Vector2(10,-16 if second else -14)]
	var rotation:float=c.beetle_angle if second else c.monitor_angle
	for i in points.size():points[i]=points[i].rotated(deg_to_rad(rotation))
	return points
static func place(b:Dictionary,c:Dictionary,roles:Array,second:bool) -> void:
	var points:=goals(c,second)
	for slot in 8:
		var actor:=int(roles[slot]);b.positions[actor]=points[slot]
		b.labels[actor]=["HELLO NEAR","HELLO DISTANT","NEAR jump1","NEAR jump2","DISTANT jump1","DISTANT jump2","BLASTER1" if second else "MONITOR1","BLASTER2" if second else "MONITOR2"][slot]
	for check in b.checks:
		if check.kind=="world_pulse":
			check.near=roles[0];check.far=roles[1];check.near_path=[roles[0],roles[2],roles[3]];check.far_path=[roles[1],roles[4],roles[5]];b.world=check
	if b.has("transfers"):b.transfers.wanted=[roles[6],roles[7]]
static func begin(b:Dictionary,state:Dictionary) -> void:
	if not b.has("omega_config"):return
	var c:Dictionary=b.omega_config
	if state.get("omega",{}).get("id","")!=str(c.id):
		state.omega={"id":str(c.id),"origin":float(state.get("sim_time",0)),"first_roles":[],"second_roles":[],"config":c.duplicate(true),"utility_fixed":false,"until":float(state.get("sim_time",0))+50.1}
		for j in 2:
			for actor in (c.first if j==0 else c.second):
				status().give(state,int(actor),"first_in_line" if j==0 else "second_in_line",1.0e30)
				status().give(state,int(actor),"omega_near_world" if int(actor)==int((c.first if j==0 else c.second)[0]) else "omega_distant_world",29.9 if j==0 else 47.9)
		if not c.get("standalone",true):
			var counts:Array=state.dynamis.map(func(x):return int(x));counts.sort()
			if counts!=[1,1,1,1,2,2,2,2]:status().fail(state,"Omega entry: actual Sigma must leave four at1/four at2")
	if b.has("omega_phase"):
		state.omega.active_phase=b.omega_phase
		var second:bool=b.omega_phase=="second";var key:="second_roles" if second else "first_roles"
		if state.omega[key].is_empty():
			state.omega[key]=choose(c,state.dynamis,second)
			if state.omega[key].is_empty():status().fail(state,"Omega: no valid actual-stack utility allocation");return
			status().event(state,"omega_coaching_allocation",{"phase":b.omega_phase,"roles":state.omega[key].duplicate(),"actual_dynamis":state.dynamis.duplicate()})
		state.omega[key]=state.omega[key].map(func(i):return int(i))
		place(b,c,state.omega[key],second)
static func snapshot(b:Dictionary,actors:Array,state:Dictionary) -> Array:
	var failures:Array=[]
	if b.get("omega_monitor",false):
		var source:Dictionary={"kind":"half","angle":float(b.omega_config.monitor_angle),"radius":100.0}
		var candidates:Array=R.hits(source,actors).filter(func(i):return i not in state.dead)
		var targets:=R.monitor_targets(candidates,source,actors.size(),state)
		var coverage:Array=[];coverage.resize(8);coverage.fill(0)
		for target in targets:
			for actor in R.hits({"actor":int(target),"radius":7.0},actors):
				coverage[actor]+=1
				if float(state.statuses[actor].get("world_vulnerability",{}).get("expires",0))>float(state.sim_time) or float(state.statuses[actor].get("magic_vulnerability",{}).get("expires",0))>float(state.sim_time):
					failures.append("Omega monitor during live vulnerability: actor%d"%actor)
					if actor not in state.dead:state.dead.append(actor)
				var prior:Dictionary=state.statuses[actor].get("omega_ruin",{})
				if float(prior.get("expires",0))>float(state.sim_time):
					failures.append("Omega monitor Twice-come Ruin x2 -> Doom")
					if actor not in state.dead:state.dead.append(actor)
				state.statuses[actor].omega_ruin={"expires":float(state.sim_time)+7.0}
				status().give(state,actor,"magic_vulnerability",5.0)
		if targets.size()!=2:failures.append("Omega monitor requires two actual living targets")
		for count in coverage:
			if int(count)>1:failures.append("Omega monitor radius7 overlap / double hit")
		status().event(state,"omega_monitor_resolution",{"candidates":candidates,"targets":targets,"coverage":coverage})
	if b.get("omega_first_finish",false):
		var counts:Array=state.dynamis.map(func(x):return int(x));counts.sort()
		if counts!=[2,2,2,2,2,2,3,3]:failures.append("Omega first World must actually leave six at2/two at3")
		for actor in b.omega_config.second:
			if int(state.dynamis[int(actor)])!=2:failures.append("Omega second World holder reached3 too early")
	return failures
static func tick(actors:Array,_previous:Array,state:Dictionary,_dt:float) -> void:
	if state.has("omega") and float(state.get("sim_time",0))<=float(state.omega.until)+0.000001:
		for actor in actors.size():
			var budget:float=state.get("motion_allowances",[])[actor] if state.get("motion_allowances",[]).size()==actors.size() else 6.0*_dt
			if R.v(actors[actor].pos).distance_to(R.v(_previous[actor].pos))>budget+0.001:status().fail(state,"Omega unauthorized movement budget: actor%d"%actor)
			if R.v(actors[actor].pos).length()>=20 and actor not in state.dead:state.dead.append(actor);status().fail(state,"Omega death wall: actor%d"%actor)
	if not state.has("omega") or state.omega.get("active_phase","")!="second" or state.omega.utility_fixed:return
	var c:Dictionary=state.omega.config
	if state.get("tether_group","")!=str(c.id)+"_blaster" or state.omega.second_roles.size()!=8:return
	var roles:Array=state.omega.second_roles
	if int(roles[6]) not in state.tether_holders or int(roles[7]) not in state.tether_holders:return
	state.omega.utility_fixed=true
	if c.profile=="cn_moogle":return #explicit Stop1/2 left/right ordering
	var source:=R.direction(float(c.beetle_angle))*20.0
	var points:=goals(c,true)
	var straight:=0.0;var swapped:=0.0
	for j in 2:
		var ray:Vector2=(R.v(actors[int(roles[6+j])].pos)-source).normalized()
		straight+=ray.dot((points[6+j]-source).normalized())
		swapped+=ray.dot((points[7-j]-source).normalized())
	if swapped>straight:
		var first:int=int(roles[6]);roles[6]=roles[7];roles[7]=first
		status().event(state,"omega_free_side_assignment",{"roles":roles.duplicate(),"reason":"documented interchangeable3-stack utility sides; actual acquired rays remain unchanged"})
static func sync(b:Dictionary,state:Dictionary) -> void:
	if b.get("omega_phase","")=="second" and state.get("omega",{}).get("utility_fixed",false) and state.omega.second_roles.size()==8:place(b,b.omega_config,state.omega.second_roles,true)
