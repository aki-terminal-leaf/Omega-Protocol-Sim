# SPDX-License-Identifier: MIT
extends SceneTree
## Pure CN initial-lineup helper gate. Not Main/native/manual acceptance.
const L=preload("res://scripts/synergy_cn_lineup.gd")
const I=preload("res://scripts/interactions.gd")
const Markers=preload("res://scripts/markers.gd")
const ROLES=["MT","ST","H1","H2","D1","D2","D3","D4"]
## Independent literal transcription of the poster icons (left -> right).
const POSTER=["H1","MT","ST","D1","D2","D3","D4","H2"]
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);print("CN LINEUP FAIL ",label)
func actors_at(points:Array)->Array:
	var out:Array=[]
	for i in 8:out.append({"role":ROLES[i],"pos":points[i],"face":0.0})
	return out
func layout_with_a(a:Variant,enabled:Variant=true)->Dictionary:
	var lay:Dictionary=Markers.default_layout()
	for m in lay.marks:
		if m.id=="A":m.pos=a;m.enabled=enabled
	return lay
func beat()->Dictionary:
	# Deliberately poisoned private fields: lineup must never read them.
	return {"title":"Party Synergy · cast","positions":[Vector2(9,9),Vector2(9,9),Vector2(9,9),Vector2(9,9),Vector2(9,9),Vector2(9,9),Vector2(9,9),Vector2(9,9)],L.KEY:L.metadata()}
