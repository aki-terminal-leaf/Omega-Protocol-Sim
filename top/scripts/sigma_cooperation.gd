# SPDX-License-Identifier: MIT
extends RefCounted
## Observed CN self marks. Combat and player movement remain independent.
const P=preload("res://scripts/sigma_preparation.gd")
const M=preload("res://scripts/markers.gd")
static func active(s:Dictionary)->bool:
	return s.get("sigma",{}).get("cooperation",{}).get("mode","") in ["manual","assist","manual_blocked"]
static func initialize(c:Dictionary,s:Dictionary)->void:
	if s.sigma.has("cooperation"):return
	M.ensure(s)
	var selected:String=str(s.get("p5_marking_mode",""))
	if str(c.profile)!="cn_moogle" or selected not in ["manual","assist"]:selected="legacy_coaching"
	if selected=="manual" and not P.whole(s.get("human_actor"),0,7):selected="manual_blocked"
	s.sigma.cooperation={"mode":selected,"source_pending":str(c.profile)!="cn_moogle","priority":c.get("priority",range(8)).duplicate(),"entry":{"dynamis":s.dynamis.duplicate(),"near":int(c.near),"far":int(c.far),"sequence":int(s.target_markers.sequence),"owners_at_entry":s.target_markers.owners.duplicate(),"reveal_kind":"current_runtime_observation","lock_boundary":"implementation_boundary","locked":false,"lock_time":-1.0,"lock_sequence":-1,"owners_at_lock":[],"resolution":{}},"latest":{},"late_events":[]}
static func observed(s:Dictionary)->Dictionary:
	var co:Dictionary=s.sigma.cooperation
	var e:Dictionary=co.entry
	# Assistance has no player self-action assessment; use the ACTUAL World
	# observer (unmarked obligation) and explicitly suppress manual receipts.
	var observer:int=int(e.near) if co.mode=="assist" else int(s.get("human_actor",-1))
	var out:Dictionary=P.resolve("cn_moogle",e.dynamis,e.near,e.far,s.target_markers.owners,s.target_markers.events,observer,e.sequence)
	if co.mode=="assist":out.self_action={"observed":false,"current":false,"events":[]};out.assisted=true
	return out
static func player_owned(s:Dictionary,actor:int)->bool:
	var history:Array=s.target_markers.events.duplicate();history.reverse()
	for event in history:
		if event is Dictionary and int(event.get("target",-1))==actor:return event.get("source","")=="player"
	return false
static func mark(s:Dictionary,actor:int,sign:String)->bool:
	var co:Dictionary=s.sigma.cooperation
	if player_owned(s,actor) or (co.mode=="manual" and actor==int(s.human_actor)):return false
	if sign!="" and sign in s.target_markers.owners:return false
	return bool(M.assign(s,actor,sign,actor,"npc" if co.mode=="manual" else "assist").ok)
static func free_sign(s:Dictionary,allowed:Array)->String:
	for sign in allowed:
		if sign not in s.target_markers.owners:return sign
	return ""
static func prepare(s:Dictionary)->Dictionary:
	var co:Dictionary=s.sigma.cooperation
	var e:Dictionary=co.entry
	if e.locked:return observed(s)
	var actual_human:int=int(s.get("human_actor",-1))
	var world:Array=[int(e.near),int(e.far)]
	var reserve_attack:int=0;var reserve_stop:int=0
	if co.mode=="manual" and actual_human not in world:
		var human_sign:String=str(s.target_markers.owners[actual_human])
		if human_sign not in P.A+["attack5"]+P.S:
			if int(e.dynamis[actual_human])==1:reserve_attack=1
			else:reserve_stop=1
	var desired_attacks:int=4-reserve_attack
	var desired_stops:int=2-reserve_stop
	# Numeric choices among free source-approved signs are implementation policy.
	var order:Array=co.priority.map(func(a):return int(a))
	for actor in world:
		if s.target_markers.owners[actor]!="":mark(s,actor,"")
	var attacks:int=0;var stops:int=0
	for actor in 8:
		if actor in world:continue
		var sign:String=str(s.target_markers.owners[actor])
		if int(e.dynamis[actor])==1 and sign in P.A+["attack5"]:attacks+=1
		elif sign in P.S:stops+=1
	for actor in order:
		if attacks>=desired_attacks:break
		if actor in world or int(e.dynamis[actor])!=1:continue
		var previous:String=str(s.target_markers.owners[actor])
		if previous in P.A+["attack5"]:continue
		var sign:=free_sign(s,P.A)
		if sign!="" and mark(s,actor,sign):
			attacks+=1
			if previous in P.S:stops-=1
	for actor in order:
		if stops>=desired_stops:break
		if actor in world:continue
		var previous:String=str(s.target_markers.owners[actor])
		if previous in P.A+["attack5"]+P.S:continue
		var sign:=free_sign(s,P.S)
		if sign!="" and mark(s,actor,sign):stops+=1
	return observed(s)
static func lock(s:Dictionary)->void:
	if not active(s) or s.sigma.cooperation.mode=="manual_blocked":return
	var e:Dictionary=s.sigma.cooperation.entry
	if e.locked:return
	var result:=prepare(s)
	e.locked=true;e.lock_time=float(s.get("sim_time",0));e.lock_sequence=int(s.target_markers.sequence);e.owners_at_lock=s.target_markers.owners.duplicate();e.resolution=result.duplicate(true)
static func sync(b:Dictionary,s:Dictionary)->void:
	if not active(s) or not b.has("sigma_config"):return
	var co:Dictionary=s.sigma.cooperation
	if co.mode=="manual" and not P.whole(s.get("human_actor"),0,7):co.mode="manual_blocked"
	if co.mode=="manual_blocked":
		co.latest={"complete":false,"errors":[{"code":"invalid_manual_human_actor"}],"roles":[-1,-1,-1,-1,-1,-1,-1,-1],"unresolved":P.N.duplicate()};s.sigma.roles=[];return
	var result:=prepare(s);var e:Dictionary=co.entry
	if e.locked:
		co.late_events=s.target_markers.events.filter(func(event):return int(event.get("sequence",0))>int(e.lock_sequence)).duplicate(true)
		if s.target_markers.owners!=e.owners_at_lock:result.errors.append({"code":"marks_changed_after_route_lock"});result.complete=false
	co.latest=result
	var roles:Variant=(e.resolution if e.locked else result).get("roles",[])
	if not roles is Array or roles.size()!=8 or not roles.all(func(actor):return P.whole(actor,-1,7)):
		s.sigma.roles=[];return
	s.sigma.roles=roles.map(func(actor):return int(actor))
	if b.has("sigma_path_index"):
		for actor in 8:b.positions[actor]=Vector2.ZERO;b.labels[actor]="Unresolved preparation"
		load("res://scripts/p5_sigma_runtime.gd").place(b,b.sigma_config,s.sigma.roles,int(b.sigma_path_index))
static func holds(actor:int,b:Dictionary,s:Dictionary)->bool:
	if not active(s):return false
	if actor==int(s.get("human_actor",-1)):return true
	if not b.has("sigma_path_index"):return false
	if s.sigma.cooperation.mode=="manual_blocked":return true
	return s.sigma.roles.size()!=8 or actor not in s.sigma.roles
