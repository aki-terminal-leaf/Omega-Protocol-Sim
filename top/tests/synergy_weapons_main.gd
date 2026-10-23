# SPDX-License-Identifier: MIT
extends SceneTree
## P2 Party Synergy dodge on actual Main: NPCs steer only from the arena's
## rendered physical-part receipt; human uses Input.parse_input_event WASD.
## Candidate headless gate only; not native/manual/Web/full-P2/full-guide.
## Args: --require-official, --smoke, --batch=positive|negative|all.
const Main=preload("res://scenes/main.tscn")
const R=preload("res://scripts/rules.gd")
const SW=preload("res://scripts/synergy_weapons.gd")
const Clones=preload("res://scripts/clone_patterns.gd")
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
const DODGE:="Party Synergy · double AOEs"
const STOP:=13.45
var checks:=0
var failures:=0
var rows:Array=[]
var held:Dictionary={}
var require_official:=false
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("SYNERGY WEAPONS MAIN FAIL ",label)
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
func scan(shapes:Array)->Vector2:
	for y in range(-16,17):
		for x in range(-16,17):
			var p:=Vector2(x,y)
			if p.length()>17:continue
			var ok:=true
			for s in shapes:
				if R.contains(s,p,[]):ok=false
			if ok:return p
	return Vector2.ZERO
func choose(app,profile:String,angle:float,sword:bool,legs:bool)->bool:
	keys([]);app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(0)
	app.seed_edit.text="17391"
	var found:=false
	for n in app.filtered.size():
		if app.filtered[n].id=="p2_synergy":
			app.choose_mechanic(n)
			for s in range(1,app.strategy_select.item_count):
				var meta:Variant=app.strategy_select.get_item_metadata(s)
				if meta is Dictionary and str(meta.get("profile",""))==profile:
					app.strategy_select.select(s);app.choose_strategy(s);found=true;break
			break
	check(found,"%s strategy found"%profile)
	if not found:return false
	app.active_profile["p2_eye_angle"]=0.0;app.active_profile["p2_clone_angle"]=angle
	app.active_profile["p2_sword"]=sword;app.active_profile["p2_legs"]=legs;app.active_profile["p2_remote"]=false
	app.demo=false;app.fresh_seed.button_pressed=false;app.start_run(0,false);app.stop_failure.button_pressed=false
	app.reset_camera();var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	check(not app.demo and int(app.state.human_actor)==0 and not app.checkpoint_assisted,"ordinary human0, no demo/checkpoint")
	return found
func dodge_index(app)->int:
	for k in app.encounter.beats.size():
		if str(app.encounter.beats[k].title)==DODGE:return k
	return -1
## Test-side public decode of what the arena rendered (same public input as NPCs).
func rendered_safe(obs:Array)->Variant:
	var seen:=SW.classify(obs)
	if not seen.ok:return null
	return scan(Clones.pair_shapes(SW.angle_of(seen.m),seen.sword,seen.legs))
func set_parts(node:Node,on:bool)->void:
	if node is MeshInstance3D and (str(node.name).contains("atr_parts_a") or str(node.name).contains("atr_parts_b")):node.visible=on
	for c in node.get_children():set_parts(c,on)
