# SPDX-License-Identifier: MIT
extends Control
const P6Setup = preload("res://scripts/p6_setup.gd")
const P6LB = preload("res://scripts/p6_lb.gd")
const Movement = preload("res://scripts/movement.gd")
const Encounter = preload("res://scripts/encounters.gd")
const Rules = preload("res://scripts/rules.gd")
const Arena = preload("res://scripts/arena.gd")
const Interactions = preload("res://scripts/interactions.gd")
const Markers=preload("res://scripts/markers.gd")
const MarkerSettings=preload("res://scripts/marker_settings.gd")
const WaymarkEditor=preload("res://scripts/waymark_editor.gd")
var marker_bindings:Dictionary=MarkerSettings.defaults()
var marker_library:Dictionary={"schema":1,"layouts":[]}
var marker_library_writable:=true
var layout_list:OptionButton
var layout_name:LineEdit
var layout_note:Label
var layout_editor:Control
var layout_syncing:=false
var key_dialog:ConfirmationDialog
var key_selects:Array=[]
var key_note:Label
var waymark_layout:Dictionary=Markers.default_layout()
var marker_popup:PopupPanel
var marker_type:OptionButton
var marker_target:OptionButton
var marker_note:Label
var waymark_dialog:ConfirmationDialog
var waymark_text:TextEdit
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
var job_select: OptionButton
var lb_target: OptionButton
var lb_ground_x: SpinBox
var lb_ground_y: SpinBox
var lb_panel: VBoxContainer
var lb_info: Label
var job_role := -1
var lb_target_signature := ""
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
# Setup remains available; practice uses a full-window world and compact HUD.
var practice_view := false
var setup_shell: Control
var practice_root: Control
var view_home: Node
var view_home_index := 0
var view_placeholder: Control
var resume_after_settings := false
var hud_title: Label
var hud_cue: Label
var hud_progress: ProgressBar
var hud_player: Label
var hud_party: VBoxContainer
var hud_party_rows: Array = []
var party_icon_cache: Dictionary = {}
const PartyStatuses = preload("res://scripts/party_statuses.gd")
var hud_feedback: RichTextLabel
var hud_feedback_panel: Control
var hud_bottom_panel: PanelContainer
var hud_pause: Button
var hud_lb_row: HBoxContainer
var hud_lb_target: OptionButton
var hud_ground_row: HBoxContainer
var hud_ground_x: SpinBox
var hud_ground_y: SpinBox
var hud_lb_status: Label
var hud_target_signature := ""
var training_overlay := false
var training_widgets: Array[Control] = []
var hud_gameplay_info: Control
var hud_hotbar: Control
var hud_menu: Button

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
	if ResourceLoader.exists("res://fonts/ui_fallback.otf"):theme_value.default_font.fallbacks=[load("res://fonts/ui_fallback.otf")]
	theme_value.set_stylebox("normal", "Button", panel(Color("1d3047"), 8)); theme_value.set_stylebox("hover", "Button", panel(Color("294a60"), 8)); theme_value.set_stylebox("pressed", "Button", panel(Color("37605f"), 8))
	theme_value.set_stylebox("normal", "LineEdit", panel(Color("172338"), 7)); theme_value.set_stylebox("panel", "PopupMenu", panel(Color("18283c"), 10))
	self.theme = theme_value
	var background = ColorRect.new(); background.color = Color("0b1120"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin); setup_shell = margin
	var root = VBoxContainer.new(); root.add_theme_constant_override("separation", 12); margin.add_child(root)
	var header = HBoxContainer.new(); root.add_child(header)
	header.add_child(label("Ω  OMEGA PROTOCOL", 26, Color("8ce3d1")))
	var subtitle = label("PRACTICE LAB  /  v0.3 preview", 14, Color("8096b4")); subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(subtitle)
	header.add_child(button("攻略來源", show_research))
	header.add_child(button("場地標記",show_waymark_settings))
	var return_view := button("回到練習", return_practice_view)
	header.add_child(return_view); launch_buttons.append(return_view)
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
	role_select = option(Encounter.ROLES); role_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL; role_select.select(4); row.add_child(role_select); role_select.item_selected.connect(func(_i): refresh_jobs(); prepare())
	slot_select = option(["隨機點名", "指定分配 1", "指定分配 2", "指定分配 3", "指定分配 4", "指定分配 5", "指定分配 6", "指定分配 7", "指定分配 8"]); row.add_child(slot_select); slot_select.item_selected.connect(func(_i): prepare())
	lb_panel=VBoxContainer.new();left.add_child(lb_panel)
	lb_panel.add_child(label("P6 職業／LB3 目標",13))
	job_select=option([]);lb_panel.add_child(job_select);refresh_jobs()
	job_select.item_selected.connect(func(_i):prepare())
	lb_target=option(["選擇單體／直線目標"]);lb_target.set_item_metadata(0,"");lb_panel.add_child(lb_target)
	var ground=HBoxContainer.new();lb_panel.add_child(ground);ground.add_child(label("法系落點 X/Z",12))
	lb_ground_x=SpinBox.new();lb_ground_y=SpinBox.new()
	for coordinate in [lb_ground_x,lb_ground_y]:
		coordinate.min_value=-25;coordinate.max_value=25;coordinate.step=0.5;coordinate.custom_minimum_size.x=76;ground.add_child(coordinate)
	lb_info=label("獨立練習以三層 Dynamis 與滿 LB3 起始；不模擬自然充能。",12);lb_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lb_panel.add_child(lb_info)
	lb_panel.visible=false
	left.add_child(label("SEED  /  可重現的隨機種子", 13))
	seed_edit = LineEdit.new(); seed_edit.text = str(randi_range(1, 999999)); seed_edit.placeholder_text = "1…2147483647"; left.add_child(seed_edit); seed_edit.text_submitted.connect(func(_v): prepare())
	var speed_row = HBoxContainer.new(); left.add_child(speed_row); speed_row.add_child(label("速度")); speed_select = option(["0.5×", "0.75×", "1×", "1.25×", "1.5×"]); speed_select.select(2); speed_row.add_child(speed_select)
	hints = CheckBox.new(); hints.text = "示範模式：顯示教學提示"; hints.button_pressed = false; left.add_child(hints)
	stop_failure = CheckBox.new(); stop_failure.text = "失誤後暫停檢討"; stop_failure.button_pressed = true; left.add_child(stop_failure)
	var start = button("▶  只練習選定機制", func(): demo = false; start_run()); left.add_child(start); launch_buttons.append(start)
	left.add_child(label("Esc 設定 · Tab 練習工具",12))
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
	transport.add_child(button("俯視", toggle_overview))
	transport.add_child(button("重設鏡頭", reset_camera))
	follow_toggle = CheckBox.new(); follow_toggle.text = "跟隨"; follow_toggle.toggled.connect(func(value): if arena.has_method("set_follow"): arena.set_follow(value)); transport.add_child(follow_toggle); follow_toggle.set_pressed_no_signal(arena.follow_player)
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
	build_practice_presentation()
	build_marker_controls()

