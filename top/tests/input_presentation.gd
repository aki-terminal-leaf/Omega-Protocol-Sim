# SPDX-License-Identifier: MIT
extends SceneTree
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("INPUT PRESENTATION FAIL: ", message)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code; event.keycode = code; event.pressed = pressed
		Input.parse_input_event(event)
	await process_frame

func mouse(position: Vector2, pressed: bool, button_index := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position; event.global_position = position
	event.button_index = button_index; event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func click(control: Control) -> void:
	# Container layout is deferred after visibility changes; click the painted
	# position, not the previous hidden-row rectangle before the next frame.
	await process_frame
	var point := control.get_global_rect().get_center()
	await mouse(point, true); await mouse(point, false)
	await process_frame

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	root.gui_embed_subwindows = true
	var app = Main.instantiate(); root.add_child(app)
	await process_frame; app.set_process(false)
	# Setup through existing UI control callbacks; never patch actors/runtime state.
	app.role_select.select(6)
	for i in app.filtered.size():
		if app.filtered[i].id == "p6_meteors": app.choose_mechanic(i); break
	app.strategy_select.select(1); app.choose_strategy(1)
	app.seed_edit.text = "17391"
	app.show_setup_tools(); await process_frame
	app.seed_edit.grab_focus()
	check(app.seed_edit.has_focus(), "seed editor is visible and actually focused")
	await key(KEY_P)
	check(not app.running, "typing P in setup does not launch a course")
	app.tools_dialog.hide()
	app.start_run()
	for i in 3: await process_frame
	check(app.practice_view and root.gui_get_focus_owner() == null, "entering player view releases seed editor focus")
	var actors_before := JSON.stringify(app.actors)
	var state_before := JSON.stringify(app.state)
	await key(KEY_P)
	check(app.paused, "viewport-routed P pauses")
	await key(KEY_TAB)
	check(app.training_overlay, "Tab explicitly reveals tools")
	await click(app.hud_pause)
	check(not app.paused, "actual HUD click resumes")
	check(app.camera_buttons == 0, "HUD button does not start world capture")
	await key(KEY_P)
	check(app.paused, "HUD button leaves P available")
	await click(app.hud_lb_target)
	var popup: PopupMenu = app.hud_lb_target.get_popup()
	check(popup.visible, "actual target click opens popup")
	check(app.camera_buttons == 0, "target popup does not start world capture")
	# The initial live target is alpha_omega. Select it through PopupMenu GUI input.
	var target_index := -1
	for i in app.hud_lb_target.item_count:
		if app.hud_lb_target.get_item_metadata(i) == "alpha_omega": target_index = i
	check(target_index >= 0, "initial real target exists")
	if target_index >= 0:
		var point := Vector2(popup.size.x / 2.0, popup.size.y - 12.0)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = Vector2(popup.position) + point; event.global_position = event.position
			event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
		check(not popup.visible, "GUI target selection closes popup")
		check(app.lb_target.get_item_metadata(app.lb_target.selected) == "alpha_omega", "GUI target is bound to real request selector")
	await mouse(Vector2(800, 400), true)
	check(app.camera_buttons == 1, "world press reaches camera routing")
	await mouse(app.hud_pause.get_global_rect().get_center(), false)
	check(app.camera_buttons == 0, "release over HUD clears world drag")
	await mouse(Vector2(800, 400), true)
	await key(KEY_ESCAPE)
	check(app.camera_buttons == 0, "Escape cancels held camera gesture")
	await mouse(Vector2(800, 400), false)
	check(not app.practice_view and app.paused, "Escape opens paused settings")
	app.return_practice_view()
	await key(KEY_P)
	check(not app.paused, "P remains available after popup and released gesture")
	check(JSON.stringify(app.actors) == actors_before, "GUI routing leaves all actor data unchanged")
	check(JSON.stringify(app.state) == state_before, "GUI routing leaves all runtime state unchanged")
	app.queue_free(); await process_frame
	print("INPUT PRESENTATION checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
