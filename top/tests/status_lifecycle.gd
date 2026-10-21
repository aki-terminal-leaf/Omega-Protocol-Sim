# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Party=preload("res://scripts/party_statuses.gd")
var checks:=0
var failures:=0
func check(ok:bool,title:String)->void:
	checks+=1
	if not ok:failures+=1;print("STATUS_LIFECYCLE FAIL ",title)
func item(rows:Array,a:int,key:String)->Dictionary:
	for e in rows[a].effects:
		if e.key==key:return e
	return {}
func choose(app,id:String)->void:
	for i in app.filtered.size():
		if app.filtered[i].id==id:
			app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1);app.seed_edit.text="17391";return
func _initialize()->void:call_deferred("run")
func run()->void:
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
	for scenario in ["p1_loop","p1_panto"]:
		choose(app,scenario);app.demo=true;app.start_run();app.stop_failure.button_pressed=false
		var saw_ruin:=false;var saw_hp:=false;var saw_vuln:=false;var removed:=[]
		var keys:=["first_in_line","second_in_line","third_in_line","fourth_in_line"]
		var initial:=Party.rows(app.actors,app.state,app.current)
		for actor in 8:
			var found:=0
			for k in keys:
				if not item(initial,actor,k).is_empty():found+=1;check(item(initial,actor,k).remaining==-1,"number has no invented expiry")
			check(found==1,"one actual In Line at entry "+scenario)
		var ticks:=0
		while app.running and ticks<1400:
			app._process(0.05);ticks+=1
			var rows:=Party.rows(app.actors,app.state,app.current)
			for actor in 8:
				if scenario=="p1_loop" and bool(app.state.loop_cleansed[actor]) and actor not in removed:
					check(keys.all(func(k):return item(rows,actor,k).is_empty()) and item(rows,actor,"looper").is_empty(),"tower consumes actual number and Looper together")
					removed.append(actor)
				for e in rows[actor].effects:
					if e.key=="p1_ruin":saw_ruin=true;check(e.icon==219861 and e.status_id==2534,"successful hit Ruin original identity")
					if e.key=="p1_hp_penalty":saw_hp=true;check(e.icon==215076 and e.remaining<=9.0001,"actual delayed HP Penalty original icon/timer")
					if e.key=="magic_vulnerability":saw_vuln=true;check(e.icon==215057,"successful missile/beam vulnerability icon")
					if e.key in ["guided_missile_kyrios","condensed_wave_cannon_kyrios"]:
						check(e.status_id in [3424,3495,3496,3497,3507,3508,3509,3510],"exact observed Panto variant SID retained")
		check(app.all_errors.is_empty() and not app.running,"complete live course passes "+scenario)
		if scenario=="p1_loop":check(saw_ruin and saw_hp and removed.size()==8,"all actual Loop success debuffs observed")
		else:
			check(saw_vuln,"Panto success vulnerability appears")
			var last:=Party.rows(app.actors,app.state,app.current)
			for actor in 8:check(keys.all(func(k):return item(last,actor,k).is_empty()),"all four actual missile rounds consumed numbers")
	for scenario in ["p6_arrow_dive","p6_exa_wave","p6_arrow_wave","p6_exa_dive"]:
		choose(app,scenario);app.demo=true;app.start_run()
		var rows:=Party.rows(app.actors,app.state,app.current)
		for actor in 8:check(item(rows,actor,"brilliant_dynamis").icon==215143 and item(rows,actor,"dynamis").is_empty(),"post-Memory standalone combo starts with actual Brilliant snapshot")
	# Projection survives JSON restore and permanent debugger rewards have no fake countdown.
	var copy:Dictionary=JSON.parse_string(JSON.stringify(app.state))
	copy.statuses[0].blue_debugger={"expires":9999.0};copy.sim_time=1.0
	check(item(Party.rows(app.actors,copy),0,"blue_debugger").remaining==-1,"debugger permanent reward presentation after restore")
	for key in ["p1_ruin","hp_penalty","limitless_ruin","twice_come_ruin","thrice_come_ruin","world_vulnerability","physical_vulnerability","delta_local_smell","delta_remote_smell","delta_monitor","omega_ruin"]:
		check(int(Party.definition(key).icon)>0 and Party.definition(key).category=="debuff","verified runtime alias "+key)
	app.queue_free();await process_frame
	print("STATUS_LIFECYCLE checks=",checks," failures=",failures);quit(1 if failures else 0)
