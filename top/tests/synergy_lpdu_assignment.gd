extends SceneTree
# Pure unit gate for LPDU profile of scripts/synergy_assignment.gd (no production wiring claims).
# Source contract: left MT/H1/M1/R1 [0,2,4,6], right ST/H2/M2/R2 [1,3,5,7] north-to-south;
# same-side duplicate => only the later (southern) actor crosses. Fire BPOG order cross,square,circle,triangle.
const Assign=preload("res://scripts/synergy_assignment.gd")
const LEFT:=[0,2,4,6]
const RIGHT:=[1,3,5,7]
const ORDER:=["cross","square","circle","triangle"]
const ALL:=["circle","cross","triangle","square"]
var checks:int=0
var failures:Array=[]
var assignments:int=0

func config()->Dictionary:
	return {"profile_id":"lpdu","left":LEFT.duplicate(),"right":RIGHT.duplicate(),"shape_order":ORDER.duplicate()}

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<50:failures.append(label)

func records(symbols:Array)->Array:
	var result:Array=[]
	for actor in range(8):result.append({"actor":actor,"symbol":symbols[actor]})
	return result

# Independent oracle: per shape pair, same original side => later-ranked actor crosses.
func oracle(symbols:Array)->Dictionary:
	var sides:Array=[]
	for actor in range(8):sides.append(0 if actor in LEFT else 1)
	var crossed:Array=[]
	for shape in ALL:
		var owners:Array=[]
		for actor in range(8):
			if symbols[actor]==shape:owners.append(actor)
		var a:int=owners[0]
		var b:int=owners[1]
		if sides[a]==sides[b]:
			var queue:Array=LEFT if sides[a]==0 else RIGHT
			var later:int=a if queue.find(a)>queue.find(b) else b
			crossed.append(later)
	for actor in crossed:sides[actor]=1-int(sides[actor])
	crossed.sort()
	var route:Array=[]
	for shape in ORDER:
		var west:int=-1
		var east:int=-1
		for actor in range(8):
			if symbols[actor]==shape:
				if int(sides[actor])==0:west=actor
				else:east=actor
		route.append_array([west,east])
	return {"profile_id":"lpdu","actor_sides":sides,"crossed":crossed,"route_order":route,"actor_symbols":symbols.duplicate()}

func verify(symbols:Array,label:String)->Dictionary:
	var input:Array=records(symbols)
	var cfg:Dictionary=config()
	var input_copy:Array=input.duplicate(true)
	var cfg_copy:Dictionary=cfg.duplicate(true)
	var out:Dictionary=Assign.assign(input,cfg)
	check(input==input_copy and cfg==cfg_copy,label+":input_unchanged")
	if out.is_empty():
		check(false,label+":empty");return out
	var expected:Dictionary=oracle(symbols)
	check(str(out.get("profile_id",""))=="lpdu",label+":profile_lpdu")
	check(out.get("actor_sides")==expected.actor_sides,label+":sides")
	check(out.get("crossed")==expected.crossed,label+":crossed")
	check(out.get("route_order")==expected.route_order,label+":route")
	check(out.get("actor_symbols")==symbols,label+":symbols")
	# Invariant: each side holds exactly one of each shape.
	for side in [0,1]:
		var seen:Array=[]
		for actor in range(8):
			if int(out.actor_sides[actor])==side:seen.append(symbols[actor])
		check(seen.size()==4,label+":four_per_side")
		for shape in ALL:check(seen.count(shape)==1,label+":one_each_"+shape)
	var trip_in:Variant=JSON.parse_string(JSON.stringify(input))
	var trip_cfg:Variant=JSON.parse_string(JSON.stringify(cfg))
	check(trip_in is Array and trip_cfg is Dictionary and Assign.assign(trip_in,trip_cfg)==out,label+":json_roundtrip_input")
	var out_trip:Variant=JSON.parse_string(JSON.stringify(out))
	check(out_trip is Dictionary and out_trip.size()==5 and str(out_trip.get("profile_id",""))=="lpdu",label+":json_output")
	return out

func blocked(input:Array,cfg:Dictionary,label:String)->void:
	check(Assign.assign(input,cfg).is_empty(),"blocked:"+label)

