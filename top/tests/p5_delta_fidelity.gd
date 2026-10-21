extends SceneTree
const P = preload("res://scripts/p5_delta_patterns.gd")
const C = preload("res://scripts/p5_delta_courses.gd")
const D = preload("res://scripts/p5_delta_runtime.gd")
const I = preload("res://scripts/interactions.gd")
const S = preload("res://scripts/statuses.gd")
const R = preload("res://scripts/rules.gd")
const E = preload("res://scripts/encounters.gd")
var assertions:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok: failures+=1; print("DELTA FAIL: ",message)
func fresh() -> Dictionary:
	var s: Dictionary={"sim_time":0.0,"dynamis":[0,0,0,0,0,0,0,0],"seed":1}
	S.ensure(s); return s
func actors_at(points: Array) -> Array:
	var result: Array=[]
	for a in 8: result.append({"pos":R.v(points[a]),"face":0.0,"role":E.ROLES[a]})
	return result
func repeated(p: Vector2) -> Array:
	var result: Array=[]
	for a in 8: result.append(p)
	return result
func make_config(id: String="aether", eye:=0.0, safe:=1, monitor_side:=1, monitor:=0, defense_choice:=0, colours: Array=[]) -> Dictionary:
	var c:=P.config(P.assignment(range(8)),eye,safe,monitor_side,monitor,defense_choice,colours)
	c.route=P.route(id); return c
func make_beat(c: Dictionary, events: Array) -> Dictionary:
	return {"duration":54.0,"delta_config":c,"delta_events":events,"positions":repeated(Vector2.ZERO),"shapes":[],"facing":{}}
func step(b: Dictionary, actors: Array, state: Dictionary, goals: Array, dt: float, sprint:=false) -> void:
	var prev:=actors.duplicate(true)
	state.motion_allowances=[]
	for a in 8:
		var allowance: float=(7.5 if sprint and a==int(state.delta.config.monitor) else 6.0)*dt
		state.motion_allowances.append(allowance)
		actors[a].pos=R.v(actors[a].pos).move_toward(R.v(goals[a]),allowance)
		if b.get("facing",{}).has(a): actors[a].face=float(b.facing[a])
	I.tick(b,actors,prev,state,dt)
