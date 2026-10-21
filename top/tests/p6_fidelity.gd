extends SceneTree
const P = preload("res://scripts/p6_patterns.gd")
const C = preload("res://scripts/p6_courses.gd")
const Runtime = preload("res://scripts/p6_runtime.gd")
const Contact = preload("res://scripts/interactions.gd")
const Status = preload("res://scripts/statuses.gd")
const Rules = preload("res://scripts/rules.gd")
const Encounter = preload("res://scripts/encounters.gd")
var assertions := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok: failures+=1; print("P6 FAIL: ",message)
func actors_at(points: Array) -> Array:
	var actors: Array=[]
	for i in 8: actors.append({"role":Encounter.ROLES[i],"pos":points[i],"face":0.0})
	return actors
func fresh() -> Dictionary:
	var state := {"sim_time":0.0}
	Status.ensure(state)
	return state
func beat(events: Array, duration := 40.0) -> Dictionary:
	return {"duration":duration,"p6_duration":duration,"p6_events":events,"shapes":[],"positions":C.repeated(Vector2.ZERO)}
func step(b: Dictionary, actors: Array, state: Dictionary, goals: Array, dt: float) -> void:
	var previous := actors.duplicate(true)
	for i in 8: actors[i].pos=Rules.v(actors[i].pos).move_toward(Rules.v(goals[i]),6.0*dt)
	Contact.tick(b,actors,previous,state,dt)
