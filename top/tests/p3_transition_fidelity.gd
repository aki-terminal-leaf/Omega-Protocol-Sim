extends SceneTree
const C=preload("res://scripts/p3_transition_courses.gd")
const P=preload("res://scripts/p3_transition_patterns.gd")
const R=preload("res://scripts/p3_transition_runtime.gd")
const Rules=preload("res://scripts/rules.gd")
const Contact=preload("res://scripts/interactions.gd")
const Status=preload("res://scripts/statuses.gd")
var checks:=0
var failures:=0
var simulations:=0
func code_version() -> String:
	var hash_context:=HashingContext.new(); hash_context.start(HashingContext.HASH_SHA256)
	for path in ["res://scripts/p3_transition_courses.gd","res://scripts/p3_transition_patterns.gd","res://scripts/p3_transition_runtime.gd","res://data/p3_transition_routes.json","res://scripts/statuses.gd","res://tests/p3_transition_fidelity.gd"]:
		hash_context.update(FileAccess.get_file_as_bytes(path))
	return hash_context.finish().hex_encode()
func equivalent(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int): return absf(float(a)-float(b))<0.00001
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for k in a:
			if not b.has(k) or not equivalent(a[k],b[k]): return false
		return true
	return a==b
class Context:
	var profile: Dictionary
	var order: Array=range(8)
	var beats: Array=[]
	var positions: Array=[]
	var labels: Array=["","","","","","","",""]
	var rng=RandomNumberGenerator.new()
	func _init(id: String): profile={"id":id}
	func beat(title: String,duration: float,note: String) -> Dictionary:
		var b: Dictionary={"title":title,"duration":duration,"note":note,"positions":positions.duplicate(),"shapes":[]}
		beats.append(b); return b
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25: print("FAIL ",message)
func fresh() -> Dictionary:
	var s: Dictionary={"sim_time":0.0,"statuses":[],"dead":[],"timeline":[],"runtime_failures":[]}
	for _a in 8: s.statuses.append({})
	return s
func actors_at(points: Array) -> Array: return points.map(func(p):return {"pos":Rules.v(p)})
func tick(state: Dictionary, actors: Array, previous: Array, dt: float) -> void:
	state.sim_time=float(state.sim_time)+dt; R.tick(actors,previous,state,dt)
func fixture(events: Array, duration:=30.0, zone_start:=100.0, zone_end:=101.0) -> Dictionary:
	for i in events.size(): events[i].serial=i
	P.sort_events(events)
	return {"p3_transition_events":events,"p3_transition_duration":duration,"p3_transition_void":{"start":zone_start,"end":zone_end,"radius":6.0}}
func simulate(id: String, family: int, sample: int, purple: Array, white: Array, restore:=false, step:=0.05, integrated:=false) -> Dictionary:
	var ctx=Context.new(id); C.append_family(ctx,family,sample,purple,white)
	var state:=fresh(); var actors:=actors_at(ctx.beats[0].spawn)
	if integrated:
		state.erase("statuses"); Status.ensure(state)
	for b in ctx.beats:
		if integrated: Contact.begin(b,actors,state)
		else: R.begin(b,state)
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(step,float(b.duration)-elapsed); var previous:=actors.duplicate(true)
			for a in 8: actors[a].pos=Rules.v(actors[a].pos).move_toward(Contact.bot_goal(a,b,actors,state) if integrated else Rules.v(b.positions[a]),6.0*dt)
			if integrated: Contact.tick(b,actors,previous,state,dt)
			else: tick(state,actors,previous,dt)
			elapsed+=dt
			if restore: state=JSON.parse_string(JSON.stringify(state))
	R.sync(ctx.beats[-1],state)
	simulations+=1
	check(state.runtime_failures.is_empty(),"physical %s family%d sample%d %s %s"%[id,family,sample,str(purple),str(state.runtime_failures)])
	check(state.p3_transition.history.filter(func(e):return e.kind=="ring").size()==8,"eight rings")
	check(state.p3_transition.history.filter(func(e):return e.kind=="arm_hit").size()==6,"six arms")
	check(state.p3_transition.packets.size()==6,"six sniper sources / eight player packets")
	check(state.p3_transition.pending.is_empty(),"all events drained")
	return state
