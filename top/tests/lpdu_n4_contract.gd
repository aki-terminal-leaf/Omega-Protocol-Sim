# SPDX-License-Identifier: MIT
# Pure generated-course / Rules regression for the LPDU N4 correction.
# Scope: E.build("p3_monitors") output + actual R.hits / R.evaluate on
# independent synthetic actor copies and fresh state. This is NOT an actual
# Main/scene replay, not an official metre calibration, not a global-optimum,
# all-role, native, Web or gameplay acceptance.
# Exact new coordinates are intentionally NOT asserted (semantic safety only).
extends SceneTree
const E=preload("res://scripts/encounters.gd")
const R=preload("res://scripts/rules.gd")

const SEEDS_FIRST:int=1
const SEEDS_LAST:int=32
const LPDU_PROFILE_INDEX:int=2
const SEPARATION_MIN:float=7.001 # splash radius 7 + contains() tolerance 0.001
const ARENA_LIMIT:float=20.0 # Rules death wall: length()>=20
# Engineering regression margin (normalized dot), NOT an official tolerance.
const M1_HALFPLANE_MARGIN:float=0.05
const HEADING_DELTAS:Array=[0.0,0.1,-0.1]
# Source-rank pairs per source: Boss, M1, M2, M3.
const EXPECTED_PAIRS:Array=[[1,2],[4,5],[0,3],[6,7]]
const SOURCE_NAMES:Array=["Boss","M1","M2","M3"]
const MAX_LABELS:int=400

var checks:int=0
var failures:int=0
var labels:Array=[]
var mirror_counts:Dictionary={"east":0,"west":0}
var evaluated:int=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		print("LPDU_N4_CONTRACT FAIL ",label)
		if labels.size()<MAX_LABELS:labels.append(label)

func fixture(seed_value:int):
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var profiles:Array=parsed as Array
	var p:Dictionary=(profiles[LPDU_PROFILE_INDEX] as Dictionary).duplicate(true)
	p.monitor_layout="lpdu"
	return E.new().build("p3_monitors",seed_value,p,0,-1)

# Fresh independent actor copies; no shared references with the beat.
func make_actors(b:Dictionary)->Array:
	var actors:Array=[]
	for actor in 8:
		var pos:Vector2=R.v(b.positions[actor])
		actors.append({"role":E.ROLES[actor],"pos":Vector2(pos.x,pos.y),"face":float(b.facing.get(actor,0.0))})
	return actors

func sorted_ranks(actor_ids:Array,rank_of:Dictionary)->Array:
	var out:Array=[]
	for raw in actor_ids:
		out.append(int(rank_of.get(int(raw),-1)))
	out.sort()
	return out