func simulate(c: Dictionary, checkpoint:=false, frame:=0.02) -> Dictionary:
	var ctx=E.new(); ctx.profile={"id":c.route.id};ctx.positions=repeated(Vector2.ZERO);ctx.labels=["","","","","","",""]
	C.append_family(ctx,c)
	var state:=fresh(); var actors:=actors_at(repeated(Vector2.ZERO))
	for b in ctx.beats:
		I.begin(b,actors,state)
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(frame,float(b.duration)-elapsed)
			var goals: Array=[]
			for a in 8: goals.append(I.bot_goal(a,b,actors,state))
			var t:=float(state.sim_time)-float(state.delta.start)
			step(b,actors,state,goals,dt,C.sprint_authorized(c) and t>=25.527 and t<31)
			elapsed+=dt
		if checkpoint:
			var saved: Dictionary=JSON.parse_string(JSON.stringify({"state":state,"actors":actors.map(func(a):return {"pos":P.xy(R.v(a.pos)),"face":a.face,"role":a.role})}))
			state=saved.state;actors=actors_at(saved.actors.map(func(a):return a.pos))
			for a in 8: actors[a].face=float(saved.actors[a].face)
	return state
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(P.fist_families().size()==36,"all balanced fist colour families")
	for n in 2:
		for f in 2: check(P.valid_assignment(P.assignment(range(8),n,f)),"one World per blue pair")
	var invalid:=P.assignment(range(8)); invalid.far=1
	check(not P.valid_assignment(invalid),"same-pair Worlds rejected")
	var c:=make_config(); var b:=make_beat(c,[{"at":0.1,"kind":"fists_spawn"},{"at":1.0,"kind":"fists_lock"},{"at":4.0,"kind":"fists_resolve"}])
	var points: Array=[Vector2(-12,-8),Vector2(-12,8),Vector2(-12,-8),Vector2(-12,8),Vector2(12,-8),Vector2(12,8),Vector2(12,-8),Vector2(12,8)]
	var actors:=actors_at(points);var state:=fresh();I.begin(b,actors,state)
	step(b,actors,state,points,1.0)
	check(state.delta.fists.size()==8,"eight separate entities")
	check(state.delta.fists.all(func(f):return f.has("lock_pos")),"all fists cast-start locked")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(state))
	check(restored.delta==JSON.parse_string(JSON.stringify(state.delta)),"entity/pending JSON round trip")
	var next: Dictionary={"duration":3.0,"positions":points,"shapes":[]}
	I.begin(next,actors,restored);step(next,actors,restored,points,3.0)
	check(restored.dead.size()==8,"old source puddle still kills after beat/checkpoint change")
	for eye in [0.0,90.0,180.0,270.0]:
		for safe in [-1,1]:
			c=make_config("aether",eye,safe)
			var inside:=Vector2(0,4.9*safe).rotated(deg_to_rad(eye))
			var outside:=Vector2(0,6.0*safe).rotated(deg_to_rad(eye))
			check(R.contains(c.swivel,inside,[]),"210 cone catches wrong old half-plane safe spot")
			check(not R.contains(c.swivel,outside,[]),"sloped Swivel boundary safe side")
	# Diagnostic full-course gates are reported honestly; no weakened radii.
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		var result:=simulate(make_config(id),true)
		print("DELTA COURSE ",id," errors=",result.runtime_failures.size()," first=",result.runtime_failures.slice(0,8))
		check(result.delta.ended,"complete event timeline "+id)
		check(result.delta.history.filter(func(e):return e.kind=="arms_fire").size()==6,"six arm repeats "+id)
		check(result.runtime_failures.is_empty(),"full live course "+id)
	negative_and_state_gates()
	if "--matrix" in OS.get_cmdline_user_args(): matrix()
	if "--assignments" in OS.get_cmdline_user_args(): assignment_matrix()
	print("DELTA assertions=",assertions," failures=",failures)
	quit(0 if failures==0 else 1)

func matrix() -> void:
	var tested:=0;var bad:=0
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		var only: String=""
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--matrix-profile="): only=argument.trim_prefix("--matrix-profile=")
		if not only.is_empty() and id!=only: continue
		var family_bad:=0
		for eye in [0.0,90.0,180.0,270.0]:
			for safe in [-1,1]:
				for monitor_side in [-1,1]:
					for monitor in 4:
						for defense_choice in 2:
							for hand in [-1,1]:
								var c:=make_config(id,eye,safe,monitor_side,monitor,defense_choice);c.monitor_hand=hand
								var result:=simulate(c,true,0.05);tested+=1
								if not result.runtime_failures.is_empty():
									family_bad+=1;bad+=1
									if family_bad<=4: print("MATRIX BAD ",id," eye=",eye," safe=",safe," mside=",monitor_side," hand=",hand," monitor=",monitor," defense=",defense_choice," errors=",result.runtime_failures.slice(0,8))
		print("MATRIX ",id," branches=256 failed=",family_bad)
		check(family_bad==0,"all monitor/safe/eye/Defense branches "+id)
		family_bad=0
		for colours in P.fist_families():
			var result:=simulate(make_config(id,0,1,1,0,0,colours),false,0.05);tested+=1
			if not result.runtime_failures.is_empty():
				family_bad+=1;bad+=1
				if family_bad<=2: print("FIST BAD ",id," colours=",colours," errors=",result.runtime_failures.slice(0,8))
		print("MATRIX ",id," fist families=36 failed=",family_bad)
		check(family_bad==0,"all balanced fists / regional adjustment "+id)
		family_bad=0
		for mask in 64:
			var c:=make_config(id)
			for arm in 6: c.arm_turns[arm]=20 if ((mask>>arm)&1) else -20
			var result:=simulate(c,false,0.05);tested+=1
			if not result.runtime_failures.is_empty():
				family_bad+=1;bad+=1
				if family_bad<=2: print("ARM BAD ",id," mask=",mask," errors=",result.runtime_failures.slice(0,8))
		print("MATRIX ",id," arm families=64 failed=",family_bad)
		check(family_bad==0,"all six independent arm directions "+id)
	print("MATRIX TOTAL ",tested," failed=",bad)

