extends SceneTree
# Unit-only gate for Aether conga wiring in scripts/synergy_preparation.gd.
# NOT actual Main / player physics / full-guide proof; parent owns those gates.
const Prep=preload("res://scripts/synergy_preparation.gd")
const Conga=preload("res://scripts/aether_conga.gd")
const KEY="synergy_preparation"
var checks:int=0
var failures:Array=[]

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<80:failures.append(label)

func beat(phase:String,profile:String="aether",remote:bool=false)->Dictionary:
	var pub:Dictionary=Prep.config(profile)
	pub.merge({"phase":phase,"eye_angle":0.0,"remote":remote,"north":0.0})
	return {"synergy_public":pub,"positions":[],"duration":3.0}

func line_actors(xs:Array)->Array:
	var result:Array=[]
	for i in 8:result.append({"role":"r%d"%i,"pos":Vector2(float(xs[i]),0.0),"face":0.0})
	return result

func default_actors()->Array:
	var result:Array=[]
	var spawn:Array=Prep.aether_spawn()
	for i in 8:result.append({"role":"r%d"%i,"pos":spawn[i],"face":0.0})
	return result

func glyphs(symbols:Array)->Array:
	var result:Array=[]
	for a in 8:result.append({"actor":a,"symbol":symbols[a]})
	return result

func fresh(ordinary:bool=true,human:int=0)->Dictionary:
	var state:Dictionary={"sim_time":0.0,"human_actor":human,"synergy_presentation_required":ordinary}
	Prep.begin(beat("cast"),state)
	return state

func blocked(state:Dictionary)->bool:
	return bool(state[KEY].blocked)

const SYMBOLS:=["cross","square","circle","triangle","cross","square","circle","triangle"]

func config_cases()->void:
	check(Prep.config("elemental")=={"profile_id":"elemental","left":[2,0,4,6],"right":[3,1,5,7],"shape_order":["circle","cross","triangle","square"]},"config:elemental_exact")
	check(Prep.config("lpdu")=={"profile_id":"lpdu","left":[0,2,4,6],"right":[1,3,5,7],"shape_order":["cross","square","circle","triangle"]},"config:lpdu_exact")
	check(Prep.config("aether").default_order==[2,6,4,0,1,5,7,3],"config:aether_default_order")
	check(Prep.config("aether").shape_order==["cross","square","circle","triangle"],"config:aether_shape_order")
	check(Prep.config("cn_moogle").is_empty(),"config:other_profile_empty")
	check(not Prep.selection(beat("cast")).is_empty(),"selection:aether_valid")
	var b:Dictionary=beat("cast");b.synergy_public.default_order=[0,1,2,3,4,5,6,7]
	check(Prep.selection(b).is_empty(),"selection:reject_wrong_order")
	b=beat("cast");b.synergy_public.erase("mode")
	check(Prep.selection(b).is_empty(),"selection:reject_missing_mode")
	b=beat("cast");b.synergy_public.left=[0,2,4,6]
	check(Prep.selection(b).is_empty(),"selection:reject_lpdu_keys_in_aether")
	b=beat("cast","elemental");b.synergy_public.mode="conga"
	check(Prep.selection(b).is_empty(),"selection:reject_conga_keys_in_elemental")
	check(not Prep.selection(beat("cast","elemental")).is_empty() and not Prep.selection(beat("cast","lpdu")).is_empty(),"selection:old_profiles_valid")
	var spawn:Array=Prep.aether_spawn()
	check(spawn[2].x<spawn[6].x and spawn[6].x<spawn[4].x and spawn[4].x<spawn[0].x and spawn[0].x<spawn[1].x and spawn[3].x>spawn[7].x,"spawn:default_line_order")
	check(Prep.queue_goal(5,{},"aether")==spawn[5],"spawn:queue_goal_default_fixture")

