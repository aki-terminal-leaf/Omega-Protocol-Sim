# SPDX-License-Identifier: MIT
extends SceneTree
## Prepared integration candidate: requires parent's Runtime.begin / I dispatch.
## This harness declares SynergySigns eligibility a SIMULATED display receipt.
## It is NOT Arena textured-Sprite3D, native-window, browser or OS evidence.
const E = preload("res://scripts/encounters.gd")
const C = preload("res://scripts/p1_courses.gd")
const I = preload("res://scripts/interactions.gd")
const R = preload("res://scripts/rules.gd")
const O = preload("res://scripts/cannons_observation.gd")
const Signs = preload("res://scripts/synergy_signs.gd")
var assertions: int=0
var errors: Array=[]
var rows: Array=[]

func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok:
		errors.append(message)
		if errors.size()<=15: print("CANNONS OBSERVATION FAIL: ",message)

func fresh(origin: float=0.0) -> Dictionary:
	return {"sim_time":origin,"dynamis":[0,0,0,0,0,0,0,0],"spent":[],"lb":"","aggro":0}

func build(profile: Dictionary, marked: Array, variant: String="static", split: bool=false) -> Dictionary:
	var selected: Dictionary=profile.duplicate(true)
	selected.p1_cannon_marked=marked.duplicate()
	selected.p1_cannon_variant=variant
	selected.p1_tank_variant="split_mitigated" if split else "north_together"
	return E.new().build("p1_cannons",42,selected)

func actors_at(beat: Dictionary) -> Array:
	var actors: Array=[]
	for actor in 8: actors.append({"pos":R.v(beat.spawn[actor]),"face":0.0,"role":E.ROLES[actor]})
	return actors

func goals(beat: Dictionary, actors: Array, state: Dictionary) -> Array:
	var points: Array=[]
	for actor in 8: points.append(I.bot_goal(actor,beat,actors,state))
	return points

func simulated_display(beat: Dictionary, state: Dictionary) -> Array:
	var displayed: Array=[]
	for actor in 8:
		if "cannon" in Signs.observed_all(actor,beat,state): displayed.append(actor)
	return displayed

func simulate(encounter: Dictionary, mode: String="normal") -> Dictionary:
	var actors: Array=actors_at(encounter.beats[0])
	var state: Dictionary=fresh()
	for raw in encounter.beats:
		var beat: Dictionary=raw.duplicate(true)
		I.begin(beat,actors,state)
		var elapsed: float=0.0
		while elapsed<float(beat.duration)-0.000001:
			var dt: float=minf(0.05,float(beat.duration)-elapsed)
			var previous: Array=actors.duplicate(true)
			O.publish(beat,state,[] if mode=="no_receipt" else simulated_display(beat,state))
			for actor in 8:
				var point: Vector2=I.bot_goal(actor,beat,actors,state)
				# An independent scripted human route, never silently rescued.
				if mode=="wrong_human" and actor==0: point=O.neutral(0)
				if mode=="clip_human" and actor==7: point=I.bot_goal(2,beat,actors,state)
				if mode=="farthest_human" and actor==7 and float(state.sim_time)>=6.1: point=R.direction(164)*19
				actors[actor].pos=R.v(actors[actor].pos).move_toward(point,6.0*dt)
				if mode=="overrun" and actor==0 and float(state.sim_time)<0.01: actors[actor].pos=R.v(previous[actor].pos)+Vector2(0.5,0)
			I.tick(beat,actors,previous,state,dt)
			elapsed+=dt
		state.runtime_failures.append_array(R.evaluate(beat,actors,state))
		# Full state JSON between every beat, including IDs restored as floats.
		state=JSON.parse_string(JSON.stringify(state))
	state["test_actor_positions"]=actors.map(func(a):return [R.v(a.pos).x,R.v(a.pos).y])
	return state

