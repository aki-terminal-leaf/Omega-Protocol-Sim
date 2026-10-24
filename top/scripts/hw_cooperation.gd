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
	# Later rounds: a public exclusive tower choice is reversible until the
	# actual tower event resolves. A tracked default choice still uses the
	# outside lane; do not fall straight through to a stale authored path.
	if int(c.round)>0:
		var pending_tower:=false
		for pending in state.hw.get("pending",[]):
			if pending.get("kind","")=="towers" and int(pending.get("round",-1))==int(c.round) and float(pending.at)>now+0.000001:pending_tower=true;break
		if revealed and pending_tower:
			var buffs:Array=state.get("statuses",[])
			if buffs.size()==8:
				var colour:="red" if buffs[human].has("red") else ("blue" if buffs[human].has("blue") else "")
				var bug:="overflow" if buffs[human].has("overflow") else ("sync" if buffs[human].has("sync") else "")
				if colour!="" and bug!="" and buffs[actor].has(colour) and buffs[actor].has(bug):
					# Actual revealed towers define occupancy; formation goals are
					# offset training targets, not the attack's hit geometry.
					# Preserve old fixtures without tower payloads as a fallback.
					var inside_own:=hp.distance_to(own)<=5.5
					var inside_alternate:=hp.distance_to(alternate)<=5.5
					for pending in state.hw.get("pending",[]):
						if pending.get("kind","")!="towers" or int(pending.get("round",-1))!=int(c.round):continue
						if float(pending.at)<=now+0.000001 or float(pending.at)-now>float(c.reveal_window):continue
						var towers:Array=pending.get("towers",[]).filter(func(t):return str(t.get("colour",""))==colour)
						if towers.size()!=2:continue
						var own_first:=own.distance_to(Rules.v(towers[0].pos))<own.distance_to(Rules.v(towers[1].pos))
						var alternate_first:=alternate.distance_to(Rules.v(towers[0].pos))<alternate.distance_to(Rules.v(towers[1].pos))
						if own_first==alternate_first:continue
						inside_own=Rules.contains(towers[0] if own_first else towers[1],hp,actors)
						inside_alternate=Rules.contains(towers[0] if alternate_first else towers[1],hp,actors)
						break
					if inside_alternate and not inside_own:state.hw[key]=ni
					elif state.hw.has(key) and inside_own and not inside_alternate:state.hw[key]=hi
		if not state.hw.has(key):return null
		if int(state.hw[key])==ni:return human
		return actor if int(state.hw[key])==hi else null
	# Round zero remains owned by the existing first-public observation policy.
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
	if round_index>0:
		var human:=int(state.get("human_actor",-1))
		var choice_key:="hw_tower_choice_%d_%d" % [round_index,mini(human,actor)]
		var side:=int(state.hw.get(choice_key,-1))
		var side_key:=key+"_side"
		# Authored route waypoints evolve during a lane. Reset only when the
		# observed responsibility changes, not on every moving waypoint.
		if int(state.hw.get(side_key,-2))!=side:
			state.hw[key]="out";state.hw[side_key]=side
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