func filter_catalog() -> void:
	filtered = []; scenario_list.clear()
	for item in catalog:
		if phase_select.selected == 0 or int(item.phase) == phase_select.selected:
			filtered.append(item); scenario_list.add_item("P%d  %s" % [int(item.phase), item.name.split(" / ")[0]])
	return_to_selection()
func return_to_selection() -> void:
	set_practice_view(false); resume_after_settings = false
	running = false; paused = false; pending_advance = false; configured = false
	encounter = {}; current = {}; actors = []; active_profile = {}; state = {}; journal = []; retry_history = []; samples = []; all_errors = []; checkpoint_assisted = false
	if is_instance_valid(lb_panel):lb_panel.visible=false
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
	set_practice_view(false); resume_after_settings = false
	running = false; paused = false; configured = false; encounter = {}; current = {}; actors = []; active_profile = {}; state = {}; journal = []; retry_history = []; samples = []; all_errors = []; checkpoint_assisted = false
	scenario_list.select(selection)
	var item = selected_item()
	if item.is_empty(): return
	lb_panel.visible=false
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
			active_profile = load("res://scripts/strategy_routes.gd").apply(profile,selected_item().id,method.get("overrides",{})); configured = true; set_launch_enabled(true); prepare(); return
func refresh_jobs() -> void:
	if job_role==role_select.selected:return
	job_role=role_select.selected;job_select.clear()
	var kind:String="tank" if job_role<2 else ("healer" if job_role<4 else ("melee" if job_role<6 else ("ranged" if job_role==6 else "caster")))
	for identity in P6LB.ACTIONS:
		if P6LB.ACTIONS[identity].kind==kind:job_select.add_item(identity)
	for i in job_select.item_count:
		if job_select.get_item_text(i)==P6Setup.JOBS[job_role]:job_select.select(i)

func prepare() -> void:
	if not is_instance_valid(arena) or filtered.is_empty() or not configured or selected_item().is_empty(): return
	set_practice_view(false); resume_after_settings = false
	running = false; paused = false; demo = false
	player = role_select.selected
	refresh_jobs()
	var item = selected_item()
	lb_panel.visible=item.id in ["p6_memory","p6_meteors","p6_magic"]
	var seed_value = maxi(1, mini(2147483647, int(seed_edit.text)))
	seed_edit.text = str(seed_value)
	encounter = Encounter.new().build(item.id, seed_value, active_profile, player, slot_select.selected - 1)
	checkpoint_select.clear()
	for beat_index in encounter.beats.size(): checkpoint_select.add_item("段落 %d" % (beat_index+1))
	title_label.text = "P%d  ·  %s" % [int(item.phase), item.name.split(" / ")[0]]
	focus_label.text = item.focus
	var method: Dictionary = strategy_select.get_item_metadata(strategy_select.selected)
	profile_note.tooltip_text = active_profile.scope
	profile_note.text = method.get("description", "自訂約定；未經外部核對。")
	index = 0; state = new_state(); journal = []; retry_history = []; samples = []; all_errors = []; beat_passed = 0; beat_failed = 0
	begin_beat(true)
	cue.text = "準備完成 · %s · %d 個訓練判定" % [Encounter.ROLES[player], encounter.beats.size()]
	feedback.text = "[color=#90a3bd]開始後控制黃色標示角色。\n請依隊伍狀態與場地判斷。[/color]"
	save_settings()
func new_state() -> Dictionary: return {"dynamis": encounter.initial_dynamis.duplicate(), "spent": [], "lb": "", "lb_actor": -1, "aggro": 0, "sim_time": 0.0,"seed":encounter.seed}
func oracle_state_before(target: int) -> Dictionary:
	var result = new_state()
	var simulated: Array = []
	for k in target:
		var b: Dictionary = encounter.beats[k].duplicate(true)
		if simulated.is_empty():
			simulated = oracle_actors(b)
			if b.has("spawn"):
				for i in 8: simulated[i].pos = b.spawn[i]
		P6Setup.initialize(result,simulated,encounter.id,-1,selected_job(),player)
		bind_snapshot_geometry(b,simulated,result)
		Interactions.begin(b, simulated, result)
		Movement.begin(b,result)
		var clock := 0.0
		while clock < float(b.duration):
			var dt := minf(0.05, float(b.duration) - clock)
			var previous := simulated.duplicate(true)
			for i in 8:
				simulated[i].pos = Rules.v(simulated[i].pos).move_toward(Interactions.bot_goal(i, b, simulated, result), dt * Movement.speed(b,result,i)) if not load("res://scripts/p6_runtime.gd").is_locked(result,i) else simulated[i].pos
				simulated[i].face = b.facing.get(i, 0.0)
			result.motion_allowances=[]
			for i in 8:result.motion_allowances.append(Movement.speed(b,result,i)*dt)
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
	set_practice_view(true)
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
	P6Setup.initialize(state,actors,encounter.id,player if not demo else -1,selected_job(),player)
	bind_snapshot_geometry(current,actors,state)
	Markers.ensure(state);state.waymark_layout=waymark_layout.duplicate(true)
	Interactions.begin(current, actors, state)
	Movement.begin(current,state,player if not demo else -1)
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
	sync_practice_hud()