func privacy_and_memory(profile: Dictionary) -> void:
	var encounter: Dictionary=build(profile,[2,3,4],"dynamic")
	var beat: Dictionary=encounter.beats[0].duplicate(true)
	var actors: Array=actors_at(beat)
	var state: Dictionary=fresh(37.0)
	I.begin(beat,actors,state)
	check(state.has(O.KEY),"parent fresh begin seam installed")
	if not state.has(O.KEY): return
	var actor_copy: Array=actors.duplicate(true)
	var physical: Array=state.p1.pending.duplicate(true)
	var prior: Array=goals(beat,actors,state)
	check(prior.slice(2)==range(2,8).map(func(a):return O.neutral(a)),"dynamic holds neutral before actual receipt")
	var poisoned: Dictionary=beat.duplicate(true)
	poisoned.positions=C.repeated(Vector2(123,-456))
	poisoned.labels=["secret","secret","secret","secret","secret","secret","secret","secret"]
	poisoned.p1_events=[{"kind":"proteans","at":6.0,"targets":[5,6,7]},{"kind":"proteans","at":15.0,"targets":[2,3,4]}]
	var poison_state: Dictionary=state.duplicate(true)
	poison_state.p1.pending=poisoned.p1_events.duplicate(true)
	poison_state.order=[7,6,5,4,3,2,1,0]
	check(goals(poisoned,actors,poison_state)==prior,"hidden positions/labels/order/both targets cannot change pre-receipt goals")
	O.publish(beat,state,[4.0,2.0,3.0])
	check(O.trio(state[O.KEY].first_ids)==[2,3,4] and state[O.KEY].first_at==37.0,"first actual receipt normalizes finite integral JSON IDs and records actual time")
	var state_before_goals: String=JSON.stringify(state)
	var expected: Array=goals(beat,actors,state)
	check(JSON.stringify(state)==state_before_goals,"goal is pure, including observation and statuses")
	poison_state[O.KEY]=state[O.KEY].duplicate(true)
	check(goals(poisoned,actors,poison_state)==expected,"hidden poison cannot change observed route")
	check(actors==actor_copy and state.p1.pending==physical,"publication/goals never mutate actors or physical events")
	state=JSON.parse_string(JSON.stringify(state))
	check(goals(beat,actors,state)==expected,"JSON observed route roundtrip")
	state.sim_time=43.0
	var recovery: Dictionary=encounter.beats[1].duplicate(true)
	I.begin(recovery,actors,state)
	O.publish(recovery,state,[])
	check(goals(recovery,actors,state).slice(2)==C.repeated(R.direction(180)*7).slice(2),"public recovery independent of partition")
	var second: Dictionary=encounter.beats[2].duplicate(true)
	state.sim_time=44.8
	I.begin(second,actors,state)
	O.publish(second,state,[])
	var inferred: Array=goals(second,actors,state)
	var context: Dictionary={"profile":{"id":"aether"}}
	check(inferred==C.cannon_goals(context,[5,6,7],true),"observed-first complement works in 7.8..9.9 empty-head gap")
	var poisoned_second: Dictionary=second.duplicate(true)
	poisoned_second.positions=C.repeated(Vector2(-99,88))
	var second_state: Dictionary=state.duplicate(true)
	second_state.p1.pending=[{"kind":"proteans","at":52.0,"targets":[2,3,4]}]
	check(goals(poisoned_second,actors,second_state)==inferred,"observed complement cannot read poisoned hidden second targets/endpoints")
	check(state[O.KEY].second_ids.is_empty() and str(state[O.KEY].complement_basis).contains("observed_first_trio"),"inferred second has explicit provenance, not fabricated receipt")
	state.sim_time=46.9
	O.publish(second,state,[7,6,5])
	check(goals(second,actors,state)==inferred and state[O.KEY].second_at==46.9,"actual second receipt agrees with complement and records actual time")
	var saved: Dictionary=state[O.KEY].duplicate(true)
	O.publish(second,state,[5,6,7])
	check(state[O.KEY]==saved,"paused repeated receipt is idempotent")
	state.sim_time=100.0
	I.begin(beat,actors,state)
	check(state[O.KEY].first_ids.is_empty() and state[O.KEY].origin==100.0,"fresh retry clears prior epoch")
	check(goals(beat,actors,state)==prior,"fresh retry cannot reuse old marks")
	# Entirely missing first observation may use a valid ACTUAL second receipt.
	state.sim_time=109.9
	O.publish(second,state,[5,6,7])
	check(goals(second,actors,state)==inferred,"actual second independent of missing first")

func invalid_and_static(profile: Dictionary) -> void:
	var encounter: Dictionary=build(profile,[2,3,4],"dynamic")
	var beat: Dictionary=encounter.beats[0]
	var actors: Array=actors_at(beat)
	for receipt in [[],[2],[2,3],[2,2,3],[0,3,4],[2,3,8],[2.5,3,4],["2",3,4],[true,3,4],[NAN,3,4],[INF,3,4]]:
		var state: Dictionary=fresh()
		I.begin(beat.duplicate(true),actors,state)
		O.publish(beat,state,receipt)
		check(goals(beat,actors,state).slice(2)==range(2,8).map(func(a):return O.neutral(a)),"invalid/missing receipt fail closed: "+str(receipt))
		check(I.bot_goal(0,beat,actors,state)==R.direction(355)*17,"tank public anchor requires no receipt")
	for corruption in ["contradiction","partial_after_valid","bad_cache","future_time","overlap_second"]:
		var state: Dictionary=fresh()
		I.begin(beat.duplicate(true),actors,state)
		O.publish(beat,state,[2,3,4])
		if corruption=="contradiction": O.publish(beat,state,[2,3,5])
		if corruption=="partial_after_valid": O.publish(beat,state,[2,3])
		if corruption=="bad_cache": state[O.KEY].first_ids=[2,2,4]
		if corruption=="future_time": state[O.KEY].first_at=999.0
		var current: Dictionary=beat
		if corruption=="overlap_second":
			current=encounter.beats[2]
			state.sim_time=9.9
			O.publish(current,state,[2,5,6])
		check(goals(current,actors,state).slice(2)==range(2,8).map(func(a):return O.neutral(a)),"invalid cache/contradictory receipt has no hidden fallback: "+corruption)
	# Static roles remain public even if observation is absent/invalid.
	var fixed: Dictionary=build(profile,[2,3,4],"static").beats[0]
	var fixed_state: Dictionary=fresh()
	I.begin(fixed.duplicate(true),actors,fixed_state)
	var fixed_goals: Array=goals(fixed,actors,fixed_state)
	O.publish(fixed,fixed_state,[2,2,4])
	check(goals(fixed,actors,fixed_state)==fixed_goals,"static public role goals invariant to invalid marks")

