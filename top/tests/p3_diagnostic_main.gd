# SPDX-License-Identifier: MIT
extends SceneTree
## Actual Main headless diagnostic UX; deliberate rejection/missing-model fixtures.
## This is not actual Web/native pixels or player full-guide acceptance.
const Main=preload("res://scenes/main.tscn")
const O=preload("res://scripts/p3_transition_observation.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var normal_frames_scanned:=0
var normal_review_lines:=-1
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("P3 DIAGNOSTIC MAIN FAIL ",label)
func choose(app,human:=0)->void:
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 for index in app.filtered.size():
  if app.filtered[index].id=="p3_transition":app.choose_mechanic(index);app.strategy_select.select(1);app.choose_strategy(1);break
 app.seed_edit.text="17391";app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
 var focus=app.get_viewport().gui_get_focus_owner()
 if focus:focus.release_focus()
func advance(app,target:float,frame:=.05,scan_clean:=false)->void:
 var frames:=0
 while float(app.state.sim_time)<target-.00001 and app.running and not app.paused and frames<1200:
  app._process(minf(frame,target-float(app.state.sim_time)));frames+=1
  if scan_clean:
   normal_frames_scanned+=1
   check(app.p3_diagnostic().status not in ["blocked","invalid_record"],"normal live frame never invents bad-cue status")
   check(not app.hud_status_panel.visible,"ordinary live frame remains clean without overlay")
 check(float(app.state.sim_time)>=target-.00001,"actual Main reached %.3f"%target)
func pure(app)->void:
 var before:Dictionary=app.state.duplicate(true);var beat:Dictionary=app.current.duplicate(true)
 for i in 6:app.p3_diagnostic()
 check(app.state==before and app.current==beat,"derived helper does not mutate actual Main state or beat")
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 choose(app);app.training_overlay=false;app.sync_practice_hud()
 check(app.p3_diagnostic().status=="waiting_marks","fresh live status")
 check(not app.hud_status_panel.visible,"ordinary pre-cue practice remains clean")
 pure(app);advance(app,.1)
 var d:Dictionary=app.p3_diagnostic()
 check(d.status=="waiting_source" and d.marks_seen,"current marks stage normally without claiming arm observed")
 app.training_overlay=true;app.sync_practice_hud()
 check(app.hud_cue.text.contains("等待手臂提示"),"overlay explains normal public wait")
 app.training_overlay=false;app.sync_practice_hud()
 check(not app.hud_status_panel.visible,"normal wait is not a mid-run warning")
 advance(app,4.2,.05,true);d=app.p3_diagnostic()
 check(d.status=="observed" and d.sources_seen==3,"actual official scene receipt classified")
 pure(app)
 check(app.report().p3_observation==d and app.report().format=="top-practice-report/3","additive primitive diagnostic report")
 app.training_overlay=true;app.sync_practice_hud()
 check(app.hud_cue.text.contains("已觀察到手臂提示"),"overlay reports past observation without first direction")
 # Explicit simulated rejection in an actual Main scene; not an actual GPU fault.
 O.publish(app.current,app.state,[{"id":"test_duplicate","pos":[0,-14]},{"id":"test_duplicate","pos":[0,-14]}])
 app.training_overlay=false;app.sync_practice_hud();d=app.p3_diagnostic()
 check(d.status=="blocked","rejection is distinct from waiting")
 check(app.hud_status_panel.visible and app.hud_cue.text.contains("手臂提示無法確認"),"actionable blocked notice uses existing HUD even without hints")
 check(app.running and not app.paused and not app.answers_visible(),"diagnostic neither pauses game nor enables answers")
 pure(app)
 var positions:Array=app.actors.map(func(a):return R.v(a.pos));var old_errors:Array=app.all_errors.duplicate()
 advance(app,4.3)
 check(range(8).all(func(a):return R.v(app.actors[a].pos)==positions[a]),"blocked NPCs and released human genuinely hold")
 check(app.all_errors==old_errors and app.state.runtime_failures.is_empty(),"diagnostic creates no physical or grading failures")
 app.stop_failure.button_pressed=true
 var boundary:float=float(app.state.sim_time)+float(app.current.duration)-app.elapsed
 advance(app,boundary)
 check(app.failed_review(),"normal physical first-beat failure still pauses at judgment")
 check(app.journal[-1].p3_observation_status=="blocked","snapshot records diagnostic at real judgment boundary")
 check(app.feedback.text.count("提示回饋 · 本段手臂提示無法確認")==1,"one neutral informational review per actual judgment")
 check(app.hud_cue.text.contains("判定失敗") and app.hud_cue.text.contains("手臂提示無法確認"),"existing failure verdict preserved")
 check(app.all_errors==app.journal[-1].failures,"diagnostic never adds a failure to grade")
 app.retry_beat()
 check(app.p3_diagnostic().status=="waiting_marks","retry restores beat-start diagnostic without future cache")
 app.start_run(0,false);advance(app,.1)
 app.state.p3_transition_observation.marks_at=float(app.state.sim_time)+1.0
 app.sync_practice_hud()
 check(app.p3_diagnostic().status=="invalid_record" and app.hud_status_panel.visible,"future timestamp is actionable invalid information, not normal wait")
 pure(app)
 app.start_run(2,false);app.training_overlay=true;app.sync_practice_hud();d=app.p3_diagnostic()
 check(d.status=="assisted" and d.checkpoint_assisted,"checkpoint remains reconstructed, never observed")
 check(app.feedback.text.count("分段輔助：P3")==1,"existing assistance feedback retained once")
 check(app.report().checkpoint_assisted and app.report().p3_observation.status=="assisted","report does not grant live/manual credit")
 choose(app);app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
 var total:=0.0
 for beat in app.encounter.beats:total+=float(beat.duration)
 advance(app,total,.1)
 app._process(.01) # Normal next frame resolves epsilon/pending-advance at the final boundary.
 check(not app.running,"actual demo reaches terminal lifecycle, not only a near-equal clock")
 check(app.all_errors.is_empty() and app.state.runtime_failures.is_empty(),"full actual demo physics unaffected")
 check(app.report().mode=="demo" and not app.report().checkpoint_assisted,"demo still not manual credit")
 check(app.journal.size()==4 and app.journal.all(func(row):return row.has("p3_observation_status")),"all four real snapshots have derived metadata count="+str(app.journal.size()))
 check(app.journal.all(func(row):return row.p3_observation_status not in ["blocked","invalid_record"]),"all normal demo snapshots avoid false-error diagnostics")
 normal_review_lines=app.feedback.text.count("提示回饋 ·")
 check(normal_review_lines==0,"normal demo emits no unexpected cue-review noise")
 app.return_to_selection()
 check(app.p3_diagnostic().status=="inactive","selection is not a failed P3 observation")
 app.role_select.select(0)
 for index in app.filtered.size():
  if app.filtered[index].id=="p1_loop":app.choose_mechanic(index);app.strategy_select.select(1);app.choose_strategy(1);break
 app.seed_edit.text="17391";app.start_run(0,false)
 check(app.report().p3_observation.status=="inactive","non-P3 report remains inactive")
 app.queue_free();await process_frame
 # Separate scene to keep deliberate model metadata tampering isolated.
 app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 choose(app);advance(app,3.3);app._process(.6);O.begin(app.current,app.state)
 for node in app.arena.stage_nodes:
  if node.get_meta("model_form","") in ["arm_left","arm_right"]:node.set_meta("official_model",false)
 app.arena.update_state(app.actors,app.current,0,false,app.elapsed,app.state);app.publish_observed_cues();app.training_overlay=false;app.sync_practice_hud()
 check(app.arena.p3_displayed_arms.is_empty() and app.p3_diagnostic().status=="waiting_source","missing official models never fabricate observed or blocked cue")
 check(not app.hud_status_panel.visible,"normal unavailable cue is not a guessed late-warning threshold")
 app.training_overlay=true;app.sync_practice_hud()
 check(app.hud_cue.text.contains("等待手臂提示"),"explicit overlay reveals missing-source status")
 pure(app)
 app.queue_free();await process_frame
 print("P3_DIAGNOSTIC_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"normal_frames_scanned":normal_frames_scanned,"normal_review_lines":normal_review_lines,"scope":"actual Main headless HUD/report/retry/grading and deliberate unavailable-model/rejected-receipt fixtures; not Web/native/GPU/manual proof"}))
 quit(1 if failures else 0)