func assignment_matrix() -> void:
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		var bad:=0;var tested:=0
		for actor in 8:
			for forced in 8:
				var order: Array=range(8)
				var generator:=RandomNumberGenerator.new();generator.seed=actor*8+forced+19
				for i in range(7,0,-1):
					var j:=generator.randi_range(0,i);var old=order[i];order[i]=order[j];order[j]=old
				var previous:=order.find(actor);order[previous]=order[forced];order[forced]=actor
				var index:=actor*8+forced
				var c:=make_config(id,(index%4)*90.0,1 if index%2 else -1,1 if (index/2)%2 else -1,int(order[index%4]),index%2,P.fist_families()[index%36])
				c.assignment=P.assignment(order,index%2,(index/2)%2,(index/4)%2)
				for arm in 6: c.arm_turns[arm]=20 if ((index>>arm)&1) else -20
				var result:=simulate(c,true,0.05);tested+=1
				if not result.runtime_failures.is_empty():
					bad+=1
					if bad<=3: print("ASSIGN BAD ",id," actor=",actor," slot=",forced," order=",order," errors=",result.runtime_failures.slice(0,8))
		print("ASSIGN ",id," forced actor/slot=",tested," failed=",bad)
		check(bad==0,"every forced actor/slot with mixed finite patterns "+id)

func json_native(value, path: String="state") -> bool:
	if value is Dictionary:
		for k in value:
			if not (k is String or k is StringName): print("NON JSON KEY ",path," ",k);return false
			if not json_native(value[k],path+"."+str(k)): return false
	elif value is Array:
		for i in value.size():
			if not json_native(value[i],path+"[%d]"%i): return false
	elif not (value==null or value is String or value is bool or value is int or value is float): print("NON JSON VALUE ",path," ",value);return false
	return true

