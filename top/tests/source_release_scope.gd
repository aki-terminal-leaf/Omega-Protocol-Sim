extends SceneTree
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
var rows:Array=[]
var output:=""
var render_proof:=false
func check(ok:bool,why:String)->void:
 checks+=1
 if not ok:failures+=1;print("RELEASE_SCOPE FAIL ",why)
func _initialize()->void:call_deferred("run")
func advance(app:Node,to:float)->void:
 while float(app.state.sim_time)<to-.000001:app._process(minf(.05,to-float(app.state.sim_time)))
func capture(app:Node,name:String)->void:
 if not render_proof:return
 app.paused=true
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"save native "+name)
 app.paused=false
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg=="--render-proof":render_proof=true
 root.size=Vector2i(1280,800)
 if render_proof:DisplayServer.window_set_title("TOP 50277 — scoped release verification")
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for i in app.filtered.size():
  if app.filtered[i].id=="p2_synergy":app.choose_mechanic(i)
 app.strategy_select.select(1);app.choose_strategy(1);app.fresh_seed.set_pressed_no_signal(false);app.hints.button_pressed=false
 app.arena.set_overhead(true)
 var cues=app.arena.source_cues
 check(not cues.experimental_effects,"release defaults to no experimental source particles")
 check(not cues.catalog.is_empty(),"actual original resource catalog installed")
 var original_catalog:Dictionary=cues.catalog
 for sword in [false,true]:
  for legs in [false,true]:
   app.active_profile.p2_sword=sword;app.active_profile.p2_legs=legs;app.seed_edit.text="42";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
   advance(app,12.7);await capture(app,"%s-%s-before"%[sword,legs])
   advance(app,13.25)
   check(not cues.animations.is_empty(),"male source windup is actually bound before impact")
   var active_sampled:=false
   for item in cues.animations.values():
    if item.binding.get("active",false):active_sampled=true
   check(active_sampled,"source pose actually sampled on the visible source")
   check(cues.effects.is_empty(),"no unverified source particle instances before impact")
   await capture(app,"%s-%s-windup"%[sword,legs])
   var before:=JSON.stringify(cues.report());app.paused=true;app._process(.4)
   check(JSON.stringify(cues.report())==before,"pause freezes sampled source state")
   app.paused=false;advance(app,13.7)
   for id in [31526 if sword else 31525,31530 if legs else 31533]:
    check(cues.emitted.filter(func(e):return int(e.ability)==id).size()==1,"weapon admission is exactly once "+str(id))
   check(cues.effects.is_empty() and cues.retired_rigs.is_empty(),"no source particles or orphan invisible rigs after transition")
   await capture(app,"%s-%s-resolution"%[sword,legs])
   advance(app,20.0)
   check(app.all_errors.is_empty(),"actual modeled PT course unchanged through laser")
   check(cues.emitted.all(func(e):return int(e.ability) in [31525,31526,31530,31533]),"release owns weapon actions only")
   var actual_state:=JSON.stringify(app.state);var actual_actors:=JSON.stringify(app.actors)
   rows.append({"sword":sword,"legs":legs,"emitted":cues.emitted.duplicate(true),"errors":app.all_errors.duplicate(),"state_sha256":actual_state.sha256_text()})
   app.start_run(0,false)
   check(cues.effects.is_empty() and cues.animations.is_empty() and cues.retired_rigs.is_empty(),"same-seed retry releases all presentation ownership")
   cues.catalog={}
   # Use identical time-step boundaries: different subdivision changes float motion budgets.
   for time in [12.7,13.25]:advance(app,time)
   app.paused=true;app._process(.4);app.paused=false
   for time in [13.7,20.0]:advance(app,time)
   check(JSON.stringify(app.state)==actual_state and JSON.stringify(app.actors)==actual_actors,"presentation-enabled and presentation-disabled combat state/actors exactly match")
   cues.catalog=original_catalog
 var result:={"checks":checks,"failures":failures,"cases":rows,"rendered":render_proof,"mode":cues.report().presentation_mode,"scope":"actual Main default release mode, all four weapon combinations, source pose, pause/retry and identical combat state without source presentation"}
 if not output.is_empty():var f=FileAccess.open(output+"/scope.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result));app.queue_free();await process_frame;quit(1 if failures else 0)
