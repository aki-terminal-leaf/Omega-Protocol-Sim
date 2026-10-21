# SPDX-License-Identifier: MIT
extends RefCounted
## Opt-in parent integration: each function appends the COMPLETE combined course.
const P = preload("res://scripts/p6_patterns.gd")
const Rules = preload("res://scripts/rules.gd")

static func append_arrow(ctx, with_waves: bool) -> void:
	var center_first := bool(ctx.rng.randi_range(0,1))
	append_arrow_family(ctx,with_waves,center_first)

static func append_arrow_family(ctx, with_waves: bool, center_first: bool) -> void:
	var route := P.route(str(ctx.profile.id))
	var events := P.arrow(center_first)
	var end := 25.6 if with_waves else 23.2
	if with_waves: events.append_array(P.waves(17.0,25.6,shuffle(ctx,range(8)),ctx.rng.randi_range(2,7)))
	else: events.append({"at":23.2,"kind":"dive"})
	var times: Array=[8.0,10.0,12.0,14.0,16.0,17.0,18.0,19.0,20.0,22.0,end]
	var goals: Array=[]
	for time in times:
		if time == end:
			goals.append(charge_goals(stack_direction(route)) if with_waves else arrow_dive_goals(route))
		else: goals.append(arrow_goals(route,center_first,float(time),with_waves))
	append(ctx,"Cosmo Arrow (%s) + %s" % ["center first" if center_first else "sides first","Wave Cannon" if with_waves else "Cosmo Dive"],events,times,goals,route,{"center_first":center_first,"numerical_lanes":"training construction; community footwork only partially audited"})

static func arrow_goals(route: Dictionary, center: bool, time: float, waves: bool) -> Array:
	var result: Array=[]
	var clocks: Array=route.clocks.duplicate()
	if clocks.is_empty(): clocks=[0,180,270,90,225,135,315,45]
	if not waves:
		var party := 135.0 if route.id=="lpdu" else 225.0
		clocks=[315,45,party,party,party,party,party,party]
	for actor in 8:
		var angle := float(clocks[actor])
		var cardinal := fposmod(angle,90.0)<0.01
		var kr_pairs: bool=waves and route.id=="kr_09stop"
		# Training pairing derived from KR's clocks makes four TH/DPS pairs;
		# exact guide quadrant pairing remains unaudited. Aether's sourced TH
		# clockwise prepositioning uses its own clock map.
		var quadrant := angle+(-45.0 if kr_pairs else 45.0) if cardinal else angle
		var p := Vector2.ZERO
		if time<=12.0:
			var coordinate := (6.0 if time==8.0 else 3.0) if center else (6.0 if time==8.0 else 11.0)
			p=Vector2(coordinate,-coordinate).rotated(deg_to_rad(quadrant-45.0))
		elif time<=16.0 and (center or time<16.0):
			p=(Vector2(-5.5 if kr_pairs else 5.5,-10.0).rotated(deg_to_rad(angle)) if cardinal else (Vector2(6,-10) if kr_pairs else Vector2(10,-6)).rotated(deg_to_rad(angle-45.0))) if center else Vector2(7,-7).rotated(deg_to_rad(quadrant-45.0))
		else:
			var coordinate := (11.0 if time<20.0 else 8.0) if center else (12.0 if time<18.0 else 8.0)
			p=Rules.direction(angle)*(12.0 if time< (20.0 if center else 18.0) else 8.0) if cardinal else Vector2(coordinate,-coordinate).rotated(deg_to_rad(angle-45.0))
		result.append(p)
	# LPDU slide 2 has pairs with lateral arrows, not WC1 clock assignments.
	if waves and route.id=="lpdu":
		var signs: Array=[Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2(-1,1),Vector2(1,1),Vector2(-1,-1),Vector2(1,-1)]
		for actor in 8:
			var p: Vector2=result[actor]
			if time<=12:
				p=Vector2(absf(p.x),absf(p.y))
			elif time<=16 and (center or time<16): p=(Vector2(5.5,10) if actor<4 else Vector2(10,5.5)) if center else Vector2(7,7)
			else:
				var outer := 12.0 if time<(20.0 if center else 18.0) else 9.0
				p=Vector2(3,outer) if actor<4 else Vector2(outer,3)
			result[actor]=p*signs[actor]
	return result

static func append_exaflares(ctx, with_dive: bool) -> void:
	var start: int = ctx.rng.randi_range(0,7)
	var direction := 1 if ctx.rng.randi_range(0,1) else -1
	append_exaflare_family(ctx,with_dive,start,direction)

static func append_exaflare_family(ctx, with_dive: bool, start: int, direction: int) -> void:
	var route := P.route(str(ctx.profile.id))
	# Unknown guide offsets are explicit training variants, never DC inference.
	var offset := float(route.exit_offset) if route.exit_offset!=null else 45.0
	var events := P.exaflares(start,direction)
	var times: Array=[]; var goals: Array=[]
	for point in P.exa_waypoints(start,direction,offset):
		times.append(point.at); goals.append(repeated(Rules.v(point.pos)))
	if with_dive:
		events.append({"at":26.3,"kind":"dive"}); times.append(26.3)
		var rear := start*45.0-direction*offset+direction*120.0
		goals.append(dive_goals(rear))
	else:
		events.append_array(P.waves(26.2,34.4,shuffle(ctx,range(8)),ctx.rng.randi_range(2,7)))
		# Step inward before fanning out: a direct chord back toward some clocks
		# intersects the still-live sixth bait. Its explosion remains at T23.
		times.append(23.0)
		goals.append(repeated(Rules.direction(start*45.0-direction*offset+direction*120.0)*9.0))
		for time in [26.2,28.2]:
			times.append(time)
			var clocks: Array=[]
			for angle in route.clocks: clocks.append(Rules.direction(float(angle))*10.0)
			goals.append(clocks)
		times.append(34.4); goals.append(charge_goals(stack_direction(route)))
	append(ctx,"Unlimited Wave Cannon + "+("Cosmo Dive" if with_dive else "Wave Cannon"),events,times,goals,route,{"start_index":start,"direction":direction,"exit_offset":offset,"offset_source":"guide" if route.exit_offset!=null else "explicit 45-degree training variant; community offset unknown"})

