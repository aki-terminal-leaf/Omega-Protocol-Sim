# SPDX-License-Identifier: MIT
extends Control
const Encounter = preload("res://scripts/encounters.gd")
const Rules = preload("res://scripts/rules.gd")
const Arena = preload("res://scripts/arena.gd")
const Interactions = preload("res://scripts/interactions.gd")
var catalog: Array = []
var strategies: Array = []
var filtered: Array = []
var mechanic_methods: Dictionary = {}
var configured := false
var active_profile: Dictionary = {}
var launch_buttons: Array = []
var camera_buttons := 0
var camera_anchor := Vector2.ZERO
var checkpoint_assisted := false
var sprint_left := 0.0
var knockback_resist_left := 0.0
var dash_left := 0.0
var dash_direction := Vector2.ZERO
var follow_toggle: CheckBox
var encounter: Dictionary = {}
var actors: Array = []
var state: Dictionary = {}
var current: Dictionary = {}
var before_state: Dictionary = {}
var start_actors: Array = []
var start_controls: Dictionary = {}
var retry_history: Array = []
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
	mechanic_methods = JSON.parse_string(FileAccess.get_file_as_string("res://data/mechanic_strategies.json"))
	build_ui()
	load_settings()
	filter_catalog()
	var cli_scenario := ""
	var cli_demo := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": cli_demo = true
		if arg.begins_with("--scenario="): cli_scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--seed="): seed_edit.text = arg.trim_prefix("--seed=")
		if arg.begins_with("--player="): role_select.select(clampi(int(arg.trim_prefix("--player=")), 0, 7))
	if cli_demo and cli_scenario.is_empty(): cli_scenario = "p1_loop"
	for i in filtered.size():
		if filtered[i].id == cli_scenario:
			choose_mechanic(i); strategy_select.select(1); choose_strategy(1)
	if cli_demo and configured: demo = true; start_run()
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
	var n = OptionButton.new(); n.custom_minimum_size.y = 36; n.focus_mode = Control.FOCUS_NONE
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
	var subtitle = label("PRACTICE LAB  /  v0.3 preview", 14, Color("8096b4")); subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(subtitle)
	header.add_child(button("攻略來源", show_research))
	var body = HBoxContainer.new(); body.add_theme_constant_override("separation", 12); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(body)
	var left_scroll = ScrollContainer.new(); left_scroll.custom_minimum_size.x = 290; left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(left_scroll)
	var left = VBoxContainer.new(); left.custom_minimum_size.x = 280; left.add_theme_constant_override("separation", 8); left_scroll.add_child(left)
	left.add_child(label("①  選擇機制", 17, Color("8ce3d1")))
	phase_select = option(["全部階段", "P1 · Omega", "P2 · Omega M/F", "P3 · Final Omega", "P4 · Blue Screen", "P5 · Run: Dynamis", "P6 · Alpha Omega"]); left.add_child(phase_select); phase_select.item_selected.connect(func(_i): filter_catalog())
	scenario_list = ItemList.new(); scenario_list.custom_minimum_size.y = 260; scenario_list.add_theme_font_size_override("font_size", 15); scenario_list.item_selected.connect(choose_mechanic); left.add_child(scenario_list)
	focus_label = label(""); focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(focus_label)
	left.add_child(label("②  選擇此機制的攻略方式", 15, Color("8ce3d1")))
	strategy_select = option(["請先選擇機制"]); strategy_select.disabled = true
	left.add_child(strategy_select); strategy_select.item_selected.connect(choose_strategy)
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
	var start = button("▶  只練習選定機制", func(): demo = false; start_run()); left.add_child(start); launch_buttons.append(start)
	left.add_child(button("←  返回機制選擇", return_to_selection))
	var reroll = HBoxContainer.new(); left.add_child(reroll); var same = button("同種子重來  R", func(): demo = false; start_run()); reroll.add_child(same); launch_buttons.append(same)
	var fresh = button("新點名", func(): seed_edit.text = str(randi_range(1, 999999)); demo = false; start_run()); reroll.add_child(fresh); launch_buttons.append(fresh)
	left.add_child(label("分段起點", 13)); checkpoint_select = OptionButton.new(); left.add_child(checkpoint_select)
	var segment = button("從選取段落開始", func(): demo = false; start_run(checkpoint_select.selected)); left.add_child(segment); launch_buttons.append(segment)
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
	pause_button = button("暫停  P", toggle_pause); transport.add_child(pause_button)
	var retry = button("重練此段", retry_beat); transport.add_child(retry); launch_buttons.append(retry)
	var show = button("示範", func(): demo = true; start_run()); transport.add_child(show); launch_buttons.append(show)
	transport.add_child(button("俯視", func(): arena.overhead = not arena.overhead; arena.update_camera()))
	transport.add_child(button("重設鏡頭", reset_camera))
	follow_toggle = CheckBox.new(); follow_toggle.text = "跟隨"; follow_toggle.toggled.connect(func(value): if arena.has_method("set_follow"): arena.set_follow(value)); transport.add_child(follow_toggle)
	transport.add_child(button("LB3  F", use_lb)); transport.add_child(button("換坦  V", provoke))
	var actions = HBoxContainer.new(); center.add_child(actions)
	actions.add_child(button("1  疾跑", use_sprint)); actions.add_child(button("2  防擊退", use_arms)); actions.add_child(button("3  突進", use_dash)); actions.add_child(button("Space  跳躍", jump_player))
	var right = VBoxContainer.new(); right.custom_minimum_size.x = 270; right.add_theme_constant_override("separation", 10); body.add_child(right)
	right.add_child(label("PARTY  /  任務與 Dynamis", 17, Color("8ce3d1")))
	party = RichTextLabel.new(); party.bbcode_enabled = true; party.custom_minimum_size.y = 365; party.scroll_active = true; right.add_child(party)
	right.add_child(label("SNAPSHOT  /  判定紀錄", 15, Color("8ce3d1")))
	feedback = RichTextLabel.new(); feedback.bbcode_enabled = true; feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL; feedback.custom_minimum_size.y = 180; right.add_child(feedback)
	right.add_child(button("匯出練習紀錄 JSON", export_report))
	right.add_child(label("WASD / 方向鍵：移動\n1：疾跑  ·  2：防擊退  ·  3：突進\nSpace：跳躍  ·  Q/E：轉身\n拖曳左右鍵：旋轉鏡頭  ·  滾輪：縮放\n右鍵：同步朝向  ·  雙鍵：前進\nP：暫停  ·  R：相同點名重來", 13, Color("90a3bd")))
	status = label("訓練模型 · 放慢時間窗 · 非職業輸出模擬", 12, Color("7d91ad")); root.add_child(status)
	custom_dialog = ConfirmationDialog.new(); custom_dialog.title = "自訂戰術設定（JSON）"; custom_dialog.size = Vector2i(740, 500); add_child(custom_dialog)
	custom_text = TextEdit.new(); custom_text.custom_minimum_size = Vector2(700, 420); custom_dialog.add_child(custom_text); custom_dialog.confirmed.connect(apply_custom)
	save_dialog = FileDialog.new(); save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; save_dialog.access = FileDialog.ACCESS_FILESYSTEM; save_dialog.filters = PackedStringArray(["*.json ; Practice report"]); save_dialog.file_selected.connect(func(path): var f = FileAccess.open(path, FileAccess.WRITE); f.store_string(report_text); status.text = "已儲存：" + path); add_child(save_dialog)

