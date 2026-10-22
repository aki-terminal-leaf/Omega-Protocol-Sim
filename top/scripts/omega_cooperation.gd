# SPDX-License-Identifier: MIT
extends RefCounted
## CN observed-sign cooperation. Does not own combat or physical line transfers.
const Policy=preload("res://scripts/omega_preparation.gd")
const Markers=preload("res://scripts/markers.gd")
const R=preload("res://scripts/rules.gd")
static func mode(c:Dictionary,state:Dictionary) -> String:
	var requested:String=str(state.get("p5_marking_mode",""))
	if c.get("profile","")!="cn_moogle" or requested not in ["manual","assist"]:return "legacy_coaching"
	if requested=="manual" and not Policy.whole(state.get("human_actor"),0,7):return "manual_blocked"
	return requested
static func active(state:Dictionary) -> bool:
	return state.get("omega",{}).get("cooperation",{}).get("mode","") in ["manual","assist","manual_blocked"]
static func initialize(c:Dictionary,state:Dictionary) -> void:
	var selected:=mode(c,state)
	state.omega.cooperation={"mode":selected,"source_pending":c.get("profile","")!="cn_moogle","phases":{}}
	if selected in ["legacy_coaching","manual_blocked"]:return
	Markers.ensure(state)
	capture(state,"first")
static func capture(state:Dictionary,phase:String) -> void:
	var co:Dictionary=state.omega.cooperation
	if co.phases.has(phase):return
	var c:Dictionary=state.omega.config
	co.phases[phase]={"dynamis":state.dynamis.duplicate(),"first":c.first.duplicate(),"second":c.second.duplicate(),"sequence":int(state.target_markers.sequence),"owners_at_entry":state.target_markers.owners.duplicate(),"locked":false,"utility":[],"roles":[],"entered":false,"contact_sequence":state.get("tether_events",[]).size()}
static func observed(state:Dictionary,phase:String) -> Dictionary:
	var p:Dictionary=state.omega.cooperation.phases[phase]
	var human:int=int(state.get("human_actor",-1))
	var result:=Policy.resolve("cn_moogle",p.dynamis,p.first,p.second,phase,state.target_markers.owners,state.target_markers.events,maxi(0,human),p.sequence)
	if human<0 or state.omega.cooperation.mode=="assist":result.self_action={"observed":false,"current":false,"events":[]}
	return result
static func player_owned(state:Dictionary,actor:int) -> bool:
	# Never silently overwrite a player's explicit sign on ANY target.
	var events:Array=state.target_markers.events.duplicate()
	events.reverse()
	for event in events:
		if not event is Dictionary:continue
		if int(event.get("target",-1))==actor:return event.get("source","")=="player"
	return false
static func mark(state:Dictionary,actor:int,sign:String) -> void:
	var co:Dictionary=state.omega.cooperation
	if co.phases.has("second") and actor in co.phases.second.utility:return
	if co.mode=="manual" and (actor==int(state.human_actor) or player_owned(state,actor)):return
	if sign!="" and sign in state.target_markers.owners:return
	Markers.assign(state,actor,sign,actor,"npc" if co.mode=="manual" else "assist")
static func free_sign(state:Dictionary,signs:Array) -> String:
	for sign in signs:
		if sign not in state.target_markers.owners:return sign
	return ""
