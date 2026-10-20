extends SceneTree
const Contact = preload("res://scripts/interactions.gd")
const Rules = preload("res://scripts/rules.gd")
const Encounter = preload("res://scripts/encounters.gd")
var failures := 0
var assertions := 0
func check(value: bool, name: String) -> void:
	assertions += 1
	if not value: print("INTERACTION FAIL: ",name); failures += 1
func party() -> Array:
	var result: Array = []
	for i in 8: result.append({"pos":Vector2(-15+i*2,-10),"face":0,"role":Encounter.ROLES[i]})
	result[0].pos=Vector2(12,0);result[1].pos=Vector2(0,-12)
	return result
func config() -> Dictionary:
	return {"transfers":{"group":"loop","initial":[0,1],"wanted":[2,3],"sources":[Vector2.ZERO,Vector2.ZERO]},"shapes":[{"actor":0,"radius":2,"tether_index":0},{"actor":1,"radius":2,"tether_index":1}],"program_loop":{"round":1,"numbers":[3,4,1,1,2,2,3,4],"holders":[]}}
func initial_state() -> Dictionary:
	return {"sim_time":0.0,"dynamis":[0,0,0,0,0,0,0,0],"spent":[],"lb":"","aggro":0}
func _initialize() -> void:
	var actors=party();var beat=config();var state=initial_state()
	actors[2].pos=Vector2(6,3);Contact.begin(beat,actors,state)
	var previous=actors.duplicate(true);actors[2].pos=Vector2(6,-3)
	Contact.tick(beat,actors,previous,state,0.016)
	check(state.tether_holders==[2,1],"swept crossing picks up line even when final point is outside radius")
	check(beat.shapes[0].actor==2 and beat.program_loop.holders[0]==2,"damage and visible line use actual holder")
	check(state.tether_events.size()==1 and state.tether_events[0].from==0 and state.tether_events[0].to==2,"pickup records donor, receiver and time")
	var next_beat=config();next_beat.transfers.initial=[4,5]
	Contact.begin(next_beat,actors,state)
	check(state.tether_holders==[2,1],"new wave does not magically reassign tethers")
	actors=party();beat=config();state=initial_state();actors[2].pos=Vector2(6,3)
	Contact.begin(beat,actors,state);previous=actors.duplicate(true);actors[2].pos=Vector2(6,2)
	Contact.tick(beat,actors,previous,state,0.1)
	check(state.tether_holders==[0,1],"near line without contact does not steal")
	previous=actors.duplicate(true);actors[2].pos=Vector2(6,0)
	Contact.tick(beat,actors,previous,state,0.1)
	var events: int=state.tether_events.size()
	for _n in 10: Contact.tick(beat,actors,actors.duplicate(true),state,0.1)
	check(state.tether_events.size()==events,"standing on contact does not ping-pong owners")
	actors[3].pos=Vector2(3,2);previous=actors.duplicate(true);actors[3].pos=Vector2(3,-2)
	Contact.tick(beat,actors,previous,state,0.1)
	check(state.tether_holders[0]==3,"a second person can steal an already transferred line")
	# Changing the actual holder changes who receives Blaster, independent of suggested goals.
	actors=party();beat=config();state=initial_state();Contact.begin(beat,actors,state);Rules.ensure_loop_state(beat,state)
	beat.shapes=[{"actor":2,"radius":1.0,"rule":"blaster","name":"Blaster"}]
	beat.program_loop.numbers=[3,4,3,4,2,2,3,4]
	Rules.evaluate(beat,actors,state)
	check(float(state.loop_hp_penalty[2])>0 and float(state.loop_hp_penalty[0])==0,"Blaster debuffs actual target, not initial tether owner")
	var errors=Rules.evaluate(beat,actors,state)
	check(str(errors).contains("Doom"),"two hits before Ruin expires cause Doom")
	state.sim_time=17.0;errors=Rules.evaluate(beat,actors,state)
	check(not str(errors).contains("Doom"),"expired Ruin is not counted as a second hit")
	# A legitimate same-number pair can swap towers: no strategy-position policing.
	var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var encounter=Encounter.new().build("p1_loop",43,profiles[0]);beat=encounter.beats[0].duplicate(true);actors=[]
	for i in 8: actors.append({"pos":beat.positions[i],"role":Encounter.ROLES[i],"face":0})
	state=initial_state();state.sim_time=16.0;Contact.begin(beat,actors,state);state.tether_holders=beat.transfers.wanted.duplicate();Contact.sync(beat,state)
	var tower_members: Array=[]
	for i in 8:
		if int(beat.program_loop.numbers[i])==1: tower_members.append(i)
	var swap=actors[tower_members[0]].pos;actors[tower_members[0]].pos=actors[tower_members[1]].pos;actors[tower_members[1]].pos=swap
	errors=Rules.evaluate(beat,actors,state)
	check(errors.is_empty(),"either active Looper holder can soak either tower")
	check(state.loop_cleansed.count(true)==2,"tower removes Looper from its actual occupants")
	# Staying at a suggested endpoint without ever taking a line cannot pass all four waves.
	state=initial_state();var detected=false
	for raw in encounter.beats:
		beat=raw.duplicate(true);actors=[];state.sim_time+=float(beat.duration)
		for i in 8: actors.append({"pos":beat.positions[i],"role":Encounter.ROLES[i],"face":0})
		Contact.begin(beat,actors,state)
		if not Rules.evaluate(beat,actors,state).is_empty(): detected=true
	check(detected,"perfect final positions alone do not bypass actual tether ownership")
	# Tower+Blaster overlap and missing Looper cleanses are actual failure causes.
	beat=encounter.beats[0].duplicate(true);actors=[];state=initial_state();state.sim_time=16.0
	for i in 8: actors.append({"pos":beat.positions[i],"role":Encounter.ROLES[i],"face":0})
	Contact.begin(beat,actors,state);state.tether_holders=[tower_members[0],tower_members[1]];Contact.sync(beat,state)
	errors=Rules.evaluate(beat,actors,state)
	check(str(errors).contains("Doom"),"taking tower and holding a Blaster line causes Ruin x2")
	beat=encounter.beats[0].duplicate(true);state=initial_state();state.sim_time=16.0
	for member in tower_members: actors[member].pos=Vector2(5,0)
	Contact.begin(beat,actors,state);state.tether_holders=beat.transfers.wanted.duplicate();Contact.sync(beat,state)
	errors=Rules.evaluate(beat,actors,state)
	check(str(errors).contains("Memory Loss"),"uncleansed expired Looper causes Memory Loss")
	# Distance-selected attacks follow the real target, not an MT/D4 name in a plan.
	actors=party();actors[4].pos=Vector2(18,0);actors[7].pos=Vector2(2,0)
	var dynamic={"dynamic_actor":{"selector":"furthest","ordinal":0},"radius":1.0}
	check(Rules.point(dynamic,actors)==actors[4].pos,"furthest-targeted circle follows actual furthest actor")
	check(Rules.selected_actor({"dynamic_actor":{"selector":"closest","ordinal":0}},actors)==7,"nearest-targeted attack uses actual nearest actor")
	# Alternate valid World routing is accepted; it need not match the displayed guide.
	encounter=Encounter.new().build("p5_dynamis",47,profiles[0]);beat=encounter.beats[0].duplicate(true);actors=[]
	for i in 8:actors.append({"pos":beat.positions[i],"role":Encounter.ROLES[i],"face":0})
	beat.checks[0].near_path=[0,0,0];beat.checks[0].far_path=[0,0,0]
	check(Rules.evaluate(beat,actors,initial_state()).is_empty(),"valid nearest/farthest world hits are not compared with a guide's path")
	print("INTERACTION ASSERTIONS ",assertions," FAILURES ",failures)
	quit(1 if failures else 0)
