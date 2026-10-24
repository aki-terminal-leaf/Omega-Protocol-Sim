# SPDX-License-Identifier: MIT
extends RefCounted
## 09STOP optional fixed-unmarked-DPS Oversampled Wave Cannon (source row340-1/340-2).
## Pure allocator + fresh public-cue observation. Never reads generated actor
## assignments, goals, facing, checks, labels or actor monitor offsets.
const Rules = preload("res://scripts/rules.gd")
const PartyStatuses = preload("res://scripts/party_statuses.gd")
const ROLES := ["MT","ST","H1","H2","D1","D2","D3","D4"]
const PRIORITY := ["H1","H2","MT","ST","D1","D2","D3","D4"]
const POLICIES := ["fixed_dps","fixed_dps_d3_outer"]
const MONITOR_KEYS := ["monitor_left","monitor_right"]

## Returns slot->actor [M1,M2,M3,N1..N5], or [] for any invalid input. No RNG.
static func allocate(marked_actor_ids: Array, policy: String) -> Array:
	if policy not in POLICIES or marked_actor_ids.size() != 3: return []
	var marked: Array = []
	for raw in marked_actor_ids:
		if not (raw is int or raw is float): return []
		var f := float(raw)
		if not is_finite(f) or f != floorf(f) or f < 0 or f >= 8: return []
		if int(f) in marked: return []
		marked.append(int(f))
	marked.sort_custom(func(a, b): return PRIORITY.find(ROLES[a]) < PRIORITY.find(ROLES[b]))
	var slots: Array = []; slots.resize(8); slots.fill(-1)
	for k in 3: slots[k] = marked[k]
	var d4_marked: bool = ROLES.find("D4") in marked
	for n in 4:
		var dps: int = ROLES.find("D%d" % (n + 1))
		if dps in marked: continue
		var slot: int = 4 + n # D1..D4 -> N2..N5
		if policy == "fixed_dps_d3_outer" and n == 2 and d4_marked: slot = 7 # D3 -> N5
		slots[slot] = dps
	var ht: Array = []
	for role in PRIORITY.slice(0, 4):
		if ROLES.find(role) not in marked: ht.append(ROLES.find(role))
	var free: Array = []
	for s in range(3, 8):
		if int(slots[s]) < 0: free.append(s)
	if free.size() != ht.size(): return []
	for k in ht.size(): slots[free[k]] = ht[k]
	return slots

## Exactly the existing kr_astoh training table, boss-mirrored.
static func canonical(sign_x: int) -> Array:
	var base := [Vector2(-7,-11),Vector2(-13,-5),Vector2(-13,5),Vector2(-0.7,-16),Vector2(3,0),Vector2(15,0),Vector2(-0.7,9),Vector2(-0.7,18)]
	var result: Array = []
	for p in base: result.append(Vector2(p.x * sign_x, p.y))
	return result

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func _int_id(raw) -> int:
	if not (raw is int or raw is float): return -1
	var f := float(raw)
	if not is_finite(f) or f != floorf(f) or f < 0 or f >= 8: return -1
	return int(f)

