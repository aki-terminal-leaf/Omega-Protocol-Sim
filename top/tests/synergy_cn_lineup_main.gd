# SPDX-License-Identifier: MIT
extends SceneTree
## CN Moogle Party Synergy INITIAL cast lineup only: actual Main, ordinary UI
## profile selector, seed 17391, physical WASD via Input.parse_input_event.
## Candidate headless gate; NOT native OS/Web/manual acceptance. Stops before
## the 3.0s glyph boundary (except the KEY_R reset check).
const Main=preload("res://scenes/main.tscn")
const R=preload("res://scripts/rules.gd")
const Markers=preload("res://scripts/markers.gd")
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
const ROLES=["MT","ST","H1","H2","D1","D2","D3","D4"]
## Poster left->right (facing A), transcribed independently of the helper.
const POSTER=["H1","MT","ST","D1","D2","D3","D4","H2"]
const STOP:=2.95
const STEP:=0.025
var checks:=0
var failures:Array=[]
var rows:Array=[]
var held:Dictionary={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("CN LINEUP MAIN FAIL ",label)
func keys(wanted:Array)->void:
	for code in KEYS:
		var down:bool=code in wanted
		if bool(held.get(code,false))==down:continue
		var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e);held[code]=down
	Input.flush_buffered_events()
func steer(app,target:Vector2)->void:
	var d:Vector2=(target-R.v(app.actors[app.player].pos)).rotated(app.arena.camera_yaw)
	if d.length()<.10:keys([]);return
	var wanted:Array=[]
	if absf(d.x)>absf(d.y)*.4142:wanted.append(KEY_D if d.x>0 else KEY_A)
	if absf(d.y)>absf(d.x)*.4142:wanted.append(KEY_S if d.y>0 else KEY_W)
	keys(wanted)
func layout_a(a:Variant,enabled:bool=true)->Dictionary:
	var lay:Dictionary=Markers.default_layout()
	for m in lay.marks:
		if m.id=="A":m.pos=a;m.enabled=enabled
	return lay
## Expected slot from the poster and the public A only.
func slot(actor:int,a:Vector2)->Vector2:
	var f:Vector2=a.normalized();var right:=Vector2(-f.y,f.x)
	return right*((float(POSTER.find(ROLES[actor]))-3.5)*1.8)
func choose(app,human:int,layout:Dictionary)->void:
	keys([]);app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
	app.seed_edit.text="17391"
	var found:=false
	for n in app.filtered.size():
		if app.filtered[n].id=="p2_synergy":
			app.choose_mechanic(n)
			for s in range(1,app.strategy_select.item_count):
				var meta:Variant=app.strategy_select.get_item_metadata(s)
				if meta is Dictionary and str(meta.get("profile",""))=="cn_moogle":
					app.strategy_select.select(s);app.choose_strategy(s);found=true;break
			break
	check(found,"CN Moogle Party Synergy strategy found via ordinary selector")
	app.waymark_layout=layout.duplicate(true)
	app.demo=false;app.fresh_seed.button_pressed=false;app.start_run(0,false);app.stop_failure.button_pressed=false
	app.reset_camera();var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	check(not app.demo and int(app.state.human_actor)==human and not app.checkpoint_assisted and str(app.active_profile.get("id",""))=="cn_moogle","ordinary actual human h%d"%human)
	check(str(app.current.get("title",""))=="Party Synergy · cast" and float(app.state.sim_time)==0.0,"starts at CN cast beat")
