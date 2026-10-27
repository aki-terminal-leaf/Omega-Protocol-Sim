extends SceneTree
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
var cases:Array=[]
var last_fingerprint:=""
func fingerprint(cues:Node3D)->String:
 var records:Array=[]
 for key in cues.effects:records.append([key,cues.effects[key].player.last_particles])
 return JSON.stringify(records)
func check(ok:bool,why:String)->void:
 checks+=1
 if not ok:failures+=1;print("WEAPON_BOUNDARY FAIL ",why)
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 app.arena.source_cues.experimental_effects=true # Explicit experimental renderer coverage.
 for i in app.filtered.size():
  if app.filtered[i].id=="p2_synergy":app.choose_mechanic(i)
 app.strategy_select.select(1);app.choose_strategy(1);app.fresh_seed.set_pressed_no_signal(false);app.hints.button_pressed=false
 for sword in [false,true]:
  for legs in [false,true]:
   app.active_profile.p2_sword=sword;app.active_profile.p2_legs=legs;app.seed_edit.text="42";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
   while float(app.state.sim_time)<13.6-0.000001:app._process(minf(.1,13.6-float(app.state.sim_time)))
   var cues=app.arena.source_cues;var ids:Array=[31526 if sword else 31525,31530 if legs else 31533]
   for id in ids:check(cues.emitted.filter(func(e):return int(e.ability)==id).size()==1,"actual Main crossing registers both actions exactly once: "+str(id))
   check(cues.retired_rigs.size()==2,"both removed helper rigs retained for bone/effect tails")
   for rig in cues.retired_rigs.values():
    check(rig.is_inside_tree() and not rig.is_visible_in_tree(),"retained rig is tree-valid but invisible")
    check(rig not in app.arena.stage_nodes,"retained rig excluded from NPC stage observation")
   check(cues.animations.size()==2,"both original PAP bindings survive actor-list transition")
   var textures:=0
   for effect in cues.effects.values():
    for draw in effect.player.draws.values():
     if draw.material_override is ShaderMaterial and draw.material_override.get_shader_parameter("tex0") is Texture2D:textures+=1
   check(textures>0,"source mask texture reaches actual drawn material")
   last_fingerprint=fingerprint(cues)
   var before:=JSON.stringify(cues.report());app.paused=true;app._process(.4)
   check(JSON.stringify(cues.report())==before,"actual Main pause does not advance source rigs/effects")
   app.paused=false
   while float(app.state.sim_time)<20.0-.000001:app._process(minf(.1,20-float(app.state.sim_time)))
   check(cues.retired_rigs.is_empty(),"source tail releases removed rigs after completion")
   cases.append({"sword":sword,"legs":legs,"drawn_texture_materials":textures,"errors":app.all_errors.duplicate()})
   check(app.all_errors.is_empty(),"modeled PT outcomes unchanged through laser")
 # Original short0.1s five-M beat must not rely on an update exactly at its end.
 while app.running and float(app.state.sim_time)<31.6-.000001:app._process(minf(.1,31.6-float(app.state.sim_time)))
 var late:Array=app.arena.source_cues.emitted.filter(func(e):return int(e.ability)==31526 and float(e.at)>30)
 check(late.size()==5,"all five M sword sources survive the short-beat transition")
 app.start_run(0,false)
 check(app.arena.source_cues.retired_rigs.is_empty() and app.arena.source_cues.effects.is_empty(),"R/new-run cleanup removes all old invisible rigs and particles")
 while float(app.state.sim_time)<13.6-.000001:app._process(minf(.1,13.6-float(app.state.sim_time)))
 check(fingerprint(app.arena.source_cues)==last_fingerprint,"same-seed R exactly repeats source particle keys, times, colors and transforms")
 var result:Dictionary={"checks":checks,"failures":failures,"cases":cases,"late_sword_sources":late.size(),"scope":"actual Main transitions, all four legal weapon combinations, source texture binding, pause and retry; not native visual fidelity"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--proof="):var f=FileAccess.open(arg.trim_prefix("--proof="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result));app.queue_free();await process_frame;quit(1 if failures else 0)
