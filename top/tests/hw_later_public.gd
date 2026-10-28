# SPDX-License-Identifier: MIT
extends SceneTree
## Later HW rounds 2-4: public-observation routing. Headless harness only:
## receipts here are "synthetic_runtime_fixture" from the runtime's own synced
## tower shapes (no Arena/visible_damage_shapes); never ordinary actual proof.
const Encounter = preload("res://scripts/encounters.gd")
const Interactions = preload("res://scripts/interactions.gd")
const Movement = preload("res://scripts/movement.gd")
const Rules = preload("res://scripts/rules.gd")
const Runtime = preload("res://scripts/hw_runtime.gd")
const F = preload("res://scripts/hw_firstwave_observation.gd")
const L = preload("res://scripts/hw_later_observation.gd")
var failures: Array=[]

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func profiles() -> Array:
	var methods: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/mechanic_strategies.json"))
	var strategies: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var result: Array=[]
	for method in methods.get("p3_hello",[]):
		for profile in strategies:
			if profile.id==method.profile: result.append(load("res://scripts/strategy_routes.gd").apply(profile,"p3_hello",method.get("overrides",{})))
	return result

# Bot-only run through the real runtime (clock, speeds, physics, statuses).
# stop: {"round":r,"before_reveal":bool} returns the live mid-transition state.
func run(profile: Dictionary, seed_value: int, stop := {}) -> Dictionary:
	var encounter: Dictionary=Encounter.new().build("p3_hello",seed_value,profile,4,-1)
	var state := {"dynamis":encounter.initial_dynamis.duplicate(),"spent":[],"lb":"","lb_actor":-1,"aggro":0,"sim_time":0.0,"seed":encounter.seed,"human_actor":-1}
	var actors: Array=[]
	for index in encounter.beats.size():
		var b: Dictionary=encounter.beats[index].duplicate(true)
		if actors.is_empty():
			for i in 8: actors.append({"role":Encounter.ROLES[i],"pos":Rules.v(b.spawn[i] if b.has("spawn") else b.positions[i]),"face":0.0})
		# Main-like: no in-goal synthetic fallback; harness presents explicitly.
		if b.get("hello_world",false): state.hw_firstwave_presentation_required=true
		Interactions.begin(b,actors,state)
		Movement.begin(b,state)
		var clock := 0.0
		while clock<float(b.duration)-0.000001:
			var dt := minf(0.05,float(b.duration)-clock)
			var previous := actors.duplicate(true)
			for i in 8: actors[i].pos=Rules.v(actors[i].pos).move_toward(Interactions.bot_goal(i,b,actors,state),dt*Movement.speed(b,state,i))
			state.motion_allowances=[]
			for i in 8: state.motion_allowances.append(Movement.speed(b,state,i)*dt)
			Interactions.tick(b,actors,previous,state,dt)
			clock+=dt
			if state.has("hw"):
				Runtime.sync(b,state)
				F._store(b,state,b.get("shapes",[]),"synthetic_runtime_fixture")
				L._store(b,state,b.get("shapes",[]),"synthetic_runtime_fixture")
				if not stop.is_empty() and L.round_of(b)==int(stop.round) and not b.has("hw_later"):
					var reveal: float=float(state.hw.start)+24.0+21.0*int(stop.round)-10.0
					var t: float=float(state.sim_time)
					if (bool(stop.before_reveal) and t<reveal-0.06) or (not bool(stop.before_reveal) and t>reveal+0.5):
						return {"state":state,"actors":actors,"beat":b,"encounter":encounter}
	return {"state":state,"actors":actors,"encounter":encounter}

func goals(beat: Dictionary, actors: Array, state: Dictionary) -> Array:
	var copy: Dictionary=state.duplicate(true)
	var result: Array=[]
	for i in 8: result.append(L.goal(i,beat,actors,copy))
	return result

