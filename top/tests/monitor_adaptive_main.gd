# SPDX-License-Identifier: MIT
extends SceneTree
## Parent-owned actual Main acceptance: 19 cases via ordinary UI selectors and WASD/QE/R.
## 12 original cases +4 changed public input cases require actual modeled PASS.
## 3 negative probes preserve actual outcomes; 30deg may randomly pass, never called a rescue.
## No actor/state injection. Numeric angle probes are not official legality bounds.
const Main=preload("res://scenes/main.tscn")
const R=preload("res://scripts/rules.gd")
const Enc=preload("res://scripts/encounters.gd")
const Prep=preload("res://scripts/monitor_preparation.gd")
const ALL_KEYS:Array=[KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E]
const STEP:float=0.025
const MAX_STEPS:int=600
const SEED_SCAN_MAX:int=128
const SEEDS_PER_SIGN:int=3
const TILT_DEG:float=11.0
const HALF_THRESHOLD:float=0.00001 # Rules: dot > cos(90deg)+0.00001
var checks:int=0
var failures:Array=[]
var rows:Array=[]
var held:Dictionary={}
var case_events:int=0
var key_mismatch:int=0
var case_mismatch:int=0
var catalog:Array=[]
var extra:Dictionary={}

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures.append(label);print("MONITOR ADAPTATION FIXTURE FAIL ",label)

