# SPDX-License-Identifier: MIT
extends RefCounted
## Later HW tower waves (rounds 2-4): coaching goals derived only from publicly
## presented state: the first-wave public order/colour, each round's actually
## drawn four towers, current rot statuses and the observed carrier mapping.
## Never reads hidden orientations, pending geometry, hw_pattern, hw_path or
## beat.positions for routing. Post-judgment beats use only the angle-free
## guide choreography (beat.hw_later.local) rotated by the received angle.
## Only chooses goals; mutates state.hw.later_public and the existing
## hw_tower_choice_* / cooperation_round observation keys.
const P = preload("res://scripts/hw_patterns.gd")
const Rules = preload("res://scripts/rules.gd")
const F = preload("res://scripts/hw_firstwave_observation.gd")

const FIRST_TOWER := 24.0
const ROUND_STEP := 21.0
const ROUND_LEAD := 11.0  # transition starts 10s after the previous tower
const TETHER_GO := 3.0  # transition semantics: tethers leave 3s before towers
const EPS := 0.000001
const SOURCES := ["arena_presented","synthetic_runtime_fixture"]

static func _tower_at(cache: Dictionary, round_index: int) -> float:
	return float(cache.origin)+FIRST_TOWER+ROUND_STEP*round_index

static func round_of(beat: Dictionary) -> int:
	if not bool(beat.get("hello_world",false)): return -1
	var later=beat.get("hw_later",null)
	if later is Dictionary and F._num(later.get("round",null)):
		var r := int(later.round)
		return r if r>=1 and r<=3 else -1
	var c=beat.get("hw_tower_cooperation",null)
	if c is Dictionary and F._num(c.get("round",null)):
		var r2 := int(c.round)
		return r2 if r2>=1 and r2<=3 else -1
	return -1

# ---------- cache ----------
# One cache per actual HW start. A new run/reset (new hw.start) replaces it;
# a beat retry restores the beat-start snapshot, i.e. only genuinely past receipts.
static func _cache(state: Dictionary):
	var hw=F._hw(state)
	if hw==null or not F._num(hw.get("start",null)): return null
	var cache=hw.get("later_public",null)
	if not (cache is Dictionary) or not F._num(cache.get("origin",null)) or absf(float(cache.origin)-float(hw.start))>EPS:
		cache={"origin":float(hw.start),"rounds":{},"reasons":{}}
		hw.later_public=cache
	if not (cache.get("rounds",null) is Dictionary): cache.rounds={}
	if not (cache.get("reasons",null) is Dictionary): cache.reasons={}
	var first=F._cache(state)
	if first==null: return null
	cache.order=F._order(first.order); cache.colour=str(first.colour)
	return cache

static func _round(cache: Dictionary, round_index: int) -> Dictionary:
	var key := str(round_index)
	if not (cache.rounds.get(key,null) is Dictionary): cache.rounds[key]={}
	return cache.rounds[key]

# A complete, past, in-window receipt for this run and round, or null.
static func _receipt(cache: Dictionary, round_index: int, now: float):
	var entry=cache.rounds.get(str(round_index),null)
	if not (entry is Dictionary) or not is_finite(now) or not str(entry.get("blocked","")).is_empty(): return null
	var r=entry.get("receipt",null)
	if not (r is Dictionary): return null
	if not F._num(r.get("at",null)) or not F._num(r.get("orientation",null)) or not F._num(r.get("round",null)): return null
	if int(r.round)!=round_index or float(r.orientation)!=floor(float(r.orientation)) or int(r.orientation)<0 or int(r.orientation)>7: return null
	if not F._num(r.get("origin",null)) or absf(float(r.origin)-float(cache.origin))>EPS: return null
	var at := float(r.at); var tower := _tower_at(cache,round_index)
	if at>now+EPS or at<tower-ROUND_LEAD-EPS or at>=tower: return null
	if F._points(r.get("targets",null)).is_empty(): return null
	if not (str(r.get("source_kind","")) in SOURCES): return null
	return r