func filter_catalog() -> void:
	filtered = []; scenario_list.clear()
	for item in catalog:
		if phase_select.selected == 0 or int(item.phase) == phase_select.selected:
			filtered.append(item); scenario_list.add_item("P%d  %s" % [int(item.phase), item.name.split(" / ")[0]])
	return_to_selection()
func return_to_selection() -> void:
	running = false; paused = false; pending_advance = false; configured = false
	encounter = {}; current = {}; actors = []; active_profile = {}; state = {}; journal = []; retry_history = []; samples = []; all_errors = []; checkpoint_assisted = false
	if is_instance_valid(arena): arena.update_state([], {}, role_select.selected, false)
	scenario_list.deselect_all(); strategy_select.clear(); strategy_select.add_item("請先選擇機制"); strategy_select.disabled = true
	checkpoint_select.clear(); title_label.text = "① 選擇機制 → ② 選攻略方式 → ③ 單獨練習"
	cue.text = "不會自動接續其他機制"; note.text = "先在左側選擇想練習的機制。"; focus_label.text = ""; profile_note.text = "每個機制只列出實際支援的解法。"
	party.text = ""; feedback.text = ""; player_info.text = ""; progress.value = 0
	set_launch_enabled(false)
func set_launch_enabled(enabled: bool) -> void:
	for control in launch_buttons: control.disabled = not enabled