func _init() -> void:
	var all := profiles()
	check(all.size()>=5,"expected >=5 p3_hello methods, got %d" % all.size())
	for p in all.size():
		var profile: Dictionary=all[p]
		var done: Dictionary=run(profile,1000+p)
		var state: Dictionary=done.state
		# Guide annotation: angle-free locals reproduce authored positions (test oracle only).
		for beat in done.encounter.beats:
			if beat.has("hw_later"):
				var r: int=int(beat.hw_later.round)
				check(r>=1 and r<=3 and beat.hw_later.local.size()==8,"bad hw_later annotation")
		var later: Dictionary=state.hw.get("later_public",{})
		for r in [1,2,3]:
			var entry: Dictionary=later.get("rounds",{}).get(str(r),{})
			check(entry.get("receipt",null) is Dictionary,"%s round %d: no receipt (%s)" % [profile.id,r,str(later.get("reasons",{}))])
			if entry.get("receipt",null) is Dictionary:
				check(str(entry.receipt.source_kind)=="synthetic_runtime_fixture" and bool(entry.receipt.assisted),"harness receipt must stay synthetic/assisted")
				check(int(entry.receipt.orientation)==int(done.encounter.beats.filter(func(b):return b.has("hw_pattern"))[0].hw_pattern.orientations[r]),"%s round %d: received angle differs from drawn towers" % [profile.id,r])
		for item in state.hw.history:
			if str(item.kind)=="hw_tower": check(item.hits.size()==1,"%s tower round %s hits %s" % [profile.id,str(item.round),str(item.hits)])
		check(bool(state.get("hw_later_assisted",false)),"synthetic receipts must mark hw_later_assisted")
	var profile0: Dictionary=all[0] if not all.is_empty() else {}
	for r in [1,2,3]:
		# Isolation (controlled synthetic perturbation of HIDDEN data only).
		var pre: Dictionary=run(profile0,77,{"round":r,"before_reveal":true})
		if not pre.has("beat"): check(false,"round %d: no pre-reveal stop" % r); continue
		var base := goals(pre.beat,pre.actors,pre.state)
		var hidden: Dictionary=pre.beat.duplicate(true); var hidden_state: Dictionary=pre.state.duplicate(true)
		hidden.positions=hidden.positions.map(func(q):return Rules.v(q).rotated(PI*0.75))
		hidden.erase("hw_path")
		for ev in hidden_state.hw.pending:
			if str(ev.kind)=="towers": ev.towers=preload("res://scripts/hw_patterns.gd").towers(posmod(int(r)*3+1,8),"red")
		var hidden_goals := goals(hidden,pre.actors,hidden_state)
		check(str(base)==str(hidden_goals),"round %d: pre-reveal goals depend on hidden data" % r)
		var post: Dictionary=run(profile0,77,{"round":r,"before_reveal":false})
		if not post.has("beat"): check(false,"round %d: no post-reveal stop" % r); continue
		var s: Dictionary=post.state; var b: Dictionary=post.beat; var a: Array=post.actors
		var g0 := goals(b,a,s)
		var hb: Dictionary=b.duplicate(true); var hs: Dictionary=s.duplicate(true)
		hb.positions=hb.positions.map(func(q):return Rules.v(q)*-1.0); hb.erase("hw_path")
		for ev in hs.hw.pending:
			if str(ev.kind)=="towers": ev.towers=[]
		check(str(g0)==str(goals(hb,a,hs)),"round %d: post-reveal goals depend on hidden data" % r)
		# Receipt validation cases (controlled synthetic state edits).
		var now: float=float(s.sim_time)
		var c1: Dictionary=s.duplicate(true); c1.hw.later_public.rounds[str(r)].receipt.at=now+1.0
		check(L._receipt(c1.hw.later_public,r,now)==null,"future receipt accepted")
		var c2: Dictionary=s.duplicate(true); c2.hw.later_public.rounds[str(r)].receipt.origin=-99.0
		check(L._receipt(c2.hw.later_public,r,now)==null,"stale-origin receipt accepted")
		var c3: Dictionary=s.duplicate(true); c3.hw.later_public.rounds[str(r)].receipt.targets=[1,2]
		check(L._receipt(c3.hw.later_public,r,now)==null,"malformed receipt accepted")
		var c4: Dictionary=s.duplicate(true); c4.hw.later_public.rounds[str(r)].erase("receipt")
		var three: Array=b.shapes.filter(func(x):return str(x.get("kind",""))=="tower").slice(0,3)
		check(not L._store(b,c4,three,"arena_presented"),"three-tower receipt accepted")
		var wrong: Array=b.shapes.duplicate(true)
		for x in wrong:
			if str(x.get("kind",""))=="tower": x.hw_round=r+1
		check(not L._store(b,c4,wrong,"arena_presented"),"other-round tower tags accepted")
		var c5: Dictionary=c4.duplicate(true)
		for buffs in c5.statuses:
			for key in ["red","blue","smell_red","smell_blue"]: buffs.erase(key)
		check(not L._store(b,c5,b.shapes,"arena_presented"),"receipt accepted without public carrier rot status")
		var c6: Dictionary=s.duplicate(true)
		L._store(b,c6,b.shapes,"arena_presented")
		check(str(c6.hw.later_public.rounds[str(r)].receipt.source_kind)=="synthetic_runtime_fixture","fixture receipt upgraded to ordinary actual")
		var c7: Dictionary=s.duplicate(true); c7.hw.start=float(c7.hw.start)+500.0
		L._cache(c7)
		check(c7.hw.later_public.rounds.is_empty(),"new-run reset kept old receipts")
		# Absent receipt on a post-judgment beat holds position, never solved goals.
		var later_beat: Dictionary={}
		for x in post.encounter.beats:
			if x.has("hw_later") and int(x.hw_later.round)==r: later_beat=x.duplicate(true); break
		var c8: Dictionary=c4.duplicate(true)
		c8.hw_firstwave_presentation_required=true
		for i in 8: check(L.goal(i,later_beat,a,c8)==Rules.v(a[i].pos),"round %d actor %d: absent receipt fell through" % [r,i])
		# A contradictory actual channel retracts the existing observation;
		# absence alone retains it. No hidden pending geometry can restore it.
		var c10: Dictionary=s.duplicate(true)
		check(L._store(b,c10,[],"arena_presented"),"absence lost historical receipt")
		var conflict: Array=b.shapes.duplicate(true)
		for x in conflict:
			if str(x.get("kind",""))=="tower": x.pos=Rules.v(x.pos).rotated(PI*0.5)
		check(not L._store(b,c10,conflict,"arena_presented") and L._receipt(c10.hw.later_public,r,now)==null,"contradictory displayed channel did not retract")
		check(not L._store(b,c10,b.shapes,"arena_presented"),"blocked round silently rescued by later payload")
		# Human is never auto-moved.
		var c9: Dictionary=s.duplicate(true); c9.human_actor=int(c9.hw.later_public.order[posmod(-2*r,8)])
		check(L.goal(int(c9.human_actor),b,a,c9)==Rules.v(a[int(c9.human_actor)].pos),"human auto-moved")
	for message in failures: printerr("FAIL: "+message)
	print("hw_later_public: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL",failures.size()])
	quit(0 if failures.is_empty() else 1)
