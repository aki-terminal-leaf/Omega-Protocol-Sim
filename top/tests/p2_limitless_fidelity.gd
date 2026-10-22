extends SceneTree
const E=preload("res://scripts/encounters.gd")
const R=preload("res://scripts/rules.gd")
const I=preload("res://scripts/interactions.gd")
const S=preload("res://scripts/statuses.gd")
const P=preload("res://scripts/p2_limitless_patterns.gd")
const C=preload("res://scripts/p2_limitless_courses.gd")
const L=preload("res://scripts/p2_limitless_runtime.gd")
var assertions:=0
var failures:=0
func check(ok:bool,reason:String)->void:
	assertions+=1
	if not ok:failures+=1;print("LIMITLESS FAIL: ",reason)
func actors_at(points:Array)->Array:
	var actors:Array=[]
	for i in 8:actors.append({"role":E.ROLES[i],"pos":R.v(points[i]),"face":0.0})
	return actors
func fixture(c:Dictionary)->Dictionary:
	var state:Dictionary={"sim_time":0.0,"dynamis":[0,0,0,0,0,0,0,0],"spent":[],"lb":"","aggro":0}
	S.ensure(state);L.begin({"limitless_config":c,"limitless_events":P.events()},state)
	return state
func build(id:String,family:int,arrow:float,shield:float,defense_rank:int,pitch_rank:int):
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var ctx=E.new();ctx.build("unused",39,profiles.filter(func(p):return p.id==id)[0])
	C.append_family(ctx,family,arrow,shield,defense_rank,pitch_rank)
	return ctx
func simulate(ctx,restore:=false)->Dictionary:
	var actors:=actors_at(ctx.beats[0].spawn);var state:=fixture(ctx.beats[0].limitless_config);var restored:=false
	for raw in ctx.beats:
		var b:Dictionary=raw.duplicate(true);I.begin(b,actors,state)
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(0.05,float(b.duration)-elapsed);var before:=actors.duplicate(true)
			for i in 8:actors[i].pos=R.v(actors[i].pos).move_toward(I.bot_goal(i,b,actors,state),6.0*dt)
			I.tick(b,actors,before,state,dt);elapsed+=dt
			if restore and not restored and float(state.sim_time)>8.0:
				state=JSON.parse_string(JSON.stringify(state));restored=true
		state.runtime_failures.append_array(R.evaluate(b,actors,state))
	if "--probe" in OS.get_cmdline_user_args():
		print("LIMITLESS TRACE ",JSON.stringify({"history":state.limitless.history,"pickups":state.get("tether_events",[]),"actors":actors.map(func(a):return P.xy(a.pos))}))
	return state