## mode: join | none | wrong | release | invalid
func exercise(app,human:int,a:Vector2,mode:String,layout:Dictionary)->Dictionary:
	choose(app,human,layout)
	var spawn:Array=[]
	for i in 8:spawn.append(R.v(app.actors[i].pos))
	var neutral:=true
	for i in 8:
		var p:Vector2=spawn[i]
		if not spawn[i].is_equal_approx(R.v(app.current.spawn[i])) or absf(absf(p.x)-3.0)>0.0001:neutral=false
	check(neutral,"neutral two-column spawn preserved h%d %s"%[human,mode])
	check(spawn[human].distance_to(slot(human,a))>0.5 or mode=="invalid","human not spawned in solved slot h%d"%human)
	var target:Vector2=slot(human,a)
	if mode=="wrong":target=slot(int([3,2,0,1,7,6,5,4][human]),a)
	var max_excess:=0.0;var npc_speed:=0.0;var frames:=0;var pressed:=false
	var released:=false;var release_pose:=Vector2.ZERO;var drift:=0.0;var npc_drift:=0.0;var glyphs:=0
	while float(app.state.sim_time)<STOP-.000001 and app.running and frames<400:
		var now:float=float(app.state.sim_time)
		if mode in ["none","invalid"]:keys([])
		elif mode=="release" and now>=0.2:
			if not released:keys([]);released=true;release_pose=R.v(app.actors[human].pos)
		else:steer(app,target)
		pressed=pressed or KEYS.any(func(k):return Input.is_physical_key_pressed(k))
		var before:Array=[]
		for i in 8:before.append(R.v(app.actors[i].pos))
		var dt:=minf(STEP,STOP-now);app._process(dt)
		for i in 8:
			var step:float=before[i].distance_to(R.v(app.actors[i].pos))
			max_excess=maxf(max_excess,step-6.0*dt)
			if i!=human:npc_speed=maxf(npc_speed,step/dt);npc_drift=maxf(npc_drift,R.v(app.actors[i].pos).distance_to(spawn[i]))
		if released:drift=maxf(drift,R.v(app.actors[human].pos).distance_to(release_pose))
		glyphs=maxi(glyphs,app.arena.synergy_displayed_glyphs.size())
		frames+=1
	keys([])
	check(str(app.current.get("title",""))=="Party Synergy · cast" and float(app.state.sim_time)<3.0,"stopped inside cast before glyph boundary h%d %s"%[human,mode])
	check(max_excess<=0.00001 and float(app.sprint_left)==0 and float(app.dash_left)==0,"all actual steps within 6m/s h%d %s"%[human,mode])
	check(glyphs==0,"no glyphs displayed during cast h%d %s"%[human,mode])
	var final:Array=[]
	for i in 8:final.append(R.v(app.actors[i].pos))
	var npc_ok:=true
	for i in 8:
		if i!=human and final[i].distance_to(slot(i,a))>0.05:npc_ok=false
	var f:Vector2=a.normalized();var right:=Vector2(-f.y,f.x)
	var by_right:Array=range(8);by_right.sort_custom(func(x,y):return final[x].dot(right)<final[y].dot(right))
	var names:Array=by_right.map(func(x):return ROLES[x])
	var all_ok:bool=npc_ok and final[human].distance_to(slot(human,a))<=0.15 and names==POSTER
	var fails:Array=app.state.get("runtime_failures",[]).duplicate()
	check(fails.is_empty() and app.all_errors.is_empty() and app.state.get("dead",[]).is_empty(),"no staging HP/death/errors invented h%d %s"%[human,mode])
	match mode:
		"join":
			check(pressed and npc_ok and all_ok,"human joined; all 8 in poster order h%d %s"%[human,str(names)])
		"none":
			check(not pressed and final[human]==spawn[human],"no-input human never moved/rescued h%d"%human)
			check(npc_ok and not all_ok,"NPCs line up; row NOT completed without human h%d"%human)
		"wrong":
			check(pressed and npc_ok and not all_ok and final[human].distance_to(slot(human,a))>1.0,"wrong human slot not corrected h%d"%human)
		"release":
			check(released and drift<0.000001 and not all_ok,"released human stays put h%d"%human)
		"invalid":
			var distinct:=true
			for i in 8:
				for j in range(i+1,8):
					if final[i].distance_to(final[j])<0.5:distinct=false
			check(npc_drift<0.000001 and distinct,"invalid A: NPCs hold distinct actual poses h%d"%human)
	var row:Dictionary={"human":human,"mode":mode,"a":[a.x,a.y],"order":names,"all_ok":all_ok,"npc_ok":npc_ok,"npc_max_speed":npc_speed,"max_walk_excess":max_excess,"human_final":[final[human].x,final[human].y],"release_drift":drift,"npc_drift":npc_drift,"failures":fails}
	rows.append(row);print("CN_LINEUP_MAIN_COURSE ",JSON.stringify(row))
	return {"spawn":spawn,"future":JSON.stringify(app.encounter.beats.slice(1))}
func press_r(app)->void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_R;key.keycode=KEY_R;key.pressed=true;app._unhandled_key_input(key)
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
	var original_layout:Dictionary=app.waymark_layout.duplicate(true)
	var def_a:=Vector2(0,-13)
	var base:Dictionary={}
	for human in range(8):
		var r:=exercise(app,human,def_a,"join",Markers.default_layout())
		if human==0:base=r
	# KEY_R: same seed, neutral pose, no future glyphs.
	press_r(app)
	var same:=true
	for i in 8:
		if not R.v(app.actors[i].pos).is_equal_approx(base.spawn[i]):same=false
	check(same and float(app.state.sim_time)==0.0 and str(app.current.title)=="Party Synergy · cast" and app.encounter.seed==17391,"KEY_R returns same seed neutral poses")
	check(app.arena.synergy_displayed_glyphs.is_empty() and not app.current.has("party_statuses"),"KEY_R shows no future glyphs")
	for mode in ["none","wrong","release"]:exercise(app,0,def_a,mode,Markers.default_layout())
	# Rotated current public A (east and diagonal).
	for human in [2,5]:exercise(app,human,Vector2(13,0),"join",layout_a([13.0,0.0]))
	exercise(app,7,Vector2(-9.0,9.0),"join",layout_a([-9.0,9.0]))
	# Invalid public A: disabled / centre. NPCs hold; future truth unchanged.
	var dis:=exercise(app,0,def_a,"invalid",layout_a([0.0,-13.0],false))
	var ctr:=exercise(app,0,def_a,"invalid",layout_a([0.0,0.0]))
	check(dis.future==base.future and ctr.future==base.future,"public A choice does not change future beats")
	keys([]);app.waymark_layout=original_layout;app.queue_free();await process_frame
	print("CN_LINEUP_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows.size(),"rows":rows,"scope":"candidate actual Main headless physical WASD, CN cast initial lineup only, seed17391; not native/Web/manual; duplicate-pair side/Fire/late North untouched"}))
	quit(1 if not failures.is_empty() else 0)