static func prepare(state:Dictionary,phase:String) -> Dictionary:
	var p:Dictionary=state.omega.cooperation.phases[phase]
	var result:=observed(state,phase)
	if p.locked:return result
	if not result.valid or not result.observations_valid:return result
	if not p.entered:
		p.entered=true
		if phase=="second":
			for actor in 8:mark(state,actor,"")
	# Required Stop actors first; a free legal human choice is never displaced.
	for kind in ["unmarked","stop","bind","attack"]:
		result=observed(state,phase)
		for actor in 8:
			if result.classes[actor]!=kind:continue
			var sign:String=str(state.target_markers.owners[actor])
			if kind=="unmarked":
				if sign!="":mark(state,actor,"")
				continue
			var allowed:Array=Policy.STOPS if kind=="stop" else (Policy.BINDS if kind=="bind" else Policy.ATTACKS)
			# Converted optional actors remain Attack while actual utility is selected.
			if kind=="bind" and result.roles[6]>=0 and result.roles[7]>=0 and actor not in [result.roles[6],result.roles[7]]:allowed=Policy.ATTACKS
			if sign in allowed:continue
			var next:=free_sign(state,allowed)
			if next!="":mark(state,actor,next)
	# Once two utilities actually own signs, explicitly convert remaining NPC
	# Binds. Four eligible actors do not require a fictional fourth Bind ID.
	result=observed(state,phase)
	if phase=="first" and result.roles[6]>=0 and result.roles[7]>=0:
		for actor in 8:
			if result.classes[actor]!="bind" or actor in [result.roles[6],result.roles[7]]:continue
			if state.target_markers.owners[actor] in Policy.ATTACKS:continue
			var sign:=free_sign(state,Policy.ATTACKS)
			if sign!="":mark(state,actor,sign)
	return observed(state,phase)
static func sync(b:Dictionary,state:Dictionary) -> void:
	if not active(state) or not b.has("omega_config"):return
	var co:Dictionary=state.omega.cooperation
	if co.mode=="manual" and not Policy.whole(state.get("human_actor"),0,7):co.mode="manual_blocked"
	if co.mode=="manual_blocked":
		co.latest={"complete":false,"valid":false,"errors":[{"code":"invalid_manual_human_actor"}],"roles":[-1,-1,-1,-1,-1,-1,-1,-1],"unresolved":Policy.ROLE_NAMES.duplicate(),"self_action":{"observed":false,"current":false,"events":[]},"npc_self_actions":[]}
		state.omega.first_roles=[];state.omega.second_roles=[]
		neutral(b);b.bot_sprint=[]
		if b.has("transfers"):b.transfers.wanted=[]
		return
	# Assist changes marking only: a real player still owns movement/Sprint.
	var human:int=int(state.human_actor) if Policy.whole(state.get("human_actor"),0,7) else -1
	if human>=0:b.bot_sprint=b.get("bot_sprint",[]).filter(func(actor):return int(actor)!=human)
	var phase:String=str(b.get("omega_phase",b.get("omega_wait_phase","first")))
	if not co.phases.has(phase):
		# Checkpoints without the real post-first resolution are not fabricated.
		co.latest={"complete":false,"errors":[{"code":"missing_actual_phase_snapshot"}],"roles":[-1,-1,-1,-1,-1,-1,-1,-1]}
		neutral(b);return
	var p:Dictionary=co.phases[phase]
	var result:=prepare(state,phase)
	co.latest=result;co.phase=phase
	if p.locked and result.roles!=p.roles:
		result.errors.append({"code":"marks_changed_after_actual_world_pulse"});result.complete=false
	if not p.utility.is_empty() and [int(result.roles[6]),int(result.roles[7])]!=p.utility:
		result.errors.append({"code":"utility_marks_changed_after_actual_contact"});result.complete=false
	var roles:Array=p.roles.duplicate() if p.locked else result.roles.duplicate()
	roles=roles.map(func(actor):return int(actor))
	var world_pair:Array=p.second if phase=="second" else p.first
	roles[0]=int(world_pair[0]);roles[1]=int(world_pair[1])
	if not p.utility.is_empty():roles[6]=int(p.utility[0]);roles[7]=int(p.utility[1])
	state.omega[phase+"_roles"]=roles
	# Requests are observed second utilities, never build-time forecast IDs.
	if b.has("transfers") and phase=="second":
		b.bot_sprint=[]
		for slot in [6,7]:
			var actor:int=int(roles[slot])
			if actor>=0 and actor<=7 and actor!=human:b.bot_sprint.append(actor)
	# Clone dodge goals are public and unaffected. No monitor/beetle-relative
	# endpoint is installed until the actual phase beat at20.5 /34.2.
	if b.has("omega_wait_phase"):neutral(b)
	if not b.has("omega_phase"):return
	neutral(b)
	var points:Array=load("res://scripts/p5_omega_runtime.gd").goals(b.omega_config,phase=="second")
	for slot in 8:
		var actor:int=int(roles[slot])
		if actor<0 or actor>7:continue
		b.positions[actor]=points[slot];b.labels[actor]=Policy.ROLE_NAMES[slot]
	for check in b.checks:
		if check.kind=="world_pulse":
			var holders:Array=p.second if phase=="second" else p.first
			check.near=int(holders[0]);check.far=int(holders[1])
			check.near_path=[check.near,roles[2],roles[3]];check.far_path=[check.far,roles[4],roles[5]];b.world=check
	if b.has("transfers"):
		b.transfers.wanted=[]
		for slot in [6,7]:
			if int(roles[slot])>=0:b.transfers.wanted.append(int(roles[slot]))
		# Roles may become observed after beat entry. Movement owns the real
		# cooldown/expiry; repeated sync cannot renew an active Sprint.
		load("res://scripts/movement.gd").begin(b,state,human)