func simulate(beats: Array, frame := 0.025, json_checkpoints := false) -> Dictionary:
	var actors := actors_at(C.repeated(Vector2.ZERO)); var state := fresh()
	for b in beats:
		Contact.begin(b,actors,state)
		var elapsed := 0.0
		while elapsed<float(b.duration)-0.000001:
			var dt := minf(frame,float(b.duration)-elapsed)
			step(b,actors,state,b.positions,dt); elapsed+=dt
		var endpoint := Rules.evaluate(b,actors,state)
		if not endpoint.is_empty(): state.runtime_failures.append_array(endpoint)
		if json_checkpoints: state=JSON.parse_string(JSON.stringify(state))
	return state
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for center in [false,true]:
		var events := P.arrow(center)
		check(events.size()==42,"Arrow actual hazard count 42")
		check(events.all(func(e):return e.kind=="hazard"),"Every Arrow cast is geometric")
		check(is_equal_approx(float(events[-1].at),22.0 if center else 20.0),"Arrow family last time")
		check(events.filter(func(e):return e.at==8.0).size()==(2 if center else 4),"First source group size")
		check(events.filter(func(e):return e.at==10.0 and e.pulse==0).size()==(4 if center else 2),"Other source group delayed 2s")
		var overlap: Array=events.filter(func(e):return e.at==10.0)
		check(overlap.any(func(e):return e.group=="central") and overlap.any(func(e):return e.group=="side"),"Both Arrow groups overlap")
		var boundary := P.strip(0,0,Vector2.ZERO,10,"central",0)
		check(Rules.contains(boundary.shape,Vector2(5,0),[]),"Arrow boundary is unsafe")
		check(not Rules.contains(boundary.shape,Vector2(5.01,0),[]),"Arrow exterior is safe")
		if center:
			check(overlap.any(func(e):return e.group=="side" and Rules.contains(e.shape,Vector2(12,3),[])),"Wrong old single-group route misses delayed side strip")
			check(overlap.any(func(e):return e.group=="central" and Rules.contains(e.shape,Vector2(6,3),[])),"Concurrent central moving strip remains dangerous")
	var visual_state := fresh(); var visual_actors := actors_at(C.repeated(Vector2.ZERO))
	var visual_beat := beat(P.arrow(true))
	Contact.begin(visual_beat,visual_actors,visual_state)
	check(visual_beat.shapes.size()==2,"Only first two central telegraphs visible at T0")
	Contact.tick(visual_beat,visual_actors,visual_actors.duplicate(true),visual_state,2.0)
	check(visual_beat.shapes.size()==6,"Four side telegraphs appear at T2, not at T0")
	for start in 8:
		for direction in [-1,1]:
			var events := P.exaflares(start,direction)
			var sources: Array=events.filter(func(e):return e.kind=="hazard" and e.pulse==0)
			check(sources.size()==4 and events.filter(func(e):return e.kind=="hazard").size()==28,"16-family exa count")
			for i in 4:
				check(Rules.v(sources[i].shape.pos).distance_to(Rules.direction((start+direction*i)*45)*24)<0.001,"Adjacent 45-degree radius-24 origin")
				check(float(sources[i].at)==12+i,"Staggered 12-second sources")
			check(events.filter(func(e):return e.kind=="bait").size()==6,"Six actual eight-player baits")
			check(events.any(func(e):return e.kind=="hazard" and e.line==0 and e.pulse==1 and absf(e.at-13.11)<0.001),"Measured first advance")
			for offset in [45.0,67.5]:
				var ctx=Encounter.new(); ctx.positions=C.repeated(Vector2.ZERO); ctx.labels=["","","","","","","",""]
				var times: Array=[]; var goals: Array=[]
				for point in P.exa_waypoints(start,direction,offset): times.append(point.at); goals.append(C.repeated(Rules.v(point.pos)))
				times.append(23.1); goals.append(goals[-1])
				C.append(ctx,"Exa proof",events,times,goals,P.route("elemental"),{})
				var state := simulate(ctx.beats)
				check(state.runtime_failures.is_empty(),"Exa 6/s family %d dir %d offset %.1f: %s" % [start,direction,offset,str(state.runtime_failures.slice(0,2))])
				check(state.p6.history.filter(func(e):return e.kind=="hazard").size()==76,"28 exas plus 48 actual bait explosions")
	var actors := actors_at(C.repeated(Vector2.ZERO)); var state := fresh()
	var b := beat([{"at":1.0,"kind":"bait","delay":3.0,"radius":6.0}])
	Contact.begin(b,actors,state)
	var previous := actors.duplicate(true)
	for actor in actors: actor.pos=Vector2(10,0)
	Contact.tick(b,actors,previous,state,2.0)
	check(state.p6.pending.size()==8,"Stacked actors still produce eight puddles")
	check(Rules.v(state.p6.pending[0].shape.pos)==Vector2(5,0),"Bait locks interpolated actual position, not future goal")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(state))
	check(restored.p6==JSON.parse_string(JSON.stringify(state.p6)),"Pending state JSON round trip")
	var next := {"duration":3.0,"shapes":[],"positions":C.repeated(Vector2(5,0))}
	Contact.begin(next,actors,restored)
	step(next,actors,restored,C.repeated(Vector2(5,0)),2.0)
	check(restored.dead.size()==8 and not restored.runtime_failures.is_empty(),"Old puddle fatal after beat change and JSON restore")
	state=fresh(); actors=actors_at(C.repeated(Vector2.ZERO)); b=beat([{"at":1.0,"kind":"bait","delay":3.0,"radius":6.0}]); Contact.begin(b,actors,state)
	state.sim_time=5.0; Runtime.tick(actors,actors,state,0.1)
	check(str(state.runtime_failures).contains("missed event history"),"Late processing cannot silently use current bait position")
	state=fresh(); b=beat([]); Contact.begin(b,actors,state); previous=actors.duplicate(true); actors[0].pos=Vector2(10,0); Contact.tick(b,actors,previous,state,0.1)
	check(not state.runtime_failures.is_empty() and 0 in state.dead,"Teleport cannot finish a course")
	state=fresh();actors=actors_at(C.repeated(Vector2.ZERO));Contact.begin(b,actors,state)
	state.motion_allowances=[0.75,0.6,0.6,0.6,0.6,0.6,0.6,0.6]
	previous=actors.duplicate(true);actors[0].pos=Vector2(0.75,0);Contact.tick(b,actors,previous,state,0.1)
	check(state.runtime_failures.is_empty(),"Authorized7.5/s Sprint does not fail the6/s walking guard")
	previous=actors.duplicate(true);actors[0].pos=Vector2(10,0);Contact.tick(b,actors,previous,state,0.1)
	check(not state.runtime_failures.is_empty(),"Authorized Sprint budget still rejects teleportation")
	actors=actors_at(C.charge_goals(90)); actors[2].pos=Vector2(12,0); actors[3].pos=Vector2(12,3.9)
	check(3 in Rules.hits(P.beam(2),actors),"8-wide beam clips at 3.9 off axis")
	actors=actors_at(C.charge_goals(90)); state=fresh(); b=beat([{"at":0.1,"kind":"charge","target":7}]); Contact.begin(b,actors,state); step(b,actors,state,C.charge_goals(90),0.1)
	check(state.runtime_failures.is_empty(),"Actual-target charge with both front tanks")
	actors[7].pos=Vector2(0,-10); state=fresh(); Contact.begin(b,actors,state); Contact.tick(b,actors,actors.duplicate(true),state,0.1)
	check(not state.runtime_failures.is_empty(),"Turning actual charge target breaks fixed east stack")
	actors=actors_at(C.dive_goals(180)); state=fresh(); b=beat([{"at":0.1,"kind":"dive"}]); Contact.begin(b,actors,state); Contact.tick(b,actors,actors.duplicate(true),state,0.1)
	check(state.runtime_failures.is_empty(),"Dive legal separated nearest tanks and farthest party")
	actors[0].pos=Vector2(-4,-4); actors[1].pos=Vector2(4,-4); state=fresh(); Contact.begin(b,actors,state); Contact.tick(b,actors,actors.duplicate(true),state,0.1)
	check(str(state.runtime_failures).contains("radius-8 overlap"),"Old +/-4 tank boundary fails")
	actors[2].pos=Vector2.ZERO; state=fresh(); Contact.begin(b,actors,state); Contact.tick(b,actors,actors.duplicate(true),state,0.1)
	check(str(state.runtime_failures).contains("closest two"),"Dive targets actual closest, not role label")
	actors=actors_at(C.dive_goals(180)); actors[2].pos=Vector2(6.01,13); state=fresh(); Contact.begin(b,actors,state); Contact.tick(b,actors,actors.duplicate(true),state,0.1)
	check(str(state.runtime_failures).contains("radius-6 party stack"),"Dive stack rejects 6.01 separation from actual farthest")
	state=fresh(); actors=actors_at(C.repeated(Vector2.ZERO)); b=beat([{"at":0.5,"kind":"lock","actor":6,"duration":2.0}]); Contact.begin(b,actors,state); previous=actors.duplicate(true); actors[6].pos=Vector2(1,0); Contact.tick(b,actors,previous,state,1.0)
	check(str(state.runtime_failures).contains("animation lock"),"Lock beginning inside large tick cannot be skipped")
	check(P.flare_combinations().size()==56,"All 56 three-flare combinations")
	for flares in P.flare_combinations():
		var goals := P.flare_goals(flares)
		check(goals[6]==Vector2(0,-16),"D3 stays north in every flare branch")
		var nonflares: Array=[]
		for actor in 8:
			if actor not in flares: nonflares.append(actor)
		state=fresh(); actors=actors_at(goals); b=beat([{"at":0.1,"kind":"flares","targets":flares,"stack_target":nonflares[0]}]); Contact.begin(b,actors,state); Contact.tick(b,actors,actors.duplicate(true),state,0.1)
		check(state.runtime_failures.is_empty() and state.p6.history[-1].falloff=="unmodeled","Meteor stack branches, no fabricated damage immunity")
	check(P.route("elemental").stack_angle==90 and P.route("aether").stack_angle==180,"Verified E/S difference")
	check(P.route("lpdu").meteor_clocks[1]==180 and P.route("cn_moogle").meteor_clocks[1]==90,"LPDU H2/ST swap is absent in CN")
	check(P.route("cn_moogle").exit_offset==null and P.route("cn_moogle").stack_angle==null,"Missing CN route facts stay unknown")
	var kr_flares := P.flare_goals([0,2,6],"kr_09stop")
	check(is_equal_approx(kr_flares[0].length(),16.0) and is_equal_approx(kr_flares[2].length(),18.0),"KR retains melee/outer flare distinction")
	check(kr_flares[6]==Vector2(0,-18),"KR outer ranged position remains fixed through flare branch")
	# Exhaust spatial families with both followups independently of RNG samples.
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		for start in 8:
			for direction in [-1,1]:
				for dive in [false,true]:
					var ctx=Encounter.new(); ctx.profile={"id":id}; ctx.rng.seed=17; ctx.positions=C.repeated(Vector2.ZERO); ctx.labels=["","","","","","","",""]
					C.append_exaflare_family(ctx,dive,start,direction)
					state=simulate(ctx.beats,0.1)
					check(state.runtime_failures.is_empty(),"Full exa family %s %d/%d dive=%s: %s" % [id,start,direction,str(dive),str(state.runtime_failures.slice(0,2))])
		for center in [false,true]:
			for waves in [false,true]:
				var ctx=Encounter.new(); ctx.profile={"id":id}; ctx.rng.seed=17; ctx.positions=C.repeated(Vector2.ZERO); ctx.labels=["","","","","","","",""]
				C.append_arrow_family(ctx,waves,center)
				state=simulate(ctx.beats)
				check(state.runtime_failures.is_empty(),"Full arrow family %s center=%s waves=%s: %s" % [id,str(center),str(waves),str(state.runtime_failures.slice(0,2))])
		for flares in P.flare_combinations():
			var ctx=Encounter.new(); ctx.profile={"id":id}; ctx.rng.seed=17; ctx.positions=C.repeated(Vector2.ZERO); ctx.labels=["","","","","","","",""]
			C.append_meteor_combination(ctx,flares)
			state=simulate(ctx.beats,0.1)
			check(state.runtime_failures.is_empty(),"Full meteor %s flares %s: %s" % [id,str(flares),str(state.runtime_failures.slice(0,2))])
			check(state.p6.history.filter(func(e):return e.kind=="lock").size()==2,"Caster and ranged cast locks are in actual course")
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		for seed_value in range(1,5):
			for kind in ["arrow_wave","arrow_dive","exa_wave","exa_dive","meteors"]:
				var ctx=Encounter.new(); ctx.profile={"id":id}; ctx.rng.seed=seed_value; ctx.positions=C.repeated(Vector2.ZERO); ctx.labels=["","","","","","","",""]
				if kind.begins_with("arrow"): C.append_arrow(ctx,kind.ends_with("wave"))
				elif kind.begins_with("exa"): C.append_exaflares(ctx,kind.ends_with("dive"))
				else: C.append_meteors(ctx)
				state=simulate(ctx.beats,0.025,true)
				check(state.runtime_failures.is_empty(),"Combined course %s %s seed %d at 6/s: %s" % [id,kind,seed_value,str(state.runtime_failures.slice(0,3))])
				check(state.p6.pending.is_empty(),"Combined course does not skip remaining overlap")
	print("P6 FIDELITY assertions=",assertions," failures=",failures)
	quit(1 if failures else 0)