func _init()->void:
	# Controlled: MT(0)/H1(2) share cross. LPDU => H1 (later, south) crosses.
	var ctrl:Array=["cross","circle","cross","square","circle","triangle","triangle","square"]
	var out:Dictionary=verify(ctrl,"controlled_mt_h1")
	check(not out.is_empty() and 2 in out.get("crossed",[]) and 0 not in out.get("crossed",[]),"controlled:h1_crosses")
	# Same symbols under existing Elemental queues [2,0,4,6]/[3,1,5,7] => MT crosses.
	var elemental:Dictionary={"profile_id":"elemental","left":[2,0,4,6],"right":[3,1,5,7],"shape_order":["circle","cross","triangle","square"]}
	var eout:Dictionary=Assign.assign(records(ctrl),elemental)
	check(not eout.is_empty() and 0 in eout.get("crossed",[]) and 2 not in eout.get("crossed",[]),"controlled:elemental_mt_crosses")
	check(str(eout.get("profile_id",""))=="elemental","controlled:elemental_profile_preserved")
	# Two duplicate pairs per side.
	var two:Array=["circle","triangle","circle","triangle","cross","square","cross","square"]
	out=verify(two,"two_dupe")
	check(not out.is_empty() and out.get("crossed")==[2,3,6,7],"two_dupe:later_each")
	# No duplicates: nobody crosses.
	out=verify(["circle","circle","cross","cross","triangle","triangle","square","square"],"opposite")
	check(not out.is_empty() and out.get("crossed")==[],"opposite:no_cross")
	# Exhaustive: base-4 enumeration filtered to exactly two of each shape (8!/(2!^4)=2520).
	for code in range(65536):
		var symbols:Array=[]
		var n:int=code
		for _i in range(8):
			symbols.append(ALL[n%4]);n=n/4
		var ok:bool=true
		for shape in ALL:
			if symbols.count(shape)!=2:ok=false
		if not ok:continue
		verify(symbols,"exhaust%d"%assignments)
		assignments+=1
	check(assignments==2520,"exhaust:count_2520")
	# Blocked inputs.
	var good:Array=records(ctrl)
	blocked(good.slice(0,7),config(),"partial")
	var dup:Array=good.duplicate(true);dup[1].actor=0;blocked(dup,config(),"duplicate_actor")
	var frac:Array=good.duplicate(true);frac[1].actor=1.5;blocked(frac,config(),"fractional")
	var inf:Array=good.duplicate(true);inf[1].actor=INF;blocked(inf,config(),"inf")
	var nan:Array=good.duplicate(true);nan[1].actor=NAN;blocked(nan,config(),"nan")
	var oob:Array=good.duplicate(true);oob[1].actor=8;blocked(oob,config(),"out_of_range")
	var strid:Array=good.duplicate(true);strid[1].actor="1";blocked(strid,config(),"string_actor")
	for marker in ["stack","flare","","star"]:
		var bad:Array=good.duplicate(true);bad[1].symbol=marker;blocked(bad,config(),"marker_"+marker)
	var nonstr:Array=good.duplicate(true);nonstr[1].symbol=1;blocked(nonstr,config(),"symbol_nonstring")
	var missing:Array=good.duplicate(true);missing[1].erase("symbol");blocked(missing,config(),"missing_symbol")
	var extra:Array=good.duplicate(true);extra[1]["position"]=Vector2.ZERO;blocked(extra,config(),"extra_field")
	blocked(records(["cross","cross","cross","square","circle","triangle","triangle","square"]),config(),"three_cross")
	# Blocked configs.
	var c:Dictionary=config();c.profile_id="LPDU";blocked(good,c,"case_mismatch_profile")
	c=config();c.profile_id="lpdu ";blocked(good,c,"padded_profile")
	c=config();c.profile_id="aether";blocked(good,c,"unknown_profile")
	c=config();c.erase("profile_id");blocked(good,c,"no_profile")
	c=config();c.shape_order=["cross","square","circle","star"];blocked(good,c,"unknown_shape")
	c=config();c.shape_order=["x","square","circle","triangle"];blocked(good,c,"noncanonical_shape")
	c=config();c.shape_order=["cross","cross","circle","triangle"];blocked(good,c,"dup_shape")
	c=config();c.shape_order=["cross","square","circle"];blocked(good,c,"short_order")
	c=config();c.left=[0,2,4,1];blocked(good,c,"overlap_groups")
	c=config();c.left=[0,2,4];blocked(good,c,"short_group")
	c=config();c.right=[1,3,5,8];blocked(good,c,"group_oob")
	c=config();c.right=[1,3,5,7.5];blocked(good,c,"group_fractional")
	blocked(good,{},"empty_config")
	print("SYNERGY_LPDU_ASSIGNMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures.size(),"failure_labels":failures,"assignments":assignments}))
	quit(0 if failures.is_empty() else 1)
