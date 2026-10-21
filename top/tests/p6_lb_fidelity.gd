extends SceneTree
const LB = preload("res://scripts/p6_lb.gd")
const R = preload("res://scripts/p6_runtime.gd")
const C = preload("res://scripts/p6_courses.gd")
const P = preload("res://scripts/p6_patterns.gd")
const D = preload("res://scripts/p6_damage.gd")
const E = preload("res://scripts/encounters.gd")
const S = preload("res://scripts/statuses.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok: failures+=1; print("LB FAIL: ",message)

func actors() -> Array:
	var result: Array=[]
	for i in 8: result.append({"pos":Vector2(0,-16) if i==6 else Vector2.ZERO,"face":0.0})
	return result

func fresh(a: Array) -> Dictionary:
	var state := {"sim_time":0.0,"dynamis":[3,3,3,3,3,3,3,3],"spent":[]}
	S.ensure(state)
	LB.begin(state,a,{"jobs":["DRK","PLD","AST","SCH","MNK","NIN","BRD","PCT"],"gauge":30000,"brilliant":range(8)})
	return state

func advance(a: Array, state: Dictionary, seconds: float) -> void:
	state.sim_time=float(state.sim_time)+seconds
	LB.tick(a,a.duplicate(true),state,seconds)

func course(ctx, a: Array, state: Dictionary) -> void:
	for b in ctx.beats:
		R.begin(b,state)
		var elapsed := 0.0
		while elapsed<float(b.duration)-0.000001:
			var dt := minf(0.05,float(b.duration)-elapsed)
			var previous := a.duplicate(true)
			for i in 8:
				if not LB.is_locked(state,i): a[i].pos=a[i].pos.move_toward(b.positions[i],6.0*dt)
			state.sim_time=float(state.sim_time)+dt
			R.tick(a,previous,state,dt); elapsed+=dt

func context():
	var ctx=E.new(); ctx.profile={"id":"elemental"}; ctx.positions=C.repeated(Vector2.ZERO); ctx.labels=["","","","","","","",""]; ctx.rng.seed=17
	return ctx

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var a := actors(); var state := fresh(a)
	LB.spawn_meteors(state)
	check(state.p6_lb.targets.size()==8,"Six distinct comets plus two meteors")
	check(not LB.request_lb(state,6,"caster",[0,0]).ok,"Human wrong job rejected")
	state.p6_lb.gauge=29999
	check(not LB.request_lb(state,7,"caster",[0,0]).ok,"Insufficient shared gauge rejected")
	state.p6_lb.gauge=30000; state.dynamis[7]=2
	check(not LB.request_lb(state,7,"caster",[0,0]).ok,"Insufficient Dynamis rejected")
	state.dynamis[7]=3; state.spent=[7]
	check(not LB.request_lb(state,7,"caster",[0,0]).ok,"Spent Brilliant rejected")
	state.spent=[]
	check(not LB.request_lb(state,7,"caster",[26,0]).ok,"Ground target out of range")
	check(LB.request_lb(state,7,"caster",[0,0]).ok,"Caster starts a real 4.5 second cast")
	check(not LB.request_lb(state,6,"ranged","meteor_1").ok,"Concurrent gauge reservation rejected")
	advance(a,state,2.0)
	state=JSON.parse_string(JSON.stringify(state))
	check(LB.is_locked(state,7),"JSON checkpoint remains locked during cast")
	advance(a,state,2.49)
	check(LB.is_locked(state,7) and state.p6_lb.gauge==30000,"No early finish or gauge consumption")
	advance(a,state,0.01)
	check(not LB.is_locked(state,7) and state.p6_lb.gauge==0,"Cast completes and consumes gauge")
	check(state.p6_lb.targets.all(func(n):return n.hp==n.max_hp),"Cast snapshot does not instantly kill NPCs")
	advance(a,state,5.05)
	check(state.p6_lb.gauge==30000 and 7 in state.spent,"Actual Brilliant refund event and common spent state")
	advance(a,state,0.55)
	check(state.p6_lb.targets.filter(func(n):return n.npc_id==15727 and n.hp==0).size()==6,"All six comets killed by delayed caster damage")
	check(state.p6_lb.targets.filter(func(n):return n.npc_id==15726 and n.hp>0 and n.hp<n.max_hp).size()==2,"Caster also damages BOTH large meteors")
	check(not LB.request_lb(state,6,"ranged","comet_0").ok,"Dead target rejected")
	check(LB.request_lb(state,6,"ranged","meteor_1").ok,"Ranged targets real south meteor from north")
	advance(a,state,8.0)
	check(state.p6_lb.targets.all(func(n):return n.hp==0),"Actual corridor kills both large meteors")
	state=fresh(a); LB.spawn_meteors(state); LB.request_lb(state,7,"caster",[15,0]); advance(a,state,10.1)
	check(state.p6_lb.targets.any(func(n):return n.npc_id==15727 and n.hp>0),"Misplaced caster circle misses comets")
	state=fresh(a); LB.spawn_meteors(state); LB.request_lb(state,7,"caster",[0,0])
	var previous := a.duplicate(true); a[7].pos=Vector2(1,0); state.sim_time=1.0; LB.tick(a,previous,state,1.0)
	check(state.p6_lb.casts.is_empty() and state.p6_lb.gauge==30000 and state.spent.is_empty(),"Movement interrupts before spending gauge/Brilliant")
	a=actors(); state=fresh(a); LB.spawn_meteors(state)
	a[6].pos=Vector2(16,0); LB.sync(a,state); LB.request_lb(state,6,"ranged","meteor_0"); advance(a,state,8.0)
	check(state.p6_lb.targets.filter(func(n):return n.npc_id==15726 and n.hp==n.max_hp).size()==1,"Sideways ranged aim misses other meteor")
	state=fresh(a); state.p6_lb.doom=[{"expires":6.0,"targets":range(8)}]; state.sim_time=5.9
	check(LB.request_lb(state,2,"healer").ok,"Late healer can start but does not cleanse instantly")
	advance(a,state,2.0)
	check(state.dead.size()==8 and not state.runtime_failures.is_empty(),"F at Doom 5.9 seconds fails even in one large tick")
	state=fresh(a); state.p6_lb.doom=[{"expires":6.0,"targets":range(8)}]; state.sim_time=3.9
	LB.request_lb(state,2,"healer"); advance(a,state,2.0)
	check(state.dead.is_empty() and state.p6_lb.doom.is_empty(),"Healer finishes before expiry")
	state=fresh(a); LB.request_lb(state,0,"tank"); advance(a,state,0.01)
	check(not LB.tank_active(state,1.0),"Tank action does not immediately apply protection")
	advance(a,state,2.3)
	check(LB.tank_active(state,2.3) and not LB.tank_active(state,10.3),"Tank buff application offset and eight-second duration")
	state=fresh(a); state.p6_lb.brilliant=[]; state.p6_lb.memory_entry=true; state.p6_auto_lb=true
	var ctx=context(); C.append_memory(ctx); course(ctx,a,state)
	check(state.dead.is_empty() and state.p6_lb.brilliant.size()==8,"Actual memory tank action plus three stacks grants Brilliant")
	a=actors(); state=fresh(a); state.p6_auto_lb=true; ctx=context(); C.append_magic(ctx); course(ctx,a,state)
	check(state.runtime_failures.is_empty() and state.dead.is_empty(),"Both Magic Number iterations with actual casts")
	check(state.p6_lb.history.filter(func(e):return e.kind=="lb_finish").size()==4,"Two distinct tanks and two healers finish")
	check(state.p6_lb.gauge==30000 and state.spent.size()==4,"Final gauge comes from second healer refund")
	state=fresh(a); state.lb="tank"; state.lb_actor=0; ctx=context(); C.append_magic(ctx); course(ctx,a,state)
	check(not state.runtime_failures.is_empty(),"Legacy instant LB flag cannot satisfy Magic Number")
	state=fresh(a); state.p6={}; D.flares(a,[0,1,2],state)
	check(not state.runtime_failures.is_empty(),"Close flares fail closed without arbitrary safe radius")
	check(D.flare_bounds(10,false).upper==null,"Unsampled interior remains genuinely unknown")
	state.p6_hp=[{"hp":100.0,"shield":20.0}]; state.dead=[]
	var packet := D.apply_packet(state,0,100,0.5)
	check(packet.remaining==70 and packet.absorbed==20,"Explicit mitigation and shields, no automatic heal")
	a=actors(); state=fresh(a); state.p6_lb.animation_seconds={"PCT":1.5}; LB.spawn_meteors(state)
	LB.request_lb(state,7,"caster",[0,0]); advance(a,state,4.5)
	check(LB.is_locked(state,7),"Explicit job animation calibration extends cast lock")
	state=JSON.parse_string(JSON.stringify(state)); advance(a,state,1.49)
	check(LB.is_locked(state,7),"Animation lock persists through JSON restore")
	advance(a,state,0.01)
	check(not LB.is_locked(state,7),"Explicit animation unlock event")
	a=actors(); state=fresh(a); LB.spawn_meteors(state); state.sim_time=12.0
	LB.request_lb(state,7,"caster",[0,0]); advance(a,state,8.5)
	state.p6={"pending":[],"history":[],"locks":[],"until":30.0}
	R.resolve({"at":20.5,"kind":"meteor_deadline","npc_id":15727},a,state)
	check(state.dead.size()==8,"Late caster finish/damage cannot pass comet deadline")
	a=actors(); state=fresh(a); state.p6={"pending":[],"history":[],"locks":[],"until":30.0}
	R.resolve({"at":20.5,"kind":"meteor_deadline","npc_id":15727},a,state)
	check(state.dead.size()==8,"Missing all NPCs cannot vacuously satisfy kill requirement")
	a=actors(); state=fresh(a); LB.spawn_meteors(state); LB.request_lb(state,6,"ranged","meteor_1")
	state.p6_lb.targets[-1].hp=0; advance(a,state,4.5)
	check(state.p6_lb.gauge==30000 and state.spent.is_empty(),"Selected meteor dying during cast interrupts without consumption")
	for id in ["elemental","aether","lpdu","cn_moogle","kr_09stop"]:
		for flares in P.flare_combinations():
			a=actors(); state=fresh(a); state.p6_auto_lb=true; ctx=context(); ctx.profile.id=id; C.append_meteor_combination(ctx,flares); course(ctx,a,state)
			check(state.runtime_failures.is_empty(),"Real locked meteor route "+id+str(flares))
			check(state.p6_lb.targets.all(func(n):return n.hp==0),"All eight real LB targets die "+id+str(flares))
	a=actors(); state=fresh(a); state.p6_auto_lb=true; state.human_actor=7; ctx=context(); C.append_meteor_combination(ctx,[0,1,2]); course(ctx,a,state)
	check(not state.runtime_failures.is_empty(),"Bots cannot cast the human's missing caster LB")
	check(state.p6_lb.history.filter(func(e):return e.kind=="lb_finish" and int(e.actor)==7).is_empty(),"No fabricated human finish")
	print("P6 LB FIDELITY assertions=",assertions," failures=",failures)
	quit(1 if failures else 0)
