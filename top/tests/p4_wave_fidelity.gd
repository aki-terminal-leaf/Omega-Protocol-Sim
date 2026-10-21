# SPDX-License-Identifier: MIT
extends SceneTree
const P = preload("res://scripts/p4_wave_patterns.gd")
const C = preload("res://scripts/p4_wave_courses.gd")
const R = preload("res://scripts/p4_wave_runtime.gd")
const Rules = preload("res://scripts/rules.gd")
const Status = preload("res://scripts/statuses.gd")
class Context:
	extends RefCounted
	var positions: Array=[]
	var beats: Array=[]
	var profile: Dictionary={"id":"elemental"}
	var rng := RandomNumberGenerator.new()
	func beat(title: String, duration: float, note: String) -> Dictionary:
		var b := {"title":title,"duration":duration,"note":note,"positions":positions.duplicate(),"shapes":[]}
		beats.append(b)
		return b
var assertions := 0
var failures := 0
var physical_cases := 0
var max_distance := 0.0
func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		if failures<25: print("FAIL ",message)
func fresh() -> Dictionary:
	var s := {"sim_time":0.0}
	Status.ensure(s)
	return s
func actors_at(points: Array) -> Array:
	var result: Array=[]
	for i in points.size(): result.append({"pos":points[i],"role":str(i),"face":0.0})
	return result
func make_course(id: String, pairs: Array, family: int) -> Array:
	var ctx := Context.new(); ctx.profile.id=id
	C.append_family(ctx,pairs,family)
	return ctx.beats
