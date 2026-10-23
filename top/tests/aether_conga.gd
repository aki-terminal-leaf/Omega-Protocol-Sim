extends SceneTree
# Pure unit gate for scripts/aether_conga.gd (no production wiring/runtime claims).
const Conga=preload("res://scripts/aether_conga.gd")
const SHAPES:=["cross","square","circle","triangle"]
const XS:=[3.0,7.0,0.0,5.0,1.0,6.0,2.0,4.0] # independent fixed horizontal order
var checks:=0
var failures:Array=[]
var assignments:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<50:failures.append(label)

func pos(xs:Array,y:float=0.0)->Array:
	var r:Array=[]
	for i in range(8):r.append(Vector2(xs[i],y+float(i)*0.3))
	return r

func records(symbols:Array)->Array:
	var r:Array=[]
	for a in range(8):r.append({"actor":a,"symbol":symbols[a]})
	return r

func enumerate(prefix:Array,counts:Dictionary,out:Array)->void:
	if prefix.size()==8:out.append(prefix.duplicate());return
	for s in SHAPES:
		if counts[s]<2:
			counts[s]+=1;prefix.append(s)
			enumerate(prefix,counts,out)
			prefix.pop_back();counts[s]-=1

func verify(symbols:Array,positions:Array,label:String)->Dictionary:
	var input:=records(symbols);var ic:=input.duplicate(true);var pc:=positions.duplicate()
	var out:=Conga.assign(input,positions)
	check(input==ic and positions==pc,label+":input_unchanged")
	if out.is_empty():check(false,label+":empty");return out
	check(out.profile_id=="aether" and out.crossed==[] and out.actor_symbols==symbols,label+":shape")
	for k in range(4):
		var owners:Array=range(8).filter(func(a):return symbols[a]==SHAPES[k])
		var lo:int=owners[0] if positions[owners[0]].x<positions[owners[1]].x else owners[1]
		var hi:int=owners[1] if lo==owners[0] else owners[0]
		check(out.route_order[k*2]==lo and out.route_order[k*2+1]==hi,label+":route_"+SHAPES[k])
		check(out.actor_sides[lo]==0 and out.actor_sides[hi]==1,label+":sides_"+SHAPES[k])
	return out

func test_all()->void:
	var all:Array=[];enumerate([],{"cross":0,"square":0,"circle":0,"triangle":0},all)
	check(all.size()==2520,"count_2520")
	var p:=pos(XS)
	for s in all:
		var out:=verify(s,p,"all")
		if not out.is_empty():assignments+=1
		# metamorphic: translation and positive x scale keep output
		var t:Array=p.map(func(v):return Vector2(v.x*2.5-40.0,v.y+9.0))
		check(Conga.assign(records(s),t)==out,"metamorphic")
		# reversed x flips every pair
		var rv:Array=p.map(func(v):return Vector2(-v.x,v.y))
		var ro:=Conga.assign(records(s),rv)
		check(not ro.is_empty() and range(8).all(func(a):return ro.actor_sides[a]==1-out.actor_sides[a]),"reversed_flip")

