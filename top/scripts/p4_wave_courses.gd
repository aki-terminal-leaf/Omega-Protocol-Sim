# SPDX-License-Identifier: MIT
extends RefCounted
## Opt-in: parent calls append_wave only for p4_wave. No parent-owned files required.
const P = preload("res://scripts/p4_wave_patterns.gd")
const Rules = preload("res://scripts/rules.gd")
static func append_course(ctx) -> void: append_wave(ctx)
static func append_wave(ctx) -> void:
	var options := P.pairs()
	var targets: Array=[]
	for _cycle in 3: targets.append(options[ctx.rng.randi_range(0,27)].duplicate())
	append_family(ctx,targets,ctx.rng.randi_range(0,3))
static func spread(route_data: Dictionary, radius := 14.0) -> Array:
	var result: Array=[]
	for angle in route_data.spread_angles: result.append(Rules.direction(float(angle))*radius)
	return result
static func stacks(route_data: Dictionary, targets: Array, radius: float) -> Array:
	var groups := P.groups(route_data,targets)
	var result: Array=[]
	for actor in 8:
		result.append(Rules.direction(float(route_data.stack_angles[0 if actor in groups[0] else 1]))*radius)
	return result
static func append_family(ctx, target_pairs: Array, family := 0) -> void:
	var route_data := P.route(str(ctx.profile.id))
	var timing: Dictionary=P.data().families[family]
	var events := P.events(target_pairs,family)
	# Each goal applies during the interval ending at this time. These are
	# waypoints only: runtime never reads them, moves actors or grants statuses.
	var points: Array=[
		[timing.proteans[0],spread(route_data)],
		[timing.stacks[0],stacks(route_data,target_pairs[0],14.0)],
		[timing.proteans[1],spread(route_data)],
		[timing.stacks[1],stacks(route_data,target_pairs[1],9.0)],
		[timing.proteans[2],spread(route_data)],
		[timing.rings[5],stacks(route_data,target_pairs[2],14.0)],
		[timing.rings[7]+0.1,stacks(route_data,target_pairs[2],9.0)]]
	var last := 0.0
	for i in points.size():
		ctx.positions=points[i][1].duplicate()
		var beat: Dictionary=ctx.beat("P4 continuous Wave Cannon / %.3fs"%float(points[i][0]),float(points[i][0])-last,"TRHM; lower marked player and opposite melee swap. Numeric waypoints are legal training realizations; normal walking 6/s.")
		beat.hide_main_boss=true
		beat.p4_wave_route=route_data.duplicate(true)
		beat.p4_wave_pattern={"targets":target_pairs.duplicate(true),"family":family,"timing_source":timing.id,"guide_geometry_complete":false}
		beat.stage_entities=[{"id":"p4_wave_boss","form":"final","pos":[0,0],"face":180.0,"original_form":"Omega Reconfigured","source":"P4 live boss casts; parent OfficialModels final registry"}]
		if i==0:
			beat.p4_wave_events=events
			beat.p4_wave_duration=float(points[-1][0])
		last=float(points[i][0])