# ---------- publish ----------
static func _role_base(slot: int, round_index: int) -> int:
	return posmod(slot-slot%2+2*round_index,8)

# Actual current rot colour of each carrier pair must agree with the public
# role rotation: role 0 keeps the defamation colour, role 4 the other one.
static func _status_check(cache: Dictionary, round_index: int, state: Dictionary) -> String:
	var buffs=state.get("statuses",null)
	if not (buffs is Array) or buffs.size()!=8: return "statuses unavailable"
	var order: Array=cache.order
	var other := "blue" if cache.colour=="red" else "red"
	for role in [0,4]:
		var base := posmod(role-2*round_index,8)
		for side in 2:
			var c := F._colour_of(buffs[int(order[base+side])])
			if c!=(str(cache.colour) if role==0 else other): return "carrier rot status conflicts with public role"
	return ""

static func _tags_ok(shapes, round_index: int, origin: float) -> bool:
	if not (shapes is Array): return false
	for s in shapes:
		if not (s is Dictionary) or str(s.get("kind",""))!="tower" or s.get("hw_preview",false)!=true: continue
		# Tags are optional for older renderers; when present they must match.
		if s.has("hw_round") and (not F._num(s.hw_round) or int(s.hw_round)!=round_index): return false
		if s.has("hw_origin") and (not F._num(s.hw_origin) or absf(float(s.hw_origin)-origin)>EPS): return false
	return true

static func _store(beat: Dictionary, state: Dictionary, shapes, source_kind: String) -> bool:
	var round_index := round_of(beat)
	if round_index<1: return false
	var cache=_cache(state)
	if cache==null: return false
	var now := F._now(state)
	var tower := _tower_at(cache,round_index)
	if not is_finite(now) or now<tower-ROUND_LEAD-EPS or now>=tower: return false
	var entry := _round(cache,round_index)
	if not str(entry.get("blocked","")).is_empty(): return false
	var current=_receipt(cache,round_index,now)
	if current!=null:
		var shown: Array=shapes.filter(func(x):return x is Dictionary and x.get("kind","")=="tower" and x.get("hw_preview",false)==true) if shapes is Array else []
		if shown.is_empty(): return true  # genuine absence may retain already observed facts
		var observed=F._tower_axis(shown,str(cache.colour))
		if not _tags_ok(shown,round_index,float(cache.origin)) or observed==null or int(observed)!=int(current.orientation):
			entry.blocked="contradictory displayed towers"; cache.reasons[str(round_index)]=entry.blocked
			return false
		return true  # never upgrade synthetic provenance

	if not _tags_ok(shapes,round_index,float(cache.origin)): cache.reasons[str(round_index)]="tower tags belong to another round/run"; return false
	var orientation=F._tower_axis(shapes,str(cache.colour))
	if orientation==null: return false
	var reason := _status_check(cache,round_index,state)
	if reason!="": cache.reasons[str(round_index)]=reason; return false
	entry.receipt={"round":round_index,"origin":float(cache.origin),"at":snappedf(now,0.000000001),"orientation":int(orientation),"targets":F._xy(P.formation(round_index,int(orientation),cache.order)),"towers":shapes.filter(func(x):return x is Dictionary and x.get("kind","")=="tower" and x.get("hw_preview",false)==true).duplicate(true),"source_kind":source_kind,"assisted":source_kind!="arena_presented"}
	entry.erase("mapping"); entry.erase("lanes"); entry.erase("lane_targets")
	cache.reasons.erase(str(round_index))
	return true

static func publish(beat: Dictionary, state: Dictionary, shapes) -> void:
	_store(beat,state,shapes,"arena_presented")

# ---------- goal ----------
static func _pose(actors: Array, actor: int):
	return F._vec(actors[actor].get("pos",null)) if actors[actor] is Dictionary else null

