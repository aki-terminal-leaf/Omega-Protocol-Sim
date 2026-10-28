extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Observer=preload("res://tests/hw_later_public_observer.gd")
const E=preload("res://scripts/encounters.gd")
const C=preload("res://scripts/hw_courses.gd")
const R=preload("res://scripts/rules.gd")
const I=preload("res://scripts/interactions.gd")
const L=preload("res://scripts/hw_later_observation.gd")
var checks:=0
var failures:Array=[]
var rows:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr("LATER MAIN FAIL ",label)
func choose(app):
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(0)
 for n in app.filtered.size():
  if app.filtered[n].id=="p3_hello":app.choose_mechanic(n);app.strategy_select.select(1);app.choose_strategy(1);break
 app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
func install(app,r:int,mode:String,angle:int=0):
 var ctx=E.new();ctx.profile={"id":"elemental"};ctx.order=range(8);ctx.positions=[];ctx.labels=[]
 for a in 8:ctx.positions.append(R.direction(a*45.0)*5.0);ctx.labels.append("")
 var angles:Array=[0,0,0,0];angles[r]=angle;C.append_family(ctx,angles,"red")
 app.encounter.beats=ctx.beats;app.encounter.assignments=ctx.order;app.index=0;app.demo=true;app.player=0
 app.state=app.new_state();app.actors=[];app.running=true;app.paused=false;app.all_errors=[];app.journal=[];app.samples=[];app.retry_history=[];app.beat_passed=0;app.beat_failed=0
 app.observation_mode=mode;app.diagnostic_round=r;app.altered_frames=0;app.speed_select.select(2);app.begin_beat(true)
func advance(app,to:float):
 var n:=0
 while app.running and float(app.state.sim_time)<to-.000001 and n<2000:
  app._process(minf(.1,to-float(app.state.sim_time)));n+=1
 check(absf(float(app.state.sim_time)-to)<.00001,"reached %.3f"%to)
func entry(app,r:int)->Dictionary:return app.state.hw.get("later_public",{}).get("rounds",{}).get(str(r),{})
func receipt(app,r:int):
 var cache=app.state.hw.get("later_public",null)
 return L._receipt(cache,r,float(app.state.sim_time)) if cache is Dictionary else null
func goals(app)->Array:
 var shadow:Dictionary=app.state.duplicate(true);var result:Array=[]
 for a in 8:result.append(I.bot_goal(a,app.current.duplicate(true),app.actors.duplicate(true),shadow))
 return result
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Scene.instantiate();app.set_script(Observer)
 var scene_state=Scene.get_state()
 for k in scene_state.get_node_property_count(0):
  var name=scene_state.get_node_property_name(0,k)
  if name!="script":app.set(name,scene_state.get_node_property_value(0,k))
 root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false);choose(app)
 for r in [1,2,3]:
  var at:float=24.0+21.0*float(r)
  var ordinary:Dictionary={}
  for mode in ["normal","withheld","contradictory","late_conflict"]:
   install(app,r,mode);advance(app,at-10.1)
   check(receipt(app,r)==null,"no future receipt r%d %s"%[r,mode])
   check(app.arena.visible_damage_shapes.filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower").is_empty(),"no shown future towers")
   if mode=="normal":ordinary={"poses":app.actors.duplicate(true),"goals":goals(app)}
   advance(app,at-9.9)
   var actual:Array=app.arena.visible_damage_shapes.filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower")
   check(actual.size()==4,"actual Arena has four towers for every intervention")
   var rec=receipt(app,r)
   if mode=="withheld":check(rec==null,"withheld must not create receipt")
   else:
    check(rec is Dictionary and rec.source_kind=="arena_presented" and not rec.assisted,"actual channel provenance")
    if rec is Dictionary:check(int(rec.orientation)==(2 if mode=="contradictory" else 0),"goals use delivered geometry, not hidden answer")
   advance(app,at-8.8)
   if mode=="late_conflict":check(receipt(app,r)==null and not str(entry(app,r).get("blocked","")).is_empty(),"later contradiction retracts observation")
   advance(app,at+.05)
   var towers:Array=app.state.hw.history.filter(func(e):return e.get("kind","")=="hw_tower" and int(e.get("round",-1))==r)
   check(towers.size()==4,"four actual tower judgments")
   if mode=="normal":check(towers.all(func(e):return e.hits.size()==1) and app.state.runtime_failures.is_empty() and app.state.dead.is_empty() and app.all_errors.is_empty(),"normal public-source actual judgments pass r%d"%r)
   elif mode=="contradictory":
    check(app.state.runtime_failures.is_empty(),"wrong colour has no immediate tower failure r%d"%r)
    check(app.state.statuses.any(func(s):return s.has("latent_red") or s.has("latent_blue")),"wrong colour has actual pending latent defect r%d"%r)
    advance(app,at+10.05)
    check(app.state.runtime_failures.any(func(f):return "latent_red expired" in str(f) or "latent_blue expired" in str(f)),"wrong colour reaches actual latent expiry r%d"%r)
    check(app.altered_frames>0,"contradictory public channel was actually altered r%d"%r)
   else:check(not app.state.runtime_failures.is_empty() and app.altered_frames>0,"altered channel cannot be rescued by hidden goals r%d %s"%[r,mode])
   rows.append({"round":r,"mode":mode,"tower_hits":towers.map(func(e):return e.hits),"actual_failures":app.state.runtime_failures.duplicate(),"blocked":entry(app,r).get("blocked",""),"altered_frames":app.altered_frames})
  # Same whole past, different unrevealed future: compare actual poses/goals.
  for angle in [2,7]:
   install(app,r,"normal",angle);advance(app,at-10.1)
   check(app.actors==ordinary.poses and goals(app)==ordinary.goals,"pre-reveal actor/goal differential r%d angle%d"%[r,angle])
  install(app,r,"normal");advance(app,at-9.5)
  check(receipt(app,r) is Dictionary,"retry fixture observed before rollback")
  app.paused=true;var saved:Dictionary=app.state.duplicate(true);app._process(.5);check(app.state==saved,"paused receipt/state unchanged");app.paused=false
  app.retry_beat();check(receipt(app,r)==null,"retry before reveal clears future receipt")
  advance(app,at-9.9)
  check(app.state.get("hw_firstwave_presentation_required",false),"retry retains actual presentation requirement")
  check(receipt(app,r) is Dictionary and receipt(app,r).source_kind=="arena_presented" and not receipt(app,r).assisted,"retry reveal uses actual public channel")
  app.demo=false;app.start_run(0,false);check(not app.state.hw.has("later_public") or app.state.hw.later_public.rounds.is_empty(),"fresh run removes all later observations")
 app.queue_free();await process_frame
 print("HW_LATER_PUBLIC_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows,"scope":"controlled Elemental all-NPC actual Main/Arena publication-channel intervention; normal physical outcomes and deliberately withheld/incorrect signals; no ordinary human/native/Web/full-guide certification"}))
 quit(0 if failures.is_empty() else 1)
