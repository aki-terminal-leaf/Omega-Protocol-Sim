extends SceneTree
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const Runtime=preload("res://scripts/p5_sigma_runtime.gd")
var failures:=0
var assertions:=0
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;print("SIGMA FAIL: ",label)
func actors_at(points: Array) -> Array:
	var out:Array=[]
	for i in 8:out.append({"pos":R.v(points[i]),"role":E.ROLES[i],"face":0.0})
	return out
func state(dynamis: Array) -> Dictionary:return {"dynamis":dynamis.duplicate(),"sim_time":0.0,"lb":"","spent":[],"aggro":0,"seed":43}
func run_course(profile: Dictionary,seed_value: int,roundtrip:=false) -> void:
	var encounter:Dictionary=E.new().build("p5_sigma",seed_value,profile)
	var actors:=actors_at(encounter.beats[0].spawn);var current:=state(encounter.initial_dynamis);var errors:Array=[]
	for raw in encounter.beats:
		var b:Dictionary=raw.duplicate(true);I.begin(b,actors,current)
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(0.1,float(b.duration)-elapsed);var previous:=actors.duplicate(true)
			for i in 8:actors[i].pos=R.v(actors[i].pos).move_toward(I.bot_goal(i,b,actors,current),6.0*dt)
			I.tick(b,actors,previous,current,dt);elapsed+=dt
		if b.has("knockback"):
			for actor in actors:actor.pos+=R.v(actor.pos).normalized()*float(b.knockback)
		errors.append_array(R.evaluate(b,actors,current))
		if roundtrip and b.get("sigma_towers",false):current=JSON.parse_string(JSON.stringify(current))
	errors.append_array(current.get("runtime_failures",[]))
	check(errors.is_empty(),"physical6/s %s seed%d %s"%[profile.id,seed_value,str(errors)])
	var counts:Array=current.dynamis.map(func(value):return int(value));counts.sort();check(counts==[1,1,1,1,2,2,2,2],"actual gains finish4x1/4x2")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var geometry_cases:=0
	for base in profiles:
		for remote in [false,true]:
			for m in 8:
				for north in 8:
					var p:Dictionary=base.duplicate(true);p.merge({"sigma_remote":remote,"sigma_m_angle":m*45,"sigma_tower_angle":north*45,"sigma_double_pairs":[0,3],"sigma_single_unmarked":[0,1]},true)
					var encounter:Dictionary=E.new().build("p5_sigma",47,p)
					var b:Dictionary=encounter.beats.filter(func(x):return x.get("sigma_towers",false))[0].duplicate(true)
					var capacities:Array=[]
					for shape in b.shapes:
						capacities.append(int(shape.count));check(is_equal_approx(R.v(shape.pos).length(),17.0) and shape.radius==3.0,"true tower origin17/radius3")
					capacities.sort();check(capacities==([1,1,2,2,2] if remote else [1,1,1,1,2,2]),"independent5/6tower capacities")
					# Geometry fixture only; actual timed statuses are exercised below.
					b.erase("sigma_config")
					check(R.evaluate(b,actors_at(b.positions),state(encounter.initial_dynamis)).is_empty(),"explicit stress tower rotations and physical-waymark assignments")
					if remote and m==0 and north==0:
						var actors:=actors_at(b.positions)
						for actor in actors:actor.pos=R.v(actor.pos).normalized()*18
						check(not R.evaluate(b,actors,state(encounter.initial_dynamis)).is_empty(),"remote cannot use old18-radius center-ish landings")
					geometry_cases+=1
		for remote in [false,true]:
			for legs in [false,true]:
				for direction in [-1,1]:
					var p:Dictionary=base.duplicate(true);p.merge({"sigma_remote":remote,"sigma_legs":legs,"sigma_direction":direction},true)
					run_course(p,17391,true)
	var e:Dictionary=E.new().build("p5_sigma",7,profiles[0]);var cfg:Dictionary=e.beats[0].sigma_config
	for family in ["western","cn","kr"]:
		cfg.family=family
		for near in 8:
			for far in 8:
				if far==near:continue
				cfg.near=near;cfg.far=far
				var dyn:Array=[1,1,1,1,1,1,0,0];var roles:=Runtime.allocation(cfg,dyn)
				check(roles.size()==8 and not roles.has(-1) and roles.count(roles[0])==1 and roles.count(roles[1])==1,"all ordered World combinations have a complete allocation")
				check(dyn[roles[6]]==1 and dyn[roles[7]]==1,"only one-stack non-World actors skip the World")
	print("SIGMA FIDELITY assertions=",assertions," geometry=",geometry_cases," failures=",failures)
	quit(1 if failures else 0)
