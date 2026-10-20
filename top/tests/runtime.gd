extends SceneTree
const Main = preload("res://scenes/main.tscn")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = Main.instantiate(); root.add_child(app)
	await process_frame
	var errors = 0
	for profile_index in app.strategies.size():
		app.strategy_select.select(profile_index)
		for i in app.filtered.size():
			app.scenario_list.select(i); app.seed_edit.text = "17391"; app.demo = true; app.start_run(); app.stop_failure.button_pressed = false
			var ticks = 0
			while app.running and ticks < 10000:
				app._process(0.1); ticks += 1
			if not app.all_errors.is_empty() or app.running:
				print("RUNTIME FAIL ", app.encounter.id," / ",profile_index, ": ",app.all_errors); errors += 1
	print("RUNTIME COURSES ", app.strategies.size() * app.filtered.size(), " FAILURES ", errors)
	app.queue_free(); await process_frame
	quit(1 if errors else 0)
