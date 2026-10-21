extends SceneTree
const P = preload("res://scripts/hw_patterns.gd")
const C = preload("res://scripts/hw_courses.gd")
const HW = preload("res://scripts/hw_runtime.gd")
const S = preload("res://scripts/statuses.gd")
const I = preload("res://scripts/interactions.gd")
const E = preload("res://scripts/encounters.gd")
const R = preload("res://scripts/rules.gd")
var assertions := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok: failures+=1; print("HW FAIL: ",message)
func fresh() -> Dictionary:
	var state := {"sim_time":0.0}; S.ensure(state); return state
func actors_at(points: Array) -> Array:
	var result: Array=[]
	for i in 8: result.append({"role":E.ROLES[i],"pos":R.v(points[i]),"face":0.0})
	return result
func course(id: String, angles: Array, colour: String, assignment: Array=[]):
	var ctx=E.new(); ctx.order=range(8) if assignment.is_empty() else assignment.duplicate(); ctx.profile={"id":id}; ctx.positions=[]; ctx.labels=[]
	for i in 8: ctx.positions.append(R.direction(i*45)*5); ctx.labels.append("")
	C.append_family(ctx,angles,colour)
	return ctx
func simulate(ctx, restore := false, frame := 0.05, checkpoint := 23.5) -> Dictionary:
	var points: Array=[]
	for i in 8: points.append(R.direction(i*45)*5)
	var actors := actors_at(points); var state := fresh(); var checkpointed := false
	for b in ctx.beats:
		I.begin(b,actors,state)
		var elapsed := 0.0
		while elapsed<float(b.duration)-0.000001:
			var dt := minf(frame,float(b.duration)-elapsed)
			var previous := actors.duplicate(true)
			for i in 8: actors[i].pos=R.v(actors[i].pos).move_toward(I.bot_goal(i,b,actors,state),6.0*dt)
			I.tick(b,actors,previous,state,dt); elapsed+=dt
			if restore and not checkpointed and float(state.sim_time)>checkpoint:
				state=JSON.parse_string(JSON.stringify(state)); checkpointed=true
	return state
func _initialize() -> void: call_deferred("run")
func native_json(value) -> bool:
	if value is Array:
		return value.all(func(x):return native_json(x))
	if value is Dictionary:
		return value.values().all(func(x):return native_json(x))
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME]
func fixture() -> Dictionary:
	var state := fresh()
	HW.begin({"hw_events":[],"hw_duration":150.0},state)
	return state
func separated() -> Array:
	var p: Array=[]
	for i in 8: p.append(Vector2(i*50.0,0))
	return actors_at(p)
func advance(actors: Array, state: Dictionary, dt: float) -> void:
	state.sim_time=float(state.sim_time)+dt
	HW.tick(actors,actors.duplicate(true),state,dt)