static func append_meteors(ctx) -> void:
	var combinations := P.flare_combinations()
	var flares: Array=combinations[ctx.rng.randi_range(0,combinations.size()-1)]
	append_meteor_combination(ctx,flares)

static func append_meteor_combination(ctx, flares: Array) -> void:
	assert(flares.size()==3 and flares[0]!=flares[1] and flares[0]!=flares[2] and flares[1]!=flares[2])
	var route := P.route(str(ctx.profile.id))
	var nonflares: Array=[]
	for actor in 8:
		if actor not in flares: nonflares.append(actor)
	var first := shuffle(ctx,range(8)); var second := shuffle(ctx,range(8))
	# Normalized timing from four captures, not old seven-second beat gaps.
	var events: Array=[{"at":5.0,"kind":"bait","delay":4.0,"radius":10.0,"name":"Cosmo Meteor initial puddle"}]
	# Captures report nominal 4500ms LB casts (~3970ms server cast interval).
	# Post-cast job-specific animation is not established by stationary replay.
	events.append({"at":9.0,"kind":"lock","actor":7,"duration":4.5})
	events.append({"at":20.0,"kind":"lock","actor":6,"duration":4.5})
	for i in 4:
		events.append({"at":[10.2,11.2,16.2,17.2][i],"kind":"spread","targets":(first if i<2 else second).slice((i%2)*4,(i%2+1)*4)})
	events.append({"at":20.2,"kind":"flare_markers","targets":flares})
	events.append({"at":28.3,"kind":"flares","targets":flares,"stack_target":nonflares[ctx.rng.randi_range(0,4)]})
	var clock_angles: Array=route.meteor_clocks
	if clock_angles.is_empty(): clock_angles=[315,180,270,90,225,135,0,45]
	var clocks: Array=[]
	for angle in clock_angles: clocks.append(Rules.direction(float(angle))*16.0)
	if route.id=="kr_09stop": clocks[6]=Rules.direction(0)*18.0
	var times: Array=[5.0,9.0,10.2,11.2,16.2,17.2,20.2,28.3]
	var goals: Array=[repeated(Vector2.ZERO),clocks,clocks,clocks,clocks,clocks,clocks,P.flare_goals(flares,str(route.id))]
	append(ctx,"Cosmo Meteor (movement only; flare damage unmodeled)",events,times,goals,route,{"flares":flares,"flare_tie":"actor-index training convention","meteor_clocks_source":"guide" if not route.meteor_clocks.is_empty() else "training convention; source map unresolved","lb":"nominal 4.5s cast lock; post-cast animation unknown; LB start times are training choices"})

static func append(ctx, title: String, events: Array, times: Array, goals: Array, route: Dictionary, pattern: Dictionary) -> void:
	var last := 0.0
	for i in times.size():
		ctx.positions=goals[i].duplicate()
		var beat: Dictionary=ctx.beat(title+" / %.2fs" % float(times[i]),float(times[i])-last,"Actual timed hazards; route coverage is partial. "+str(route.unknown))
		beat.p6_route=route.duplicate(true); beat.p6_pattern=pattern.duplicate(true)
		beat.p6_pattern.stack_direction_source="guide" if route.stack_angle!=null else "south is a training choice; community stack direction unresolved"
		beat.p6_pattern.guide_route_complete=false
		if i==0:
			beat.p6_events=P.sorted(events); beat.p6_duration=float(times[-1])
		last=float(times[i])

static func shuffle(ctx, values: Array) -> Array:
	var result := values.duplicate()
	for i in range(result.size()-1,0,-1):
		var j: int=ctx.rng.randi_range(0,i)
		var old=result[i]; result[i]=result[j]; result[j]=old
	return result

static func repeated(pos: Vector2) -> Array:
	var result: Array=[]
	for _i in 8: result.append(pos)
	return result

static func stack_direction(route: Dictionary) -> float:
	# Explicit training direction for source-unknown CN, recorded in route.
	return float(route.stack_angle) if route.stack_angle!=null else 180.0

static func charge_goals(angle: float) -> Array:
	var result: Array=[]
	for actor in 8: result.append(Rules.direction(angle)*(6.0+actor*0.6))
	return result

static func dive_goals(rear: float) -> Array:
	var result := repeated(Rules.direction(rear)*13.0)
	result[0]=Rules.direction(rear+150)*9.0; result[1]=Rules.direction(rear-150)*9.0
	return result

static func arrow_dive_goals(route: Dictionary) -> Array:
	var result := repeated(Rules.direction(135 if route.id=="lpdu" else 225)*13.0)
	result[0]=Rules.direction(330 if route.id=="kr_09stop" else 315)*9.0
	result[1]=Rules.direction(30 if route.id=="kr_09stop" else 45)*9.0
	return result
