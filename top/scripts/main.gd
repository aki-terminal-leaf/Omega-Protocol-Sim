# SPDX-License-Identifier: MIT
extends Control
const Encounter = preload("res://scripts/encounters.gd")
const Rules = preload("res://scripts/rules.gd")
const Arena = preload("res://scripts/arena.gd")
var catalog: Array = []
var strategies: Array = []
var filtered: Array = []
var encounter: Dictionary = {}
var actors: Array = []
var state: Dictionary = {}
var current: Dictionary = {}
var before_state: Dictionary = {}
var start_actors: Array = []
var journal: Array = []
var samples: Array = []
var all_errors: Array = []
var index = 0
var elapsed = 0.0
var sample_elapsed = 0.0
var running = false
var paused = false
var pending_advance = false
var demo = false
var player = 4
var wall_recorded = false
var arena: Node3D
var world: SubViewport
var view_container: SubViewportContainer
var phase_select: OptionButton
var strategy_select: OptionButton
var role_select: OptionButton
var slot_select: OptionButton
var speed_select: OptionButton
var scenario_list: ItemList
var checkpoint_select: OptionButton
var seed_edit: LineEdit
var hints: CheckBox
var stop_failure: CheckBox
var title_label: Label
var cue: Label
var note: Label
var status: Label
var player_info: Label
var party: RichTextLabel
var feedback: RichTextLabel
var progress: ProgressBar
var pause_button: Button
var focus_label: Label
var profile_note: Label
var custom_dialog: ConfirmationDialog
var custom_text: TextEdit
var save_dialog: FileDialog
var report_text = ""
var beat_passed = 0
var beat_failed = 0

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	strategies = JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	build_ui()
	load_settings()
	filter_catalog()
	prepare()
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": demo = true; hints.button_pressed = true; start_run()
		if arg.begins_with("--scenario="):
			var id = arg.trim_prefix("--scenario=")
			for i in filtered.size():
				if filtered[i].id == id: scenario_list.select(i); prepare()
		if arg.begins_with("--seed="): seed_edit.text = arg.trim_prefix("--seed="); prepare()
		if arg.begins_with("--player="): role_select.select(int(arg.trim_prefix("--player="))); prepare()
	# Demo starts after all command-line selection arguments have been processed.
	if demo: start_run()
	for capture_arg in OS.get_cmdline_user_args():
		if capture_arg.begins_with("--capture="):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_arg.trim_prefix("--capture="))

func label(text_value: String, size_value := 16, colour := Color("c6d4ea")) -> Label:
	var n = Label.new(); n.text = text_value; n.add_theme_font_size_override("font_size", size_value); n.add_theme_color_override("font_color", colour); return n
func button(text_value: String, callback: Callable) -> Button:
	var n = Button.new(); n.text = text_value; n.custom_minimum_size.y = 38; n.pressed.connect(callback); n.focus_mode = Control.FOCUS_NONE; return n
func option(items: Array) -> OptionButton:
	var n = OptionButton.new(); n.custom_minimum_size.y = 36
	for item in items: n.add_item(str(item))
	return n
func panel(colour: Color, padding := 14) -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color = colour; style.corner_radius_top_left = 12; style.corner_radius_top_right = 12; style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	style.content_margin_left = padding; style.content_margin_right = padding; style.content_margin_top = padding; style.content_margin_bottom = padding
	return style
