# SPDX-License-Identifier: MIT
extends SceneTree
## Aether Party Synergy actual human horizontal rank + Optimized Fire III: actual Main,
## physical WASD via Input.parse_input_event. Candidate headless gate only;
## not native/manual/all-guide/full-P2 conformance. Driver reads only the
## actually displayed Arena glyph receipt and remembers it after icons vanish.
const Main=preload("res://scenes/main.tscn")
const R=preload("res://scripts/rules.gd")
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
const ORDINAL=["cross","square","circle","triangle"]
const STOP:=19.85
var checks:=0
var failures:=0
var rows:Array=[]
var held:Dictionary={}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("SYNERGY INPUT FAIL ",label)
func keys(wanted:Array):
 for code in KEYS:
  var down:bool=code in wanted
  if bool(held.get(code,false))==down:continue
  var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e);held[code]=down
 Input.flush_buffered_events()
func steer(app,target:Vector2):
 var d:Vector2=(target-R.v(app.actors[app.player].pos)).rotated(app.arena.camera_yaw)
 if d.length()<.10:keys([]);return
 var wanted:Array=[]
 if absf(d.x)>absf(d.y)*.4142:wanted.append(KEY_D if d.x>0 else KEY_A)
 if absf(d.y)>absf(d.x)*.4142:wanted.append(KEY_S if d.y>0 else KEY_W)
 keys(wanted)
func norm(symbol:String)->String:
 var s:=symbol.strip_edges().to_lower()
 match s:
  "o","circle","maru":return "circle"
  "x","cross","batsu":return "cross"
  "triangle","sankaku":return "triangle"
  "square","shikaku":return "square"
 return s
func phase(app)->String:
 var raw:Variant=app.current.get("synergy_public",null)
 return str(raw.get("phase","")) if raw is Dictionary else ""
func choose(app,human:int,remote:bool):
 keys([]);app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 app.seed_edit.text="17391"
 var found:=false
 for n in app.filtered.size():
  if app.filtered[n].id=="p2_synergy":
   app.choose_mechanic(n)
   for s in range(1,app.strategy_select.item_count):
    var meta:Variant=app.strategy_select.get_item_metadata(s)
    if meta is Dictionary and str(meta.get("profile",""))=="aether":
     app.strategy_select.select(s);app.choose_strategy(s);found=true;break
   break
 check(found,"Aether Party Synergy strategy found")
 # Controlled generated-profile overrides; Main.prepare rebuilds from active_profile.
 app.active_profile["p2_eye_angle"]=0.0;app.active_profile["p2_clone_angle"]=22.5;app.active_profile["p2_remote"]=remote
 app.demo=false;app.fresh_seed.button_pressed=false;app.start_run(0,false);app.stop_failure.button_pressed=false
 app.reset_camera();var focus=app.get_viewport().gui_get_focus_owner()
 if focus:focus.release_focus()
 check(not app.demo and int(app.state.human_actor)==human and not app.checkpoint_assisted and str(app.active_profile.get("id",""))=="aether","ordinary actual human, no demo/checkpoint")
## Independent derivation from remembered displayed glyphs only.
func derive(glyphs:Array,poses:Array,human:int)->Dictionary:
 var sym:Dictionary={}
 for g in glyphs:sym[int(g.actor)]=norm(str(g.symbol))
 var side:Dictionary={}
 for actor in 8:
  var mates:Array=range(8).filter(func(a):return a!=actor and sym.get(a,"")==sym.get(actor,""))
  if mates.size()!=1:return {}
  side[actor]=0 if R.v(poses[actor].pos).x<R.v(poses[mates[0]].pos).x else 1
 var rank:int=range(8).filter(func(a):return R.v(poses[a].pos).x<R.v(poses[human].pos).x).size()
 return {"symbol":str(sym.get(human,"")),"side":int(side.get(human,-1)),"sides":side,"actual_rank":rank,"capture":[float(poses[human].pos.x),float(poses[human].pos.y)]}
func fire_point(d:Dictionary,remote:bool,wrong:bool)->Vector2:
 var rank:int=ORDINAL.find(str(d.symbol));var right:bool=int(d.side)==1
 if wrong:right=not right
 var z:float=-12.0+rank*8.0
 var x:float=sqrt(18.0*18.0-z*z) if remote else 11.0
 # Aether Remote swaps OUTER rows only; inner Square/Circle remain.
 if right and remote and rank in [0,3]:z=-z
 return Vector2(x if right else -x,z)  # static eye 0 => identity rotation
