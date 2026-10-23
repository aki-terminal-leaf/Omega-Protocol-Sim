extends SceneTree
# Pure unit gate for scripts/synergy_assignment.gd (no production wiring claims).
const Assign=preload("res://scripts/synergy_assignment.gd")
const LEFT:=[2,0,4,6]
const RIGHT:=[3,1,5,7]
const SHAPES:=["circle","cross","triangle","square"]
var checks:=0
var failures:Array=[]
var assignments:=0

func config()->Dictionary:
	return {"profile_id":"elemental","left":LEFT.duplicate(),"right":RIGHT.duplicate(),"shape_order":SHAPES.duplicate()}

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<50:failures.append(label)

func records(symbols:Array)->Array:
	var result:Array=[]
	for actor in range(8):result.append({"actor":actor,"symbol":symbols[actor]})
	return result

# Source invariants checked independently of the module's loop structure.
func verify(symbols:Array,label:String)->Dictionary:
	var input:=records(symbols)
	var cfg:=config()
	var input_copy:=input.duplicate(true)
	var cfg_copy:=cfg.duplicate(true)
	var out:=Assign.assign(input,cfg)
	check(input==input_copy and cfg==cfg_copy,label+":input_unchanged")
	if out.is_empty():
		check(false,label+":empty");return out
	check(out.actor_symbols==symbols,label+":symbols_preserved")
	for side in [0,1]:
		var members:Array=range(8).filter(func(a):return out.actor_sides[a]==side)
		check(members.size()==4,label+":four_per_side")
		var seen:Array=members.map(func(a):return symbols[a])
		for shape in SHAPES:check(seen.count(shape)==1,label+":one_each_"+shape)
	for index in range(4):
		var pair:Array=[out.route_order[index*2],out.route_order[index*2+1]]
		var owners:Array=range(8).filter(func(a):return symbols[a]==SHAPES[index])
		pair.sort()
		check(pair==owners,label+":pair_membership_"+SHAPES[index])
		check(out.actor_sides[out.route_order[index*2]]==0 and out.actor_sides[out.route_order[index*2+1]]==1,label+":route_sides")
		var a:int=owners[0];var b:int=owners[1]
		var same:=(a in LEFT)==(b in LEFT)
		if not same:
			check(a not in out.crossed and b not in out.crossed,label+":opposite_no_cross")
		else:
			var queue:Array=LEFT if a in LEFT else RIGHT
			var lower:int=a if queue.find(a)>queue.find(b) else b
			var upper:int=b if lower==a else a
			check(lower in out.crossed and upper not in out.crossed,label+":lower_only_cross")
	for actor in range(8):
		var initial:=0 if actor in LEFT else 1
		check((actor in out.crossed)==(out.actor_sides[actor]!=initial),label+":crossed_consistent")
	var trip:Variant=JSON.parse_string(JSON.stringify(input))
	check(trip is Array and Assign.assign(trip,JSON.parse_string(JSON.stringify(cfg)))==out,label+":json_roundtrip_input")
	var out_trip:Variant=JSON.parse_string(JSON.stringify(out))
	check(out_trip is Dictionary and out_trip.size()==5,label+":json_output")
	return out

func blocked(input:Array,cfg:Dictionary,label:String)->void:
	check(Assign.assign(input,cfg).is_empty(),"blocked:"+label)

