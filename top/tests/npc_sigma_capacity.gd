# SPDX-License-Identifier: MIT
extends SceneTree
const E=preload("res://scripts/encounters.gd")
const Arena=preload("res://scripts/arena.gd")
const R=preload("res://scripts/rules.gd")
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("SIGMA CAPACITY FAIL ",label)
func people(points:Array)->Array:
 var result:Array=[]
 for actor in 8:result.append({"pos":R.v(points[actor]),"role":E.ROLES[actor],"face":0.0})
 return result
func shown(arena)->Array:
 return arena.sigma_capacity_labels.filter(func(label):return label.visible)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900)
 var arena=Arena.new();root.add_child(arena);await process_frame;arena.set_process(false)
 var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
 var identities:Array=arena.sigma_capacity_labels.map(func(label):return label.get_instance_id())
 for base in profiles:
  for remote in [false,true]:
   var p:Dictionary=base.duplicate(true);p.sigma_remote=remote
   var e:Dictionary=E.new().build("p5_sigma",17391,p)
   var initial:Dictionary=e.beats[0]
   var reveal:Dictionary=e.beats.filter(func(b):return b.get("sigma_tell",false))[0]
   var resolve:Dictionary=e.beats.filter(func(b):return b.get("sigma_towers",false))[0]
   var after:Dictionary=e.beats.filter(func(b):return str(b.title).contains("F and arms appear"))[0]
   var actors:=people(initial.spawn)
   arena.update_state(actors,initial,4,false,0.0,{"sim_time":0.0})
   check(shown(arena).is_empty(),"no capacity before reveal "+str(base.id))
   for beat in [reveal,resolve]:
    for guide in [false,true]:
     arena.update_state(actors,beat,4,guide,0.0,{"sim_time":19.3})
     var labels:=shown(arena)
     check(labels.size()==(5 if remote else 6),"actual labels for both capacities, hints="+str(guide))
     var total:=0
     for i in labels.size():
      total+=int(labels[i].text)
      var point:=R.v(beat.shapes[i].pos)
      check(labels[i].text==str(int(beat.shapes[i].count)) and Vector2(labels[i].position.x,labels[i].position.z).distance_to(point)<.001,"visible count bound to actual tower")
     check(total==8,"visible capacities total eight")
   arena.update_state(actors,after,4,false,0.0,{"sim_time":31.8})
   check(shown(arena).is_empty(),"F hides every old tower numeral")
   arena.update_state(actors,reveal,4,false,0.0,{"sim_time":19.3})
   arena.update_state(actors,initial,4,false,0.0,{"sim_time":19.3})
   check(shown(arena).is_empty(),"equal-clock fresh run does not retain capacity")
   arena.update_state([],reveal,4,false,0.0,{})
   check(shown(arena).is_empty(),"unconfigured actors hide capacity")
   check(arena.sigma_capacity_labels.map(func(label):return label.get_instance_id())==identities,"labels are pooled across updates and retries")
 arena.queue_free();await process_frame
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
 var selected:=-1
 for i in app.filtered.size():
  if app.filtered[i].id=="p5_sigma":selected=i
 check(selected>=0,"Sigma real product selection exists")
 for remote in [false,true]:
  app.choose_mechanic(selected);app.strategy_select.select(4);app.choose_strategy(4)
  app.active_profile.sigma_remote=remote;app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
  var ticks:=0
  while app.running and not app.current.get("sigma_tell",false) and ticks<300:
   app._process(.1);ticks+=1
  check(app.current.get("sigma_tell",false) and app.all_errors.is_empty(),"actual Main reaches early reveal without damage")
  check(app.state.sigma.get("visible_towers",[]).size()==(5 if remote else 6),"Main production report has actual visible towers")
  app.state.sigma.visible_towers=[]
  app.retry_beat()
  check(app.state.sigma.get("visible_towers",[]).size()==(5 if remote else 6),"real Main.retry_beat reconstructs only current reveal")
  check(shown(app.arena).size()==(5 if remote else 6),"real retry visible numeral lifecycle")
  app.start_run(0,false)
  check(shown(app.arena).is_empty() and not app.state.sigma.has("visible_towers"),"R fresh run hides all prior tower information")
  await process_frame
 app.return_to_selection();check(shown(app.arena).is_empty(),"selection has no previous capacities")
 app.queue_free();await process_frame
 print("SIGMA_CAPACITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"real Arena pooled labels hints-off/on, five profiles both distances; actual Main retry/reset"}))
 quit(1 if failures else 0)
