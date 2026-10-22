extends SceneTree
const C=preload("res://scripts/hw_cooperation.gd")
const Courses=preload("res://scripts/hw_courses.gd")
const Encounter=preload("res://scripts/encounters.gd")
const Interactions=preload("res://scripts/interactions.gd")
const Rules=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var courses:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func actors(human_pos:Vector2)->Array:
	var a=[]
	for i in 8:a.append({"pos":human_pos if i in [0,4] else Vector2.ZERO})
	return a
func state(now:float,human:int=0)->Dictionary:
	return {"sim_time":now,"human_actor":human,"statuses":[{"red":{},"overflow":{}},{"red":{},"overflow":{}},{},{},{"blue":{},"sync":{}},{"blue":{},"sync":{}},{},{}],"hw":{"pending":[{"kind":"towers","round":0,"at":20.0}]}}
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var beat={"hw_tower_cooperations":[{"round":0,"actors":[0.0,1.0],"goals":[Vector2(-10,-10),Vector2(10,-10)],"reveal_window":10.0},{"round":0,"actors":[4.0,5.0],"goals":[Vector2(-10,10),Vector2(10,10)],"reveal_window":10.0}]}
	var s=state(12.0);var a=actors(Vector2(10,-10))
	check(C.replacement_actor(1,beat,a,s)==0,"legal alternate side makes NPC follow human opposite-side course")
	check(int(s.hw.hw_tower_choice_0_0)==1,"choice is preserved for restore/retry state")
	check(C.replacement_actor(0,beat,a,s)==null,"human is never steered")
	check(C.replacement_actor(2,beat,a,s)==null,"unaffected bot is unchanged")
	var early=state(9.0);check(C.replacement_actor(1,beat,a,early)==null,"future orientation is hidden before reveal")
	var omitted=state(12.0);check(C.replacement_actor(1,beat,actors(Vector2.ZERO),omitted)==null,"omission does not fabricate a choice")
	var wrong=state(12.0);check(C.replacement_actor(1,beat,actors(Vector2(18,0)),wrong)==null,"wrong position does not redirect NPC")
	var late=state(20.1);late.hw.pending=[];check(C.replacement_actor(1,beat,a,late)==null,"late choice after resolution cannot redirect NPC")
	var invalid=state(12.0);invalid.statuses[0].clear();check(C.replacement_actor(1,beat,a,invalid)==null,"missing actual rot cannot fabricate an equivalent choice")
	var restored=JSON.parse_string(JSON.stringify(s));restored.hw.pending=[];check(C.replacement_actor(1,beat,a,restored)==0,"serialized choice persists after tower resolution")
	var sync_state=state(12.0,4);var sync_actors=actors(Vector2(10,10))
	check(C.replacement_actor(5,beat,sync_actors,sync_state)==4,"sync pair has equivalent alternate-side cooperation")
	check(C.replacement_actor(4,beat,sync_actors,sync_state)==null,"human route is never overwritten")
	var next_beat={"hw_tower_cooperations":[{"round":1,"actors":[4,5],"goals":[Vector2(-10,10),Vector2(10,10)],"reveal_window":10.0}]}
	sync_state.hw.pending=[{"kind":"towers","round":1,"at":41.0}];sync_state.sim_time=33.0
	check(C.replacement_actor(5,next_beat,actors(Vector2.ZERO),sync_state)==null and not sync_state.hw.has("hw_tower_choice_0_4"),"cooperation route state clears next round")
	for human in [0,1,4,5]:
		for colour in ["red","blue"]:
			var result:=walking(human,colour,false)
			check(result.runtime_failures.is_empty(),"real full-course alternate soaker %d/%s: %s" % [human,colour,str(result.runtime_failures.slice(0,4))])
			check(result.hw.history.filter(func(e):return e.kind=="hw_tower").size()==16,"all16 actual tower judgments")
			check(result.hw.history.filter(func(e):return e.kind=="hw_blast").size()==32,"all32 actual bug and rot blasts")
			check(result.hw.history.any(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8),"all eight earn authentic debugger through real handoffs")
	var omission:=walking(0,"red",true)
	check(not omission.runtime_failures.is_empty() and omission.hw.history.any(func(e):return e.kind=="hw_tower" and e.hits.size()!=1),"omitted human movement genuinely misses tower; no NPC rescue")
	print("NPC_HW_COOPERATION checks=",checks," moving_courses=",courses," failures=",failures);quit(1 if failures else 0)

func walking(human:int,colour:String,omission:bool)->Dictionary:
	var ctx=Encounter.new();ctx.order=range(8);ctx.profile={"id":"elemental"};ctx.positions=[];ctx.labels=[]
	var observed:Array=[]
	for i in 8:
		ctx.positions.append(Rules.direction(i*45.0)*5.0);ctx.labels.append("")
		observed.append({"role":Encounter.ROLES[i],"pos":ctx.positions[i],"face":0.0})
	Courses.append_family(ctx,[0,0,0,0],colour)
	var live:Dictionary={"sim_time":0.0,"human_actor":human}
	var alternate_actor:=human+1 if human in [0,4] else human-1
	var player_lane:=0
	for b in ctx.beats:
		Interactions.begin(b,observed,live)
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(0.1,float(b.duration)-elapsed)
			var before:=observed.duplicate(true)
			for actor in 8:
				var target:=Interactions.bot_goal(actor,b,observed,live)
				if actor==human:
					# Explicit simulated player input, not application auto-control.
					# Choose the alternate only AFTER the first actual tower is visible.
					var round_index:=int(b.get("hw_tower_cooperation",{}).get("round",-1))
					var alternate:bool=round_index==0 and float(live.sim_time)>=14.0
					target=Courses.base_goal(alternate_actor if alternate else actor,b,live)
					if alternate and human in [4,5] and float(live.sim_time)<24.0:
						# Human input follows explicit safe waypoints around the outer south,
						# independent from the NPC navigation helper.
						var side:float=-1.0 if human==4 else 1.0
						var waypoints:Array=[Vector2(side*10.0,15.0),Vector2(0,18.0),Vector2(-side*10.0,15.0)]
						if player_lane<waypoints.size():
							target=waypoints[player_lane]
							if Rules.v(observed[actor].pos).distance_to(target)<0.2:player_lane+=1
					if omission:target=Rules.direction(human*45.0)*5.0
				observed[actor].pos=Rules.v(observed[actor].pos).move_toward(target,6.0*dt)
			Interactions.tick(b,observed,before,live,dt);elapsed+=dt
	courses+=1
	return live
