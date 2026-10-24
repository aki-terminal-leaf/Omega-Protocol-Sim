# SPDX-License-Identifier: MIT
extends SceneTree
## Focused regression for later-round source repair (NOT manual/fullguide certification):
## conditional later-round HW partner choice lock (hw_cooperation.replacement_actor key
## hw_tower_choice_<round>_<min>). Reuses hw_firstwave_input.gd conventions: actual Main
## scene, controlled family, physical WASD via Input.parse_input_event, manual _process.
## Prelude HW0..34 is all-NPC production pathing (demo=true, human_actor=-1); handoff at
## HW34 to real human6. Every course is SYNTHETIC_AUTO_PRELUDE_NOT_ORDINARY_MANUAL.
const Main=preload("res://scenes/main.tscn")
const E=preload("res://scripts/encounters.gd")
const C=preload("res://scripts/hw_courses.gd")
const R=preload("res://scripts/rules.gd")
const KEYS=[KEY_W,KEY_A,KEY_S,KEY_D]
const HUMAN:=6
const METHOD:=1
const DT:=0.025
const MAX_STEPS:=2400
const HANDOFF_AT:=34.0
const TOWER2_AT:=45.0
const STOP_AT:=45.05
const ENTER:=0.2
const TOUCH_HOLD:=0.2
const TRACE_CAP:=1000
const LABEL:="SYNTHETIC_AUTO_PRELUDE_NOT_ORDINARY_MANUAL"
var checks:=0
var failures:=0
var failure_labels:Array=[]
var rows:Array=[]
var held:Dictionary={}

func check(ok:bool,label:String):
	checks+=1
	if not ok:
		failures+=1;failure_labels.append(label);print("HW LATER DIAGNOSTIC FIXTURE FAIL ",label)

func keys(wanted:Array):
	for code in KEYS:
		var down:bool=code in wanted
		if bool(held.get(code,false))==down:continue
		var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e);held[code]=down
	Input.flush_buffered_events()

func held_names()->Array:
	var out:Array=[]
	for code in KEYS:
		if Input.is_physical_key_pressed(code):out.append(OS.get_keycode_string(code))
	return out

# Same 8-direction physical-key steering as hw_firstwave_input.gd (no sprint/dash).
func steer(app,target:Vector2):
	var d:Vector2=(target-R.v(app.actors[app.player].pos)).rotated(app.arena.camera_yaw)
	if d.length()<.10:keys([]);return
	var wanted:Array=[]
	if absf(d.x)>absf(d.y)*.4142:wanted.append(KEY_D if d.x>0 else KEY_A)
	if absf(d.y)>absf(d.x)*.4142:wanted.append(KEY_S if d.y>0 else KEY_W)
	keys(wanted)

func a2(v)->Array:
	var p:Vector2=R.v(v);return [snappedf(p.x,.001),snappedf(p.y,.001)]

func hw_now(app)->float:
	return float(app.state.sim_time)-float(app.state.hw.start)

# Public current rot/bug exactly as replacement_actor tests them.
func bug_state(buffs:Dictionary)->Dictionary:
	return {"colour":"red" if buffs.has("red") else ("blue" if buffs.has("blue") else ""),"bug":"overflow" if buffs.has("overflow") else ("sync" if buffs.has("sync") else "")}

func status_summary(app)->Array:
	var out:Array=[]
	for a in 8:
		var names:Array=app.state.statuses[a].keys().map(func(k):return str(k));names.sort()
		var d:Dictionary={}
		for n in names:d[n]=snappedf(float(app.state.statuses[a][n].get("expires",0.0))-float(app.state.hw.start),.001)
		out.append(d)
	return out

func drawn_towers(app)->Array:
	return app.arena.visible_damage_shapes.filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower")

func tower_events(app,round_index:int)->Array:
	return app.state.hw.history.filter(func(e):return e.kind=="hw_tower" and int(e.get("round",-1))==round_index)

func choice_keys(app)->Dictionary:
	var out:Dictionary={}
	for k in app.state.hw.keys():
		if str(k).begins_with("hw_tower_choice_1_"):out[str(k)]=app.state.hw[k]
	return out

