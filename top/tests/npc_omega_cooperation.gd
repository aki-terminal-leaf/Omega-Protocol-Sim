# SPDX-License-Identifier: MIT
extends SceneTree
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const M=preload("res://scripts/movement.gd")
const Marks=preload("res://scripts/markers.gd")
const C=preload("res://scripts/omega_cooperation.gd")
const P=preload("res://scripts/omega_preparation.gd")
const O=preload("res://scripts/p5_omega_runtime.gd")
const MainProjection=preload("res://scripts/main.gd")
var cases:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	cases+=1
	if not ok:failures+=1;print("OMEGA COOP FAIL: ",label)
func json_normal(value:Variant) -> Variant:
	# Use the same numeric representation/precision as the checkpoint writer.
	return JSON.parse_string(JSON.stringify(value))
func party(points:Array) -> Array:
	var out:Array=[]
	for actor in 8:out.append({"pos":R.v(points[actor]),"face":0.0,"role":E.ROLES[actor]})
	return out
func player_sign(state:Dictionary,phase:String) -> void:
	var result:=C.observed(state,phase)
	var human:int=int(state.human_actor)
	var kind:String=result.classes[human]
	var signs:Array=P.STOPS if kind=="stop" else (P.BINDS if kind=="bind" else P.ATTACKS)
	# Deliberately take an equivalent legal numbered sign, even if an NPC had
	# it. The real Markers event records displacement; NPCs must complement it.
	Marks.assign(state,human,"" if kind=="unmarked" else signs[0],human,"player")
