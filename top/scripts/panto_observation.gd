# SPDX-License-Identifier: MIT
extends RefCounted
## Information-fair Panto steering. This is local, JSON-safe observation memory,
## not an event oracle. Original-game cue onset remains source_unknown.
const Rules = preload("res://scripts/rules.gd")
const Late = preload("res://scripts/late_damage_preview.gd")
const Courses = preload("res://scripts/p1_courses.gd")
const INLINE = ["first_in_line","second_in_line","third_in_line","fourth_in_line"]
const PROFILES = ["elemental","aether","lpdu","cn_moogle","kr_09stop"]
const VARIANTS = ["inner_out_outer_return","outer_out_inner_return"]

static func neutral(actor: int) -> Vector2:
	return Vector2(-3.5+actor,6.0)

static func begin(beat: Dictionary, state: Dictionary) -> void:
	# The owner calls this ONLY for a fresh Panto p1_events epoch. Ordinary
	# beat changes and JSON/checkpoint restoration must preserve the cache.
	var selected=beat.get("panto_public",{})
	if not selected is Dictionary: selected={}
	state.panto_observation={"origin":float(state.get("sim_time",0)),
		"profile_id":str(selected.get("profile_id","")),"variant":str(selected.get("variant","")),
		"axis":null,"axis_at":-1.0,"direction":0,"direction_at":-1.0,
		"numbers":[],"groups":[],"assignment_at":-1.0,
		"rotation_axis":null,"rotation_damage_at":-1.0}

static func selection_valid(seen: Dictionary) -> bool:
	return str(seen.get("profile_id","")) in PROFILES and str(seen.get("variant","")) in VARIANTS

static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==float(int(value))

static func assignments(seen: Dictionary) -> Dictionary:
	# Normalize JSON numbers in local arrays; never rewrite statuses, physical
	# event records, actors, or the solved route. Invalid caches fail closed.
	if not selection_valid(seen): return {}
	var raw=seen.get("numbers",[])
	if not raw is Array or raw.size()!=8: return {}
	var numbers: Array=[]
	for value in raw:
		if not integer(value) or int(value)<1 or int(value)>4: return {}
		numbers.append(int(value))
	var groups: Array=[]; groups.resize(8)
	for number in range(1,5):
		var members: Array=range(8).filter(func(actor):return numbers[actor]==number)
		if members.size()!=2: return {}
		var ordered: Array=Courses.pair({"profile":{"id":str(seen.profile_id)}},members)
		for side in 2: groups[int(ordered[side])]=side
	var cached=seen.get("groups",[])
	if not cached is Array: return {}
	if not cached.is_empty():
		if cached.size()!=8: return {}
		for actor in 8:
			if not integer(cached[actor]) or int(cached[actor])!=int(groups[actor]): return {}
	return {"numbers":numbers,"groups":groups}

static func observe_assignments(seen: Dictionary, state: Dictionary, now: float) -> void:
	if not assignments(seen).is_empty(): return # Missiles remove Inline; memory survives.
	if not selection_valid(seen): return
	var statuses=state.get("statuses",[])
	if not statuses is Array or statuses.size()!=8: return
	var numbers: Array=[]
	for actor in 8:
		if not statuses[actor] is Dictionary: return
		var number:=0
		for n in 4:
			if not statuses[actor].has(INLINE[n]): continue
			var status=statuses[actor][INLINE[n]]
			if not status is Dictionary or float(status.get("expires",INF))<=now: continue
			if number!=0: return # Contradictory public number icons.
			number=n+1
		if number==0: return
		numbers.append(number)
	var candidate: Dictionary=seen.duplicate(true); candidate.numbers=numbers; candidate.groups=[]
	var observed: Dictionary=assignments(candidate)
	if observed.is_empty(): return
	seen.numbers=observed.numbers; seen.groups=observed.groups
	seen.assignment_at=now-float(seen.origin)

static func sync(beat: Dictionary, state: Dictionary) -> void:
	# Standalone physics uses visibility eligibility. Main requires its actual
	# current-frame cone mesh publication; internal substeps cannot reveal cues.
	if state.get("panto_presentation_required",false): return
	observe(beat,state,beat.get("shapes",[]))

static func presented(beat: Dictionary, state: Dictionary, displayed: Array) -> void:
	if not state.get("panto_presentation_required",false): return
	observe(beat,state,displayed)

static func observe(beat: Dictionary, state: Dictionary, displayed: Array) -> void:
	if not state.has("panto_observation"): return
	var seen: Dictionary=state.panto_observation
	var now:=float(state.get("sim_time",0))
	var relative:=now-float(seen.origin)
	observe_assignments(seen,state,now)
	var elapsed:=now-float(state.get("beat_started",now))
	for shape in displayed:
		if not shape.get("p1_preview",false) or shape.get("kind","")!="cone": continue
		if not Late.visible(shape,beat,state,elapsed,false): continue
		var angle:=float(shape.get("angle",NAN))
		if not is_finite(angle): continue
		var axis:=fposmod(angle,180.0)
		if seen.axis==null:
			seen.axis=axis; seen.axis_at=relative
		# Compare consecutive actually displayed cones. Their current public
		# damage_at stamps identify the existing2s cadence without reading a
		# hidden pulse index or pending event. A skipped tell reanchors rather
		# than mistaking a later modulo180 angle for the opposite rotation.
		var damage_at:=float(shape.get("damage_at",NAN))
		if not is_finite(damage_at): continue
		if int(seen.direction)==0 and seen.get("rotation_axis")!=null and relative>float(seen.axis_at)+Late.EPSILON:
			var delta:=wrapf(axis-float(seen.rotation_axis),-90.0,90.0)
			if absf(damage_at-float(seen.rotation_damage_at)-2.0)<0.001 and absf(absf(delta)-30.0)<0.001:
				seen.direction=1 if delta>0 else -1
				seen.direction_at=relative
		if damage_at>=float(seen.get("rotation_damage_at",-1.0)):
			seen.rotation_axis=axis; seen.rotation_damage_at=damage_at

static func goal(actor: int, state: Dictionary) -> Vector2:
	var hold:=neutral(actor)
	var seen: Dictionary=state.get("panto_observation",{})
	var assignment: Dictionary=assignments(seen)
	if actor<0 or actor>=8 or assignment.is_empty() or seen.get("axis")==null: return hold
	var axis:=float(seen.axis)
	if not is_finite(axis): return hold
	var id:=str(seen.profile_id)
	var preferred:=315.0 if id=="elemental" else (180.0 if id=="aether" else 0.0)
	var center:=Courses.safe_sector(id,axis,preferred)
	var outer:=str(seen.variant)=="outer_out_inner_return"
	var group:=int(assignment.groups[actor])
	if not integer(seen.get("direction",0)): return hold
	var sign_value:=int(seen.get("direction",0))
	if sign_value==0:
		return Rules.direction(center+group*180)*(4.0 if outer else 10.0)
	if sign_value not in [-1,1]: return hold
	var base:=center-sign_value*(-40.0 if outer else 45.0)
	var now:=float(state.get("sim_time",0))-float(seen.origin)
	# Preserve the existing origin-relative 0.1-second route cadence and knots.
	var waypoint:=clampf((floorf((now+0.000001)*10.0)+1)*0.1,0.1,32.3)
	return Courses.panto_point(waypoint,int(assignment.numbers[actor]),base+group*180,sign_value,outer)
