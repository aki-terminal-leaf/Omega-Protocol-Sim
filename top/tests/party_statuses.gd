# SPDX-License-Identifier: MIT
extends SceneTree
const Party=preload("res://scripts/party_statuses.gd")
const Status=preload("res://scripts/statuses.gd")
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
func check(ok:bool,title:String)->void:
	checks+=1
	if not ok: failures+=1;print("PARTY_STATUS FAIL: ",title)
func item(rows:Array,actor:int,key:String)->Dictionary:
	for e in rows[actor].effects:
		if e.key==key:return e
	return {}
func choose(app,id:String)->void:
	for i in app.filtered.size():
		if app.filtered[i].id==id:
			app.choose_mechanic(i);app.seed_edit.text="17391";app.strategy_select.select(1);app.choose_strategy(1);return
	check(false,"fixture mechanism exists")
func _initialize()->void:call_deferred("run")
func run()->void:
	var actors:Array=[]
	for i in 8:actors.append({"role":str(i),"pos":Vector2(i,0)})
	var state:Dictionary={"sim_time":10.0,"dynamis":[0,1,2,3,0,0,0,0],"spent":[]}
	Status.ensure(state)
	for i in 8:Status.give(state,i,"red" if i%2==0 else "blue",12+i)
	state.statuses[7].packet_named_effect={"expires":18.0,"status_id":3453};state.loop_numbers=[1,2,3,4,1,2,3,4];state.statuses[0].looper={"expires":16.0};state.statuses[0].expired={"expires":9.0};state.statuses[1].unknown_effect={"expires":17.0,"stacks":2}
	var before:=JSON.stringify(state);var before_actors:=JSON.stringify(actors)
	var rows:=Party.rows(actors,state,{"labels":["SECRET"],"positions":[Vector2(99,99)]})
	check(rows.size()==8,"all eight actual party members")
	for i in 8:check(is_equal_approx(float(item(rows,i,"red" if i%2==0 else "blue").remaining),12+i),"actor-specific authoritative timers")
	check(item(rows,0,"expired").is_empty(),"expired effects hidden")
	check(item(rows,7,"packet_named_effect").icon==215146 and item(rows,7,"packet_named_effect").name.contains("Left"),"actual packet identity resolves icon/name without parsing labels")
	check(item(rows,1,"unknown_effect").stacks==2 and item(rows,1,"unknown_effect").icon==0,"unknown actual effect retained with stack and honest text fallback")
	check(item(rows,3,"dynamis").stacks==3,"actual Dynamis stacks")
	check(item(rows,0,"first_in_line").is_empty() and item(rows,0,"looper").remaining==6.0,"Looper order does not fabricate a separate In Line buff")
	check(JSON.stringify(state)==before and JSON.stringify(actors)==before_actors,"getter does not mutate status history or actor state")
	Status.give(state,0,"blue",9.0);rows=Party.rows(actors,state)
	check(item(rows,0,"red").is_empty() and item(rows,0,"blue").remaining==9.0,"real opposing rot overwrite shown immediately")
	state.sim_time=20.0;rows=Party.rows(actors,state)
	check(item(rows,0,"blue").is_empty(),"sim-clock expiry not wall time")
	state.p6_lb={"memory_entry":false,"brilliant":[0,1],"jobs":["WAR"],"tank_buffs":[{"actor":0,"start":18.0,"end":26.0}],"doom":[{"targets":[2,3],"expires":24.0}]}
	state.spent=[1];rows=Party.rows(actors,state,{}, {"actor":4,"sprint_left":8.0,"knockback_resist_left":3.0})
	check(not item(rows,0,"brilliant_dynamis").is_empty(),"actual Brilliant holder")
	check(item(rows,1,"brilliant_dynamis").is_empty() and item(rows,1,"dynamis").is_empty(),"spent Brilliant does not reappear as old Dynamis stacks")
	check(item(rows,7,"tank_lb_war").remaining==6.0 and item(rows,7,"tank_lb_war").name=="Land Waker","actual tank job buff granted to party")
	check(item(rows,2,"magic_number").remaining==4.0 and item(rows,0,"magic_number").is_empty(),"Magic Number only actual target list")
	check(item(rows,4,"sprint").remaining==8 and item(rows,4,"arms_length").remaining==3 and item(rows,5,"sprint").is_empty(),"manual self buffs only on actual controlled actor")
	check(item(rows,4,"arms_length").status_id==0 and item(rows,4,"arms_length").name=="Knockback Resistance","generic immunity does not pretend a job-specific Arms Length/Surecast packet")
	state.dead=[2];rows=Party.rows(actors,state);check(rows[2].dead and rows[2].effects.is_empty(),"KO member identified without pretending statuses persist")
	state.sim_time=27.0;rows=Party.rows(actors,state);check(item(rows,7,"tank_lb_war").is_empty() and item(rows,3,"magic_number").is_empty(),"LB buff and Magic Number expiry")
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
	choose(app,"p1_loop");app.start_run();app.hints.button_pressed=true
	app.current.labels=[]
	for i in 8:app.current.labels.append("SECRET ROUTE")
	app.current.note="SECRET EXPLANATION";app.current.title="SECRET TITLE";app.update_hud()
	check(not app.answers_visible() and not app.report().hints,"legacy teaching preference cannot reveal practice answers")
	check(not app.cue.text.contains("SECRET") and not app.player_info.text.contains("SECRET") and not app.party.text.contains("SECRET") and app.note.text.is_empty(),"practice text surfaces do not leak labels/title/note")
	app.toggle_pause();app.update_hud();check(not app.answers_visible() and not app.hud_feedback_panel.visible,"ordinary pause is not failure review")
	app.arena.update_state(app.actors,app.current,app.player,app.answers_visible(),0,app.state);app.arena._process(0.01)
	check(not app.arena.actor_labels[app.player].text.contains("SECRET"),"3D actor labels do not leak route")
	# Actual Rules.evaluate path produces failure; no fake journal entry.
	app.current.checks=[{"kind":"aggro","actor":1,"name":"Test failed aggro"}];app.current.shapes=[];app.current.erase("program_loop");app.current.erase("knockback");app.state.aggro=0
	app.resolve_beat();app.update_hud()
	check(not app.journal[-1].failures.is_empty() and app.failed_review() and app.answers_visible(),"actual failed snapshot enables review")
	check(app.hud_feedback.text.contains("SECRET ROUTE") and app.hud_feedback.text.contains("SECRET EXPLANATION") and app.hud_feedback_panel.visible,"failed review includes reference and reason")
	app.retry_beat();app.update_hud();check(not app.answers_visible() and not app.hud_feedback_panel.visible and not app.cue.text.contains("SECRET"),"retry closes old review and restores independent practice")
	app.demo=true;check(app.answers_visible(),"explicit non-scored demo may teach")
	var panto=app.catalog.filter(func(entry):return str(entry.id).contains("panto"))[0]
	choose(app,str(panto.id));app.start_run();rows=Party.rows(app.actors,app.state,app.current)
	for i in 8:
		check(item(rows,i,"guided_missile_kyrios").icon==215126 and item(rows,i,"condensed_wave_cannon_kyrios").icon==215026,"actual missile/wave countdowns visible without route instructions")
	choose(app,"p2_synergy");app.start_run()
	for beat in app.encounter.beats:
		if beat.has("party_statuses"):
			var observed:=Party.rows(app.actors,app.state,beat)
			for i in 8:
				check(not item(observed,i,"synergy_marker").is_empty(),"actual paired marker available independently of left/right labels")
				check(not item(observed,i,"mid_glitch").is_empty() or not item(observed,i,"remote_glitch").is_empty(),"actual Glitch persists across optical/knockback beats")
	choose(app,"p3_monitors");app.start_run();rows=Party.rows(app.actors,app.state,app.current)
	var monitor_count:=0
	for row in rows:
		for effect in row.effects:
			if effect.key in ["monitor_left","monitor_right"]:monitor_count+=1
	check(monitor_count==3,"three actual monitor holders and loaded sides visible")
	app.queue_free();await process_frame
	print("PARTY_STATUS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