func replay(mandatory:int,variant:String,human_utility:=false) -> void:
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var profile:Dictionary=profiles.filter(func(p):return p.id=="cn_moogle")[0].duplicate(true)
	profile.merge({"omega_monitor_angle":90,"omega_beetle_angle":0},true)
	var encounter:Dictionary=E.new().build("p5_omega",17391,profile)
	var cfg:Dictionary=encounter.beats[0].omega_config
	var stacks:Array=[1,1,1,1,1,1,1,1]
	for j in mandatory:stacks[int(cfg.second[j])]=2
	for actor in 8:
		if stacks.count(2)>=4:break
		if actor not in cfg.first and actor not in cfg.second:stacks[actor]=2
	var human:int=int(cfg.second[0]) if mandatory>0 else stacks.find(2)
	if human_utility:
		for actor in 8:
			if stacks[actor]==2 and actor not in cfg.first and actor not in cfg.second:human=actor
	var state:Dictionary={"sim_time":0.0,"dynamis":stacks.duplicate(),"spent":[],"lb":"","aggro":0,"seed":17391,"human_actor":human,"p5_marking_mode":"manual"}
	var actors:=party(encounter.beats[0].spawn)
	var combat:Array=[]
	var signed_second:=false
	var first_report:Dictionary={}
	var prefix:="m%d %s utility%s "%[mandatory,variant,human_utility]
	var player_sprint_until:=0.0
	var player_sprint_ready:=0.0
	var pickup_boundary:=0
	var saw_human_pickup:=false
	var first_locked:Dictionary={}
	for raw in encounter.beats:
		var b:Dictionary=raw.duplicate(true)
		# Scenario setup before the real transfer grant, never a holder write.
		if human_utility and b.has("transfers"):b.transfers.initial=cfg.first.duplicate()
		I.begin(b,actors,state)
		if state.omega.cooperation.phase=="first" and state.target_markers.events.all(func(event):return event.source!="player"):
			if human_utility:
				check(state.omega.first_roles[6]>=0 and state.omega.first_roles[7]>=0 and human not in state.omega.first_roles.slice(6),prefix+"actual NPC utilities precede eligible human Attack")
				Marks.assign(state,human,"attack2",human,"player")
			elif variant=="correct":player_sign(state,"first")
			elif variant=="wrong":Marks.assign(state,human,"attack8",human,"player")
		if b.get("omega_wait_phase","")=="second" and not signed_second:
			signed_second=true
			if human_utility:
				check(int(state.omega.cooperation.phases.second.dynamis[human])==3,prefix+"human actual first gain reaches3")
				# Player explicitly replaces their first Attack; omission is blank.
				if variant=="correct":player_sign(state,"second")
				else:Marks.assign(state,human,"",human,"player")
			elif variant=="correct" and state.omega.cooperation.phases.second.dynamis[human]==2:player_sign(state,"second")
		I.sync(b,state);M.begin(b,state,human)
		if b.has("transfers"):
			var expected_requests:Array=state.omega.second_roles.slice(6).filter(func(actor):return int(actor)>=0 and int(actor)!=human)
			check(b.bot_sprint==expected_requests,prefix+"Sprint requests from actual NPC utilities")
			for actor in expected_requests:
				check(is_equal_approx(float(state.bot_sprint_until[int(actor)]),float(state.sim_time)+10.0) and is_equal_approx(float(state.bot_sprint_ready[int(actor)]),float(state.sim_time)+60.0),prefix+"real NPC Sprint expiry and cooldown")
			pickup_boundary=state.get("tether_events",[]).size()
			if human_utility and variant=="correct" and float(state.sim_time)>=player_sprint_ready:
				# Test-driver PLAYER ability, not Movement.begin or bot Sprint.
				player_sprint_until=float(state.sim_time)+10.0;player_sprint_ready=float(state.sim_time)+60.0
		var seq:int=int(state.target_markers.sequence)
		I.sync(b,state);I.sync(b,state)
		check(int(state.target_markers.sequence)==seq,prefix+"idempotent sync "+b.title)
		if b.has("omega_wait_phase"):
			check(b.positions.all(func(point):return R.v(point)==Vector2.ZERO),prefix+"no future relative wait geometry")
		if b.get("omega_phase","")=="first" and first_report.is_empty():
			first_report=state.omega.cooperation.latest.duplicate(true)
			check(first_report.complete if variant=="correct" or human_utility else not first_report.complete,prefix+"observed first contract")
			check(first_report.mandatory.size()==mandatory,prefix+"actual compulsory II count")
			check(first_report.self_action.observed==(variant!="omitted" or human_utility),prefix+"real receipt only")
			if variant!="correct" and not human_utility:check(human not in state.omega.first_roles,prefix+"wrong/omitted human never oracle allocated")
		var elapsed:=0.0
		while elapsed<float(b.duration)-0.000001:
			var dt:=minf(0.05,float(b.duration)-elapsed)
			var previous:=actors.duplicate(true);state.motion_allowances=[]
			for actor in 8:
				var speed:=7.5 if actor==human and float(state.sim_time)<player_sprint_until else M.speed(b,state,actor)
				state.motion_allowances.append(speed*dt)
				var goal:Vector2=R.v(actors[actor].pos)
				if actor==human:
					# Explicit test-driver player input, never NPC automation.
					if not b.has("omega_phase") or variant=="correct" or (human_utility and b.get("omega_phase","")=="first"):
						goal=I.raw_bot_goal(actor,b,actors,state) if b.has("transfers") and b.transfers.wanted.size()==2 else R.v(b.positions[actor])
					# Omission driver stays at their first receiver destination;
					# no accidental center-line pickup and no future source lookup.
					if human_utility and variant=="omitted" and b.get("omega_wait_phase","")=="second":goal=R.v(actors[actor].pos)
				else:
					# Exact proposed parent hook, then unchanged physical router.
					if not C.holds(actor,b,state):goal=I.bot_goal(actor,b,actors,state)
				actors[actor].pos=R.v(actors[actor].pos).move_toward(goal,speed*dt)
			I.tick(b,actors,previous,state,dt);elapsed+=dt
		if b.has("transfers") and human_utility:
			for event in state.get("tether_events",[]).slice(pickup_boundary):
				if event.get("kind","")=="tether_pickup" and int(event.get("to",-1))==human:saw_human_pickup=true
			check((human in state.tether_holders)==(variant=="correct"),prefix+"actual player line ownership")
		if b.get("omega_monitor",false):check(not state.omega.get("monitor_resolved",false),prefix+"monitor unresolved before actual judgment")
		combat.append_array(R.evaluate(b,actors,state))
		if b.get("omega_monitor",false):check(state.omega.get("monitor_resolved",false),prefix+"monitor resolved after actual judgment")
		if b.has("world") and int(b.world.pulse)==0:
			var locked:Dictionary=state.omega.cooperation.phases[str(b.omega_phase)]
			check(locked.locked and locked.resolution==state.omega.cooperation.latest,prefix+"actual pulse resolution receipt")
			check(locked.owners_at_lock==state.target_markers.owners and int(locked.lock_sequence)==int(state.target_markers.sequence) and is_equal_approx(float(locked.lock_time),float(state.sim_time)),prefix+"actual lock owners sequence time")
			if b.omega_phase=="first":first_locked=locked.duplicate(true)
			else:
				var retained:Dictionary=state.omega.cooperation.phases.first
				check(json_normal(retained.resolution)==json_normal(first_locked.resolution),prefix+"first receipt retained after second and JSON")
				for field in ["owners_at_lock","lock_sequence","lock_time","owners_at_entry"]:
					check(json_normal(retained[field])==json_normal(first_locked[field]),prefix+"first lock metadata retained "+field)
		if b.get("omega_first_finish",false):
			check(state.omega.cooperation.phases.first.dynamis==stacks,prefix+"grant snapshot immutable")
			check(state.omega.cooperation.phases.second.dynamis==state.dynamis,prefix+"second actual32.1 snapshot")
			check(state.omega.cooperation.phases.first.resolution==first_locked.resolution,prefix+"first receipt exact before JSON")
			state=JSON.parse_string(JSON.stringify(state))
			check(json_normal(state.omega.cooperation.phases.first.resolution)==json_normal(first_locked.resolution),prefix+"first receipt same JSON normal form immediately after restore")
			I.begin(b,actors,state) # same-beat restore must not regrant or remark
			check(int(state.target_markers.sequence)==int(state.target_markers.events.back().sequence),prefix+"JSON sequence intact")
	if human_utility:check(saw_human_pickup==(variant=="correct"),prefix+"actual pickup versus omission")
	check(state.target_markers.events.all(func(event):return event.source!="npc" or int(event.target)!=human),prefix+"NPC never marks human")
	check(float(state.bot_sprint_until[human])==0.0,prefix+"no automatic human Sprint")
	check(not str(state.get("runtime_failures",[])).contains("marker"),prefix+"preparation not synthetic combat failure")
	if variant=="correct":
		check(combat.is_empty(),prefix+"actual moving-course combat "+str(combat.slice(0,5)))
		check(state.dynamis==[3,3,3,3,3,3,3,3],prefix+"actual gains")
	else:
		check(Marks.marker_for(state,human)==("attack8" if variant=="wrong" else ""),prefix+"human error remains visible")
		check(not combat.is_empty(),prefix+"negative course remains physically judged")
	# Use the actual moving-course output, not a hand-built passing receipt,
	# to exercise the production report projection in both positive/negative cases.
	var before_projection:String=JSON.stringify(state)
	var projection=MainProjection.new();projection.state=state;projection.player=human;projection.demo=false;projection.checkpoint_assisted=false
	var result:Dictionary=projection.preparation_report()
	check(result.manual_preparation_complete_at_world_pulses==(variant=="correct"),prefix+"actual Main judgment receipt projection")
	check(result.manual_preparation_complete==(variant=="correct"),prefix+"actual Main manual result never derives from endpoint alone")
	check(JSON.stringify(state)==before_projection,prefix+"opening results cannot mutate actual attempt")
	projection.free()
