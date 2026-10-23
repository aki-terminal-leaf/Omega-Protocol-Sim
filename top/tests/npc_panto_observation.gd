# SPDX-License-Identifier: MIT
extends SceneTree
## Production-only integration gate: real bot_goal + tick, unchanged 6 u/s.
## --fast: 12 courses (all public selections/both signs, orientation 0).
## --full (default): 72 courses (all selections/six orientations/both signs).
## --out=PATH preserves one invocation's JSON evidence; --seed=N changes order.
const E = preload("res://scripts/encounters.gd")
const C = preload("res://scripts/p1_courses.gd")
const I = preload("res://scripts/interactions.gd")
const R = preload("res://scripts/rules.gd")
const O = preload("res://scripts/panto_observation.gd")
const Late = preload("res://scripts/late_damage_preview.gd")
var assertions:=0
var errors: Array=[]
var rows: Array=[]
var neutral_hash:=""
var sign_hashes: Dictionary={}

func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok:
		errors.append(message)
		if errors.size()<=12: print("PANTO OBSERVATION FAIL: ",message)

func argument(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.substr(prefix.length())
	return fallback

func fresh(origin:=0.0) -> Dictionary:
	return {"sim_time":origin,"dynamis":[0,0,0,0,0,0,0,0],"spent":[],"lb":"","aggro":0}

func build(profile: Dictionary, orientation: int, direction: int, variant: String, seed_value:=17391) -> Dictionary:
	var selected: Dictionary=profile.duplicate(true)
	selected.p1_orientation=orientation; selected.p1_direction=direction; selected.p1_panto_variant=variant
	return E.new().build("p1_panto",seed_value,selected)

func actors_at(beat: Dictionary) -> Array:
	var actors: Array=[]
	for actor in 8: actors.append({"pos":R.v(beat.spawn[actor]),"face":0.0,"role":E.ROLES[actor]})
	return actors

func goals(beat: Dictionary, actors: Array, state: Dictionary) -> Array:
	var result: Array=[]
	for actor in 8: result.append(I.bot_goal(actor,beat,actors,state))
	return result

func coordinates(points: Array) -> Array:
	return points.map(func(point):return [R.v(point).x,R.v(point).y])

func boundary_and_privacy(profile: Dictionary) -> void:
	var encounter:=build(profile,0,1,"inner_out_outer_return")
	var beat: Dictionary=encounter.beats[0].duplicate(true)
	var actors:=actors_at(beat)
	var original_actors: Array=actors.duplicate(true)
	var state:=fresh(91.25)
	I.begin(beat,actors,state)
	check(state.panto_observation.numbers.size()==8,"sync observes public Inline without bot_goal")
	var observed_numbers: Array=state.panto_observation.numbers.duplicate()
	var origin:=float(state.panto_observation.origin)
	for relative in [2.099,2.1,7.599,7.6]:
		state.sim_time=origin+relative
		var physical_before: Array=state.p1.pending.duplicate(true)
		I.sync(beat,state)
		var seen: Dictionary=state.panto_observation
		check((seen.axis!=null)==(relative>=2.1),"axis boundary %.3f"%relative)
		check((int(seen.direction)!=0)==(relative>=7.6),"sign boundary %.3f"%relative)
		var visible: Array=beat.shapes.filter(func(shape):return shape.get("p1_preview",false) and shape.get("kind","")=="cone" and Late.visible(shape,beat,state,relative,false))
		check((not visible.is_empty())==(relative>=2.1 and relative<=6.1 or relative>=7.6),"renderer agrees %.3f"%relative)
		check(state.p1.pending==physical_before,"observation never mutates physical event records")
		var expected: Array=goals(beat,actors,state)
		# Same displayed field and public statuses; ALL hidden oracle answers differ.
		var counter: Dictionary=beat.duplicate(true)
		counter.p1_path={"base":123456.0,"direction":-1,"numbers":[4,4,3,3,2,2,1,1],"groups":[1,1,1,1,1,1,1,1],"outer":true}
		check(goals(counter,actors,state)==expected,"hidden oracle counterfactual %.3f"%relative)
		var paused: Dictionary=state.panto_observation.duplicate(true)
		I.sync(beat,state)
		check(state.panto_observation==paused,"paused sync is idempotent %.3f"%relative)
		state=JSON.parse_string(JSON.stringify(state))
		I.sync(beat,state)
		check(goals(beat,actors,state)==expected,"JSON restore preserves goals %.3f"%relative)
	check(absf(float(state.panto_observation.axis_at)-2.1)<0.00001 and absf(float(state.panto_observation.direction_at)-7.6)<0.00001,"observation timestamps are origin-relative")
	var saved: Dictionary=state.panto_observation.duplicate(true)
	I.begin(encounter.beats[1].duplicate(true),actors,state)
	check(state.panto_observation==saved,"checkpoint begin preserves observation epoch")
	# Cached public numbers survive the actual runtime removal of all Inline icons.
	for actor in 8:
		for name in O.INLINE: state.statuses[actor].erase(name)
	I.sync(beat,state)
	check(state.panto_observation.numbers.map(func(n):return int(n))==observed_numbers.map(func(n):return int(n)),"number memory survives icon removal and JSON")
	check(actors==original_actors,"begin/sync/planning never move or mutate actors")
	state.sim_time=200.0
	var again: Dictionary=encounter.beats[0].duplicate(true)
	I.begin(again,actors,state)
	check(state.panto_observation.axis==null and int(state.panto_observation.direction)==0 and float(state.panto_observation.origin)==200.0,"fresh p1_events resets only the new Panto epoch")
	check(goals(again,actors,state)==range(8).map(func(actor):return O.neutral(actor)),"fresh epoch cannot reuse prior visible orientation")

func epsilon_boundaries(profile: Dictionary) -> void:
	var encounter:=build(profile,2,-1,"inner_out_outer_return")
	var raw: Dictionary=encounter.beats[0]
	var cones: Array=raw.p1_events.filter(func(event):return event.kind=="hazard" and event.shape.kind=="cone")
	var axis_boundary:=float(cones[0].at)-4.0
	var rotated: Array=cones.filter(func(event):return int(event.pulse)==1)
	var sign_boundary:=float(rotated[0].at)-Late.WINDOW_SECONDS
	for boundary in [axis_boundary,sign_boundary]:
		for delta in [-2.0*Late.EPSILON,-0.5*Late.EPSILON,0.0,2.0*Late.EPSILON]:
			var beat: Dictionary=raw.duplicate(true)
			var actors:=actors_at(beat); var state:=fresh(37.0)
			I.begin(beat,actors,state)
			if boundary==sign_boundary:
				state.sim_time=37.0+axis_boundary; I.sync(beat,state)
			state.sim_time=37.0+boundary+delta; I.sync(beat,state)
			var visible: Array=beat.shapes.filter(func(shape):return shape.get("p1_preview",false) and shape.get("kind","")=="cone" and Late.visible(shape,beat,state,boundary+delta,false))
			var seen: Dictionary=state.panto_observation
			if boundary==axis_boundary:
				check((seen.axis!=null)==(not visible.is_empty()),"axis exact renderer predicate at epsilon %.9f"%delta)
				check(int(seen.direction)==0,"opposite initial cones never reveal sign")
			else:
				var changed: bool=visible.any(func(shape):return absf(absf(wrapf(fposmod(float(shape.angle),180.0)-float(seen.axis),-90.0,90.0))-30.0)<0.001)
				check((int(seen.direction)!=0)==changed,"sign exact renderer predicate at epsilon %.9f"%delta)
			var memory: Dictionary=seen.duplicate(true)
			state=JSON.parse_string(JSON.stringify(state)); I.sync(beat,state)
			check(JSON.parse_string(JSON.stringify(state.panto_observation))==JSON.parse_string(JSON.stringify(memory)),"epsilon JSON persistence with JSON numeric types")

func skipped_tell_control(profile: Dictionary) -> void:
	for direction in [-1,1]:
		var encounter:=build(profile,0,direction,"inner_out_outer_return")
		var beat:Dictionary=encounter.beats[0].duplicate(true)
		var actors:=actors_at(beat);var state:=fresh();I.begin(beat,actors,state)
		state.sim_time=2.1;I.sync(beat,state)
		# Pulse5 has the opposite apparent modulo180 delta. It is NOT a
		# consecutive observed cone and must never authorize the wrong sign.
		state.sim_time=15.6;I.sync(beat,state)
		check(int(state.panto_observation.direction)==0,"skipped cone family cannot falsely invert sign")
		state=JSON.parse_string(JSON.stringify(state))
		state.sim_time=17.6;I.sync(beat,state)
		check(int(state.panto_observation.direction)==direction,"two subsequently observed consecutive cones recover actual sign")

func invalid_assignments(profile: Dictionary) -> void:
	var encounter:=build(profile,0,1,"inner_out_outer_return")
	for mode in ["missing","contradictory","unpaired","no_selection","bad_selection"]:
		var beat: Dictionary=encounter.beats[0].duplicate(true)
		if mode=="no_selection": beat.erase("panto_public")
		if mode=="bad_selection": beat.panto_public.profile_id="not_a_profile"
		var actors:=actors_at(beat)
		var state:=fresh()
		I.begin(beat,actors,state)
		# Simulate missing/bad public source before observation; never consult p1_path.
		state.panto_observation.numbers=[]; state.panto_observation.groups=[]
		for actor in 8:
			for name in O.INLINE: state.statuses[actor].erase(name)
		if mode in ["contradictory","unpaired"]:
			for actor in 8: state.statuses[actor].first_in_line={"expires":1000.0}
			if mode=="contradictory": state.statuses[0].second_in_line={"expires":1000.0}
		for relative in [2.1,7.6]:
			state.sim_time=relative; I.sync(beat,state)
			check(goals(beat,actors,state)==range(8).map(func(actor):return O.neutral(actor)),"fail-closed %s at %.1f"%[mode,relative])
	# A malformed serialized cache must not authorize route movement.
	var beat: Dictionary=encounter.beats[0].duplicate(true)
	var actors:=actors_at(beat); var state:=fresh(); I.begin(beat,actors,state)
	state.sim_time=2.1; I.sync(beat,state)
	state.panto_observation.numbers=[1,1,2,2,3,3,4,4.5]
	check(goals(beat,actors,state)==range(8).map(func(actor):return O.neutral(actor)),"non-integral JSON assignment fails closed")

func neutral_seed_counterfactuals(profiles: Array) -> void:
	for profile in profiles:
		for seed_value in [1,39,941,17391]:
			for variant in ["inner_out_outer_return","outer_out_inner_return"]:
				var encounter:=build(profile,seed_value%6,-1 if seed_value%2 else 1,variant,seed_value)
				var beat: Dictionary=encounter.beats[0].duplicate(true)
				var actors:=actors_at(beat); var state:=fresh(); I.begin(beat,actors,state)
				var neutral: Array=range(8).map(func(actor):return O.neutral(actor))
				check(actors.map(func(actor):return actor.pos)==neutral,"seed/profile/number/variant-independent actual spawn")
				state.sim_time=2.099; I.sync(beat,state)
				check(goals(beat,actors,state)==neutral,"pre-axis goals independent of public assignment permutation")

func native_failure_control(profile: Dictionary) -> void:
	var encounter:=build(profile,0,1,"inner_out_outer_return")
	var beat: Dictionary=encounter.beats[0].duplicate(true)
	var actors:=actors_at(beat); var state:=fresh(); I.begin(beat,actors,state)
	var previous: Array=actors.duplicate(true)
	actors[0].pos=R.v(actors[0].pos)+Vector2(2,0)
	I.tick(beat,actors,previous,state,0.1)
	check(str(state.runtime_failures).contains("movement exceeds"),"native speed-overrun failures propagate")

func course(profile: Dictionary, orientation: int, direction: int, variant: String, seed_value: int, facing:=0.0, step:=0.05) -> void:
	var selected: Dictionary=profile.duplicate(true); selected.p1_boss_facing=facing
	var encounter:=build(selected,orientation,direction,variant,seed_value)
	var actors:=actors_at(encounter.beats[0])
	var state:=fresh()
	var pre_axis: Array=[]; var pre_sign: Array=[]
	var local_errors: Array=[]
	var retained:=false
	var assignment: Array=[]
	for raw in encounter.beats:
		var beat: Dictionary=raw.duplicate(true)
		I.begin(beat,actors,state)
		if assignment.is_empty(): assignment=state.panto_observation.numbers.duplicate()
		var elapsed:=0.0
		while elapsed<float(beat.duration)-0.000001:
			var dt:=minf(step,float(beat.duration)-elapsed)
			var previous: Array=actors.duplicate(true)
			var targets:=goals(beat,actors,state)
			var seen: Dictionary=state.panto_observation
			var axis_hidden: bool=seen.axis==null
			var sign_hidden: bool=int(seen.direction)==0
			var trace: Array=[float(state.sim_time),coordinates(previous.map(func(actor):return actor.pos)),coordinates(targets)]
			state.motion_allowances=[]
			for actor in 8:
				actors[actor].pos=R.v(actors[actor].pos).move_toward(targets[actor],6.0*dt)
				state.motion_allowances.append(6.0*dt)
			I.tick(beat,actors,previous,state,dt); elapsed+=dt
			trace.append(coordinates(actors.map(func(actor):return actor.pos)))
			if axis_hidden: pre_axis.append(trace)
			if sign_hidden: pre_sign.append(trace)
			if not retained and float(state.sim_time)>=12.1:
				check(state.panto_observation.numbers==assignment,"actual first missile retains observed numbers")
				var first: Array=state.p1.history.filter(func(event):return event.kind=="missile_beam")
				check(first.size()==1 and first[0].missiles.all(func(actor):return not state.statuses[int(actor)].has("first_in_line")),"actual missile removed Inline1 icons")
				retained=true
		local_errors.append_array(R.evaluate(beat,actors,state))
		# State-only JSON restore at every real beat boundary, without restarting.
		state=JSON.parse_string(JSON.stringify(state))
	local_errors.append_array(state.runtime_failures)
	var history: Array=state.p1.history
	var counts: Dictionary={"hazards":history.filter(func(event):return event.kind=="hazard").size(),"baits":history.filter(func(event):return event.kind=="bait").size(),"missiles":history.filter(func(event):return event.kind=="missile_beam").size()}
	var label:="%s/%d/%d/%s/facing=%s/dt=%s/seed=%d"%[profile.id,orientation,direction,variant,facing,step,seed_value]
	check(local_errors.is_empty(),"6 u/s production physics "+label+": "+str(local_errors.slice(0,4)))
	check(counts=={"hazards":108,"baits":10,"missiles":4},"unchanged actual event counts "+label)
	check(float(state.panto_observation.axis_at)>=2.1-Late.EPSILON and float(state.panto_observation.axis_at)<2.1+step+0.00001 and float(state.panto_observation.direction_at)>=7.6-Late.EPSILON and float(state.panto_observation.direction_at)<7.6+step+0.00001,"actual tick visibility timestamps "+label)
	check(state.p1.pending.is_empty(),"all physical events resolved "+label)
	var axis_hash:=JSON.stringify(pre_axis).sha256_text()
	if neutral_hash=="": neutral_hash=axis_hash
	if step==0.05: check(axis_hash==neutral_hash,"pre-axis traces independent of all hidden fields "+label)
	var key:="%s/%d/%s/%s/%s/%d"%[profile.id,orientation,variant,facing,step,seed_value]
	var sign_hash:=JSON.stringify(pre_sign).sha256_text()
	if direction==-1: sign_hashes[key]=sign_hash
	else: check(sign_hashes.get(key,"")==sign_hash,"pre-sign physical traces independent of hidden sign "+label)
	rows.append({"case":label,"seed":seed_value,"facing":facing,"dt":step,"counts":counts,"errors":local_errors,"observed":state.panto_observation,"pre_axis_trace":{"sha256":axis_hash,"samples":pre_axis.size(),"first_time":pre_axis[0][0],"last_time":pre_axis[-1][0]},"pre_sign_trace":{"sha256":sign_hash,"samples":pre_sign.size(),"first_time":pre_sign[0][0],"last_time":pre_sign[-1][0]}})

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var profiles: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	boundary_and_privacy(profiles[0]); epsilon_boundaries(profiles[0]); skipped_tell_control(profiles[0]); invalid_assignments(profiles[0]); native_failure_control(profiles[0]); neutral_seed_counterfactuals(profiles)
	var fast: bool="--fast" in OS.get_cmdline_user_args()
	var seed_value:=int(argument("--seed=","17391"))
	for profile in profiles:
		var variants: Array=["inner_out_outer_return","outer_out_inner_return"] if profile.id=="cn_moogle" else [str(C.route(str(profile.id)).panto_variant)]
		for orientation in (1 if fast else 6):
			for variant in variants:
				for direction in [-1,1]: course(profile,orientation,direction,variant,seed_value)
	check(rows.size()==(12 if fast else 72),"complete requested matrix")
	# Optional robustness extension, separate from the exact 72-case baseline.
	if "--robust" in OS.get_cmdline_user_args():
		for profile in profiles:
			for direction in [-1,1]: course(profile,3,direction,str(C.route(str(profile.id)).panto_variant),941,30.0,0.037)
	var result: Dictionary={"assertions":assertions,"failures":errors.size(),"errors":errors,"courses":rows.size(),"cases":rows,"source_status":"original-game cue onset source_unknown; current simulator visibility only"}
	var out:=argument("--out=","")
	if out!="":
		var file=FileAccess.open(out,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(result,"  "))
		else: check(false,"cannot write requested evidence "+out)
	print("NPC PANTO OBSERVATION courses=%d assertions=%d failures=%d"%[rows.size(),assertions,errors.size()])
	quit(0 if errors.is_empty() else 1)