func retry_beat() -> void:
	if encounter.is_empty(): return
	retry_history.append({"beat":index,"elapsed":elapsed,"state":state.duplicate(true),"actors":actors.duplicate(true),"controls":{"sprint":sprint_left,"resist":knockback_resist_left,"dash":dash_left,"direction":dash_direction}})
	state = before_state.duplicate(true); actors = start_actors.duplicate(true)
	sprint_left = start_controls.get("sprint",0.0); knockback_resist_left = start_controls.get("resist",0.0); dash_left = start_controls.get("dash",0.0); dash_direction = start_controls.get("direction",Vector2.ZERO)
	running = true; paused = false; elapsed = 0; pending_advance = false; wall_recorded = false
	Interactions.sync(current, state)
	status.text = "重練段落 %d" % (index+1)
func _process(delta: float) -> void:
	# Web pointer lock may complete after a quick press/release has already ended.
	# Reconcile that late capture even while paused or back in setup.
	if camera_buttons == 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if current.is_empty(): return
	var speed: float = [0.5, 0.75, 1.0, 1.25, 1.5][speed_select.selected]
	if running and not paused:
		var budget:=delta*speed
		while budget>0.000001 and running and not paused:
			if pending_advance:
				advance_beat()
				continue
			var remaining:=maxf(0.0,float(current.duration)-elapsed)
			if remaining<=0.000001:
				resolve_beat()
				continue
			var dt:=minf(budget,minf(0.05,remaining))
			budget-=dt
			elapsed += dt
			var previous = actors.duplicate(true)
			for i in 8:
				if i == player and not demo: continue
				actors[i].pos = Rules.v(actors[i].pos).move_toward(Interactions.bot_goal(i, current, actors, state), dt * Movement.speed(current,state,i)) if not load("res://scripts/p6_runtime.gd").is_locked(state,i) else actors[i].pos
				actors[i].face = current.facing.get(i, 0.0)
			state.motion_allowances=[]
			for i in 8:state.motion_allowances.append(Movement.speed(current,state,i)*dt)
			if not demo:state.motion_allowances[player]=(7.5 if sprint_left>0 else 6.0)*dt+30.0*minf(dash_left,dt)
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
				samples.append({"beat": index, "time": snappedf(elapsed, 0.01), "player_pos": [actors[player].pos.x, actors[player].pos.y], "actors": actors.duplicate(true), "face": actors[player].face, "statuses": state.get("statuses", []).duplicate(true), "tether_holders": state.get("tether_holders", []).duplicate()})
			if elapsed >= float(current.duration): resolve_beat()
	arena.update_state(actors, current, player, answers_visible(), elapsed, state)
	update_hud()
func move_player(dt: float) -> void:
	if demo: return
	var cast_locked: bool=load("res://scripts/p6_runtime.gd").is_locked(state,player)
	var allow_input := not cast_locked and not (get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit)
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
	if dash_left > 0 and not cast_locked:
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
	follow_toggle.set_pressed_no_signal(arena.follow_player)
func on_arena_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var owner = get_viewport().gui_get_focus_owner()
		if owner: owner.release_focus()
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var steps := (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0) * maxf(1.0, event.factor)
			if arena.has_method("zoom_steps"): arena.zoom_steps(steps)
			else: arena.zoom(steps * 2.0)
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB and practice_view and not (get_viewport().gui_get_focus_owner() is LineEdit):
		training_overlay = not training_overlay; sync_practice_hud(); get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if is_instance_valid(marker_popup) and marker_popup.visible:
			marker_popup.hide();get_viewport().set_input_as_handled();return
		camera_buttons = 0; Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if practice_view: open_practice_settings()
func _unhandled_key_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.shift_pressed and event.physical_keycode==KEY_R:
		demo=true;start_run();return
	if event.ctrl_pressed and event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_8:
		apply_target_marker(player,"attack%d"%(event.physical_keycode-KEY_1+1));return
	if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed:
		for action in MarkerSettings.ACTIONS:
			if event.physical_keycode!=int(marker_bindings[action]):continue
			match action:
				"panel":show_target_markers()
				"self":apply_target_marker(player,str(Markers.IDS[marker_type.selected]))
				"next":next_self_marker()
				"clear":apply_target_marker(player,"")
			get_viewport().set_input_as_handled();return
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
	if can_act() and actors.size() == 8 and float(actors[player].get("height",0.0)) == 0: actors[player].vertical = 13.0
func use_sprint() -> void:
	if can_act() and float(state.get("player_sprint_ready",0))<=float(state.sim_time):
		sprint_left=10.0;state.player_sprint_ready=float(state.sim_time)+60.0
func use_arms() -> void:
	if can_act(): knockback_resist_left = 6.0
func use_dash() -> void:
	if can_act() and dash_left <= 0:
		dash_left = 0.5; dash_direction = arena.movement_vector(Vector2(0,-1))
		actors[player].face = rad_to_deg(atan2(dash_direction.x, -dash_direction.y))
func selected_job() -> String:
	return job_select.get_item_text(job_select.selected) if job_select.selected>=0 else ""
func use_lb() -> void:
	if not running or paused:return
	if not state.has("p6_lb"):
		status.text="此機制沒有 LB3 練習狀態。";return
	P6LB.sync(actors,state)
	var identity:String=state.p6_lb.jobs[player]
	var kind:String=P6LB.ACTIONS[identity].kind
	var target=null
	if kind=="caster":target=Vector2(lb_ground_x.value,lb_ground_y.value)
	elif kind in ["ranged","melee"] and lb_target.selected>=0:target=lb_target.get_item_metadata(lb_target.selected)
	var result:Dictionary=P6LB.request_lb(state,player,kind,target)
	if result.ok:dash_left=0.0
	status.text=("LB3 開始：%s / %s"%[Encounter.ROLES[player],identity]) if result.ok else ("LB3 未開始："+str(result.reason))
	update_hud()
func can_act() -> bool:
	return running and not paused and not load("res://scripts/p6_runtime.gd").is_locked(state,player)
