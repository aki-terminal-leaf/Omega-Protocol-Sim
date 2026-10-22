# SPDX-License-Identifier: MIT
extends RefCounted
## Source rank is immutable; this module never assigns player inputs or damage.
const R=preload("res://scripts/rules.gd")
static func point(actor:int,beat:Dictionary)->Vector2:
	var c:Dictionary=beat.monitor_preparation
	var slot:int=c.order.find(actor)
	# CN's first unmarked observes north; three marked and the remaining four
	# sort separately. Exact missing figure1 positions are NOT claimed.
	if str(c.layout).begins_with("cn_"):
		if slot==3:return Vector2(0,-7.0)
		return Vector2(-4.0,-3.0+slot*3.0) if slot<3 else Vector2(4.0,-4.5+(slot-4)*3.0)
	# Published conga priority, top to bottom; numeric spacing is training-only.
	var ranked:Array=c.order.duplicate()
	ranked.sort_custom(func(a,b):return c.priority.find(["MT","ST","H1","H2","D1","D2","D3","D4"][int(a)])<c.priority.find(["MT","ST","H1","H2","D1","D2","D3","D4"][int(b)]))
	return Vector2(-4.0,-5.25+ranked.find(actor)*1.5)
static func sorting(beat:Dictionary,state:Dictionary)->bool:
	return beat.has("monitor_preparation") and float(state.get("sim_time",0))-float(state.get("beat_started",0))<float(beat.monitor_preparation.sort_until)
static func goal(actor:int,beat:Dictionary,state:Dictionary)->Vector2:
	return point(actor,beat) if sorting(beat,state) else R.v(beat.positions[actor])
static func observe(beat:Dictionary,actors:Array,state:Dictionary)->void:
	if not sorting(beat,state):return
	var human:=int(state.get("human_actor",-1))
	if human<0 or human>=actors.size():return
	if R.v(actors[human].pos).distance_to(point(human,beat))<=1.0:
		state.monitor_preparation_observed={"actor":human,"at":float(state.sim_time),"sort_observed":true,"source_rank":beat.monitor_preparation.order.find(human),"scope":"observed staging, not full guide certification"}