func setup(app)->bool:
	keys([]);app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(HUMAN)
	var found:=false
	for n in app.filtered.size():
		if app.filtered[n].id=="p3_hello":app.choose_mechanic(n);app.strategy_select.select(METHOD);app.choose_strategy(METHOD);found=true;break
	check(found,"setup: p3_hello catalog entry found")
	if not found:return false
	# demo=true so actual Main new_state/begin_beat give human_actor=-1 and _process moves all 8 by bot_goal.
	app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
	# Controlled colour/orientation/identity-order family (same pattern as firstwave fixture).
	var ctx=E.new();ctx.profile={"id":str(app.encounter.profile)};ctx.order=range(8);ctx.positions=[];ctx.labels=[]
	for a in 8:ctx.positions.append(R.direction(a*45.0)*5.0);ctx.labels.append("")
	C.append_family(ctx,[0,0,0,0],"red")
	app.encounter.beats=ctx.beats;app.encounter.assignments=ctx.order;app.index=0;app.player=HUMAN;app.demo=true
	app.state=app.new_state();app.actors=[];app.running=true;app.paused=false;app.all_errors=[];app.journal=[];app.samples=[];app.retry_history=[];app.beat_passed=0;app.beat_failed=0
	app.begin_beat(true);app.reset_camera();var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	var ok:bool=app.demo and int(app.state.human_actor)==-1 and not app.checkpoint_assisted and app.player==HUMAN and app.state.has("hw")
	check(ok,"setup: all-NPC prelude config demo=true human_actor=-1 hw active")
	check(int(app.speed_select.selected)==2,"setup: Main speed x1.0")
	return ok

func analyse_reveal(app,towers:Array,pose:Vector2,now:float)->Dictionary:
	var hs:Dictionary=bug_state(app.state.statuses[HUMAN])
	var peers:Array=[]
	for a in 8:
		if a==HUMAN or a in app.state.dead:continue
		var s:Dictionary=bug_state(app.state.statuses[a])
		if hs.colour!="" and hs.bug!="" and s.colour==hs.colour and s.bug==hs.bug:peers.append(a)
	var colour:String=str(hs.colour)
	var matching:Array=towers.filter(func(s):return str(s.colour)==colour) if colour!="" else []
	var res:Dictionary={"at":snappedf(now,.001),"pose":a2(pose),"human_state":hs,"same_state_peers":peers,"drawn":towers.map(func(s):return {"pos":a2(s.pos),"colour":str(s.colour),"radius":float(s.radius)}),"matching":matching.size(),"drive_valid":false,"reason":""}
	if colour=="":res.reason="human has no current red/blue rot";return res
	if matching.size()!=2:res.reason="drawn same-colour tower count %d != 2"%matching.size();return res
	var p0:Vector2=R.v(matching[0].pos);var p1:Vector2=R.v(matching[1].pos)
	var d0:=pose.distance_to(p0);var d1:=pose.distance_to(p1)
	res.distances=[snappedf(d0,.001),snappedf(d1,.001)]
	if absf(d0-d1)<0.5:res.reason="own/alternate distances not distinguishable";return res
	res.own=p0 if d0<d1 else p1;res.alternate=p1 if d0<d1 else p0;res.drive_valid=true
	# LABELLED DIAGNOSTIC INSTRUMENTATION ONLY (after public reveal; never a driver target):
	# authored pair membership (actor IDs only, not goals).
	var pair:Array=[]
	for c in app.current.get("hw_tower_cooperations",[]):
		var ids:Array=c.actors.map(func(v):return int(v))
		if int(c.round)==1 and HUMAN in ids:pair=ids
	res.instrumentation_authored_pair=pair
	var partner:int=-1
	for a in pair:
		if a!=HUMAN:partner=a
	res.instrumentation_partner=partner
	res.replacement_prereq_met=hs.bug!="" and partner>=0 and partner in peers
	return res

