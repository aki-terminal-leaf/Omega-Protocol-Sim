# SPDX-License-Identifier: MIT
extends RefCounted
const P = preload("res://scripts/p3_transition_patterns.gd")
const Rules = preload("res://scripts/rules.gd")
static func append_course(ctx) -> void: append_transition(ctx)
static func append_transition(ctx) -> void:
	append_family(ctx,int(ctx.profile.get("p3_transition_arm_first",ctx.rng.randi_range(0,1))),int(ctx.profile.get("p3_transition_sample",2)),ctx.profile.get("p3_transition_purple",ctx.order.slice(0,4)),ctx.profile.get("p3_transition_white",ctx.order.slice(4,6)))
static func ranked(values: Array, priority: Array) -> Array:
	var result: Array=values.map(func(a):return int(a))
	var normalized: Array=priority.map(func(a):return int(a))
	result.sort_custom(func(a,b):return normalized.find(a)<normalized.find(b))
	return result
static func slots(route: Dictionary, purple: Array, white: Array) -> Array:
	assert(P.valid_partition(purple,white))
	var result: Array=[]; result.resize(8)
	var empty: Array=[]
	for a in 8:
		if a not in purple and a not in white: empty.append(a)
	var p:=ranked(purple,route.priority); var w:=ranked(white,route.priority); var n:=ranked(empty,route.priority)
	for i in 4: result[p[i]]=float(route.purple_angles[i])
	for i in 2:
		result[w[i]]=float(route.white_angles[i]); result[n[i]]=float(route.white_angles[i])
	return result
static func pocket(nominal: float, first: int) -> Array:
	# Six legal pockets adjacent to the FIRST arms, avoiding the second wave.
	# Numerical training realization; neither angles nor radii claim official guide coordinates.
	var best: Array=[]; var error:=1000.0
	for i in 3:
		var center:=float(first*60+i*120)
		for sign_value in [-1,1]:
			var angle: float=center+sign_value*16.0
			var distance:=absf(wrapf(nominal-angle,-180,180))
			if distance<error:
				error=distance; best=[angle,center+sign_value*46.0]
	return best
static func points(assignments: Array, first: int, radius: float, final_pocket: bool) -> Array:
	var result: Array=[]
	for nominal in assignments:
		var angles:=pocket(float(nominal),first)
		result.append(Rules.direction(float(angles[0 if final_pocket else 1]))*radius)
	return result
static func append_family(ctx, arm_first: int, sample_index: int=2, purple: Array=[], white: Array=[]) -> void:
	if purple.is_empty(): purple=ctx.order.slice(0,4)
	if white.is_empty(): white=ctx.order.slice(4,6)
	var f:=P.family(arm_first,sample_index,purple,white)
	var route:=P.route(str(ctx.profile.id)); var assignments:=slots(route,purple,white)
	var outside:=points(assignments,arm_first,19.0,false)
	var inside:=points(assignments,arm_first,16.5,false)
	var final_points:=points(assignments,arm_first,16.5,true)
	var lineup: Array=[]; lineup.resize(8)
	for i in 8: lineup[int(route.priority[i])]=Vector2(-7.0+2.0*i,7.0)
	# A beat's goal is approached from its beginning. Never move early into ring 3.
	var times: Array=[f.rings[2]+0.04,f.rings[3]+0.04,f.rings[6]+0.04,f.duration]
	var goals: Array=[outside,inside,outside,final_points]
	var previous:=0.0
	for a in 8: ctx.labels[a]="Sniper" if a in purple else ("High-powered Sniper" if a in white else "Unmarked partner")
	for i in times.size():
		ctx.positions=goals[i].duplicate()
		var beat: Dictionary=ctx.beat("P3 transition: concurrent rings / arms / sniper",float(times[i])-previous,"Follow actual arm order and current debuffs. Numerical guide realization; HP/shields unmodeled.")
		beat.hide_main_boss=true
		beat.p3_transition_route=route.duplicate(true)
		beat.p3_transition_public={"profile_id":str(ctx.profile.id),"phase":["outer","inner","outer_return","pocket"][i]}
		beat.p3_transition_family={"arm_first":arm_first,"sample_index":sample_index,"sample_id":f.sample_id}
		beat.stage_entities=[{"id":"p3_transition_boss","form":"final","pos":[0,0],"name":"Omega Reconfigured","p3_transition_entity":true}]
		if i==0:
			beat.spawn=lineup; beat.p3_transition_events=P.events(f); beat.p3_transition_duration=f.duration
			beat.p3_transition_void={"start":f.void_start,"end":f.void_end,"radius":6.0,"confidence":P.data().geometry.void_confidence}
		previous=float(times[i])
