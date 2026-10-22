# SPDX-License-Identifier: MIT
extends RefCounted
## Pure CN poster panels 11/12 policy. No positions, clocks, combat, RNG or mutation.
## Pairs are authoritative [Near, Far]; stacks are ACTUAL, never forecast.
## Stop is markers.gd's ignore, Chain is bind. Other profiles are source-pending.
const ATTACKS = ["attack1", "attack2", "attack3", "attack4"]
const STOPS = ["ignore1", "ignore2"]
const BINDS = ["bind1", "bind2", "bind3"]
const SIGNS = ["", "attack1", "attack2", "attack3", "attack4", "attack5", "attack6", "attack7", "attack8", "ignore1", "ignore2", "bind1", "bind2", "bind3", "square", "circle", "plus", "triangle"]
const ROLE_NAMES = ["near_holder", "far_holder", "near_jump1", "near_jump2", "far_jump1", "far_jump2", "utility_left", "utility_right"]

static func whole(value: Variant, low: int, high: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func issue(out: Dictionary, code: String, actor: int = -1, marker: String = "") -> void:
	out.errors.append({"code": code, "actor": actor, "marker": marker})

static func expected(profile: String, dynamis: Variant, first: Variant, second: Variant, phase: String) -> Dictionary:
	var out: Dictionary = {"supported": profile == "cn_moogle", "valid": false, "errors": [], "classes": [], "mandatory": [], "eligible": [], "holders": [], "phase": phase}
	if not out.supported:
		issue(out, "unsupported_source_pending")
		return out
	if phase not in ["first", "second"]:
		issue(out, "invalid_phase")
		return out
	if not dynamis is Array or dynamis.size() != 8:
		issue(out, "invalid_dynamis_length")
		return out
	for value in dynamis:
		if not whole(value, 0, 3):
			issue(out, "invalid_dynamis_integer")
			return out
	var seen: Array = []
	for pair in [first, second]:
		if not pair is Array or pair.size() != 2:
			issue(out, "invalid_world_pair")
			return out
		for value in pair:
			if not whole(value, 0, 7) or int(value) in seen:
				issue(out, "invalid_world_actor")
				return out
			seen.append(int(value))
	var first_ids: Array = [int(first[0]), int(first[1])]
	var second_ids: Array = [int(second[0]), int(second[1])]
	out.holders = first_ids if phase == "first" else second_ids
	for actor in 8:
		var count: int = int(dynamis[actor])
		var kind: String = "invalid"
		if actor in out.holders:
			kind = "unmarked"
			if (phase == "first" and count not in [1, 2]) or (phase == "second" and count != 2):
				issue(out, "wrong_world_stack", actor)
		elif phase == "first":
			if count == 1:
				kind = "attack"
			elif count == 2:
				kind = "stop" if actor in second_ids else "bind"
				out.eligible.append(actor)
				if kind == "stop":
					out.mandatory.append(actor)
		else:
			if count == 2:
				kind = "attack"
			elif count == 3:
				kind = "stop"
				out.mandatory.append(actor)
				out.eligible.append(actor)
		out.classes.append(kind)
		if kind == "invalid":
			issue(out, "ineligible_actual_stack", actor)
	if out.eligible.size() < 2 or (phase == "second" and out.eligible.size() != 2):
		issue(out, "invalid_utility_count")
	out.valid = out.errors.is_empty()
	return out

## Events use markers.gd's real event schema. phase_start_sequence is a caller-owned
## history boundary (NOT a timing cutoff). It excludes prior-phase self receipts.
## Owners are authoritative observations; events never create or repair owners.
static func resolve(profile: String, dynamis: Variant, first: Variant, second: Variant, phase: String, owners: Variant, events: Variant, human: Variant, phase_start_sequence: Variant = 0) -> Dictionary:
	var out: Dictionary = expected(profile, dynamis, first, second, phase)
	out["roles"] = [-1, -1, -1, -1, -1, -1, -1, -1]
	out["intents"] = []
	out["unresolved"] = []
	out["displaced"] = []
	out["self_action"] = {"observed": false, "current": false, "events": []}
	out["npc_self_actions"] = []
	out["complete"] = false
	out["observations_valid"] = false
	out["combat_failures"] = [] # Contract errors are never damage/death.
	if not out.valid:
		return out
	if not whole(human, 0, 7) or not whole(phase_start_sequence, 0, 2147483647):
		issue(out, "invalid_human_or_phase_sequence")
		return out
	if not owners is Array or owners.size() != 8 or not events is Array:
		issue(out, "invalid_observations")
		return out
	for sign in owners:
		if not sign is String or sign not in SIGNS:
			issue(out, "invalid_marker")
			return out
	var duplicate: Array = []
	for actor in 8:
		if owners[actor] != "" and owners.count(owners[actor]) > 1:
			duplicate.append(actor)
			issue(out, "duplicate_marker", actor, owners[actor])
	out.observations_valid = true
	out.roles[0] = out.holders[0]
	out.roles[1] = out.holders[1]
	var utility: Array = []
	var mandatory_ready: bool = true
	for actor in out.mandatory:
		if owners[actor] not in STOPS or actor in duplicate:
			mandatory_ready = false
	# Real sign order, not actor/job priority. Every eligible actor can claim a
	# free legal sign; an unmarked mandatory II cannot be replaced by a Chain.
	for sign in STOPS:
		var actor: int = owners.find(sign)
		if actor >= 0 and actor in out.mandatory and actor not in duplicate:
			utility.append(actor)
	if mandatory_ready and phase == "first":
		for sign in BINDS:
			var actor: int = owners.find(sign)
			if utility.size() < 2 and actor >= 0 and out.classes[actor] == "bind" and actor not in duplicate:
				utility.append(actor)
	var selected: bool = mandatory_ready and utility.size() == 2
	if selected:
		out.roles[6] = utility[0]
		out.roles[7] = utility[1]
	for actor in 8:
		var sign: String = owners[actor]
		var kind: String = out.classes[actor]
		if actor in duplicate:
			continue
		if kind == "unmarked":
			if sign != "":
				issue(out, "world_must_be_unmarked", actor, sign)
		elif sign == "":
			issue(out, "missing_marker", actor)
		elif kind == "stop":
			if sign not in STOPS:
				issue(out, "mandatory_stop", actor, sign)
		elif kind == "bind":
			if sign in BINDS:
				if selected and actor not in utility:
					issue(out, "unused_bind_needs_attack", actor, sign)
			elif sign in ATTACKS:
				if not selected:
					issue(out, "attack_before_monitor_selection", actor, sign)
			else:
				issue(out, "wrong_marker_class", actor, sign)
		elif kind == "attack" and sign not in ATTACKS:
			issue(out, "wrong_marker_class", actor, sign)
		# A remaining eligible Chain can become an Attack only AFTER selection.
		if sign in ATTACKS and (kind == "attack" or (kind == "bind" and selected and actor not in utility)):
			var slot: int = [5, 2, 3, 4][ATTACKS.find(sign)]
			out.roles[slot] = actor
	if not selected:
		issue(out, "unresolved_utility")
	for slot in 8:
		if out.roles[slot] < 0:
			out.unresolved.append(ROLE_NAMES[slot])
		else:
			out.intents.append({"actor": out.roles[slot], "slot": slot, "role": ROLE_NAMES[slot]})
	_receipts(out, owners, events, int(human), int(phase_start_sequence))
	out.complete = out.errors.is_empty() and out.unresolved.is_empty()
	return out

static func _receipts(out: Dictionary, owners: Array, events: Array, human: int, after: int) -> void:
	var latest_human: int = -1
	var previous_sequence: int = -1
	for raw in events:
		if not raw is Dictionary:
			issue(out, "invalid_marker_event")
			continue
		if not whole(raw.get("sequence"), 1, 2147483647) or not whole(raw.get("actor"), 0, 7) or not whole(raw.get("target"), 0, 7) or not whole(raw.get("displaced", -1), -1, 7):
			issue(out, "invalid_marker_event")
			continue
		var sequence: int = int(raw.sequence)
		if sequence <= previous_sequence:
			issue(out, "unordered_marker_events")
		previous_sequence = sequence
		if not raw.get("marker") is String or raw.marker not in SIGNS or raw.get("operation") != ("clear" if raw.marker == "" else "assign") or not raw.get("source") is String:
			issue(out, "invalid_marker_event")
			continue
		if sequence <= after:
			continue
		var actor: int = int(raw.actor)
		var target: int = int(raw.target)
		var displaced: int = int(raw.get("displaced", -1))
		if displaced >= 0:
			out.displaced.append({"actor": displaced, "by": target, "marker": raw.marker, "sequence": sequence})
		if target == human or displaced == human:
			latest_human = sequence
		if actor == target and actor == human and raw.source == "player":
			out.self_action.events.append(raw.duplicate(true))
			out.self_action.observed = true
		elif actor == target and actor != human and raw.source == "npc":
			out.npc_self_actions.append(raw.duplicate(true))
	# A real but subsequently displaced/overwritten self action stays a receipt,
	# never proof of a currently owned sign or of a correct classification.
	if not out.self_action.events.is_empty():
		var last: Dictionary = out.self_action.events.back()
		out.self_action.current = int(last.sequence) == latest_human and owners[human] == last.marker
