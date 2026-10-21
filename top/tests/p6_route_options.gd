# SPDX-License-Identifier: MIT
extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Rules = preload("res://scripts/rules.gd")
var assertions := 0
var failures := 0
var cases := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		print("P6 OPTION FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = Main.instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var profiles: Array = ["elemental", "aether", "lpdu", "cn_moogle", "kr_09stop"]
	for id in ["p6_arrow_dive", "p6_exa_wave", "p6_arrow_wave", "p6_exa_dive"]:
		var index := -1
		for i in app.filtered.size():
			if app.filtered[i].id == id: index = i
		check(index >= 0, "mechanic exists: " + id)
		if index < 0: continue
		app.choose_mechanic(index)
		check(app.strategy_select.item_count == 6, "placeholder plus five supported profiles: " + id)
		var seen: Array = []
		for option in range(1, app.strategy_select.item_count):
			app.choose_mechanic(index)
			app.seed_edit.text = "17391"
			app.strategy_select.select(option)
			var method: Dictionary = app.strategy_select.get_item_metadata(option)
			app.choose_strategy(option)
			var profile: String = method.profile
			seen.append(profile)
			cases += 1
			check(app.configured and app.active_profile.id == profile and app.encounter.profile == profile, "actual Main resolves selected profile, not default: " + id + "/" + profile)
			var first: Dictionary = app.encounter.beats[0]
			var last: Dictionary = app.encounter.beats[-1]
			check(first.p6_route.id == profile and not first.p6_route.complete, "source limitations survive into actual encounter")
			check(not first.p6_pattern.guide_route_complete, "partial choices never claim complete original routes")
			if id.ends_with("wave"):
				var end: Vector2 = Rules.v(last.positions[2])
				check(end.x > 0 and absf(end.y) < 0.001 if profile == "elemental" else end.y > 0 and absf(end.x) < 0.001, "source-supported E versus S final stack: " + profile)
			if id == "p6_arrow_dive":
				var party: Vector2 = Rules.v(last.positions[2])
				check(party.y > 0 and (party.x > 0 if profile == "lpdu" else party.x < 0), "LPDU southeast versus other southwest party convention")
			if id.begins_with("p6_exa") and profile in ["lpdu", "cn_moogle"]:
				check(first.p6_route.exit_offset == null and str(first.p6_pattern.offset_source).contains("unknown"), "unknown original escape offset remains unknown, not promoted by menu")
			if id == "p6_arrow_wave" and profile == "lpdu":
				var healer: Vector2 = Rules.v(first.positions[2])
				check(healer.x < 0 and healer.y > 0, "LPDU paired-quadrant route is active")
		seen.sort()
		var wanted := profiles.duplicate()
		wanted.sort()
		check(seen == wanted, "no duplicate aliases omit a requested profile")
	check(cases == 20, "all twenty actual profile/combined-course selections checked")
	app.queue_free()
	await process_frame
	print("P6 ROUTE OPTIONS cases=", cases, " assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)
