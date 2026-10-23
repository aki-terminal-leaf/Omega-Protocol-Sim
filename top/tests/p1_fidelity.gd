extends SceneTree
const C=preload("res://scripts/p1_courses.gd")
const P=preload("res://scripts/p1_patterns.gd")
const Runtime=preload("res://scripts/p1_runtime.gd")
const Contact=preload("res://scripts/interactions.gd")
const Status=preload("res://scripts/statuses.gd")
const Cannon=preload("res://scripts/cannons_observation.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
const Rules=preload("res://scripts/rules.gd")
const Encounter=preload("res://scripts/encounters.gd")
var assertions:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1; print("P1 FAIL: ",message)
func fresh() -> Dictionary:
	var s: Dictionary={"sim_time":0.0,"dynamis":[0,0,0,0,0,0,0,0],"spent":[],"lb":"","aggro":0}
	Status.ensure(s)
	return s
func actors_at(points: Array) -> Array:
	var actors: Array=[]
	for i in 8: actors.append({"pos":points[i],"role":Encounter.ROLES[i],"face":0.0})
	return actors
func context(profile: Dictionary,seed_value:=39):
	var ctx=Encounter.new()
	ctx.build("unused",seed_value,profile)
	return ctx
func simulate(beats: Array,restore:=false) -> Dictionary:
	var actors:=actors_at(beats[0].get("spawn",C.repeated(Vector2.ZERO)));var state:=fresh()
	for raw in beats:
		var b: Dictionary=raw.duplicate(true)
		Contact.begin(b,actors,state)
		var elapsed:=0.0
		var restored_loop:=false
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(0.025,float(b.duration)-elapsed);var previous:=actors.duplicate(true)
			# Event-only simulator has no Arena. Explicitly simulate the current
			# eligible head receipt, NOT an actual rendered/native/Web observation.
			if b.has("cannons_public"):
				var displayed:Array=[]
				for actor in 8:
					if "cannon" in Signs.observed_all(actor,b,state):displayed.append(actor)
				Cannon.publish(b,state,displayed)
			var goals:Array=[]
			# Match Main's ordered bot update, while retaining actual pre-frame positions for swept contacts.
			for i in 8:
				var goal:Vector2=Contact.bot_goal(i,b,actors,state)
				goals.append(P.xy(goal))
				actors[i].pos=Rules.v(actors[i].pos).move_toward(goal,6.0*dt)
			Contact.tick(b,actors,previous,state,dt);elapsed+=dt
			if "--loop-trace" in OS.get_cmdline_user_args() and b.has("program_loop") and int(elapsed*2)!=int((elapsed-dt)*2):
				print("LOOP TRACE ",JSON.stringify({"time":state.sim_time,"holders":state.tether_holders,"released":state.loop_released,"actors":actors.map(func(a):return P.xy(a.pos)),"goals":goals}))
			if "--loop-restore" in OS.get_cmdline_user_args() and b.has("program_loop") and not restored_loop and elapsed>=float(b.duration)*0.5:
				# Exercise planner persistence independently of authoritative status serialization.
				for key in ["loop_refuges","loop_released","loop_departure_order","loop_deadline","tether_routes"]:
					state[key]=JSON.parse_string(JSON.stringify(state[key]))
				restored_loop=true
		var endpoint:=Rules.evaluate(b,actors,state)
		state.runtime_failures.append_array(endpoint)
		if b.has("program_loop") and not endpoint.is_empty() and "--loop-probe" in OS.get_cmdline_user_args():
			print("LOOP SNAPSHOT ",JSON.stringify({"time":state.sim_time,"round":b.program_loop.round,"holders":state.tether_holders,"wanted":b.transfers.wanted,"numbers":b.program_loop.numbers,"actors":actors.map(func(a):return P.xy(a.pos)),"goals":b.positions.map(func(p):return P.xy(p)),"errors":endpoint}))
		if restore and not b.has("transfers"):state=JSON.parse_string(JSON.stringify(state))
	return state
func _initialize() -> void: call_deferred("run")
func event_beat(events: Array,duration:=40.0) -> Dictionary:
	return {"duration":duration,"p1_events":events,"p1_duration":duration,"shapes":[],"positions":C.repeated(Vector2.ZERO)}
func advance(b: Dictionary,actors: Array,state: Dictionary,dt: float) -> void:
	Contact.tick(b,actors,actors.duplicate(true),state,dt)
func negative_and_boundaries() -> void:
	loop_navigation_negatives()
	var actors:=actors_at(C.repeated(Vector2.ZERO));var state:=fresh()
	var b:=event_beat([{"kind":"bait","at":1.0,"bait":0,"delay":3.0,"radius":5.0}])
	Contact.begin(b,actors,state)
	var previous:=actors.duplicate(true)
	for actor in actors: actor.pos=Vector2(10,0)
	Contact.tick(b,actors,previous,state,2.0)
	check(state.p1.pending.size()==8,"each actual actor locks one puddle even when stacked")
	check(Rules.v(state.p1.pending[0].shape.pos).distance_to(Vector2(5,0))<0.0001,"lock samples actual interpolated positions at T1, not route goals")
	state=JSON.parse_string(JSON.stringify(state))
	b={"duration":3.0,"positions":C.repeated(Vector2(5,0)),"shapes":[]}
	Contact.begin(b,actors,state);previous=actors.duplicate(true)
	for actor in actors: actor.pos=Vector2(5,0)
	Contact.tick(b,actors,previous,state,2.0)
	check(state.dead.size()==8 and state.p1.history.size()==9,"returning to previous bait fails across beat boundary and JSON restore")
	check(state.p1.history[-1].at==4.0,"restore retains original explosion deadline")
	state=fresh();b=event_beat([]);actors=actors_at(C.repeated(Vector2.ZERO));Contact.begin(b,actors,state);previous=actors.duplicate(true);actors[0].pos=Vector2(7.5,0)
	Contact.tick(b,actors,previous,state,1.0)
	check(not state.runtime_failures.is_empty(),"unauthorized Sprint/teleport is rejected")
	state=fresh();actors=actors_at(C.repeated(Vector2.ZERO));Contact.begin(b,actors,state);previous=actors.duplicate(true);actors[0].pos=Vector2(7.5,0);state.motion_allowances=[7.5,6,6,6,6,6,6,6]
	Contact.tick(b,actors,previous,state,1.0)
	check(state.runtime_failures.is_empty(),"explicit parent motion allowance honors authorized Sprint/dash")
	state=fresh();b=event_beat(P.cannons([2,3,4],1.0));actors=actors_at([Vector2(-1,-17),Vector2(1,-17),Vector2(-10,0),Vector2(0,10),Vector2(10,0),Vector2(-7,7),Vector2(7,7),Vector2(0,8)])
	Contact.begin(b,actors,state);advance(b,actors,state,1.0)
	check(state.p1.history[0].targets==[0,1],"first cleave selects actual two farthest tanks")
	previous=actors.duplicate(true);actors[7].pos=Vector2(0,19);Contact.tick(b,actors,previous,state,2.1)
	var cleaves: Array=state.p1.history.filter(func(e):return e.kind=="cleaves")
	check(7 in cleaves[-1].targets and str(state.runtime_failures).contains("furthest"),"second pulse retargets a newly farther non-tank")
	check(float(P.beam(2).width)==6.0,"beam full width is six")
	check(Rules.contains(P.beam(3),Vector2(3,10),actors) and not Rules.contains(P.beam(3),Vector2(3.01,10),actors),"beam edge uses half-width three")
	# Independent absolute Looper deadline fixture: no towers and no numbered-wave shortcut.
	state=fresh();b={"program_loop":{"round":1,"numbers":[1,1,2,2,3,3,4,4]},"shapes":[],"positions":C.repeated(Vector2(0,5))}
	Status.begin(b,state)
	for n in 4:
		state.sim_time=[16.0,25.0,34.0,43.0][n]-0.001;Rules.tick_loop_state(state)
		check(state.loop_memory_loss.size()==n*2,"Looper remains alive just before number %d deadline" % (n+1))
		state.sim_time+=0.001;Rules.tick_loop_state(state)
		check(state.loop_memory_loss.size()==(n+1)*2 and state.dead.size()==(n+1)*2,"actual deadline causes Memory Loss death for number %d" % (n+1))
	state=JSON.parse_string(JSON.stringify(state));Rules.tick_loop_state(state)
	check(state.loop_memory_loss.size()==8,"restored Memory Loss does not duplicate actor IDs")
	state=fresh();Status.begin(b,state);state.sim_time=10.0;Rules.queue_loop_hp(0,state)
	state.sim_time=10.649;Rules.tick_loop_state(state)
	check(not Rules.loop_hp_active(0,state) and state.loop_max_hp[0]==1.0,"HP penalty does not arrive early")
	state.sim_time=10.65;Rules.tick_loop_state(state)
	check(Rules.loop_hp_active(0,state) and state.loop_max_hp[0]==0.01,"delayed HP gain clamps maximum HP to one percent")
	state.sim_time=19.649;Rules.tick_loop_state(state);check(Rules.loop_hp_active(0,state),"P1 HP penalty lasts nine seconds")
	state.sim_time=19.65;Rules.tick_loop_state(state);check(not Rules.loop_hp_active(0,state) and state.loop_max_hp[0]==1.0,"HP cap expires without claiming automatic full healing")
	check(float(Status.parameter("omega_hp_penalty_duration"))==3.0,"Omega HP duration remains three seconds")
	state=fresh();Status.begin(b,state);actors=actors_at(C.repeated(Vector2(0,5)));var errors: Array=[]
	Rules.apply_loop_ruin(0,state,actors,errors,"tower");state.sim_time=10.99;Rules.apply_loop_ruin(0,state,actors,errors,"Blaster")
	check(str(errors).contains("Doom") and 0 in state.dead,"two Ruin hits within eleven seconds cause Doom")
	state=fresh();Status.begin(b,state);errors=[];Rules.apply_loop_ruin(0,state,actors,errors,"tower");state.sim_time=11;Rules.apply_loop_ruin(0,state,actors,errors,"Blaster")
	check(errors.is_empty(),"Ruin expired at eleven seconds permits later hit")
	for policy in ["unverified_exclusive","allow_multiple"]:
		state=fresh();actors=actors_at(C.repeated(Vector2(-10,10)));actors[0].pos=Vector2(12,0);actors[1].pos=Vector2(0,-12);actors[2].pos=Vector2(6,2)
		b={"positions":C.repeated(Vector2(0,5)),"shapes":[],"program_loop":{"round":1,"numbers":[1,1,2,2,3,3,4,4]},"transfers":{"group":"loop","initial":[0,1],"wanted":[2,3],"sources":[Vector2.ZERO,Vector2.ZERO],"activation_delay":5.3,"ownership_policy":policy}}
		b.shapes=[{"kind":"circle","actor":0,"tether_index":0,"radius":15.0,"rule":"blaster","name":"Blaster"}]
		Contact.begin(b,actors,state)
		check(b.tethers.is_empty() and b.program_loop.holders.is_empty() and b.shapes.is_empty(),"future lines and holder previews hidden before activation: "+policy)
		previous=actors.duplicate(true);actors[2].pos=Vector2(6,-2);Contact.tick(b,actors,previous,state,5.0)
		check(state.tether_holders==[0,1],"crossing future line before T5.3 cannot steal: "+policy)
		previous=actors.duplicate(true);actors[2].pos=Vector2(6,2);Contact.tick(b,actors,previous,state,0.6)
		check(state.tether_holders[0]==2 and not b.tethers.is_empty() and b.shapes[0].radius==15.0 and b.shapes[0].actor==2,"real active contact transfers at/after T5.3 and restores complete hazard: "+policy)
	check(is_equal_approx(fposmod(C.safe_sector("aether",0,180),360),270),"Aether fully covered A/C sends G1 west")
	check(is_equal_approx(fposmod(C.safe_sector("lpdu",0,0),360),90),"LPDU fully covered A/C sends G1 east")
	for id in ["cn_moogle","kr_09stop"]:
		check(is_equal_approx(fposmod(C.safe_sector(id,0,0),360),270),id+" fully covered A/C sends high priority west")
		for orientation in range(1,6):
			check(is_equal_approx(fposmod(C.safe_sector(id,orientation*30,0),360),fposmod(orientation*30-90,360)),id+" six-panel initial sectors")
	var samples: Array=[];var repetition:=false
	var profiles: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	for seed_value in range(1,65):
		var ctx=context(profiles[0],seed_value);C.append_loop(ctx);var last_key:=""
		for raw in ctx.beats:
			if not raw.has("program_loop"):continue
			var towers: Array=raw.shapes.filter(func(s):return s.get("looper_tower",false))
			var keys: Array=[]
			for tower in towers:
				var p: Vector2=tower.pos;var x:=roundi(p.x);var y:=roundi(p.y)
				check((absi(x)==3 and absi(y)==12) or (absi(x)==12 and absi(y)==3),"Loop uses actual offset slots")
				keys.append("%d,%d" % [x,y])
			keys.sort();var key:=str(keys)
			if key==last_key:repetition=true
			if key not in samples:samples.append(key)
			last_key=key
	check(samples.size()==12,"Loop generator reaches both offset families, six unordered pairs each")
	check(repetition,"identical consecutive tower pairs remain executable")
func loop_navigation_negatives() -> void:
	# Every ordered initial-owner pair must produce the SAME preactivation
	# movement; knowing the future initial array cannot inform the planner.
	var points:Array=[]
	for i in 8:points.append(Vector2(-3.5+i,6))
	for a in 8:
		for b in 8:
			if a==b:continue
			var actors:=actors_at(points);var state:=fresh()
			var beat:Dictionary={"duration":13.4,"positions":points.duplicate(),"shapes":[],"program_loop":{"round":1,"numbers":[1,1,2,2,3,3,4,4]},"transfers":{"group":"loop","initial":[a,b],"wanted":[4,5],"sources":[Vector2.ZERO,Vector2.ZERO],"activation_delay":5.3,"preposition":points.duplicate()}}
			Contact.begin(beat,actors,state)
			check(range(8).all(func(i):return Contact.bot_goal(i,beat,actors,state)==points[i]),"hidden owners cannot affect preactivation navigation %d/%d"%[a,b])
	var actors:=actors_at([Vector2(3,0),Vector2(0,-3),Vector2(3,1),Vector2(-8,-8),Vector2(-8,-8),Vector2(-8,-8),Vector2(-8,-8),Vector2(-8,-8)])
	var state:=fresh()
	var goals:Array=C.repeated(Vector2(-8,-8));goals[0]=Vector2(17,0);goals[1]=Vector2(0,-17);goals[2]=Vector2(-12,3)
	var beat:Dictionary={"duration":9.0,"positions":goals,"shapes":[],"program_loop":{"round":1,"numbers":[3,3,1,1,2,2,4,4]},"transfers":{"group":"loop","initial":[0,1],"wanted":[0,1],"sources":[Vector2.ZERO,Vector2.ZERO]}}
	Contact.begin(beat,actors,state)
	var before:=actors.duplicate(true)
	var goal:=Contact.bot_goal(0,beat,actors,state)
	check(not state.loop_released and goal.length()<=3.01,"outgoing carrier cannot grow its ray before retiring tower player clears center")
	check(actors==before and state.tether_holders==[0,1],"planning never assigns positions or transfers ownership")
	for policy in ["unverified_exclusive","allow_multiple"]:
		actors=actors_at(C.repeated(Vector2(-10,10)));actors[0].pos=Vector2(12,0);actors[1].pos=Vector2(0,-12);actors[2].pos=Vector2(6,1.5);actors[3].pos=Vector2(1.5,-6)
		state=fresh();beat.transfers.ownership_policy=policy;Contact.begin(beat,actors,state)
		before=actors.duplicate(true);actors[2].pos=Vector2(6,-1.5);actors[3].pos=Vector2(-1.5,-6)
		Contact.tick(beat,actors,before,state,0.5)
		check(state.tether_holders==[2,3] and state.tether_events.size()==2,"human-speed crossings steal both actual lines under "+policy)
		check(Contact.desired_holders(beat)==[0,1],"human deviation remains an incorrect owner outcome under "+policy)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--loop-probe" in args:
		var profiles: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
		var ctx=context(profiles.filter(func(p):return p.id==args[1])[0],int(args[2]));C.append_loop(ctx)
		var state:=simulate(ctx.beats);print(state.runtime_failures);quit(1 if not state.runtime_failures.is_empty() else 0);return
	negative_and_boundaries()
	var profiles: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var loop_only: bool="--loop-only" in args
	if not loop_only:
		panto_and_cannons(profiles)
	if "--events-only" not in args:
		for profile in profiles:
			for seed_value in range(1,49):
				if "--loop-regressions" in args and seed_value not in [3,4,8,16,20,21,46,47]:continue
				var ctx=context(profile,seed_value);C.append_loop(ctx);var state:=simulate(ctx.beats)
				check(state.runtime_failures.is_empty(),"Loop 6/s %s seed %d: %s" % [profile.id,seed_value,str(state.runtime_failures.slice(0,5))])
				check(state.loop_hp_pending.is_empty() and state.loop_max_hp.all(func(hp):return hp==1.0),"full independent Loop course reaches final delayed HP expiry")
	print("P1 event-only Cannons receipts: SIMULATED SynergySigns eligibility, not Arena/native/Web proof")
	print("P1 fidelity: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
func panto_and_cannons(profiles: Array) -> void:
	for orientation in 6:
		for direction in [-1,1]:
			var events:=P.panto(range(8),orientation,direction)
			check(events.filter(func(e):return e.kind=="hazard").size()==28,"14 opposite cone pairs")
			check(events.filter(func(e):return e.kind=="bait").size()==10,"ten eight-player bait locks")
			for n in 14:
				var flames: Array=events.filter(func(e):return e.kind=="hazard" and int(e.pulse)==n)
				check(flames.size()==2 and absf(float(flames[0].at)-(6.1+2*n))<0.00001 and flames.any(func(e):return float(e.shape.angle)==orientation*30+direction*n*30) and absf(float(flames[0].shape.angle)-float(flames[1].shape.angle))==180.0 and flames.all(func(e):return e.shape.width==60.0 and e.shape.radius==65.0),"flame pair timestamp, full geometry and thirty-degree advance")
			var shots: Array=events.filter(func(e):return e.kind=="missile_beam")
			for n in 4: check(shots[n].beams==[[4,5],[6,7],[0,1],[2,3]][n] and shots[n].missiles==[n*2,n*2+1],"actual beam number 3/4/1/2, missile 1/2/3/4")
			for profile in profiles:
				for variant in (["inner_out_outer_return","outer_out_inner_return"] if profile.id=="cn_moogle" else ["inner_out_outer_return"]):
					var ctx=context(profile)
					ctx.profile.p1_orientation=orientation;ctx.profile.p1_direction=direction;ctx.profile.p1_panto_variant=variant
					C.append_panto(ctx)
					var state:=simulate(ctx.beats,orientation==0 and direction==1)
					check(state.runtime_failures.is_empty(),"Panto 6/s %s %d/%d %s: %s" % [profile.id,orientation,direction,variant,str(state.runtime_failures.slice(0,4))])
					check(state.p1.history.filter(func(e):return e.kind=="hazard").size()==108,"28 flames + 80 actual puddles resolve")
	for profile in profiles:
		for a in range(2,6):
			for b in range(a+1,7):
				for c in range(b+1,8):
					for variant in (["static","dynamic"] if profile.id=="aether" else ["static"]):
						var ctx=context(profile);ctx.profile.p1_cannon_marked=[a,b,c];ctx.profile.p1_cannon_variant=variant
						C.append_cannons(ctx);var state:=simulate(ctx.beats,true)
						check(state.runtime_failures.is_empty(),"Cannons %s %s marked %s: %s" % [profile.id,variant,str([a,b,c]),str(state.runtime_failures.slice(0,4))])
						check(state.p1.history.filter(func(e):return e.kind=="cleaves").size()==5 and state.p1.history.filter(func(e):return e.kind=="proteans").size()==2,"five cleaves and both protean waves complete")
						if profile.id=="lpdu":
							ctx=context(profile);ctx.profile.p1_cannon_marked=[a,b,c];ctx.profile.p1_tank_variant="split_mitigated"
							C.append_cannons(ctx);state=simulate(ctx.beats,true)
							check(state.runtime_failures.is_empty(),"LPDU optional split tanks / tighter party spread: "+str([a,b,c]))