func lifecycle() -> void:
	var cfg:Dictionary={"profile":"cn_moogle","id":"test","first":[0,1],"second":[2,3],"monitor_angle":90,"beetle_angle":0,"standalone":true}
	var state:Dictionary={"dynamis":[1,1,2,2,2,2,1,1],"human_actor":0.0,"p5_marking_mode":"manual","sim_time":0.0}
	var b:Dictionary={"omega_config":cfg,"omega_phase":"first","positions":[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],"labels":["","","","","","","",""],"checks":[]}
	I.begin(b,party(b.positions),state)
	check(C.active(state),"JSON human0 activates manual")
	Marks.assign(state,0,"attack8",0,"player");I.sync(b,state)
	check(Marks.marker_for(state,0)=="attack8" and str(state.omega.cooperation.latest.errors).contains("world_must_be_unmarked"),"wrong World sign stays visible and reported")
	check(state.omega.first_roles.slice(0,2)==[0,1],"World identity never comes from marker")
	var seq:int=int(state.target_markers.sequence)
	I.begin(b,party(b.positions),state)
	check(int(state.target_markers.sequence)==seq,"same-beat begin no new events")
	check(C.mode(cfg,{})=="legacy_coaching","absent mode explicitly legacy")
	check(C.mode({"profile":"elemental"},{"p5_marking_mode":"manual","human_actor":0})=="legacy_coaching","other profile source pending")
	var assist:Dictionary={"dynamis":[1,1,2,2,2,2,1,1],"human_actor":0,"p5_marking_mode":"assist","sim_time":0.0}
	I.begin(b.duplicate(true),party(b.positions),assist)
	check(assist.target_markers.events.all(func(event):return event.source=="assist"),"assist source tagged")
	check(not assist.omega.cooperation.latest.self_action.observed,"assist no human receipt")
	var fresh:Dictionary={"dynamis":[1,1,2,2,2,2,1,1],"human_actor":0,"p5_marking_mode":"manual","sim_time":0.0}
	I.begin(b.duplicate(true),party(b.positions),fresh)
	check(int(fresh.omega.cooperation.phases.first.sequence)==0,"fresh reset phase boundary")
