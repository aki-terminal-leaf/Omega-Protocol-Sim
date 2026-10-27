extends SceneTree
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("HW_CHECKPOINT_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog()
 for n in app.filtered.size():
  if app.filtered[n].id=="p3_hello":app.choose_mechanic(n);app.strategy_select.select(1);app.choose_strategy(1);break
 app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
 var checkpoints:Array=[]
 for r in [1,2,3]:
  for n in app.encounter.beats.size():
   if int(app.encounter.beats[n].get("hw_tower_cooperation",{}).get("round",-1))==r:checkpoints.append(n);break
 checkpoints.append(app.encounter.beats.size()-1)
 for index in checkpoints:
  app.demo=true;app.start_run(index,false);app.stop_failure.button_pressed=false
  check(app.checkpoint_assisted and app.report().checkpoint_assisted and app.feedback.text.contains("分段輔助"),"late checkpoint visibly marked assisted %d"%index)
  check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty(),"actual oracle past clean %d"%index)
  var steps:=0
  while app.running and float(app.state.sim_time)<130.0-0.000001 and steps<4000:app._process(0.1);steps+=1
  check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty() and app.all_errors.is_empty(),"late checkpoint live continuation clean %d: %s"%[index,str(app.state.runtime_failures.slice(0,4))])
  check(app.state.hw.history.any(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8),"late checkpoint actual Critical Error all8 %d"%index)
  app.start_run(0,false)
  check(not app.checkpoint_assisted and not app.state.has("hw_later_assisted") and not app.state.hw.has("later_public"),"fresh attempt clears later assistance/receipts %d"%index)
 app.queue_free();await process_frame
 print("HW_LATER_CHECKPOINT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"checkpoints":checkpoints,"scope":"actual Main assisted reconstruction at waves2/3/4 and terminal beat; not ordinary/manual credit"}))
 quit(1 if failures else 0)