func run_seed(seed_value:int)->void:
	var tag:String="seed%d" % seed_value
	var ctx=fixture(seed_value)
	check(ctx.beats.size()==1,tag+" single beat")
	if ctx.beats.size()<1:return
	var b:Dictionary=(ctx.beats[0] as Dictionary).duplicate(true)
	check(str(b.get("monitor_layout",""))=="lpdu",tag+" layout lpdu")
	check(b.has("monitor_preparation"),tag+" monitor_preparation present")
	check(b.has("monitors") and (b.monitors as Array).size()==4,tag+" four monitor sources")
	if not b.has("monitor_preparation") or not b.has("monitors") or (b.monitors as Array).size()!=4:return
	var order:Array=(b.monitor_preparation.order as Array).duplicate()
	check(order.size()==8,tag+" order size 8")
	if order.size()!=8:return
	var rank_of:Dictionary={}
	for r in 8:rank_of[int(order[r])]=r
	check(rank_of.size()==8,tag+" order is a permutation")
	var sources:Array=b.monitors as Array
	for i in 3:
		var s:Dictionary=sources[i+1]
		check(s.has("actor") and int(rank_of.get(int(s.get("actor",-1)),-1))==i,tag+" %s holder is source rank%d" % [SOURCE_NAMES[i+1],i])
	var m1_actor:int=int(order[0])
	var n4_actor:int=int(order[6])
	var n5_actor:int=int(order[7])
	var base:Array=make_actors(b)
	# Mirror bookkeeping from M1 rank0 x sign (natural RNG, not forced).
	var m1_pos:Vector2=base[m1_actor].pos
	if m1_pos.x>0.0:mirror_counts.east+=1
	elif m1_pos.x<0.0:mirror_counts.west+=1
	# Arena + pairwise separation.
	for a in 8:
		check((base[a].pos as Vector2).length()<ARENA_LIMIT,tag+" actor%d rank%d inside arena |p|=%.4f" % [a,int(rank_of[a]),(base[a].pos as Vector2).length()])
		for c in range(a+1,8):
			var d:float=(base[a].pos as Vector2).distance_to(base[c].pos)
			check(d>SEPARATION_MIN,tag+" ranks%d/%d separation %.4f>%.3f" % [int(rank_of[a]),int(rank_of[c]),d,SEPARATION_MIN])
	# Source step5: N4 near boss (inner), N5 at the wall.
	var n4_len:float=(base[n4_actor].pos as Vector2).length()
	var n5_len:float=(base[n5_actor].pos as Vector2).length()
	check(n4_len<n5_len,tag+" N4 inner than N5 (%.4f<%.4f)" % [n4_len,n5_len])
	for delta in HEADING_DELTAS:
		var dtag:String=tag+" M1%+.1fdeg" % float(delta)
		var actors:Array=make_actors(b)
		actors[m1_actor].face=float(actors[m1_actor].face)+float(delta)
		# N4 outside M1 halfplane with engineering margin, using Rules' own geometry.
		var m1_source:Dictionary=sources[1]
		var axis:Vector2=R.aim(m1_source,actors)
		var rel:Vector2=(actors[n4_actor].pos as Vector2)-R.point(m1_source,actors)
		var ndot:float=rel.normalized().dot(axis) if rel.length()>0.01 else 1.0
		check(ndot<=-M1_HALFPLANE_MARGIN,dtag+" N4 outside M1 halfplane normalized dot %.5f<=-%.2f" % [ndot,M1_HALFPLANE_MARGIN])
		# Exact intended rank pairs via actual Rules.hits.
		var pair_targets:Array=[]
		for si in 4:
			var got:Array=sorted_ranks(R.hits(sources[si],actors),rank_of)
			check(got==EXPECTED_PAIRS[si],dtag+" %s ranks %s expected %s" % [SOURCE_NAMES[si],str(got),str(EXPECTED_PAIRS[si])])
			pair_targets.append(R.hits(sources[si],actors))
		# Independent coverage recomputation (pairs of size2 => targets fixed regardless of RNG).
		var coverage:Array=[0,0,0,0,0,0,0,0]
		for t in pair_targets:
			for target in t:
				for hit in R.hits({"actor":int(target),"radius":7.0},actors):coverage[int(hit)]+=1
		check(coverage==[1,1,1,1,1,1,1,1],dtag+" independent coverage 8x1 got %s" % str(coverage))
		# Actual Rules.evaluate on fresh synthetic state.
		var sim_time:float=float(b.get("duration",10.1))
		var state:Dictionary={"sim_time":sim_time,"seed":seed_value,"dead":[]}
		var eval_actors:Array=make_actors(b)
		eval_actors[m1_actor].face=float(eval_actors[m1_actor].face)+float(delta)
		var result:Array=R.evaluate(b.duplicate(true),eval_actors,state)
		evaluated+=1
		check(result.is_empty(),dtag+" evaluate no errors: %s" % str(result))
		check((state.get("dead",[]) as Array).is_empty(),dtag+" death none: %s" % str(state.get("dead",[])))
		var statuses:Variant=state.get("statuses",null)
		check(statuses!=null,dtag+" statuses created")
		if statuses==null:continue
		for i in 8:
			var st:Dictionary=statuses[i] as Dictionary
			var mv:float=float((st.get("magic_vulnerability",{}) as Dictionary).get("expires",-1.0))
			var tr:float=float((st.get("twice_come_ruin",{}) as Dictionary).get("expires",-1.0))
			check(is_equal_approx(mv,sim_time+5.0),dtag+" actor%d magic_vulnerability 5s expires %.3f" % [i,mv])
			check(is_equal_approx(tr,sim_time+7.0),dtag+" actor%d twice_come_ruin 7s expires %.3f" % [i,tr])

func _initialize()->void:
	for seed_value in range(SEEDS_FIRST,SEEDS_LAST+1):run_seed(seed_value)
	check(int(mirror_counts.east)>0 and int(mirror_counts.west)>0,"both mirrors observed naturally east=%d west=%d" % [int(mirror_counts.east),int(mirror_counts.west)])
	var summary:Dictionary={"marker":"LPDU_N4_CONTRACT_RESULT","scope":"pure generated-course + Rules on synthetic copies; not actual Main","seeds":[SEEDS_FIRST,SEEDS_LAST],"checks":checks,"failures":failures,"evaluated":evaluated,"mirrors":mirror_counts,"failure_labels":labels,"labels_truncated":failures>labels.size()}
	print("LPDU_N4_CONTRACT_RESULT ",JSON.stringify(summary))
	quit(1 if failures>0 else 0)
