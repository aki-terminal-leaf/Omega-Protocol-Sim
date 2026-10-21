extends SceneTree
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const M=preload("res://scripts/movement.gd")
var failures:=0
var cases:=0
func run_course(profile:Dictionary,seed_value:int) -> void:
	var encounter:Dictionary=E.new().build("p5_full",seed_value,profile)
	var actors:Array=[]
	for i in 8:actors.append({"role":E.ROLES[i],"pos":encounter.beats[0].positions[i],"face":0.0})
	var state:Dictionary={"sim_time":0.0,"dynamis":encounter.initial_dynamis.duplicate(),"spent":[],"lb":"","aggro":0,"seed":seed_value};var errors:Array=[]
	for raw in encounter.beats:
		var b:Dictionary=raw.duplicate(true);I.begin(b,actors,state);M.begin(b,state)
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(0.05,float(b.duration)-elapsed);var previous:=actors.duplicate(true);state.motion_allowances=[]
			for i in 8:
				var speed:=M.speed(b,state,i);state.motion_allowances.append(speed*dt)
				actors[i].pos=R.v(actors[i].pos).move_toward(I.bot_goal(i,b,actors,state),speed*dt);actors[i].face=b.facing.get(i,0.0)
			I.tick(b,actors,previous,state,dt);elapsed+=dt
		for check in b.checks:
			if check.kind=="aggro":state.aggro=check.actor
		var result:=R.evaluate(b,actors,state);errors.append_array(result)
		state.last_snapshot_actors=actors.duplicate(true)
		if not result.is_empty() and "--probe" in OS.get_cmdline_user_args():print("P5 SNAPSHOT ",JSON.stringify({"title":b.title,"time":state.sim_time,"actors":actors.map(func(a):return [a.pos.x,a.pos.y]),"goals":b.positions.map(func(p):return [p.x,p.y]),"actual":state.get("tether_holders",[]),"wanted":b.get("transfers",{}).get("wanted",[]),"errors":result}))
	errors.append_array(state.get("runtime_failures",[]));cases+=1
	if not errors.is_empty() or state.dynamis!=[3,3,3,3,3,3,3,3]:
		failures+=1;print("P5 CONTINUOUS FAIL ",profile.id," seed",seed_value," ",errors.slice(0,10)," final",state.dynamis)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"));var args:=OS.get_cmdline_user_args()
	if "--probe" in args:
		var profile:String=args[1] if args.size()>1 else "lpdu";var seed_value:=int(args[2]) if args.size()>2 else 7
		run_course(profiles.filter(func(p):return p.id==profile)[0],seed_value)
	else:
		for p in profiles:
			for seed_value in [17391,7,43]:run_course(p,seed_value)
	print("P5 CONTINUOUS cases=",cases," failures=",failures)
	quit(1 if failures else 0)