static func _mapping(entry: Dictionary, order: Array, targets: Array, actors: Array) -> Array:
	var stored=F._order(entry.get("mapping",null))
	if not stored.is_empty(): return stored
	var mapping: Array=range(8)
	for base in [0,2,4,6]:
		var a: int=int(order[base]); var b: int=int(order[base+1])
		var pa=_pose(actors,a); var pb=_pose(actors,b)
		if pa==null or pb==null: continue
		var keep := maxf(absf(angle_difference(pa.angle(),targets[a].angle())),absf(angle_difference(pb.angle(),targets[b].angle())))
		var swap := maxf(absf(angle_difference(pa.angle(),targets[b].angle())),absf(angle_difference(pb.angle(),targets[a].angle())))
		if swap<keep-EPS: mapping[a]=b; mapping[b]=a
	entry.mapping=mapping
	return mapping

# Same v32 exclusive occupancy/reversal policy, but geometry comes ONLY from
# the actual displayed receipt. Never call the legacy pending-event observer.
static func _human_rep(actor: int, round_index: int, beat: Dictionary, actors: Array, state: Dictionary, entry: Dictionary, targets: Array, mapping: Array):
	var human := int(state.get("human_actor",-1))
	if human<0 or human>7 or human==actor: return null
	var cache=_cache(state)
	if cache==null: return null
	var now := F._now(state)
	var receipt=_receipt(cache,round_index,now)
	if receipt==null: return null
	var pair: Array=[]
	for role in [0,4]:
		var slot := posmod(role-2*round_index,8)
		var candidate: Array=[int(cache.order[slot]),int(cache.order[slot+1])]
		if human in candidate and actor in candidate: pair=candidate; break
	if pair.is_empty(): return null
	var hi := pair.find(human); var ni := 1-hi
	var key := "hw_tower_choice_%d_%d" % [round_index,mini(pair[0],pair[1])]
	if int(state.hw.get("cooperation_round",-1))!=round_index:
		for old in state.hw.keys():
			if str(old).begins_with("hw_tower_choice_"): state.hw.erase(old)
	state.hw.cooperation_round=round_index
	if now<_tower_at(cache,round_index)-EPS:
		var buffs: Array=state.get("statuses",[])
		if buffs.size()==8:
			var colour := "red" if buffs[human].has("red") else ("blue" if buffs[human].has("blue") else "")
			var bug := "overflow" if buffs[human].has("overflow") else ("sync" if buffs[human].has("sync") else "")
			if colour!="" and bug!="" and buffs[actor].has(colour) and buffs[actor].has(bug):
				var towers: Array=receipt.get("towers",[]).filter(func(t):return str(t.get("colour",""))==colour)
				if towers.size()==2:
					var own: Vector2=targets[mapping[human]]; var other: Vector2=targets[mapping[actor]]
					var own_first := own.distance_to(Rules.v(towers[0].pos))<own.distance_to(Rules.v(towers[1].pos))
					var other_first := other.distance_to(Rules.v(towers[0].pos))<other.distance_to(Rules.v(towers[1].pos))
					if own_first!=other_first:
						var hp: Vector2=Rules.v(actors[human].pos)
						var in_own := Rules.contains(towers[0] if own_first else towers[1],hp,actors)
						var in_other := Rules.contains(towers[0] if other_first else towers[1],hp,actors)
						if in_other and not in_own: state.hw[key]=ni
						elif state.hw.has(key) and in_own and not in_other: state.hw[key]=hi
	if not state.hw.has(key): return null
	return human if int(state.hw[key])==ni else actor

