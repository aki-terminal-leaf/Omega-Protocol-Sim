# SPDX-License-Identifier: MIT
extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Official=preload("res://scripts/official_models.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("SOURCE_CUE FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=Scene.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var a=app.arena;var cues=a.source_cues
 cues.experimental_effects=true # This fixture explicitly tests the opt-in graph renderer.
 a.set_encounter("p2_synergy")
 var points:Array=[Vector2(-10,-10),Vector2(10,-10),Vector2(-10,10),Vector2(10,10)]
 var ids:Array=[31525,31526,31530,31533];var stances:Array=["SHIELD","SWORD","LEGS","STAFF"]
 for node in a.stage_nodes:node.free()
 a.stage_nodes=[]
 for i in 4:
  var model:=Official.instantiate("male" if i<2 else "female");a.add_child(model);model.position=Vector3(points[i].x,0,points[i].y);Official.set_stance(model,stances[i]);a.stage_nodes.append(model)
 var actors:Array=[]
 for i in 8:actors.append({"pos":Vector2(i,0),"face":0.0})
 var state:Dictionary={"sim_time":0.0,"timeline":[]}
 var beat:Dictionary={"duration":1.0,"title":"same-title","shapes":[{"kind":"donut","pos":points[0],"name":"Beyond Strength"},{"kind":"circle","pos":points[1],"name":"Efficient Bladework"},{"kind":"line","pos":points[2],"name":"Superliminal Steel","angle":0},{"kind":"line","pos":points[3],"name":"Optimized Blizzard III","angle":0}]}
 cues.update(state,beat,actors,0)
 for time in [0.4,0.7,1.0,1.1,1.4]:
  state.sim_time=time;cues.update(state,beat,actors,time);await process_frame
 check(cues.emitted.size()==4,"exactly one source action per physical weapon; end-of-beat clock stable")
 var before:=JSON.stringify(cues.report());var effect_count:int=cues.effects.size()
 for i in 5:cues.update(state,beat,actors,1.4)
 check(JSON.stringify(cues.report())==before,"paused source state is unchanged")
 check(effect_count>0,"source emitter instances created")
 var seen:Dictionary={};var particles:=0
 for item in cues.effects.values():
  seen[int(item.ability)]=true;particles+=item.player.last_particles.size()
 check(ids.all(func(id):return seen.has(id)),"all four actions have actual source packs")
 check(particles>0,"source particles sampled, not just catalog entries")
 check(cues.animations.size()==4,"all four real PAP samples active")
 check(not cues.diagnostics.has("missing_action_timeline/31530"),"leg source dispatch is concrete")
 var keys:Array=cues.scheduled.keys()
 var fresh:Dictionary={"sim_time":0.0,"timeline":[]};cues.update(fresh,beat,actors,0)
 check(cues.effects.is_empty() and cues.animations.is_empty(),"new run removes all prior effects/overrides")
 for time in [0.4,0.7,1.0,1.1,1.4]:fresh.sim_time=time;cues.update(fresh,beat,actors,time)
 check(cues.scheduled.keys()==keys,"same run reset uses deterministic source keys")
 cues.clear();cues.phase=3
 var arm_event:Dictionary={"kind":"p3_transition_arm_hit","time":1.0,"details":{"origin":[-12,0]}}
 cues.consume(arm_event,actors,10);cues.consume(arm_event,actors,11)
 check(cues.emitted.size()==2,"two simultaneous same-position events are not collapsed")
 cues.clear();cues.phase=2;cues.state_ref={"limitless":{"arrow":{"kind":"line","pos":[0,0],"angle":0,"name":"Optimized Sagittarius Arrow"}}}
 cues.consume({"kind":"limitless_arrow_lock","time":1.0,"details":{"shape":{"kind":"line","pos":[0,0],"angle":0,"name":"Optimized Sagittarius Arrow"}}},actors,0)
 check(cues.emitted.is_empty(),"arrow target-lock does not play attack")
 cues.consume({"kind":"limitless_arrow","time":2.0,"details":{}},actors,1)
 check(cues.emitted.size()==1,"arrow fires on actual resolution")
 cues.clear();check(cues.effects.is_empty(),"final cleanup")
 var result:Dictionary={"checks":checks,"failures":failures,"particles_at_four_weapon_sample":particles,"scope":"actual imported models, source graphs and PAP; stable time, pause, retry, simultaneous events and no early arrow attack; headless not visual"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--proof="):var f=FileAccess.open(arg.trim_prefix("--proof="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ")+"\n")
 print("SOURCE_CUE_RESULT ",JSON.stringify(result));app.queue_free();await process_frame;quit(1 if failures else 0)