func test_cases()->void:
	var s:=["cross","cross","square","square","circle","circle","triangle","triangle"]
	# partner crossing: swapping only actor0/1 x flips cross only
	var a:=pos([0,1,2,3,4,5,6,7]);var b:=pos([1,0,2,3,4,5,6,7])
	var oa:=verify(s,a,"base");var ob:=verify(s,b,"partner_swap")
	check(oa.route_order.slice(0,2)==[0,1] and ob.route_order.slice(0,2)==[1,0] and oa.route_order.slice(2)==ob.route_order.slice(2),"partner_cross")
	# unrelated crossing: actor1 passes actor2 (other shape) -> no change
	var c:=pos([0,2.5,2,3,4,5,6,7])
	check(verify(s,c,"unrelated").route_order==oa.route_order,"unrelated_cross")
	check(Conga.assign(records(s),pos([0,0.02,2,3,4,5,6,7])).is_empty(),"same_tie_reject")
	check(Conga.assign(records(s),pos([0,0,2,3,4,5,6,7])).is_empty(),"same_exact_tie_reject")
	check(not Conga.assign(records(s),pos([0,1,1,3,4,5,6,7])).is_empty(),"diff_tie_legal")
	check(not Conga.assign(records(["x","×","□","square","o","○","△","triangle"]),a).is_empty(),"aliases")
	var bad_pos:Array=[a.slice(0,7),a.map(func(v):return v)+[Vector2.ZERO]]
	var nan:=a.duplicate();nan[3]=Vector2(NAN,0);bad_pos.append(nan)
	var inf:=a.duplicate();inf[2]=Vector2(0,INF);bad_pos.append(inf)
	var nv:=a.duplicate();nv[1]=[1,0];bad_pos.append(nv)
	for i in range(bad_pos.size()):check(Conga.assign(records(s),bad_pos[i]).is_empty(),"bad_pos_%d"%i)
	var bad:Array=[]
	var r:=records(s);r.pop_back();bad.append(r)
	r=records(s);r[7]={"actor":0,"symbol":"triangle"};bad.append(r)
	r=records(s);r[2]={"actor":"2","symbol":"square"};bad.append(r)
	r=records(s);r[2]={"actor":2.5,"symbol":"square"};bad.append(r)
	r=records(s);r[2]={"actor":8,"symbol":"square"};bad.append(r)
	r=records(s);r[2]={"actor":2,"symbol":3};bad.append(r)
	r=records(s);r[2]={"actor":2,"symbol":"cross"};bad.append(r)
	r=records(s);r[2]={"actor":2,"symbol":"stack"};bad.append(r)
	r=records(s);r[2]={"symbol":"square"};bad.append(r)
	r=records(s);r[2]=null;bad.append(r)
	r=records(s);r[2]={"actor":2,"symbol":"square","future":true};bad.append(r)
	r=records(s);r[2]={"actor":NAN,"symbol":"square"};bad.append(r)
	for i in range(bad.size()):check(Conga.assign(bad[i],a).is_empty(),"bad_rec_%d"%i)
	r=records(s);r[2]={"actor":2.0,"symbol":"square"}
	check(not Conga.assign(r,a).is_empty(),"json_float_actor")
	for so in [["cross","square","circle"],["cross","cross","circle","triangle"],["cross","square","circle","stack"],["cross",1,"circle","triangle"]]:
		check(Conga.assign(records(s),a,so).is_empty(),"bad_shape_order")
	var alt:=Conga.assign(records(s),a,["triangle","circle","square","cross"])
	check(alt.route_order==[6,7,4,5,2,3,0,1],"alt_shape_order")

func test_line()->void:
	var slots:=Conga.initial_slots()
	check(slots.size()==8 and slots[0]==Vector2(-6.3,0) and is_equal_approx(slots[7].x-slots[0].x,12.6),"slots")
	check(Conga.initial_slots(NAN).is_empty() and Conga.initial_slots(0).is_empty() and Conga.initial_slots(1.8,INF).is_empty(),"slots_invalid")
	var p:=pos(XS)
	for rank in range(8):
		var human:=1
		var hp:=p.duplicate();hp[human]=Vector2(slots[rank].x+0.2,5.0);var hc:=hp.duplicate()
		var out:=Conga.npc_line_goals(hp,human)
		check(hp==hc,"human_input_unchanged")
		check(out.reserved_slot==rank and out.goals.size()==7 and not out.goals.has(human),"reserve_%d"%rank)
		check(not out.goals.values().has(slots[rank]),"reserved_free_%d"%rank)
		var npcs:Array=range(8).filter(func(a):return a!=human)
		npcs.sort_custom(func(x,y):return hp[x].x<hp[y].x)
		check(out.npc_order==npcs,"npc_relative_order")
		var gx:Array=npcs.map(func(a):return out.goals[a].x)
		var sorted:=gx.duplicate();sorted.sort()
		check(gx==sorted,"npc_goals_monotone_%d"%rank)
	var demo:=Conga.npc_line_goals(p,-1)
	check(demo.reserved_slot==-1 and demo.goals.size()==8 and demo.npc_order==[2,4,6,0,7,3,5,1] and demo.goals[2]==slots[0],"demo")
	var tie:=pos([0,0,1,2,3,4,5,6])
	check(Conga.npc_line_goals(tie,-1).npc_order.slice(0,2)==[0,1],"tie_index")
	check(Conga.npc_line_goals(tie,-1,[7,6,5,4,3,2,1,0]).npc_order.slice(0,2)==[1,0],"tie_previous")
	check(Conga.npc_line_goals(pos([0,1,2,3,4,5,6,7]),-1,[7,6,5,4,3,2,1,0]).npc_order==[0,1,2,3,4,5,6,7],"previous_ties_only")
	for h in [-2,8,99]:check(Conga.npc_line_goals(p,h).is_empty(),"bad_human")
	check(Conga.npc_line_goals(p,0,[0,1,2]).is_empty() and Conga.npc_line_goals(p,0,[0,0,1,2,3,4,5,6]).is_empty(),"bad_previous")
	var nan:=p.duplicate();nan[0]=Vector2(NAN,0)
	check(Conga.npc_line_goals(nan,0).is_empty() and Conga.npc_line_goals(p.slice(0,7),0).is_empty(),"bad_line_pos")

func _init()->void:
	test_all();test_cases();test_line()
	print("AETHER_CONGA_RESULT "+JSON.stringify({"checks":checks,"assignments":assignments,"failures":failures}))
	quit(0 if failures.is_empty() and assignments==2520 else 1)
