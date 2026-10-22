# SPDX-License-Identifier: MIT
extends SceneTree
const P = preload("res://scripts/omega_preparation.gd")
var cases: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	cases += 1
	if not value:
		failures += 1
		push_error(label)
func has_code(result: Dictionary, code: String) -> bool:
	for error in result.errors:
		if error.code == code:
			return true
	return false
func solve(stacks: Array, marks: Array, phase: String = "first", events: Array = [], human: Variant = 0, after: Variant = 0) -> Dictionary:
	return P.resolve("cn_moogle", stacks, [0, 1], [2, 3], phase, marks, events, human, after)
func event(seq: Variant, actor: Variant, target: Variant, sign: String, source: String = "player", displaced: int = -1) -> Dictionary:
	return {"sequence": seq, "actor": actor, "target": target, "marker": sign, "source": source, "displaced": displaced, "operation": "clear" if sign == "" else "assign"}
func run() -> void:
	var stacks: Array = [1, 1, 2, 2, 2, 2, 1, 1]
	var marks: Array = ["", "", "ignore2", "ignore1", "attack1", "attack4", "attack2", "attack3"]
	var r: Dictionary = solve(stacks, marks)
	check(r.complete and r.roles == [0, 1, 6, 7, 5, 4, 3, 2], "two mandatory II; actual Stop order; CN attack1 Far2/4 Far1")
	var one: Array = [1, 2, 2, 1, 2, 2, 1, 1]
	var one_marks: Array = ["", "", "ignore2", "attack1", "bind3", "attack4", "attack2", "attack3"]
	r = solve(one, one_marks)
	check(r.complete and r.roles[6] == 2 and r.roles[7] == 4, "Stop2 outranks Bind3; one mandatory")
	one_marks[4] = "attack4"; one_marks[5] = "bind1"
	r = solve(one, one_marks)
	check(r.complete and r.roles[7] == 5, "equally eligible alternative actor choice is legal")
	var zero: Array = [2, 2, 1, 1, 2, 2, 1, 1]
	var zero_marks: Array = ["", "", "attack1", "attack4", "bind2", "bind1", "attack2", "attack3"]
	r = solve(zero, zero_marks)
	check(r.complete and r.roles.slice(6) == [5, 4], "zero mandatory uses actual Bind order")
	var overflow: Array = [1, 2, 1, 1, 2, 2, 2, 1]
	var overflow_marks: Array = ["", "", "attack1", "attack2", "bind3", "bind2", "bind1", "attack4"]
	r = solve(overflow, overflow_marks)
	check(has_code(r, "unused_bind_needs_attack") and r.roles.slice(6) == [6, 5] and r.roles[3] == -1, "Bind3 overflow is unresolved, not silently an Attack")
	overflow_marks[4] = "attack3"
	check(solve(overflow, overflow_marks).complete, "explicit overflow conversion after selected monitors")
	var bad: Array = marks.duplicate(); bad[2] = ""
	r = solve(stacks, bad)
	check(not r.complete and r.roles[6] == -1 and has_code(r, "missing_marker") and r.combat_failures.is_empty(), "missing compulsory II cannot be filled by a priority fallback")
	bad[2] = "attack1"; bad[4] = "bind1"
	r = solve(stacks, bad)
	check(has_code(r, "mandatory_stop") and r.roles[6] == -1, "compulsory II cannot escape monitor using Attack")
	bad = marks.duplicate(); bad[0] = "bind1"
	r = solve(stacks, bad)
	check(has_code(r, "world_must_be_unmarked") and r.roles[0] == 0, "World I illegal mark never changes original holder")
	bad = marks.duplicate(); bad[6] = "ignore1"; bad[3] = "bind1"
	check(has_code(solve(stacks, bad), "wrong_marker_class"), "one stack cannot monitor")
	bad = marks.duplicate(); bad[4] = "bind1"; bad[5] = "bind2"
	r = solve(stacks, bad)
	check(r.roles.slice(6) == [3, 2] and has_code(r, "unused_bind_needs_attack"), "Stop1/2 precedence over both Binds")
	var second_stacks: Array = [2, 2, 2, 2, 3, 3, 2, 2]
	var second_marks: Array = ["attack1", "attack4", "", "", "ignore2", "ignore1", "attack2", "attack3"]
	r = solve(second_stacks, second_marks, "second")
	check(r.complete and r.roles == [2, 3, 6, 7, 1, 0, 5, 4], "actual three stack Stop utility; II remains unmarked")
	r = solve(second_stacks, marks, "second")
	check(not r.complete and has_code(r, "world_must_be_unmarked") and has_code(r, "mandatory_stop"), "stale first signs rejected at second phase")
	var json_stacks: Array = JSON.parse_string(JSON.stringify(stacks))
	r = P.resolve("cn_moogle", json_stacks, [0.0, 1.0], [2.0, 3.0], "first", marks, [event(1.0, 0.0, 0.0, "")], 0.0)
	check(r.complete and r.self_action.current, "integer JSON floats and human zero including real self clear")
	for value in [1.5, NAN, INF, "1", true]:
		var invalid: Array = stacks.duplicate(); invalid[0] = value
		check(has_code(solve(invalid, marks), "invalid_dynamis_integer"), "reject non-integral or nonnumeric stacks")
	check(has_code(solve([1, 2], marks), "invalid_dynamis_length"), "length validation")
	check(has_code(solve(stacks, marks, "first", [], 0.5), "invalid_human_or_phase_sequence"), "fractional actor rejected")
	check(has_code(P.expected("cn_moogle", stacks, [0, 1], [1, 3], "first"), "invalid_world_actor"), "overlapping authoritative Worlds rejected")
	for profile in ["elemental", "aether", "lpdu", "kr_09stop"]:
		check(not P.expected(profile, stacks, [0, 1], [2, 3], "first").supported, "other profiles explicitly source-pending")
	r = solve(stacks, marks, "first", [event(1, 6, 6, "attack2")], 6)
	check(r.self_action.current and r.self_action.observed, "real human self assignment receipt")
	r = solve(stacks, marks, "first", [event(1, 6, 7, "attack3")], 6)
	check(not r.self_action.observed, "human marking teammate is not self-action")
	r = solve(stacks, marks, "first", [event(1, 6, 6, "attack2", "npc"), event(2, 7, 7, "attack3", "npc")], 6)
	check(not r.self_action.observed and r.npc_self_actions.size() == 1, "NPC self events separate; NPC cannot impersonate human")
	bad = marks.duplicate(); bad[6] = ""; bad[7] = "attack2"
	r = solve(stacks, bad, "first", [event(1, 6, 6, "attack2"), event(2, 7, 7, "attack2", "npc", 6)], 6)
	check(r.self_action.observed and not r.self_action.current and r.displaced.size() == 1 and has_code(r, "missing_marker"), "displacement preserves honest receipt and missing role")
	r = solve(stacks, marks, "first", [event(1, 6, 6, "attack2")], 6, 1)
	check(not r.self_action.observed, "phase boundary excludes stale self receipt without invented time cutoff")
	bad = marks.duplicate(); bad[4] = "attack2"
	r = solve(stacks, bad)
	check(has_code(r, "duplicate_marker") and r.roles[2] == -1, "duplicate imported owners do not silently pick first actor")
	bad = marks.duplicate(); bad[4] = "attack8"
	check(has_code(solve(stacks, bad), "wrong_marker_class"), "generic marker exists but CN four-receiver contract rejects attack8")
	var four_binds: Array = [1, 1, 1, 1, 2, 2, 2, 2]
	var four_marks: Array = ["", "", "attack1", "attack2", "bind3", "bind2", "attack3", "attack4"]
	r = solve(four_binds, four_marks)
	check(r.complete and r.roles.slice(6) == [5, 4], "four eligible actors fit by explicit two monitor choices and two Attack conversions")
	four_marks[5] = "attack4"; four_marks[7] = ""
	r = solve(four_binds, four_marks)
	check(not r.complete and has_code(r, "attack_before_monitor_selection"), "premature overflow Attack cannot manufacture a second monitor")
	var wrong_second: Array = second_stacks.duplicate(); wrong_second[4] = 2
	r = solve(wrong_second, second_marks, "second")
	check(has_code(r, "invalid_utility_count") and r.roles[6] == -1, "no forecasted three-stack collector")
	r = solve(stacks, marks, "first", [event(1.5, 6, 6, "attack2")], 6)
	check(has_code(r, "invalid_marker_event") and not r.self_action.observed, "fractional event sequence rejected")
	r = solve(stacks, marks, "first", [event(1, 6, 6, "attack2"), event(2, 7, 6, "attack2")], 6)
	check(r.self_action.observed and not r.self_action.current, "a later teammate overwrite is not a current self action")
	r = solve(stacks, marks, "first", [event(2, 6, 6, "attack2"), event(1, 6, 6, "attack2")], 6)
	check(has_code(r, "unordered_marker_events"), "out-of-order history cannot claim complete contract")
	var before: String = JSON.stringify([stacks, marks])
	solve(stacks, marks)
	check(JSON.stringify([stacks, marks]) == before, "pure inputs unchanged; no gains or marks manufactured")
	print("NPC OMEGA PREPARATION cases=", cases, " failures=", failures)
	quit(1 if failures else 0)
