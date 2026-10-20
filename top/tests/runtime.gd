extends SceneTree
const Main = preload("res://scenes/main.tscn")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = Main.instantiate(); root.add_child(app)
	await process_frame
	app.set_process(false)
	var errors = 0; var courses = 0
	var stress: bool = "--contact-stress" in OS.get_cmdline_user_args()
	if app.configured or app.running or not app.encounter.is_empty(): print("FLOW FAIL: boot must wait for a mechanism and strategy"); errors += 1
	for i in app.filtered.size():
		if stress and app.filtered[i].id not in ["p1_loop", "p2_limitless"]: continue
		if "--limitless-only" in OS.get_cmdline_user_args() and app.filtered[i].id != "p2_limitless": continue
		app.choose_mechanic(i)
		if app.configured or not app.encounter.is_empty(): print("FLOW FAIL: mechanism alone must not select a strategy"); errors += 1
		var method_count: int = app.strategy_select.item_count
		for method in range(1, method_count):
			for seed_value in (range(1,49) if stress else [17391, 7, 43]):
				app.choose_mechanic(i); app.strategy_select.select(method); app.choose_strategy(method)
				app.seed_edit.text = str(seed_value); app.demo = true; app.start_run(); app.stop_failure.button_pressed = false
				var ticks = 0
				while app.running and ticks < 10000:
					app._process(0.1); ticks += 1
				courses += 1
				if not app.all_errors.is_empty() or app.running:
					print("RUNTIME FAIL ", app.encounter.id," / ",method," seed ",seed_value, ": ",app.all_errors); errors += 1
				var completed: String = app.encounter.id
				app._process(10.0)
				if app.running or app.encounter.id != completed: print("FLOW FAIL: changed mechanism without user selection"); errors += 1
				if completed == "p1_loop" and app.state.get("tether_events", []).is_empty(): print("CONTACT FAIL: demo has no actual pickup"); errors += 1
	app.return_to_selection()
	app.start_run()
	if app.running: print("FLOW FAIL: R/start without a new strategy must not launch"); errors += 1
	print("RUNTIME COURSES ", courses, " FAILURES ", errors)
	app.queue_free(); await process_frame
	quit(1 if errors else 0)