func run() -> void:
	var profiles: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var aether: Dictionary=profiles.filter(func(p):return p.id=="aether")[0]
	privacy_and_memory(aether)
	invalid_and_static(aether)
	var families: Array=[{"id":"aether","variant":"dynamic","split":false},{"id":"aether","variant":"static","split":false},{"id":"lpdu","variant":"static","split":false},{"id":"lpdu","variant":"static","split":true},{"id":"elemental","variant":"static","split":false},{"id":"cn_moogle","variant":"static","split":false},{"id":"kr_09stop","variant":"static","split":false}]
	for family in families:
		var profile: Dictionary=profiles.filter(func(p):return p.id==family.id)[0]
		for a in range(2,6):
			for b in range(a+1,7):
				for c in range(b+1,8):
					var marked: Array=[a,b,c]
					var encounter: Dictionary=build(profile,marked,str(family.variant),bool(family.split))
					check(encounter.beats[0].spawn==range(8).map(func(i):return O.neutral(i)),"public neutral spawn independent of subset/profile/variant")
					check(encounter.beats.size()==3 and encounter.beats.all(func(beat):return beat.has("cannons_public") and beat.cannons_public.source_onset=="source_unknown"),"all three beats carry source-honest public descriptor")
					var state: Dictionary=simulate(encounter)
					var cleaves: Array=state.p1.history.filter(func(e):return e.kind=="cleaves")
					var proteans: Array=state.p1.history.filter(func(e):return e.kind=="proteans")
					var label: String="%s/%s/split=%s/%s"%[family.id,family.variant,family.split,str(marked)]
					check(state.runtime_failures.is_empty(),"moving course "+label+": "+str(state.runtime_failures.slice(0,4)))
					check(cleaves.size()==5 and proteans.size()==2 and state.p1.pending.is_empty() and absf(float(state.sim_time)-15.1)<0.00001,"five live farthest cleaves/two proteans/no pending at15.1: "+label)
					rows.append({"family":family,"marked":marked,"failures":state.runtime_failures,"cleaves":cleaves.size(),"proteans":proteans.size(),"observation":state.get(O.KEY,{})})
	check(rows.size()==140,"seven offered families times twenty subsets")
	var fixed: Dictionary=build(aether,[2,3,4],"static")
	for mode in ["wrong_human","clip_human","farthest_human","overrun"]:
		var state: Dictionary=simulate(fixed,mode)
		check(not state.runtime_failures.is_empty(),"real route/speed failure judged: "+mode)
		if mode=="farthest_human":
			var pulses: Array=state.p1.history.filter(func(e):return e.kind=="cleaves")
			check(pulses.size()==5 and 7 in pulses[1].targets.map(func(value):return int(value)) and 7 in pulses[3].targets.map(func(value):return int(value)),"actual farthest non-tank retargets second AND later pulse")
		if mode=="overrun": check(str(state.runtime_failures).contains("budget"),"negative overrun is actual runtime speed rejection")
	var missing: Dictionary=simulate(build(aether,[2,3,4],"dynamic"),"no_receipt")
	check(not missing.runtime_failures.is_empty(),"dynamic no-render receipt remains an honest judged failure")
	var report: Dictionary={"assertions":assertions,"errors":errors,"courses":rows,"receipt_evidence":"DECLARED simulated display from SynergySigns eligibility; NOT Arena/native/Web/OS proof","dt":0.05,"speed":6.0,"source_onset":"source_unknown"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			var output: FileAccess=FileAccess.open(arg.substr(6),FileAccess.WRITE)
			if output!=null: output.store_string(JSON.stringify(report,"  ")+"\n")
	print("Cannons observation: %d assertions, %d errors, %d moving courses; simulated receipts only"%[assertions,errors.size(),rows.size()])
	quit(1 if not errors.is_empty() else 0)

func _initialize() -> void:
	call_deferred("run")