static func _lane_goal(actor: int, here: Vector2, target: Vector2, lane: float, entry: Dictionary) -> Vector2:
	if not (entry.get("lanes",null) is Dictionary): entry.lanes={}
	if not (entry.get("lane_targets",null) is Dictionary): entry.lane_targets={}
	var key := str(actor)
	var prior=F._vec(entry.lane_targets.get(key,null))
	if prior==null or prior.distance_to(target)>0.001:
		entry.lanes[key]="out"; entry.lane_targets[key]=P.xy(target)
	var phase := str(entry.lanes.get(key,"out"))
	if phase=="in": return target
	if phase=="out":
		if absf(here.length()-lane)>0.2: return (here.normalized() if here.length()>0.001 else Vector2.UP)*lane
		entry.lanes[key]="around"
	var difference := angle_difference(here.angle(),target.angle())
	if absf(difference)>F.ANGLE_DONE: return Vector2.from_angle(here.angle()+clampf(difference,-F.ANGLE_STEP,F.ANGLE_STEP))*lane
	entry.lanes[key]="in"
	return target

static func _stage_radius(role: int) -> float:
	return F.CARRIER_LANE if role==0 else (F.SYNC_LANE if role==4 else 3.0)

## Returns a Vector2 coaching goal, or null when the beat is out of scope.
static func goal(actor: int, beat: Dictionary, actors: Array, state: Dictionary):
	var round_index := round_of(beat)
	if round_index<1 or actors.size()!=8 or actor<0 or actor>7: return null
	var here=_pose(actors,actor)
	if here==null: return Vector2.ZERO
	var cache=_cache(state)
	# Broken/absent public observation never falls through to solved goals.
	if cache==null: return here
	var now := F._now(state)
	if not is_finite(now): return here
	if actor==int(state.get("human_actor",-1)): return here
	var entry := _round(cache,round_index)
	var order: Array=cache.order
	var tower := _tower_at(cache,round_index)
	# Round start: capture actual poses once for neutral radial staging.
	if not (entry.get("start_pose",null) is Array) and now>=tower-ROUND_LEAD-EPS:
		entry.start_pose=actors.map(func(a):return P.xy(F._vec(a.get("pos",null)) if a is Dictionary and F._vec(a.get("pos",null))!=null else Vector2.ZERO))
	if _receipt(cache,round_index,now)==null and not bool(state.get("hw_firstwave_presentation_required",false)):
		# Explicit non-Main harness fixture: never ordinary/human source proof.
		if _store(beat,state,beat.get("shapes",[]),"synthetic_runtime_fixture"): state.hw_later_assisted=true
	var receipt=_receipt(cache,round_index,now)
	var later=beat.get("hw_later",null)
	var slot := order.find(actor)
	if receipt==null:
		if later is Dictionary: return here  # post-reveal beat without a receipt: hold
		var start=F._points(entry.get("start_pose",null))
		if start.is_empty(): return here
		var p: Vector2=start[actor]
		return (p.normalized() if p.length()>0.001 else Vector2.UP)*_stage_radius(_role_base(slot,round_index))
	if bool(receipt.get("assisted",false)): state.hw_later_assisted=true
	var targets := F._points(receipt.targets)
	var mapping := _mapping(entry,order,targets,actors)
	var effective: int=mapping[actor]
	var rep=_human_rep(actor,round_index,beat,actors,state,entry,targets,mapping)
	if rep!=null: effective=mapping[int(rep)]
	var effective_slot := order.find(effective)
	var role := _role_base(effective_slot,round_index)
	if later is Dictionary:
		var local := F._points(later.get("local",null))
		if local.is_empty(): return here
		return (local[role+effective_slot%2] as Vector2).rotated(deg_to_rad(float(receipt.orientation)*45.0))
	# Transition: carriers outside lanes, tethers wait inside until 3s before towers.
	var target: Vector2=targets[effective]
	if role in [2,6]:
		var start2=F._points(entry.get("start_pose",null))
		if now<tower-TETHER_GO-EPS and not start2.is_empty():
			var q: Vector2=start2[actor]
			return (q.normalized() if q.length()>0.001 else Vector2.UP)*3.0
		return target
	return _lane_goal(actor,here,target,_stage_radius(role),entry)