func negative_and_state_gates() -> void:
	var c:=make_config();var state:=fresh();var b:=make_beat(c,[])
	var safe_pairs: Array=[Vector2(-13,-3),Vector2(-13,3),Vector2(-10,-3),Vector2(-10,3),Vector2(7,-13),Vector2(7,13),Vector2(12,-11),Vector2(12,11)]
	var actors:=actors_at(safe_pairs);I.begin(b,actors,state)
	step(b,actors,state,safe_pairs,18.0)
	check(state.delta.tethers.all(func(t):return not t.broken),"no automatic scheduled breaks")
	check(is_equal_approx(float(state.delta.tethers[0].expires),29.976),"Remote 1673 twelve-second TTL")
	check(is_equal_approx(float(state.delta.tethers[2].expires),53.976),"Local 1672 thirty-six-second TTL")
	step(b,actors,state,safe_pairs,12.0)
	check(state.dead.size()==8,"unbroken Remote expires at thirty seconds, not sixty-five")
	check(state.delta.tethers.slice(2).all(func(t):return not t.broken),"Local remains active independently of Remote TTL")
	state=fresh();b=make_beat(c,[])
	var early: Array=[Vector2(-10,-12),Vector2(-10,12),Vector2(10,-12),Vector2(10,12),Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,1)]
	actors=actors_at(early);I.begin(b,actors,state);step(b,actors,state,early,18.0)
	check(state.dead.size()==8,"early simultaneous multi-Patch kills")
	check(state.delta.history.filter(func(e):return e.kind=="patch").size()==4,"all four independently broken tethers recorded")
	check(float(state.statuses[0].get("world_vulnerability",{}).get("expires",0))==0,"Patch does not masquerade as World vulnerability")
	# A malformed fist pairing is a range-100 wipe even after leaving puddles.
	c=make_config();c.colours=[0,1,0,1,0,1,0,1]
	b=make_beat(c,[{"at":0.1,"kind":"fists_spawn"},{"at":0.2,"kind":"fists_lock"},{"at":3.2,"kind":"fists_resolve"}]);state=fresh()
	var bait: Array=[Vector2(-12,-8),Vector2(-12,8),Vector2(-12,-8),Vector2(-12,8),Vector2(12,-8),Vector2(12,8),Vector2(12,-8),Vector2(12,8)]
	actors=actors_at(bait);I.begin(b,actors,state);step(b,actors,state,bait,0.2);step(b,actors,state,repeated(Vector2.ZERO),3.0)
	check(state.runtime_failures.any(func(e):return "31483" in e),"same-colour entity overlaps fail even if all players leave")
	# Lock interpolated actual positions, and keep chasing NPC position separate.
	c=make_config();c.parameters.fist_chase_speed=1.0
	b=make_beat(c,[{"at":0.1,"kind":"fists_spawn"},{"at":1.0,"kind":"fists_lock"}]);state=fresh();actors=actors_at(bait);I.begin(b,actors,state)
	step(b,actors,state,bait,0.1)
	var moved:=bait.duplicate();moved[0]=Vector2(-6,-8)
	step(b,actors,state,moved,1.0)
	check(R.v(state.delta.fists[0].lock_pos).distance_to(Vector2(-6.6,-8))<0.001,"fist bait captured inside frame at cast start")
	check(R.v(state.delta.fists[0].pos).distance_to(R.v(state.delta.fists[0].lock_pos))>4.0,"unmeasured chase parameter isolated from cast-location capture")
	check(json_native(state),"all durable pending/history/entity/status values JSON-native")
	var before_pending: int=state.delta.pending.size();I.begin(b,actors,state)
	check(state.delta.pending.size()==before_pending,"same-beat retry begin is idempotent")
	# Closest means actual closest, including a different player than guide role.
	c=make_config();b=make_beat(c,[{"at":0.01,"kind":"arms_spawn"},{"at":0.1,"kind":"arms_lock"}]);state=fresh()
	var arm_points:=repeated(Vector2.ZERO);arm_points[7]=Vector2(1,-19)
	actors=actors_at(arm_points);I.begin(b,actors,state);step(b,actors,state,arm_points,0.2)
	check(int(state.delta.arms[0].target)==7,"arm locks actual closest actor, not guide owner")
	var locked: float=state.delta.arms[0].angle
	step(b,actors,state,repeated(Vector2.ZERO),3.0)
	check(is_equal_approx(float(state.delta.arms[0].angle),locked),"arm does not reaim when bait leaves")
	# Movement is judged at the production hook, not only in the harness.
	state=fresh();b=make_beat(make_config(),[]);actors=actors_at(repeated(Vector2.ZERO));I.begin(b,actors,state)
	var prev:=actors.duplicate(true);actors[0].pos=Vector2(11,0);I.tick(b,actors,prev,state,1.0)
	check(0 in state.dead,"11/s walking / endpoint teleport rejected")
	state=fresh();b=make_beat(make_config(),[]);actors=actors_at(repeated(Vector2.ZERO));I.begin(b,actors,state)
	prev=actors.duplicate(true);actors[0].pos=Vector2(7.5,0);state.motion_allowances=[7.5,6,6,6,6,6,6,6];I.tick(b,actors,prev,state,1.0)
	check(state.runtime_failures.is_empty(),"explicit parent Sprint budget accepted")
	# Actual nearest/farthest chains include the original holder on jump two.
	c=make_config();b=make_beat(c,[{"at":0.1,"kind":"world","pulse":0},{"at":1.1,"kind":"world","pulse":1},{"at":2.1,"kind":"world","pulse":2}]);state=fresh()
	var bounce: Array=[Vector2(-9,-9),Vector2(0,-9),Vector2(9,9),Vector2(-18,6),Vector2(18,3),Vector2(3,0),Vector2(-5,6),Vector2(5,-1)]
	actors=actors_at(bounce);I.begin(b,actors,state);step(b,actors,state,bounce,2.2)
	check(state.runtime_failures.any(func(e):return "bounce back" in e),"original holder bounce-back fails during five-second World vulnerability")
	check(int(state.world_chains.delta.history[4].receiver)==0,"actual near chain returns to original holder")
	check(int(state.dynamis[0])==2,"Dynamis follows actual hits even on failing bounce")
	# Live Magic Vulnerability from a World also rejects a premature late cut.
	state=fresh();b=make_beat(make_config(),[]);actors=actors_at(safe_pairs);I.begin(b,actors,state)
	step(b,actors,state,safe_pairs,18.0)
	S.give(state,0,"world_vulnerability",5.0)
	var close:=safe_pairs.duplicate();close[4]=Vector2(7,10)
	step(b,actors,state,close,4.0)
	check(state.runtime_failures.any(func(e):return "Patch during vulnerability" in e),"green cut while World vulnerability remains kills")
	# Real Pile Pitch has three receivers in the usual route, and no victim.
	var result:=simulate(make_config(),true)
	var pitch: Dictionary=result.delta.history.filter(func(e):return e.kind=="pile_pitch")[0]
	check(pitch.hits.size()==3,"legal three-player Pile Pitch, not prescribed seven")
	check(not pitch.hits.any(func(a):return a in pitch.excluded),"actual Defense victim excluded")
	var monitors: Dictionary=result.delta.history.filter(func(e):return e.kind=="monitors")[0]
	check(monitors.coverage.count(1.0)==4 or monitors.coverage.count(1)==4,"four actual single monitor hits, not eight required members")
	check(result.dynamis.count(1.0)==6 or result.dynamis.count(1)==6,"six actual World recipients; two stay without a forced stack")
	# Half membership alone is insufficient: two selected targets six yards
	# apart both receive both radius-seven splashes.
	c=make_config();b=make_beat(c,[{"at":0.1,"kind":"monitors"}]);state=fresh()
	var splash: Array=[Vector2(0,5),Vector2(-10,2.5),Vector2(0,2.5),Vector2(0.5,2.5),Vector2(-7,-13),Vector2(-7,13),Vector2(-1,-13),Vector2(7,13)]
	actors=actors_at(splash);actors[0].face=90.0;I.begin(b,actors,state);step(b,actors,state,splash,0.2)
	check(state.runtime_failures.any(func(e):return "Monitor double-hit" in e),"actual radius-seven monitor splash rejects nominal correct half counts")
	c=make_config();b=make_beat(c,[{"at":0.1,"kind":"defense"},{"at":1.1,"kind":"pile_pitch"}]);state=fresh()
	var stack_start: Array=[Vector2.ZERO,Vector2(6,0),Vector2(6,1),Vector2(-15,-5),Vector2(-15,5),Vector2(0,16),Vector2(12,-10),Vector2(12,10)]
	actors=actors_at(stack_start);I.begin(b,actors,state);step(b,actors,state,stack_start,0.1)
	var stack_end:=stack_start.duplicate();stack_end[1]=Vector2(1,0);stack_end[2]=Vector2(1,1)
	step(b,actors,state,stack_end,1.0)
	check(state.runtime_failures.any(func(e):return "Beyond Defense victim in Pile Pitch" in e),"actual previous Defense victim rejected from otherwise legal three-stack")
	c=make_config();b=make_beat(c,[{"at":0.1,"kind":"world","pulse":0}]);state=fresh()
	var clip:=bounce.duplicate();clip[1]=Vector2(-8,-9)
	actors=actors_at(clip);I.begin(b,actors,state);step(b,actors,state,clip,0.2)
	check(state.runtime_failures.any(func(e):return "AoE clipped" in e),"actual radius-eight initial World clip fails")
	check(int(state.dynamis[1])==1,"clipped player receives actual Dynamis; no guide recipient equality")
	var kr:=simulate(make_config("kr_09stop"),true)
	check(kr.dynamis.slice(0,6)==[1.0,1.0,1.0,1.0,1.0,1.0] and kr.dynamis.slice(6)==[0.0,0.0],"KR figure338 gives Worlds to four blues and inner greens, not Elemental recipients")