func build_ui() -> void:
	var theme_value = Theme.new(); theme_value.default_font_size = 15
	var font = SystemFont.new(); font.font_names = PackedStringArray(["Noto Sans TC", "Microsoft JhengHei", "WenQuanYi Zen Hei", "Arial"]); theme_value.default_font = font
	if ResourceLoader.exists("res://fonts/ui.ttf"): theme_value.default_font = load("res://fonts/ui.ttf")
	theme_value.set_stylebox("normal", "Button", panel(Color("1d3047"), 8)); theme_value.set_stylebox("hover", "Button", panel(Color("294a60"), 8)); theme_value.set_stylebox("pressed", "Button", panel(Color("37605f"), 8))
	theme_value.set_stylebox("normal", "LineEdit", panel(Color("172338"), 7)); theme_value.set_stylebox("panel", "PopupMenu", panel(Color("18283c"), 10))
	self.theme = theme_value
	var background = ColorRect.new(); background.color = Color("0b1120"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root = VBoxContainer.new(); root.add_theme_constant_override("separation", 12); margin.add_child(root)
	var header = HBoxContainer.new(); root.add_child(header)
	header.add_child(label("Ω  OMEGA PROTOCOL", 26, Color("8ce3d1")))
	var subtitle = label("PRACTICE LAB  /  v0.1", 14, Color("8096b4")); subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(subtitle)
	header.add_child(button("攻略來源", show_research))
	var body = HBoxContainer.new(); body.add_theme_constant_override("separation", 12); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(body)
	var left_scroll = ScrollContainer.new(); left_scroll.custom_minimum_size.x = 290; left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(left_scroll)
	var left = VBoxContainer.new(); left.custom_minimum_size.x = 280; left.add_theme_constant_override("separation", 8); left_scroll.add_child(left)
	left.add_child(label("ENCOUNTER  /  選擇練習", 17, Color("8ce3d1")))
	phase_select = option(["全部階段", "P1 · Omega", "P2 · Omega M/F", "P3 · Final Omega", "P4 · Blue Screen", "P5 · Run: Dynamis", "P6 · Alpha Omega"]); left.add_child(phase_select); phase_select.item_selected.connect(func(_i): filter_catalog(); prepare())
	scenario_list = ItemList.new(); scenario_list.custom_minimum_size.y = 260; scenario_list.add_theme_font_size_override("font_size", 15); scenario_list.item_selected.connect(func(_i): prepare()); left.add_child(scenario_list)
	focus_label = label(""); focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(focus_label)
	left.add_child(label("STRATEGY  /  優先序與約定", 15, Color("8ce3d1")))
	strategy_select = OptionButton.new()
	for p in strategies: strategy_select.add_item(p.name)
	left.add_child(strategy_select); strategy_select.item_selected.connect(func(_i): prepare())
	profile_note = label("共用訓練幾何；不是各區所有戰術的完整復刻。", 12, Color("8598b1")); profile_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(profile_note)
	left.add_child(button("匯入／編輯自訂優先序", edit_custom))
	var row = HBoxContainer.new(); left.add_child(row)
	role_select = option(Encounter.ROLES); role_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL; role_select.select(4); row.add_child(role_select); role_select.item_selected.connect(func(_i): prepare())
	slot_select = option(["隨機點名", "指定分配 1", "指定分配 2", "指定分配 3", "指定分配 4", "指定分配 5", "指定分配 6", "指定分配 7", "指定分配 8"]); row.add_child(slot_select); slot_select.item_selected.connect(func(_i): prepare())
	left.add_child(label("SEED  /  可重現的隨機種子", 13))
	seed_edit = LineEdit.new(); seed_edit.text = str(randi_range(1, 999999)); seed_edit.placeholder_text = "1…2147483647"; left.add_child(seed_edit); seed_edit.text_submitted.connect(func(_v): prepare())
	var speed_row = HBoxContainer.new(); left.add_child(speed_row); speed_row.add_child(label("速度")); speed_select = option(["0.5×", "0.75×", "1×", "1.25×", "1.5×"]); speed_select.select(2); speed_row.add_child(speed_select)
	hints = CheckBox.new(); hints.text = "教學提示：顯示建議站位"; hints.button_pressed = true; left.add_child(hints)
	stop_failure = CheckBox.new(); stop_failure.text = "失誤後暫停檢討"; stop_failure.button_pressed = true; left.add_child(stop_failure)
	left.add_child(button("▶  開始練習", func(): demo = false; start_run()))
	var reroll = HBoxContainer.new(); left.add_child(reroll); reroll.add_child(button("同種子重來  R", func(): demo = false; start_run())); reroll.add_child(button("新點名", func(): seed_edit.text = str(randi_range(1, 999999)); demo = false; start_run()))
	left.add_child(label("分段起點", 13)); checkpoint_select = OptionButton.new(); left.add_child(checkpoint_select)
	left.add_child(button("從選取段落開始", func(): demo = false; start_run(checkpoint_select.selected)))
	var center = VBoxContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.add_theme_constant_override("separation", 8); body.add_child(center)
	title_label = label("", 21, Color("edf4ff")); center.add_child(title_label)
	cue = label("", 17, Color("ffd58f")); cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cue.custom_minimum_size.y = 42; center.add_child(cue)
	progress = ProgressBar.new(); progress.custom_minimum_size.y = 8; progress.show_percentage = false; center.add_child(progress)
	view_container = SubViewportContainer.new(); view_container.stretch = true; view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL; view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; view_container.custom_minimum_size = Vector2(350, 300); center.add_child(view_container)
	world = SubViewport.new(); world.size = Vector2i(800, 600); world.render_target_update_mode = SubViewport.UPDATE_ALWAYS; world.own_world_3d = true; view_container.add_child(world)
	arena = Arena.new(); world.add_child(arena)
	view_container.gui_input.connect(on_arena_input)
	player_info = label("", 16, Color("8ce3d1")); center.add_child(player_info)
	note = label("", 13); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size.y = 65; center.add_child(note)
	var transport = HBoxContainer.new(); center.add_child(transport)
	pause_button = button("暫停  Space", toggle_pause); transport.add_child(pause_button)
	transport.add_child(button("重練此段", retry_beat)); transport.add_child(button("示範", func(): demo = true; start_run()))
	transport.add_child(button("俯視", func(): arena.overhead = not arena.overhead; arena.update_camera()))
	transport.add_child(button("LB3  F", use_lb)); transport.add_child(button("換坦  V", provoke))
	var right = VBoxContainer.new(); right.custom_minimum_size.x = 270; right.add_theme_constant_override("separation", 10); body.add_child(right)
	right.add_child(label("PARTY  /  任務與 Dynamis", 17, Color("8ce3d1")))
	party = RichTextLabel.new(); party.bbcode_enabled = true; party.custom_minimum_size.y = 260; party.scroll_active = false; right.add_child(party)
	right.add_child(label("SNAPSHOT  /  判定紀錄", 15, Color("8ce3d1")))
	feedback = RichTextLabel.new(); feedback.bbcode_enabled = true; feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL; feedback.custom_minimum_size.y = 180; right.add_child(feedback)
	right.add_child(button("匯出練習紀錄 JSON", export_report))
	right.add_child(label("WASD / 方向鍵：移動\nShift：疾跑  ·  Q/E：轉身\n右鍵：面向滑鼠  ·  滾輪：縮放\nSpace：暫停  ·  R：相同點名重來", 13, Color("90a3bd")))
	status = label("訓練模型 · 放慢時間窗 · 非職業輸出模擬", 12, Color("7d91ad")); root.add_child(status)
	custom_dialog = ConfirmationDialog.new(); custom_dialog.title = "自訂戰術設定（JSON）"; custom_dialog.size = Vector2i(740, 500); add_child(custom_dialog)
	custom_text = TextEdit.new(); custom_text.custom_minimum_size = Vector2(700, 420); custom_dialog.add_child(custom_text); custom_dialog.confirmed.connect(apply_custom)
	save_dialog = FileDialog.new(); save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; save_dialog.access = FileDialog.ACCESS_FILESYSTEM; save_dialog.filters = PackedStringArray(["*.json ; Practice report"]); save_dialog.file_selected.connect(func(path): var f = FileAccess.open(path, FileAccess.WRITE); f.store_string(report_text); status.text = "已儲存：" + path); add_child(save_dialog)

func filter_catalog() -> void:
	filtered = []; scenario_list.clear()
	for item in catalog:
		if phase_select.selected == 0 or int(item.phase) == phase_select.selected:
			filtered.append(item); scenario_list.add_item("P%d  %s" % [int(item.phase), item.name.split(" / ")[0]])
	if not filtered.is_empty(): scenario_list.select(0)
func selected_item() -> Dictionary:
	var selected = scenario_list.get_selected_items()
	return filtered[selected[0] if selected.size() else 0]
func prepare() -> void:
	if not is_instance_valid(arena) or filtered.is_empty(): return
	running = false; paused = false; demo = false
	player = role_select.selected
	var item = selected_item()
	var seed_value = maxi(1, mini(2147483647, int(seed_edit.text)))
	seed_edit.text = str(seed_value)
	encounter = Encounter.new().build(item.id, seed_value, strategies[strategy_select.selected], player, slot_select.selected - 1)
	checkpoint_select.clear()
	for b in encounter.beats: checkpoint_select.add_item(b.title)
	title_label.text = "P%d  ·  %s" % [int(item.phase), item.name.split(" / ")[0]]
	focus_label.text = item.focus
	profile_note.tooltip_text = strategies[strategy_select.selected].scope
	profile_note.text = strategies[strategy_select.selected].get("short_scope", "共用訓練幾何；不是各區所有戰術的完整復刻。")
	index = 0; state = new_state(); journal = []; samples = []; all_errors = []; beat_passed = 0; beat_failed = 0
	begin_beat(true)
	cue.text = "準備完成 · %s · %d 個訓練判定" % [Encounter.ROLES[player], encounter.beats.size()]
	feedback.text = "[color=#90a3bd]開始後控制黃色標示角色。\n關閉提示可練習獨立判斷。[/color]"
	save_settings()
func new_state() -> Dictionary: return {"dynamis": encounter.initial_dynamis.duplicate(), "spent": [], "lb": "", "lb_actor": -1, "aggro": 0}
func oracle_state_before(target: int) -> Dictionary:
	var result = new_state()
	for k in target:
		var b: Dictionary = encounter.beats[k]
		var simulated = oracle_actors(b)
		for check in b.checks:
			if check.kind == "lb": result.lb = check.type; result.lb_actor = check.eligible[0]
			if check.kind == "aggro": result.aggro = check.actor
		Rules.evaluate(b, simulated, result)
	return result
func oracle_actors(b: Dictionary) -> Array:
	var simulated: Array = []
	for i in 8:
		var p: Vector2 = b.positions[i]
		if b.has("knockback"): p += p.normalized() * float(b.knockback)
		simulated.append({"role": Encounter.ROLES[i], "pos": p, "face": b.facing.get(i, 0)})
	return simulated
func start_run(checkpoint := 0) -> void:
	var demonstrate = demo
	prepare(); demo = demonstrate
	index = clampi(checkpoint, 0, encounter.beats.size() - 1)
	state = oracle_state_before(index)
	journal = []; samples = []; all_errors = []; beat_passed = 0; beat_failed = 0
	running = true; paused = false; pending_advance = false
	feedback.text = "[color=#8ce3d1]%s · seed %s[/color]\n" % ["示範模式（不計入成績）" if demo else "練習開始", seed_edit.text]
	begin_beat(true)
func begin_beat(reset_positions := false) -> void:
	current = encounter.beats[index].duplicate(true)
	before_state = state.duplicate(true)
	elapsed = 0; wall_recorded = false; pending_advance = false
	state.lb = ""; state.lb_actor = -1
	if reset_positions or actors.size() != 8:
		actors = []
		var initial: Dictionary = encounter.beats[maxi(0, index - 1)] if index > 0 else current
		for i in 8:
			var p: Vector2 = initial.positions[i]
			if index > 0 and initial.has("knockback"): p += p.normalized() * float(initial.knockback)
			actors.append({"role": Encounter.ROLES[i], "pos": p, "face": 0.0})
	if current.has("rotation_sources"):
		for j in current.rotation_sources.size():
			var source: Dictionary = current.rotation_sources[j]
			var axis: Vector2 = Rules.v(actors[int(source.target)].pos) - Rules.v(source.pos)
			current.shapes[j].angle = rad_to_deg(atan2(axis.x, -axis.y)) + float(source.turn)
	start_actors = actors.duplicate(true)
	cue.text = current.title
	note.text = current.note
	checkpoint_select.select(index)
	update_hud()
func toggle_pause() -> void:
	if not running: return
	paused = not paused; pause_button.text = "繼續  Space" if paused else "暫停  Space"
func retry_beat() -> void:
	if encounter.is_empty(): return
	state = before_state.duplicate(true); actors = start_actors.duplicate(true)
	running = true; paused = false; elapsed = 0; pending_advance = false; wall_recorded = false
	status.text = "重練：" + current.title
func _process(delta: float) -> void:
	if current.is_empty(): return
	var speed: float = [0.5, 0.75, 1.0, 1.25, 1.5][speed_select.selected]
	if running and not paused:
		if pending_advance:
			advance_beat()
		else:
			var dt = delta * speed
			elapsed += dt
			for i in 8:
				if i == player and not demo: continue
				actors[i].pos = Rules.v(actors[i].pos).move_toward(current.positions[i], dt * 11.0)
				actors[i].face = current.facing.get(i, 0.0)
			move_player(dt)
			if Rules.v(actors[player].pos).length() >= 20 and not wall_recorded:
				wall_recorded = true
				log_feedback("Death wall: " + Encounter.ROLES[player], false)
			for check in current.checks:
				if check.kind == "lb" and (demo or player not in check.eligible) and elapsed > float(current.duration) * 0.45:
					state.lb = check.type; state.lb_actor = int(check.eligible[0])
				if check.kind == "aggro" and (demo or player != int(check.actor)): state.aggro = int(check.actor)
			sample_elapsed += dt
			if sample_elapsed >= 0.2:
				sample_elapsed = 0
				samples.append({"beat": index, "time": snappedf(elapsed, 0.01), "player_pos": [actors[player].pos.x, actors[player].pos.y], "face": actors[player].face})
			if elapsed >= float(current.duration): resolve_beat()
	arena.update_state(actors, current, player, hints.button_pressed or (paused and pending_advance))
	update_hud()
func move_player(dt: float) -> void:
	if demo: return
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
	var movement = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): movement.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement.x += 1
	var speed = 8.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 6.0
	actors[player].pos += movement.normalized() * speed * dt
	if movement.length() > 0: actors[player].face = rad_to_deg(atan2(movement.x, -movement.y))
	if Input.is_physical_key_pressed(KEY_Q): actors[player].face -= 150 * dt
	if Input.is_physical_key_pressed(KEY_E): actors[player].face += 150 * dt
