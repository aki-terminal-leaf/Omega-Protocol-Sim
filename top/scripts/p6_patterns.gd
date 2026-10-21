# SPDX-License-Identifier: MIT
extends RefCounted
## Original finite geometry. Event times are relative to course start, positions
## are JSON arrays, angles are arena N=0/CW. No community name changes hazards.
const Rules = preload("res://scripts/rules.gd")

static func xy(p: Vector2) -> Array: return [p.x, p.y]

static func arrow(center_first: bool) -> Array:
	var events: Array = []
	for axis in [0.0, 90.0]:
		var normal := Rules.direction(axis + 90.0)
		var central := 8.0 if center_first else 10.0
		events.append(strip(central, axis, normal * 0, 10.0, "central", 0))
		for pulse in range(1, 4):
			for sign_value in [-1, 1]:
				events.append(strip(central + pulse * 2, axis, normal * sign_value * (7.5 + (pulse - 1) * 5), 5.0, "central", pulse))
		var side := 10.0 if center_first else 8.0
		for sign_value in [-1, 1]:
			for pulse in 7:
				var offset := 15.0 if pulse == 0 else 15.0 - 7.5 - (pulse - 1) * 5.0
				events.append(strip(side + pulse * 2, axis, normal * sign_value * offset, 10.0 if pulse == 0 else 5.0, "side", pulse))
	return sorted(events)

static func strip(at: float, angle: float, pos: Vector2, width: float, group: String, pulse: int) -> Dictionary:
	var result := {"at":at,"kind":"hazard","group":group,"pulse":pulse,"shape":{"kind":"line","pos":xy(pos),"angle":angle,"width":width,"start":-40.0,"length":40.0,"name":"Cosmo Arrow"}}
	if pulse==0: result.telegraph_at=at-8.0
	return result

static func exaflares(start_index: int, direction: int) -> Array:
	assert(start_index >= 0 and start_index < 8 and direction in [-1, 1])
	var events: Array = []
	for line in 4:
		var outward := Rules.direction((start_index + direction * line) * 45.0)
		for pulse in 7:
			# Normalized capture timing: first advance ~1.11, subsequent ~1.00.
			var at := 12.0 + line + (0.0 if pulse == 0 else 1.11 + pulse - 1)
			var event := {"at":at,"kind":"hazard","line":line,"pulse":pulse,"shape":{"kind":"circle","pos":xy(outward * (24.0 - pulse * 8.0)),"radius":8.0,"name":"Exaflare"}}
			if pulse==0: event.telegraph_at=float(line)
			events.append(event)
	for bait in 6:
		events.append({"at":10.0 + bait * 2,"kind":"bait","delay":3.0,"radius":6.0,"bait":bait,"name":"Wave Cannon puddle"})
	return sorted(events)

static func sorted(events: Array) -> Array:
	events.sort_custom(func(a, b): return float(a.at) < float(b.at))
	return events

static func waves(first: float, stack: float, targets: Array, charge_target: int) -> Array:
	assert(targets.size() == 8)
	return [{"at":first,"kind":"proteans","targets":targets.slice(0,4)}, {"at":first+2.0,"kind":"proteans","targets":targets.slice(4,8)}, {"at":stack,"kind":"charge","target":charge_target}]

static func beam(target: int) -> Dictionary:
	return {"kind":"line","pos":[0,0],"target":target,"width":8.0,"length":100.0,"name":"Wave Cannon"}

static func route(id: String) -> Dictionary:
	# Missing source fields remain null. Numeric dodge lanes elsewhere are an
	# explicit training construction, never claimed to be an audited diagram.
	var r := {"id":id,"complete":false,"clocks":[],"meteor_clocks":[],"stack_angle":null,"exit_offset":null,"arrow_party_angle":null,"unknown":[]}
	match id:
		"elemental":
			r.clocks=[315,180,270,90,225,135,0,45]; r.stack_angle=90.0; r.exit_offset=67.5
			r.unknown=["First Arrow quadrant", "exact Arrow lateral lanes", "meteor clock map and flare E/W tie"]
		"aether":
			r.clocks=[0,180,270,90,225,135,315,45]; r.stack_angle=180.0
			r.unknown=["D1/D2 assumed SAM/DRG convention, not generic source assignment", "exaflare exit offset", "meteor clock map", "exact Arrow lateral lanes"]
		"lpdu":
			r.clocks=[0,90,270,180,225,135,315,45]; r.meteor_clocks=[315,180,270,90,225,135,0,45]; r.stack_angle=180.0; r.arrow_party_angle=135.0
			r.unknown=["exaflare exit offset", "full Arrow temporal footwork", "meteor flare/LB route"]
		"cn_moogle":
			r.clocks=[0,90,270,180,225,135,315,45]; r.meteor_clocks=[315,90,270,180,225,135,0,45]
			r.unknown=["exaflare exit offset", "Wave stack direction", "Arrow temporal footwork", "meteor flare/LB route"]
		"kr_09stop":
			r.clocks=[315,180,270,90,225,135,0,45]; r.meteor_clocks=r.clocks.duplicate(); r.stack_angle=180.0; r.exit_offset=67.5; r.arrow_party_angle=225.0
			r.unknown=["full Arrow animation and exact pair-to-quadrant mapping", "flare E/W tie", "Dive selection prose conflicts with encounter evidence"]
		_:
			r.unknown=["Unsupported community"]
	return r

static func exa_waypoints(start_index: int, direction: int, offset: float) -> Array:
	var points: Array = [{"at":10.0,"pos":[0.0,0.0]}]
	var escape := start_index * 45.0 - direction * offset
	for i in 6:
		var angle := escape + direction * maxf(0, i-1) * 30.0
		var radius := 6.0 if i == 0 else (14.0 if i == 1 else 15.0)
		points.append({"at":12.0+i*2,"pos":xy(Rules.direction(angle)*radius)})
	return points

static func flare_combinations() -> Array:
	var result: Array=[]
	for a in 6:
		for b in range(a+1,7):
			for c in range(b+1,8): result.append([a,b,c])
	return result

static func flare_goals(flares: Array, profile_id := "") -> Array:
	# D3 is never moved out of its northern LB position. E/W tie is a training
	# actor-index convention, not a claimed community priority.
	var result: Array=[]
	var stack_angle := 180.0 if 6 in flares else 0.0
	for actor in 8: result.append(Rules.direction(stack_angle)*16.0)
	var ordered := flares.duplicate(); ordered.sort()
	if 6 in ordered:
		result[6]=Rules.direction(0)*16.0; ordered.erase(6)
	else:
		result[ordered.pop_back()]=Rules.direction(180)*16.0
	result[ordered[0]]=Rules.direction(90)*18.0
	result[ordered[1]]=Rules.direction(270)*18.0
	if profile_id=="kr_09stop":
		# KR distinguishes max-melee tank/melee flares from outer ranged/healer
		# flares. 16/18 are training distances; the relative distinction is sourced.
		for actor in 8:
			if actor in flares:
				result[actor]=result[actor].normalized()*(16.0 if actor in [0,1,4,5] else 18.0)
			elif 6 not in flares: result[actor]=Rules.direction(0)*18.0
	return result
