# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Party=preload("res://scripts/party_statuses.gd")
var checks:=0
var failures:=0
func check(ok:bool,title:String)->void:
 checks+=1
 if not ok:failures+=1;print("STATUS_COVERAGE FAIL ",title)
func capture(app,effects:Dictionary,signals:Dictionary)->void:
 for row in app.observed_party():
  for item in row.effects:
   var out:Dictionary=signals if str(item.kind)=="marker" else effects
   if not out.has(str(item.key)):
    out[str(item.key)]={"status_id":int(item.status_id),"icon":int(item.icon),"name":str(item.name),"category":str(item.get("category","unknown")),"first_observed_course_seconds":snappedf(float(app.state.sim_time),0.001)}
   if str(item.kind)!="marker":check(int(item.icon)>0 or str(item.key)=="arms_length","actual effect resolves to an original icon: "+str(item.key))
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
 var report:Dictionary={"schema":1,"seed":17391,"scope":"all offered independent methods at this fixed seed; observed live UI effects, not exhaustive original status/spawn certification","mechanics":{}}
 var courses:=0
 for i in app.filtered.size():
  app.choose_mechanic(i);var id:String=app.filtered[i].id;var methods:int=app.strategy_select.item_count;var effects:Dictionary={};var signals:Dictionary={}
  for method in range(1,methods):
   app.choose_mechanic(i);app.strategy_select.select(method);app.choose_strategy(method);app.seed_edit.text="17391";app.demo=true;app.start_run();app.stop_failure.button_pressed=false;capture(app,effects,signals)
   if id=="p1_loop":
    for row in app.observed_party():check(row.effects.any(func(e):return e.key in ["first_in_line","second_in_line","third_in_line","fourth_in_line"]),"Loop actual numbered status available at entry")
   if id=="p5_sigma":
    var holders:=0
    for row in app.observed_party():
     if row.effects.any(func(e):return e.key in ["near_world","distant_world"]):holders+=1
    check(holders==2,"Sigma shows exactly the two actual World holders from entry")
   var count:=0
   while app.running and count<5000:
    app._process(0.2);count+=1;capture(app,effects,signals)
   courses+=1;check(not app.running and app.all_errors.is_empty(),id+" method"+str(method)+" full live course")
   if id=="p2_synergy":
    for row in app.observed_party():check(not row.effects.any(func(e):return e.key in ["mid_glitch","remote_glitch","synergy_marker"]),"completed Party Synergy consumes actual forced signals")
   await process_frame
  report.mechanics[id]={"methods":methods-1,"effects":effects,"forced_markers":signals}
 check(report.mechanics.size()==20 and courses==100,"all20 mechanisms/all100 offered methods audited")
 report.courses=courses;report.checks=checks;report.failures=failures
 var file:=FileAccess.open("user://status-coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 app.queue_free();await process_frame;print("STATUS_COVERAGE courses=",courses," checks=",checks," failures=",failures);quit(1 if failures else 0)
