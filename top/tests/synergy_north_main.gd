# SPDX-License-Identifier: MIT
extends SceneTree
## Actual Main, actual built-body display and physical WASD. Current simulator
## geometry only; driver reuses public preparation math, not full-guide proof.
const Main=preload("res://scenes/main.tscn")
const N=preload("res://scripts/synergy_north.gd")
const P=preload("res://scripts/synergy_preparation.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
var checks:=0
var failures:=0
var rows:Array=[]
var held:Dictionary={}
var require_official:=false
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("SYNERGY NORTH MAIN FAIL ",label)
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
func choose(app,profile:String,remote:bool,human:int)->void:
 keys([]);app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 var found:=false
 for k in app.filtered.size():
  if app.filtered[k].id!="p2_synergy":continue
  app.choose_mechanic(k)
  for s in range(1,app.strategy_select.item_count):
   var meta:Variant=app.strategy_select.get_item_metadata(s)
   if meta is Dictionary and str(meta.get("profile",""))==profile:
    app.strategy_select.select(s);app.choose_strategy(s);found=true;break
  break
 check(found,"strategy "+profile)
 app.seed_edit.text="17391";app.fresh_seed.button_pressed=false
 app.active_profile["p2_late_f_angle"]=90.0;app.active_profile["p2_remote"]=remote
 app.active_profile["p2_eye_angle"]=0.0;app.active_profile["p2_clone_angle"]=22.5
 app.demo=false;app.arena.visible=true;app.start_run(0,false);app.stop_failure.button_pressed=false
 app.reset_camera();var focus=app.get_viewport().gui_get_focus_owner()
 if focus:focus.release_focus()
 check(not app.demo and not app.checkpoint_assisted and int(app.state.human_actor)==human,"ordinary human ownership")
func phase(app)->String:return str(app.current.get("synergy_public",{}).get("phase",""))
func body_only_off(node:Node)->void:
 if node is MeshInstance3D:
  var name_s:=str(node.name)
  if not name_s.contains("atr_parts_a") and not name_s.contains("atr_parts_b"):node.visible=false
 for c in node.get_children():body_only_off(c)
func mutate(app,variant:String,past:bool)->void:
 var males:Array=[]
 for node in app.arena.stage_nodes:
  var official:bool=bool(node.get_meta("official_model",false))
  var form:String=str(node.get_meta("model_form","")) if official else str(node.get_meta("fallback_form",""))
  if not (form.begins_with("male") or form.begins_with("female")):continue
  if form.begins_with("male"):males.append(node)
  var holder:String="GameMesh" if official else "Body"
  if variant=="body_hidden" or (variant=="removed_after" and past):
   if node.has_node(holder):node.get_node(holder).visible=false
  if variant=="weapon_only" and node.has_node(holder):body_only_off(node.get_node(holder))
  if variant=="changed_before" or (variant=="changed_after" and past):
   var p3:Vector3=node.global_position;var p2:=Vector2(p3.x,p3.z).rotated(PI/2.0);node.global_position=Vector3(p2.x,p3.y,p2.y)
 if variant=="duplicate_after" and past and males.size()>=2:males[1].global_position=males[0].global_position
 app.arena.synergy_north_observations=app.arena.observe_north_bodies(app.arena.stage_nodes)
 app.publish_observed_cues()
func exercise(app,profile:String,remote:bool,human:int,variant:String="")->void:
 choose(app,profile,remote,human)
 var truth_before:String=JSON.stringify(app.json_safe(app.encounter))
 var first:Dictionary={};var official_count:=0;var official_all:=true
 var past:=false;var blocked:=false;var held_seen:=false;var staging:=false
 var frames:=0;var pressed:=false;var max_walk_excess:=0.0;var no_keys_drift:=0.0
 var released:=false;var released_pose:=Vector2.ZERO;var release_drift:=0.0;var knock_impulses:=0
 while app.running and float(app.state.sim_time)<32.0-.000001 and frames<5000:
  var ph:=phase(app);var now:float=float(app.state.sim_time)
  var receipt:Dictionary=N.receipt(app.current,app.state)
  if not receipt.is_empty():
   past=true
   if first.is_empty():first=receipt.duplicate(true)
  if ph=="knock" and float(app.elapsed)<2.65:
   staging=staging or range(8).all(func(a):return I.bot_goal(a,app.current,app.actors,app.state).length()<.00001)
  var cache:Dictionary=app.state.get(N.KEY,{})
  blocked=blocked or str(cache.get("blocked",""))!=""
  if ph=="knock" and float(app.elapsed)>2.75 and receipt.is_empty():
   held_seen=range(8).filter(func(a):return a!=human).all(func(a):return I.bot_goal(a,app.current,app.actors,app.state).distance_to(R.v(app.actors[a].pos))<.000001)
  if variant=="release" and ph=="knock" and float(app.elapsed)>2.6:
   if not released:released=true;released_pose=R.v(app.actors[human].pos)
   keys([])
  elif variant in ["body_hidden","weapon_only","changed_after","duplicate_after","changed_before"] and ph in ["knock","stack","blades"]:keys([])
  elif ph in ["cast","remember"] and profile=="aether":steer(app,Vector2(-6.3,0))
  else:steer(app,I.bot_goal(human,app.current,app.actors,app.state))
  var any_key:bool=KEYS.any(func(c):return Input.is_physical_key_pressed(c));pressed=pressed or any_key
  var pos:Vector2=R.v(app.actors[human].pos)
  # Suppress the unmodified frame before injecting a DISPLAY-ONLY variant.
  # Actual mesh nodes are then mutated/observed; recipes/hazards stay fixed.
  var controlled:bool=variant in ["body_hidden","weapon_only","removed_after","changed_before","changed_after","duplicate_after"] and ph=="knock"
  if controlled:app.arena.visible=false
  var journals_before:int=app.journal.size()
  var dt:=minf(.025,32.0-now);app._process(dt);frames+=1
  var impulse:bool=app.journal.size()>journals_before and str(app.journal[-1].title).begins_with("Discharger")
  var measured:Vector2=R.v(app.actors[human].pos)
  if impulse:
   knock_impulses+=1
   # Main applies the real13m radial impulse in judge(), sometimes before
   # advancing phase. Remove ONLY that known impulse from walk measurement.
   measured-=measured.normalized()*13.0
  if controlled and phase(app)=="knock":
   app.arena.visible=true;mutate(app,variant,past)
  else:app.arena.visible=true
  for o in app.arena.synergy_north_observations:
   official_count+=1;official_all=official_all and bool(o.get("official",false))
  if phase(app)==ph and ph not in ["stack"]:
   var step:float=pos.distance_to(measured)
   max_walk_excess=maxf(max_walk_excess,step-6.0*dt)
   if not any_key:no_keys_drift=maxf(no_keys_drift,step)
  if released and phase(app)=="knock" and not impulse:release_drift=maxf(release_drift,R.v(app.actors[human].pos).distance_to(released_pose))
 keys([]);app.arena.visible=true
 check(frames<5000 and float(app.state.sim_time)>=31.6,"actual post-Bladework clock reached")
 check(JSON.stringify(app.json_safe(app.encounter))==truth_before,"all generator truth/hazards/positions/metadata fixed")
 check(staging,"unconditional early centre staging retained")
 check(KEYS.all(func(c):return not Input.is_physical_key_pressed(c)),"physical keys released")
 check(no_keys_drift<.000004,"no human NPC rescue without keys")
 check(max_walk_excess<.00001,"actual WASD bounded walking speed")
 var judgments:Array=app.journal.filter(func(j):return str(j.title).begins_with("Discharger") or str(j.title).begins_with("Spotlight") or str(j.title).begins_with("Efficient Bladework"))
 check(judgments.size()==3,"actual Discharger/Spotlight/Bladework judgments, not goal-only")
 check(knock_impulses==1,"one actual radial knockback, separated from walking")
 if variant in ["body_hidden","weapon_only"]:
  check(first.is_empty() and held_seen,"missing physical bodies before first holds actual NPC poses")
 else:
  check(not first.is_empty() and str(first.get("basis",""))==N.DISPLAYED,"actual built-body displayed receipt")
  if require_official:check(official_all and official_count>0,"actual official body geometry")
 if variant in ["changed_after","duplicate_after"]:check(blocked and held_seen,"complete contradiction revokes and holds")
 if variant=="removed_after":check(not blocked and not first.is_empty(),"true physical disappearance remembers legitimate past")
 if variant=="changed_before":check(absf(N.angle_diff(float(first.get("north",NAN)),180.0))<.01,"changed public geometry follows public North while private90 fixed")
 if variant=="release":check(released and release_drift<.000001,"released human held without rescue; a legal released pose may legitimately pass")
 if variant=="":check(pressed,"actual physical WASD exercised")
 var errors:Array=[]
 for j in judgments:errors.append_array(j.failures)
 if variant=="":check(errors.is_empty(),"real late knock/stack/blade successful judgments")
 if variant in ["body_hidden","weapon_only","changed_before","changed_after","duplicate_after"]:check(not errors.is_empty(),"wrong/missing source or omitted human has actual judgment consequence")
 var row:={"profile":profile,"remote":remote,"human":human,"variant":variant,"frames":frames,"first":first,"blocked":blocked,"held_seen":held_seen,"official_count":official_count,"official_all":official_all,"judgments":app.json_safe(judgments),"judgment_failures":errors,"max_walk_excess":max_walk_excess,"no_keys_drift":no_keys_drift}
 rows.append(row);print("SYNERGY_NORTH_MAIN_COURSE ",JSON.stringify(row))
func _initialize()->void:call_deferred("run")
func run()->void:
 var args:=OS.get_cmdline_user_args();require_official="--require-official" in args
 var batch:="all"
 for a in args:
  if str(a).begins_with("--batch="):batch=str(a).substr(8)
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 if "--smoke" in args:exercise(app,"elemental",false,0)
 else:
  if batch in ["all","positive"]:
   for profile in ["elemental","aether","lpdu"]:
    for remote in [false,true]:exercise(app,profile,remote,0)
  if "--role-sample" in args and batch in ["all","positive"]:
   for human in range(1,8):exercise(app,"elemental",human%2==1,human)
  if batch in ["all","negative"]:
   for variant in ["body_hidden","weapon_only","removed_after","changed_before","changed_after","duplicate_after","release"]:exercise(app,"elemental",false,0,variant)
 keys([]);app.queue_free();await process_frame
 print("SYNERGY_NORTH_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"scope":"headless actual Main; built-body public receipt + physical input + actual late judgments; recorded judgment failures are NOT a successful full clear; current simulator geometry, human0/seed17391 only; not native/Web/manual/fullguide; optional seven extra Elemental role samples; all-profile/all-role Cartesian product and independent-driver coverage OPEN"}))
 quit(1 if failures or checks==0 else 0)