func update_lb_controls() -> void:
	if not state.has("p6_lb"):return
	var lb:Dictionary=state.p6_lb;var selected:String=str(lb_target.get_item_metadata(lb_target.selected)) if lb_target.selected>=0 else ""
	var signature:String=JSON.stringify(lb.targets.map(func(n):return [n.id,float(n.hp)>0,bool(n.get("targetable",true))]))
	if signature!=lb_target_signature:
		lb_target_signature=signature;lb_target.clear();lb_target.add_item("選擇單體／直線目標");lb_target.set_item_metadata(0,"")
		for npc in lb.targets:
			lb_target.add_item(str(npc.id)+("（已死亡）" if float(npc.hp)<=0 else ""));var index:int=lb_target.item_count-1;lb_target.set_item_metadata(index,npc.id)
			if npc.id==selected:lb_target.select(index)
	var detail:String="LB3 %.0f%% · %s"%[float(lb.gauge)/300.0,"讀條／動畫鎖" if P6LB.is_locked(state,player) else "可操作"]
	for cast in lb.casts:
		if int(cast.actor)==player:detail+=" · 讀條 %.1fs"%maxf(0,float(cast.finish)-float(state.sim_time))
	lb_info.text=detail+"\n獨立前置快照：三層 Dynamis、滿 LB3；不模擬自然充能。"
	var kind:String=P6LB.ACTIONS[lb.jobs[player]].kind
	lb_target.visible=kind in ["ranged","melee"];lb_ground_x.get_parent().visible=kind=="caster"

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
	journal.append({"beat": index, "title": current.title, "seed": encounter.seed, "failures": errors, "dynamis": state.dynamis.duplicate(), "mode": "demo" if demo else "practice", "statuses": state.get("statuses", []).duplicate(true), "timeline_cursor": state.get("timeline", []).size(), "actors": actors.duplicate(true), "actual_tether_holders": state.get("tether_holders", []).duplicate(), "loop_cleansed": state.get("loop_cleansed", []).duplicate(), "loop_ruin_expires": state.get("loop_ruin_expires", []).duplicate()})
	if errors.is_empty(): beat_passed += 1; log_feedback("✓ 判定 %d 通過" % (index+1), true)
	else:
		beat_failed += 1; all_errors.append_array(errors)
		for error in errors: log_feedback(error, false)
		if stop_failure.button_pressed:
			paused = true; pause_button.text = "繼續  P"
	pending_advance = true
	if not errors.is_empty():
		log_feedback("失敗檢討 · " + current.title, false)
		if not str(current.labels[player]).strip_edges().is_empty(): log_feedback("參考處理：" + str(current.labels[player]), false)
		log_feedback(str(current.get("note","")), false)
	update_hud()
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
	feedback.text += "[color=%s]%s[/color]\n" % ["#8ce3d1" if good else "#ff9a9a", text_value.replace("[", "(").replace("]", ")")]
	feedback.scroll_to_line(feedback.get_line_count())
func failed_review() -> bool:
	return pending_advance and not journal.is_empty() and int(journal[-1].beat)==index and not journal[-1].failures.is_empty() and (paused or not running)
func answers_visible() -> bool:
	return (demo and hints.button_pressed) or failed_review()
func observed_party() -> Array:
	return PartyStatuses.rows(actors,state,current,{"actor":player,"sprint_left":sprint_left,"knockback_resist_left":knockback_resist_left})
func update_hud() -> void:
	if actors.size() != 8: return
	progress.value = clampf(elapsed / float(current.get("duration", 1)) * 100, 0, 100)
	player_info.text = "%s  ·  判定 %d/%d  ·  %.1fs" % [Encounter.ROLES[player],index+1,encounter.beats.size(),maxf(0,float(current.duration)-elapsed)]
	if running:
		cue.text = current.title if answers_visible() else ("示範模式 · 不計入成績" if demo else "練習中 · 請觀察場地與隊伍狀態")
	note.text = str(current.get("note","")) if answers_visible() else ""
	var text_value := "[b]PARTY / 狀態[/b]\n"
	for row in observed_party():
		text_value += "[color=%s]%s %s[/color]" % ["#fff0a7" if row.actor==player else "#d2dded","YOU" if row.actor==player else "",row.role]
		var effects:PackedStringArray=[]
		for item in row.effects: effects.append(PartyStatuses.format_effect(item))
		text_value += "\n" + ("KO" if row.dead else ("／".join(effects) if not effects.is_empty() else "—")) + "\n"
	party.text = text_value
	update_lb_controls()
	sync_practice_hud()
func report() -> Dictionary:
	return {"format": "top-practice-report/3", "version": ProjectSettings.get_setting("application/config/version", "0.3.0-preview"), "scenario": encounter.get("id", ""), "seed": encounter.get("seed", 0), "strategy": encounter.get("profile", ""), "strategy_definition": active_profile.duplicate(true), "fidelity_parameters": Interactions.Statuses.parameter_snapshot(), "role": Encounter.ROLES[player], "mode": "demo" if demo else "practice", "hints": answers_visible(), "teaching_preference": hints.button_pressed, "snapshots": journal, "retries": retry_history, "samples": samples, "failures": all_errors, "fidelity": "stateful contacts, statuses and expiry / partially calibrated community geometry", "checkpoint_assisted": checkpoint_assisted, "dead": state.get("dead",[]).duplicate(), "statuses": state.get("statuses", []).duplicate(true), "timeline": state.get("timeline", []).duplicate(true), "runtime_failures": state.get("runtime_failures", []).duplicate(), "paired_tethers": state.get("paired_tethers", []).duplicate(true), "tether_events": state.get("tether_events", []).duplicate(true), "simulation_time": state.get("sim_time", 0.0), "runtime_state": report_runtime_state(), "target_markers":state.get("target_markers",{}).duplicate(true), "waymarks":state.get("waymark_layout",waymark_layout).duplicate(true), "camera": {"yaw": arena.camera_yaw, "pitch": arena.camera_pitch, "distance": arena.camera_size, "follow": arena.follow_player, "overhead": arena.overhead, "fov": arena.camera.fov, "viewport": [world.size.x,world.size.y], "practice_view": practice_view}, "controls": {"marker_keys":marker_bindings.duplicate(),"sprint_left": sprint_left, "knockback_resist_left": knockback_resist_left, "dash_left": dash_left, "jump_height": actors[player].get("height",0.0) if actors.size()==8 else 0.0}}
