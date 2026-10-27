extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Pose=preload("res://scripts/source_animation.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,why:String)->void:
 checks+=1
 if not ok:failures.append(why)
func _initialize()->void:call_deferred("run")
func inspect_rig(node:Node)->void:
 check(not node is CollisionObject3D,"retained rig contains no physics body/area")
 check(node.get_groups().is_empty(),"retained rig has no gameplay groups")
 for child in node.get_children():inspect_rig(child)
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for i in app.filtered.size():
  if app.filtered[i].id=="p2_synergy":app.choose_mechanic(i)
 app.strategy_select.select(1);app.choose_strategy(1);app.fresh_seed.set_pressed_no_signal(false)
 app.active_profile.p2_sword=true;app.active_profile.p2_legs=true;app.seed_edit.text="42";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
 while float(app.state.sim_time)<13.35-.000001:app._process(minf(.05,13.35-float(app.state.sim_time)))
 var cues=app.arena.source_cues
 var restarted:Dictionary=app.state.duplicate(true);restarted.sim_time=13.4
 var before:=JSON.stringify(restarted)
 cues.snapshot(app.current,app.actors,restarted)
 cues.update(restarted,app.current,app.actors,float(app.current.duration))
 check(cues.emitted.filter(func(e):return int(e.ability)==31530).size()==1,"snapshot-first new-state zero-lead action survives update exactly once")
 check(JSON.stringify(restarted)==before,"source adapter does not mutate battle state")
 check(cues.emitted.all(func(e):return str(e.tmb_time_origin).begins_with("exact_resolution_fallback")),"fallback records honest timing origin")
 var old_ids:Array=[]
 for rig in app.arena.stage_nodes:
  if str(rig.get_meta("model_form","")) in ["male","female"]:
   old_ids.append(cues.source_identity(rig))
   if cues.retire_actor(rig):inspect_rig(rig)
 check(cues.retired_rigs.size()==2,"both source rigs retained")
 var new_ids:Array=[]
 for rig in cues.retired_rigs.values():new_ids.append(cues.source_identity(rig))
 check(new_ids.size()==2 and new_ids[0]!=new_ids[1],"retired rig identities distinct")
 for id in new_ids:check(id in old_ids,"retiring preserves source identity")
 for item in cues.animations.values():
  cues.sample_animations(float(item.end)+.001)
  check(item.get("frozen",false),"PAP final pose retained while bound effect remains")
 cues.clear()
 check(cues.retired_rigs.is_empty() and cues.effects.is_empty() and cues.animations.is_empty(),"reset clears all visual ownership")
 var player:=AnimationPlayer.new();root.add_child(player);var lib:=AnimationLibrary.new()
 for name in ["old","new"]:
  var a:=Animation.new();a.length=2;lib.add_animation(name,a)
 player.add_animation_library("",lib);player.play("old");player.seek(.4)
 var saved:={"player":player,"active":true,"clip":"old","position":.4,"playing":true}
 player.active=false;player.play("new");player.seek(.8)
 var requested_clip:=player.current_animation;var requested_position:=player.current_animation_position
 Pose._restore_player(saved)
 check(player.current_animation==requested_clip and is_equal_approx(player.current_animation_position,requested_position) and player.active,"release preserves actual external clip/position request; inactive seek itself need not apply")

 var result:={"checks":checks,"failures":failures,"scope":"snapshot-before-update retry, no state writes, rig identity/group/physics isolation, frozen pose ownership, external animator override"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--proof="):var f=FileAccess.open(arg.trim_prefix("--proof="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result));player.queue_free();app.queue_free();await process_frame;quit(1 if not failures.is_empty() else 0)
