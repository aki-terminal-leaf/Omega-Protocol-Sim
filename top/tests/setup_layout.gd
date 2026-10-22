# SPDX-License-Identifier: MIT
extends SceneTree
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var methods := 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1; print("SETUP LAYOUT FAIL: ", title)
func settle() -> void:
	for i in 4: await process_frame
func click(control: Control) -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		event.position = control.get_global_rect().get_center(); event.global_position = event.position
		Input.parse_input_event(event); await process_frame
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if not "--capture-ui" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/top-ui-" + name + ".png")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900); root.gui_embed_subwindows = true
	var app = Main.instantiate(); root.add_child(app); await settle(); app.set_process(false)
	check(not app.configured and app.start_button.disabled, "explicit strategy required at boot")
	check(not app.tools_dialog.visible and not app.seed_edit.is_visible_in_tree() and not app.feedback.is_visible_in_tree(), "advanced controls hidden by default")
	await capture("selection")
	var rendered_smoke := "--render-smoke" in OS.get_cmdline_user_args()
	var resolutions := [Vector2i(1440, 900)] if rendered_smoke else [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]
	for resolution in resolutions:
		root.size = resolution; app.phase_select.select(0); app.filter_catalog(); await settle()
		var expected: Rect2 = app.view_container.get_global_rect()
		print("LAYOUT ",resolution," app=",app.size," preview=",expected," column=",app.preview_column.get_global_rect())
		check(expected.size.x > 450 and expected.size.y >= 300, "usable preview at " + str(resolution))
		for phase in ([0, 5, 6] if rendered_smoke else range(7)):
			app.phase_select.select(phase); app.filter_catalog(); await settle()
			check(app.view_container.get_global_rect().is_equal_approx(expected), "phase filter preserves preview bounds")
		app.phase_select.select(0); app.filter_catalog()
		# Cover all 20 mechanisms, all methods at 1440; other sizes cover long P5 and conditional P6.
		for item_index in app.filtered.size():
			if rendered_smoke and not item_index in [0, 19]: continue
			if resolution != Vector2i(1440, 900) and not item_index in [0, 10, 13, 18, 19]: continue
			app.arena.camera_yaw = 0.35; app.arena.camera_size = 8.5
			app.choose_mechanic(item_index); await settle()
			check(app.view_container.get_global_rect().is_equal_approx(expected), "mechanic selection preserves preview")
			check(app.arena.camera_yaw == 0.35 and app.arena.camera_size == 8.5, "mechanic selection preserves user camera")
			for method_index in (range(1, mini(2, app.strategy_select.item_count)) if rendered_smoke else range(1, app.strategy_select.item_count)):
				app.strategy_select.select(method_index); app.choose_strategy(method_index); await settle(); methods += 1
				check(app.configured and not app.start_button.disabled, "strategy enables start")
				check(app.view_container.get_global_rect().is_equal_approx(expected), "strategy/P6 settings cannot resize preview")
			check(Rect2(Vector2.ZERO, app.size).encloses(app.start_button.get_global_rect()), "start remains on-screen")
	root.size = Vector2i(1440, 900); app.phase_select.select(0); app.filter_catalog(); app.choose_mechanic(0); app.strategy_select.select(1); app.choose_strategy(1); await settle()
	var baseline: Rect2 = app.view_container.get_global_rect()
	var original_profile: String = app.profile_note.text
	app.profile_note.text = "長攻略說明與來源。".repeat(100)
	app.title_label.text = "非常長的機制標題".repeat(30); app.cue.text = "準備與判定訊息".repeat(30)
	app.strategy_select.set_item_text(1, "非常長的打法名稱".repeat(30)); await settle()
	check(app.view_container.get_global_rect().is_equal_approx(baseline), "extreme text cannot change preview bounds")
	app.choose_mechanic(0); app.strategy_select.select(1); app.choose_strategy(1); app.reset_camera(); await settle()
	app.profile_note.text = original_profile
	print("UI_TARGETS phase=",app.phase_select.get_global_rect()," list=",app.scenario_list.get_global_rect()," strategy=",app.strategy_select.get_global_rect()," start=",app.start_button.get_global_rect()," tools=",app.tools_button.get_global_rect())
	await capture("ready")
	await click(app.tools_button)
	check(app.tools_dialog.visible and app.seed_edit.is_visible_in_tree(), "actual tools click opens settings")
	check(app.view_container.get_global_rect().is_equal_approx(baseline), "modal settings do not reflow preview")
	await capture("tools"); app.tools_dialog.hide(); await settle()
	await click(app.start_button)
	check(app.practice_view and app.running and not app.setup_shell.visible, "actual primary button enters practice")
	check(not app.hud_hotbar.is_visible_in_tree(), "practice remains clean by default")
	app.training_overlay = true; app.sync_practice_hud(); await settle()
	for child in app.hud_hotbar.get_children():
		if child is Button and child.text == "JSON": print("UI_JSON ",child.get_global_rect())
	app.training_overlay = false; app.sync_practice_hud()
	app.open_practice_settings(); await settle()
	check(app.paused and app.resume_button.is_visible_in_tree(), "settings offer resume for paused course")
	print("RESTORE baseline=",baseline," actual=",app.view_container.get_global_rect())
	check(app.view_container.get_global_rect().is_equal_approx(baseline), "returning from fullscreen restores exact preview")
	await click(app.resume_button)
	check(app.practice_view and not app.paused, "resume click preserves paused ownership")
	app.return_to_selection(); await settle()
	check(app.start_button.disabled and not app.resume_button.visible, "selection reset clears start/resume state")
	app.queue_free(); await process_frame
	print("SETUP LAYOUT checks=", checks, " methods=", methods, " failures=", failures)
	quit(1 if failures else 0)