func course(app,mode:String)->Dictionary:
	var row:Dictionary={"mode":mode,"label":LABEL,"synthetic_auto_prelude":true,"ordinary_manual":false,"method":METHOD,"human":HUMAN,"family":{"orientations":[0,0,0,0],"colour":"red","order":range(8),"seed":17391}}
	var steps:=0
	if not setup(app):row.setup_ok=false;rows.append(row);return row
	row.setup_ok=true
	# ---- Prelude: real Main all-NPC stepping HW0 -> HW34, no state edits.
	var prelude_trace:Array=[]
	while app.running and steps<MAX_STEPS and hw_now(app)<HANDOFF_AT-.000001:
		keys([])
		app._process(minf(DT,HANDOFF_AT-hw_now(app)));steps+=1
		if steps%40==0:prelude_trace.append({"t":snappedf(hw_now(app),.01),"h":a2(app.actors[HUMAN].pos)})
	var r0:Array=tower_events(app,0)
	var prelude:Dictionary={"steps":steps,"hw_time":snappedf(hw_now(app),.000001),"running":app.running,"round0_towers":r0.map(func(e):return {"pos":e.pos,"colour":e.colour,"hits":e.hits}),"runtime_failures":app.state.runtime_failures.duplicate(),"all_errors":app.all_errors.duplicate(true),"dead":app.state.dead.duplicate(),"blasts":app.state.hw.history.filter(func(e):return e.kind=="hw_blast").map(func(e):return {"t":e.time,"a":e.actor,"s":e.status,"hits":e.hits}),"patches":app.state.hw.history.filter(func(e):return e.kind=="hw_patch").map(func(e):return {"t":e.time,"id":e.id}),"trace_1hz":prelude_trace}
	var prelude_clean:bool=app.running and absf(hw_now(app)-HANDOFF_AT)<.001 and r0.size()==4 and r0.all(func(e):return e.hits.size()==1) and app.state.runtime_failures.is_empty() and app.all_errors.is_empty() and app.state.dead.is_empty()
	prelude.clean=prelude_clean
	row.prelude=prelude
	check(prelude_clean,"%s prelude: clean real HW0..34 (4 one-soaker round0 towers, no failures/errors/dead)"%mode)
	# ---- Handoff at HW34: switch actual Main to real human6; keep poses/statuses/clocks/history.
	app.demo=false;app.player=HUMAN;app.state.human_actor=HUMAN
	var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	var base_failures:int=app.state.runtime_failures.size();var base_errors:int=app.all_errors.size();var base_dead:Array=app.state.dead.duplicate()
	row.handoff={"hw_time":snappedf(hw_now(app),.000001),"beat_index":app.index,"beat_title":str(app.current.get("title","")),"positions":app.actors.map(func(x):return a2(x.pos)),"statuses":status_summary(app),"history_size":app.state.hw.history.size(),"failures":base_failures,"errors":base_errors,"dead":base_dead}
	check(not app.demo and int(app.state.human_actor)==HUMAN and app.player==HUMAN,"%s handoff: actual human6 demo=false"%mode)
	# ---- Real human phase.
	var phase:="wait_reveal";var reveal:Dictionary={};var own:=Vector2.ZERO;var alt:=Vector2.ZERO
	var enter_t:=-1.0;var left_alt_t:=-1.0;var own_t:=-1.0;var alt_reached_t:=-1.0
	var max_excess:=-INF;var max_npc_excess:=-INF;var pressed:=false;var trace:Array=[];var key_events:Array=[];var last_sig:=JSON.stringify({})
	var key_ever:=false;var key_at_return:Dictionary={};var key_pre45:Dictionary={};var new_events:Array=[]
	var min_peer_alt:=INF;var min_peer_own:=INF;var peer:=-1
	while app.running and steps<MAX_STEPS and hw_now(app)<STOP_AT-.000001:
		var now:=hw_now(app);var here:Vector2=R.v(app.actors[HUMAN].pos)
		if phase=="wait_reveal":
			var towers:Array=drawn_towers(app)
			if towers.size()==4:
				reveal=analyse_reveal(app,towers,here,now)
				if reveal.drive_valid:own=reveal.own;alt=reveal.alternate;phase="drive_alt";peer=int(reveal.get("instrumentation_partner",-1))
				else:phase="hold_invalid"
		# Phase switches use only public distance and actual sim clock.
		if phase=="drive_alt" and here.distance_to(alt)<=ENTER:
			alt_reached_t=now
			if mode=="alternate_hold":phase="hold_alt"
			else:phase="touch_hold";enter_t=now
		if phase=="touch_hold" and now>=(maxf(40.8,enter_t+TOUCH_HOLD) if mode.ends_with("_late") else enter_t+TOUCH_HOLD)-.000001:phase="drive_own";left_alt_t=now
		if phase=="drive_own" and here.distance_to(own)<=ENTER:
			phase="hold_own";own_t=now;key_at_return=choice_keys(app)
		match phase:
			"drive_alt":steer(app,alt)
			"drive_own":steer(app,own)
			_:keys([])
		pressed=pressed or not held_names().is_empty()
		if now<TOWER2_AT-.000001:key_pre45=choice_keys(app)
		var before:Vector2=R.v(app.actors[HUMAN].pos);var dt:=minf(DT,STOP_AT-now)
		var npc_before:Array=app.actors.map(func(a):return R.v(a.pos))
		app._process(dt);steps+=1
		for actor in 8:
			if actor!=HUMAN:max_npc_excess=maxf(max_npc_excess,npc_before[actor].distance_to(R.v(app.actors[actor].pos))-6.0*dt)
		var after:Vector2=R.v(app.actors[HUMAN].pos)
		max_excess=maxf(max_excess,before.distance_to(after)-6.0*dt)
		var t:=snappedf(hw_now(app),.001)
		var ck:Dictionary=choice_keys(app);var sig:=JSON.stringify(ck)
		if not ck.is_empty():key_ever=true
		if sig!=last_sig:key_events.append({"t":t,"keys":ck,"phase":phase,"h":a2(after)});last_sig=sig
		if app.state.runtime_failures.size()>base_failures+new_events.filter(func(x):return x.k=="failure").size():
			for i in range(base_failures+new_events.filter(func(x):return x.k=="failure").size(),app.state.runtime_failures.size()):new_events.append({"k":"failure","t":t,"r":str(app.state.runtime_failures[i])})
		if peer>=0 and alt!=Vector2.ZERO:
			var pp:Vector2=R.v(app.actors[peer].pos);min_peer_alt=minf(min_peer_alt,pp.distance_to(alt));min_peer_own=minf(min_peer_own,pp.distance_to(own))
		if steps%4==0 and trace.size()<TRACE_CAP:
			trace.append({"t":t,"ph":phase,"h":a2(after),"p":a2(app.actors[peer].pos) if peer>=0 else null,"k":held_names(),"c":ck})
	keys([])
	var r1:Array=tower_events(app,1)
	var hs:Dictionary=reveal.get("human_state",{})
	var same:Array=r1.filter(func(e):return str(e.colour)==str(hs.get("colour","")))
	var all_one:bool=r1.size()==4 and r1.all(func(e):return e.hits.size()==1)
	var new_dead:Array=app.state.dead.filter(func(a):return a not in base_dead)
	var new_fail:Array=app.state.runtime_failures.slice(base_failures)
	var stacked:bool=same.size()==2 and ((same[0].hits.size()>=2 and same[1].hits.is_empty()) or (same[1].hits.size()>=2 and same[0].hits.is_empty()))
	row.reveal=reveal.duplicate(true)
	if row.reveal.has("own"):row.reveal.own=a2(own);row.reveal.alternate=a2(alt)
	row.phase_times={"alt_reached":snappedf(alt_reached_t,.001),"touch_enter":snappedf(enter_t,.001),"left_alt":snappedf(left_alt_t,.001),"own_reached":snappedf(own_t,.001),"final_phase":phase}
	row.steps=steps;row.final_hw_time=snappedf(hw_now(app),.000001);row.max_walk_excess=max_excess;row.max_npc_walk_excess=max_npc_excess;row.pressed=pressed
	row.sprint_left=float(app.sprint_left);row.dash_left=float(app.dash_left)
	row.round1_towers=r1.map(func(e):return {"t":e.time,"pos":e.pos,"colour":e.colour,"hits":e.hits})
	row.same_colour_tower_hits=same.map(func(e):return e.hits)
	row.choice_key_ever_set=key_ever;row.choice_key_at_return=key_at_return;row.choice_key_pre45=key_pre45;row.choice_key_events=key_events
	row.peer_motion={"peer_instrumentation":peer,"min_dist_to_alternate":snappedf(min_peer_alt,.001) if min_peer_alt<INF else null,"min_dist_to_own":snappedf(min_peer_own,.001) if min_peer_own<INF else null,"peer_goal_not_queried":"Interactions.bot_goal/replacement_actor mutate state.hw; deliberately not called"}
	row.final_statuses=status_summary(app)
	row.actual_hw_history=app.state.hw.history.duplicate(true)
	row.actual_status_timeline=app.state.timeline.duplicate(true)
	row.new_all_errors=app.all_errors.slice(base_errors)
	row.all_runtime_failures=app.state.runtime_failures.duplicate();row.all_errors=app.all_errors.duplicate(true);row.dead=app.state.dead.duplicate()
	row.new_failures=new_fail;row.new_failure_events=new_events;row.new_dead=new_dead
	row.all_one_occupant=all_one;row.same_colour_stacked_one_empty=stacked
	row.trace=trace;row.trace_rows=trace.size()
	# ---- Fixture validity (separate from product outcome).
	check(steps<=MAX_STEPS and hw_now(app)>=STOP_AT-.000001,"%s bounded run reached HW45.05 within %d steps"%[mode,MAX_STEPS])
	check(r1.size()==4,"%s four actual round2 tower judgments recorded"%mode)
	check(max_excess<=.000004 and float(app.sprint_left)==0 and float(app.dash_left)==0,"%s human motion <=6*dt+4e-6, no sprint/dash"%mode)
	check(max_npc_excess<=.000004,"%s every NPC step obeys <=6*dt+4e-6"%mode)
	check(KEYS.all(func(k):return not Input.is_physical_key_pressed(k)),"%s all physical keys released"%mode)
	check(trace.size()<=TRACE_CAP,"%s trace cap"%mode)
	check(not reveal.is_empty() and float(reveal.at)>=HANDOFF_AT and float(reveal.at)<=35.5,"%s public four-tower reveal observed ~HW35"%mode)
	var prereq:bool=prelude_clean and bool(reveal.get("drive_valid",false)) and bool(reveal.get("replacement_prereq_met",false))
	row.prerequisites_met=prereq
	var product_ok:bool=all_one and new_fail.is_empty() and row.new_all_errors.is_empty() and new_dead.is_empty() and same.size()==2 and same.all(func(e):return e.hits.size()==1)
	row.product_outcome="PASS" if product_ok else "FAIL"
	if mode=="alternate_hold":
		if prereq:check(product_ok,"control alternate_hold: NPC fills own, all4 one occupant, no new failures/dead")
		row.control="EVALUATED" if prereq else "NOT_APPLICABLE_PREREQUISITES_ABSENT"
	else:
		if bool(reveal.get("drive_valid",false)) and new_dead.is_empty():
			check(enter_t>=0 and own_t>=0 and own_t<TOWER2_AT,"touch_alternate_then_return: touched alternate and returned to own before HW45")
	rows.append(row)
	print("HW_LATER_CHOICE_INPUT_COURSE ",JSON.stringify(row))
	return row