func selected_item() -> Dictionary:
	var selected = scenario_list.get_selected_items()
	return filtered[selected[0]] if selected.size() and not filtered.is_empty() else {}
func choose_mechanic(selection: int) -> void:
	running = false; paused = false; configured = false; encounter = {}; current = {}; actors = []; active_profile = {}; state = {}; journal = []; retry_history = []; samples = []; all_errors = []; checkpoint_assisted = false
	scenario_list.select(selection)
	var item = selected_item()
	if item.is_empty(): return
	strategy_select.clear(); strategy_select.disabled = false; strategy_select.add_item("請選擇此機制的攻略方式")
	for method in mechanic_methods.get(item.id, []):
		strategy_select.add_item(method.name)
		strategy_select.set_item_metadata(strategy_select.item_count - 1, method)
	strategy_select.select(0); checkpoint_select.clear(); set_launch_enabled(false)
	title_label.text = "P%d · %s" % [int(item.phase), item.name.split(" / ")[0]]
	focus_label.text = item.focus; cue.text = "② 選擇此機制的攻略方式"; note.text = "選好攻略方式後才會建立此機制的練習。"
	profile_note.text = "共 %d 種可用解法；只套用到本次選定機制。" % (strategy_select.item_count - 1)
	party.text = ""; feedback.text = ""; arena.update_state([], {}, role_select.selected, false)
	if arena.has_method("set_encounter"): arena.set_encounter(item.id)
	reset_camera()
func choose_strategy(selection: int) -> void:
	if selection <= 0:
		configured = false; running = false; current = {}; encounter = {}; set_launch_enabled(false); return
	var method: Dictionary = strategy_select.get_item_metadata(selection)
	for profile in strategies:
		if profile.id == method.profile:
			active_profile = profile; configured = true; set_launch_enabled(true); prepare(); return
func prepare() -> void:
	if not is_instance_valid(arena) or filtered.is_empty() or not configured or selected_item().is_empty(): return
	running = false; paused = false; demo = false
	player = role_select.selected
	var item = selected_item()
	var seed_value = maxi(1, mini(2147483647, int(seed_edit.text)))
	seed_edit.text = str(seed_value)
	encounter = Encounter.new().build(item.id, seed_value, active_profile, player, slot_select.selected - 1)
	checkpoint_select.clear()
	for b in encounter.beats: checkpoint_select.add_item(b.title)
	title_label.text = "P%d  ·  %s" % [int(item.phase), item.name.split(" / ")[0]]
	focus_label.text = item.focus
	var method: Dictionary = strategy_select.get_item_metadata(strategy_select.selected)
	profile_note.tooltip_text = active_profile.scope
	profile_note.text = method.get("description", "自訂約定；未經外部核對。")
	index = 0; state = new_state(); journal = []; retry_history = []; samples = []; all_errors = []; beat_passed = 0; beat_failed = 0
	begin_beat(true)
	cue.text = "準備完成 · %s · %d 個訓練判定" % [Encounter.ROLES[player], encounter.beats.size()]
	feedback.text = "[color=#90a3bd]開始後控制黃色標示角色。\n關閉提示可練習獨立判斷。[/color]"
	save_settings()
