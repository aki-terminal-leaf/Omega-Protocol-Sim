# SPDX-License-Identifier: MIT
extends SceneTree
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("PREFERENCES FAIL: ", message)
func settle() -> void:
	for i in 4: await process_frame
func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event); await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture-ui" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/top-preferences-" + name + ".png")
func instructions_fit(box: Control) -> bool:
	var text_label: Label = box.get_child(0).get_child(0)
	return text_label.get_line_count() == text_label.get_visible_line_count()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900); root.gui_embed_subwindows = true
	var app = Main.instantiate(); root.add_child(app); await settle(); app.set_process(false)
	check(app.fresh_seed.button_pressed and not app.seed_edit.editable, "fresh seeds default on for new or migrated settings")
	check(app.setup_controls.is_visible_in_tree(), "setup instructions visible without opening tools")
	check(instructions_fit(app.setup_controls), "all setup instructions fit in fixed footer")
	var expected: Rect2 = app.view_container.get_global_rect()
	for language in 3:
		app.language_select.select(language); app.language_select.item_selected.emit(language); await settle()
		check(app.scenario_list.item_count == 20, "locale keeps all twenty mechanics")
		for i in app.catalog.size():
			check(app.scenario_list.get_item_text(i) == "P%d  %s" % [int(app.catalog[i].phase), app.catalog[i].names[app.NAME_LOCALES[language]]], "localized catalogue: " + app.catalog[i].id)
		check(app.view_container.get_global_rect().is_equal_approx(expected), "locale does not resize preview")
	app.choose_mechanic(0); app.strategy_select.select(1); app.choose_strategy(1); await settle()
	app.seed_edit.text = "1"; app.prepare()
	var last_seed := 1
	for i in 3:
		app.start_button.pressed.emit(); await settle()
		check(app.encounter.seed != last_seed and app.encounter.seed >= 1 and app.encounter.seed <= 2147483647, "each primary start generates a new valid seed")
		last_seed = app.encounter.seed
		check(app.practice_view and app.running, "primary start enters practice")
		app.open_practice_settings(); await settle()
	app.return_practice_view(); await settle()
	var previous_encounter: Dictionary = app.encounter.duplicate(true)
	var previous_actors: Array = app.start_actors.duplicate(true)
	await key(KEY_R)
	check(app.encounter == previous_encounter and app.encounter.seed == last_seed, "actual R keeps identical generated encounter")
	check(app.start_actors == previous_actors, "R resets original same-seed spawn")
	check(app.hud_controls.is_visible_in_tree() and not app.training_overlay, "practice footer visible with tools hidden")
	check(instructions_fit(app.hud_controls), "practice instructions are not clipped")
	var state: Dictionary = app.state.duplicate(true)
	app.open_practice_settings(); await settle()
	var selected_strategy: int = app.strategy_select.selected
	var selected_id: String = app.selected_item().id
	for language in 3:
		app.language_select.select(language); app.language_select.item_selected.emit(language); await settle()
		check(app.configured and app.paused and app.strategy_select.selected == selected_strategy and app.selected_item().id == selected_id, "locale preserves selected strategy and paused run")
		check(app.encounter == previous_encounter and app.state == state and app.encounter.seed == last_seed, "locale is display-only, no reroll/reset")
		check(app.title_label.text.contains(app.catalog[0].names[app.NAME_LOCALES[language]]) and app.hud_title.text == app.title_label.text, "locale refreshes preview and HUD titles")
		check(app.view_container.get_global_rect().is_equal_approx(expected), "selected locale keeps exact preview bounds")
		await capture("locale-" + str(language))
	app.fresh_seed.button_pressed = false; app.seed_edit.text = "42"; app.prepare(); app.start_button.pressed.emit(); await settle()
	check(app.encounter.seed == 42 and app.seed_edit.editable, "fixed-seed opt-out uses explicit seed")
	app.open_practice_settings(); app.start_button.pressed.emit(); await settle()
	check(app.encounter.seed == 42, "fixed-seed start remains deterministic")
	app.training_overlay = true; app.sync_practice_hud(); await settle()
	check(app.hud_bottom_panel.get_global_rect().end.y <= app.hud_controls.get_global_rect().position.y, "hotbar does not cover bottom instructions")
	await capture("practice")
	app.open_practice_settings(); app.show_setup_tools(); await settle(); await capture("settings"); app.tools_dialog.hide()
	var config := ConfigFile.new(); config.load("user://settings.cfg"); config.set_value("unrelated", "keep", 73); config.save("user://settings.cfg")
	app.language_select.select(2); app.language_select.item_selected.emit(2); app.save_settings()
	app.mechanism_language = "en"; app.fresh_seed.set_pressed_no_signal(true); app.load_settings()
	check(app.mechanism_language == "ja" and app.language_select.selected == 2 and not app.fresh_seed.button_pressed and app.seed_edit.editable, "locale and fixed-seed preference survive settings reload")
	config.load("user://settings.cfg"); check(config.get_value("unrelated", "keep") == 73, "saving new preferences preserves unrelated settings")
	config.set_value("settings", "mechanism_language", "unsupported"); config.erase_section_key("settings", "fresh_seed"); config.save("user://settings.cfg"); app.load_settings()
	check(app.mechanism_language == "zh_TW" and app.fresh_seed.button_pressed, "unknown locale falls back and old configs default to fresh seeds")
	app.save_settings(); app.queue_free(); await process_frame
	print("PRACTICE PREFERENCES checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
