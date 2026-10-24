# SPDX-License-Identifier: MIT
extends SceneTree
## PLAYER verdict = actual attack/status/death outcomes, never guide coordinates.
## Synthetic minimal beats exercise the real Rules/Statuses/P6/Sigma code paths; this
## does NOT claim the 100-option generator, a 4-person layout, or full guide solving.
const Rules = preload("res://scripts/rules.gd")
const Statuses = preload("res://scripts/statuses.gd")
const P6Damage = preload("res://scripts/p6_damage.gd")
const Sigma = preload("res://scripts/p5_sigma_runtime.gd")
const Omega = preload("res://scripts/p5_omega_runtime.gd")

var checks: Array = []

func ok(name: String, condition: bool, detail = null) -> void:
	checks.append({"name": name, "pass": condition, "detail": detail})

func party(points: Array) -> Array:
	var actors: Array = []
	var roles := ["MT","ST","H1","H2","D1","D2","D3","D4"]
	for i in 8: actors.append({"role": roles[i], "pos": points[i], "face": 0.0})
	return actors

func ring(radius: float) -> Array:
	var out: Array = []
	for i in 8: out.append(Vector2(sin(TAU * i / 8.0), -cos(TAU * i / 8.0)) * radius)
	return out

func fresh() -> Dictionary:
	var s := {"sim_time": 0.0, "dynamis": [0,0,0,0,0,0,0,0], "spent": []}
	Statuses.ensure(s)
	return s