func report_runtime_state() -> Dictionary:
	var result:Dictionary=state.duplicate(true)
	result.erase("timeline") #the authoritative top-level timeline is already exported
	return result
func json_safe(value):
	if value is Vector2:return [value.x,value.y]
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Array:
		var result:Array=[]
		for item in value:result.append(json_safe(item))
		return result
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[str(key)]=json_safe(value[key])
		return result
	return value
func write_report() -> void:
	report_text = JSON.stringify(json_safe(report()), "  ")
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
	config.load("user://settings.cfg") # Preserve unrelated settings and future sections.
	config.set_value("settings", "role", player); config.set_value("settings", "hints", hints.button_pressed); config.set_value("settings", "seed", seed_edit.text)
	if strategies[-1].id == "custom": config.set_value("settings", "custom", strategies[-1])
	config.set_value("settings","waymarks",waymark_layout)
	config.set_value("settings","marker_keys",marker_bindings)
	if marker_library_writable:config.set_value("settings","waymark_library",marker_library)
	if is_instance_valid(marker_type):config.set_value("settings","self_marker",marker_type.selected)
	config.save("user://settings.cfg")
func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return
	var keys_checked:=MarkerSettings.validate_keys(config.get_value("settings","marker_keys",marker_bindings))
	if keys_checked.ok:marker_bindings=keys_checked.keys
	var library_checked:=MarkerSettings.validate_library(config.get_value("settings","waymark_library",marker_library))
	marker_library_writable=library_checked.ok
	if library_checked.ok:marker_library=library_checked.library
	refresh_layout_list();refresh_marker_hint()
	var checked:=Markers.validate_layout(config.get_value("settings","waymarks",waymark_layout))
	if checked.ok:waymark_layout=checked.layout
	if is_instance_valid(arena):arena.set_waymarks(waymark_layout)
	if is_instance_valid(marker_type):marker_type.select(clampi(int(config.get_value("settings","self_marker",0)),0,16))
	if config.has_section_key("settings", "custom"):
		var p: Dictionary = config.get_value("settings", "custom"); strategies.append(p)
	role_select.select(clampi(int(config.get_value("settings", "role", 4)), 0, 7)); hints.button_pressed = bool(config.get_value("settings", "hints", false)); seed_edit.text = str(config.get_value("settings", "seed", "1"))

# Presentation-only: the original viewport/actors survive both layouts.
func hud_panel(parent: Node, preset: int, offsets: Rect2) -> PanelContainer:
	var box := PanelContainer.new()
	parent.add_child(box)
	box.set_anchors_and_offsets_preset(preset)
	box.offset_left = offsets.position.x; box.offset_top = offsets.position.y
	box.offset_right = offsets.end.x; box.offset_bottom = offsets.end.y
	box.add_theme_stylebox_override("panel", panel(Color(0.035,0.055,0.09,0.78),8))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

func build_practice_presentation() -> void:
	view_home = view_container.get_parent(); view_home_index = view_container.get_index()
	view_placeholder = Control.new()
	view_placeholder.custom_minimum_size = Vector2(350,300)
	view_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_home.add_child(view_placeholder); view_home.move_child(view_placeholder,view_home_index)
	view_placeholder.hide()
	practice_root = Control.new(); practice_root.name = "PlayerView"
	add_child(practice_root); practice_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	practice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := hud_panel(practice_root,Control.PRESET_CENTER_TOP,Rect2(-320,10,640,88))
	training_widgets.append(top)
	var titles := VBoxContainer.new(); titles.mouse_filter = Control.MOUSE_FILTER_IGNORE; top.add_child(titles)
	hud_title = label("",16,Color("edf4ff")); hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; titles.add_child(hud_title)
	hud_cue = label("",14,Color("ffd58f")); hud_cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hud_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; titles.add_child(hud_cue)
	hud_progress = ProgressBar.new(); hud_progress.custom_minimum_size.y = 4; hud_progress.show_percentage = false; hud_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE; titles.add_child(hud_progress)
	var menu := button("練習設定", open_practice_settings)
	hud_menu = menu; training_widgets.append(menu)
	practice_root.add_child(menu); menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -116; menu.offset_right = -12; menu.offset_top = 12; menu.offset_bottom = 50
	var mark_button:=button("標記",show_target_markers);practice_root.add_child(mark_button);training_widgets.append(mark_button)
	mark_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);mark_button.offset_left=-116;mark_button.offset_right=-12;mark_button.offset_top=56;mark_button.offset_bottom=94
	var roster := hud_panel(practice_root,Control.PRESET_TOP_LEFT,Rect2(12,16,310,390))
	hud_party = VBoxContainer.new(); hud_party.mouse_filter=Control.MOUSE_FILTER_IGNORE; roster.add_child(hud_party)
	hud_party.add_theme_constant_override("separation",3)
	hud_party.add_child(label("PARTY / 狀態",13,Color("c5d8ee")))
	for i in 8:
		var row := HBoxContainer.new(); row.custom_minimum_size.y=43; row.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud_party.add_child(row)
		var role := label("",13); role.custom_minimum_size.x=44; role.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(role)
		var sign:=TextureRect.new();sign.name="TargetSign";sign.custom_minimum_size=Vector2(24,26);sign.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sign.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(sign)
		var sign_fallback:=label("",10);sign_fallback.custom_minimum_size.x=0;row.add_child(sign_fallback)
		var effects := HFlowContainer.new(); effects.size_flags_horizontal=Control.SIZE_EXPAND_FILL; effects.add_theme_constant_override("h_separation",3); effects.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(effects)
		hud_party_rows.append({"role":role,"marker":sign,"marker_fallback":sign_fallback,"effects":effects,"signature":"","slots":[]})
	hud_feedback_panel = hud_panel(practice_root,Control.PRESET_BOTTOM_LEFT,Rect2(12,-242,350,128))
	hud_feedback = RichTextLabel.new(); hud_feedback.bbcode_enabled = true; hud_feedback.custom_minimum_size = Vector2(330,104); hud_feedback.scroll_active = true; hud_feedback_panel.add_child(hud_feedback)
	hud_bottom_panel = hud_panel(practice_root,Control.PRESET_BOTTOM_WIDE,Rect2(12,-104,-24,94))
	var bottom := hud_bottom_panel
	var bars := VBoxContainer.new(); bars.add_theme_constant_override("separation",4); bottom.add_child(bars)
	var info := HBoxContainer.new(); bars.add_child(info); hud_gameplay_info = info
	hud_player = label("",14,Color("8ce3d1")); hud_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_child(hud_player); training_widgets.append(hud_player)
	hud_lb_status = label("",12,Color("ffd58f")); info.add_child(hud_lb_status)
	var hotbar := HBoxContainer.new(); hud_hotbar = hotbar; training_widgets.append(hotbar); hotbar.add_theme_constant_override("separation",4); bars.add_child(hotbar)
	for action in [["1 疾跑",use_sprint],["2 防擊退",use_arms],["3 突進",use_dash],["Space 跳躍",jump_player],["F LB3",use_lb],["V 換坦",provoke]]:
		var ability := button(str(action[0]),action[1]); ability.custom_minimum_size.y = 30; hotbar.add_child(ability)
	var gap := Control.new(); gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; gap.mouse_filter = Control.MOUSE_FILTER_IGNORE; hotbar.add_child(gap)
	hud_pause = button("P 暫停",toggle_pause); hud_pause.custom_minimum_size.y = 30; hotbar.add_child(hud_pause)
	for action in [["R 重來",func():demo=false;start_run()],["俯視",toggle_overview],["鏡頭",reset_camera],["JSON",export_report]]:
		var item := button(str(action[0]),action[1]); item.custom_minimum_size.y = 30; hotbar.add_child(item)
	hud_lb_row = HBoxContainer.new(); hud_lb_row.add_theme_constant_override("separation",6); bars.add_child(hud_lb_row)
	hud_lb_target = option([]); hud_lb_target.custom_minimum_size = Vector2(200,28); hud_lb_row.add_child(hud_lb_target)
	hud_lb_target.item_selected.connect(func(i):if i<lb_target.item_count:lb_target.select(i))
	hud_ground_row = HBoxContainer.new(); hud_lb_row.add_child(hud_ground_row); hud_ground_row.add_child(label("法系落點 X/Z",12))
	hud_ground_x = SpinBox.new(); hud_ground_y = SpinBox.new()
	for coordinate in [hud_ground_x,hud_ground_y]:
		coordinate.min_value = -25; coordinate.max_value = 25; coordinate.step = 0.5; coordinate.custom_minimum_size = Vector2(76,28); hud_ground_row.add_child(coordinate)
	hud_ground_x.value_changed.connect(func(value):lb_ground_x.value=value)
	hud_ground_y.value_changed.connect(func(value):lb_ground_y.value=value)
	practice_root.hide()

