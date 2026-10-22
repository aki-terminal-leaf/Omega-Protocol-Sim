# SPDX-License-Identifier: MIT
extends RefCounted
## Read-only presentation of observed effects. Never reads route labels/goals.
static var definitions: Dictionary = {}
static func definition(key: String) -> Dictionary:
	if definitions.is_empty(): definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/party_status_definitions.json")).effects
	return definitions.get(key, {"status_id":0,"icon":0,"name":key.replace("_"," ").capitalize()}).duplicate(true)
static func effect(key: String, raw: Dictionary, now: float) -> Dictionary:
	var result := definition(key)
	result.merge(raw,true); result.key = key
	result.kind="marker" if bool(raw.get("marker",false)) else "status"
	# A runtime packet can provide a precise identity for an otherwise unknown key.
	if int(raw.get("status_id",0))>0:
		for known in definitions.values():
			if int(known.status_id)==int(raw.status_id) or known.get("variants",[]).any(func(v):return int(v.status_id)==int(raw.status_id)):
				if not raw.has("icon"): result.icon=known.icon
				if not raw.has("category"):result.category=known.get("category","unknown")
				if not raw.has("name"): result.name=known.name
				break
	result.remaining = maxf(0,float(raw.expires)-now) if raw.has("expires") and float(raw.expires)<1.0e20 else float(raw.get("remaining",-1))
	if bool(result.get("permanent",false)) and float(result.remaining)!=0: result.remaining=-1.0
	result.stacks = int(raw.get("stacks",1))
	return result
static func add(effects: Dictionary, key: String, raw: Dictionary, now: float) -> void:
	var item := effect(key,raw,now)
	if float(item.remaining)==0 or int(item.stacks)<=0: return
	effects[key] = item
static func contains_actor(values:Array,actor:int)->bool:
	return values.any(func(value):return int(value)==actor)
static func signal_visible(raw:Dictionary,state:Dictionary,beat:Dictionary) -> bool:
	var elapsed:=float(state.get("sim_time",0))-float(state.get("beat_started",0))
	return elapsed+0.000001>=float(raw.get("visible_from",0)) and elapsed<float(raw.get("visible_until",INF))
static func rows(actors: Array,state: Dictionary,beat: Dictionary={},controls: Dictionary={}) -> Array:
	var result: Array=[]
	var now:=float(state.get("sim_time",0))
	var lb:Dictionary=state.get("p6_lb",{})
	for i in actors.size():
		var effects:Dictionary={}
		for raw in beat.get("party_statuses",[]):
			if int(raw.actor)==i and signal_visible(raw,state,beat) and str(raw.key) not in state.get("consumed_party_signals",{}).get(str(i),[]): add(effects,str(raw.key),raw,now)
		var buffs:Dictionary=state.get("statuses",[])[i] if i<state.get("statuses",[]).size() else {}
		for key in buffs:
			effects.erase(str(key)) # Runtime expiry overrides any presentation metadata.
			add(effects,str(key),buffs[key],now)
		var stacks:=int(state.get("dynamis",[])[i]) if i<state.get("dynamis",[]).size() else 0
		if (lb.is_empty() or bool(lb.get("memory_entry",false))) and not buffs.has("brilliant_dynamis") and not buffs.has("spark_dynamis"):
			if stacks>0: add(effects,"dynamis",{"stacks":stacks},now)
		elif contains_actor(lb.get("brilliant",[]),i) and not contains_actor(state.get("spent",[]),i): add(effects,"brilliant_dynamis",{},now)
		if contains_actor(lb.get("sparks",[]),i): add(effects,"spark_dynamis",{},now)
		for buff in lb.get("tank_buffs",[]):
			if float(buff.start)<=now and now<float(buff.end):
				var job:=str(lb.get("jobs",[])[int(buff.actor)]) if int(buff.actor)<lb.get("jobs",[]).size() else ""
				add(effects,"tank_lb_"+job.to_lower() if job in ["PLD","WAR","DRK","GNB"] else "tank_lb",{"expires":buff.end},now)
		for doom in lb.get("doom",[]):
			if contains_actor(doom.targets,i): add(effects,"magic_number",{"expires":doom.expires},now)
		if int(controls.get("actor",-1))==i:
			if float(controls.get("sprint_left",0))>0: add(effects,"sprint",{"remaining":controls.sprint_left},now)
			if float(controls.get("knockback_resist_left",0))>0: add(effects,"arms_length",{"remaining":controls.knockback_resist_left},now)
		if i<state.get("bot_sprint_until",[]).size() and float(state.bot_sprint_until[i])>now:add(effects,"sprint",{"expires":float(state.bot_sprint_until[i])},now)
		var dead:bool=contains_actor(state.get("dead",[]),i)
		result.append({"actor":i,"role":str(actors[i].get("role",str(i))),"dead":dead,"effects":[] if dead else effects.values()})
	return result
static func format_effect(item: Dictionary) -> String:
	var text:=str(item.name)
	if int(item.stacks)>1: text+=" x%d"%int(item.stacks)
	if float(item.remaining)>=0: text+=" %.1fs"%float(item.remaining)
	return text