func _init() -> void:
	# Safe non-guide positions: arbitrary ring off any suggested point, AoE at centre.
	var safe := party(ring(12.0))
	var aoe := {"shapes": [{"kind": "circle", "pos": [0, 0], "radius": 5, "name": "Centre AoE"}]}
	ok("safe_non_guide_positions_pass", Rules.evaluate(aoe, safe, fresh()).is_empty())
	var hit_points := ring(12.0); hit_points[3] = Vector2(1, 1)
	ok("real_aoe_hit_fails", not Rules.evaluate(aoe, party(hit_points), fresh()).is_empty())
	var tower := {"shapes": [{"kind": "tower", "rule": "count", "count": 2, "pos": [0, -12], "radius": 3, "name": "Tower"}]}
	ok("tower_wrong_count_fails", not Rules.evaluate(tower, safe, fresh()).is_empty())
	var tower_points := ring(12.0); tower_points[1] = Vector2(1, -12)
	ok("tower_correct_count_any_members_pass", Rules.evaluate(tower, party(tower_points), fresh()).is_empty())
	var tether := {"checks": [{"kind": "distance", "a": 0, "b": 4, "min": 30, "name": "Tether"}]}
	ok("tether_distance_fails", not Rules.evaluate(tether, safe, fresh()).is_empty())
	# Vulnerability control: second magic hit during live Magic Vulnerability fails.
	var vs := fresh()
	Statuses.magic_hit(vs, [2], "Control A")
	Statuses.magic_hit(vs, [2], "Control B")
	ok("vulnerability_double_hit_fails", vs.runtime_failures.size() == 1, vs.runtime_failures)
	# Persistent dead actor standing safely at its guide coordinate must fail; JSON float form too.
	var ds := fresh(); ds.dead = [5]
	ok("dead_actor_safe_position_fails", Rules.evaluate(aoe, safe, ds).any(func(f): return "D2: dead" in str(f)))
	var js: Dictionary = JSON.parse_string(JSON.stringify({"dead": [5], "dynamis": [0,0,0,0,0,0,0,0]}))
	ok("dead_actor_json_numeric_fails", Rules.evaluate(aoe, safe, js).any(func(f): return "D2: dead" in str(f)), js.dead)
	ok("living_actor_no_death_failure", not Rules.evaluate(aoe, safe, fresh()).any(func(f): return "dead" in str(f)))
	# P6 flare: unmeasured near separation -> VERIFICATION advisory, no failure, no damage claim.
	var fs := fresh(); fs.p6 = {}
	var near := ring(12.0)
	var packets := P6Damage.flares(party(near), [0], fs)
	P6Damage.flares(party(near), [0], fs)
	var verification: Array = fs.get("advisories", []).filter(func(a): return a.kind == "verification")
	ok("flare_unmeasured_no_runtime_failure", fs.runtime_failures.is_empty(), fs.runtime_failures)
	ok("flare_unmeasured_advisory_deduped", verification.size() == 1, verification)
	ok("flare_damage_still_unknown", packets.all(func(p): return p.target_actor == p.source_actor or p.distance >= P6Damage.MIN_OBSERVED_FAR_DISTANCE or (p.bounds.known == false and p.bounds.upper == null)) and str(fs.p6.damage_verification).begins_with("incomplete"))
	ok("flare_no_death_invented", fs.dead.is_empty())
	ok("flare_no_HP_synthesized_and_bounds_unknown", not fs.has("p6_hp") and packets.all(func(p):return p.bounds.upper==null and not p.bounds.known))
	fs.beat_started=5.0;fs.sim_time=5.0;P6Damage.flares(party(near),[0],fs)
	ok("flare_later_beat_verification_recorded_separately", fs.advisories.filter(func(a):return a.kind=="verification").size()==2)
	var bad := fresh(); bad.p6 = {}
	var nan_points := ring(12.0); nan_points[1] = Vector2(NAN, 0)
	P6Damage.flares(party(nan_points), [0], bad)
	ok("flare_nonfinite_still_rejected", bad.runtime_failures.has("P6 flare has non-finite actor positions"))
	fs.p6_hp = []
	for i in 8: fs.p6_hp.append({"hp": 100000.0, "shield": 0.0})
	var lethal := P6Damage.apply_packet(fs, 3, 150000.0)
	ok("known_lethal_packet_kills", lethal.ok and 3 in fs.dead)
	ok("known_lethal_packet_fails_verdict", Rules.evaluate(aoe, safe, fs).any(func(f): return "H2: dead" in str(f)))
	# Sigma coaching allocation gap: GUIDE advisory, but actual Looper expiry still kills/fails.
	var ss := fresh()
	var sigma_beat := {"sigma_config": {"id": "outcome_test", "remote": false, "near": 0, "far": 1, "priority": [0,1,2,3,4,5,6,7], "family": "cn", "profile": "outcome_test_legacy", "path_key": "unused"}, "sigma_path_index": 0, "positions": [], "labels": []}
	Sigma.begin(sigma_beat, ss)
	Sigma.begin(sigma_beat, ss)
	var guide: Array = ss.get("advisories", []).filter(func(a): return a.kind == "guide")
	ok("sigma_allocation_guide_advisory_once", guide.size() == 1, guide)
	ok("sigma_allocation_not_runtime_failure", ss.runtime_failures.is_empty(), ss.runtime_failures)
	ok("sigma_no_roles_synthesized", ss.sigma.roles.is_empty())
	var actors := party(ring(12.0))
	ss.sim_time = 17.0; Sigma.tick(actors, actors, ss, 0.1)
	ss.sim_time = 35.0; Sigma.tick(actors, actors, ss, 0.1)
	ok("sigma_looper_expiry_still_fails", ss.runtime_failures.size() == 8 and ss.dead.size() == 8, ss.runtime_failures)
	ok("sigma_dead_fail_verdict_despite_advisory", Rules.evaluate({}, actors, ss).size() == 8)
	var os := fresh()
	var oc := {"id":"outcome_omega", "profile":"outcome_test_legacy", "first":[0,1], "second":[2,3], "priority":[0,1,2,3,4,5,6,7], "standalone":true}
	var ob := {"omega_config":oc, "omega_phase":"first"}
	Omega.begin(ob,os);Omega.begin(ob,os)
	ok("omega_allocation_advisory_no_synthesized_roles", os.runtime_failures.is_empty() and os.omega.first_roles.is_empty() and os.advisories.filter(func(a):return a.kind=="guide").size()==1)
	var terminal := Omega.snapshot({"omega_config":oc,"omega_first_finish":true},actors,os)
	ok("omega_actual_terminal_bad_Dynamis_still_fails", not terminal.is_empty(),terminal)
	var passed := checks.filter(func(c): return c.pass).size()
	print("OUTCOME_VERDICT_RESULT " + JSON.stringify({"passed": passed, "total": checks.size(), "failed": checks.filter(func(c): return not c.pass).map(func(c): return {"name": c.name, "detail": str(c.detail)}), "scope": "synthetic beats on real rule code; not generator-wide, not full guide solving"}))
	quit(0 if passed == checks.size() else 1)