func set_practice_view(enabled: bool) -> void:
	if not is_instance_valid(practice_root): return
	practice_view = enabled
	if enabled:
		training_overlay = false
		var focused := get_viewport().gui_get_focus_owner()
		if focused: focused.release_focus()
		if view_container.get_parent() != practice_root:
			view_container.reparent(practice_root,false); practice_root.move_child(view_container,0)
		view_container.custom_minimum_size = Vector2.ZERO
		view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view_placeholder.show(); setup_shell.hide(); practice_root.show()
	else:
		if view_container.get_parent() != view_home:
			view_container.reparent(view_home,false); view_home.move_child(view_container,view_home_index)
		view_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		view_container.custom_minimum_size = Vector2(350,300)
		view_placeholder.hide(); practice_root.hide(); setup_shell.show()
	sync_practice_hud()

func open_practice_settings() -> void:
	resume_after_settings = running and not paused
	if resume_after_settings: toggle_pause()
	set_practice_view(false)

func return_practice_view() -> void:
	if not configured or actors.size()!=8: return
	if not running:
		demo = false; start_run(); return
	set_practice_view(true)
	if resume_after_settings and running and paused: toggle_pause()
	resume_after_settings = false

func toggle_overview() -> void:
	if arena.has_method("set_overhead"): arena.set_overhead(not arena.overhead)
	else: arena.overhead=not arena.overhead; arena.update_camera()
	follow_toggle.set_pressed_no_signal(arena.follow_player)

func sync_practice_hud() -> void:
	if not is_instance_valid(hud_title): return
	hud_title.text = title_label.text; hud_cue.text = cue.text
	hud_progress.value = progress.value; hud_player.text = player_info.text
	hud_pause.text = "P 繼續" if paused else "P 暫停"
	hud_feedback.text = feedback.text
	hud_feedback_panel.visible = training_overlay and configured and (failed_review() or (not running and not all_errors.is_empty()))
	for widget in training_widgets: widget.visible = training_overlay
	sync_party_status_hud()
	hud_lb_row.visible = configured and lb_panel.visible and state.has("p6_lb")
	hud_lb_status.text = lb_info.text.split("\n")[0] if hud_lb_row.visible else ""
	hud_bottom_panel.visible = training_overlay or hud_lb_row.visible
	hud_gameplay_info.visible = training_overlay or hud_lb_row.visible
	hud_bottom_panel.offset_top = (-144 if hud_lb_row.visible else -104) if training_overlay else -82
	hud_feedback_panel.offset_top = -282 if hud_lb_row.visible else -242
	hud_feedback_panel.offset_bottom = -154 if hud_lb_row.visible else -114
	if not hud_lb_row.visible: return
	var items: Array = []
	for i in lb_target.item_count: items.append([lb_target.get_item_text(i),lb_target.get_item_metadata(i)])
	var signature := JSON.stringify(items)
	if signature != hud_target_signature:
		hud_target_signature = signature; hud_lb_target.clear()
		for i in items.size():
			hud_lb_target.add_item(items[i][0]); hud_lb_target.set_item_metadata(i,items[i][1])
	if lb_target.selected >= 0 and lb_target.selected < hud_lb_target.item_count: hud_lb_target.select(lb_target.selected)
	hud_lb_target.visible = lb_target.visible
	hud_ground_row.visible = lb_ground_x.get_parent().visible
	if not hud_ground_x.get_line_edit().has_focus(): hud_ground_x.value = lb_ground_x.value
	if not hud_ground_y.get_line_edit().has_focus(): hud_ground_y.value = lb_ground_y.value