func negatives()->void:
	var data:=P.registry()
	check(data.observations.size()==4,"four complete captured clears")
	for o in data.observations:
		check(o.verified_capture_files==7 and float(o.jump_prediction_residual)<0.04,"actual shield jump source predicts next source within0.04")
		check(absf(R.v(o.arrow_source).length()-22.0)<0.05 and absf(R.v(o.shield_source).length()-22.0)<0.05,"validated source radii")
	var shape:=P.arrow(Vector2(0,22),Vector2(0,7))
	check(R.contains(shape,Vector2(5,0),[]) and not R.contains(shape,Vector2(5.01,0),[]),"Arrow fullwidth10, no fake halfwidth")
	check(R.contains(shape,Vector2(0,-78),[]) and not R.contains(shape,Vector2(0,-78.01),[]),"Arrow length100 from actual source")
	var ctx=build("elemental",0,0,90,0,0);var c:Dictionary=ctx.beats[0].limitless_config
	var actors:=actors_at([Vector2(12,4),Vector2(12,-4),Vector2.ZERO,Vector2(0,1),Vector2(0,2),Vector2(0,3),Vector2(0,4),Vector2(19,0)])
	var state:=fixture(c);state.sim_time=24.65
	L.resolve({"kind":"defense","at":24.65},actors,state)
	check(int(state.limitless.defense_victim)==7,"Defense chooses actual closest player, not presumed tank")
	check(R.v(state.limitless.shield_current).distance_to(Vector2(22,0))<0.001,"jump cannot overshoot source on a target inside stopping distance")
	actors[7].pos=Vector2(-8,0);actors[0].pos=Vector2.ZERO;actors[1].pos=Vector2.ZERO;state.sim_time=27.8
	L.resolve({"kind":"pitch","at":27.8},actors,state)
	check(state.limitless.history[-1].source==state.limitless.shield_current,"Pitch uses post-jump source")
	state=fixture(c);state.sim_time=5.45
	L.resolve({"kind":"arrow_lock","at":5.45},actors,state);var locked:Dictionary=state.limitless.arrow.duplicate(true)
	for actor in actors:actor.pos+=Vector2(12,0)
	check(state.limitless.arrow==locked,"moving after cast start cannot retarget Arrow")
	state=fixture(c);state.tether_holders=[2,3];state.sim_time=13.55
	L.resolve({"kind":"bladedance","at":13.55},actors,state)
	check(str(state.runtime_failures).contains("actual tether holder is not a tank"),"guide wanted owners cannot grant an actual tank line")
	# Every flare allocation preserves three separate real100y attacks, not safe circles.
	for a in 8:
		for b in range(a+1,8):
			for d in range(b+1,8):
				var config:=c.duplicate(true);config.flare_targets=[a,b,d]
				state=fixture(config);state.sim_time=27.45
				L.resolve({"kind":"flares","at":27.45},actors,state)
				var record:Dictionary=state.limitless.history[-1]
				check(record.origins.size()==3 and record.hits.size()==3 and record.hits.all(func(h):return h.size()==8),"three distinct actual flare packets "+str([a,b,d]))
func _initialize()->void:call_deferred("run")
func run()->void:
	var args:=OS.get_cmdline_user_args()
	if "--probe" in args:
		var ctx=build(args[1],int(args[2]),float(args[3]),float(args[4]),int(args[5]),int(args[6]))
		var state:=simulate(ctx);print("LIMITLESS PROBE FAILURES ",state.runtime_failures);quit(1 if not state.runtime_failures.is_empty() else 0);return
	negatives()
	# Normal generation must exercise each preserved joint observed tuple through
	# actual contacts, movement, lock/snapshot positions and checkpoint restore.
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var observed_courses:=0
	for profile in profiles:
		var captures:Array=[]
		for seed_value in range(1,65):
			var ctx=E.new();ctx.build("p2_limitless",seed_value,profile)
			var c:Dictionary=ctx.beats[0].limitless_config
			if c.spawn_capture in captures:continue
			captures.append(c.spawn_capture)
			var actual:=simulate(ctx,true)
			check(actual.runtime_failures.is_empty(),"observed joint layout %s/%s: %s"%[profile.id,c.spawn_capture,str(actual.runtime_failures)])
			check(actual.limitless.history.size()==8,"all observed-layout events resolve")
			observed_courses+=1
			if captures.size()==4:break
		check(captures.size()==4,"all four measured joint layouts reached for "+str(profile.id))
	print("LIMITLESS OBSERVED MOVING COURSES ",observed_courses)
	var quick:bool="--quick" in args
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		for family in (range(1) if quick else range(4)):
			for angle in ([0,30] if quick else range(0,360,30)):
				var ctx=build(id,family,float(angle),float(posmod(int(angle)+90,360)),posmod(int(angle/30)+family,2),int(angle/30)%2)
				var state:=simulate(ctx,quick)
				check(state.runtime_failures.is_empty(),"%s family%d Arrow%d: %s" % [id,family,angle,str(state.runtime_failures.slice(0,5))])
				check(state.limitless.history.size()==8,"all eight actual events resolve")
	print("LIMITLESS ASSERTIONS ",assertions," FAILURES ",failures)
	quit(1 if failures else 0)