func negative_tests() -> void:
	# Exhaust every directed actor edge, both colours, and all combinations
	# of the recipient's two Debuggers. No recipient is selected by a route.
	for a in 8:
		for b in 8:
			if a==b: continue
			for colour in ["red","blue"]:
				for mask in 4:
					for prior in ["","red","blue"]:
						# A live rot and its own earned Debugger cannot coexist.
						if (prior=="red" and mask&1) or (prior=="blue" and mask&2): continue
						for reverse_immune in [false,true]:
							var actors := separated(); actors[b].pos=actors[a].pos+Vector2(0.5,0)
							var state := fixture()
							var opposite := "blue" if colour=="red" else "red"
							S.give(state,a,colour,27.0)
							if reverse_immune: S.give(state,a,opposite+"_debugger",9999)
							if prior!="": S.give(state,b,prior,27)
							if mask&1: S.give(state,b,"red_debugger",9999.0)
							if mask&2: S.give(state,b,"blue_debugger",9999.0)
							S.contacts(actors,actors.duplicate(true),state)
							var blocked: bool=bool(mask&(1 if colour=="red" else 2))
							var ambiguous: bool=prior==opposite and not blocked and not reverse_immune
							var expected: String=prior if blocked or ambiguous else colour
							check((state.statuses[b].has(expected) if expected!="" else not state.statuses[b].has(colour)) and (not state.runtime_failures.is_empty())==ambiguous,"reachable contact state %d/%d/%s/%d/%s/%s" % [a,b,colour,mask,prior,str(reverse_immune)])
	for colour in ["red","blue"]:
		var other := "blue" if colour=="red" else "red"
		var actors := separated(); actors[1].pos=Vector2(0.5,0)
		var state := fixture(); S.give(state,0,colour,27); S.give(state,0,other+"_debugger",9999); S.give(state,1,other,27)
		S.contacts(actors,actors.duplicate(true),state)
		check(state.statuses[1].has(colour) and not state.statuses[1].has(other),"opposite infection genuinely overwrites without route selection")
		state=fixture(); S.give(state,0,colour,27); S.give(state,1,other,27)
		S.contacts(actors,actors.duplicate(true),state)
		check(not state.runtime_failures.is_empty() and state.statuses[0].has(colour) and state.statuses[1].has(other),"simultaneous opposite carriers remain explicitly ambiguous")
	var actors := separated(); var state := fixture()
	S.give(state,0,"red",27); actors[0].pos=Vector2(-2,0); actors[1].pos=Vector2.ZERO
	var previous := actors.duplicate(true); actors[0].pos=Vector2(2,0); state.sim_time=1.0
	HW.tick(actors,previous,state,1.0)
	check(state.statuses[1].has("red"),"accidental swept pass infects despite separated endpoints")
	check(float(state.statuses[1].red.expires)>27 and float(state.statuses[1].red.expires)<28,"swept contact gets real acquisition clock")
	actors=separated(); state=fixture(); S.give(state,0,"red",0.1); actors[0].pos=Vector2(-2,0); actors[1].pos=Vector2.ZERO
	previous=actors.duplicate(true); actors[0].pos=Vector2(2,0); state.sim_time=1.0
	HW.tick(actors,previous,state,1.0)
	check(not state.statuses[1].has("red"),"expiry before crossing cannot transmit late")
	actors=separated(); state=fixture(); S.give(state,0,"sync",0.1); advance(actors,state,0.2)
	check(state.runtime_failures.any(func(s):return "unshared Synchronization" in s),"incorrect Sync count judged by actual blast")
	actors=separated(); state=fixture(); S.give(state,0,"latent_sync",69.0); advance(actors,state,69.1)
	check(state.runtime_failures.any(func(s):return "latent_sync expired" in s),"latent Sync genuinely expires at69")
	actors=separated(); state=fixture(); S.give(state,0,"latent_red",10.0); S.give(state,0,"red",10.5); advance(actors,state,11)
	check(state.runtime_failures.any(func(s):return "latent_red expired" in s),"late rot does not extend tower latent TTL")
	actors=separated(); state=fixture()
	HW.resolve({"kind":"regression","at":0.0,"id":"hw_late_local","regression":"local","a":0,"b":1,"duration":10.0,"status_id":3529},actors,state)
	advance(actors,state,10.01)
	check(state.runtime_failures.any(func(s):return "Regression expired" in s),"too-late Local wipes at genuine10s expiry")
	actors=separated(); actors[1].pos=Vector2(2,0); actors[3].pos=actors[2].pos+Vector2(2,0); state=fixture()
	for pair in [[0,1],[2,3]]: HW.resolve({"kind":"regression","at":0.0,"id":"hw_early_%d" % pair[0],"regression":"local","a":pair[0],"b":pair[1],"duration":10.0,"status_id":3529},actors,state)
	advance(actors,state,0.1)
	check(state.runtime_failures.any(func(s):return "Thrice-come Ruin" in s),"two paired Patch bursts too early reach four stacks")
	actors=separated(); state=fixture()
	for i in 7: S.give(state,i,"overflow_debugger",9999)
	HW.resolve({"kind":"critical_error","at":0.0},actors,state)
	check(state.statuses[7].has("overflow") and not state.statuses[0].has("overflow"),"Critical Error grant blocked only by actual Debugger")
	check(state.runtime_failures.any(func(s):return "Critical Error lacks" in s),"missing Critical Error Debugger fails")
	advance(actors,state,21.01)
	check(state.hw.history.any(func(e):return e.kind=="hw_blast" and e.actor==7),"bad Critical Error Overflow is not silently discarded")
	actors=separated(); actors[1].pos=Vector2(8,0); state=fixture(); S.give(state,0,"overflow",0.1); S.give(state,1,"overflow_debugger",9999)
	advance(actors,state,0.2)
	check(not state.statuses[1].has("overflow") and not state.statuses[1].has("overflow_debugger"),"Overflow blast consumes one-shot Debugger")
	actors=separated(); state=fixture(); S.give(state,0,"red",27); actors[1].pos=Vector2.ZERO; state.sim_time=2.0
	S.contacts(actors,actors.duplicate(true),state); var expiry: float=state.statuses[1].red.expires
	state.sim_time=3.0; S.contacts(actors,actors.duplicate(true),state)
	check(float(state.statuses[1].red.expires)==expiry,"default explicitly-unverified same-colour preserve policy")
	actors=separated(); state=fixture(); previous=actors.duplicate(true); actors[0].pos+=Vector2(7.5,0); state.sim_time=1.0
	HW.tick(actors,previous,state,1.0)
	check(state.runtime_failures.any(func(s):return "budget exceeded" in s),"7.5 speed without explicit Sprint budget is rejected")
	state=fixture(); state.motion_allowances=[7.5,6,6,6,6,6,6,6]; state.sim_time=1.0
	HW.tick(actors,previous,state,1.0)
	check(state.runtime_failures.is_empty(),"explicit authorized Sprint budget accepted at7.5")
