# SPDX-License-Identifier: MIT
extends SceneTree
const Main = preload("res://scenes/main.tscn")
const LB = preload("res://scripts/p6_lb.gd")
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1; print("PRESENTATION FAIL: ",title)
func select(app, id: String, role: int) -> void:
	var found := -1
	for i in app.filtered.size():
		if app.filtered[i].id == id: found = i
	check(found >= 0,"mechanic exists")
	app.role_select.select(role); app.choose_mechanic(found)
	app.seed_edit.text = "17391"; app.strategy_select.select(1); app.choose_strategy(1)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = Main.instantiate(); root.add_child(app)
	await process_frame; app.set_process(false)
	check(not app.practice_view and app.setup_shell.visible,"boot is setup, not an automatically started course")
	select(app,"p1_loop",4)
	app.start_run(); await process_frame; await process_frame
	check(app.practice_view and app.practice_root.visible and not app.setup_shell.visible,"start enters player view")
	check(app.view_container.get_parent() == app.practice_root,"same live viewport is used fullscreen")
	check(app.view_container.size.distance_to(app.size) < 2.0,"world uses entire window, not old center column")
	check(app.hud_party.is_visible_in_tree() and app.hud_party_rows.size() == 8,"eight-member status HUD stays in the game")
	check(not app.hud_title.is_visible_in_tree() and not app.hud_cue.is_visible_in_tree() and not app.hud_hotbar.is_visible_in_tree() and not app.hud_menu.is_visible_in_tree() and not app.hud_bottom_panel.visible,"ordinary practice has no training chrome")
	app.training_overlay = true; app.sync_practice_hud()
	check(app.hud_hotbar.is_visible_in_tree() and app.hud_menu.is_visible_in_tree(),"explicit tools overlay exposes training utilities")
	var actor_bytes := JSON.stringify(app.actors)
	var state_bytes := JSON.stringify(app.state)
	app.open_practice_settings()
	check(not app.practice_view and app.paused,"opening settings pauses active practice")
	check(app.view_container.get_parent() == app.view_home,"settings restore preview placement without recreating the world")
	check(JSON.stringify(app.actors) == actor_bytes and JSON.stringify(app.state) == state_bytes,"presentation switch does not alter actual actor/runtime state")
	app.return_practice_view()
	check(app.practice_view and not app.paused and not app.training_overlay,"return resumes only settings-owned pause")
	app.toggle_pause(); app.open_practice_settings(); app.return_practice_view()
	check(app.paused,"an already paused course is not unpaused by menu")
	app.return_to_selection()
	check(not app.practice_view and not app.configured and app.setup_shell.visible,"return requires explicit new mechanism/strategy")
	app.start_run(); check(not app.running,"start without strategy remains blocked")
	select(app,"p6_meteors",6); app.start_run()
	# Control binding fixture only: not a full meteor course/spawn-timing proof.
	LB.spawn_meteors(app.state); app.update_hud()
	check(app.hud_lb_row.visible and app.hud_lb_target.visible,"ranged target remains available in player HUD")
	var target := -1
	for i in app.hud_lb_target.item_count:
		if app.hud_lb_target.get_item_metadata(i) == "meteor_1": target = i
	check(target > 0,"actual named NPC is in HUD selector")
	app.hud_lb_target.select(target); app.hud_lb_target.item_selected.emit(target)
	check(app.lb_target.get_item_metadata(app.lb_target.selected) == "meteor_1","HUD selection feeds actual LB request input")
	app.use_lb()
	check(app.state.p6_lb.casts.size() == 1 and int(app.state.p6_lb.casts[0].actor) == 6,"HUD-selected NPC begins actual ranged LB")
	select(app,"p6_meteors",7); app.start_run(); app.update_hud()
	check(app.hud_ground_row.visible and not app.hud_lb_target.visible,"caster gets ground controls instead of NPC selector")
	app.hud_ground_x.value = 1.5; app.hud_ground_y.value = -2.0
	check(app.lb_ground_x.value == 1.5 and app.lb_ground_y.value == -2.0,"HUD ground values feed actual caster request")
	app.lb_ground_x.value = 3.0; app.sync_practice_hud()
	check(app.hud_ground_x.value == 3.0,"legacy/setting ground choice is mirrored back")
	app.use_lb(); check(app.state.p6_lb.casts.size() == 1 and int(app.state.p6_lb.casts[0].actor) == 7,"HUD caster target begins actual LB")
	check(app.hud_bottom_panel.offset_top == -82 and not app.hud_hotbar.visible and app.hud_bottom_panel.offset_bottom <= 0,"P6 controls reserve visible window space")
	var report: Dictionary = app.report()
	check(report.camera.practice_view and report.camera.viewport.size() == 2,"report retains presentation context")
	app.return_to_selection(); app.queue_free(); await process_frame
	print("PRESENTATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