func invalid_manual() -> void:
	var cfg:Dictionary={"profile":"cn_moogle","id":"blocked","first":[0,1],"second":[2,3],"priority":range(8),"monitor_angle":90,"beetle_angle":0,"standalone":true}
	for bad in [null,-1,8,0.5,NAN,INF,"0"]:
		var state:Dictionary={"dynamis":[1,1,2,2,2,2,1,1],"p5_marking_mode":"manual","sim_time":0.0}
		if bad!=null:state.human_actor=bad
		var b:Dictionary={"omega_config":cfg,"omega_phase":"first","positions":[Vector2.ONE,Vector2.ONE,Vector2.ONE,Vector2.ONE,Vector2.ONE,Vector2.ONE,Vector2.ONE,Vector2.ONE],"labels":["","","","","","","",""],"checks":[],"bot_sprint":[0,1]}
		var actors:=party(b.positions)
		I.begin(b,actors,state);I.sync(b,state)
		check(state.omega.cooperation.mode=="manual_blocked","invalid human blocked "+str(bad))
		check(state.omega.first_roles.is_empty() and state.omega.second_roles.is_empty(),"invalid human no legacy allocation "+str(bad))
		check(state.omega.cooperation.phases.is_empty() and not state.omega.cooperation.latest.complete,"invalid human no fabricated phase "+str(bad))
		check(str(state.omega.cooperation.latest.errors).contains("invalid_manual_human_actor"),"invalid human provenance error "+str(bad))
		check(b.positions.all(func(point):return point==Vector2.ZERO) and C.holds(7,b,state) and b.bot_sprint.is_empty(),"invalid human no oracle movement "+str(bad))
		check(state.get("runtime_failures",[]).is_empty() and state.dead.is_empty(),"invalid human no synthetic damage "+str(bad))
		check(state.get("target_markers",{}).get("events",[]).is_empty(),"invalid human no self actions "+str(bad))
func contact_state() -> Dictionary:
	return {"omega":{"id":"contact","second_roles":[0,1,2,3,4,5,6,7],"cooperation":{"mode":"manual","phases":{"second":{"utility":[],"contact_sequence":1}}}},"tether_group":"contact_blaster","tether_holders":[6,7],"tether_events":[{"kind":"tether_pickup","to":6,"from":0,"line":0,"time":1.0}]}
func utility_commit() -> void:
	var pickup:Dictionary={"kind":"tether_pickup","to":7,"from":1,"line":1,"time":35.0}
	var state:=contact_state()
	C.contacts(state)
	check(state.omega.cooperation.phases.second.utility.is_empty(),"both initial owners do not fabricate pickup; old event excluded")
	state.tether_events.append({"kind":"unrelated","to":7});C.contacts(state)
	check(state.omega.cooperation.phases.second.utility.is_empty(),"unrelated event never commits utility")
	state=contact_state();state.tether_holders=[0,7];state.tether_events.append(pickup.duplicate(true));C.contacts(state)
	check(state.omega.cooperation.phases.second.utility.is_empty(),"one pickup without other owner remains provisional")
	state=contact_state();state.tether_events.append(pickup.duplicate(true));C.contacts(state)
	var p:Dictionary=state.omega.cooperation.phases.second
	check(p.utility==[6,7],"initial selected owner plus other pickup commits")
	check(p.utility_commit.event==pickup and p.utility_commit.event_index==1 and p.utility_commit.holders==[6,7],"commit preserves exact event and current holders")
	state=contact_state();state.tether_events.append(pickup.duplicate(true));state.tether_events.append({"kind":"tether_pickup","to":3,"from":6,"line":0,"time":35.1});state.tether_holders=[3,7];C.contacts(state)
	check(state.omega.cooperation.phases.second.utility.is_empty(),"ownership lost before commitment blocks historical pickup")
	state.tether_events.append({"kind":"tether_pickup","to":6,"from":3,"line":0,"time":35.2});state.tether_holders=[6,7]
	state=JSON.parse_string(JSON.stringify(state));C.contacts(state)
	check(state.omega.cooperation.phases.second.utility==[6,7],"JSON ownership and real reacquisition commit")
	check(typeof(state.tether_holders[0])==TYPE_FLOAT and state.tether_holders==[6.0,7.0],"JSON actual ownership remains untouched")
	check(state.omega.cooperation.phases.second.get("utility_commit",{}).get("holders",[])==[6,7],"JSON commit normalized local provenance")
	for bad in [6.5,true,false,NAN,INF,-1,8,"6",null]:
		state=contact_state();state.tether_holders=[bad,7];state.tether_events.append(pickup.duplicate(true));C.contacts(state)
		check(state.omega.cooperation.phases.second.utility.is_empty(),"invalid holder cannot commit "+str(bad))
		check(typeof(state.tether_holders[0])==typeof(bad),"invalid holder never rewritten "+str(bad))
	var receipt:Dictionary={"complete":true,"self_action":{"events":[{"actor":6,"sequence":9,"time":30.1}]}}
	var restored:Dictionary=json_normal(receipt)
	check(json_normal(restored)==json_normal(receipt),"receipt JSON normalization preserves values")
	restored.self_action.events[0].sequence=10.0
	check(json_normal(restored)!=json_normal(receipt),"receipt comparison detects nested provenance mutation")
