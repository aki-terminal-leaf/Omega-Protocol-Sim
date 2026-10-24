# SPDX-License-Identifier: MIT
extends RefCounted
## Source rank is immutable; this module never assigns player inputs or damage.
const R=preload("res://scripts/rules.gd")
const Party=preload("res://scripts/party_statuses.gd")

# --- Astoh-only adaptive N3 goal (training choreography, not official calibration) ---
# Scope: layout=="astoh", state.human_actor==order[1] (M2), steered actor==order[5]
# (N3, not human), after normal sorting. Everything else returns the original goal.
# Only the AI goal changes; actors/beat/RNG/verdict are never mutated. The only
# written state is state[ADAPTIVE_KEY], erased per beat by begin().
const ADAPTIVE_KEY:="monitor_adaptive"
const ADAPT_LAYOUT:="astoh"
const ADAPT_HUMAN_RANK:=1
const ADAPT_ACTOR_RANK:=5
const SETTLE_TOLERANCE:=0.2
const HUMAN_STABLE_FOR:=0.3
const HUMAN_POS_TOLERANCE:=0.1
const HUMAN_FACE_TOLERANCE_DEG:=0.5
const COMMIT_BEFORE_END:=1.25
const ARRIVE_BEFORE_END:=0.2
const NPC_SPEED:=6.0
const ARENA_LIMIT:=19.8
const MIN_SPACING:=7.1
const HALF_THRESHOLD:=0.00001
const MIN_ORIGIN_DISTANCE:=0.01
const ROBUST_MARGIN:=0.05
const GRID_X_MIN:=8.5
const GRID_X_STEPS:=35
const GRID_Y_MIN:=-2.0
const GRID_Y_STEPS:=17
const GRID_STEP:=0.25
# Source index 0 = Boss, 1..3 = monitor holders order[0..2]; values are source ranks.
const DESIRED_RANK_PAIRS:=[[4,5],[1,2],[0,3],[6,7]]

static func point(actor:int,beat:Dictionary)->Vector2:
	var c:Dictionary=beat.monitor_preparation
	var slot:int=c.order.find(actor)
	# CN's first unmarked observes north; three marked and the remaining four
	# sort separately. Exact missing figure1 positions are NOT claimed.
	if str(c.layout).begins_with("cn_"):
		if slot==3:return Vector2(0,-7.0)
		return Vector2(-4.0,-3.0+slot*3.0) if slot<3 else Vector2(4.0,-4.5+(slot-4)*3.0)
	# Published conga priority, top to bottom; numeric spacing is training-only.
	var ranked:Array=c.order.duplicate()
	ranked.sort_custom(func(a,b):return c.priority.find(["MT","ST","H1","H2","D1","D2","D3","D4"][int(a)])<c.priority.find(["MT","ST","H1","H2","D1","D2","D3","D4"][int(b)]))
	return Vector2(-4.0,-5.25+ranked.find(actor)*1.5)
static func sorting(beat:Dictionary,state:Dictionary)->bool:
	return beat.has("monitor_preparation") and float(state.get("sim_time",0))-float(state.get("beat_started",0))<float(beat.monitor_preparation.sort_until)
## Per-beat reset of private adaptive state (call after Statuses.begin).
static func begin(_beat:Dictionary,state:Dictionary)->void:
	state.erase(ADAPTIVE_KEY)
static func goal(actor:int,beat:Dictionary,state:Dictionary,actors:Array=[])->Vector2:
	var base:Vector2=point(actor,beat) if sorting(beat,state) else R.v(beat.positions[actor])
	if actors.is_empty() or sorting(beat,state) or not _in_scope(actor,beat,state,actors):return base
	return _adaptive_goal(actor,beat,state,actors,base)
