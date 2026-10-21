extends SceneTree
const Status = preload("res://scripts/statuses.gd")
const Contact = preload("res://scripts/interactions.gd")
const Rules = preload("res://scripts/rules.gd")
const Encounter = preload("res://scripts/encounters.gd")
const Main = preload("res://scenes/main.tscn")
var assertions := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok: failures += 1; print("STATEFUL FAIL: ", description)
func party() -> Array:
	var actors: Array = []
	for i in 8: actors.append({"role":Encounter.ROLES[i],"pos":Rules.direction(i*45)*18.0,"face":0.0})
	return actors
func fresh() -> Dictionary:
	var state := {"sim_time":0.0,"dynamis":[0,0,0,0,0,0,0,0],"spent":[],"lb":"","aggro":0}
	Status.ensure(state)
	return state
func advance(actors: Array, previous: Array, state: Dictionary, dt: float) -> void:
	state.sim_time += dt
	Status.tick(actors,previous,state,dt)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var actors := party(); var state := fresh()
	actors[0].pos=Vector2.ZERO; actors[6].pos=Vector2(-3,0)
	Status.give(state,0,"red",10)
	var previous := actors.duplicate(true); actors[6].pos=Vector2(3,0)
	advance(actors,previous,state,0.1)
	check(state.statuses[6].has("red"),"unassigned actor crossing a source is infected without ending on it")
	check(state.statuses[0].has("red"),"propagation does not remove donor rot")
	check(state.statuses[6].red.source==0,"actual source recorded, no suggested recipient read")
	var expiry: float=state.statuses[6].red.expires
	Status.give(state,6,"red",27)
	check(state.statuses[6].red.expires==expiry,"same-colour repeat does not extend timer")
	Status.give(state,6,"blue",27,1)
	check(state.statuses[6].has("blue") and not state.statuses[6].has("red"),"opposite colour overwrites old rot")
	state.statuses[6].red_debugger={"expires":INF}
	Status.give(state,6,"red",27,0)
	check(state.statuses[6].has("blue") and not state.statuses[6].has("red"),"Underflow Debugger prevents overwrite")
	# One receiver touching both colours has an explicit unresolved-policy failure, not actor-index priority.
	actors=party(); actors[0].pos=Vector2(-0.75,0); actors[1].pos=Vector2(0.75,0); actors[2].pos=Vector2.ZERO
	state=fresh(); Status.give(state,0,"red",10); Status.give(state,1,"blue",10)
	Status.contacts(actors,actors,state)
	check(not state.statuses[2].has("red") and not state.statuses[2].has("blue") and not state.runtime_failures.is_empty(),"ambiguous simultaneous contacts fail explicitly")
	var reversed := fresh(); Status.give(reversed,0,"blue",10); Status.give(reversed,1,"red",10)
	Status.contacts(actors,actors,reversed)
	check(state.statuses[2]==reversed.statuses[2] and state.runtime_failures==reversed.runtime_failures,"simultaneous opposite-colour outcome is order-invariant")
	# Independent simultaneous contacts batch from the pre-contact state.
	actors=party(); actors[0].pos=Vector2.ZERO; actors[2].pos=Vector2(0.7,0); actors[3].pos=Vector2(1.4,0)
	state=fresh(); Status.give(state,0,"blue",10); Status.contacts(actors,actors,state)
	check(state.statuses[2].has("blue") and not state.statuses[3].has("blue"),"new infection cannot recursively jump twice in one contact batch")
	# Expiry checks actual blast recipients, consumes latent only on the surviving carrier.
	actors=party(); actors[0].pos=Vector2.ZERO; actors[1].pos=Vector2(4,0)
	state=fresh(); Status.give(state,0,"red",0.1); Status.give(state,0,"latent_red",5)
	advance(actors,actors.duplicate(true),state,0.2)
	check(state.statuses[0].has("red_debugger") and not state.statuses[0].has("latent_red"),"rot expiry grants immunity and clears matching latent")
	check(1 in state.dead and str(state.runtime_failures).contains("expiry blast"),"nearby actor dies to rot expiry even with no endpoint check")
	state=fresh(); Status.give(state,0,"latent_blue",0.1); advance(actors,actors,state,0.2)
	check(str(state.runtime_failures).contains("latent_blue expired"),"unresolved tower latent fails on its own timer")
	state=fresh(); Status.give(state,0,"smell_blue",0.1); advance(actors,actors,state,0.2)
	check(state.statuses[0].has("blue"),"code smell transitions into active bug")
	# A correct tower endpoint cannot cure an incorrect earlier infection.
	actors=party(); actors[6].pos=Vector2(-10,0); state=fresh()
	Status.give(state,6,"blue",0.5,0)
	var wrong_tower := {"shapes":[{"kind":"tower","pos":Vector2(-10,0),"radius":3.0,"rule":"count","count":1,"rot_colour":"red"}],"positions":[Vector2.ZERO],"labels":["guide says red"]}
	check(Rules.evaluate(wrong_tower,actors,state).is_empty(),"geometry can pass while wrong infection remains pending")
	advance(actors,actors,state,11.0)
	check(str(state.runtime_failures).contains("latent_red expired"),"wrong actual colour fails latent expiry despite correct final tower position")
	# Live early breaks stay failed even after moving to the correct end positions.
	actors=party(); actors[0].pos=Vector2(-1,0); actors[1].pos=Vector2(1,0)
	state=fresh(); Status.give(state,0,"magic_vulnerability",1)
	Status.begin({"paired_tethers":[{"id":"early","kind":"local","a":0,"b":1,"duration":2}]},state)
	advance(actors,actors,state,0.1)
	check(state.paired_tethers[0].broken and str(state.runtime_failures).contains("Magic Vulnerability"),"early Local break causes persistent vulnerability failure")
	actors[0].pos=Vector2(-10,0); actors[1].pos=Vector2(10,0); advance(actors,actors,state,2)
	check(not state.runtime_failures.is_empty(),"moving to a later correct endpoint does not clear an earlier failure")
	state=fresh(); Status.begin({"paired_tethers":[{"id":"timeout","kind":"remote","a":0,"b":1,"duration":0.1}]},state)
	advance(actors,actors,state,0.2)
	check(str(state.runtime_failures).contains("Regression expired"),"unbroken Remote expires")
	# Transferable lines support both explicit ownership policies, with live damage following the result.
	for policy in ["unverified_exclusive","allow_multiple"]:
		actors=party(); actors[0].pos=Vector2(12,0); actors[1].pos=Vector2(0,-12); actors[2].pos=Vector2(0,4)
		state=fresh()
		var beat := {"shapes":[{"actor":0,"radius":1.0,"tether_index":0}],"transfers":{"group":"test","initial":[0,1],"sources":[Vector2.ZERO,Vector2.ZERO],"wanted":[2,3],"ownership_policy":policy}}
		Contact.begin(beat,actors,state)
		previous=actors.duplicate(true); actors[1].pos=Vector2(6,0)
		Contact.tick(beat,actors,previous,state,0.1)
		check(state.tether_holders==([0,1] if policy=="unverified_exclusive" else [1,1]),"double-line policy: "+policy)
		check(beat.shapes[0].actor==state.tether_holders[0],"explosion follows real owner under "+policy)
	# All explicitly supported shape families have a safe point; concrete attack boundaries are tested too.
	for orientation in [0.0,90.0,180.0,270.0]:
		for sword in [false,true]:
			for legs in [false,true]:
				for second in [false,true]:
					var shapes := Encounter.omega_shapes(sword,legs,orientation,second)
					var known_safe := (Vector2(14,0) if sword else Vector2(-8,0)) if legs else (Vector2(15,6) if sword else Vector2(-12,6))
					known_safe = known_safe.rotated(deg_to_rad(orientation+(90 if second else 0)))
					check(shapes.all(func(shape):return not Rules.contains(shape,known_safe,[])),"independent known safe point for clone family %s" % str([orientation,sword,legs,second]))
	var shapes := Encounter.omega_shapes(true,false,0,false)
	check(Rules.contains(shapes[0],Vector2(-8,0),[]) and not Rules.contains(shapes[0],Vector2(3,0),[]),"sword circle has actual radius ten around clone")
	shapes=Encounter.omega_shapes(false,false,0,false)
	check(not Rules.contains(shapes[0],Vector2(-8,0),[]) and Rules.contains(shapes[0],Vector2(3,0),[]),"shield donut reverses inside/outside")
	shapes=Encounter.omega_shapes(true,true,0,false)
	check(Rules.contains(shapes[1],Vector2(8,5),[]) or Rules.contains(shapes[2],Vector2(8,5),[]),"F side rectangles hit beyond four-unit corridor")
	check(not Rules.contains(shapes[1],Vector2(8,3),[]) and not Rules.contains(shapes[2],Vector2(8,3),[]),"F side rectangles leave the actual narrow corridor")
	check(Rules.contains(shapes[-2],Vector2(0,-10),[]) and not Rules.contains(shapes[-2],Vector2(10,0),[]),"Diffuse uses a 120-degree cone in its real direction")
	var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var world: Dictionary=Encounter.new().build("p5_dynamis",47,profiles[0]).beats[1]
	actors=party()
	for i in 8: actors[i].pos=world.positions[i]
	state=fresh();state.blaster_victims=[world.checks[0].near];state.tether_holders=[world.checks[0].far]
	world.checks[0].exclude_blaster=true
	check(str(Rules.evaluate(world,actors,state)).contains("Blaster holder"),"World excludes actual earlier Blaster victims even if historical holder changes")
	var first := Encounter.arrow_shapes(true,0); var next := Encounter.arrow_shapes(true,1)
	check(first[0].width==10 and next[0].width==5 and absf(next[0].pos.x)==7.5,"Arrow first translation and widths")
	check(absf(Encounter.arrow_shapes(true,2)[0].pos.x)==12.5,"Arrow subsequent translation is five, not a goal-shaped gap")
	# Moving stream origin, spacing and scheduled explosion time are independent of suggested goals.
	actors=party(); actors[0].pos=Vector2(-17,0); state=fresh()
	Status.begin({"streams":[{"id":"moving","pos":Vector2(-24,0),"advance":Vector2(7,0),"radius":2.0,"delay":0.1,"interval":1.0,"remaining":3}]},state)
	advance(actors,actors,state,1.2)
	var explosions: Array=state.timeline.filter(func(e):return e.kind=="stream_explosion")
	check(explosions.size()==2 and explosions[0].pos==Vector2(-24,0) and explosions[1].pos==Vector2(-17,0),"stream moves seven from actual origin")
	check(is_equal_approx(explosions[1].scheduled-explosions[0].scheduled,1.0) and str(state.runtime_failures).contains("moving exaflare"),"moving blast hits at its interval")
	# Exercise actual Main retry and report, not a dictionary-copy-only surrogate.
	var app=Main.instantiate(); root.add_child(app); await process_frame; app.set_process(false)
	for i in app.filtered.size():
		if app.filtered[i].id!="p3_hello":continue
		app.choose_mechanic(i); app.strategy_select.select(1); app.choose_strategy(1); app.demo=true; app.start_run()
		var saved: Dictionary=app.before_state.duplicate(true)
		app._process(0.1); Status.fail(app.state,"deliberate retry failure")
		app.sprint_left=4.0;app.knockback_resist_left=3.0;app.dash_left=0.2
		app.retry_beat()
		check(app.state==saved,"retry restores timers, contacts, timeline, tethers and failure state exactly")
		check(app.sprint_left==app.start_controls.sprint and app.knockback_resist_left==app.start_controls.resist and app.dash_left==app.start_controls.dash,"retry restores physical action durations")
		check(app.retry_history[-1].controls.sprint==4.0,"retry archive preserves actual abandoned action state")
		app.stop_failure.button_pressed=false
		var ticks:=0
		while app.running and ticks<3000:app._process(0.1);ticks+=1
		check(not app.running and app.all_errors.is_empty(),"P3 live course completes without suppressing errors")
		var report: Dictionary=app.report()
		check(report.has("timeline") and report.has("statuses") and report.timeline.any(func(e):return e.kind=="bug_explosion"),"report includes actual status/blast history")
		check(report.timeline.any(func(e):return e.kind=="debugger_block" and e.status=="overflow"),"Critical Error is blocked by earned Overflow Debugger")
		var final_breaks: Array=report.timeline.filter(func(e):return e.kind=="paired_tether_break" and e.id.ends_with("_3"))
		check(final_breaks.size()==2 and final_breaks[0].id=="hw_local_3","fourth iteration actually breaks Local before Remote")
		app.demo=true;app.start_run(2)
		check(app.checkpoint_assisted and app.state.timeline.any(func(e):return e.kind=="status_gain" and e.source>=0),"checkpoint replays actual infections")
	app.queue_free(); await process_frame
	print("STATEFUL ASSERTIONS ",assertions," FAILURES ",failures)
	quit(1 if failures else 0)