func formation_cases()->void:
	var state:Dictionary=fresh(true,0)
	var cast:Dictionary=beat("cast")
	var actors:Array=line_actors([5.0,-6.0,-4.0,-2.0,0.0,2.0,4.0,6.0])
	check(state[KEY].glyphs.is_empty() and state[KEY].positions==null,"noglyph:empty_memory")
	var goals:Array=[]
	for i in 8:
		var g:Vector2=Prep.goal(i,cast,actors,state)
		goals.append(g)
		actors[i].pos=Vector2(99.0,99.0) if i!=0 else actors[i].pos # partial move must not re-snapshot
	var expected:Dictionary=Conga.npc_line_goals(Prep.pose_snapshot(line_actors([5.0,-6.0,-4.0,-2.0,0.0,2.0,4.0,6.0])),0,[])
	var ok:bool=true
	for a in expected.goals:ok=ok and goals[a].is_equal_approx(expected.goals[a])
	check(ok,"formation:coherent_same_clock_snapshot")
	check(int(state[KEY].formation.reserved_slot)==6,"formation:human_x5_reserves_slot6")
	check(JSON.parse_string(JSON.stringify(state[KEY].formation)) is Dictionary,"formation:json_safe")
	# Human actually moves west; next clock reserves a different rank.
	state.sim_time=0.05
	actors=line_actors([-6.2,-6.0,-4.0,-2.0,0.0,2.0,4.0,6.0])
	Prep.goal(1,cast,actors,state)
	check(int(state[KEY].formation.reserved_slot)==0,"formation:human_rank_change_follows_actual_x")
	check(0 not in state[KEY].formation.order,"formation:human_not_moved")
	# Equal NPC x ties keep previous observed order (not actor id/role).
	var prev:Array=state[KEY].formation.order.duplicate()
	state.sim_time=0.1
	actors=line_actors([-6.2,1.0,1.0,1.0,1.0,1.0,1.0,1.0])
	Prep.goal(1,cast,actors,state)
	check(state[KEY].formation.order==prev,"formation:tie_stable_previous_order")
	# Remember before freeze still uses formation; sync clears cache.
	Prep.tick(beat("remember"),state)
	check(not state[KEY].has("formation"),"formation:sync_clears_cache")

func freeze_cases()->void:
	var state:Dictionary=fresh(true,0)
	var rem:Dictionary=beat("remember")
	state.sim_time=3.2
	var actors:Array=default_actors()
	# Ordinary mode rejects headless basis.
	var s2:Dictionary=state.duplicate(true)
	Prep.publish(rem,s2,glyphs(SYMBOLS),"headless_public_statuses_not_displayed",actors)
	check(blocked(s2),"basis:ordinary_requires_displayed")
	# Position-less publication (sync) is silent, not a receipt or reject.
	var s3:Dictionary=state.duplicate(true)
	Prep.publish(rem,s3,glyphs(SYMBOLS))
	check(not blocked(s3) and s3[KEY].glyphs.is_empty(),"sync:no_actors_no_receipt")
	# Human (MT=0) crosses its cross-partner (H1=2) before display: actual x decides.
	var crossed:Array=default_actors()
	var p0:Vector2=crossed[0].pos;crossed[0].pos=crossed[4].pos;crossed[4].pos=p0
	var s4:Dictionary=state.duplicate(true)
	Prep.publish(rem,s4,glyphs(SYMBOLS),"displayed_textured_glyphs",crossed)
	check(not blocked(s4),"freeze:accepted")
	var mem:Dictionary=Prep.memory(rem,s4)
	check(not mem.is_empty() and mem.positions.size()==8 and mem.positions[0]==[float(crossed[0].pos.x),float(crossed[0].pos.y)],"freeze:json_positions")
	check(mem.positions_at==3.2 and mem.positions_basis=="displayed_textured_glyphs" and mem.positions_profile=="aether","freeze:metadata")
	check(JSON.parse_string(JSON.stringify(mem)) is Dictionary,"freeze:json_safe")
	var asg:Dictionary=Prep.assignment_of(mem.glyphs,mem,"aether")
	var direct:Dictionary=Conga.assign(glyphs(SYMBOLS),Prep.pose_snapshot(crossed))
	check(asg==direct,"freeze:assignment_from_actual_poses")
	var baseline:Dictionary=Conga.assign(glyphs(SYMBOLS),Prep.aether_spawn())
	check(asg.actor_sides!=baseline.actor_sides,"freeze:human_crossing_changes_groups")
	# Repeat after actors move: frozen past retained exactly.
	var frozen:Array=mem.positions.duplicate(true)
	var moved:Array=default_actors()
	for a in moved:a.pos=Vector2(-a.pos.x,3.0)
	s4.sim_time=3.4
	Prep.publish(rem,s4,glyphs(SYMBOLS),"displayed_textured_glyphs",moved)
	check(not blocked(s4) and s4[KEY].positions==frozen and float(s4[KEY].at)==3.2,"repeat:frozen_past_retained")
	check(Prep.goal(1,rem,moved,s4)==Vector2(frozen[1][0],frozen[1][1]),"repeat:npc_holds_frozen_pose")
	check(Prep.goal(1,beat("appear"),moved,s4)==Vector2(frozen[1][0],frozen[1][1]),"appear:npc_holds_frozen_pose")
	# Contradictory repeat glyph rejects.
	var s5:Dictionary=s4.duplicate(true)
	var swapped:Array=SYMBOLS.duplicate();swapped[0]="square";swapped[1]="cross"
	Prep.publish(rem,s5,glyphs(swapped),"displayed_textured_glyphs",moved)
	check(blocked(s5),"repeat:contradictory_rejects")
	# Unrelated actor moved before display: legal, recorded.
	var unrelated:Array=default_actors();unrelated[7].pos.y=2.5
	var s6:Dictionary=state.duplicate(true)
	Prep.publish(rem,s6,glyphs(SYMBOLS),"displayed_textured_glyphs",unrelated)
	check(not blocked(s6) and s6[KEY].positions[7][1]==2.5,"freeze:unrelated_move_recorded")
	# Assisted path keeps assisted basis.
	var s7:Dictionary=state.duplicate(true);s7.synergy_checkpoint_assisted=true
	Prep.publish(rem,s7,glyphs(SYMBOLS),"assisted_checkpoint_not_observed",actors)
	check(not blocked(s7) and s7[KEY].positions_basis=="assisted_checkpoint_not_observed" and not Prep.memory(rem,s7).is_empty(),"assisted:distinct_basis")
	# Headless synthetic mode (no presentation) accepts headless basis via observe.
	var s8:Dictionary=fresh(false,-1);s8.sim_time=3.2
	Prep.publish(rem,s8,glyphs(SYMBOLS),"headless_public_statuses_not_displayed",actors)
	check(not blocked(s8) and s8[KEY].positions_basis=="headless_public_statuses_not_displayed","headless:distinct_basis")
	# Fresh cast clears.
	Prep.begin(beat("cast"),s4)
	check(s4[KEY].glyphs.is_empty() and s4[KEY].positions==null and not s4[KEY].has("formation"),"fresh_cast:clears")