static func neutral(b:Dictionary) -> void:
	for actor in 8:b.positions[actor]=Vector2.ZERO;b.labels[actor]="Unresolved preparation"
static func after_snapshot(b:Dictionary,state:Dictionary) -> void:
	if not active(state) or state.omega.cooperation.mode=="manual_blocked":return
	var co:Dictionary=state.omega.cooperation
	var phase:String=str(b.get("omega_phase",""))
	if co.phases.has(phase):
		var p:Dictionary=co.phases[phase]
		if state.get("world_chains",{}).has(str(state.omega.id)+"_"+phase) and not p.locked:
			p.locked=true;p.roles=state.omega[phase+"_roles"].duplicate()
			p.resolution=co.latest.duplicate(true)
			p.owners_at_lock=state.target_markers.owners.duplicate()
			p.lock_sequence=int(state.target_markers.sequence)
			p.lock_time=float(state.get("sim_time",0))
	if b.get("omega_first_finish",false):capture(state,"second")
static func contacts(state:Dictionary) -> void:
	if not active(state) or state.omega.cooperation.mode=="manual_blocked" or not state.omega.cooperation.phases.has("second"):return
	var p:Dictionary=state.omega.cooperation.phases.second
	if not p.utility.is_empty():return
	var roles:Array=state.omega.get("second_roles",[])
	if roles.size()!=8 or int(roles[6])<0 or int(roles[7])<0:return
	if state.get("tether_group","")!=str(state.omega.id)+"_blaster":return
	var selected:Array=[int(roles[6]),int(roles[7])]
	if selected[0]==selected[1]:return
	# JSON restores numeric IDs as floats. Validate before LOCAL normalization;
	# never coerce fractional/bool IDs or rewrite actual physical ownership.
	var actual_holders:Variant=state.get("tether_holders",[])
	if not actual_holders is Array:return
	var holders:Array=[]
	for holder in actual_holders:
		if not Policy.whole(holder,0,7):return
		holders.append(int(holder))
	if not selected.all(func(actor):return actor in holders):return
	var events:Array=state.get("tether_events",[])
	for index in range(events.size()-1,int(p.contact_sequence)-1,-1):
		var event:Variant=events[index]
		if event is Dictionary and event.get("kind","")=="tether_pickup" and Policy.whole(event.get("to"),0,7) and int(event.to) in selected:
			p.utility=selected
			p.utility_commit={"event_index":index,"event":event.duplicate(true),"holders":holders.duplicate(),"boundary":int(p.contact_sequence)}
			return
	# Both selected initial owners without a post-boundary pickup remain
	# provisional. The actual World pulse still locks roles; no fake receipt.
## Shared Interactions hook: at the START of bot_goal, if holds(...) return
## R.v(actors[actor].pos). Otherwise use the unchanged physical transfer router.
static func holds(actor:int,b:Dictionary,state:Dictionary) -> bool:
	if not active(state) or not b.has("omega_config"):return false
	if state.omega.cooperation.mode=="manual_blocked":return true
	if state.omega.cooperation.mode=="manual" and actor==int(state.human_actor):return true
	if not b.has("omega_phase"):return false
	var roles:Array=state.omega.get(str(b.omega_phase)+"_roles",[])
	if actor not in roles:return true
	# The legacy transfer router indexes wanted[slot] and requires two actual
	# intended utilities. An unresolved set must not enter that array path.
	return b.has("transfers") and b.transfers.wanted.size()!=2