## variant: ""(positive) | removed | swap | both ; human: correct|wrong|hold|release
func exercise(app,profile:String,angle:float,sword:bool,legs:bool,variant:String="",human:String="correct")->void:
	if not choose(app,profile,angle,sword,legs):return
	var k:=dodge_index(app)
	check(k>=0 and app.encounter.beats[k].has("synergy_weapon_public"),"dodge carries public metadata")
	if k<0:return
	var dodge_beat:Dictionary=app.encounter.beats[k]
	var meta_before:=JSON.stringify(dodge_beat.synergy_weapon_public);var shapes_before:=JSON.stringify(dodge_beat.shapes)
	var true_safe:=scan(Clones.pair_shapes(angle,sword,legs))
	# Rendered-variant negatives change only the clone display entity, never shapes/meta.
	for e in dodge_beat.stage_entities:
		var id:=str(e.get("id",""))
		if variant in ["removed","both"] and id in ["helper_m","helper_f"]:e.stance="NEUTRAL"
		if variant=="swap" and id=="helper_m":e.stance="SHIELD" if sword else "SWORD"
	var appear_neutral:=true;var appear_seen:=false;var first_receipt:Variant=null;var first_basis:=""
	var official_observations:=0;var official_all:=true;var npc_start:Array=[];var human_start:=Vector2.ZERO;var human_moved_without_keys:=0.0
	var released:=false;var release_pose:=Vector2.ZERO;var release_drift:=0.0;var safe:Variant=null;var frames:=0
	var receipt_ever:=false;var injected:=false;var blocked_seen:=false;var post_block:Array=[]
	while float(app.state.sim_time)<STOP-.000001 and app.running and frames<4000:
		var title:=str(app.current.get("title",""))
		if title.begins_with("Party Synergy · two M"):
			for i in app.arena.stage_nodes.size():
				if not (str(app.current.stage_entities[i].get("id","")) in ["helper_m","helper_f"]):continue
				var obs:Array=app.arena.observe_weapon_nodes([app.arena.stage_nodes[i]])
				appear_seen=appear_seen or not obs.is_empty()
				for o in obs:
					if str(o.weapon)!="":appear_neutral=false
		var at_dodge:=title==DODGE
		if at_dodge:
			if npc_start.is_empty():
				for i in 8:npc_start.append(R.v(app.actors[i].pos))
				human_start=R.v(app.actors[0].pos)
				if variant=="both":
					for i in app.arena.stage_nodes.size():
						if str(app.current.stage_entities[i].get("id","")) in ["helper_m","helper_f"]:set_parts(app.arena.stage_nodes[i],true)
			for o in app.arena.synergy_weapon_observations:
				official_observations+=1;official_all=official_all and bool(o.official)
			var r:=SW.receipt(app.current,app.state)
			if not r.is_empty():
				receipt_ever=true
				if first_receipt==null:first_receipt=r.duplicate(true);first_basis=str(r.basis)
			if variant in ["both_after","removed_after"] and receipt_ever and not injected:
				for i in app.arena.stage_nodes.size():
					if str(app.current.stage_entities[i].get("id","")) in ["helper_m","helper_f"]:set_parts(app.arena.stage_nodes[i],variant=="both_after")
				injected=true
			if str(app.state.get(SW.KEY,{}).get("blocked",""))=="contradiction":
				blocked_seen=true
				if post_block.is_empty():
					for i in 8:post_block.append(R.v(app.actors[i].pos))
			if safe==null:safe=rendered_safe(app.arena.synergy_weapon_observations)
		var now:=float(app.state.sim_time)
		if not at_dodge or human=="hold":keys([])
		elif human=="release" and now>11.0:
			if not released:released=true;keys([]);release_pose=R.v(app.actors[0].pos)
		elif human=="wrong":steer(app,Vector2(R.direction(angle)*10.0) if sword else -R.direction(angle)*10.0+R.direction(angle)*2.0)
		elif human=="truth":steer(app,true_safe)
		elif safe!=null:steer(app,safe)
		else:keys([])
		var before:=R.v(app.actors[0].pos);var pressed:=KEYS.any(func(c):return Input.is_physical_key_pressed(c))
		app._process(minf(.025,STOP-now));frames+=1
		if not pressed:human_moved_without_keys=maxf(human_moved_without_keys,before.distance_to(R.v(app.actors[0].pos)))
		if released:release_drift=maxf(release_drift,R.v(app.actors[0].pos).distance_to(release_pose))
	keys([])
	var snaps:Array=app.journal.filter(func(e):return str(e.title)==DODGE)
	var fails:Array=[]
	for s in snaps:fails.append_array(s.failures)
	var npc_end:Array=[]
	var judged_actors:Array=snaps[0].get("actors",[]) if snaps.size()==1 else []
	check(judged_actors.size()==8,"eight actual dodge snapshot actors")
	if judged_actors.size()!=8:return
	for i in 8:npc_end.append(R.v(judged_actors[i].pos))
	var human_damage_free:bool=dodge_beat.shapes.all(func(shape):return not R.contains(shape,npc_end[0],judged_actors))
	var human_failures:Array=fails.filter(func(f):return str(f).begins_with(str(judged_actors[0].role)+":"))
	var npc_failures:Array=fails.filter(func(f):return range(1,8).any(func(i):return str(f).begins_with(str(judged_actors[i].role)+":")))
	var npcs_at_true:=range(1,8).all(func(i):return (npc_end[i] as Vector2).distance_to(true_safe)<.05)
	var npcs_held:=npc_start.size()==8 and range(1,8).all(func(i):return (npc_end[i] as Vector2).distance_to(npc_start[i])<.000001)
	check(snaps.size()==1,"actual dodge snapshot judged [%s]"%profile)
	check(JSON.stringify(dodge_beat.synergy_weapon_public)==meta_before and JSON.stringify(dodge_beat.shapes)==shapes_before,"metadata/hazards unchanged by test")
	check(appear_seen and appear_neutral,"no weapon tell at neutral pre-reveal")
	check(human_moved_without_keys<.000001,"human never moved by bot path without keys")
	check(KEYS.all(func(c):return not Input.is_physical_key_pressed(c)),"keys released")
	if require_official:check(official_all and official_observations>0,"original official physical parts required")
	if variant=="":
		check(first_basis==SW.DISPLAYED,"displayed physical basis")
		check(npcs_at_true,"NPCs reach source-baseline safe from rendered cue")
		if human=="correct":check(fails.is_empty() and app.state.dead.is_empty(),"real dodge success %s %s"%[profile,str(fails.slice(0,3))])
		if human=="wrong":check(not fails.is_empty(),"wrong human dodge actually fails")
		if human=="release":check(released and release_drift<.000001,"released pose held")
	elif variant in ["removed","both"]:
		check(not receipt_ever and npcs_held,"%s tells: no receipt, NPCs hold"%variant)
	elif variant=="both_after":
		check(receipt_ever and injected and blocked_seen and post_block.size()==8,"actual both-visible after receipt revokes memory")
		check(post_block.size()==8 and range(1,8).all(func(i):return (npc_end[i] as Vector2).distance_to(post_block[i])<.000001),"NPCs hold actual pose after contradiction, not old target")
	elif variant=="removed_after":
		check(receipt_ever and injected and not blocked_seen and npcs_at_true,"genuine physical cue disappearance retains observed past")
	elif variant=="swap":
		check(first_basis==SW.DISPLAYED and first_receipt!=null and bool(first_receipt.sword)!=sword,"route follows wrong rendered cue")
		# Human stands on the true safe spot, so failures come from wrong-cue NPCs.
		check(human_damage_free and human_failures.is_empty() and not npcs_at_true and not npc_failures.is_empty(),"real judgment fails, no hidden rescue %s"%str(fails.slice(0,3)))
	var row:={"profile":profile,"angle":angle,"sword":sword,"legs":legs,"variant":variant,"human":human,"basis":first_basis,"receipt_ever":receipt_ever,"blocked_seen":blocked_seen,"injected":injected,"official_all":official_all,"human_damage_free":human_damage_free,"human_failures":human_failures,"npc_failures":npc_failures,"human_judged_pos":[npc_end[0].x,npc_end[0].y],"true_safe":[true_safe.x,true_safe.y],"failures":fails.slice(0,6),"frames":frames}
	rows.append(row);print("SYNERGY_WEAPONS_MAIN_COURSE ",JSON.stringify(row))