func new_state() -> Dictionary: return {"dynamis": encounter.initial_dynamis.duplicate(), "spent": [], "lb": "", "lb_actor": -1, "aggro": 0, "sim_time": 0.0}
func oracle_state_before(target: int) -> Dictionary:
	var result = new_state()
	var simulated: Array = []
	for k in target:
		var b: Dictionary = encounter.beats[k].duplicate(true)
		if simulated.is_empty():
			simulated = oracle_actors(b)
			if b.has("spawn"):
				for i in 8: simulated[i].pos = b.spawn[i]
		bind_snapshot_geometry(b,simulated,result)
		Interactions.begin(b, simulated, result)
		var clock := 0.0
		while clock < float(b.duration):
			var dt := minf(0.05, float(b.duration) - clock)
			var previous := simulated.duplicate(true)
			for i in 8:
				simulated[i].pos = Rules.v(simulated[i].pos).move_toward(Interactions.bot_goal(i, b, simulated, result), dt * 11.0)
				simulated[i].face = b.facing.get(i, 0.0)
			Interactions.tick(b, simulated, previous, result, dt)
			clock += dt
		for check in b.checks:
			if check.kind == "lb": result.lb = check.type; result.lb_actor = check.eligible[0]
			if check.kind == "aggro": result.aggro = check.actor
		if b.has("knockback"):
			for actor in simulated: actor.pos += Rules.v(actor.pos).normalized() * float(b.knockback)
		var errors := Rules.evaluate(b, simulated, result)
		for error in errors: Interactions.Statuses.fail(result,error)
		Interactions.Statuses.event(result,"snapshot",{"title":b.title,"failures":errors,"actors":simulated.duplicate(true)})
		result.last_snapshot_actors = simulated.duplicate(true)
	result.checkpoint_actors = simulated
	return result
func oracle_actors(b: Dictionary) -> Array:
	var simulated: Array = []
	for i in 8:
		var p: Vector2 = b.positions[i]
		if b.has("knockback"): p += p.normalized() * float(b.knockback)
		simulated.append({"role": Encounter.ROLES[i], "pos": p, "face": b.facing.get(i, 0)})
	return simulated
func start_run(checkpoint := 0) -> void:
	if not configured or selected_item().is_empty(): return
	checkpoint_assisted = checkpoint > 0
	var demonstrate = demo
	prepare(); demo = demonstrate
	index = clampi(checkpoint, 0, encounter.beats.size() - 1)
	state = oracle_state_before(index)
	if index > 0: actors = state.checkpoint_actors.duplicate(true)
	journal = []; retry_history = []; samples = []; all_errors = []; beat_passed = 0; beat_failed = 0
	sprint_left = 0; knockback_resist_left = 0; dash_left = 0
	running = true; paused = false; pending_advance = false; sample_elapsed = 0; pause_button.text = "暫停  P"
	feedback.text = "[color=#8ce3d1]%s · seed %s[/color]\n" % ["示範模式（不計入成績）" if demo else "練習開始", seed_edit.text]
	begin_beat(true)
func begin_beat(reset_positions := false) -> void:
	current = encounter.beats[index].duplicate(true)
	elapsed = 0; wall_recorded = false; pending_advance = false
	state.lb = ""; state.lb_actor = -1
	if reset_positions and state.get("checkpoint_actors", []).size() == 8:
		actors = state.checkpoint_actors.duplicate(true)
	elif reset_positions or actors.size() != 8:
		actors = []
		var initial: Dictionary = encounter.beats[maxi(0, index - 1)] if index > 0 else current
		for i in 8:
			var p: Vector2 = initial.positions[i]
			if index > 0 and initial.has("knockback"): p += p.normalized() * float(initial.knockback)
			if index == 0 and current.has("spawn"): p = current.spawn[i]
			actors.append({"role": Encounter.ROLES[i], "pos": p, "face": 0.0})
	bind_snapshot_geometry(current,actors,state)
	Interactions.begin(current, actors, state)
	if current.has("program_loop"): Rules.ensure_loop_state(current, state)
	before_state = state.duplicate(true)
	start_actors = actors.duplicate(true)
	start_controls = {"sprint":sprint_left,"resist":knockback_resist_left,"dash":dash_left,"direction":dash_direction}
	cue.text = current.title
	note.text = current.note
	checkpoint_select.select(index)
	update_hud()
