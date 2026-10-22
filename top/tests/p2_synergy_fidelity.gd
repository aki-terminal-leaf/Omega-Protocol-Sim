extends SceneTree
const Encounter=preload("res://scripts/encounters.gd")
const Rules=preload("res://scripts/rules.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
const Party=preload("res://scripts/party_statuses.gd")
const Interactions=preload("res://scripts/interactions.gd")
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
func check(ok:bool,title:String)->void:
	checks+=1
	if not ok:failures+=1;print("SYNERGY FAIL ",title)
func _initialize()->void:call_deferred("run")
func run()->void:
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var total:=0
	for profile in profiles:
		for remote in [false,true]:
			for sword in [false,true]:
				for legs in [false,true]:
					for rotation in 8:
						var p:Dictionary=profile.duplicate(true)
						p.merge({"p2_remote":remote,"p2_sword":sword,"p2_legs":legs,"p2_clone_angle":22.5+45*rotation},true)
						var encounter:Dictionary=Encounter.new().build("p2_synergy",42,p)
						var b:Array=encounter.beats;var ends:Array=[];var t:=0.0
						for beat in b:t+=float(beat.duration);ends.append(snappedf(t,0.001))
						check(ends.size()==11 and range(11).all(func(i):return absf(float(ends[i])-float([3.0,6.1,8.3,13.4,19.8,20.2,27.1,31.4,31.5,33.1,34.6][i]))<0.0005),"source nominal event boundaries")
						check(b[2].stage_entities.filter(func(e):return e.form=="male").size()==2 and b[2].stage_entities.filter(func(e):return e.form=="female").size()==2,"two M/two F, not only attacking pair")
						check(b[2].stage_entities.filter(func(e):return e.get("stance","")=="NEUTRAL").size()==2,"weapons not revealed before tell")
						check(b[3].shapes.size()==3,"only genuine pair owns initial hazards")
						check(b[3].stage_entities.any(func(e):return e.get("id","")=="main_m" and Rules.v(e.pos)==Vector2.ZERO),"main male at center decoy")
						check(not b[3].has("entity_transitions") and is_equal_approx(float(b[4].synergy_start)+float(b[4].entity_transitions[2].at),18.8),"visible gender swap follows actual AnimationSwap, not earlier SubjectSimulation")
						check(b[6].stage_entities.filter(func(e):return e.form=="male").size()==5 and b[6].stage_entities.filter(func(e):return e.form=="female" and Rules.v(e.pos)==Vector2.ZERO).size()==1,"five male sword sources + center female knockback")
						check(b[8].shapes.size()==5 and b[8].shapes.all(func(s):return s.radius==10.0 and Rules.v(s.pos).length()>12.99),"five outer circles; never fake center circle")
						check(b[4].shapes.size()==8 and b[5].shapes.size()==1 and is_equal_approx(float(b[5].duration),0.4),"Fire spreads before separate Laser")
						check(b[7].shapes.size()==2 and b[8].shapes.size()==5,"Spotlight before five sword circles")
						for i in range(1,11):check(b[i].stage_entities.any(func(e):return e.form=="optical_unit" and is_equal_approx(Rules.v(e.pos).length(),45.0)),"eye stays present at radius45")
						for actor in 8:
							check(Signs.observed(actor,b[0],{"sim_time":1.0})=="","no marker before cast ends")
							check(Signs.symbol_name(Signs.observed(actor,b[1],{"sim_time":4.0,"beat_started":3.0}))!="","actual colored symbol during memory")
							check(Signs.observed(actor,b[2],{"sim_time":7.0,"beat_started":6.1})=="","symbol disappears before genuine/decoy test")
							check(Signs.observed(actor,b[3],{"sim_time":12.0})=="","no answer retained in combat")
						total+=1
	var a:Dictionary=Encounter.new().build("p2_synergy",42,profiles[0])
	var z:Dictionary=Encounter.new().build("p2_synergy",7,profiles[0])
	check(a.beats[0].spawn==z.beats[0].spawn,"pre-icon role lineup cannot encode future seeded assignments")
	check(a.assignments!=z.assignments,"different seeds still produce genuinely different paired actors")
	# Production Main, actual movement/beat transitions + the real render data path.
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
	var found:=-1
	for i in app.filtered.size():
		if app.filtered[i].id=="p2_synergy":found=i
	app.choose_mechanic(found);app.strategy_select.select(1);app.choose_strategy(1);app.fresh_seed.set_pressed_no_signal(false);app.seed_edit.text="42";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
	var points:Array=[2.9,4.0,7.0,9.0,12.7,14.3,20.3,20.9,22.9,27.2,31.45,31.6,33.2,34.6]
	for time in points:
		while app.running and float(app.state.sim_time)<float(time)-0.00001:app._process(minf(0.05,float(time)-float(app.state.sim_time)))
		app.arena._process(0.01)
		if time==2.9:check(range(8).all(func(i):return app.actors[i].pos.distance_to(app.current.spawn[i])<0.001),"no anticipatory bot sorting before actual icons")
		if time==4.0:check(app.arena.mechanic_signs.all(func(n):return n.visible and n.texture!=null),"real arena emits eight graphical marks without hints")
		if time==7.0:check(app.arena.mechanic_signs.all(func(n):return not n.visible),"real arena clears all eight signs")
		if time==9.0:check(app.arena.stage_nodes.filter(func(n):return n.get_meta("model_form","")=="male").size()==2,"actual original four-clone path")
		if time==12.7:check(app.arena.stage_nodes.filter(func(n):return n.get_meta("model_form","")=="male").size()==2,"gender swap keeps two male/two female before helpers vanish")
		if time==14.3:check(app.arena.stage_nodes.filter(func(n):return n.get_meta("model_form","")=="male" and n.visible).size()==5,"four helpers appear0.8 after double AoEs, main still male")
		if time==22.9:check(app.arena.stage_nodes.filter(func(n):return n.get_meta("model_form","")=="male" and n.visible).size()==5,"new male reappears between helpers only after Laser")
		if time==20.3:check(app.arena.mechanic_signs.all(func(n):return not n.visible),"no premature stack markers")
		if time==20.9:check(app.arena.mechanic_signs.filter(func(n):return n.visible).size()==2,"actual two stack markers after Laser+0.6")
		if time==20.9:check(range(8).all(func(i):return Interactions.bot_goal(i,app.current,app.actors,app.state)==Vector2.ZERO),"no final group/new-north steering before visual reappearance")
		if time==31.6:check(app.arena.mechanic_signs.all(func(n):return not n.visible),"stack markers vanish after snapshot")
		if time==33.2:check(app.observed_party().all(func(row):return row.effects.all(func(e):return e.key not in ["mid_glitch","remote_glitch","synergy_marker"])),"Glitch expires on original27s duration")
		await process_frame
	app._process(0.05)
	check(not app.running and app.all_errors.is_empty(),"production course complete without geometry/timing relaxation: "+str(app.all_errors))
	# Fast retry and paused redraw derive symbols from simulation state, not wall time.
	app.demo=true;app.start_run(0,false);app._process(4.0);app.paused=true;app.arena._process(1.0)
	check(app.arena.mechanic_signs.all(func(n):return n.visible),"paused marker phase remains visible")
	app.retry_beat();app.arena.update_state(app.actors,app.current,app.player,false,app.elapsed,app.state);app.arena._process(0.01)
	check(app.arena.mechanic_signs.all(func(n):return n.visible),"checkpoint retry restores symbols")
	app.demo=true;app.start_run(0,false);app.arena.update_state(app.actors,app.current,app.player,false,app.elapsed,app.state);app.arena._process(0.01)
	check(app.arena.mechanic_signs.all(func(n):return not n.visible),"full retry clears future markers")
	for shape in ["O","X","Triangle","Square","stack"]:check(Signs.texture(shape)!=null,"vector texture renders "+shape)
	app.queue_free();await process_frame
	print("SYNERGY_RESULT families=",total," checks=",checks," failures=",failures)
	quit(1 if failures else 0)
