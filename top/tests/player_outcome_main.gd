# SPDX-License-Identifier: MIT
extends SceneTree
## Actual Main + Input events. Not native OS/Web/manual evidence.
const Scene = preload("res://scenes/main.tscn")
const Status = preload("res://scripts/statuses.gd")
const Damage = preload("res://scripts/p6_damage.gd")
var checks: Array = []
func check(name: String, ok: bool, details = null) -> void:
	checks.append({"name":name,"ok":ok,"details":details})
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func fresh_solar():
	var app=Scene.instantiate();root.add_child(app);await process_frame;app.set_process(false)
	for i in app.filtered.size():
		if app.filtered[i].id=="p5_solar":app.choose_mechanic(i);break
	app.strategy_select.select(1);app.choose_strategy(1)
	app.fresh_seed.button_pressed=false;app.seed_edit.text="17391";app.speed_select.select(2)
	app.demo=false;app.stop_failure.button_pressed=true;app.start_run(0,false);app.set_process(false)
	return app
func move(app, code: int, seconds: float) -> void:
	key(code,true);await process_frame
	for _i in int(round(seconds/.02)):app._process(.02)
	key(code,false);await process_frame
func snapshot(app) -> void:
	var steps=0
	while app.journal.is_empty() and app.running and steps<400:
		app._process(.02);steps+=1
	check("actual_snapshot_obtained",not app.journal.is_empty(),steps)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var app=await fresh_solar()
	var before:Vector2=app.actors[4].pos
	await move(app,KEY_W,1.0)
	var actual:Vector2=app.actors[4].pos
	check("physical_input_changed_human",actual.distance_to(before)>5.5,actual)
	# This only proves a different legal position was exercised. Product PASS below
	# still comes solely from the actual attack/status/death result, never this distance.
	check("safe_case_not_NPC_guide_position",actual.distance_to(app.current.positions[4])>3.0)
	Status.advise(app.state,"guide","Source test: coaching allocation unavailable")
	snapshot(app)
	check("safe_alternative_actual_attack_passes",not app.journal.is_empty() and app.journal[0].failures.is_empty() and app.beat_passed==1 and app.beat_failed==0,app.all_errors)
	check("safe_alternative_no_abnormal_status_or_death",not app.state.statuses[4].has("magic_vulnerability") and app.state.dead.is_empty())
	var report:Dictionary=app.report()
	check("advisory_separate_from_failure",report.advisories.size()==1 and report.failures.is_empty() and app.journal[0].advisories.size()==1)
	check("report_has_outcome_policy",report.verdict_policy.basis=="actual_attack_status_death" and not report.verdict_policy.guide_position_required)
	check("review_advisory_does_not_log_failure",app.feedback.text.contains("攻略提示") and app.beat_failed==0)
	app.queue_free();await process_frame
	app=await fresh_solar()
	await move(app,KEY_A,1.0)
	await move(app,KEY_W,2.6)
	snapshot(app)
	check("actual_attack_clip_fails",not app.all_errors.is_empty() and app.beat_failed==1,app.all_errors)
	check("actual_attack_applies_status",app.state.statuses[4].has("magic_vulnerability"),app.state.statuses[4])
	app.queue_free();await process_frame
	app=await fresh_solar()
	app.state.p6_hp=[]
	for _i in 8:app.state.p6_hp.append({"hp":100.0,"shield":0.0})
	var lethal:Dictionary=Damage.apply_packet(app.state,4,101.0)
	check("real_packet_causes_death",lethal.ok and 4 in app.state.dead)
	snapshot(app)
	check("dead_at_safe_guide_position_still_fails",app.beat_failed==1 and app.all_errors.any(func(e):return "D1: dead" in str(e)),app.all_errors)
	Status.advise(app.state,"guide","Source test: before R")
	key(KEY_R,true);await process_frame;key(KEY_R,false);await process_frame;app.set_process(false)
	check("R_clears_prior_dead_and_advisories",app.state.dead.is_empty() and app.state.get("advisories",[]).is_empty() and app.all_errors.is_empty())
	check("R_retains_same_seed",int(app.encounter.seed)==17391)
	# Controlled verification-advisory integration, not a P6 runtime in a Solar phase.
	Status.advise(app.state,"verification","Source test: damage measurement remains incomplete")
	snapshot(app)
	var uncertain:Dictionary=app.report()
	check("unknown_measurement_not_invented_player_failure",app.beat_passed==1 and app.beat_failed==0 and app.all_errors.is_empty())
	check("unknown_verification_not_claimed_complete",uncertain.verification_status=="partial" and app.journal[0].verification_status=="partial" and app.journal[0].outcome=="pass" and uncertain.verdict_policy.verification_is_separate)
	app.queue_free();await process_frame
	var failed=checks.filter(func(c):return not c.ok)
	print("OUTCOME_MAIN_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failed,"courses":4,"evidence":checks,"scope":"Actual Main/Input and real attack/status/death outcomes; no native/Web/manual/allguide credit"}))
	quit(0 if failed.is_empty() else 1)