func classify(a:Dictionary,b:Dictionary)->Dictionary:
	if not a.get("prerequisites_met",false) or not b.get("prerequisites_met",false):
		return {"class":"INCONCLUSIVE","reason":"status/pair/geometry prerequisites absent or prelude unclean; no bug inference"}
	if str(a.get("product_outcome",""))!="PASS":
		return {"class":"INCONCLUSIVE","reason":"positive control alternate_hold failed: fixture/control failure, NOT proof of return-lock cause"}
	if float(b.phase_times.own_reached)<0:
		return {"class":"INCONCLUSIVE","reason":"course B did not complete physical return protocol"}
	if not b.get("choice_key_ever_set",false):
		return {"class":"INCONCLUSIVE","reason":"hw_tower_choice_1_* never set; lock not engaged in this run"}
	var pair:Array=b.reveal.get("instrumentation_authored_pair",[])
	var pair_stack:=false
	for hits in b.get("same_colour_tower_hits",[]):
		var normalized:Array=hits.map(func(v):return int(v));normalized.sort()
		var expected:Array=pair.duplicate();expected.sort()
		if expected.size()==2 and normalized==expected:pair_stack=true
	var unrelated_early:bool=not b.new_dead.is_empty()
	for error in b.new_all_errors:
		if not str(error).begins_with("HW: tower requires one soaker, got"):unrelated_early=true
	for event in b.get("new_failure_events",[]):
		if float(event.t)<TOWER2_AT-.000001 or not str(event.r).begins_with("HW: tower requires one soaker, got"):unrelated_early=true
	if unrelated_early:
		return {"class":"INCONCLUSIVE","reason":"unrelated death/error or pre-tower failure; do not attribute to return-lock"}
	if b.get("same_colour_stacked_one_empty",false) and pair_stack and not (b.choice_key_at_return as Dictionary).is_empty() and b.choice_key_at_return==b.choice_key_pre45:
		return {"class":"CONFIRMED_CONTROLLED_CASE_ONLY","reason":"both at one same-colour tower, other empty, choice key retained after return"}
	if str(b.get("product_outcome",""))=="PASS":
		return {"class":"REFUTED","reason":"return to own succeeded with all4 one occupant"}
	return {"class":"INCONCLUSIVE","reason":"other/unrelated failure pattern; see course B failures"}

