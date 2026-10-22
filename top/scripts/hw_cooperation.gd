# SPDX-License-Identifier: MIT
extends RefCounted
## Visible player-led tower cooperation; resolution remains in hw_runtime.
const Rules = preload("res://scripts/rules.gd")

static func replacement_actor(actor:int,beat:Dictionary,actors:Array,state:Dictionary):
	if actors.size()!=8:return null
	var human:=int(state.get("human_actor",-1))
	var choices:Array=beat.get("hw_tower_cooperations",[])
	if choices.is_empty() and beat.has("hw_tower_cooperation"):choices=[beat.hw_tower_cooperation]
	var c:Dictionary={}
	for candidate in choices:
		var candidate_pair:Array=candidate.actors.map(func(value):return int(value))
		if human in candidate_pair and actor in candidate_pair and actor!=human:c=candidate;break
	if c.is_empty():return null
	var pair:Array=c.actors.map(func(value):return int(value))
	if human not in pair or actor not in pair or actor==human:return null
	var now:=float(state.get("sim_time",0.0))
	var revealed:=false
	for pending in state.get("hw",{}).get("pending",[]):
		if pending.get("kind","")=="towers" and int(pending.get("round",-1))==int(c.round) and float(pending.at)-now<=float(c.reveal_window):revealed=true;break
	var hi:=pair.find(human);var ni:=1-hi
	var own:=Rules.v(c.goals[hi]);var alternate:=Rules.v(c.goals[ni])
	var hp:=Rules.v(actors[human].pos)
	var key:="hw_tower_choice_%d_%d" % [int(c.round),mini(pair[0],pair[1])]
	var active_round:=int(state.hw.get("cooperation_round",-1))
	if active_round!=int(c.round):
		for old_key in state.hw.keys():
			if str(old_key).begins_with("hw_tower_choice_"):state.hw.erase(old_key)
	state.hw.cooperation_round=int(c.round)
	# Persist the observed legal side swap through every later beat in this round.
	if not state.hw.has(key):
		if not revealed:return null
		# Planned pair membership is not proof of actual current rot/bug state.
		var buffs:Array=state.get("statuses",[])
		if buffs.size()!=8:return null
		var colour:="red" if buffs[human].has("red") else ("blue" if buffs[human].has("blue") else "")
		var bug:="overflow" if buffs[human].has("overflow") else ("sync" if buffs[human].has("sync") else "")
		if colour=="" or bug=="" or not buffs[actor].has(colour) or not buffs[actor].has(bug):return null
		if hp.distance_to(alternate)<=5.5 and hp.distance_to(own)>5.5:state.hw[key]=ni
	if int(state.hw.get(key,hi))!=ni:return null
	return human

# A swapped carrier goes around the outside rather than through clean waiting
# tether players. These are explicit training lanes, not official coordinates.
static func walking_goal(actor:int,target:Vector2,beat:Dictionary,actors:Array,state:Dictionary)->Vector2:
	var round_index:=int(beat.hw_tower_cooperation.round)
	var tower_pending:=false
	for pending in state.hw.pending:
		if pending.get("kind","")=="towers" and int(pending.get("round",-1))==round_index:tower_pending=true;break
	if not tower_pending:return target
	var key:="hw_cooperation_lane_%d_%d" % [round_index,actor]
	var phase:=str(state.hw.get(key,"out"))
	var here:=Rules.v(actors[actor].pos)
	if phase=="out":
		if here.length()<17.8:return here.normalized()*18.0
		phase="around";state.hw[key]=phase
	if phase=="around":
		var difference:=angle_difference(here.angle(),target.angle())
		if absf(difference)>0.03:return Vector2.from_angle(here.angle()+clampf(difference,-0.1,0.1))*18.0
		state.hw[key]="in"
	return target
