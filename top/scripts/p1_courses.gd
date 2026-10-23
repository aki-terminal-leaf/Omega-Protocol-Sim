# SPDX-License-Identifier: MIT
extends RefCounted
const P = preload("res://scripts/p1_patterns.gd")
const Rules = preload("res://scripts/rules.gd")
const ROLES = ["MT","ST","H1","H2","D1","D2","D3","D4"]

static func repeated(p: Vector2) -> Array:
	var result: Array=[]
	for _i in 8: result.append(p)
	return result
static func route(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/p1_routes.json"))[id]
static func pair(ctx, values: Array) -> Array:
	var id:=str(ctx.profile.id)
	var result:=values.duplicate()
	if id in ["aether","lpdu"]:
		var g1: Array=[0,2,4,6]
		if (int(result[0]) in g1)!=(int(result[1]) in g1):
			return result if int(result[0]) in g1 else [result[1],result[0]]
		var priority: Array=[2,6,4,0,3,7,5,1]
		result.sort_custom(func(a,b):return priority.find(int(a))<priority.find(int(b)))
		return result if int(result[0]) in g1 else [result[1],result[0]]
	var priority: Array=[2,0,1,4,5,6,7,3]
	result.sort_custom(func(a,b):return priority.find(int(a))<priority.find(int(b)))
	return result
static func append(ctx, title: String, events: Array, times: Array, goals: Array, metadata: Dictionary) -> void:
	var previous:=0.0
	for i in times.size():
		ctx.positions=goals[i].duplicate()
		var b: Dictionary=ctx.beat(title,float(times[i])-previous,"Numerical guide realization; actual movement and snapshots decide outcomes.")
		b.p1_route=metadata.duplicate(true)
		if i==0: b.p1_events=events.duplicate(true); b.p1_duration=float(times[-1])
		previous=float(times[i])

static func panto_point(t: float, number: int, base: float, direction: int, outer_out := false) -> Vector2:
	# Staggered lane change: remain for one bait after the prior beam, then
	# inner/front/back-out. The reverse CN variant uses the outer outbound lane.
	var theta:=base+direction*15.0*(maxf(t,6.1)-6.1)
	var shot:=12.1+6.0*(number-1)
	var knots: Array=[[-4.4,0.0,10.0],[-2.4,65.0,3.0],[-0.4,96.0,10.0],[0.0,96.0,10.0],[1.6,45.0,16.0],[3.6,0.0,10.0]]
	if outer_out: knots=[[-4.4,0.0,10.0],[-2.4,-45.0,16.0],[-0.4,-90.0,10.0],[0.0,-90.0,10.0],[1.6,-27.0,4.0],[3.3,0.0,10.0]]
	var relative:=t-shot; var offset:=0.0; var radius:=10.0
	for i in range(knots.size()-1):
		if relative>=float(knots[i][0]) and relative<=float(knots[i+1][0]):
			var f: float=(relative-float(knots[i][0]))/(float(knots[i+1][0])-float(knots[i][0]))
			offset=lerpf(float(knots[i][1]),float(knots[i+1][1]),f)
			radius=lerpf(float(knots[i][2]),float(knots[i+1][2]),f)
	return Rules.direction(theta+direction*offset)*radius

static func append_panto(ctx) -> void:
	var orientation:=int(ctx.profile.get("p1_orientation",ctx.rng.randi_range(0,5)))
	var direction:=int(ctx.profile.get("p1_direction",1 if ctx.rng.randi_range(0,1) else -1))
	var facing:=float(ctx.profile.get("p1_boss_facing",0))
	var id:=str(ctx.profile.id); var meta:=route(id)
	var outer:=str(ctx.profile.get("p1_panto_variant",meta.panto_variant))=="outer_out_inner_return"
	var preferred: float=315.0 if id=="elemental" else (180.0 if id=="aether" else 0.0)
	var flame:=facing+orientation*30
	# Preferred axes select a safe SECTOR, not a mandatory standing point.
	var center:=safe_sector(id,flame,preferred)
	var base:=center-direction*(-40.0 if outer else 45.0)
	var group: Array=repeated(Vector2.ZERO); var numbers: Array=[]; numbers.resize(8)
	for n in 4:
		var pairing:=pair(ctx,ctx.order.slice(n*2,n*2+2))
		for g in 2: group[int(pairing[g])]=g; numbers[int(pairing[g])]=n+1; ctx.labels[int(pairing[g])]="Missile %d / beam %d / G%d" % [n+1,[3,4,1,2][n],g+1]
	var times: Array=[12.1,18.1,24.1,32.3]; var goals: Array=[]
	for t in times:
		var points: Array=[]
		for actor in 8: points.append(panto_point(float(t),int(numbers[actor]),base+int(group[actor])*180,direction,outer))
		goals.append(points)
	meta.orientation=orientation; meta.direction=direction; meta.boss_facing=facing
	meta.panto_variant="outer_out_inner_return" if outer else "inner_out_outer_return"
	meta.rotation_evidence="both signs observed in four-clear helper facings (screen radians/100, then +90 degrees); also explicit in KR row 100"
	meta.orientation_evidence="six 30-degree initial families from community diagrams; four clears do not exhaust all six"
	var start: int=ctx.beats.size()
	append(ctx,"Pantokrator",P.panto(ctx.order,orientation,direction,facing),times,goals,meta)
	for i in range(start,ctx.beats.size()):
		ctx.beats[i].p1_path={"numbers":numbers.duplicate(),"groups":group.duplicate(),"base":base,"direction":direction,"outer":outer}
		# Public scenario selection is separate from the solved demo/checkpoint path.
		ctx.beats[i].panto_public={"profile_id":id,"variant":meta.panto_variant}
		ctx.beats[i].title="Pantokrator · missile %d/4"%(i-start+1)
	# Public training fixture: never spawn on the future missile checkpoint.
	ctx.beats[start].spawn=[]
	for actor in 8: ctx.beats[start].spawn.append(Vector2(-3.5+actor,6.0))
	ctx.beats[start].status_grants=[]
	for actor in 8:
		var number:=int(numbers[actor])
		ctx.beats[start].status_grants.append({"actor":actor,"name":["first_in_line","second_in_line","third_in_line","fourth_in_line"][number-1],"duration":1.0e30})
		ctx.beats[start].status_grants.append({"actor":actor,"name":"guided_missile_kyrios","duration":12.0+6*(number-1),"status_id":[3424,3495,3496,3497][number-1]})
		ctx.beats[start].status_grants.append({"actor":actor,"name":"condensed_wave_cannon_kyrios","duration":12.0+6*([3,4,1,2].find(number)),"status_id":[3507,3508,3509,3510][[3,4,1,2].find(number)]})

static func safe_sector(id: String, flame: float, preferred: float) -> float:
	var target:=preferred
	var separation:=absf(wrapf(preferred-flame,-90,90))
	if separation<29.99:
		# LPDU/Aether/Elemental explicitly turn CW on full coverage. CN/KR
		# show the high/H1 group WEST for a fully covered north marker.
		target+=-90.0 if id in ["cn_moogle","kr_09stop"] else 90.0
	var first:=flame+90.0;var second:=flame+270.0
	return first if Rules.direction(first).dot(Rules.direction(target))>Rules.direction(second).dot(Rules.direction(target)) else second

static func cannon_goals(ctx, marked: Array, dynamic: bool) -> Array:
	var goals:=repeated(Vector2.ZERO)
	goals[0]=Rules.direction(355)*17; goals[1]=Rules.direction(5)*17
	var split:=str(ctx.profile.get("p1_tank_variant","north_together"))=="split_mitigated"
	if split:
		goals[0]=Rules.direction(315)*17; goals[1]=Rules.direction(45)*17
	if dynamic:
		var ranked:=marked.duplicate(); var priority: Array=[2,4,6,7,5,3]
		ranked.sort_custom(func(a,b):return priority.find(int(a))<priority.find(int(b)))
		for actor in range(2,8): goals[actor]=Rules.direction(150)*8
		for i in 3: goals[int(ranked[i])]=Rules.direction(([250,180,110] if split else [270,180,90])[i])*12
	else:
		var angles: Array=[0,0,260,100,228,132,196,164]
		if str(ctx.profile.id)=="cn_moogle": angles=[0,0,230,130,198,162,270,90]
		if str(ctx.profile.id)=="kr_09stop": angles=[0,0,198,162,230,130,270,90]
		if split: angles=[0,0,250,110,222,138,194,166]
		for actor in range(2,8): goals[actor]=Rules.direction(angles[actor])*12
	return goals
static func append_cannons(ctx) -> void:
	var marked: Array=[]
	for actor in ctx.order:
		if int(actor)>=2 and marked.size()<3: marked.append(int(actor))
	if ctx.profile.has("p1_cannon_marked"): marked=ctx.profile.p1_cannon_marked.map(func(i):return int(i))
	assert(marked.size()==3 and marked.all(func(i):return int(i)>=2 and int(i)<8) and marked[0]!=marked[1] and marked[0]!=marked[2] and marked[1]!=marked[2])
	var rest: Array=[]
	for actor in range(2,8):
		if actor not in marked: rest.append(actor)
	var meta:=route(str(ctx.profile.id))
	var dynamic:=str(ctx.profile.get("p1_cannon_variant",meta.cannon_variant))=="dynamic"
	meta.selected_cannon_variant="dynamic" if dynamic else "static"
	meta.cannon_variant_source_status="documented" if str(ctx.profile.id)=="aether" or not dynamic else "custom training choice, not verified for this community"
	meta.tank_variant=str(ctx.profile.get("p1_tank_variant","north_together"))
	meta.tank_variant_source_status="LPDU slide 8 optional mitigated layout; movement only, mitigation unmodeled" if meta.tank_variant=="split_mitigated" and str(ctx.profile.id)=="lpdu" else ("documented north tanks" if meta.tank_variant=="north_together" else "custom training layout")
	var first:=cannon_goals(ctx,marked,dynamic); var second:=cannon_goals(ctx,rest,dynamic)
	var center:=repeated(Rules.direction(180)*7)
	center[0]=first[0]; center[1]=first[1]
	var start: int=ctx.beats.size()
	append(ctx,"Wave Cannons",P.cannons(marked),[6.0,7.8,15.1],[first,center if dynamic else first,second],meta)
	for i in range(start,ctx.beats.size()):
		# Public method/timing only: never include the solved marked partition.
		ctx.beats[i].cannons_public={"profile_id":str(ctx.profile.id),"dynamic":dynamic,"split_tanks":meta.tank_variant=="split_mitigated","phase":["first","recover","second"][i-start],"source_onset":"source_unknown"}
	# Subset-independent training fixture, NOT an original pull formation.
	ctx.beats[start].spawn=[]
	for actor in 8: ctx.beats[start].spawn.append(Vector2(-3.5+actor,6.0))

static func append_loop(ctx) -> void:
	var start: int=ctx.beats.size()
	var old_profile: Dictionary=ctx.profile.duplicate(true); var old_priority: Array=ctx.priority.duplicate()
	if str(ctx.profile.id) in ["cn_moogle","kr_09stop"]: ctx.profile.loop_start_angle=0.0
	if str(ctx.profile.id)=="lpdu":
		ctx.priority=[4,5,0,1,6,7,2,3]
		ctx.profile.loop_start_angle=315.0 # Raidplan includes the slot slightly left of N as first.
	ctx.program_loop()
	ctx.profile=old_profile; ctx.priority=old_priority
	for i in range(start,ctx.beats.size()):
		ctx.beats[i].p1_route=route(str(ctx.profile.id))
		if i==start:
			ctx.beats[i].transfers.activation_delay=5.3
			var pre: Array=ctx.beats[i].spawn.duplicate()
			for actor in ctx.beats[i].transfers.wanted: pre[int(actor)]=Vector2(-0.8 if int(actor)==int(ctx.beats[i].transfers.wanted[0]) else 0.8,3)
			ctx.beats[i].transfers.preposition=pre
	# Last tower is 40.4; uncured number four expires at 43, not at the tower.
	var tail: Dictionary=ctx.beat("Program Loop: final Looper deadline",2.7,"Uncleansed Looper expires at T43; HP Penalty remains separately timed.")
	tail.p1_route=route(str(ctx.profile.id))
	var recovery: Dictionary=ctx.beat("Program Loop: final status recovery",8.4,"Observe the final delayed HP Penalty and Ruin expiry; healing and job mitigation are not modeled.")
	recovery.p1_route=route(str(ctx.profile.id))