func run() -> void:
	negative_tests()
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/hw_routes.json"))
	var captured_towers := 0
	for capture in evidence.capture_geometry:
		check(int(capture.manifest_files_verified)==7,"all seven decompressed capture files SHA256 verified")
		for wave in capture.tower_waves:
			var observed := actors_at(wave.players)
			for tower in wave.towers:
				var hits := R.hits({"pos":tower.helper_center,"radius":6.0},observed)
				check(hits==[int(tower.recipient)],"captured interpolated player tower judgment "+str(capture.report)+" / "+str(wave.round))
				captured_towers+=1
	check(captured_towers==64,"four complete clears,16 towers each; no empty evidence gate")
	for angle in 8:
		for colour in ["red","blue"]:
			var towers := P.towers(angle,colour)
			check(towers.size()==4,"four towers")
			for t in towers:
				check(absf(R.v(t.pos).length()-14)<0.0001 and t.radius==6.0,"true radius14/radius6 geometry")
	var baseline := simulate(course("elemental",[0,0,0,0],"red"))
	print("BASELINE FAILURES: ",baseline.runtime_failures)
	print("BASELINE PATCHES: ",baseline.hw.history.filter(func(e):return e.kind=="hw_patch"))
	check(baseline.runtime_failures.is_empty(),"four-round walking course")
	check(baseline.hw.history.filter(func(e):return e.kind=="hw_tower").size()==16,"16 runtime tower judgments; cannot pass empty geometry")
	check(baseline.hw.history.filter(func(e):return e.kind=="hw_blast").size()==32,"16 actual bug blasts and 16 actual rot blasts")
	check(baseline.hw.history.filter(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8).size()==1,"all eight authentic Overflow Debuggers block Critical Error")
	for actor in 8:
		for name in ["red","blue","overflow","sync"]:
			check(baseline.hw.history.filter(func(e):return e.kind=="hw_blast" and e.actor==actor and e.status==name).size()==1,"each actor naturally resolves each bug exactly once")
	var restored := simulate(course("elemental",[0,0,0,0],"red"),true)
	check(JSON.stringify(JSON.parse_string(JSON.stringify(baseline)))==JSON.stringify(JSON.parse_string(JSON.stringify(restored))),"JSON restore at live bugs and paired lines is deterministic")
	check(native_json(baseline),"all durable state, history and pending events are JSON-native")
	for checkpoint in [25.6,46.5,86.5]:
		var resumed := simulate(course("elemental",[0,0,0,0],"red"),true,0.05,checkpoint)
		check(JSON.stringify(JSON.parse_string(JSON.stringify(baseline)))==JSON.stringify(JSON.parse_string(JSON.stringify(resumed))),"restore at actual handoff / late immunity checkpoint %.1f" % checkpoint)
		if JSON.stringify(JSON.parse_string(JSON.stringify(baseline)))!=JSON.stringify(JSON.parse_string(JSON.stringify(resumed))):
			for key in baseline:
				var a := JSON.stringify(JSON.parse_string(JSON.stringify(baseline[key])))
				var b := JSON.stringify(JSON.parse_string(JSON.stringify(resumed[key])))
				if a!=b:
					for i in mini(a.length(),b.length()):
						if a[i]!=b[i]:
							print("RESTORE FIELD ",key," at ",i,": ",a.substr(maxi(0,i-70),160)," / ",b.substr(maxi(0,i-70),160)); break
	var retry_ctx=course("kr_09stop",[0,3,6,1],"blue")
	var retry_a := simulate(retry_ctx); var retry_b := simulate(retry_ctx)
	check(JSON.stringify(retry_a)==JSON.stringify(retry_b),"retry with the same previously rendered course is deterministic")
	for key in baseline:
		if JSON.stringify(JSON.parse_string(JSON.stringify(baseline[key])))!=JSON.stringify(JSON.parse_string(JSON.stringify(restored[key]))): print("RESTORE DIFF: ",key)
	if "--quick" in OS.get_cmdline_user_args():
		print("HW quick fidelity: %d assertions, %d failures" % [assertions,failures]); quit(1 if failures else 0); return
	for angle in 8:
		for colour in ["red","blue"]:
			var angles: Array=[angle,angle,angle,angle]
			var state := simulate(course("elemental",angles,colour))
			check(state.runtime_failures.is_empty(),"constant orientation %s/%s: %s" % [str(angles),colour,str(state.runtime_failures.slice(0,3))])
			angles=[0,angle,posmod(angle*3,8),posmod(angle*5,8)]
			state=simulate(course("elemental",angles,colour))
			check(state.runtime_failures.is_empty(),"changing orientations %s/%s: %s" % [str(angles),colour,str(state.runtime_failures.slice(0,3))])
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		for wave in 4:
			for angle in 8:
				for colour in ["red","blue"]:
					var angles: Array=[0,0,0,0]; angles[wave]=angle
					var state := simulate(course(id,angles,colour),false,0.125)
					check(state.runtime_failures.is_empty() and state.hw.history.filter(func(e):return e.kind=="hw_tower").size()==16 and state.hw.history.filter(func(e):return e.kind=="hw_blast").size()==32 and state.hw.history.any(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8),"%s wave%d orientation%d %s: %s" % [id,wave+1,angle,colour,str(state.runtime_failures.slice(0,2))])
		print("HW matrix finished: ",id)
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		for shift in 8:
			var assignment: Array=[]
			for i in 8: assignment.append(posmod(shift-i,8))
			for colour in ["red","blue"]:
				var state := simulate(course(id,[shift,posmod(shift+3,8),posmod(shift+6,8),posmod(shift+1,8)],colour,assignment),false,0.125)
				check(state.runtime_failures.is_empty(),"arbitrary actor assignment %s/%d/%s: %s" % [id,shift,colour,str(state.runtime_failures.slice(0,2))])
	print("HW fidelity: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