func bind_snapshot_geometry(b: Dictionary, party_actors: Array, runtime: Dictionary) -> void:
	for shape in b.get("shapes", []):
		if shape.has("snapshot_position_actor"):
			shape.pos = Rules.v(runtime.get("last_snapshot_actors", party_actors)[int(shape.snapshot_position_actor)].pos)
		if shape.has("snapshot_direction_actor"):
			var axis = Rules.v(runtime.get("last_snapshot_actors", party_actors)[int(shape.snapshot_direction_actor)].pos) - Rules.v(shape.get("pos", Vector2.ZERO))
			shape.angle = rad_to_deg(atan2(axis.x, -axis.y))
	if b.has("rotation_sources"):
		var group: String=b.get("rotation_group","")
		if not runtime.has("rotation_snapshots"):runtime.rotation_snapshots={}
		if not group.is_empty() and not runtime.rotation_snapshots.has(group):
			var angles: Array=[]
			for source in b.rotation_sources:
				var axis: Vector2=Rules.v(party_actors[int(source.target)].pos)-Rules.v(source.pos)
				angles.append(rad_to_deg(atan2(axis.x,-axis.y)))
			runtime.rotation_snapshots[group]=angles
		for j in b.rotation_sources.size():
			var source: Dictionary=b.rotation_sources[j]
			var axis: Vector2=Rules.v(party_actors[int(source.target)].pos)-Rules.v(source.pos)
			var angle: float=rad_to_deg(atan2(axis.x,-axis.y)) if group.is_empty() else runtime.rotation_snapshots[group][j]
			b.shapes[j].angle=angle+float(source.turn)
func toggle_pause() -> void:
	if not running: return
	paused = not paused; pause_button.text = "繼續  P" if paused else "暫停  P"
	if paused: write_report()
func retry_beat() -> void:
	if encounter.is_empty(): return
	retry_history.append({"beat":index,"elapsed":elapsed,"state":state.duplicate(true),"actors":actors.duplicate(true),"controls":{"sprint":sprint_left,"resist":knockback_resist_left,"dash":dash_left,"direction":dash_direction}})
	state = before_state.duplicate(true); actors = start_actors.duplicate(true)
	sprint_left = start_controls.get("sprint",0.0); knockback_resist_left = start_controls.get("resist",0.0); dash_left = start_controls.get("dash",0.0); dash_direction = start_controls.get("direction",Vector2.ZERO)
	running = true; paused = false; elapsed = 0; pending_advance = false; wall_recorded = false
	Interactions.sync(current, state)
	status.text = "重練：" + current.title
func _process(delta: float) -> void:
	if current.is_empty(): return
	var speed: float = [0.5, 0.75, 1.0, 1.25, 1.5][speed_select.selected]
	if running and not paused:
		if pending_advance:
			advance_beat()
		else:
			var dt = minf(delta * speed, maxf(0.0, float(current.duration) - elapsed))
			elapsed += dt
			var previous = actors.duplicate(true)
			for i in 8:
				if i == player and not demo: continue
				actors[i].pos = Rules.v(actors[i].pos).move_toward(Interactions.bot_goal(i, current, actors, state), dt * 11.0)
				actors[i].face = current.facing.get(i, 0.0)
			move_player(dt)
			Interactions.tick(current, actors, previous, state, dt)
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
				samples.append({"beat": index, "time": snappedf(elapsed, 0.01), "player_pos": [actors[player].pos.x, actors[player].pos.y], "face": actors[player].face, "statuses": state.get("statuses", []).duplicate(true), "tether_holders": state.get("tether_holders", []).duplicate()})
			if elapsed >= float(current.duration): resolve_beat()
	arena.update_state(actors, current, player, hints.button_pressed or (paused and pending_advance))
	update_hud()
