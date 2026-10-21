extends SceneTree
const Main=preload("res://scenes/main.tscn")
var cases:=0
var failures:=0
var maximum_speed:=0.0
var started:=0

func _initialize() -> void: call_deferred("run")

func execute(app, scenario:String, method:int, seed_value:int, override:Dictionary={}) -> bool:
 var chosen: int=-1
 for i in app.filtered.size():
  if app.filtered[i].id==scenario:chosen=i;break
 if chosen<0:print("WALK FAIL missing scenario ",scenario);failures+=1;return false
 app.choose_mechanic(chosen);app.strategy_select.select(method);app.choose_strategy(method)
 for key in override:app.active_profile[key]=override[key]
 app.seed_edit.text=str(seed_value);app.speed_select.select(2);app.demo=true;app.start_run();app.stop_failure.button_pressed=false
 if not app.running:print("WALK FAIL did not start ",scenario);failures+=1;return false
 var ticks:=0;var peak:=0.0
 while app.running and ticks<1000:
  var before:Array=app.actors.duplicate(true)
  # Resolve_beat applies the explicitly modeled instantaneous knockback.
  # It is not walking and cannot be divided by the frame's walking budget.
  var knockback:bool=app.current.has("knockback") and app.elapsed+0.200001>=float(app.current.duration)
  app._process(0.2);ticks+=1
  if not knockback:
   for actor in 8:
    peak=maxf(peak,before[actor].pos.distance_to(app.actors[actor].pos)/0.2)
 maximum_speed=maxf(maximum_speed,peak);cases+=1
 if app.running or ticks==0 or not app.all_errors.is_empty() or peak>6.0003:
  print("WALK FAIL ",scenario," method",method," seed",seed_value," forced",override," peak",peak," errors",app.all_errors);failures+=1;return false
 if cases%32==0:print("WALK PROGRESS cases=",cases," failures=",failures," peak=",maximum_speed)
 return true

func end(app) -> void:
 print("WALKING_RESULT cases=",cases," failures=",failures," max_ordinary_speed=",maximum_speed," elapsed_ms=",Time.get_ticks_msec()-started)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var f=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
   if f:f.store_string(JSON.stringify({"cases":cases,"failures":failures,"max_ordinary_speed":maximum_speed,"milliseconds":Time.get_ticks_msec()-started}))
 app.queue_free();await process_frame;quit(1 if failures else 0)

func run() -> void:
 started=Time.get_ticks_msec();var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
 # Actual Main: all32 source clone families ×five offered Synergy methods
 # ×two deterministic allocations (320 courses), then all six monitor methods
 # ×three allocations (18). No route-goal teleport or boosted bot speed.
 for method in range(1,6):
  for seed_value in [17391,7]:
   for sword in [false,true]:
    for legs in [false,true]:
     for orientation in 8:
      if not execute(app,"p2_synergy",method,seed_value,{"p2_sword":sword,"p2_legs":legs,"p2_clone_angle":22.5+45*orientation}):await end(app);return
      await process_frame
 for method in range(1,7):
  for seed_value in [17391,7,43]:
   if not execute(app,"p3_monitors",method,seed_value):await end(app);return
   await process_frame
 if cases!=338 or maximum_speed<5.99:failures+=1;print("WALK FAIL incomplete coverage or unexercised movement")
 await end(app)