func party_icon(icon_id: int) -> Texture2D:
	if icon_id<=0: return null
	if not party_icon_cache.has(icon_id): party_icon_cache[icon_id]=arena.original_icon(icon_id)
	return party_icon_cache[icon_id]
func sync_party_status_hud() -> void:
	var rows := observed_party()
	for i in rows.size():
		var data:Dictionary=rows[i]; var widgets:Dictionary=hud_party_rows[i]
		var marker:=Markers.marker_for(state,i);var marker_texture:=party_icon(Markers.icon_id(marker))
		widgets.marker.texture=marker_texture;widgets.marker.visible=marker!="" and marker_texture!=null;widgets.marker.tooltip_text=Markers.title(marker)
		widgets.marker_fallback.text=Markers.title(marker) if marker!="" and marker_texture==null else ""
		widgets.role.text=("▶ " if i==player else "")+str(data.role)+( " KO" if data.dead else "")
		widgets.role.modulate=Color("fff0a7") if i==player else Color("d2dded")
		var signature:=JSON.stringify(data.effects.map(func(item):return [item.key,item.icon,item.name]))
		if signature!=widgets.signature:
			widgets.signature=signature
			for child in widgets.effects.get_children(): widgets.effects.remove_child(child);child.queue_free()
			widgets.slots=[]
			for item in data.effects:
				var slot:=VBoxContainer.new(); slot.add_theme_constant_override("separation",0); slot.mouse_filter=Control.MOUSE_FILTER_STOP; widgets.effects.add_child(slot)
				var texture:=party_icon(int(item.icon))
				if texture!=null:
					var icon:=TextureRect.new();icon.texture=texture;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(24,26);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(icon)
				else:
					var fallback:=label(str(item.name).left(5),22 if str(item.name).length()==1 else 10);fallback.custom_minimum_size=Vector2(28,26);fallback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(fallback)
				var timer:=label("",10);timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;timer.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(timer)
				widgets.slots.append({"slot":slot,"timer":timer})
		for j in data.effects.size():
			var item:Dictionary=data.effects[j];var slot:Dictionary=widgets.slots[j]
			slot.slot.tooltip_text=PartyStatuses.format_effect(item)
			slot.timer.text=(str(int(ceil(float(item.remaining))))+"s" if float(item.remaining)>=0 else "")+(" x%d"%int(item.stacks) if int(item.stacks)>1 else "")

