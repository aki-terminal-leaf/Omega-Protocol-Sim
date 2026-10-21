extends SceneTree
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const M=preload("res://scripts/movement.gd")
const Runtime=preload("res://scripts/p5_omega_runtime.gd")
var assertions:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	assertions+=1
	if not ok:failures+=1;print("OMEGA FAIL: ",label)
func actors_at(points:Array) -> Array:
	var out:Array=[]
	for i in 8:out.append({"pos":R.v(points[i]),"role":E.ROLES[i],"face":0.0})
	return out
func course(profile:Dictionary,seed_value:int,restore:=false) -> void:
	var e:Dictionary=E.new().build("p5_omega",seed_value,profile)
	var actors:=actors_at(e.beats[0].spawn);var state:Dictionary={"sim_time":0.0,"dynamis":e.initial_dynamis.duplicate(),"spent":[],"lb":"","aggro":0,"seed":seed_value};var errors:Array=[]
	for raw in e.beats:
		var b:Dictionary=raw.duplicate(true);I.begin(b,actors,state);M.begin(b,state)
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(0.05,float(b.duration)-elapsed);var previous:=actors.duplicate(true);state.motion_allowances=[]
			for i in 8:
				var speed:=M.speed(b,state,i);state.motion_allowances.append(speed*dt)
				actors[i].pos=R.v(actors[i].pos).move_toward(I.bot_goal(i,b,actors,state),speed*dt)
			I.tick(b,actors,previous,state,dt);elapsed+=dt
		var result:=R.evaluate(b,actors,state);errors.append_array(result)
		if "--probe" in OS.get_cmdline_user_args() and not result.is_empty():print("OMEGA SNAPSHOT ",JSON.stringify({"title":b.title,"time":state.sim_time,"actors":actors.map(func(a):return [a.pos.x,a.pos.y]),"goals":b.positions.map(func(v):return [v.x,v.y]),"wanted":b.get("transfers",{}).get("wanted",[]),"actual":state.get("tether_holders",[]),"errors":result}))
		if restore and b.get("omega_first_finish",false):state=JSON.parse_string(JSON.stringify(state))
	errors.append_array(state.get("runtime_failures",[]))
	check(errors.is_empty(),"physical %s seed%d side%s beetle%s: %s"%[profile.id,seed_value,str(profile.get("omega_monitor_angle","random")),str(profile.get("omega_beetle_angle","random")),str(errors.slice(0,10))])
	check(state.dynamis==[3,3,3,3,3,3,3,3],"all actual eight finish3")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	if "--probe" in OS.get_cmdline_user_args():
		var args:=OS.get_cmdline_user_args();var p:Dictionary=profiles[0].duplicate(true);p.merge({"omega_monitor_angle":int(args[1]) if args.size()>1 else 90,"omega_beetle_angle":int(args[2]) if args.size()>2 else 0},true);course(p,17391,true);quit(1 if failures else 0);return
	# All256 geometric combinations are robustly tested;192 are the documented
	# normal families,64 both-identical repeats are explicit custom stress cases.
	var clone_cases:=0
	for orientation in [0,90,180,270]:
		for offset in [-90,90]:
			for diffuse in [0,90]:
				for s1 in 4:
					for s2 in 4:
						var p:Dictionary=profiles[0].duplicate(true);p.merge({"omega_orientation":orientation,"omega_second_offset":offset,"omega_diffuse_axis":diffuse,"omega_stances":[[bool(s1&1),bool(s1&2)],[bool(s2&1),bool(s2&2)]]},true)
						var e:Dictionary=E.new().build("p5_omega",17,p)
						for b in e.beats.slice(0,2):
							check(b.shapes.all(func(shape):return not R.contains(shape,b.positions[0],[])),"single guide cardinal avoids full clone and diffuse geometry")
						check(e.beats[0].positions[0].distance_to(e.beats[1].positions[0])<=24.0,"default far16.5 safe-cardinal realization is reachable within4sec walking")
						clone_cases+=1
	for base in profiles:
		for monitor in [90,270]:
			for beetle in [0,90,180,270]:
				var p:Dictionary=base.duplicate(true);p.merge({"omega_monitor_angle":monitor,"omega_beetle_angle":beetle},true);course(p,17391,true)
	var e:Dictionary=E.new().build("p5_omega",7,profiles[0])
	var b:Dictionary=e.beats.filter(func(item):return item.get("omega_monitor",false))[0].duplicate(true)
	var state:Dictionary={"sim_time":0.0,"dynamis":e.initial_dynamis.duplicate(),"spent":[],"lb":"","aggro":0}
	var actors:=actors_at(b.positions);I.begin(b,actors,state)
	var angle:float=b.omega_config.monitor_angle
	for i in 8:actors[i].pos=R.direction(angle+180)*10.0+Vector2(0,i*0.01)
	actors[0].pos=R.direction(angle)*10;actors[1].pos=actors[0].pos+Vector2(0.1,0.1)
	var result:=R.evaluate(b,actors,state)
	check(str(result).contains("radius7 overlap") and state.timeline.any(func(event):return event.kind=="omega_monitor_resolution" and event.targets.has(0) and event.targets.has(1)),"monitor selects actual half players, not guide utility; overlapping7y splashes fail")
	check(state.dynamis==e.initial_dynamis,"monitor cannot manufacture Dynamis")
	state={"sim_time":0.0,"dynamis":e.initial_dynamis.duplicate(),"spent":[],"lb":"","aggro":0};actors=actors_at(b.positions);I.begin(b,actors,state)
	var previous:=actors.duplicate(true);actors[0].pos+=Vector2(7.0,0);state.sim_time=1.0;Runtime.tick(actors,previous,state,1.0)
	check(str(state.runtime_failures).contains("unauthorized movement"),"Omega rejects unauthorized movement even if a later endpoint is safe")
	var cfg:Dictionary=b.omega_config.duplicate(true);var no_three:Array=[2,2,2,2,2,2,2,2]
	check(Runtime.choose(cfg,no_three,true).is_empty(),"missed firstWorld gains cannot invent two3-stack Blaster players")
	var sprint_state:Dictionary={"sim_time":0.0,"timeline":[]};var sprint_beat:Dictionary={"omega_config":{},"bot_sprint":[0]};M.begin(sprint_beat,sprint_state);check(M.speed(sprint_beat,sprint_state,0)==7.5,"declared Sprint is an explicit ability")
	sprint_state.sim_time=10.0;M.begin(sprint_beat,sprint_state);check(M.speed(sprint_beat,sprint_state,0)==6.0,"Sprint expires10s and cannot refresh before60s cooldown")
	print("OMEGA FIDELITY assertions=",assertions," clone_cases=",clone_cases," failures=",failures)
	quit(1 if failures else 0)
