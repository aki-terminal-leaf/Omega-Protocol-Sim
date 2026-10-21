extends SceneTree
const Main=preload("res://scenes/main.tscn")
const LB=preload("res://scripts/p6_lb.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;print("P6 CONTROLS FAIL ",message)
func choose(app,scenario:String,role:int,demonstrate:bool)->void:
	app.role_select.select(role)
	for i in app.filtered.size():
		if app.filtered[i].id!=scenario:continue
		app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1)
		app.seed_edit.text="17391";app.demo=demonstrate;app.start_run();app.stop_failure.button_pressed=false;return
	check(false,"missing scenario "+scenario)
func advance(app,until:float)->void:
	var count:=0
	while app.running and float(app.state.sim_time)<until-0.00001 and count<2000:
		app._process(minf(0.05,until-float(app.state.sim_time)));count+=1
func _initialize()->void:call_deferred("run")
func run()->void:
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
	choose(app,"p6_memory",0,false)
	check(app.state.p6_lb.jobs[0]==app.selected_job() and app.state.human_actor==0,"actual selected job and human exclusion initialized")
	check(app.state.p6_training_entry.has("brilliant") and app.state.p6_lb.brilliant.is_empty(),"Memory does not grant Brilliant before survival")
	advance(app,1.0);var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_F;app._unhandled_key_input(key)
	check(app.state.p6_lb.history.any(func(e):return e.kind=="lb_begin" and int(e.actor)==0),"F dispatches a real request")
	app._process(0.05);check(LB.is_locked(app.state,0),"tank has a post-cast animation lock")
	var before:Vector2=app.actors[0].pos;app.use_dash();app.use_sprint();app.jump_player();app._process(0.1)
	check(app.dash_left==0 and app.sprint_left==0 and app.actors[0].pos==before and float(app.actors[0].get("height",0))==0,"locked player cannot activate movement actions")
	advance(app,6.0);check(app.state.runtime_failures.is_empty() and app.state.p6_lb.brilliant.size()==8,"manual tank action survives Memory and earns Brilliant")
	choose(app,"p6_memory",0,false);advance(app,6.0)
	check(not app.state.runtime_failures.is_empty() and app.state.p6_lb.brilliant.is_empty(),"missing human tank action is not supplied by a bot or legacy flag")
	choose(app,"p6_meteors",7,true);advance(app,8.5);app.demo=false;app.state.human_actor=7
	app.lb_ground_x.value=-25;app.lb_ground_y.value=25;app.use_lb()
	check(app.state.p6_lb.casts.is_empty() and app.status.text.contains("Target out of range"),"ground selection obeys actual range")
	app.lb_ground_x.value=0;app.lb_ground_y.value=0;app.use_lb()
	check(app.state.p6_lb.casts.size()==1 and app.state.p6_lb.casts[0].kind=="caster" and app.state.get("lb","")=="","ground UI starts caster cast, never sets legacy success")
	var original_finish:float=app.state.p6_lb.casts[0].finish
	app.state=JSON.parse_string(JSON.stringify(app.json_safe(app.state)));check(LB.is_locked(app.state,7) and is_equal_approx(float(app.state.p6_lb.casts[0].finish),original_finish),"real in-progress Main cast survives JSON")
	before=app.actors[7].pos;app._process(0.1);check(app.actors[7].pos==before and LB.is_locked(app.state,7),"actual Main movement respects cast lock")
	var saved:Dictionary=app.before_state.duplicate(true);app.retry_beat()
	check(app.state==saved and app.state.p6_lb.casts.is_empty(),"retry restores real gauge, casts, targets, buffs and pending events")
	advance(app,20.5)
	check(not app.state.runtime_failures.is_empty() and not app.state.p6_lb.history.any(func(e):return e.kind=="lb_finish" and int(e.actor)==7),"missing caster input fails comet deadline without fabricated finish")
	choose(app,"p6_meteors",6,true);advance(app,8.5);app.demo=false;app.state.human_actor=6
	app.use_lb();check(app.state.p6_lb.casts.is_empty(),"ranged UI requires explicit target")
	for i in app.lb_target.item_count:
		if app.lb_target.get_item_metadata(i)=="meteor_1":app.lb_target.select(i)
	app.use_lb();check(app.state.p6_lb.casts.size()==1 and app.state.p6_lb.casts[0].target=="meteor_1" and app.state.p6_lb.casts[0].kind=="ranged","ranged uses selected live NPC, not a role-wide hit")
	var report:Dictionary=app.report();check(report.runtime_state.has("p6_training_entry") and report.runtime_state.p6_lb.casts.size()==1 and report.timeline.any(func(e):return e.kind=="p6_lb_begin"),"JSON report carries real entry, cast and action history")
	choose(app,"p6_magic",0,true);app.start_run(2)
	check(app.state.p6_lb.history.any(func(e):return e.kind=="lb_finish") and not app.state.p6_lb.effects.is_empty(),"checkpoint reconstructs actual earlier actions and pending lock/refund events")
	choose(app,"p6_magic",1,false);app.start_run(2);app.stop_failure.button_pressed=false
	check(app.state.human_actor==1,"practice checkpoint resets oracle bot ownership to the human")
	advance(app,32.0)
	check(not app.state.runtime_failures.is_empty() and not app.state.p6_lb.history.any(func(e):return e.kind=="lb_finish" and int(e.actor)==1),"checkpoint does not fabricate the human's next Tank LB")
	app.return_to_selection();check(not app.lb_panel.visible,"return clears LB controls from nonselected mechanic")
	print("P6 CONTROLS checks=",checks," failures=",failures)
	app.queue_free();await process_frame;quit(1 if failures else 0)