func _init()->void:
	# Controlled order [1,0,3,2,5,4,7,6] as pair labels: actors (1,0),(3,2),(5,4),(7,6) share symbols.
	var ctrl:=["circle","circle","cross","cross","triangle","triangle","square","square"]
	var out:=verify(ctrl,"controlled")
	check(not out.is_empty() and out.crossed.is_empty(),"controlled:nobody_crosses")
	# One duplicate each side: left[2,0,4,6] circle twice (2,4), right cross twice (3,5).
	var one:=["triangle","triangle","circle","cross","circle","cross","square","square"]
	out=verify(one,"one_dupe")
	check(not out.is_empty() and out.crossed==[4,5],"one_dupe:lower_only")
	# Two duplicates each side: left 2,0 circle / 4,6 cross; right 3,1 triangle / 5,7 square.
	var two:=["circle","triangle","circle","triangle","cross","square","cross","square"]
	out=verify(two,"two_dupe")
	check(not out.is_empty() and out.crossed==[0,1,6,7],"two_dupe:lower_two_each")
	# Exhaust 2520 = C(8,2)*C(6,2)*C(4,2) labeled symbol pair assignments.
	for a in range(8):
		for b in range(a+1,8):
			var rest1:Array=range(8).filter(func(x):return x!=a and x!=b)
			for i in range(6):
				for j in range(i+1,6):
					var rest2:Array=rest1.filter(func(x):return x!=rest1[i] and x!=rest1[j])
					for k in range(4):
						for l in range(k+1,4):
							var symbols:Array=["square","square","square","square","square","square","square","square"]
							symbols[a]="circle";symbols[b]="circle"
							symbols[rest1[i]]="cross";symbols[rest1[j]]="cross"
							symbols[rest2[k]]="triangle";symbols[rest2[l]]="triangle"
							verify(symbols,"exhaust%d"%assignments)
							assignments+=1
	check(assignments==2520,"exhaust:count_2520")
	# Normalization via Signs.symbol_name; aliases accepted.
	var alias:=records(["o","O","x","×","△","triangle","□","square"])
	check(Assign.assign(alias,config()).get("actor_symbols",[])==ctrl,"alias_normalized")
	check(not Assign.assign(JSON.parse_string(JSON.stringify(records(ctrl))),config()).is_empty(),"json_float_actors_ok")
	# Blocked cases.
	var good:=records(ctrl)
	blocked(good.slice(0,7),config(),"partial")
	var dup:=good.duplicate(true);dup[1].actor=0;blocked(dup,config(),"duplicate_actor")
	var frac:=good.duplicate(true);frac[1].actor=1.5;blocked(frac,config(),"fractional")
	var inf:=good.duplicate(true);inf[1].actor=INF;blocked(inf,config(),"inf")
	var nan:=good.duplicate(true);nan[1].actor=NAN;blocked(nan,config(),"nan")
	var oob:=good.duplicate(true);oob[1].actor=8;blocked(oob,config(),"out_of_range")
	var strid:=good.duplicate(true);strid[1].actor="1";blocked(strid,config(),"string_actor")
	for marker in ["stack","flare","cannon","","star"]:
		var bad:=good.duplicate(true);bad[1].symbol=marker;blocked(bad,config(),"marker_"+marker)
	var nonstr:=good.duplicate(true);nonstr[1].symbol=1;blocked(nonstr,config(),"symbol_nonstring")
	var missing:=good.duplicate(true);missing[1].erase("symbol");blocked(missing,config(),"missing_symbol")
	var extra:=good.duplicate(true);extra[1]["position"]=Vector2.ZERO;blocked(extra,config(),"extra_field")
	blocked(records(["circle","circle","circle","cross","triangle","triangle","square","square"]),config(),"three_circles")
	var c:=config();c.profile_id="hector";blocked(good,c,"non_elemental")
	c=config();c.erase("profile_id");blocked(good,c,"no_profile")
	c=config();c.shape_order=["circle","cross","triangle","star"];blocked(good,c,"unknown_shape")
	c=config();c.shape_order=["o","cross","triangle","square"];blocked(good,c,"noncanonical_shape")
	c=config();c.shape_order=["circle","circle","triangle","square"];blocked(good,c,"dup_shape")
	c=config();c.left=[2,0,4,3];blocked(good,c,"overlap_groups")
	c=config();c.left=[2,0,4];blocked(good,c,"short_group")
	c=config();c.right=[3,1,5,8];blocked(good,c,"group_oob")
	c=config();c.right=[3,1,5,7.5];blocked(good,c,"group_fractional")
	blocked(good,{},"empty_config")
	print("SYNERGY_ASSIGNMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"assignments":assignments}))
	quit(0 if failures.is_empty() else 1)