static func observe(beat:Dictionary,actors:Array,state:Dictionary)->void:
	if not sorting(beat,state):return
	var human:=int(state.get("human_actor",-1))
	if human<0 or human>=actors.size():return
	if R.v(actors[human].pos).distance_to(point(human,beat))<=1.0:
		state.monitor_preparation_observed={"actor":human,"at":float(state.sim_time),"sort_observed":true,"source_rank":beat.monitor_preparation.order.find(human),"scope":"observed staging, not full guide certification"}

static func _in_scope(actor:int,beat:Dictionary,state:Dictionary,actors:Array)->bool:
	var c=beat.get("monitor_preparation")
	if not (c is Dictionary) or str(c.get("layout",""))!=ADAPT_LAYOUT:return false
	var order=c.get("order")
	if not (order is Array) or order.size()!=8 or actors.size()!=8:return false
	var human:=int(state.get("human_actor",-1))
	return human>=0 and human==int(order[ADAPT_HUMAN_RANK]) and actor==int(order[ADAPT_ACTOR_RANK]) and actor!=human

static func _finite_v(p:Vector2)->bool:
	return is_finite(p.x) and is_finite(p.y)
static func _pose(actors:Array,i:int)->Dictionary:
	if i<0 or i>=actors.size():return {}
	var a=actors[i]
	if not (a is Dictionary) or not a.has("pos") or not a.has("face"):return {}
	var p:Vector2=R.v(a.pos)
	var f:=float(a.face)
	if not _finite_v(p) or not is_finite(f):return {}
	return {"pos":p,"face":f}
static func _angle_gap(a:float,b:float)->float:
	return absf(fposmod(a-b+180.0,360.0)-180.0)

static func _adaptive_goal(actor:int,beat:Dictionary,state:Dictionary,actors:Array,base:Vector2)->Vector2:
	var order:Array=beat.monitor_preparation.order
	var human:=int(order[ADAPT_HUMAN_RANK])
	var now:=float(state.get("sim_time",0))
	var elapsed:=now-float(state.get("beat_started",0))
	var duration:=float(beat.get("duration",0))
	if not is_finite(now) or not is_finite(elapsed) or not is_finite(duration) or duration<=0 or not _finite_v(base):return base
	if not (state.get(ADAPTIVE_KEY) is Dictionary) or int(state[ADAPTIVE_KEY].get("actor",-1))!=actor or int(state[ADAPTIVE_KEY].get("human",-1))!=human:
		state[ADAPTIVE_KEY]={"actor":actor,"human":human,"status":"waiting","frozen":false,"searches":0,"scope":"Astoh M2-human N3 adaptive training goal; not official calibration or release approval"}
	var ad:Dictionary=state[ADAPTIVE_KEY]
	var target:Vector2=ad.plan.goal if ad.has("plan") else base
	if ad.frozen:return target
	if elapsed>=duration-COMMIT_BEFORE_END:
		ad.frozen=true;ad.frozen_at=now
		if ad.has("plan"):ad.plan.frozen=true
		return target
	var hp:=_pose(actors,human)
	var np:=_pose(actors,actor)
	if hp.is_empty() or np.is_empty():
		return _fail_closed(ad,base,now,"fail_closed_pose")
	# Use exactly the currently visible public status projection, including runtime
	# expiry overrides/consumed cues. Check even at an unchanged human signature;
	# malformed current inputs must not revive a previous cached target.
	var srcs:=_sources(beat,actors,order,state)
	if srcs.is_empty():return _fail_closed(ad,base,now,"fail_closed_sources")
	# Stable-observation anchor, updated once per sim tick.
	if float(ad.get("last_tick",-INF))!=now:
		ad.last_tick=now
		if not ad.has("anchor") or (ad.anchor.pos as Vector2).distance_to(hp.pos)>HUMAN_POS_TOLERANCE or _angle_gap(float(ad.anchor.face),float(hp.face))>HUMAN_FACE_TOLERANCE_DEG:
			ad.anchor={"pos":hp.pos,"face":float(hp.face),"since":now}
	if now-float(ad.anchor.since)<HUMAN_STABLE_FOR:
		ad.status="human_unstable";return target
	for j in 8:
		if j==actor or j==human:continue
		var op:=_pose(actors,j)
		if op.is_empty():
			return _fail_closed(ad,base,now,"fail_closed_pose")
		if (op.pos as Vector2).distance_to(R.v(beat.positions[j]))>SETTLE_TOLERANCE:
			ad.status="npcs_settling";return target
	var sig:Array=[ad.anchor.pos,float(ad.anchor.face)]
	if ad.has("signature") and ad.signature==sig:return target
	ad.signature=sig
	ad.searches=int(ad.searches)+1
	var res:=_plan(beat,actors,order,actor,human,base,srcs)
	if not res.get("ok",false):
		ad.status=str(res.get("reason","no_feasible_goal"));ad.last_rejection={"at":now,"reason":ad.status}
		return base if res.get("malformed",false) else target
	var eta:float=(np.pos as Vector2).distance_to(R.v(res.goal))/NPC_SPEED
	if eta>duration-ARRIVE_BEFORE_END-elapsed:
		ad.status="arrival_infeasible";ad.last_rejection={"at":now,"reason":ad.status,"eta":eta}
		return target
	ad.plan={"actor":actor,"goal":res.goal,"mode":res.mode,"margin":res.get("margin",-1.0),"observed":{"human_pos":ad.anchor.pos,"human_face":float(ad.anchor.face),"human_side":res.human_side,"n3_pos":np.pos},"computed_at":now,"elapsed":elapsed,"eta":eta,"commit_at_elapsed":duration-COMMIT_BEFORE_END,"frozen":false}
	ad.status="planned"
	return res.goal