func exercise(app,human:int,remote:bool,desired_rank:int,negative:String="",step_dt:float=.025):
 choose(app,human,remote)
 var spawn:Vector2=R.v(app.actors[human].pos)
 var memory:Array=[];var mark_seen:=-1.0;var d:Dictionary={};var dodge_base:Variant=null
 var pressed:=false;var max_excess:=0.0;var speed:=0.0;var frames:=0
 var released:=false;var release_pose:=Vector2.ZERO;var release_drift:=0.0;var fire_judged:=false;var glyphs_after_mark:=-1
 while float(app.state.sim_time)<STOP-.000001 and app.running and frames<20000:
  var now:float=float(app.state.sim_time);var ph:=phase(app)
  if memory.is_empty() and ph=="remember" and app.arena.synergy_displayed_glyphs.size()==8:
   memory=app.arena.synergy_displayed_glyphs.duplicate(true);mark_seen=now;d=derive(memory,app.actors,human)
  if ph in ["dodge","fire"] and glyphs_after_mark<0:glyphs_after_mark=app.arena.synergy_displayed_glyphs.size()
  if ph=="laser":fire_judged=true
  var hold:bool=negative=="omitted" or (negative=="release" and ph=="fire")
  if negative=="release" and ph=="fire" and not released:released=true;release_pose=R.v(app.actors[human].pos)
  if hold:
   keys([])
  elif d.is_empty() and ph in ["cast","remember"]:
   if negative=="stationaryprep":keys([])
   else:steer(app,Vector2((float(desired_rank)-3.5)*1.8,0))
  elif ph in ["remember","appear"]:
   keys([])
  elif ph=="dodge":
   # Shared old weapon baseline: does NOT certify weapon reading/source privacy.
   if dodge_base==null:dodge_base=R.v(app.current.positions[human])
   steer(app,dodge_base)
  elif ph=="fire":
   if negative=="late" and now<19.55:keys([])
   else:steer(app,fire_point(d,remote,negative=="wrong"))
  else:keys([])
  pressed=pressed or KEYS.any(func(k):return Input.is_physical_key_pressed(k))
  var before:Vector2=R.v(app.actors[human].pos);var dt:=minf(step_dt,STOP-now);app._process(dt)
  var step:float=before.distance_to(R.v(app.actors[human].pos))
  speed=maxf(speed,step/dt);max_excess=maxf(max_excess,step-6.0*dt)
  if released:release_drift=maxf(release_drift,R.v(app.actors[human].pos).distance_to(release_pose))
  frames+=1
 keys([])
 if phase(app)=="laser":fire_judged=true
 var fails:Array=app.state.runtime_failures.duplicate()
 var fire_snapshots:Array=app.journal.filter(func(e):return e.title=="Optimized Fire III")
 for snapshot in fire_snapshots:
  for error in snapshot.failures:
   if error not in fails:fails.append(error)
 check(fire_snapshots.size()==1,"actual Fire snapshot exists (not only continuous runtime failures)")
 var relevant:Array=fails.filter(func(f):var t:=str(f);return "Glitch" in t or "Fire" in t)
 check(frames<20000 and float(app.state.sim_time)>=STOP-.000001 and fire_judged,"reached post-Fire T19.85 before knock")
 check(memory.size()==8,"eight displayed glyph records remembered")
 var counts:Dictionary={}
 for g in memory:counts[norm(str(g.symbol))]=int(counts.get(norm(str(g.symbol)),0))+1
 check(counts.size()==4 and counts.values().all(func(c):return c==2) and ORDINAL.all(func(s):return counts.has(s)),"2 of each normalized glyph")
 check(glyphs_after_mark==0,"icons actually vanished after mark (memory kept)")
 check(max_excess<=0.000004 and float(app.sprint_left)==0 and float(app.dash_left)==0,"speed6 physical WASD, no abilities")
 check(KEYS.all(func(k):return not Input.is_physical_key_pressed(k)),"all physical keys released")
 check(not app.checkpoint_assisted and not app.state.get("synergy_checkpoint_assisted",false),"never checkpoint-assisted")
 if negative in ["","stationaryprep"]:
  check(fails.is_empty() and app.all_errors.is_empty() and app.state.dead.is_empty(),"real success human%d remote%s %s %s"%[human,remote,negative,str(fails.slice(0,4))])
  check(pressed,"actual physical input used")
 else:
  check(not relevant.is_empty(),"actual Glitch/Fire consequence for %s human%d %s"%[negative,human,str(fails.slice(0,4))])
  if negative=="omitted":check(R.v(app.actors[human].pos)==spawn,"omitted human never moved by NPC")
  if negative=="release":check(released and release_drift<.000001,"released human pose held, no NPC rescue")
 if negative=="":check(int(d.get("actual_rank",-1))==desired_rank,"actual human reached requested rank before first displayed glyphs")
 if negative=="stationaryprep":check(Vector2(float(d.capture[0]),float(d.capture[1])).distance_to(spawn)<.000001,"legal stationary preparation no forced movement")
 var row:Dictionary={"desired_rank":desired_rank,"actual_rank":d.get("actual_rank",-1),"human":human,"remote":remote,"negative":negative,"step_dt":step_dt,"mark_at":mark_seen,"glyphs":memory,"derived":d,"max_speed":speed,"max_walk_excess":max_excess,"failures":fails,"release_drift":release_drift,"fire_snapshots":fire_snapshots}
 rows.append(row);print("AETHER_INPUT_COURSE ",JSON.stringify(row))
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var smoke:bool="--smoke" in OS.get_cmdline_user_args()
 if smoke:
  exercise(app,0,false,0);exercise(app,0,false,7)
 else:
  for remote in [false,true]:
   for human in range(8):
    for desired_rank in range(8):exercise(app,human,remote,desired_rank)
  for negative in ["omitted","wrong","late","release"]:exercise(app,0,false,0,negative)
  exercise(app,0,true,7,"wrong")
  for human in range(8):exercise(app,human,false,-1,"stationaryprep")
 keys([]);app.queue_free();await process_frame
 var crossed:Array=[]
 print("AETHER_INPUT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows.size(),"crossed_positive_subset":crossed,"rows":rows,"scope":"candidate actual Main physical WASD headless, Aether actual8humanrank choice + Fire III only, all8roles/MidRemote, seed17391 eye0 clone22.5; dodge uses shared current.positions baseline (not weapon-read/source-privacy proof); not native/manual/all-guide/full-P2"}))
 quit(1 if failures else 0)