func send_key(code:int,down:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code as Key;e.keycode=code as Key;e.pressed=down
	Input.parse_input_event(e);case_events+=1

func keys(wanted:Array)->void:
	for code in ALL_KEYS:
		var down:bool=code in wanted
		if bool(held.get(code,false))==down:continue
		send_key(int(code),down);held[code]=down
	Input.flush_buffered_events()
	for code in ALL_KEYS:
		if Input.is_physical_key_pressed(code as Key)!=bool(held.get(code,false)):
			key_mismatch+=1;case_mismatch+=1

func held_names()->Array:
	var out:Array=[]
	for code in ALL_KEYS:
		if Input.is_physical_key_pressed(code as Key):out.append(OS.get_keycode_string(code as Key))
	return out

func steer(app,target:Vector2,human:int)->void:
	var d:Vector2=(target-R.v(app.actors[human].pos)).rotated(float(app.arena.camera_yaw))
	var wanted:Array=[]
	if absf(d.x)>absf(d.y)*.4142:wanted.append(KEY_D if d.x>0 else KEY_A)
	if absf(d.y)>absf(d.x)*.4142:wanted.append(KEY_S if d.y>0 else KEY_W)
	keys(wanted)

func layout_of(profile:Dictionary)->String:
	var pid:String=str(profile.get("id",""))
	return str(profile.get("monitor_layout",pid if pid in ["aether","lpdu"] else "astoh"))

func choose_method(app,s:int)->bool:
	keys([])
	app.return_to_selection();app.phase_select.select(0);app.filter_catalog()
	var found:bool=false
	for n in int(app.filtered.size()):
		if str(app.filtered[n].id)=="p3_monitors":
			app.choose_mechanic(n);found=true;break
	if not found or int(app.strategy_select.item_count)<=s:return false
	var meta:Variant=app.strategy_select.get_item_metadata(s)
	if not meta is Dictionary:return false
	app.strategy_select.select(s);app.choose_strategy(s)
	return bool(app.configured)

## Independent analytic direction: angle -> (sin,-cos), 0=north, +90=east.
func ndir(deg:float)->Vector2:
	return Vector2(sin(deg_to_rad(deg)),-cos(deg_to_rad(deg)))

## Local pure planner copy (never injected): same builder Main.prepare uses.
func plan(app,seed_value:int)->Dictionary:
	var builder=Enc.new()
	var enc:Dictionary=builder.build("p3_monitors",seed_value,app.active_profile,0,-1)
	var beats:Array=enc.beats
	for bi in beats.size():
		var b:Dictionary=beats[bi]
		if not b.has("monitors"):continue
		var srcs:Array=b.monitors
		var boss:float=float(srcs[0].angle)
		var marked:Array=[];var offsets:Array=[]
		for k in range(1,srcs.size()):
			marked.append(int(srcs[k].actor));offsets.append(float(srcs[k].offset))
		var unmarked:Array=[]
		for i in 8:
			if not i in marked:unmarked.append(i)
		var poses:Array=[]
		for i in 8:poses.append(R.v(b.positions[i]))
		return {"seed":seed_value,"beat_index":bi,"beat":b,"boss":boss,"sign":1 if boss>0 else -1,"marked":marked,"offsets":offsets,"unmarked":unmarked,"poses":poses}
	return {}

func halfplanes(b:Dictionary,poses:Array)->Array:
	var out:Array=[]
	for src in b.monitors:
		var s:Dictionary=src
		if s.has("actor"):
			var a:int=int(s.actor)
			out.append({"o":poses[a],"n":ndir(float(b.facing.get(a,0.0))+float(s.offset)),"actor":a})
		else:
			out.append({"o":R.v(s.get("pos",Vector2.ZERO)),"n":ndir(float(s.angle)),"actor":-1})
	return out

## Copied previously verified membership-preserving marked-human planner.
func marked_realization(p:Dictionary,human:int)->Dictionary:
	var b:Dictionary=p.beat;var base:Array=p.poses
	var expected:Array=halfplanes(b,base)
	var candidates:Array=[base[human]]
	for radius in [0.25,0.4,0.6]:
		for k in 24:candidates.append(R.v(base[human])+ndir(k*15.0)*float(radius))
	for candidate in candidates:
		var c:Vector2=candidate
		if c.length()>=19.5:continue
		var poses:Array=base.duplicate();poses[human]=c
		var actual:Array=halfplanes(b,poses)
		var ok:bool=true;var min_margin:float=INF
		for n in expected.size():
			var eh:Dictionary=expected[n];var ah:Dictionary=actual[n]
			for j in 8:
				if j==int(eh.actor):continue
				var de:Vector2=R.v(base[j])-R.v(eh.o)
				var da:Vector2=R.v(poses[j])-R.v(ah.o)
				var be:float=de.dot(R.v(eh.n));var ba:float=da.dot(R.v(ah.n))
				if (be>de.length()*0.00001)!=(ba>da.length()*0.00001):ok=false
				if int(eh.actor)==human or j==human:
					min_margin=minf(min_margin,absf(ba))
					if absf(ba)<0.18:ok=false
		for j in 8:
			if j!=human and c.distance_to(R.v(base[j]))<=7.1:ok=false
		if ok:return {"found":true,"pos":c,"margin":min_margin,"offset":c.distance_to(R.v(base[human]))}
	return {"found":false,"pos":base[human],"margin":0.0,"offset":0.0}

func find_cov(v:Variant,depth:int)->Array:
	if depth>7:return []
	if v is Dictionary:
		var d:Dictionary=v
		if d.has("coverage") and d.has("sources") and d.coverage is Array and (d.coverage as Array).size()==8:return (d.coverage as Array).duplicate()
		for k in d.keys():
			var r:Array=find_cov(d[k],depth+1)
			if not r.is_empty():return r
	elif v is Array:
		for e in (v as Array):
			var r2:Array=find_cov(e,depth+1)
			if not r2.is_empty():return r2
	return []

func monitor_check(b:Dictionary)->Dictionary:
	for c in b.get("checks",[]):
		if str(c.get("kind",""))=="monitors":return c
	return {}

## Independent source geometry description from the beat's monitors check
## (origin actor/pos, aim face_actor+offset or fixed angle). Read-only.
func source_geom(src:Dictionary,poses:Array,faces:Array)->Dictionary:
	var o:Vector2
	var actor:int=-1
	if src.has("actor"):
		actor=int(src.actor);o=R.v(poses[actor])
	else:o=R.v(src.get("pos",[0,0]))
	var ang:float
	if src.has("face_actor"):ang=float(faces[int(src.face_actor)])+float(src.get("offset",0.0))
	else:ang=float(src.get("angle",0.0))
	var excl:Array=[]
	for e in src.get("exclude",[]):excl.append(int(e))
	return {"o":o,"n":ndir(ang).normalized(),"aim_deg":ang,"actor":actor,"radius":float(src.get("radius",45.0)),"exclude":excl,"kind":str(src.get("kind",""))}

func cands_of(g:Dictionary,poses:Array)->Dictionary:
	var out:Array=[];var min_margin:float=INF
	for j in 8:
		if j in g.exclude:continue
		var d:Vector2=R.v(poses[j])-R.v(g.o)
		var dist:float=d.length()
		if dist<=0.01:continue
		var dn:float=d.normalized().dot(R.v(g.n))
		min_margin=minf(min_margin,absf(dn-HALF_THRESHOLD))
		if dist<=float(g.radius) and dn>HALF_THRESHOLD:out.append(j)
	return {"cands":out,"min_margin":min_margin}

func ranks_of(ids:Array,order:Array)->Array:
	var r:Array=[]
	for t in ids:r.append(order.find(int(t)))
	r.sort()
	return r

## Analytic-only counterfactual: move ONLY rank N3 (order[5]) in a bounded
## 20x20 grid in the Boss-side corridor; keep other 7 poses and all faces
## (incl. actual human angle) unchanged. Never injected into Main.
func counterfactual(b:Dictionary,actual_poses:Array,actual_faces:Array,sgn:int,control_pairs:Array)->Dictionary:
	var mc:Dictionary=monitor_check(b)
	if mc.is_empty():return {"status":"INVALID_no_monitor_check","found":false}
	var order:Array=[]
	for o in b.monitor_preparation.order:order.append(int(o))
	var n3:int=int(order[5])
	var splash:float=float(mc.get("splash_radius",7.0))
	var feasible:int=0;var tried:int=0;var best:Dictionary={}
	for ix in 20:
		for iy in 20:
			var c:Vector2=Vector2(float(sgn)*(8.5+6.0*ix/19.0),-1.0+2.0*iy/19.0)
			tried+=1
			if c.length()>=19.5:continue
			var poses:Array=actual_poses.duplicate();poses[n3]=c
			var minsep:float=INF
			for a in 8:
				for bb in range(a+1,8):minsep=minf(minsep,R.v(poses[a]).distance_to(R.v(poses[bb])))
			if minsep<=7.1:continue
			var ok:bool=true;var per:Array=[];var cov:Array=[0,0,0,0,0,0,0,0];var mm:float=INF
			var si:int=0
			for src in mc.sources:
				var g:Dictionary=source_geom(src,poses,actual_faces)
				var cr:Dictionary=cands_of(g,poses)
				mm=minf(mm,float(cr.min_margin))
				var cs:Array=cr.cands
				if cs.size()!=2:ok=false
				elif si<control_pairs.size() and ranks_of(cs,order)!=control_pairs[si]:ok=false
				if cs.size()==2:
					for t in cs:
						for j in 8:
							if R.v(poses[j]).distance_to(R.v(poses[int(t)]))<=splash+0.001:cov[j]+=1
				per.append({"source_actor":int(g.actor),"aim_deg":g.aim_deg,"candidates":cs,"candidate_ranks":ranks_of(cs,order),"min_halfplane_margin":cr.min_margin})
				si+=1
			for k in 8:
				if int(cov[k])!=1:ok=false
			if not ok:continue
			feasible+=1
			var disp:float=c.distance_to(R.v(actual_poses[n3]))
			if best.is_empty() or disp<float(best.displacement):
				best={"pos":[c.x,c.y],"displacement":disp,"min_pair_sep":minsep,"min_halfplane_margin":mm,"per_source":per,"coverage":cov,"center_dist":c.length()}
	var ap:Vector2=R.v(actual_poses[n3])
	return {"status":"FOUND_ANALYTIC_ONLY" if feasible>0 else "NOT_FOUND","found":feasible>0,"n3_actor":n3,"n3_actual_pos":[ap.x,ap.y],"tried":tried,"feasible_count":feasible,"best":best,
		"scope":"analytic geometry only; NOT run in Main; NPC NOT actually moved; not native geometry; necessary-not-sufficient for variant legality"}

## New measurement only: exact live current snapshot, never injected into game.
func motion_snapshot(app,human:int,n3:int)->Dictionary:
	var a:Array=[]
	for i in 8:
		var p:Vector2=R.v(app.actors[i].pos)
		a.append({"actor":i,"pos":[p.x,p.y],"face":float(app.actors[i].face),"normal_speed":preload("res://scripts/movement.gd").speed(app.current,app.state,i)})
	return {"t":float(app.state.sim_time),"elapsed":float(app.elapsed),"actors":a,"human":human,"n3":n3,"scope":"actual current live Main snapshot, measurement only"}

func run_case(app,label:String,s:int,p:Dictionary,human:int,variant:bool,control_ref:Dictionary,first:bool,cfg:Dictionary={})->Dictionary:
	case_events=0;case_mismatch=0
	var ok_sel:bool=choose_method(app,s)
	check(ok_sel,label+" ordinary method selected")
	app.role_select.select(human);app.slot_select.select(0);app.seed_edit.text=str(int(p.seed))
	app.fresh_seed.button_pressed=false;app.speed_select.select(2);app.stop_failure.button_pressed=false
	app.demo=false;app.start_run(0,false);app.set_process(false);app.reset_camera()
	var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	var b:Dictionary=app.current
	check(not bool(app.demo) and int(app.state.human_actor)==human and not bool(app.checkpoint_assisted) and int(app.encounter.seed)==int(p.seed),label+" ordinary actual human run, correct seed, no assistance")
	check(int(p.beat_index)==0 and int(app.index)==0 and b.has("monitors") and b.has("monitor_preparation"),label+" starts at monitor beat")
	check(int(app.speed_select.selected)==2 and float(app.state.sim_time)==0.0,label+" 1x and t=0")
	check(layout_of(app.active_profile)=="astoh",label+" astoh layout")
	var same:bool=true
	for i in 8:
		if not R.v(b.positions[i]).is_equal_approx(p.poses[i]):same=false
	for k in 3:
		if int(b.monitors[k+1].actor)!=int(p.marked[k]):same=false
	check(same,label+" actual encounter equals local plan copy")
	var order:Array=[]
	for o in b.monitor_preparation.order:order.append(int(o))
	check(order.size()==8 and int(order[1])==human and human in p.marked,label+" human is order[1] (M2) and marked")
	var spawn:Vector2=R.v(app.actors[human].pos)
	check(spawn.is_equal_approx(R.v(b.spawn[human])),label+" human at neutral spawn")
	var mp:Dictionary=marked_realization(p,human)
	check(bool(mp.found),label+" independent marked realization found")
	var goal:Vector2=R.v(mp.pos)+R.v(cfg.get("goal_shift",Vector2.ZERO))
	var base_face:float=float(b.facing.get(human,0.0))
	var sgn:int=int(p.sign)
	var face_goal:float=base_face+(float(cfg.get("tilt",TILT_DEG))*sgn if variant else 0.0)
	var late_started:bool=false
	var n3_track:Array=[]
	var adaptive_trace:Array=[]
	var freeze_plan:String=""
	var freeze_unchanged:bool=true
	var order_before:String=JSON.stringify(b.monitor_preparation.order)
	var npc_faces_before:Array=[]
	for i in 8:npc_faces_before.append(float(b.facing.get(i,0.0)))
	var facing_stable:Dictionary={};var other_ready:Dictionary={}
	var npc_step_excess:float=0.0;var npc_walk_max:float=0.0;var npc_speed_law_max:float=0.0
	var steps:int=0;var settled:bool=false;var faced:bool=false;var still:int=0
	var settle_pose:Vector2=Vector2.ZERO;var drift:float=0.0;var walk_max:float=0.0;var excess:float=0.0;var dt_max:float=0.0
	var short_frames:int=0;var prep_reached:bool=false;var samples:Array=[];var any_pressed:bool=false
	while bool(app.journal.is_empty()) and bool(app.running) and steps<MAX_STEPS:
		var hp:Vector2=R.v(app.actors[human].pos)
		if cfg.has("late_at") and not late_started and float(app.elapsed)>=float(cfg.late_at):
			face_goal=base_face+float(cfg.late_tilt)*sgn;faced=false;late_started=true
		var dt:float=STEP
		if Prep.sorting(app.current,app.state):
			var pt:Vector2=Prep.point(human,app.current)
			var d0:float=hp.distance_to(pt)
			if d0<0.08:
				keys([]);prep_reached=true
			else:
				steer(app,pt,human)
				if d0<0.15:dt=maxf(d0/6.0,0.001);short_frames+=1
		elif not settled:
			var d:float=hp.distance_to(goal)
			if d<0.08:
				settled=true;keys([]);settle_pose=hp
			else:
				steer(app,goal,human)
				if d<0.15:dt=maxf(d/6.0,0.001);short_frames+=1
		elif still<4:
			keys([]);still+=1
		elif not faced:
			var diff:float=wrapf(face_goal-float(app.actors[human].face),-180.0,180.0)
			if absf(diff)<1.5:
				faced=true;keys([])
			else:
				keys([KEY_E] if diff>0 else [KEY_Q])
				if absf(diff)<3.75:dt=maxf(absf(diff)/150.0,0.001);short_frames+=1
		else:keys([])
		for c in ALL_KEYS:
			if Input.is_physical_key_pressed(c as Key):any_pressed=true
		dt_max=maxf(dt_max,dt)
		var before:Vector2=R.v(app.actors[human].pos)
		var npc_before:Array=[];var npc_speeds:Array=[]
		for i in 8:
			npc_before.append(R.v(app.actors[i].pos))
			npc_speeds.append(preload("res://scripts/movement.gd").speed(app.current,app.state,i))
		app._process(dt)
		var np:Vector2=R.v(app.actors[int(order[5])].pos)
		n3_track.append({"t":float(app.state.sim_time),"pos":[np.x,np.y],"dt":dt})
		var ad:Dictionary=app.state.get("monitor_adaptive",{})
		var entry:Dictionary={"t":float(app.state.sim_time),"elapsed":float(app.elapsed),"status":ad.get("status","absent"),"searches":ad.get("searches",0),"frozen":ad.get("frozen",false),"plan":ad.get("plan",{}).duplicate(true)}
		if adaptive_trace.is_empty() or JSON.stringify(entry.plan)!=JSON.stringify(adaptive_trace[-1].plan) or entry.status!=adaptive_trace[-1].status or entry.frozen!=adaptive_trace[-1].frozen:adaptive_trace.append(entry)
		if bool(ad.get("frozen",false)):
			var frozen_json:String=JSON.stringify(ad.get("plan",{}))
			if freeze_plan.is_empty():freeze_plan=frozen_json
			elif frozen_json!=freeze_plan:freeze_unchanged=false
		for i in 8:
			if i==human:continue
			var ds:float=R.v(app.actors[i].pos).distance_to(npc_before[i])
			npc_walk_max=maxf(npc_walk_max,ds/dt)
			npc_speed_law_max=maxf(npc_speed_law_max,float(npc_speeds[i]))
			npc_step_excess=maxf(npc_step_excess,ds-float(npc_speeds[i])*dt)
		if faced and settled:
			var n3:int=int(order[5])
			if facing_stable.is_empty():facing_stable=motion_snapshot(app,human,n3)
			var ready:bool=true
			for i in 8:
				if i!=human and i!=n3 and R.v(app.actors[i].pos).distance_to(R.v(b.positions[i]))>0.2:ready=false
			if ready and other_ready.is_empty():other_ready=motion_snapshot(app,human,n3)
		var st:float=before.distance_to(R.v(app.actors[human].pos))
		walk_max=maxf(walk_max,st/dt);excess=maxf(excess,st-6.0*dt)
		if settled:drift=maxf(drift,R.v(app.actors[human].pos).distance_to(settle_pose))
		if steps%40==0:
			var sp:Vector2=R.v(app.actors[human].pos)
			samples.append({"t":snappedf(float(app.state.sim_time),.001),"pos":[snappedf(sp.x,.001),snappedf(sp.y,.001)],"face":snappedf(float(app.actors[human].face),.01),"held":held_names()})
		steps+=1
	keys([])
	var journal_ok:bool=not bool(app.journal.is_empty())
	check(journal_ok and steps<MAX_STEPS,label+" actual journal obtained within bound")
	var jfail:Array=[];var cov:Array=[]
	if journal_ok:
		var j:Dictionary=app.journal[0]
		jfail=(j.get("failures",[]) as Array).duplicate()
		cov=find_cov(j,0)
	if cov.is_empty():cov=find_cov(app.state,0)
	var fin:Vector2=R.v(app.actors[human].pos);var face:float=float(app.actors[human].face)
	var face_err:float=absf(wrapf(face_goal-face,-180.0,180.0))
	check(dt_max<=STEP+1e-9,label+" dt<=0.025")
	check(excess<=0.00001 and float(app.sprint_left)==0.0 and float(app.dash_left)==0.0,label+" walk only <=6m/s, no sprint/dash")
	check(any_pressed and settled and fin.distance_to(goal)<0.1 and drift<0.000001,label+" human reached planned point by real input, drift<1e-6")
	check(faced and face_err<1.5,label+" QE facing within 1.5deg of desired face")
	check(prep_reached,label+" human reached sorting point during sorting")
	check(case_mismatch==0,label+" Input held state matched sent events")
	var npc_ok:bool=true;var npc_face_ok:bool=true
	for i in 8:
		if i==human:continue
		if i!=int(order[5]) and R.v(app.actors[i].pos).distance_to(p.poses[i])>0.2:npc_ok=false
		if absf(wrapf(float(app.actors[i].face)-float(npc_faces_before[i]),-180.0,180.0))>1.5:npc_face_ok=false
	var order_same:bool=JSON.stringify(app.current.monitor_preparation.order)==order_before
	check(npc_ok and order_same,label+" other six NPCs at fixed canonical positions, no rank change")
	check(not facing_stable.is_empty() and not other_ready.is_empty(),label+" actual facing/other-NPC readiness snapshots captured")
	check(npc_step_excess<0.00001 and npc_speed_law_max<=6.0,label+" actual allNPC motion within ordinary6m/s law; no sprint")
	var report:Dictionary=app.report()
	var vp:Dictionary=report.get("verdict_policy",{})
	check(str(vp.get("basis",""))=="actual_attack_status_death" and not bool(vp.get("guide_position_required",true)),label+" verdict_policy actual attack/status/death")
	var status_rows:Array=[];var status_ok:bool=true
	for si in 8:
		var cs:Dictionary=app.state.statuses[si]
		var active:Array=[]
		for key in cs:
			if float(cs[key].get("expires",0.0))>float(app.state.sim_time)+0.0001:active.append(str(key))
		active.sort()
		status_rows.append({"actor":si,"active":active,"entries":cs.duplicate(true)})
		if active!=["magic_vulnerability","twice_come_ruin"]:status_ok=false
		for expected in [{"key":"magic_vulnerability","duration":5.0},{"key":"twice_come_ruin","duration":7.0}]:
			if not cs.has(expected.key):status_ok=false
			elif absf(float(cs[expected.key].expires)-float(app.state.sim_time)-float(expected.duration))>0.001:status_ok=false
	var dead:Array=(app.state.get("dead",[]) as Array).duplicate()
	var all_one:bool=cov.size()==8
	for c2 in cov:
		if int(c2)!=1:all_one=false
	var all_errors:Array=(app.all_errors as Array).duplicate()
	var physical_pass:bool=journal_ok and jfail.is_empty() and all_one and int(app.beat_passed)==1 and int(app.beat_failed)==0 and all_errors.is_empty() and dead.is_empty() and status_ok
	if str(cfg.get("expected","pass"))=="pass":
		check(physical_pass,label+" actual journal PASS coverage 1x8, normal statuses, no death")
	elif str(cfg.expected)=="fail":
		check(not physical_pass and not jfail.is_empty(),label+" actual negative faithfully FAILS")
	var adaptive:Dictionary=app.state.get("monitor_adaptive",{})
	check(bool(adaptive.get("frozen",false)) and freeze_unchanged,label+" commitment freezes plan and never chases late input")
	check(int(adaptive.get("searches",0))>0 and int(adaptive.get("searches",0))<20,label+" event-driven bounded searches, not per-frame grid")
	var final_plan:Dictionary=adaptive.get("plan",{})
	if str(cfg.get("expected","pass"))=="pass":
		check(not final_plan.is_empty(),label+" actual current-input plan obtained")
		if not final_plan.is_empty():
			check(float(final_plan.computed_at)-float(app.state.beat_started)<float(b.duration)-1.25,label+" plan computed before commitment")
			check(float(final_plan.elapsed)+float(final_plan.eta)<=float(b.duration)-.2+1e-6,label+" actual plan physically reachable by cutoff")
			check(R.v(app.actors[int(order[5])].pos).distance_to(R.v(final_plan.goal))<.001,label+" N3 actually arrived at chosen goal")
			if variant:
				check(str(final_plan.mode)=="adaptive_search" and float(final_plan.margin)>=.05,label+" variant uses robust computed grid plan")
				check(R.v(final_plan.goal).distance_to(R.v(b.positions[int(order[5])]))>.1,label+" N3 actually shifts from canonical")
			else:check(str(final_plan.mode)=="baseline_retained" and R.v(final_plan.goal).is_equal_approx(R.v(b.positions[int(order[5])])),label+" control retains exact original goal")
	var resolution:Dictionary={}
	for event in app.state.get("timeline",[]):
		if str(event.get("kind",""))=="monitor_resolution":resolution=event.duplicate(true)
	var actual_poses:Array=[];var actual_faces:Array=[];var actors_row:Array=[]
	for i in 8:
		var a=app.actors[i];var ap:Vector2=R.v(a.pos)
		actual_poses.append(ap);actual_faces.append(float(a.face))
		actors_row.append({"actor":i,"rank":order.find(i),"pos":[ap.x,ap.y],"face":float(a.face)})
	check(cov.size()==8 and resolution.get("sources",[]).size()==4,label+" actual coverage/sources present")
	check(npc_face_ok,label+" NPC faces remain canonical")
	var analytic_matches:bool=true
	var actual_geometry:Array=[]
	var control_two:bool=true
	var mc:Dictionary=monitor_check(b)
	var actual_srcs:Array=resolution.get("sources",[])
	for si in mc.sources.size():
		var geom:Dictionary=source_geom(mc.sources[si],actual_poses,actual_faces)
		var cand:Dictionary=cands_of(geom,actual_poses)
		actual_geometry.append({"source_actor":geom.actor,"origin":[geom.o.x,geom.o.y],"aim_deg":geom.aim_deg,"radius":geom.radius,"exclude":geom.exclude,"kind":geom.kind})
		if si>=actual_srcs.size() or cand.cands!=actual_srcs[si].get("candidates",[]):analytic_matches=false
		if cand.cands.size()!=2:control_two=false
	check(analytic_matches,label+" independent halfplane candidates match actual resolution")
	if str(cfg.get("expected","pass"))=="pass":check(control_two,label+" each actual source exactly two candidates")
	var pairs:Array=[]
	for src in resolution.get("sources",[]):pairs.append(ranks_of(src.get("targets",[]),order))
	var control_pairs:Array=pairs if not variant else control_ref.get("pairs",[])
	if variant:
		check(not control_pairs.is_empty(),label+" control rank pairs available for same seed")
		if str(cfg.get("expected","pass"))=="pass":check(pairs==control_pairs,label+" actual restored all four canonical target pairs")
	var cf:Dictionary={"status":"NOT_RUN_NEW_RUNTIME_ACCEPTANCE","found":false}
	var outcome:String="ACTUAL_PASS" if physical_pass else "ACTUAL_FAIL"
	var repro:String="N_A_control"
	if variant:repro="ACTUAL_FAILURE_OBSERVED" if not physical_pass else "REPRO_UNKNOWN_no_actual_failure"
	if first:extra.first_case=label
	return {"label":label,"kind":"variant" if variant else "control","seed":int(p.seed),"boss_sign":sgn,"boss_angle":float(p.boss),"method_index":s,
		"human":human,"human_role":Enc.ROLES[human],"role_rank":"M2","rank1":order.find(human),"order":order,
		"face_baseline":base_face,"face_goal":face_goal,"face":face,"face_err":face_err,"tilt_deg":(float(cfg.get("tilt",TILT_DEG))*sgn if variant else 0.0),"cfg":cfg,"n3_track":n3_track,"adaptive_state":adaptive.duplicate(true),"adaptive_trace":adaptive_trace,"freeze_unchanged":freeze_unchanged,
		"timing":{"facing_stable":facing_stable,"other_npcs_ready":other_ready,"npc_walk_max":npc_walk_max,"npc_step_excess":npc_step_excess,"npc_speed_law_max":npc_speed_law_max},"input_events":case_events,"key_mismatch":case_mismatch,"dt_max":dt_max,"walk_max":walk_max,"final_drift":drift,"steps":steps,"short_frames":short_frames,
		"final_pos":[fin.x,fin.y],"actual_source_geometry":actual_geometry,"actual_resolution":resolution,"actual_rank_pairs":pairs,"coverage":cov,"journal_failures":jfail,"all_errors":all_errors,
		"verdict_policy":vp,"statuses":status_rows,"dead":dead,"actors":actors_row,"npc_fixed":npc_ok,"npc_faces_fixed":npc_face_ok,"order_unchanged":order_same,
		"physical_pass":physical_pass,"outcome":outcome,"repro":repro,"samples":samples,"counterfactual_n3":cf,
		"scope":"actual Main headless Input, one astoh seed/M2 case; tilt is synthetic probe; counterfactual analytic only"}

func press_r(app,human:int,seed_value:int)->void:
	keys([])
	var before_errors:int=(app.all_errors as Array).size()
	var before_journal:int=(app.journal as Array).size()
	var before_obs:bool=app.state.has("monitor_preparation_observed")
	var before_adaptive:bool=app.state.has("monitor_adaptive")
	var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	send_key(KEY_R,true);Input.flush_buffered_events();await process_frame
	send_key(KEY_R,false);Input.flush_buffered_events();await process_frame
	app.set_process(false)
	var spawn_ok:bool=true
	for i in 8:
		if not R.v(app.actors[i].pos).is_equal_approx(R.v(app.current.spawn[i])):spawn_ok=false
	check(before_adaptive and not app.state.has("monitor_adaptive"),"R clears actual previous adaptive plan and frozen cache")
	check(int(app.encounter.seed)==seed_value,"R retains seed")
	check(spawn_ok and float(app.state.sim_time)==0.0,"R neutral spawn, sim_time 0")
	check((app.all_errors as Array).is_empty() and (app.journal as Array).is_empty() and not app.state.has("monitor_preparation_observed"),"R clears errors journal and preparation observation")
	var hp:Vector2=R.v(app.actors[human].pos)
	extra.r={"seed":int(app.encounter.seed),"sim_time":float(app.state.sim_time),"human_pos":[hp.x,hp.y],
		"before":{"errors":before_errors,"journal":before_journal,"prep_observed":before_obs,"adaptive":before_adaptive},
		"after":{"errors":(app.all_errors as Array).size(),"journal":(app.journal as Array).size(),"prep_observed":app.state.has("monitor_preparation_observed"),"adaptive":app.state.has("monitor_adaptive")},
		"note":"recorded observation; earlier rows are deep copies and are not asserted cleared"}

func _initialize()->void:call_deferred("run")

func run()->void:
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
	var method:int=-1
	for s in range(1,7):
		var ok:bool=choose_method(app,s)
		var lay:String="";var nm:String=""
		if ok:lay=layout_of(app.active_profile);nm=str(app.strategy_select.get_item_text(s))
		catalog.append({"index":s,"ok":ok,"name":nm,"layout":lay})
		if ok and lay=="astoh" and method<0:method=s
	check(method>=0,"astoh/Elemental method found among ordinary selectors")
	if method>=0:extra.method_name=str(catalog[method-1].name)
	check(str(extra.get("method_name",""))=="Astoh / HHTTDDDD","actual selected method name Astoh / HHTTDDDD")
	var by_sign:Dictionary={1:[],-1:[]}
	var scanned:int=0
	if method>=0 and choose_method(app,method):
		for sv in range(1,SEED_SCAN_MAX+1):
			scanned=sv
			var p:Dictionary=plan(app,sv)
			if p.is_empty():continue
			var arr:Array=by_sign[int(p.sign)]
			if arr.size()<SEEDS_PER_SIGN:arr.append(p)
			if (by_sign[1] as Array).size()>=SEEDS_PER_SIGN and (by_sign[-1] as Array).size()>=SEEDS_PER_SIGN:break
	extra.seed_scan={"range":[1,SEED_SCAN_MAX],"stopped_at":scanned,"east":(by_sign[1] as Array).map(func(q):return int(q.seed)),"west":(by_sign[-1] as Array).map(func(q):return int(q.seed))}
	check((by_sign[1] as Array).size()==SEEDS_PER_SIGN and (by_sign[-1] as Array).size()==SEEDS_PER_SIGN,"3 seeds per Boss sign within scan 1..128")
	var first:bool=true
	for sg in [1,-1]:
		for p in by_sign[sg]:
			var pd:Dictionary=p
			var order:Array=pd.beat.monitor_preparation.order
			var human:int=int(order[1])
			var ctl:Dictionary=run_case(app,"CTRL_s%d_sign%d"%[int(pd.seed),sg],method,pd,human,false,{},first)
			rows.append(ctl);print("MONITOR_ADAPTIVE_CASE ",JSON.stringify({"label":ctl.label,"outcome":ctl.outcome,"coverage":ctl.coverage,"cf":ctl.counterfactual_n3.status}))
			if first:
				first=false
				await press_r(app,human,int(pd.seed))
			var var_row:Dictionary=run_case(app,"VAR_s%d_sign%d"%[int(pd.seed),sg],method,pd,human,true,{"pairs":ctl.actual_rank_pairs},false)
			var_row.control_final_pos=ctl.final_pos
			var_row.same_final_pos_as_control=R.v(var_row.final_pos).distance_to(R.v(ctl.final_pos))<0.1
			check(bool(var_row.same_final_pos_as_control),"same seed control and variant physical position match")
			rows.append(var_row);print("MONITOR_ADAPTIVE_CASE ",JSON.stringify({"label":var_row.label,"outcome":var_row.outcome,"repro":var_row.repro,"coverage":var_row.coverage,"cf":var_row.counterfactual_n3.status}))
			if int(pd.seed)==1:await press_r(app,human,int(pd.seed))
	# Distinct public input probes exclude a hardcoded six-case destination.
	for sg in [1,-1]:
		var pd:Dictionary=by_sign[sg][0]
		var h:int=int(pd.beat.monitor_preparation.order[1])
		var ctl:Dictionary={}
		for rr in rows:
			if int(rr.seed)==int(pd.seed) and rr.kind=="control":ctl=rr
		for cfg in [{"tilt":13.0},{"tilt":11.0,"goal_shift":Vector2(0,-.25)}]:
			var tag:String="ANGLE13" if float(cfg.tilt)==13.0 else "SHIFT"
			var rr:Dictionary=run_case(app,"%s_s%d_sign%d"%[tag,int(pd.seed),sg],method,pd,h,true,{"pairs":ctl.actual_rank_pairs},false,cfg)
			rows.append(rr)
	# Large and late input are observed, never guaranteed rescued by the NPC.
	var neg:Dictionary=by_sign[1][0]
	var nh:int=int(neg.beat.monitor_preparation.order[1])
	var ref:Dictionary={}
	for rr in rows:
		if int(rr.seed)==int(neg.seed) and rr.kind=="control":ref={"pairs":rr.actual_rank_pairs}
	for cfg in [{"tilt":30.0,"expected":"record_negative"},{"tilt":180.0,"expected":"fail"},{"tilt":0.0,"late_at":8.9,"late_tilt":120.0,"expected":"fail"}]:
		var rr:Dictionary=run_case(app,"NEG_%d"%rows.size(),method,neg,nh,true,ref,false,cfg)
		rows.append(rr)
	keys([])
	for c in ALL_KEYS:
		if Input.is_physical_key_pressed(c as Key):check(false,"key released at cleanup")
	check(rows.size()==19,"exactly 19 rows")
	check(key_mismatch==0,"global Input held state matched sent events")
	var observed_fail:int=0;var cf_found:int=0
	for r in rows:
		if r.kind=="variant" and not bool(r.physical_pass):observed_fail+=1
		if bool(r.counterfactual_n3.found):cf_found+=1
	extra.summary={"variant_actual_failures":observed_fail,"variants":6,"counterfactual_found_rows":cf_found,
		"interpretation":"all16 positive courses require actual clean attack/status/death outcomes; three negative probes are not rescued; no player-coordinate verdict gate"}
	app.queue_free();await process_frame
	print("MONITOR_ADAPTIVE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"catalog":catalog,"extra":extra,"key_mismatch":key_mismatch,
		"scope":"actual adaptive Main headless Input WASD/QE/R, astoh only, 19 bounded cases; not native/Web/GPU, not all roles/seeds or official angle calibration"}))
	quit(1 if not failures.is_empty() or rows.size()!=19 else 0)