func _initialize()->void:call_deferred("run")
func run()->void:
	var args:=OS.get_cmdline_user_args()
	require_official="--require-official" in args
	var batch:="all"
	for a in args:
		if str(a).begins_with("--batch="):batch=str(a).substr(8)
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
	var profiles:=["elemental","aether","lpdu","cn_moogle","kr_09stop"]
	if "--smoke" in args:
		exercise(app,"cn_moogle",22.5,true,true)
	else:
		if batch in ["all","positive"]:
			var n:=0
			for sword in [true,false]:
				for legs in [true,false]:
					for angle in [22.5,157.5]:
						exercise(app,profiles[n%5],angle,sword,legs);n+=1
		if batch in ["all","negative"]:
			exercise(app,"kr_09stop",67.5,true,false,"removed","hold")
			exercise(app,"lpdu",22.5,true,true,"swap","truth")
			exercise(app,"aether",112.5,false,true,"both","hold")
			exercise(app,"elemental",22.5,true,true,"","wrong")
			exercise(app,"cn_moogle",202.5,false,false,"","release")
			exercise(app,"cn_moogle",22.5,true,true,"both_after","truth")
			exercise(app,"kr_09stop",157.5,false,true,"removed_after","truth")
	keys([]);app.queue_free();await process_frame
	print("SYNERGY_WEAPONS_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures==0 and checks>0,"courses":rows.size(),"batch":batch,"require_official":require_official,"rows":rows,"scope":"candidate actual Main headless, P2 Party Synergy dodge only, seed17391 eye0, human0 physical WASD; NPC legacy single-point grid endpoint; not native/manual/Web/full-P2/full-guide; LPDU6 group-side and sourceUnknown OPEN"}))
	quit(1 if failures or checks==0 else 0)
