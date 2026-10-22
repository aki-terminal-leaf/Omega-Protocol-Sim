# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
var failures:Array=[]
var checks:=0
func check(ok:bool,note:String)->void:
 checks+=1
 if not ok:failures.append(note);print("OUTCOME FAIL ",note)
func _initialize()->void:call_deferred("run")
func select_monitor(app)->void:
 for i in app.filtered.size():
  if app.filtered[i].id=="p3_monitors":app.choose_mechanic(i);break
 for j in range(1,app.strategy_select.item_count):
  if str(app.strategy_select.get_item_metadata(j).profile)=="cn_moogle":app.strategy_select.select(j);app.choose_strategy(j);break
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
 select_monitor(app);app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
 check(not app.hud_cue.is_visible_in_tree(),"ordinary practice does not show solution panel")
 var ticks:=0
 while app.running and ticks<500:app._process(0.2);ticks+=1
 check(not app.running and app.all_errors.is_empty(),"real moving monitor course completes")
 check(app.hud_cue.is_visible_in_tree() and "示範結束" in app.hud_cue.text,"completion visible with tools off")
 check("1 通過 / 0 失誤" in app.hud_cue.text,"completion reports actual verdict counts")
 app.demo=false;app.start_run(0,false)
 check(not app.hud_cue.is_visible_in_tree(),"retry hides old verdict")
 check(int(app.state.human_actor)==int(app.player),"practice control ownership exposed to NPC runtime")
 # Stand still on the arena wall: actual geometry creates a failed judgment.
 app.actors[app.player].pos=Vector2(20.1,0);app.stop_failure.button_pressed=true
 ticks=0
 while app.running and not app.paused and ticks<500:app._process(0.2);ticks+=1
 check(app.paused and not app.all_errors.is_empty(),"actual failed snapshot pauses")
 check(app.hud_cue.is_visible_in_tree() and "判定失敗" in app.hud_cue.text,"failure verdict visible without Tab")
 check("Tab 檢討" in app.hud_cue.text and app.hud_cue.text!=str(app.current.note),"failure banner does not print the strategy note")
 check(not app.training_overlay,"tools remain off")
 print("NPC_OUTCOME_RESULT checks=",checks," failures=",failures.size())
 app.queue_free();await process_frame;quit(1 if not failures.is_empty() else 0)