func simulate(beats: Array, frame: float, restore := false, speed := 6.0) -> Dictionary:
	var state := fresh()
	var actors := actors_at([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
	for b in beats:
		Status.begin(b,state)
		var elapsed := 0.0
		while elapsed<float(b.duration)-0.000001:
			var dt := minf(frame,float(b.duration)-elapsed)
			var previous := actors.duplicate(true)
			for i in 8:
				actors[i].pos=Rules.v(actors[i].pos).move_toward(Rules.v(b.positions[i]),speed*dt)
				max_distance=maxf(max_distance,Rules.v(previous[i].pos).distance_to(Rules.v(actors[i].pos))/dt)
			state.sim_time=float(state.sim_time)+dt
			R.tick(actors,previous,state,dt)
			elapsed+=dt
		# Restore at each beat boundary, including pending old proteans.
		if restore: state=JSON.parse_string(JSON.stringify(state))
	return state
func one_event(event: Dictionary, actors: Array) -> Dictionary:
	var s := fresh()
	R.begin({"p4_wave_events":[],"p4_wave_duration":5.0},s)
	R.resolve(event,actors,s)
	return s
func negatives() -> void:
	var line := P.beam(Vector2.ZERO,Vector2(10,0))
	for y in [2.999,3.0,3.001]: check(Rules.contains(line,Vector2(50,y),[])==(y<=3.0),"line halfwidth boundary "+str(y))
	check(Rules.contains(line,Vector2(100,0),[]) and not Rules.contains(line,Vector2(100.001,0),[]),"100 length boundary")
	check(not Rules.contains(line,Vector2(-0.01,0),[]),"no backward beam")
	for pulse in 4:
		var shape := {"kind":"circle" if pulse==0 else "donut","pos":[0,0],"inner":pulse*6.0,"radius":(pulse+1)*6.0}
		check(Rules.contains(shape,Vector2((pulse+1)*6.0,0),[]),"ring outer boundary inclusive "+str(pulse))
		check(not Rules.contains(shape,Vector2((pulse+1)*6.0+0.01,0),[]),"ring outer exterior "+str(pulse))
		if pulse>0:
			check(Rules.contains(shape,Vector2(pulse*6.0,0),[]),"ring inner boundary inclusive "+str(pulse))
			check(not Rules.contains(shape,Vector2(pulse*6.0-0.01,0),[]),"ring inner safe "+str(pulse))
	var route := P.route("elemental")
	var actors := actors_at(C.spread(route))
	var s := one_event({"kind":"protean","at":0.0,"repeat_at":4.74,"cycle":0,"origin":[0,0]},actors)
	check(s.runtime_failures.is_empty() and s.p4_wave.pending.size()==8,"eight actual baits")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(s))
	check(restored.p4_wave==JSON.parse_string(JSON.stringify(s.p4_wave)),"pending state JSON-native")
	var visual := {"shapes":[{"kind":"circle","radius":2.0,"name":"parent shape"}]}
	R.sync(visual,restored);R.sync(visual,restored)
	check(visual.shapes.size()==9 and visual.shapes[0].name=="parent shape","sync preserves parent shapes and is idempotent")
	check(visual.shapes.slice(1).all(func(shape):return shape.decorative and shape.p4_wave_preview),"preview does not double-judge hazards")
	check(restored.statuses.all(func(buffs):return buffs.is_empty()),"no guide-derived status grants")
	# Move into somebody else's OLD beam, while its owner goes elsewhere.
	var locked: Dictionary=restored.p4_wave.pending[0]
	actors[0].pos=Vector2(0,14); actors[1].pos=Rules.direction(float(locked.shape.angle))*14
	R.resolve(locked,actors,restored)
	check(1 in restored.dead,"old beam still kills after owner moves and JSON restore")
	for count in [3,4,5]:
		var pts: Array=[]
		for i in 8: pts.append(Vector2(-5,13) if i<count else Vector2(5,13))
		s=fresh();R.begin({"p4_wave_events":[],"p4_wave_duration":5.0},s);s.p4_wave.markers=[0,7]
		R.resolve({"kind":"stack","at":1.0,"origin":[0,0]},actors_at(pts),s)
		check(s.runtime_failures.is_empty()==(count==4),"stack exact4+4 "+str(count))
	var pts := C.stacks(route,[0,1],14)
	pts[0]=Vector2(-1,13);pts[1]=Vector2(1,13)
	s=fresh();R.begin({"p4_wave_events":[],"p4_wave_duration":5.0},s);s.p4_wave.markers=[0,1]
	R.resolve({"kind":"stack","at":1.0,"origin":[0,0]},actors_at(pts),s)
	check(not s.runtime_failures.is_empty(),"double clip rejected")
	# A line share accepts large longitudinal separation. A radius-six stack
	# implementation would incorrectly reject these two valid groups.
	pts=[]
	for i in 8: pts.append(Vector2(-4.0-float(i%4)*4.0,0) if i<4 else Vector2(4.0+float(i%4)*4.0,0))
	s=fresh();R.begin({"p4_wave_events":[],"p4_wave_duration":5.0},s);s.p4_wave.markers=[0,4]
	R.resolve({"kind":"stack","at":1.0,"origin":[0,0]},actors_at(pts),s)
	check(s.runtime_failures.is_empty(),"target-directed line share is not a radius-six circle")
	s=fresh();R.begin({"p4_wave_events":[],"p4_wave_duration":5.0},s);s.p4_wave.markers=[0,4];s.dead=[1]
	R.resolve({"kind":"stack","at":1.0,"origin":[0,0]},actors_at(pts),s)
	check(not s.runtime_failures.is_empty(),"dead actors cannot satisfy stacks")
	# Large frames interpolate at event time, not at the final position.
	s=fresh();R.begin({"p4_wave_events":[{"kind":"protean","at":0.5,"repeat_at":4.0,"cycle":0,"origin":[0,0]}],"p4_wave_duration":5.0},s)
	actors=actors_at(C.spread(route));var previous := actors.duplicate(true)
	for actor in actors: actor.pos+=Vector2(1,0)
	s.sim_time=1.0;R.tick(actors,previous,s,1.0)
	var expected := P.beam(Vector2.ZERO,Rules.v(previous[0].pos)+Vector2(0.5,0))
	check(absf(s.p4_wave.pending[0].shape.angle-expected.angle)<0.001,"interpolated lock")
	for speed in [6.0,7.5,11.0]:
		s=fresh();R.begin({"p4_wave_events":[],"p4_wave_duration":5.0},s)
		actors=actors_at(C.spread(route));previous=actors.duplicate(true)
		actors[0].pos+=Vector2(speed*0.1,0);s.sim_time=0.1
		if speed==7.5:s.motion_allowances=[0.75,0.6,0.6,0.6,0.6,0.6,0.6,0.6]
		if speed==11.0:s.motion_allowances=[1.1,1.1,1.1,1.1,1.1,1.1,1.1,1.1]
		R.tick(actors,previous,s,0.1)
		check(s.runtime_failures.is_empty()==(speed<=7.5),"motion budget "+str(speed))
	s=fresh();R.begin({"p4_wave_events":[],"p4_wave_duration":5.0},s)
	actors=actors_at(C.spread(route));actors[0].pos=Vector2(20,0);s.sim_time=0.1;R.tick(actors,actors,s,0.1)
	check(0 in s.dead,"deathwall inclusive")
	s=fresh();R.begin({"p4_wave_events":[{"kind":"markers","at":0.5,"targets":[0,1]}],"p4_wave_duration":5.0},s)
	s.sim_time=2.0;R.tick(actors,actors,s,0.1)
	check(str(s.runtime_failures).contains("missed event history"),"missed snapshots fail")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var started := Time.get_ticks_msec()
	var quick := "--quick" in OS.get_cmdline_user_args()
	negatives()
	var options := P.pairs()
	check(options.size()==28,"all target pairs")
	for profile in P.data().profiles:
		check(P.groups(profile,[0,6])==[[0,5,2,4],[1,7,3,6]],"same-left ranged swaps with D2")
		check(P.groups(profile,[1,3])==[[0,6,2,3],[1,7,4,5]],"same-right healer swaps with D1")
		for pair in options:
			var groups := P.groups(profile,pair)
			check(groups[0].size()==4 and groups[1].size()==4 and groups[0].count(pair[0])+groups[0].count(pair[1])==1,"swap matrix "+profile.id+str(pair))
		for family in (range(1) if quick else range(4)):
			for index in (range(0,28,7) if quick else range(28)):
				var pairs: Array=[options[index],options[(index+9)%28],options[(index+19)%28]]
				var course := make_course(profile.id,pairs,family)
				var state := simulate(course,0.05 if quick else 0.025)
				physical_cases+=1
				check(state.runtime_failures.is_empty(),"walk6 "+profile.id+" family "+str(family)+" pairs "+str(pairs)+" "+str(state.runtime_failures.slice(0,3)))
				check(state.p4_wave.pending.is_empty(),"full timeline exhausted")
				check(state.p4_wave.history.filter(func(e):return e.kind=="ring").size()==8,"two four-ring sequences")
				check(state.p4_wave.history.filter(func(e):return e.kind=="repeat").size()==24,"24 delayed old beams")
				if index==0:
					var replay := simulate(course,0.05 if quick else 0.025,true)
					check(JSON.parse_string(JSON.stringify(replay.p4_wave))==JSON.parse_string(JSON.stringify(state.p4_wave)),"deterministic JSON restore "+profile.id)
	var sweep_course := make_course("elemental",[[0,2],[1,7],[4,6]],0)
	for frame in [0.017,0.033,0.1,0.2]:
		var state := simulate(sweep_course,frame)
		check(state.runtime_failures.is_empty(),"time sweep "+str(frame)+" "+str(state.runtime_failures.slice(0,2)))
	var slow := simulate(sweep_course,0.05,false,1.0)
	check(not slow.runtime_failures.is_empty(),"normal movement failure is not suppressed")
	# Stop after the first lock, then resume into the old beams: a negative
	# physical trace rather than only an endpoint geometry assertion.
	var stopped := make_course("elemental",[[0,1],[2,3],[4,5]],0)
	for i in range(1,stopped.size()): stopped[i].positions=stopped[0].positions.duplicate()
	var stopped_state := simulate(stopped,0.05)
	check(stopped_state.dead.size()==8 and str(stopped_state.runtime_failures).contains("repeat"),"stationary old-position repeat wipes")
	print("P4_WAVE_GATE mode=", "quick" if quick else "full", " assertions=",assertions," failures=",failures," physical_cases=",physical_cases," elapsed_ms=",Time.get_ticks_msec()-started," max_observed_speed=",max_distance)
	quit(0 if failures==0 else 1)