func reject_cases()->void:
	var rem:Dictionary=beat("remember")
	var base:Dictionary=fresh(true,0);base.sim_time=3.2
	var actors:Array=default_actors()
	var cases:Dictionary={}
	var wrong:Array=SYMBOLS.duplicate();wrong[0]="stack"
	cases["wrong_symbol"]=[glyphs(wrong),actors]
	cases["missing_glyph"]=[glyphs(SYMBOLS).slice(0,7),actors]
	var nan:Array=default_actors();nan[3].pos=Vector2(NAN,0.0)
	cases["nonfinite_pose"]=[glyphs(SYMBOLS),nan]
	cases["missing_pose"]=[glyphs(SYMBOLS),default_actors().slice(0,7)]
	var tie:Array=default_actors();tie[4].pos.x=tie[0].pos.x # MT & H1 share cross
	cases["same_pair_tie"]=[glyphs(SYMBOLS),tie]
	for label in cases:
		var s:Dictionary=base.duplicate(true)
		Prep.publish(rem,s,cases[label][0],"displayed_textured_glyphs",cases[label][1])
		check(blocked(s),"reject:"+label)
		check(Prep.goal(5,rem,actors,s)==actors[5].pos,"reject_holds_actual:"+label)
	# Invalid public memory must hold in every phase, including the old dodge baseline.
	var poisoned:Dictionary=base.duplicate(true)
	Prep.reject(poisoned,"parent_invalid_receipt_fixture")
	var dodge:Dictionary=beat("dodge")
	dodge.positions=range(8).map(func(_a):return Vector2(18.0,0.0))
	check(Prep.goal(5,dodge,actors,poisoned)==actors[5].pos,"invalid:dodge_must_not_fallback_to_baked_route")
	# Different-symbol tie is legal.
	var legal:Array=default_actors();legal[1].pos.x=legal[0].pos.x # MT cross, ST square
	var ok:Dictionary=base.duplicate(true)
	Prep.publish(rem,ok,glyphs(SYMBOLS),"displayed_textured_glyphs",legal)
	check(not blocked(ok),"tie:different_symbol_legal")
	# Outside window.
	var early:Dictionary=fresh(true,0);early.sim_time=2.0
	Prep.publish(rem,early,glyphs(SYMBOLS),"displayed_textured_glyphs",actors)
	check(blocked(early),"reject:outside_window")
	# Cached validation.
	var good:Dictionary=base.duplicate(true)
	Prep.publish(rem,good,glyphs(SYMBOLS),"displayed_textured_glyphs",actors)
	check(not Prep.memory(rem,good).is_empty(),"cache:valid")
	var t:Dictionary=good.duplicate(true);t[KEY].positions_at=3.25
	check(Prep.memory(rem,t).is_empty(),"cache:positions_time_mismatch")
	t=good.duplicate(true);t[KEY].at=9.0;t[KEY].positions_at=9.0
	check(Prep.memory(rem,t).is_empty(),"cache:future_or_out_of_window")
	t=good.duplicate(true);t[KEY].positions[2]=[INF,0.0]
	check(Prep.memory(rem,t).is_empty(),"cache:nonfinite_positions")
	t=good.duplicate(true);t[KEY].positions_basis="headless_public_statuses_not_displayed"
	check(Prep.memory(rem,t).is_empty(),"cache:basis_mismatch")
	t=good.duplicate(true);t[KEY].positions_profile="lpdu"
	check(Prep.memory(rem,t).is_empty(),"cache:positions_profile_mismatch")
	check(Prep.memory(beat("remember","lpdu"),good).is_empty(),"cache:cross_profile_rejects")
	t=good.duplicate(true);t[KEY].profile_id="elemental"
	check(Prep.memory(rem,t).is_empty(),"cache:aether_beat_rejects_elemental_memory")