func move_player(dt: float) -> void:
	if demo: return
	var allow_input := not (get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit)
	var movement = Vector2.ZERO
	if allow_input and (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)): movement.y -= 1
	if allow_input and (Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)): movement.y += 1
	if allow_input and (Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)): movement.x -= 1
	if allow_input and (Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)): movement.x += 1
	if allow_input and camera_buttons == 3: movement.y = -1
	if arena.has_method("movement_vector"): movement = arena.movement_vector(movement)
	if allow_input and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): movement = arena.movement_vector(Vector2(0,-1))
	sprint_left = maxf(0, sprint_left - dt); knockback_resist_left = maxf(0, knockback_resist_left - dt)
	var speed = 7.5 if sprint_left > 0 else 6.0
	actors[player].pos += movement.normalized() * speed * dt
	if dash_left > 0:
		var dash_dt = minf(dt, dash_left); actors[player].pos += dash_direction * 30.0 * dash_dt; dash_left -= dash_dt
	var height: float = actors[player].get("height", 0.0)
	var vertical: float = actors[player].get("vertical", 0.0)
	if height > 0 or vertical > 0:
		height = maxf(0, height + vertical * dt - 18.5 * dt * dt); vertical -= 37.0 * dt
		if height == 0: vertical = 0
	actors[player].height = height; actors[player].vertical = vertical
	if movement.length() > 0: actors[player].face = rad_to_deg(atan2(movement.x, -movement.y))
	if allow_input and (Input.is_physical_key_pressed(KEY_Q)): actors[player].face -= 150 * dt
	if allow_input and (Input.is_physical_key_pressed(KEY_E)): actors[player].face += 150 * dt
func reset_camera() -> void:
	if arena.has_method("reset_camera"): arena.reset_camera()
	follow_toggle.set_pressed_no_signal(false)
func on_arena_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var owner = get_viewport().gui_get_focus_owner()
		if owner: owner.release_focus()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: arena.zoom(-2 * maxf(1.0, event.factor))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: arena.zoom(2 * maxf(1.0, event.factor))
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and event.pressed:
			if camera_buttons == 0: camera_anchor = get_global_mouse_position()
			camera_buttons |= 1 if event.button_index == MOUSE_BUTTON_LEFT else 2
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		camera_buttons &= ~(1 if event.button_index == MOUSE_BUTTON_LEFT else 2)
		if camera_buttons == 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE); get_viewport().warp_mouse(camera_anchor)
	if event is InputEventMouseMotion and camera_buttons != 0:
		if arena.has_method("orbit"): arena.orbit(event.relative)
		if camera_buttons & 2 and actors.size() == 8 and arena.get("camera_yaw") != null:
			actors[player].face = -rad_to_deg(float(arena.camera_yaw))
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and camera_buttons:
		camera_buttons = 0; Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
func _unhandled_key_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_SPACE, KEY_L: jump_player()
		KEY_P: toggle_pause()
		KEY_1: use_sprint()
		KEY_2: use_arms()
		KEY_3: use_dash()
		KEY_R: demo = false; start_run()
		KEY_F: use_lb()
		KEY_V: provoke()
func jump_player() -> void:
	if running and not paused and actors.size() == 8 and float(actors[player].get("height",0.0)) == 0: actors[player].vertical = 13.0
func use_sprint() -> void:
	if running and not paused: sprint_left = 10.0
func use_arms() -> void:
	if running and not paused: knockback_resist_left = 6.0
func use_dash() -> void:
	if running and not paused and dash_left <= 0:
		dash_left = 0.5; dash_direction = arena.movement_vector(Vector2(0,-1))
		actors[player].face = rad_to_deg(atan2(dash_direction.x, -dash_direction.y))
func use_lb() -> void:
	if not running or paused: return
	state.lb = "tank" if player < 2 else ("healer" if player < 4 else ("melee" if player < 6 else ("ranged" if player == 6 else "caster")))
	state.lb_actor = player
	status.text = "LB3：%s (%s)" % [Encounter.ROLES[player], state.lb]
func provoke() -> void:
	if player < 2 and running and not paused: state.aggro = player; status.text = "Provoke：" + Encounter.ROLES[player]
