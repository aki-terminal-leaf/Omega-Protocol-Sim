# SPDX-License-Identifier: MIT
extends RefCounted
## Live Sigma status/tower outcomes and coaching allocation, never forced gains.
const R=preload("res://scripts/rules.gd")
static func status():return load("res://scripts/statuses.gd")
static var coaching: Dictionary={}
static func paths() -> Dictionary:
	if coaching.is_empty():coaching=JSON.parse_string(FileAccess.get_file_as_string("res://data/sigma_coaching_paths.json"))
	return coaching.routes
static func allocation(c: Dictionary,dynamis: Array) -> Array:
	var near:=int(c.near);var far:=int(c.far)
	var eligible:Array=[]
	for raw in c.priority:
		var actor:=int(raw)
		if actor not in [near,far] and int(dynamis[actor])==1:eligible.append(actor)
	if eligible.size()<3:return []
	var fside:Array=eligible.slice(0,3);var other:Array=[]
	for raw in c.priority:
		var actor:=int(raw)
		if actor not in [near,far] and actor not in fside:other.append(actor)
	if str(c.family)=="cn":
		# Attack1 goes from F to the first far jump; Attack2/3 bait arms.
		other.sort_custom(func(a,b):return int(dynamis[a])>int(dynamis[b]) if int(dynamis[a])!=int(dynamis[b]) else c.priority.find(a)<c.priority.find(b))
		return [near,far,other[1],other[2],fside[0],other[0],fside[1],fside[2]]
	if str(c.family)=="kr":return [near,far,other[1],other[2],other[0],fside[1],fside[0],fside[2]]
	return [near,far,other[0],other[1],fside[1],other[2],fside[0],fside[2]]
static func place(beat: Dictionary,c: Dictionary,roles: Array,point_index: int) -> void:
	var key: String=c.path_key
	var route: Dictionary=paths()[key]
	for slot in 8:
		if roles.size()!=8 or not preload("res://scripts/sigma_preparation.gd").whole(roles[slot],0,7):continue
		var p:=R.v(route.roles[slot][point_index].pos).rotated(deg_to_rad(float(c.f_angle)))
		beat.positions[int(roles[slot])]=p
		beat.labels[int(roles[slot])]=["HELLO NEAR","HELLO DISTANT","NEAR jump1","NEAR jump2","DISTANT jump1","DISTANT jump2","ARM LEFT","ARM RIGHT"][slot]
	for check in beat.get("checks",[]):
		if check.kind=="world_pulse":
			check.near=int(c.near);check.far=int(c.far)
			check.near_path=[roles[0],roles[2],roles[3]];check.far_path=[roles[1],roles[4],roles[5]]
			beat.world=check
static func begin(beat: Dictionary,state: Dictionary) -> void:
	if not beat.has("sigma_config"):return
	var c:Dictionary=beat.sigma_config
	if state.get("sigma",{}).get("id","")!=str(c.id):
		state.sigma={"id":str(c.id),"origin":float(state.get("sim_time",0)),"given":false,"expired":false,"cleansed":[false,false,false,false,false,false,false,false],"roles":[],"history":[]}
		for actor in 8:status().give(state,actor,"remote_glitch" if c.remote else "mid_glitch",32.0)
		status().give(state,int(c.near),"near_world",56.0)
		status().give(state,int(c.far),"distant_world",56.0)
	preload("res://scripts/sigma_cooperation.gd").initialize(c,state)
	if beat.has("sigma_path_index"):
		if preload("res://scripts/sigma_cooperation.gd").active(state):preload("res://scripts/sigma_cooperation.gd").lock(state);preload("res://scripts/sigma_cooperation.gd").sync(beat,state);return
		if state.sigma.roles.is_empty():
			state.sigma.roles=allocation(c,state.dynamis)
			if state.sigma.roles.is_empty():status().advise(state,"guide","Sigma: fewer than three one-stack non-World utility candidates; coaching route unsolved (NPC routing not synthesized)",{"dynamis":state.dynamis.duplicate()});return
			status().event(state,"sigma_coaching_allocation",{"roles":state.sigma.roles.duplicate(),"dynamis":state.dynamis.duplicate(),"tie":"documented eligibility; deterministic community priority for free conga ties"})
		state.sigma.roles=state.sigma.roles.map(func(i):return int(i))
		place(beat,c,state.sigma.roles,int(beat.sigma_path_index))