func route_cases()->void:
	var asg:Dictionary=Conga.assign(glyphs(SYMBOLS),Prep.aether_spawn())
	var lp:Dictionary=asg.duplicate(true);lp.profile_id="lpdu"
	# Remote: Aether swaps outer rows (ranks 0/3) only; LPDU full reverse.
	var r1:int=int(asg.route_order[3])
	check(Prep.fire_goal(r1,asg,true,0.0).y==Prep.fire_goal(int(asg.route_order[2]),asg,true,0.0).y,"remote:aether_inner_row_not_swapped")
	check(Prep.fire_goal(r1,lp,true,0.0).y==-Prep.fire_goal(r1,asg,true,0.0).y,"remote:lpdu_full_reverse")
	var r0:int=int(asg.route_order[1])
	check(is_equal_approx(Prep.fire_goal(r0,asg,true,0.0).y,-Prep.fire_goal(int(asg.route_order[0]),asg,true,0.0).y),"remote:aether_outer_row_swapped")
	# North flex: same-side stack targets -> north-most (smaller de-rotated y) swaps.
	var left:Array=[int(asg.route_order[0]),int(asg.route_order[2])]
	var north_actor:int=left[0] if Prep.fire_goal(left[0],asg,false,0.0).y<Prep.fire_goal(left[1],asg,false,0.0).y else left[1]
	var south_actor:int=left[1] if north_actor==left[0] else left[0]
	var g:Array=Prep.knock_goals(asg,left,false,0.0,0.0)
	var right_ref:int=int(asg.route_order[7])
	check(g[north_actor].distance_to(g[right_ref])<0.5,"flex:aether_north_moves")
	check(g[south_actor].distance_to(g[right_ref])>1.0,"flex:aether_south_stays")
	var el:Dictionary=asg.duplicate(true);el.profile_id="elemental"
	var ge:Array=Prep.knock_goals(el,left,false,0.0,0.0)
	check(ge[south_actor].distance_to(ge[right_ref])<0.5,"flex:other_profiles_unchanged_south")

func _init()->void:
	config_cases()
	formation_cases()
	freeze_cases()
	reject_cases()
	route_cases()
	print("AETHER_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures.size(),"failure_labels":failures,"scope":"unit_only_not_main_physics"}))
	quit(0 if failures.is_empty() else 1)
