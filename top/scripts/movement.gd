# SPDX-License-Identifier: MIT
extends RefCounted
## Explicit coaching abilities; never an exemption from real movement budgets.
static func begin(beat:Dictionary,state:Dictionary,exclude_actor:=-1) -> void:
	if not state.has("bot_sprint_until"):
		state.bot_sprint_until=[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
		state.bot_sprint_ready=[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	var now:=float(state.get("sim_time",0))
	var requests:Array=beat.get("bot_sprint",[]).duplicate()
	var delta:Dictionary=beat.get("delta_motion",{})
	if delta.get("sprint_authorized",false) and now>=float(delta.sprint_start)-0.0001 and now<float(delta.sprint_end):requests.append(int(delta.sprint_actor))
	for raw in requests:
		var actor:=int(raw)
		if actor==exclude_actor or float(state.bot_sprint_ready[actor])>now:continue
		state.bot_sprint_until[actor]=now+10.0;state.bot_sprint_ready[actor]=now+60.0
		load("res://scripts/statuses.gd").event(state,"coaching_sprint",{"actor":actor,"expires":now+10.0,"ready":now+60.0})
static func speed(beat:Dictionary,state:Dictionary,actor:int) -> float:
	if state.has("bot_sprint_until") and float(state.bot_sprint_until[actor])>float(state.get("sim_time",0)):return 7.5
	return 6.0 if beat.has("p1_route") or beat.has("p6_route") or beat.has("hw_route") or beat.has("limitless_route") or beat.has("sigma_config") or beat.has("omega_config") or beat.get("delta_guide",false) or beat.get("p5_solar",false) else 11.0