## Builds current public source geometry; returns {} when malformed.
static func _fail_closed(ad:Dictionary,base:Vector2,now:float,reason:String)->Vector2:
	ad.erase("plan");ad.erase("signature")
	ad.status=reason;ad.last_rejection={"at":now,"reason":reason}
	return base

static func _sources(beat:Dictionary,actors:Array,order:Array,state:Dictionary)->Array:
	var monitors=beat.get("monitors")
	var statuses:Array=Party.rows(actors,state,beat)
	if not (monitors is Array) or monitors.size()!=4 or statuses.size()!=8:return []
	var out:Array=[]
	var seen:={}
	for s in monitors:
		if not (s is Dictionary) or str(s.get("kind",""))!="half":return []
		var radius:=float(s.get("radius",-1))
		if not is_finite(radius) or radius<=0:return []
		var ex:Array=[]
		for e in s.get("exclude",[]):ex.append(int(e))
		var slot:int
		var origin:Vector2
		var aim:Vector2
		var side:=0.0
		var src_actor:=-1
		if not s.has("actor"):
			if not s.has("angle") or not is_finite(float(s.angle)):return []
			slot=0;origin=R.v(s.get("pos",[0,0]));aim=R.direction(float(s.angle))
		else:
			src_actor=int(s.actor)
			var rank:int=order.find(src_actor)
			if rank<0:rank=order.find(float(src_actor))
			if rank<0 or rank>2 or int(s.get("face_actor",-1))!=src_actor:return []
			slot=rank+1
			var keys:Array=(statuses[src_actor].effects as Array).filter(func(st):return str(st.get("key","")) in ["monitor_left","monitor_right"])
			if keys.size()!=1:return []
			side=90.0 if str(keys[0].key)=="monitor_right" else -90.0
			var offset:=float(s.get("offset",0))
			if not is_finite(offset) or signf(offset)!=signf(side):return []
			var pose:=_pose(actors,src_actor)
			if pose.is_empty():return []
			origin=pose.pos;aim=R.direction(float(pose.face)+offset)
		if seen.has(slot) or not _finite_v(origin) or not _finite_v(aim):return []
		seen[slot]=true
		var desired:Array=[]
		for rk in DESIRED_RANK_PAIRS[slot]:desired.append(int(order[rk]))
		out.append({"slot":slot,"actor":src_actor,"origin":origin,"aim":aim,"radius":radius,"exclude":ex,"desired":desired,"side":side})
	return out