func assist_player_sprint() -> void:
	# Direct second-phase runtime fixture, not a claimed physical replay.
	# Both actual utility slots, JSON integral IDs, and all-NPC demo are covered.
	for raw_human in [6,7,6.0,-1]:
		var human:int=int(raw_human)
		var prefix:="assist Sprint human%s "%str(raw_human)
		var cfg:Dictionary={"profile":"cn_moogle","id":"assist_sprint","first":[0,1],"second":[2,3],"monitor_angle":90,"beetle_angle":0,"standalone":true}
		var state:Dictionary={"dynamis":[1,1,2,2,2,2,1,1],"human_actor":raw_human,"p5_marking_mode":"assist","sim_time":0.0}
		var b:Dictionary={"omega_config":cfg,"omega_phase":"first","positions":[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],"labels":["","","","","","","",""],"checks":[],"bot_sprint":range(8)}
		var actors:=party(b.positions)
		I.begin(b,actors,state)
		check((human<0 and b.bot_sprint==range(8)) or (human>=0 and human not in b.bot_sprint),prefix+"baseline requests exclude real player only")
		# Explicit actual-stack fixture; no forecast, player input or owner writes.
		state.dynamis=[2,2,2,2,2,2,3,3];state.sim_time=34.2
		C.capture(state,"second")
		b.omega_phase="second"
		b.transfers={"group":"assist_sprint_blaster","initial":[0,1],"sources":[Vector2(-10,0),Vector2(10,0)]}
		b.bot_sprint=range(8)
		I.begin(b,actors,state)
		var expected:Array=[6,7].filter(func(actor):return actor!=human)
		check(state.omega.second_roles.slice(6)==[6,7],prefix+"actual three-stack utility roles")
		check(b.bot_sprint==expected,prefix+"only actual NPC utilities requested")
		check(state.target_markers.events.all(func(event):return event.source=="assist") and not state.omega.cooperation.latest.self_action.observed,prefix+"assisted marking provenance without player receipt")
		check(state.tether_holders==[0,1],prefix+"no synthetic ownership transfer")
		for actor in expected:
			check(is_equal_approx(float(state.bot_sprint_until[actor]),44.2) and is_equal_approx(float(state.bot_sprint_ready[actor]),94.2),prefix+"NPC actual ten-second Sprint sixty-second cooldown")
		if human>=0:
			check(float(state.bot_sprint_until[human])==0.0 and float(state.bot_sprint_ready[human])==0.0,prefix+"player bot Sprint untouched")
			check(M.speed(b,state,human)==6.0,prefix+"player ordinary speed remains unchanged")
		var sprint_events:Array=state.timeline.filter(func(event):return event.kind=="coaching_sprint")
		check(sprint_events.size()==expected.size() and sprint_events.all(func(event):return int(event.actor) in expected),prefix+"no coaching Sprint event targets player")
		state.sim_time=35.2;I.sync(b,state)
		check(state.timeline.filter(func(event):return event.kind=="coaching_sprint").size()==sprint_events.size(),prefix+"repeat sync does not renew Sprint")
		for actor in expected:check(is_equal_approx(float(state.bot_sprint_until[actor]),44.2),prefix+"expiry unchanged after sync")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	lifecycle();invalid_manual();utility_commit();assist_player_sprint()
	for mandatory in [0,1,2]:
		for variant in ["correct","omitted","wrong"]:replay(mandatory,variant)
	for variant in ["correct","omitted"]:replay(0,variant,true)
	print("NPC OMEGA COOPERATION cases=",cases," failures=",failures)
	quit(1 if failures else 0)
