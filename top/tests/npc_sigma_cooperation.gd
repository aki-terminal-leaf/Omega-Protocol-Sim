# SPDX-License-Identifier: MIT
extends SceneTree
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const M=preload("res://scripts/movement.gd")
const Marks=preload("res://scripts/markers.gd")
const C=preload("res://scripts/sigma_cooperation.gd")
const MainProjection=preload("res://scripts/main.gd")
var cases:=0
var failures:=0
var courses:=0
var receipts:Dictionary={}
func check(ok:bool,label:String)->void:
	cases+=1
	if not ok:failures+=1;print("SIGMA COOP FAIL ",label)
func party(points:Array)->Array:
	var out:Array=[]
	for actor in 8:out.append({"pos":R.v(points[actor]),"face":0.0,"role":E.ROLES[actor]})
	return out
func replay(human:int,variant:String,preferred:String="",seed_value:int=17391)->void:
	courses+=1
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var profile:Dictionary=profiles.filter(func(p):return p.id=="cn_moogle")[0].duplicate(true)
	var encounter:Dictionary=E.new().build("p5_sigma",seed_value,profile)
	var config:Dictionary=encounter.beats[0].sigma_config
	var state:Dictionary={"sim_time":0.0,"dynamis":encounter.initial_dynamis.duplicate(),"spent":[],"lb":"","aggro":0,"seed":seed_value,"human_actor":human,"p5_marking_mode":"assist" if variant=="assist" else "manual"}
	var actors:=party(encounter.beats[0].spawn)
	var combat:Array=[];var signed:=false;var late_changed:=false;var locked:Dictionary={}
	var world:bool=human in [int(config.near),int(config.far)]
	var prefix:String="seed%d h%d %s %s "%[seed_value,human,variant,preferred]
	for raw in encounter.beats:
		var b:Dictionary=raw.duplicate(true)
		I.begin(b,actors,state)
		if not signed:
			signed=true
			if variant in ["correct","late","alternative"] and not world:
				var sign:String=("attack5" if variant=="alternative" else "attack1") if int(state.dynamis[human])==1 else "ignore1"
				Marks.assign(state,human,preferred if preferred!="" else sign,human,"player")
			elif variant=="wrong":Marks.assign(state,human,"attack8",human,"player")
		I.sync(b,state);M.begin(b,state,human)
		check(I.bot_goal(human,b,actors,state)==R.v(actors[human].pos),prefix+"production guard never steers player")
		var sequence:int=int(state.target_markers.sequence);I.sync(b,state);I.sync(b,state)
		check(int(state.target_markers.sequence)==sequence,prefix+"sync idempotence")
		if b.has("sigma_path_index"):
			var entry:Dictionary=state.sigma.cooperation.entry
			if locked.is_empty():
				locked=entry.duplicate(true)
				check(entry.locked and entry.lock_boundary=="implementation_boundary",prefix+"explicit implementation lock")
				check(bool(entry.resolution.complete)==(variant not in ["wrong","omitted"]),prefix+"current observed contract at lock "+str(entry.resolution.errors))
				check(state.runtime_failures.is_empty() if variant not in ["wrong","omitted"] else true,prefix+"no invented pre-path damage")
				if variant=="late":Marks.assign(state,human,"attack8",human,"player");late_changed=true;I.sync(b,state)
				# Checkpoint/JSON restore uses actual captured state and same beat.
				state=JSON.parse_string(JSON.stringify(state));I.begin(b,actors,state)
				check(state.sigma.cooperation.entry.lock_sequence==locked.lock_sequence,prefix+"restore cannot relock")
			check(JSON.parse_string(JSON.stringify(state.sigma.cooperation.entry.resolution.roles))==JSON.parse_string(JSON.stringify(locked.resolution.roles)),prefix+"immutable locked roles across JSON numeric representation")
			for actor in 8:
				if actor not in state.sigma.roles:check(I.bot_goal(actor,b,actors,state)==R.v(actors[actor].pos),prefix+"unresolved NPC has no hidden endpoint")
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(.05,float(b.duration)-elapsed)
			var previous:Array=actors.duplicate(true);state.motion_allowances=[]
			for actor in 8:
				var speed:float=M.speed(b,state,actor);state.motion_allowances.append(speed*dt)
				var goal:Vector2=I.bot_goal(actor,b,actors,state)
				if actor==human:
					# Explicit replay-driver player input, not NPC automation or a
					# claim of native human full-course play.
					goal=R.v(actors[actor].pos) if b.has("sigma_path_index") and variant in ["wrong","omitted"] else I.raw_bot_goal(actor,b,actors,state)
				actors[actor].pos=R.v(actors[actor].pos).move_toward(goal,speed*dt)
			I.tick(b,actors,previous,state,dt);elapsed+=dt
		combat.append_array(R.evaluate(b,actors,state))
	check(state.target_markers.events.all(func(event):return event.source!="npc" or int(event.target)!=human),prefix+"no NPC marker targets human")
	check(float(state.bot_sprint_until[human])==0.0,prefix+"no automatic human Sprint")
	check(not str(state.runtime_failures).contains("marker"),prefix+"marker error never fabricated damage")
	if variant in ["wrong","omitted"]:
		check(not combat.is_empty(),prefix+"negative input has real physical consequences")
		check(Marks.marker_for(state,human)==("attack8" if variant=="wrong" else ""),prefix+"wrong/omitted sign not repaired")
	else:
		check(combat.is_empty(),prefix+"real moving combat "+str(combat.slice(0,5)))
		var stacks:Array=state.dynamis.map(func(value):return int(value));stacks.sort()
		check(stacks==[1,1,1,1,2,2,2,2],prefix+"actual final gains")
	if late_changed:
		check(not state.sigma.cooperation.latest.complete and not state.sigma.cooperation.late_events.is_empty(),prefix+"late edit is current evidence, not locked rewrite")
	var before:String=JSON.stringify(state)
	var app=MainProjection.new();app.state=state;app.encounter={"id":"p5_sigma"};app.active_profile=profile;app.player=human;app.demo=false;app.checkpoint_assisted=false
	var report:Dictionary=app.preparation_report()
	check(report.manual_preparation_complete_at_lock==(variant not in ["wrong","omitted","assist"]),prefix+"actual Main immutable lock projection")
	check(report.manual_preparation_complete==(variant not in ["wrong","omitted","assist","late"]),prefix+"actual Main current assignment projection")
	check(JSON.stringify(state)==before,prefix+"report cannot mutate combat state")
	if variant=="correct" and not receipts.has("positive"):receipts.positive=app.json_safe(state)
	if variant=="omitted":receipts.negative=app.json_safe(state)
	app.free();print("SIGMA COURSE seed",seed_value," ",human," ",variant," ",preferred," combat=",combat.size()," lock=",locked.get("resolution",{}).get("complete",false))
