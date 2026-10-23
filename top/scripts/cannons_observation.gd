# SPDX-License-Identifier: MIT
extends RefCounted
## Only actual displayed textured-head actor IDs enter this planner.
## Empty receipts preserve memory (including the public no-head gap).
## Invalid nonempty receipts poison this epoch: no hidden-answer recovery.
const C = preload("res://scripts/p1_courses.gd")
const R = preload("res://scripts/rules.gd")
const PROFILES: Array = ["elemental","aether","lpdu","cn_moogle","kr_09stop"]
const DOMAIN: Array = [2,3,4,5,6,7]
const KEY: String = "cannons_observation"

static func neutral(actor: int) -> Vector2:
	return Vector2(-3.5+actor,6.0)

static func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func trio(value: Variant) -> Array:
	if not value is Array or value.size()!=3: return []
	var result: Array=[]
	for raw in value:
		if not finite_number(raw): return []
		var number: float=float(raw)
		if number!=floor(number) or number<2.0 or number>7.0: return []
		var actor: int=int(number)
		if actor in result: return []
		result.append(actor)
	result.sort()
	return result

static func complement(ids: Array) -> Array:
	var result: Array=[]
	for actor in DOMAIN:
		if actor not in ids: result.append(actor)
	return result

static func selection(beat: Dictionary) -> Dictionary:
	var raw: Variant=beat.get("cannons_public",null)
	if not raw is Dictionary: return {}
	if str(raw.get("profile_id","")) not in PROFILES: return {}
	if not raw.get("dynamic",null) is bool or not raw.get("split_tanks",null) is bool: return {}
	if str(raw.get("phase","")) not in ["first","recover","second"]: return {}
	return {"profile_id":str(raw.profile_id),"dynamic":bool(raw.dynamic),"split_tanks":bool(raw.split_tanks)}

static func begin(beat: Dictionary, state: Dictionary) -> void:
	# Parent invokes only for a fresh Cannons p1_events run; later beats retain it.
	state[KEY]={"version":1,"origin":float(state.get("sim_time",0.0)),"selection":selection(beat),"first_ids":[],"second_ids":[],"first_at":null,"second_at":null,"first_relative":null,"second_relative":null,"first_basis":"","second_basis":"","complement_ids":[],"complement_at":null,"complement_basis":"","blocked":false,"checkpoint_fixture":{},"invalid_receipts":[],"source_onset":"source_unknown"}

static func memory(beat: Dictionary, state: Dictionary) -> Dictionary:
	var raw: Variant=state.get(KEY,null)
	if not raw is Dictionary: return {}
	var chosen: Dictionary=selection(beat)
	if chosen.is_empty() or raw.get("selection",null)!=chosen: return {}
	if raw.get("version",null)!=1 or not raw.get("blocked",null) is bool or raw.blocked: return {}
	if raw.get("source_onset","")!="source_unknown" or not raw.get("invalid_receipts",null) is Array: return {}
	if not raw.invalid_receipts.is_empty(): return {}
	if not finite_number(raw.get("origin",null)) or not finite_number(state.get("sim_time",null)): return {}
	var origin: float=float(raw.origin)
	var now: float=float(state.sim_time)
	if now<origin: return {}
	for wave in ["first","second"]:
		var ids: Variant=raw.get(wave+"_ids",null)
		if not ids is Array: return {}
		if ids.is_empty():
			if raw.get(wave+"_at",null)!=null or raw.get(wave+"_relative",null)!=null or raw.get(wave+"_basis","")!="": return {}
			continue
		if trio(ids).is_empty() or not finite_number(raw.get(wave+"_at",null)) or not finite_number(raw.get(wave+"_relative",null)): return {}
		var at: float=float(raw[wave+"_at"])
		var relative: float=at-origin
		if at>now+0.000001 or absf(relative-float(raw[wave+"_relative"]))>0.000001: return {}
		if (wave=="first" and (relative<0.0 or relative>=6.0)) or (wave=="second" and (relative+0.000001<9.9 or relative>=15.0)): return {}
		if raw.get(wave+"_basis","")!="displayed_textured_heads": return {}
	var first: Array=trio(raw.first_ids)
	var second: Array=trio(raw.second_ids)
	if not first.is_empty():
		if trio(raw.get("complement_ids",null))!=complement(first): return {}
		if raw.get("complement_basis","")!="observed_first_trio/public_six_non_tanks_two_disjoint_waves": return {}
		if raw.get("complement_at",null)!=raw.first_at: return {}
		if not second.is_empty() and second!=complement(first): return {}
	elif raw.get("complement_ids",[])!=[] or raw.get("complement_at",null)!=null or raw.get("complement_basis","")!="": return {}
	var fixture:Variant=raw.get("checkpoint_fixture",{})
	if not fixture is Dictionary:return {}
	if not fixture.is_empty():
		var assisted:Variant=state.get("cannons_checkpoint_assisted",false)
		if not assisted is bool or not assisted:return {}
		if fixture.get("basis","")!="assisted_checkpoint_fixture_not_observed":return {}
		if fixture.get("source","")!="builder_first_wave_targets":return {}
		var known:Array=trio(fixture.get("first_ids",null))
		if known.is_empty() or not finite_number(fixture.get("at",null)):return {}
		if float(fixture.at)<origin or float(fixture.at)>now+0.000001:return {}
		if not first.is_empty() and first!=known:return {}
		if not second.is_empty() and second!=complement(known):return {}
	return raw