func negative() -> void:
	check(not P.valid_partition([0,0,2,3],[4,5]),"duplicate marks rejected")
	check(not P.valid_partition([0,1,2,3],[3,5]),"cross-class marks rejected")
	check(not P.valid_partition([0,1,2,3],[4,8]),"out of range marks rejected")
	for radius in [6.0,12.0,18.0,24.0]:
		var ring:=int(radius/6.0)-1
		var shape: Dictionary={"kind":"circle" if ring==0 else "donut","pos":[0,0],"inner":ring*6.0,"radius":radius}
		check(Rules.contains(shape,Vector2(radius,0),[]),"outer ring boundary included")
		check(not Rules.contains(shape,Vector2(radius+0.01,0),[]),"outside ring boundary excluded")
	var state:=fresh(); var actors:=actors_at([Vector2(7,0),Vector2(7,0),Vector2(7,0),Vector2(7,0),Vector2(7,0),Vector2(7,0),Vector2(7,0),Vector2(7,0)])
	R.begin(fixture([],4,1,2),state); var previous:=actors.duplicate(true)
	actors[0].pos=Vector2(-7,0); state.motion_allowances=[20,20,20,20,20,20,20,20]
	tick(state,actors,previous,3)
	check(0 in state.dead,"void clipped-time segment catches tunneling with safe endpoints")
	state=fresh(); R.begin(fixture([],4,1,2),state);actors=actors_at(previous.map(func(a):return a.pos));actors[0].pos=Vector2(0,0)
	tick(state,actors,actors.duplicate(true),0.9);check(state.dead.is_empty(),"center legal before void activates")
	tick(state,actors,actors.duplicate(true),0.2);check(0 in state.dead,"void activates at its own time")
	state=fresh(); R.begin(fixture([],4,1,2),state);state.sim_time=2;state.p3_transition.last_time=2
	tick(state,actors,actors.duplicate(true),0.2);check(state.dead.is_empty(),"void removed after window")
	for allowance in [false,true]:
		state=fresh(); R.begin(fixture([]),state);actors=actors_at(previous.map(func(a):return a.pos));var before:=actors.duplicate(true)
		actors[0].pos=Vector2(14.5,0)
		if allowance: state.motion_allowances=[7.5,6,6,6,6,6,6,6]
		tick(state,actors,before,1)
		check(state.dead.is_empty()==allowance,"Sprint needs explicit parent allowance")
	state=fresh();R.begin(fixture([]),state);actors[0].pos=Vector2(20,0);tick(state,actors,actors.duplicate(true),0.1)
	check(0 in state.dead,"death wall at20")
	var route:=P.route("elemental"); var assign:=C.slots(route,[0,1,2,3],[4,5]);var points:=C.points(assign,0,16.5,true)
	for mode in ["valid","double_white","purple_overlap","vulnerable","missing","dead_owner","dead_partner","white_solo"]:
		state=fresh(); actors=actors_at(points)
		R.begin(fixture([{"kind":"marks","at":0.0,"purple":[0,1,2,3],"white":[4,5],"expires":2.0},{"kind":"sniper","at":2.0}]),state)
		tick(state,actors,actors.duplicate(true),0.1)
		if mode=="double_white": actors[5].pos=actors[4].pos
		if mode=="purple_overlap": actors[1].pos=actors[0].pos
		if mode=="vulnerable": state.statuses[0].magic_vulnerability={"expires":3}
		if mode=="missing": state.statuses[0].erase("sniper_cannon_fodder")
		if mode=="dead_owner": state.dead.append(0)
		if mode=="dead_partner": state.dead.append(6)
		if mode=="white_solo": actors[6].pos=Vector2(0,7)
		tick(state,actors,actors.duplicate(true),1.9)
		check(state.runtime_failures.is_empty()==(mode=="valid"),"sniper judgment "+mode)
		if mode=="vulnerable": check(0 in state.dead,"prior magic vuln kills")
	# Exact event interpolation and locked original arm origin survive JSON.
	state=fresh(); actors=actors_at(points)
	var arm: Dictionary={"id":"test","pos":[7,0],"at":1.0,"cue_at":0.0,"form":"arm_left","form_confidence":"fixture"}
	R.begin(fixture([{"kind":"arm_cue","at":0.0,"entity":arm},{"kind":"arm_hit","at":1.0,"id":"test"}]),state)
	tick(state,actors,actors.duplicate(true),0.1);state=JSON.parse_string(JSON.stringify(state))
	actors[0].pos=Vector2(18,0);tick(state,actors,actors.duplicate(true),0.9)
	check(0 in state.dead,"arm radius11 boundary kills after JSON restore")
	check(equivalent(state.p3_transition.history[-1].origin,[7,0]),"arm source remains locked")
	var b: Dictionary={};R.sync(b,state)
	check(b.stage_entities[0].form=="final","original Omega Reconfigured form")
	state=fresh();R.begin(fixture([{"kind":"ring","at":0.5,"ring":0,"shape":{"pos":[0,0],"radius":6}}]),state)
	actors=actors_at(points);actors[0].pos=Vector2(8,0);previous=actors.duplicate(true);actors[0].pos=Vector2(2,0)
	tick(state,actors,previous,1)
	check(equivalent(state.p3_transition.history[0].positions[0],[5,0]),"snapshot at event time, not endpoint")
	check(0 in state.dead,"sampled ring hits independently of guide")
	# Render contract: six actual arm forms at their locked origins, no generic fallback.
	state=fresh();var ctx=Context.new("elemental");C.append_family(ctx,0)
	R.begin(ctx.beats[0],state);actors=actors_at(ctx.beats[0].spawn)
	tick(state,actors,actors.duplicate(true),7)
	b={"stage_entities":[{"id":"parent_unrelated","form":"male"}]};R.sync(b,state)
	check(b.stage_entities.size()==8,"six arms plus final boss and preserved unrelated entity")
	check(b.stage_entities.filter(func(e):return e.get("form","") in ["arm_left","arm_right"]).size()==6,"all six use original arm models")
	check(state.p3_transition.arms.values().all(func(a):return absf(Rules.v(a.locked_pos).length()-14)<0.01),"cast origins radius14, never arbitrary20")
	R.sync(b,state);check(b.stage_entities.size()==8,"sync idempotent and preserves unrelated entities")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var started:=Time.get_ticks_msec(); var quick: bool="--quick" in OS.get_cmdline_user_args()
	negative()
	for id in P.data().routes:
		for family in 2:
			for sample in (1 if quick else 4): simulate(id,family,2 if quick else sample,[0,1,2,3],[4,5])
	var normal:=simulate("elemental",0,2,[7,2,5,0],[6,3])
	var restored:=simulate("elemental",0,2,[7,2,5,0],[6,3],true)
	check(equivalent(normal.p3_transition.history,restored.p3_transition.history),"every-frame JSON restore preserves event history within1e-5")
	var integrated:=simulate("elemental",0,2,[7,2,5,0],[6,3],false,0.05,true)
	check(equivalent(normal.p3_transition.history,integrated.p3_transition.history),"three hooks preserve judgments through actual Interactions/Statuses pipeline")
	# All 70 choices of four purple times six white pairs = 420 partitions.
	var partitions:=0
	for mask in 256:
		var purple: Array=[];var rest: Array=[]
		for a in 8:
			if mask & (1<<a): purple.append(a)
			else: rest.append(a)
		if purple.size()!=4: continue
		for i in 4:
			for j in range(i+1,4):
				var white: Array=[rest[i],rest[j]];partitions+=1
				for id in P.data().routes:
					var route:=P.route(id);var slots:=C.slots(route,purple,white)
					var reversed_p:=purple.duplicate();reversed_p.reverse();var reversed_w:=white.duplicate();reversed_w.reverse()
					check(slots==C.slots(route,reversed_p,reversed_w),"priority independent of arbitrary actor input order")
					if not quick:
						for family in 2: simulate(id,family,2,purple,white,false,0.1)
	check(partitions==420,"all legal partitions")
	# Force-slot contexts use ctx.order, not a hard-coded role-to-mark map.
	for actor in 8:
		for slot in 8:
			var ctx=Context.new("elemental");ctx.order[slot]=actor;ctx.order[actor]=slot;C.append_family(ctx,0)
			var mark: Dictionary=ctx.beats[0].p3_transition_events[0]
			check((actor in mark.purple)==(slot<4) and (actor in mark.white)==(slot>=4 and slot<6),"forced actor slot")
	print("P3_TRANSITION_RESULT ",JSON.stringify({"code_sha256":code_version(),"mode":"quick" if quick else "full","checks":checks,"failures":failures,"physical_simulations":simulations,"partitions":partitions,"elapsed_ms":Time.get_ticks_msec()-started}))
	quit(1 if failures else 0)