func _initialize()->void:call_deferred("run")
func run()->void:
	for human in 8:replay(human,"correct")
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var profile:Dictionary=profiles.filter(func(p):return p.id=="cn_moogle")[0]
	var encounter:Dictionary=E.new().build("p5_sigma",17391,profile);var c:Dictionary=encounter.beats[0].sigma_config
	var human:int=int(range(8).filter(func(actor):return int(encounter.initial_dynamis[actor])==1 and actor not in [int(c.near),int(c.far)])[0])
	for variant in ["wrong","omitted","late","alternative","assist"]:replay(human,variant)
	for preferred in ["attack2","attack3","attack4"]:replay(human,"correct",preferred)
	var eligible:int=range(8).filter(func(actor):return int(encounter.initial_dynamis[actor])==1 and actor not in [int(c.near),int(c.far)]).size()
	if eligible>=5:replay(human,"correct","ignore1")
	# Exercise generated World-zero families without modifying or forcing RNG.
	var found:Dictionary={}
	for seed_value in range(1,129):
		var generated:Dictionary=E.new().build("p5_sigma",seed_value,profile)
		var cfg:Dictionary=generated.beats[0].sigma_config
		var eligible_actors:Array=range(8).filter(func(actor):return int(generated.initial_dynamis[actor])==1 and actor not in [int(cfg.near),int(cfg.far)])
		if eligible_actors.size() in [5,6] and not found.has(eligible_actors.size()):
			found[eligible_actors.size()]=seed_value
			replay(int(eligible_actors[0]),"correct","ignore1",seed_value)
		if found.size()==2:break
	check(found.size()==2,"actual generator includes one/both World-zero cases within bounded sample")
	var file=FileAccess.open("user://sigma-cooperation-receipts.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(receipts))
	print("NPC SIGMA COOPERATION courses=",courses," cases=",cases," failures=",failures)
	quit(1 if failures else 0)