func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
	var a:Dictionary=course(app,"alternate_hold")
	var b:Dictionary=course(app,"touch_alternate_then_return")
	var late:Dictionary=course(app,"touch_alternate_then_return_late")
	check(late.get("prerequisites_met",false) and late.get("product_outcome","")=="FAIL" and not late.get("new_failures",[]).is_empty(),"late physical return retains actual failure; no human/NPC teleport or outcome rescue")
	check(a.has("handoff") and b.has("handoff") and late.has("handoff") and a.handoff==b.handoff and a.handoff==late.handoff,"prelude handoff identical across all three fresh courses (determinism)")
	check(b.get("product_outcome","")=="PASS" and b.get("all_one_occupant",false) and b.get("new_failures",[]).is_empty() and b.get("new_all_errors",[]).is_empty() and b.get("new_dead",[]).is_empty(),"early return must pass actual four towers, attacks/status/death outcomes")
	check(b.get("choice_key_at_return",{})=={"hw_tower_choice_1_6":0} and b.get("choice_key_pre45",{})=={"hw_tower_choice_1_6":0},"early return must replace obsolete side1 with side0 before actual judgment")
	check(late.get("choice_key_pre45",{})=={"hw_tower_choice_1_6":0},"late return also updates choice; failure cannot pass by retaining old lock")
	var late_hits:Array=late.get("same_colour_tower_hits",[])
	check(late_hits.size()==2 and late_hits.any(func(h):return h==[HUMAN]) and late_hits.any(func(h):return h.is_empty()),"late failure is human-only own tower plus empty alternate, not obsolete human/peer double-soak")
	var late_peer_rows:Array=late.trace.filter(func(r):return r.p is Array and int(r.c.get("hw_tower_choice_1_6",-1))==0)
	check(late_peer_rows.size()>1 and R.v(late_peer_rows[-1].p).distance_to(R.v(late_peer_rows[0].p))>1.0 and R.v(late_peer_rows[-1].p).distance_to(R.v(late.reveal.alternate))<R.v(late_peer_rows[0].p).distance_to(R.v(late.reveal.alternate))-1.0,"late NPC physically leaves old hold and progresses toward public alternate after side update")
	check(late.dead.is_empty() and late.new_failure_events.all(func(e):return absf(float(e.t)-45.0)<.000001 and (str(e.r).begins_with("HW: tower requires one soaker, got") or str(e.r).begins_with("HW: overlapping HW magic damage:"))),"late expected consequence only at actual45 tower/overflow, no earlier unrelated failure")
	var cls:Dictionary=classify(a,b) if a.get("setup_ok",false) and b.get("setup_ok",false) else {"class":"INCONCLUSIVE","reason":"setup failed"}
	check(str(cls.get("class",""))=="REFUTED","fixed-source early-return classifier must reject recurrence of old stale-lock hypothesis")
	keys([]);app.queue_free();await process_frame
	print("HW_LATER_CHOICE_INPUT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"failure_labels":failure_labels,"courses":rows.size(),"hypothesis_classification":cls,"rows":rows.map(func(r):return {"mode":r.mode,"label":r.label,"prerequisites_met":r.get("prerequisites_met",false),"prelude_clean":r.get("prelude",{}).get("clean",false),"reveal":r.get("reveal",{}),"phase_times":r.get("phase_times",{}),"round1_towers":r.get("round1_towers",[]),"choice_key_ever_set":r.get("choice_key_ever_set",false),"choice_key_pre45":r.get("choice_key_pre45",{}),"new_failures":r.get("new_failures",[]),"new_dead":r.get("new_dead",[]),"product_outcome":r.get("product_outcome",""),"trace_rows":r.get("trace_rows",0)}),"synthetic":LABEL,"prelude":"all-NPC actual Main demo=true human_actor=-1 HW0..34, then real human6 WASD","diagnostic_validity_vs_product_outcome":"failures counts only fixture/setup/control assertions; product FAIL in course B is a diagnostic outcome, not a build failure","fixture_runtime_injection":false,"source_under_test":"later-round-cooperation-repair","scope":"controlled family [0,0,0,0]/red seed17391 Method1 human6 only; not manual/fullguide/native/Web certification"}))
	quit(1 if failures else 0)