static func tick(actors: Array,_previous: Array,state: Dictionary,_dt: float) -> void:
	if not state.has("sigma"):return
	var now:=float(state.get("sim_time",0));var origin:=float(state.sigma.origin)
	if not state.sigma.given and now>=origin+16.5:
		state.sigma.given=true
		for actor in actors.size():
			status().give(state,actor,"looper",maxf(0,origin+34.5-now));state.statuses[actor].looper.expires=origin+34.5
		status().event(state,"sigma_looper_gain",{"time":origin+16.5,"expires":origin+34.5})
	if not state.sigma.expired and now>=origin+34.5:
		state.sigma.expired=true
		for actor in actors.size():
			if not bool(state.sigma.cleansed[actor]):
				status().fail(state,"Sigma actor%d: Looper expired -> Memory Loss"%actor)
				if actor not in state.dead:state.dead.append(actor)
static func snapshot(beat: Dictionary,actors: Array,state: Dictionary) -> Array:
	var errors:Array=[]
	if not beat.has("sigma_config"):return errors
	var now:=float(state.get("sim_time",0))
	if beat.get("sigma_towers",false):
		for tower in beat.shapes:
			if tower.get("kind","")!="tower":continue
			var caught:=R.hits(tower,actors)
			if caught.size()!=int(tower.count):continue
			for actor in caught:
				if state.sigma.cleansed[actor] or not state.sigma.given or not state.statuses[actor].has("looper"):errors.append("Sigma Storage Violation Obliteration: no Looper")
				else:state.sigma.cleansed[actor]=true;state.statuses[actor].erase("looper")
				var old:Dictionary=state.statuses[actor].get("twice_come_ruin",{})
				var stacks:=int(old.get("stacks",0))+1 if float(old.get("expires",0))>now else 1
				state.statuses[actor].twice_come_ruin={"expires":now+11.0,"stacks":stacks}
				if stacks>=2:errors.append("Sigma Twice-come Ruin x2 -> Doom")
		status().event(state,"sigma_towers",{"cleansed":state.sigma.cleansed.duplicate()})
	if beat.get("sigma_magic_hits",false):
		for shape in beat.shapes:
			if shape.get("decorative",false):continue
			for actor in R.hits(shape,actors):
				if float(state.statuses[actor].get("world_vulnerability",{}).get("expires",0))>now or float(state.statuses[actor].get("magic_vulnerability",{}).get("expires",0))>now:
					errors.append("Sigma actor%d: repeated magic hit during vulnerability"%actor)
					if actor not in state.dead:state.dead.append(actor)
				status().give(state,actor,"magic_vulnerability",2.0)
	if beat.get("sigma_finish",false):
		var values:Array=state.dynamis.map(func(value):return int(value));values.sort()
		if values!=[1,1,1,1,2,2,2,2]:errors.append("Sigma: actual Dynamis must finish four at1 / four at2")
	return errors
static func sync(beat: Dictionary,state: Dictionary) -> void:
	if not state.has("sigma"):return
	preload("res://scripts/sigma_cooperation.gd").sync(beat,state)
	if not beat.get("sigma_tell",false):
		# Preserve the learned pattern through resolution, then clear stale UI.
		if not beat.get("sigma_towers",false):state.sigma.erase("visible_towers")
		return
	state.sigma.visible_towers=[]
	for shape in beat.get("shapes",[]):
		if shape.get("sigma_tell",false):
			var pos:=R.v(shape.pos)
			state.sigma.visible_towers.append({"pos":[float(pos.x),float(pos.y)],"radius":float(shape.radius),"capacity":int(shape.count),"label":str(shape.capacity_label)})