func near(a:Vector2,b:Vector2)->bool:return a.distance_to(b)<0.0001
func _initialize()->void:call_deferred("run")
func run()->void:
	var poses:Array=[]
	for i in 8:poses.append(Vector2(-7.0+i*1.3,4.0+0.37*i))
	var actors:=actors_at(poses)
	# 1. Order matches poster icons, by role name not index tautology.
	var named:Array=[]
	for a in L.ORDER:named.append(ROLES[int(a)])
	check(named==POSTER,"ORDER equals poster H1 MT ST D1 D2 D3 D4 H2")
	var uniq:Dictionary={}
	for a in L.ORDER:uniq[int(a)]=true
	check(uniq.size()==8,"order covers 8 unique actors")
	# 2. Default A: high->low x increasing, z constant, 1.8 spacing, centred.
	var d:Array=L.default_slots()
	var xs_ok:=true;var sum:=Vector2.ZERO
	for r in 8:
		var p:Vector2=d[int(L.ORDER[r])];sum+=p
		if absf(p.y)>0.0001:xs_ok=false
		if r>0:
			var q:Vector2=d[int(L.ORDER[r-1])]
			if absf((p.x-q.x)-1.8)>0.0001:xs_ok=false
	check(xs_ok,"default A row: increasing worldx at 1.8m, on z=0")
	check(sum.length()<0.0001,"row centred on arena")
	check(near(d[2],Vector2(-6.3,0)) and near(d[3],Vector2(6.3,0)),"H1 leftmost, H2 rightmost facing default A")
	# 3. Runtime public A (default) through Interactions route.
	var st:Dictionary={"human_actor":-1,"waymark_layout":Markers.default_layout()}
	for i in 8:check(near(I.raw_bot_goal(i,beat(),actors,st),d[i]),"route default A actor%d"%i)
	# 4. Rotated A (east): forward=(1,0), right=(0,1) => high rank most negative z.
	var east:Dictionary={"human_actor":-1,"waymark_layout":layout_with_a([13.0,0.0])}
	var g2:Vector2=L.goal(2,beat(),actors,east);var g3:Vector2=L.goal(3,beat(),actors,east)
	check(near(g2,Vector2(0,-6.3)) and near(g3,Vector2(0,6.3)),"rotated east A: H1 at z-6.3, H2 at z+6.3")
	var diag:Dictionary={"human_actor":-1,"waymark_layout":layout_with_a([5.0,-5.0])}
	var lin:=true;var prev:Vector2=L.goal(int(L.ORDER[0]),beat(),actors,diag)
	var fw:Vector2=Vector2(5,-5).normalized();var right:=Vector2(-fw.y,fw.x)
	for r in range(1,8):
		var p:Vector2=L.goal(int(L.ORDER[r]),beat(),actors,diag)
		if absf((p-prev).dot(right)-1.8)>0.0001 or absf(p.dot(fw))>0.0001:lin=false
		prev=p
	check(lin,"diagonal A: linear, perpendicular to A, high->low along right")
	# 5. Invalid inputs hold ACTUAL pose (never centre/north/positions).
	var bad_states:Dictionary={
		"missing_layout":{"human_actor":-1},
		"missing_A":{"human_actor":-1,"waymark_layout":{"schema":1,"marks":[{"id":"B","enabled":true,"pos":[13.0,0.0]}]}},
		"disabled_A":{"human_actor":-1,"waymark_layout":layout_with_a([0.0,-13.0],false)},
		"zero_A":{"human_actor":-1,"waymark_layout":layout_with_a([0.0,0.0])},
		"nonfinite_A":{"human_actor":-1,"waymark_layout":layout_with_a([NAN,-13.0])},
		"out_of_wall_A":{"human_actor":-1,"waymark_layout":layout_with_a([0.0,-25.0])},
		"string_A":{"human_actor":-1,"waymark_layout":layout_with_a(["0","-13"])},
		"bad_enabled":{"human_actor":-1,"waymark_layout":layout_with_a([0.0,-13.0],"yes")},
		"duplicate_A":{"human_actor":-1,"waymark_layout":{"schema":1,"marks":[{"id":"A","enabled":true,"pos":[0.0,-13.0]},{"id":"A","enabled":true,"pos":[13.0,0.0]}]}},
		"bad_schema":{"human_actor":-1,"waymark_layout":{"schema":2,"marks":Markers.default_layout().marks}},
		"layout_not_dict":{"human_actor":-1,"waymark_layout":[1,2]}}
	for k in bad_states:
		for i in [0,3,6]:
			var r:Dictionary=L.resolve(i,beat(),actors,bad_states[k])
			check(not r.ok and near(I.raw_bot_goal(i,beat(),actors,bad_states[k]),poses[i]),"%s holds actual actor%d"%[k,i])
	var bad_meta:Array=[null,{},"x",{"schema":1}]
	var m1:Dictionary=L.metadata();m1.order=[0,2,1,4,5,6,7,3];bad_meta.append(m1)
	var m2:Dictionary=L.metadata();m2.spacing=3.0;bad_meta.append(m2)
	var m3:Dictionary=L.metadata();m3.profile_id="aether";bad_meta.append(m3)
	var m4:Dictionary=L.metadata();m4.order=[2,0,1];bad_meta.append(m4)
	var m5:Dictionary=L.metadata();m5.order=["2","0","1","4","5","6","7","3"];bad_meta.append(m5)
	for n in bad_meta.size():
		var b:=beat();b[L.KEY]=bad_meta[n]
		check(near(I.raw_bot_goal(5,b,actors,st),poses[5]),"malformed metadata%d holds actual pose"%n)
	# 6. Human held when directly queried.
	var hs:Dictionary=st.duplicate(true);hs.human_actor=4
	check(near(L.goal(4,beat(),actors,hs),poses[4]) and not near(L.goal(5,beat(),actors,hs),poses[5]),"human held, NPC still routed")
	# 7. Actor/actors safety.
	check(not L.resolve(-1,beat(),actors,st).ok and not L.resolve(8,beat(),actors,st).ok and not L.resolve(0,beat(),[],st).ok,"invalid actor index/actors rejected")
	var nan_actors:=actors.duplicate(true);nan_actors[1].pos=Vector2(NAN,0)
	check(not L.resolve(1,beat(),nan_actors,st).ok,"nonfinite actual pose rejected")
	# 8. JSON-safe metadata/layout.
	var jb:Dictionary=beat();jb[L.KEY]=JSON.parse_string(JSON.stringify(L.metadata()))
	var js:Dictionary={"human_actor":-1,"waymark_layout":JSON.parse_string(JSON.stringify(east.waymark_layout))}
	check(L.valid_metadata(jb[L.KEY]) and near(L.goal(2,jb,actors,js),Vector2(0,-6.3)),"JSON round-trip metadata/layout")
	# 9. Private perturbations: positions/eye/pairs/assignments/beat-time ignored.
	var pb:Dictionary=beat()
	for i in 8:pb.positions[i]=Vector2(-15+i,15-i)
	pb.p2_eye_angle=135.0;pb.pairs=[[0,7]];pb.assignment={"route_order":[7,6,5,4,3,2,1,0]};pb.synergy_start=99.0
	var ps:Dictionary=st.duplicate(true);ps.sim_time=2.9;ps.rng_seed=1;ps.future_eye=Vector2(45,0)
	var same:=true
	for i in 8:
		if not near(L.goal(i,pb,actors,ps),L.goal(i,beat(),actors,st)):same=false
	check(same,"private positions/eye/pairs/assignment/time do not change goals")
	# 10. Moving actual poses doesn't move valid goals (not pose-relative).
	var moved:=actors_at([Vector2(1,1),Vector2(2,2),Vector2(3,3),Vector2(4,4),Vector2(5,5),Vector2(6,6),Vector2(7,7),Vector2(8,8)])
	check(near(L.goal(6,beat(),moved,st),d[6]),"valid goal independent of actual pose")
	# 11. No metadata => interactions falls back to beat.positions (other profiles unchanged).
	var plain:Dictionary=beat();plain.erase(L.KEY)
	check(near(I.raw_bot_goal(0,plain,actors,st),Vector2(9,9)),"no-meta beat unaffected by lineup route")
	var result:Dictionary={"checks":checks,"failures":failures,"scope":"pure helper + Interactions route; not Main/native/manual"}
	print("CN_LINEUP_RESULT ",JSON.stringify(result))
	quit(1 if not failures.is_empty() else 0)
