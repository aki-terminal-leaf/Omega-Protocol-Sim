extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Encounter = preload("res://scripts/encounters.gd")
var failures = 0
var assertions = 0
func check(condition: bool, name: String) -> void:
	assertions += 1
	if not condition: failures += 1; print("NEGATIVE TEST FAIL: ", name)
func actor(p: Vector2, role := "D1", face := 0) -> Dictionary: return {"pos": p, "role": role, "face": face}
func state() -> Dictionary: return {"dynamis": [0,0,0,0,0,0,0,0], "spent": [], "lb": "", "lb_actor": -1, "aggro": 0}
func _initialize() -> void:
	var party = [actor(Vector2(1,0)),actor(Vector2(9,0))]
	check(Rules.contains({"kind":"circle","radius":2},Vector2(2,0),party), "circle boundary included")
	check(not Rules.contains({"kind":"circle","radius":2},Vector2(2.01,0),party), "circle outside excluded")
	check(Rules.contains({"kind":"donut","inner":3,"radius":7},Vector2(4,0),party),"donut hit")
	check(not Rules.contains({"kind":"donut","inner":3,"radius":7},Vector2(2,0),party),"donut inner safe")
	check(Rules.contains({"kind":"line","angle":90,"width":4,"length":8},Vector2(4,1),party),"forward beam hit")
	check(not Rules.contains({"kind":"line","angle":90,"width":4,"length":8},Vector2(-4,1),party),"beam behind safe")
	check(not Rules.same_members([0,0],[0,1]),"duplicate roles rejected")
	var tower = {"kind":"tower","pos":Vector2.ZERO,"radius":2,"rule":"count","count":1,"required":[0],"name":"Tower"}
	check(Rules.evaluate({"shapes":[tower]},party,state()).is_empty(),"correct tower accepted")
	party[0].pos=Vector2(8,0)
	check(not Rules.evaluate({"shapes":[tower]},party,state()).is_empty(),"empty tower rejected")
	party[1].pos=Vector2(1,0)
	check(not Rules.evaluate({"shapes":[tower]},party,state()).is_empty(),"wrong tower debuff rejected")
	party[0].pos=Vector2.ZERO
	check(not Rules.evaluate({"shapes":[tower]},party,state()).is_empty(),"overfilled tower rejected")
	party[1].pos=Vector2(20.1,0)
	check(not Rules.evaluate({},party,state()).is_empty(),"death wall rejected")
	var profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var encounter = Encounter.new().build("p3_monitors",47,profiles[0])
	var b: Dictionary = encounter.beats[0]
	party = []
	for i in 8: party.append(actor(b.positions[i],Encounter.ROLES[i],b.facing.get(i,0)))
	check(Rules.evaluate(b,party,state()).is_empty(),"monitor valid layout accepted")
	var owner: int = encounter.assignments[0]
	party[owner].face += 180
	check(not Rules.evaluate(b,party,state()).is_empty(),"wrong monitor facing rejected")
	encounter = Encounter.new().build("p5_dynamis",47,profiles[0]); b=encounter.beats[0];party=[]
	for i in 8:party.append(actor(b.positions[i],Encounter.ROLES[i]))
	var valid_state = state()
	check(Rules.evaluate(b,party,valid_state).is_empty(),"world geometry accepted")
	check(valid_state.dynamis.count(1)==6,"exactly six world gains")
	party[int(b.world.near_path[1])].pos=party[int(b.world.near)].pos+Vector2(0.1,0)
	check(not Rules.evaluate(b,party,state()).is_empty(),"world clipping rejected")
	party=[actor(Vector2.ZERO),actor(Vector2(1,0)),actor(Vector2(10,0))]
	check(Rules.chain(0,false,party)==[0,1,0],"nearest bounce-back remains eligible")
	check(Rules.chain(0,true,party)==[0,2,0],"furthest bounce-back remains eligible")
	check(Encounter.select_monitors([2,2,2,2,1,1,1,1],[0,4],[1,5]).has(1),"second-in-line two-stack priority")
	check(not Encounter.select_monitors([2,2,2,2,1,1,1,1],[0,4],[1,5]).has(0),"first-in-line cannot monitor")
	b={"checks":[{"kind":"lb","type":"healer","eligible":[2],"name":"Magic Number"}]}
	party=[]
	for i in 8:party.append(actor(Vector2(i,0)))
	check(not Rules.evaluate(b,party,state()).is_empty(),"missing healer LB rejected")
	var wrong =state();wrong.lb="tank";wrong.lb_actor=0
	check(not Rules.evaluate(b,party,wrong).is_empty(),"wrong LB type rejected")
	var correct =state();correct.lb="healer";correct.lb_actor=2
	check(Rules.evaluate(b,party,correct).is_empty(),"correct LB accepted")
	correct.lb="healer";correct.lb_actor=2
	check(not Rules.evaluate(b,party,correct).is_empty(),"Brilliant Dynamis cannot be reused")
	party=[]
	for i in 8: party.append(actor(Vector2((i / 2) * 4, (i % 2) * 0.5)))
	var fist_check = {"kind":"fists","colours":[0,1,0,1,0,1,0,1]}
	check(Rules.evaluate({"checks":[fist_check]},party,state()).is_empty(),"opposite-colour fists accepted")
	fist_check.colours[1]=0
	check(not Rules.evaluate({"checks":[fist_check]},party,state()).is_empty(),"same-colour fists rejected")
	party=[actor(Vector2(-18,0)),actor(Vector2(18,0))]
	check(not Rules.evaluate({"checks":[{"kind":"distance","a":0,"b":1,"min":18,"max":29}]},party,state()).is_empty(),"Mid Glitch landing too far rejected")
	check(Rules.evaluate({"checks":[{"kind":"distance","a":0,"b":1,"min":32,"max":40}]},party,state()).is_empty(),"Remote Glitch landing accepted")
	encounter=Encounter.new().build("p6_arrow_wave",47,profiles[0])
	var overlap_snapshots = 0
	for item in encounter.beats:
		var arrow=false;var beam=false
		for shape in item.shapes:
			if shape.name == "Concurrent Cosmo Arrow": arrow=true
			if shape.name == "Wave Cannon spread": beam=true
		if arrow and beam:overlap_snapshots+=1
	check(overlap_snapshots==2,"Arrow and Wave must coexist on both spread snapshots")
	for seed_value in range(1, 17):
		var loop = Encounter.new().build("p1_loop", seed_value, profiles[0])
		var tower_points: Array = []
		var angles_valid = true
		for item in loop.beats:
			var points: Array = []
			for shape in item.shapes:
				if shape.kind == "tower":
					points.append(shape.pos)
					if not tower_points.has(shape.pos): tower_points.append(shape.pos)
			var gap = absf(rad_to_deg(points[0].angle_to(points[1])))
			if absf(gap - 90) > 0.01 and absf(gap - 180) > 0.01: angles_valid = false
		check(tower_points.size() == 8, "all eight Program Loop tower locations exactly once")
		check(angles_valid, "Program Loop paired towers 90 or 180 degrees apart")
	for role in 8:
		for slot in 8:
			var first=Encounter.new().build("p1_loop",921,profiles[0],role,slot)
			var repeated=Encounter.new().build("p1_loop",921,profiles[0],role,slot)
			check(first==repeated,"seed determinism")
			check(first.assignments[slot]==role,"forced assignment")
	print("RULE ASSERTIONS ",assertions," FAILURES ",failures)
	quit(1 if failures else 0)
