extends SceneTree
const Encounter = preload("res://scripts/encounters.gd")
const Rules = preload("res://scripts/rules.gd")
const Status = preload("res://scripts/statuses.gd")
var assertions := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok: failures+=1;print("CALIBRATION FAIL: ",label)
func fresh() -> Dictionary:
	return {"dynamis":[0,0,0,0,0,0,0,0],"sim_time":0.0}
func actors_for(b: Dictionary) -> Array:
	var actors: Array=[]
	for i in 8:actors.append({"role":Encounter.ROLES[i],"pos":b.positions[i],"face":0})
	return actors
func _initialize() -> void:
	var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var world: Dictionary=Encounter.new().build("p5_dynamis",47,profiles[0])
	var b: Dictionary=world.beats[0];var actors:=actors_for(b);var state:=fresh()
	check(float(b.checks[0].holder_radius)==8.0 and float(b.checks[0].jump_radius)==4.0,"actual first/jump radii 8/4")
	check(Rules.evaluate(b,actors,state).is_empty(),"initial two holders resolve independently")
	check(state.dynamis.count(1)==2,"future jumps do not grant Dynamis early")
	var near_a: int=b.checks[0].near_path[1];var near_b: int=b.checks[0].near_path[2]
	# Both legal 4y movements fit within the next 1s at ordinary 6y/s.
	actors[near_a].pos.y-=4;actors[near_b].pos.y-=4;state.sim_time=1.0
	check(Rules.evaluate(world.beats[1],actors,state).is_empty(),"legal alternate first jump accepted")
	var chain: Dictionary=state.world_chains[b.checks[0].chain_id]
	check(chain.history[2].receiver==near_b,"first jump reads changed nearest actor, not guide assignment")
	state.sim_time=2.0
	check(Rules.evaluate(world.beats[2],actors,state).is_empty(),"second jump reads the actual prior receiver")
	check(chain.history[4].receiver==near_a and state.dynamis.count(1)==6,"alternate route produces all six actual gains")
	actors=actors_for(b);state=fresh();Status.ensure(state)
	var later: int=b.checks[0].near_path[2]
	state.blaster_victims=[later];Status.give(state,later,"hp_penalty",3.0)
	for pulse in 3:
		state.sim_time=1.7+pulse
		check(Rules.evaluate(world.beats[pulse],actors,state).is_empty(),"expired HP Penalty is not a permanent historical-ownership veto pulse%d"%pulse)
	actors=actors_for(b);state=fresh();Status.ensure(state)
	Status.give(state,int(b.checks[0].near),"hp_penalty",3.0)
	check(str(Rules.evaluate(b,actors,state)).contains("HP Penalty"),"active HP Penalty checked on actual hit")
	actors=actors_for(b);state=fresh()
	var origin: int=b.checks[0].near
	actors[near_a].pos=actors[origin].pos+Vector2(-8,0)
	check(str(Rules.evaluate(b,actors,state)).contains("clipped"),"8y first World boundary is hazardous, not old5y radius")
	actors=actors_for(b);state=fresh();Status.ensure(state);state.dead=[origin]
	check(str(Rules.evaluate(b,actors,state)).contains("holder died"),"dead World holder is not silently reassigned")
	check(float(Status.parameter("ruin_duration"))==11 and float(Status.parameter("hp_penalty_duration"))==9,"P1 reported11s Ruin and9s HP Penalty")
	check(float(Status.parameter("omega_hp_penalty_duration"))==3,"Omega HP Penalty is not reused9s P1 timer")
	check(float(Status.parameter("hw_smell_duration"))==3 and float(Status.parameter("hw_latent_sync_duration"))==69,"observed initial Smell and LatentSync timers")
	print("CALIBRATION ASSERTIONS ",assertions," FAILURES ",failures)
	quit(1 if failures else 0)
