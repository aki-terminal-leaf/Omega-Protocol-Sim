extends SceneTree
const LB = preload("res://scripts/p6_lb.gd")
const D = preload("res://scripts/p6_damage.gd")
const R = preload("res://scripts/p6_runtime.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; print("PRECISION FAIL: ",message)

func actors() -> Array:
	var a: Array=[]
	for i in 8: a.append({"pos":Vector2.ZERO,"face":0.0})
	return a

func fresh(a: Array) -> Dictionary:
	var s := {"sim_time":0.0,"dynamis":[3,3,3,3,3,3,3,3],"spent":[],"dead":[],"runtime_failures":[],"timeline":[],"p6":{"pending":[],"history":[],"locks":[],"until":40.0}}
	LB.begin(s,a,{"jobs":["PLD","WAR","WHM","SCH","DRG","MNK","BRD","SMN"],"gauge":30000,"brilliant":range(8),"animation_seconds":{"BRD":3.7,"SMN":8.1}})
	return s

func npc(id: String, p: Vector2) -> Dictionary:
	return {"id":id,"npc_id":15726,"pos":[p.x,p.y],"hp":482324,"max_hp":482324,"targetable":true}

func advance(s: Dictionary, a: Array, time: float) -> void:
	var dt := time-float(s.sim_time); s.sim_time=time
	LB.tick(a,a.duplicate(true),s,dt)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var a := actors()
	# These certify the declared training rectangle, NOT server hitbox edges.
	for point in [Vector2(8,15),Vector2(8.001,15),Vector2(-8,15),Vector2(-8.001,15),Vector2(0,-0.001),Vector2(0,30),Vector2(0,30.001)]:
		var s := fresh(a)
		s.p6_lb.targets=[npc("aim",Vector2(0,20)),npc("probe",point)]
		check(LB.request_lb(s,6,"ranged","aim").ok,"Ranged boundary fixture starts")
		advance(s,a,4.5)
		check(LB.is_locked(s,6),"Real ranged postlock applies")
		advance(s,a,8.0)
		var expected: bool = absf(point.x)<=8 and point.y>=0 and point.y<=30
		check((s.p6_lb.targets[1].hp<482324)==expected,"Training corridor edge "+str(point))
	var s := fresh(a)
	s.p6_lb.targets=[npc("aim",Vector2(0,20)),npc("old_axis",Vector2(0,15)),npc("new_axis",Vector2(15,0))]
	LB.request_lb(s,6,"ranged","aim")
	s.p6_lb.targets[0].pos=[20,0]
	advance(s,a,4.5)
	s=JSON.parse_string(JSON.stringify(s))
	s.p6_lb.targets[0].pos=[0,20]
	advance(s,a,8.0)
	check(s.p6_lb.targets[1].hp==482324 and s.p6_lb.targets[2].hp<482324,"Moving target aims at finish; delayed damage retains snapshot through JSON")
	for mode in ["dead","untargetable","removed"]:
		s=fresh(a); s.p6_lb.targets=[npc("aim",Vector2(0,20))]
		LB.request_lb(s,6,"ranged","aim")
		match mode:
			"dead": s.p6_lb.targets[0].hp=0
			"untargetable": s.p6_lb.targets[0].targetable=false
			"removed": s.p6_lb.targets=[]
		advance(s,a,4.5)
		check(s.p6_lb.gauge==30000 and s.spent.is_empty() and s.p6_lb.effects.is_empty(),"Invalid completion preserves resources: "+mode)
	# Nonzero world origin must translate both circle and line geometry.
	a[6].pos=Vector2(5,-4); s=fresh(a)
	s.p6_lb.targets=[npc("aim",Vector2(5,16)),npc("behind",Vector2(5,-4.01))]
	LB.request_lb(s,6,"ranged","aim"); advance(s,a,8.0)
	check(s.p6_lb.targets[0].hp<482324 and s.p6_lb.targets[1].hp==482324,"Ranged origin is actor position")
	a=actors()
	for distance in [14.999,15.0,15.001]:
		s=fresh(a); s.p6_lb.targets=[npc("probe",Vector2(distance,0))]
		LB.request_lb(s,7,"caster",[0,0]); advance(s,a,10.1)
		check((s.p6_lb.targets[0].hp<482324)==(distance<=15),"Caster training center boundary")
		check(LB.is_locked(s,7),"Caster remains postlocked after damage")
	# Practice checkpoint boundary, deliberately not an inferred NPC enrage.
	for offset in [-0.001,0.0,0.001]:
		s=fresh(a); LB.spawn_meteors(s)
		s.p6.pending=[{"at":30.5,"kind":"meteor_deadline","npc_id":15726}]
		s.p6_lb.effects=[{"kind":"damage","at":30.5+offset,"actor":6,"targets":["meteor_0","meteor_1"],"amount":500000,"cast_id":1}]
		s.sim_time=30.501; R.tick(a,a.duplicate(true),s,30.501)
		check(s.dead.is_empty()==(offset<=0),"Checkpoint at/before/after packet ordering")
		check(not s.p6.history[0].server_deadline_verified,"Checkpoint never reports original enrage verified")
	for distance in [0.0,10.0,19.292,37.088,50.0]:
		var b := D.flare_bounds(distance,distance==0)
		check(b.upper==null and not b.known,"No universal flare upper bound at "+str(distance))
	for invalid in [NAN,INF,-1.0]:
		var bound := D.flare_bounds(invalid,false)
		check(bound.upper==null and not bound.known,"Invalid distance cannot prove survival")
	var damage_state := {"p6_hp":[{"hp":100.0,"shield":25.0}],"dead":[]}
	for invalid in [NAN,INF]:
		check(not D.apply_packet(damage_state,0,invalid).ok,"Invalid damage rejected")
		check(not D.apply_packet(damage_state,0,10.0,invalid).ok,"Invalid mitigation rejected")
	check(damage_state.p6_hp[0].hp==100.0 and damage_state.p6_hp[0].shield==25.0,"Invalid numeric packets preserve HP and shields")
	s=fresh(a); D.flares(a,[0,1,2],s)
	check(not s.runtime_failures.is_empty(),"Interior uncertainty still rejects practice survival")
	print("P6 precision: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)