## Fresh every call: public HUD rows + nonactor boss monitor only. No cache.
static func observed(beat: Dictionary, actors: Array, state: Dictionary) -> Dictionary:
	var config = beat.get("monitor_fixed_dps")
	if not config is Dictionary or str(config.get("policy", "")) not in POLICIES: return _fail("config")
	if str(beat.get("monitor_layout", "")) != "kr_astoh": return _fail("layout")
	if actors.size() != 8: return _fail("actors")
	# Validate public packets before the HUD projector can dereference them.
	var now_raw = state.get("sim_time"); var start_raw = state.get("beat_started"); var duration_raw = beat.get("duration")
	for value in [now_raw,start_raw,duration_raw]:
		if not (value is int or value is float) or not is_finite(float(value)): return _fail("clock")
	var now:float=float(now_raw); var elapsed:float=now-float(start_raw)
	if float(duration_raw)<=0 or elapsed<0 or elapsed>=float(duration_raw):return _fail("clock")
	for i in 8:
		if not actors[i] is Dictionary or str(actors[i].get("role",""))!=ROLES[i]:return _fail("identity")
	var packets=beat.get("party_statuses",[])
	if not packets is Array:return _fail("malformed_cue")
	var consumed_raw=state.get("consumed_party_signals",{})
	if not consumed_raw is Dictionary:return _fail("malformed_consumption")
	for value in consumed_raw.values():
		if not value is Array:return _fail("malformed_consumption")
	var statuses=state.get("statuses",[])
	if not statuses is Array or (statuses.size()!=0 and statuses.size()!=8):return _fail("malformed_statuses")
	for status in statuses:
		if not status is Dictionary:return _fail("malformed_statuses")
		for key in status:
			var value=status[key]
			if not value is Dictionary:return _fail("malformed_statuses")
			for field in ["expires","remaining","stacks"]:
				if value.has(field) and (not (value[field] is int or value[field] is float) or not is_finite(float(value[field]))):return _fail("malformed_statuses")
	for raw in packets:
		if not raw is Dictionary or _int_id(raw.get("actor"))<0 or not raw.get("key") is String:return _fail("malformed_cue")
		for field in ["visible_from","expires","remaining","stacks"]:
			if raw.has(field) and (not (raw[field] is int or raw[field] is float) or not is_finite(float(raw[field]))):return _fail("malformed_cue")
		if raw.has("visible_until") and (not (raw.visible_until is int or raw.visible_until is float) or is_nan(float(raw.visible_until))):return _fail("malformed_cue")
	var rows: Array = PartyStatuses.rows(actors, state, beat)
	if rows.size() != 8: return _fail("rows")
	# Raw currently-visible, unconsumed presentation entries (rows() dedupes by key).
	var raw_counts: Dictionary = {}
	var consumed: Dictionary = state.get("consumed_party_signals", {})
	for raw in beat.get("party_statuses", []):
		if not raw is Dictionary or str(raw.get("key", "")) not in MONITOR_KEYS: continue
		var who := _int_id(raw.get("actor"))
		if who < 0: return _fail("malformed_cue")
		if not PartyStatuses.signal_visible(raw, state, beat): continue
		if str(raw.key) in consumed.get(str(who), []): continue
		var visible:Dictionary=PartyStatuses.effect(str(raw.key),raw,now)
		if float(visible.remaining)==0 or int(visible.stacks)<=0:continue
		var k := "%d:%s" % [who, str(raw.key)]
		raw_counts[k] = int(raw_counts.get(k, 0)) + 1
	var marked: Array = []
	var sides: Dictionary = {}
	for i in 8:
		var row: Dictionary = rows[i]
		if int(row.get("actor", -1)) != i or str(row.get("role", "")) != ROLES[i]: return _fail("identity")
		if bool(row.get("dead", false)): return _fail("dead")
		var keys: Array = []
		for item in row.get("effects", []):
			if str(item.get("key", "")) in MONITOR_KEYS: keys.append(str(item.key))
		if keys.size() > 1: return _fail("conflicting_cue")
		if keys.size() == 1:
			if int(raw_counts.get("%d:%s" % [i, keys[0]], 0)) > 1: return _fail("duplicate_cue")
			marked.append(i)
			sides[i] = 90.0 if keys[0] == "monitor_right" else -90.0
	if marked.size() != 3: return _fail("cue_count")
	if not beat.get("monitors",[]) is Array:return _fail("boss_malformed")
	var bosses: Array = []
	for source in beat.get("monitors", []):
		if source is Dictionary and not source.has("actor"): bosses.append(source)
	if bosses.size() != 1: return _fail("boss_count")
	var boss: Dictionary = bosses[0]
	var angle_raw = boss.get("angle"); var radius_raw = boss.get("radius")
	if str(boss.get("kind", "")) != "half" or not (angle_raw is int or angle_raw is float) or not (radius_raw is int or radius_raw is float): return _fail("boss_malformed")
	var angle := float(angle_raw); var radius := float(radius_raw)
	if not is_finite(angle) or not is_finite(radius) or radius <= 0 or not (is_equal_approx(angle, 90.0) or is_equal_approx(angle, -90.0)): return _fail("boss_angle")
	var sign_x: int = 1 if angle > 0 else -1
	var order: Array = allocate(marked, str(config.policy))
	if order.size() != 8: return _fail("allocation")
	return {"ok": true, "order": order, "sign_x": sign_x, "marked": marked, "sides": sides, "policy": str(config.policy)}

static func goal(actor: int, beat: Dictionary, actors: Array, state: Dictionary) -> Vector2:
	var pos: Vector2 = Rules.v(actors[actor].pos)
	if actor == int(state.get("human_actor", -1)): return pos
	var seen := observed(beat, actors, state)
	if not seen.ok: return pos
	var slot: int = seen.order.find(actor)
	if slot < 0: return pos
	return canonical(seen.sign_x)[slot]

static func facing(actor: int, beat: Dictionary, actors: Array, state: Dictionary):
	var face = actors[actor].get("face", 0.0)
	if actor == int(state.get("human_actor", -1)): return face
	var seen := observed(beat, actors, state)
	if not seen.ok: return face
	var slot: int = seen.order.find(actor)
	if slot < 0 or slot >= 3: return face
	var goals := [270.0 * seen.sign_x, 0.0, 180.0]
	return float(goals[slot]) - float(seen.sides[actor])