func resolve_beat() -> void:
	if current.has("knockback"):
		for i in actors.size():
			if i == player and not demo and knockback_resist_left > 0: continue
			actors[i].pos += Rules.v(actors[i].pos).normalized() * float(current.knockback)
	var errors = Rules.evaluate(current, actors, state)
	for failure in state.get("runtime_failures", []).slice(int(state.get("failure_cursor",0))):
		if failure not in errors: errors.append(failure)
	Interactions.Statuses.event(state,"snapshot",{"title":current.title,"failures":errors,"actors":actors.duplicate(true)})
	state.failure_cursor = state.get("runtime_failures",[]).size()
	state.last_snapshot_actors = actors.duplicate(true)
	if wall_recorded and not ("Death wall (earlier during movement)" in errors): errors.append("Death wall (earlier during movement)")
	journal.append({"beat": index, "title": current.title, "seed": encounter.seed, "failures": errors, "dynamis": state.dynamis.duplicate(), "mode": "demo" if demo else "practice", "statuses": state.get("statuses", []).duplicate(true), "timeline": state.get("timeline", []).duplicate(true), "actors": actors.duplicate(true), "actual_tether_holders": state.get("tether_holders", []).duplicate(), "loop_cleansed": state.get("loop_cleansed", []).duplicate(), "loop_ruin_expires": state.get("loop_ruin_expires", []).duplicate()})
	if errors.is_empty(): beat_passed += 1; log_feedback("✓ " + current.title, true)
	else:
		beat_failed += 1; all_errors.append_array(errors)
		for error in errors: log_feedback(error, false)
		if stop_failure.button_pressed:
			paused = true; pause_button.text = "繼續  P"
	pending_advance = true
	write_report()
func advance_beat() -> void:
	pending_advance = false
	if index + 1 >= encounter.beats.size():
		running = false
		cue.text = "示範結束" if demo else ("練習通過" if all_errors.is_empty() else "練習完成 · 請檢討失誤")
		status.text = "本機制結束，不會接續其他機制 · %d 通過 / %d 失誤 · seed %s" % [beat_passed, beat_failed, seed_edit.text]
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
	if state.has("tether_holders") and current.has("transfers"):
		text_value += "\n[b]當下持線者[/b]\n"
		for k in state.tether_holders.size(): text_value += "線 %d → %s\n" % [k + 1, Encounter.ROLES[int(state.tether_holders[k])]]
		text_value += "接線事件 %d 次\n" % state.get("tether_events", []).size()
	if state.has("loop_cleansed"):
		text_value += "\nYOU · %s" % ("Looper 已消除" if state.loop_cleansed[player] else "Looper %d" % int(current.program_loop.numbers[player]))
		if float(state.loop_ruin_expires[player]) > float(state.sim_time): text_value += " · Ruin 1"
		if float(state.loop_hp_penalty[player]) > float(state.sim_time): text_value += " · HP Penalty"
	if state.has("statuses"):
		var names := {"red":"紅色腐毒", "blue":"藍色腐毒", "overflow":"Critical Overflow", "sync":"Critical Synchronization", "latent_red":"紅塔潛在錯誤", "latent_blue":"藍塔潛在錯誤", "latent_sync":"Latent Synchronization", "latent_overflow":"Latent Overflow", "red_debugger":"紅色除錯", "blue_debugger":"藍色除錯", "overflow_debugger":"Overflow Debugger", "sync_debugger":"Synchronization Debugger", "magic_vulnerability":"魔法易傷", "thrice_come_ruin":"Thrice-come Ruin", "hp_penalty":"HP Penalty"}
		var effects: PackedStringArray = []
		for key in state.statuses[player]:
			var effect: Dictionary = state.statuses[player][key]
			var remaining := float(effect.expires) - float(state.get("sim_time",0.0))
			var title: String = names.get(key,str(key).trim_prefix("smell_").capitalize()+" Code Smell")
			if effect.has("stacks"): title += " ×%d" % int(effect.stacks)
			if remaining < 1.0e20: title += " %.1fs" % maxf(remaining,0.0)
			effects.append(title)
		text_value += "\n當前效果：" + ("／".join(effects) if not effects.is_empty() else "無")
	party.text = text_value
