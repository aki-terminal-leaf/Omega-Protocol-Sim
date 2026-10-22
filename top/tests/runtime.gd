extends SceneTree
const Main = preload("res://scenes/main.tscn")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = Main.instantiate(); root.add_child(app)
	await process_frame
	app.set_process(false)
	var errors = 0; var courses = 0
	var only_scenario := ""; var only_seed := -1; var only_method := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only-scenario="): only_scenario = argument.trim_prefix("--only-scenario=")
		if argument.begins_with("--only-seed="): only_seed = int(argument.trim_prefix("--only-seed="))
		if argument.begins_with("--only-method="): only_method = int(argument.trim_prefix("--only-method="))
	if only_scenario == "p5_full" and "--hidden-fixture" in OS.get_cmdline_user_args():
		app.catalog.append({"id":"p5_full","phase":5,"name":"Internal continuous P5 fixture","focus":"state persistence","fidelity":"training"})
		app.filter_catalog()
	var stress: bool = "--contact-stress" in OS.get_cmdline_user_args()
	if app.configured or app.running or not app.encounter.is_empty(): print("FLOW FAIL: boot must wait for a mechanism and strategy"); errors += 1
	for i in app.filtered.size():
		if only_scenario != "" and app.filtered[i].id != only_scenario: continue
		if stress and app.filtered[i].id not in ["p1_loop", "p2_limitless"]: continue
		if "--limitless-only" in OS.get_cmdline_user_args() and app.filtered[i].id != "p2_limitless": continue
		app.choose_mechanic(i)
		if app.configured or not app.encounter.is_empty(): print("FLOW FAIL: mechanism alone must not select a strategy"); errors += 1
		var method_count: int = app.strategy_select.item_count
		for method in range(1, method_count):
			if only_method >= 0 and method != only_method: continue
			for seed_value in ([only_seed] if only_seed >= 0 else (range(1,49) if stress else [17391, 7, 43])):
				app.choose_mechanic(i); app.strategy_select.select(method); app.choose_strategy(method)
				app.seed_edit.text = str(seed_value); app.demo = true; app.start_run(0,false); app.stop_failure.button_pressed = false
				var ticks = 0
				while app.running and ticks < 10000:
					app._process(0.1); ticks += 1
				courses += 1
				if "--source-timeline" in OS.get_cmdline_user_args():
					var proof:Dictionary=preload("res://tests/timeline_observations.gd").validate(app)
					if not proof.failures.is_empty():print("SOURCE_TIMELINE FAIL ",proof.failures);errors+=1
					else:print("SOURCE_TIMELINE PASS ",app.encounter.id," method",method," seed",seed_value," checks",proof.checks)
				if "--progress" in OS.get_cmdline_user_args(): print("RUNTIME COURSE ",courses," ",app.encounter.id," method",method," seed",seed_value," failures",app.all_errors.size())
				if not app.all_errors.is_empty() or app.running:
					print("RUNTIME FAIL ", app.encounter.id," / ",method," seed ",seed_value, ": ",app.all_errors); errors += 1
				if "--diagnose" in OS.get_cmdline_user_args() and not app.all_errors.is_empty():
					for entry in app.journal: print("BEAT ",entry.title," ERR ",entry.failures," HOLDERS ",entry.actual_tether_holders," ACTORS ",entry.get("actors",[]))
					print("PICKUPS ",app.state.get("tether_events",[]))
				# Source tests queue UI/model nodes for deletion; process their frees each
				# course so an exhaustive matrix does not retain hundreds of scenes.
				await process_frame
				var completed: String = app.encounter.id
				app._process(10.0)
				if app.running or app.encounter.id != completed: print("FLOW FAIL: changed mechanism without user selection"); errors += 1
				if completed == "p1_loop" and app.state.get("tether_events", []).is_empty(): print("CONTACT FAIL: demo has no actual pickup"); errors += 1
	if courses == 0: print("RUNTIME FAIL: no courses matched the requested filters"); errors += 1
	app.return_to_selection()
	app.start_run()
	if app.running: print("FLOW FAIL: R/start without a new strategy must not launch"); errors += 1
	print("RUNTIME COURSES ", courses, " FAILURES ", errors)
	app.queue_free(); await process_frame
	quit(1 if errors else 0)