func build_marker_controls()->void:
	marker_popup=PopupPanel.new();marker_popup.name="TargetMarkers";add_child(marker_popup)
	var box:=VBoxContainer.new();box.custom_minimum_size.x=300;marker_popup.add_child(box)
	box.add_child(label("目標標記",17))
	marker_target=option(Encounter.ROLES);box.add_child(marker_target)
	marker_type=option(Markers.LABELS);box.add_child(marker_type)
	marker_type.item_selected.connect(func(_i):save_settings())
	box.add_child(button("對選定隊友上標",func():apply_target_marker(marker_target.selected,str(Markers.IDS[marker_type.selected]))))
	box.add_child(button("對自己上標",func():apply_target_marker(player,str(Markers.IDS[marker_type.selected]))))
	box.add_child(button("自己下一個空號",next_self_marker))
	box.add_child(button("清除選定隊友標記",func():apply_target_marker(marker_target.selected,"")))
	box.add_child(button("快捷鍵設定",show_marker_keys))
	box.add_child(button("關閉",marker_popup.hide))
	marker_note=label("M 自標 · N 下一空號 · Backspace 清自標
Ctrl+1–8 對自己上攻擊編號",12);marker_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(marker_note)
	waymark_dialog=ConfirmationDialog.new();waymark_dialog.title="場地標記配置";waymark_dialog.size=Vector2i(860,610);add_child(waymark_dialog)
	var content:=VBoxContainer.new();waymark_dialog.add_child(content)
	var library_row:=HBoxContainer.new();content.add_child(library_row)
	layout_list=OptionButton.new();layout_list.fit_to_longest_item=false;layout_list.custom_minimum_size.x=180;library_row.add_child(layout_list)
	layout_list.item_selected.connect(load_library_draft)
	layout_name=LineEdit.new();layout_name.placeholder_text="配置名稱";layout_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;library_row.add_child(layout_name)
	library_row.add_child(button("儲存",func():save_library_draft(false)))
	library_row.add_child(button("複製",func():save_library_draft(true)))
	library_row.add_child(button("移除",remove_library_draft))
	var presets:=HBoxContainer.new();content.add_child(presets)
	for preset in [["通用八標",13.0],["外圈八標",18.0]]:
		var radius:=float(preset[1]);presets.add_child(button(str(preset[0]),func():set_layout_draft(Markers.default_layout(radius))))
	presets.add_child(button("不顯示",func():set_layout_draft({"schema":1,"name":"不顯示","marks":[]})))
	var rotation:=SpinBox.new();rotation.min_value=-360;rotation.max_value=360;rotation.step=5;rotation.value=45;presets.add_child(rotation)
	presets.add_child(button("旋轉草稿",func():
		var raw:Variant=JSON.parse_string(waymark_text.text)
		var checked:Dictionary=MarkerSettings.rotated(raw,rotation.value) if raw is Dictionary else {"ok":false,"reason":"JSON 無效"}
		if checked.ok:set_layout_draft(checked.layout)
		else:layout_note.text=str(checked.reason)))
	content.add_child(label("北方固定；拖曳圖上的標記。套用後會重開練習，儲存配置庫不會改動當前戰鬥。",13))
	var editing:=HBoxContainer.new();content.add_child(editing)
	waymark_text=TextEdit.new();waymark_text.custom_minimum_size=Vector2(470,350);waymark_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;editing.add_child(waymark_text)
	layout_editor=WaymarkEditor.new();layout_editor.custom_minimum_size=Vector2(300,300);editing.add_child(layout_editor)
	layout_note=label("",13);content.add_child(layout_note)
	waymark_text.text_changed.connect(sync_layout_draft)
	layout_editor.layout_changed.connect(func(layout:Dictionary):
		layout_syncing=true;waymark_text.text=JSON.stringify(layout,"  ");layout_syncing=false)
	waymark_dialog.confirmed.connect(apply_waymark_settings)
	key_dialog=ConfirmationDialog.new();key_dialog.title="標記快捷鍵";key_dialog.size=Vector2i(400,340);add_child(key_dialog)
	var keys_box:=VBoxContainer.new();key_dialog.add_child(keys_box)
	for title in MarkerSettings.TITLES:
		var row:=HBoxContainer.new();keys_box.add_child(row);row.add_child(label(title,14))
		var select:=OptionButton.new();select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		for key in MarkerSettings.KEYS:select.add_item(OS.get_keycode_string(key));select.set_item_metadata(select.item_count-1,key)
		row.add_child(select);key_selects.append(select)
	keys_box.add_child(label("使用單鍵；Ctrl+1–8 仍為直接自標攻擊編號。",12))
	key_note=label("",12);keys_box.add_child(key_note)
	key_dialog.confirmed.connect(apply_marker_keys)
	refresh_layout_list()
func refresh_marker_hint()->void:
	if is_instance_valid(marker_note):marker_note.text="%s 自標 · %s 下一空號 · %s 清自標\nCtrl+1–8 對自己上攻擊編號"%[OS.get_keycode_string(marker_bindings.self),OS.get_keycode_string(marker_bindings.next),OS.get_keycode_string(marker_bindings.clear)]
func show_marker_keys()->void:
	marker_popup.hide()
	for i in MarkerSettings.ACTIONS.size():key_selects[i].select(MarkerSettings.KEYS.find(int(marker_bindings[MarkerSettings.ACTIONS[i]])))
	key_note.text="";key_dialog.popup_centered()
func apply_marker_keys()->void:
	var proposed:={}
	for i in MarkerSettings.ACTIONS.size():proposed[MarkerSettings.ACTIONS[i]]=int(key_selects[i].get_item_metadata(key_selects[i].selected))
	var checked:=MarkerSettings.validate_keys(proposed)
	if not checked.ok:key_note.text=str(checked.reason);key_dialog.call_deferred("popup_centered");return
	marker_bindings=checked.keys;save_settings();refresh_marker_hint()
func refresh_layout_list()->void:
	if not is_instance_valid(layout_list):return
	layout_list.clear();layout_list.add_item("選擇已存配置…")
	for item in marker_library.layouts:layout_list.add_item(str(item.name))
func set_layout_draft(layout:Dictionary)->void:
	var checked:=Markers.validate_layout(layout)
	if not checked.ok:layout_note.text=str(checked.reason);return
	layout_syncing=true;waymark_text.text=JSON.stringify(checked.layout,"  ");layout_syncing=false
	layout_name.text=str(checked.layout.name);layout_editor.set_layout(checked.layout);layout_note.text="僅編輯草稿；按確定才套用至練習。"
func sync_layout_draft()->void:
	if layout_syncing:return
	var checked:=Markers.validate_layout(JSON.parse_string(waymark_text.text))
	if checked.ok:layout_editor.set_layout(checked.layout);layout_note.text="草稿有效；按確定才套用至練習。"
	else:layout_note.text="尚未套用："+str(checked.reason)
func load_library_draft(index_value:int)->void:
	if index_value>0 and index_value<=marker_library.layouts.size():set_layout_draft(marker_library.layouts[index_value-1])
func save_library_draft(copy:bool)->void:
	var raw:Variant=JSON.parse_string(waymark_text.text)
	if not raw is Dictionary:layout_note.text="JSON 無效，未更動配置庫";return
	var checked:=MarkerSettings.store(marker_library,raw,layout_name.text,copy)
	if not checked.ok:layout_note.text=str(checked.reason);return
	marker_library=checked.library;marker_library_writable=true;save_settings();refresh_layout_list()
	var selected:int=marker_library.layouts.size()-1
	if not copy:
		for i in marker_library.layouts.size():
			if marker_library.layouts[i].name==layout_name.text.strip_edges():selected=i;break
	if selected>=0:set_layout_draft(marker_library.layouts[selected]);layout_list.select(selected+1)
	layout_note.text="已儲存配置庫；當前練習未改動。"
func remove_library_draft()->void:
	var selected:=layout_list.selected-1
	if selected<0 or selected>=marker_library.layouts.size():return
	marker_library.layouts.remove_at(selected);marker_library_writable=true;save_settings();refresh_layout_list()
	layout_note.text="已從配置庫移除；當前場地配置未改動。"
func show_target_markers()->void:
	if not practice_view or actors.size()!=8:return
	marker_target.select(player);marker_popup.popup_centered(Vector2i(320,450))
func apply_target_marker(target:int,marker:String)->void:
	if not running or paused or not practice_view or player in state.get("dead",[]):return
	var result:=Markers.assign(state,target,marker,player)
	if is_instance_valid(marker_note):marker_note.text="已清除" if result.ok and marker=="" else ("已上標："+Markers.title(marker) if result.ok else str(result.reason))
	arena.update_state(actors,current,player,answers_visible(),elapsed,state);sync_party_status_hud()
func next_self_marker()->void:
	if not running or paused or not practice_view or player in state.get("dead",[]):return
	var result:=Markers.next_attack(state,player)
	if not result.ok:marker_note.text=str(result.reason)
	arena.update_state(actors,current,player,answers_visible(),elapsed,state);sync_party_status_hud()
func show_waymark_settings()->void:
	if practice_view:open_practice_settings()
	set_layout_draft(waymark_layout);waymark_dialog.popup_centered(Vector2i(860,610))
func apply_waymark_settings()->void:
	var checked:=Markers.validate_layout(JSON.parse_string(waymark_text.text))
	if not checked.ok:status.text="場地配置未變更："+str(checked.reason);return
	if running or not encounter.is_empty():
		var archive:=FileAccess.open("user://before-waymark-change-%d.json"%Time.get_ticks_msec(),FileAccess.WRITE)
		if archive:archive.store_string(JSON.stringify(json_safe(report()),"  "))
	waymark_layout=checked.layout;save_settings()
	if running or not encounter.is_empty():
		demo=false;start_run();open_practice_settings()
	arena.set_waymarks(waymark_layout)
	status.text="場地標記已儲存"+"；已重開練習，請回到練習繼續。" if running else "場地標記已儲存"