func on_arena_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: arena.zoom(-2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: arena.zoom(2)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and actors.size() == 8:
			var point = arena.screen_to_world(event.position)
			var axis = point - Rules.v(actors[player].pos)
			actors[player].face = rad_to_deg(atan2(axis.x, -axis.y))
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_SPACE: toggle_pause()
		KEY_R: demo = false; start_run()
		KEY_F: use_lb()
		KEY_V: provoke()
func use_lb() -> void:
	if not running or paused: return
	state.lb = "tank" if player < 2 else ("healer" if player < 4 else ("melee" if player < 6 else ("ranged" if player == 6 else "caster")))
	state.lb_actor = player
	status.text = "LB3：%s (%s)" % [Encounter.ROLES[player], state.lb]
func provoke() -> void:
	if player < 2 and running and not paused: state.aggro = player; status.text = "Provoke：" + Encounter.ROLES[player]
func resolve_beat() -> void:
	if current.has("knockback"):
		for actor in actors: actor.pos += Rules.v(actor.pos).normalized() * float(current.knockback)
	var errors = Rules.evaluate(current, actors, state)
	if wall_recorded and not ("Death wall (earlier during movement)" in errors): errors.append("Death wall (earlier during movement)")
	journal.append({"beat": index, "title": current.title, "seed": encounter.seed, "failures": errors, "dynamis": state.dynamis.duplicate(), "mode": "demo" if demo else "practice"})
	if errors.is_empty(): beat_passed += 1; log_feedback("✓ " + current.title, true)
	else:
		beat_failed += 1; all_errors.append_array(errors)
		for error in errors: log_feedback(error, false)
		if stop_failure.button_pressed:
			paused = true; pause_button.text = "繼續  Space"
	pending_advance = true
	write_report()
func advance_beat() -> void:
	pending_advance = false
	if index + 1 >= encounter.beats.size():
		running = false
		cue.text = "示範結束" if demo else ("練習通過" if all_errors.is_empty() else "練習完成 · 請檢討失誤")
		status.text = "%d 通過 / %d 失誤段落 · seed %s" % [beat_passed, beat_failed, seed_edit.text]
		write_report()
		return
	index += 1; begin_beat()
func log_feedback(text_value: String, good: bool) -> void:
	feedback.append_text("[color=%s]%s[/color]\n" % ["#8ce3d1" if good else "#ff9a9a", text_value.replace("[", "(").replace("]", ")")])
	feedback.scroll_to_line(feedback.get_line_count())
func update_hud() -> void:
	if actors.size() != 8: return
	progress.value = clampf(elapsed / float(current.get("duration", 1)) * 100, 0, 100)
	player_info.text = "%s  ·  %s  ·  Dynamis %d  ·  %.1fs" % [Encounter.ROLES[player], current.labels[player], int(state.dynamis[player]), maxf(0, float(current.duration) - elapsed)]
	var text_value = ""
	for i in 8:
		text_value += "[color=%s]%s %s[/color]  %s\n[color=#889bb5]%s[/color]\n" % ["#fff0a7" if i == player else "#d2dded", "▶" if i == player else "·", Encounter.ROLES[i], "●".repeat(int(state.dynamis[i])) + "○".repeat(3 - int(state.dynamis[i])), current.labels[i]]
	party.text = text_value
func report() -> Dictionary:
	return {"format": "top-practice-report/1", "version": "0.1.0", "scenario": encounter.get("id", ""), "seed": encounter.get("seed", 0), "strategy": encounter.get("profile", ""), "role": Encounter.ROLES[player], "mode": "demo" if demo else "practice", "hints": hints.button_pressed, "snapshots": journal, "samples": samples, "failures": all_errors, "fidelity": "schematic geometry / slowed training windows"}
func write_report() -> void:
	report_text = JSON.stringify(report(), "  ")
	var file = FileAccess.open("user://last_run.json", FileAccess.WRITE)
	if file: file.store_string(report_text)
func export_report() -> void:
	write_report()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(report_text.to_utf8_buffer(), "top-practice-%s.json" % seed_edit.text, "application/json")
	else:
		save_dialog.current_file = "top-practice-%s.json" % seed_edit.text; save_dialog.popup_centered(Vector2i(850, 550))
func show_research() -> void:
	var dialog = AcceptDialog.new(); dialog.title = "攻略與訓練精確度"; dialog.size = Vector2i(850, 650); add_child(dialog)
	var text_value = RichTextLabel.new(); text_value.custom_minimum_size = Vector2(810, 580); text_value.bbcode_enabled = true
	text_value.text = "[b]已核對的戰術約定[/b]\nNA Aether: TMR, BPOG/GPOB, north flex\nEU LPDU: MTRH, BPOG full cross\nJP/Elemental: HTDH, 1234/4231, south flex\nKR: 09STOP 公開 workbook 已核對 P1/P3 優先序與 Omega 選人；不是完整韓服戰術。\nCN: 莫古力公開宏已核對全程優先序；完整站位／其他打法仍需核對。\nTW/其他 DC: 不能用語言推斷統一戰術；可匯入自訂優先序。\n\n[b]這版的範圍[/b]\n22 項示意型走位／判斷練習，不是原戰鬥逐幀重現。\nP5 近遠跳躍依真實距離計算，連續課程追蹤 Dynamis。\n部分複合機制拆成檢查點，塔位、AoE 大小及時間窗是訓練參數；完整限制見 docs/research/FIDELITY.md。\n無 HP、傷害、完整職業減傷、輸出與網路延遲模擬。\n\n[url=https://ffxiv.tuufless.com/elemental/top/]JP / Elemental guide[/url]\n[url=https://www.thepfstrat.com/u/top]NA / Aether PF[/url]\n[url=https://github.com/cliaux/lpdu.github.io/blob/main/top/top_discord_strats.md]EU / LPDU[/url]\n[url=https://www.inven.co.kr/board/ff14/4338/7027]KR / Rominny[/url]\n[url=https://docs.qq.com/doc/DSlBpR0JqSElVelhH]CN / 莫古力宏[/url]\n[url=https://github.com/aki-terminal-leaf/Omega-Protocol-Sim]Repository / 完整研究與限制[/url]"
	text_value.meta_clicked.connect(func(url): OS.shell_open(str(url))); dialog.add_child(text_value); dialog.popup_centered(); dialog.confirmed.connect(dialog.queue_free)
func edit_custom() -> void:
	custom_text.text = JSON.stringify(strategies[strategy_select.selected], "  "); custom_dialog.popup_centered()
func apply_custom() -> void:
	var p = JSON.parse_string(custom_text.text)
	if not p is Dictionary or not p.has("priority") or not p.has("shapes") or not p.has("stack_flex"):
		status.text = "設定無效：需要 priority、shapes、stack_flex"; return
	if not p.priority is Array or not p.shapes is Array:
		status.text = "設定無效：priority 和 shapes 必須是陣列"; return
	if not Rules.same_members(p.priority, Encounter.ROLES) or p.priority.size() != 8 or p.shapes.size() != 4 or not p.stack_flex in ["north", "south"]:
		status.text = "設定無效：角色必須各出現一次，shapes 必須四種，flex 必須 north/south"; return
	for shape_name in p.shapes:
		if not shape_name is String or p.shapes.count(shape_name) != 1:
			status.text = "設定無效：四種圖形必須是不同字串"; return
	if p.has("p6_stack_angle") and not (p.p6_stack_angle is int or p.p6_stack_angle is float):
		status.text = "設定無效：p6_stack_angle 必須是數字"; return
	if p.has("p3_priority") and (not p.p3_priority is Array or not Rules.same_members(p.p3_priority, Encounter.ROLES)):
		status.text = "設定無效：p3_priority 必須包含八個不重複角色"; return
	if p.has("loop_start_angle") and not (p.loop_start_angle is int or p.loop_start_angle is float):
		status.text = "設定無效：loop_start_angle 必須是數字"; return
	p.id = "custom"; p.name = "Custom · 自訂"; p.short_scope = "自訂約定 · 未經外部核對"; p.scope = "User-supplied convention; not externally verified"
	if strategies[-1].id == "custom": strategies[-1] = p
	else: strategies.append(p); strategy_select.add_item(p.name)
	strategy_select.select(strategies.size() - 1); prepare()
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "role", player); config.set_value("settings", "strategy", strategy_select.selected); config.set_value("settings", "hints", hints.button_pressed); config.set_value("settings", "seed", seed_edit.text)
	if strategies[-1].id == "custom": config.set_value("settings", "custom", strategies[-1])
	config.save("user://settings.cfg")
func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return
	if config.has_section_key("settings", "custom"):
		var p: Dictionary = config.get_value("settings", "custom"); strategies.append(p); strategy_select.add_item(p.name)
	role_select.select(clampi(int(config.get_value("settings", "role", 4)), 0, 7)); strategy_select.select(clampi(int(config.get_value("settings", "strategy", 0)), 0, strategies.size() - 1)); hints.button_pressed = bool(config.get_value("settings", "hints", true)); seed_edit.text = str(config.get_value("settings", "seed", "1"))