static func install_checkpoint_fixture(beat:Dictionary,state:Dictionary,first_targets:Array)->void:
	# Only Main's explicitly assisted synthetic pre-roll grants this PAST-wave
	# fixture. It is deliberately NOT a displayed/head receipt or manual credit.
	var assisted:Variant=state.get("cannons_checkpoint_assisted",false)
	if not assisted is bool or not assisted or not beat.has("p1_events"):return
	var seen:Dictionary=memory(beat,state);var ids:Array=trio(first_targets)
	if seen.is_empty() or ids.is_empty() or not seen.first_ids.is_empty() or not seen.second_ids.is_empty():return
	seen.checkpoint_fixture={"first_ids":ids,"at":float(state.sim_time),"basis":"assisted_checkpoint_fixture_not_observed","source":"builder_first_wave_targets"}

static func known_first(seen:Dictionary)->Array:
	var actual:Array=trio(seen.first_ids)
	if not actual.is_empty():return actual
	return trio(seen.get("checkpoint_fixture",{}).get("first_ids",[]))

static func reject(state: Dictionary, displayed: Array, reason: String) -> void:
	var seen: Dictionary=state[KEY]
	seen.blocked=true
	# Invalid input itself may contain non-JSON values: record reason/count only.
	if not seen.get("invalid_receipts",null) is Array: seen.invalid_receipts=[]
	seen.invalid_receipts.append({"at":float(state.get("sim_time",0.0)),"count":displayed.size(),"reason":reason})

static func publish(beat: Dictionary, state: Dictionary, displayed: Array) -> void:
	if not state.get(KEY,null) is Dictionary: return
	if state[KEY].get("blocked",true)!=false: return
	var seen: Dictionary=memory(beat,state)
	if seen.is_empty():
		reject(state,displayed,"invalid_cache_or_public_selection")
		return
	if displayed.is_empty(): return
	var ids: Array=trio(displayed)
	if ids.is_empty():
		reject(state,displayed,"incomplete_duplicate_or_out_of_domain")
		return
	var now: float=float(state.sim_time)
	var relative: float=now-float(seen.origin)
	var wave: String="first" if relative>=0.0 and relative<6.0 else ("second" if relative+0.000001>=9.9 and relative<15.0 else "")
	if wave.is_empty():
		reject(state,displayed,"heads_outside_current_public_window")
		return
	var previous: Array=trio(seen[wave+"_ids"])
	if not previous.is_empty() and previous!=ids:
		reject(state,displayed,"contradictory_visible_trio")
		return
	if wave=="second" and not known_first(seen).is_empty() and ids!=complement(known_first(seen)):
		reject(state,displayed,"second_not_disjoint_complement")
		return
	if previous.is_empty():
		seen[wave+"_ids"]=ids
		seen[wave+"_at"]=now
		seen[wave+"_relative"]=relative
		seen[wave+"_basis"]="displayed_textured_heads"
		if wave=="first":
			seen.complement_ids=complement(ids)
			seen.complement_at=now
			seen.complement_basis="observed_first_trio/public_six_non_tanks_two_disjoint_waves"

static func goal(actor: int, beat: Dictionary, _actors: Array, state: Dictionary) -> Vector2:
	# Pure: no actor/status/event/observation writes, and no solved positions read.
	var chosen: Dictionary=selection(beat)
	if actor<0 or actor>7 or chosen.is_empty(): return neutral(actor)
	var ctx: Dictionary={"profile":{"id":chosen.profile_id,"p1_tank_variant":"split_mitigated" if chosen.split_tanks else "north_together"}}
	# Public static role/tank destinations never require a marker receipt.
	if actor<2 or not chosen.dynamic: return C.cannon_goals(ctx,[],false)[actor]
	if str(beat.cannons_public.phase)=="recover": return R.direction(180)*7
	var seen: Dictionary=memory(beat,state)
	if seen.is_empty(): return neutral(actor)
	var marked: Array=known_first(seen)
	if str(beat.cannons_public.phase)=="second":
		marked=trio(seen.second_ids)
		if marked.is_empty() and not known_first(seen).is_empty(): marked=complement(known_first(seen))
	if marked.is_empty(): return neutral(actor)
	return C.cannon_goals(ctx,marked,true)[actor]