func report() -> Dictionary:
	return {"format": "top-practice-report/2", "version": ProjectSettings.get_setting("application/config/version", "0.3.0-preview"), "scenario": encounter.get("id", ""), "seed": encounter.get("seed", 0), "strategy": encounter.get("profile", ""), "strategy_definition": active_profile.duplicate(true), "fidelity_parameters": Interactions.Statuses.parameter_snapshot(), "role": Encounter.ROLES[player], "mode": "demo" if demo else "practice", "hints": hints.button_pressed, "snapshots": journal, "retries": retry_history, "samples": samples, "failures": all_errors, "fidelity": "stateful contacts, statuses and expiry / partially calibrated community geometry", "checkpoint_assisted": checkpoint_assisted, "dead": state.get("dead",[]).duplicate(), "statuses": state.get("statuses", []).duplicate(true), "timeline": state.get("timeline", []).duplicate(true), "runtime_failures": state.get("runtime_failures", []).duplicate(), "paired_tethers": state.get("paired_tethers", []).duplicate(true), "tether_events": state.get("tether_events", []).duplicate(true), "simulation_time": state.get("sim_time", 0.0), "camera": {"yaw": arena.camera_yaw, "pitch": arena.camera_pitch, "distance": arena.camera_size, "follow": arena.follow_player, "overhead": arena.overhead}, "controls": {"sprint_left": sprint_left, "knockback_resist_left": knockback_resist_left, "dash_left": dash_left, "jump_height": actors[player].get("height",0.0) if actors.size()==8 else 0.0}}
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
	text_value.text = "[b]已核對的戰術約定[/b]\nNA Aether: TMR, BPOG/GPOB, north flex\nEU LPDU: MTRH, BPOG full cross\nJP/Elemental: HTDH, 1234/4231, south flex\nKR: 09STOP 公開 workbook 已核對 P1/P3 優先序與 Omega 選人；不是完整韓服戰術。\nCN: 莫古力公開宏已核對全程優先序；完整站位／其他打法仍需核對。\nTW/其他 DC: 不能用語言推斷統一戰術；可匯入自訂優先序。\n\n[b]這版的範圍[/b]\n20 項獨立機制練習（含示意型項目），不是原戰鬥逐幀重現。\nProgram Loop 與 Limitless Synergy 支援實際接線；P5 近遠跳躍依當下距離計算。\n部分複合機制拆成檢查點，塔位、AoE 大小及時間窗是訓練參數；完整限制見 docs/research/FIDELITY.md。\n無 HP、傷害、完整職業減傷、輸出與網路延遲模擬。\n\n[url=https://ffxiv.tuufless.com/elemental/top/]JP / Elemental guide[/url]\n[url=https://www.thepfstrat.com/u/top]NA / Aether PF[/url]\n[url=https://github.com/cliaux/lpdu.github.io/blob/main/top/top_discord_strats.md]EU / LPDU[/url]\n[url=https://www.inven.co.kr/board/ff14/4338/7027]KR / Rominny[/url]\n[url=https://docs.qq.com/doc/DSlBpR0JqSElVelhH]CN / 莫古力宏[/url]\n[url=https://github.com/aki-terminal-leaf/Omega-Protocol-Sim]Repository / 完整研究與限制[/url]"
	text_value.meta_clicked.connect(func(url): OS.shell_open(str(url))); dialog.add_child(text_value); dialog.popup_centered(); dialog.confirmed.connect(dialog.queue_free)
func edit_custom() -> void:
	if not configured: return
	custom_text.text = JSON.stringify(active_profile, "  "); custom_dialog.popup_centered()
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
	else: strategies.append(p)
	strategy_select.add_item(p.name); strategy_select.set_item_metadata(strategy_select.item_count - 1, {"profile": "custom", "description": "自訂約定；未經外部核對。"})
	strategy_select.select(strategy_select.item_count - 1); active_profile = p; configured = true; prepare()
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "role", player); config.set_value("settings", "hints", hints.button_pressed); config.set_value("settings", "seed", seed_edit.text)
	if strategies[-1].id == "custom": config.set_value("settings", "custom", strategies[-1])
	config.save("user://settings.cfg")
func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return
	if config.has_section_key("settings", "custom"):
		var p: Dictionary = config.get_value("settings", "custom"); strategies.append(p)
	role_select.select(clampi(int(config.get_value("settings", "role", 4)), 0, 7)); hints.button_pressed = bool(config.get_value("settings", "hints", true)); seed_edit.text = str(config.get_value("settings", "seed", "1"))