## Normalized half-plane test matching Rules.contains for "half". dn=NAN if at origin.
static func _dn(pos:Vector2,src:Dictionary)->float:
	var d:Vector2=pos-src.origin
	if d.length()<=MIN_ORIGIN_DISTANCE:return NAN
	return d.normalized().dot(src.aim)
static func _inside(pos:Vector2,src:Dictionary,dn:float)->bool:
	return not is_nan(dn) and (pos-src.origin).length()<=float(src.radius) and dn>cos(deg_to_rad(90.0))+HALF_THRESHOLD

static func _plan(beat:Dictionary,actors:Array,order:Array,actor:int,human:int,canon:Vector2,srcs:Array)->Dictionary:
	if srcs.is_empty():return {"ok":false,"malformed":true,"reason":"fail_closed_sources"}
	var poses:Array=[]
	for j in 8:poses.append(_pose(actors,j).get("pos",Vector2(NAN,NAN)))
	var human_side:=0.0
	# Fixed (non-N3) memberships must already be exact; margins only on the human source.
	var fixed_margin:=1.0
	for src in srcs:
		if int(src.actor)==human:human_side=float(src.side)
		for j in 8:
			if j==actor or j in src.exclude:continue
			var dn:=_dn(poses[j],src)
			if _inside(poses[j],src,dn)!=(j in src.desired):return {"ok":false,"reason":"fixed_membership_mismatch"}
			if int(src.actor)==human:
				if is_nan(dn):return {"ok":false,"reason":"fixed_membership_mismatch"}
				fixed_margin=minf(fixed_margin,absf(dn-HALF_THRESHOLD))
	# Baseline retention: canonical N3 already exact with spacing; no needless shift.
	var base_eval:=_eval_n3(canon,poses,srcs,actor,false)
	if base_eval.ok:return {"ok":true,"goal":canon,"mode":"baseline_retained","margin":minf(fixed_margin,float(base_eval.margin)),"human_side":human_side}
	if fixed_margin<ROBUST_MARGIN:return {"ok":false,"reason":"human_source_fixed_margin_low"}
	var sx:=signf(canon.x)
	if sx==0:return {"ok":false,"malformed":true,"reason":"fail_closed_canonical_side"}
	var best:={}
	for ix in GRID_X_STEPS:
		for iy in GRID_Y_STEPS:
			var p:=Vector2(sx*(GRID_X_MIN+GRID_STEP*ix),GRID_Y_MIN+GRID_STEP*iy)
			var e:=_eval_n3(p,poses,srcs,actor,true)
			if not e.ok:continue
			var m:=minf(fixed_margin,float(e.margin))
			var dist:=p.distance_to(canon)
			if best.is_empty() or dist<float(best.dist)-1e-9 or (absf(dist-float(best.dist))<=1e-9 and m>float(best.margin)+1e-12):
				best={"goal":p,"dist":dist,"margin":m}
	if best.is_empty():return {"ok":false,"reason":"no_robust_grid_point"}
	return {"ok":true,"goal":best.goal,"mode":"adaptive_search","margin":best.margin,"human_side":human_side}

static func _eval_n3(p:Vector2,poses:Array,srcs:Array,actor:int,robust:bool)->Dictionary:
	if not _finite_v(p) or p.length()>=ARENA_LIMIT:return {"ok":false}
	for j in 8:
		if j==actor:continue
		if not _finite_v(poses[j]) or p.distance_to(poses[j])<=MIN_SPACING:return {"ok":false}
	var margin:=1.0
	for src in srcs:
		if actor in src.exclude:return {"ok":false}
		var dn:=_dn(p,src)
		if is_nan(dn) or _inside(p,src,dn)!=(actor in src.desired):return {"ok":false}
		var m:=absf(dn-HALF_THRESHOLD)
		if robust and m<ROBUST_MARGIN:return {"ok":false}
		margin=minf(margin,m)
	return {"ok":true,"margin":margin}
