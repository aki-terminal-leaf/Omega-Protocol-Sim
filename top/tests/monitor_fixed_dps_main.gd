# SPDX-License-Identifier: MIT
extends SceneTree
## P3 Oversampled Wave Cannon (p3_monitors) bounded actual-Main fixture.
## Actual Main + ordinary selectors + Input.parse_input_event WASD/QE/R only.
## No state/actor/checkpoint injection, no app.move_player/resolve_beat calls.
## Candidate headless evidence only: NOT native/Web/manual/GPU, NOT whole guide.
const Main=preload("res://scenes/main.tscn")
const R=preload("res://scripts/rules.gd")
const Enc=preload("res://scripts/encounters.gd")
const Prep=preload("res://scripts/monitor_preparation.gd")
const ALL_KEYS:Array=[KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E]
const STEP:float=0.025
const MAX_STEPS:int=600
const LAYOUTS:Array=["astoh","aether","lpdu","cn_fixed","cn_mirror","kr_astoh"]
var checks:int=0
var failures:Array=[]
var rows:Array=[]
var held:Dictionary={}
var case_events:int=0
var key_mismatch:int=0
var catalog:Array=[]
var extra:Dictionary={}

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures.append(label);print("MONITOR ACTUAL MAIN FAIL ",label)

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
		if Input.is_physical_key_pressed(code as Key)!=bool(held.get(code,false)):key_mismatch+=1

func held_names()->Array:
	var out:Array=[]
	for code in ALL_KEYS:
		if Input.is_physical_key_pressed(code as Key):out.append(OS.get_keycode_string(code as Key))
	return out

## Camera-yaw-aware 8-way steer (same scheme as existing synergy fixture).
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

## Independent analytic half-plane normal: direction(angle) = (sin, -cos).
func ndir(deg:float)->Vector2:
	return Vector2(sin(deg_to_rad(deg)),-cos(deg_to_rad(deg)))

## Local fixture copy only (never injected): same builder Main.prepare uses.
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

func plan_alternate(p:Dictionary,human:int)->Dictionary:
	var b:Dictionary=p.beat;var poses:Array=p.poses
	var base:Vector2=poses[human]
	var hp:Array=halfplanes(b,poses)
	var tried:int=0
	for r in [3.4,4.0,5.0]:
		for k in 24:
			var ang:float=k*15.0
			var c:Vector2=base+ndir(ang)*float(r);tried+=1
			if c.length()>=19.5:continue
			var sep:float=INF
			for j in 8:
				if j!=human:sep=minf(sep,c.distance_to(poses[j]))
			if sep<=7.1:continue
			var ok:bool=true;var dots:Array=[]
			for h in hp:
				var o:Vector2=h.o;var n:Vector2=h.n
				var db:float=(base-o).dot(n);var dc:float=(c-o).dot(n)
				dots.append([snappedf(db,.001),snappedf(dc,.001)])
				if signf(db)!=signf(dc) or absf(dc)<0.5 or absf(db)<0.5:ok=false
			if ok:return {"found":true,"pos":c,"radius":float(r),"angle":ang,"min_sep":sep,"dots":dots,"tried":tried}
	return {"found":false,"tried":tried}

## Independent analytic scenario planner. A near-guide pose is not necessarily
## legal when a target sits on the guide beam boundary. Preserve all canonical
## memberships, but move only the test human's planned point off affected edges.
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
		var ok:bool=true;var min_margin:float=INF;var dots:Array=[]
		for n in expected.size():
			var eh:Dictionary=expected[n];var ah:Dictionary=actual[n]
			for j in 8:
				if j==int(eh.actor):continue
				var de:Vector2=R.v(base[j])-R.v(eh.o)
				var da:Vector2=R.v(poses[j])-R.v(ah.o)
				var be:float=de.dot(R.v(eh.n));var ba:float=da.dot(R.v(ah.n))
				var expected_in:bool=be>de.length()*0.00001
				var actual_in:bool=ba>da.length()*0.00001
				if expected_in!=actual_in:ok=false
				if int(eh.actor)==human or j==human:
					min_margin=minf(min_margin,absf(ba))
					if absf(ba)<0.18:ok=false
					dots.append([n,j,be,ba])
		for j in 8:
			if j!=human and c.distance_to(R.v(base[j]))<=7.1:ok=false
		if ok:return {"found":true,"pos":c,"margin":min_margin,"dots":dots,"offset":c.distance_to(R.v(base[human]))}
	return {"found":false,"pos":base[human],"margin":0.0,"dots":[],"offset":0.0}

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

## mode: marked | unmarked | none
func run_case(app,label:String,s:int,p:Dictionary,human:int,mode:String,alt:Dictionary,first:bool)->Dictionary:
	case_events=0
	var ok_sel:bool=choose_method(app,s)
	check(ok_sel,label+" ordinary method selected")
	app.role_select.select(human);app.slot_select.select(0);app.seed_edit.text=str(int(p.seed))
	app.fresh_seed.button_pressed=false;app.speed_select.select(2);app.stop_failure.button_pressed=false
	app.demo=false;app.start_run(0,false);app.set_process(false);app.reset_camera()
	var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	var layout:String=layout_of(app.active_profile)
	var b:Dictionary=app.current
	check(not bool(app.demo) and int(app.state.human_actor)==human and not bool(app.checkpoint_assisted) and int(app.encounter.seed)==int(p.seed),label+" ordinary actual human run")
	check(int(p.beat_index)==0 and int(app.index)==0 and str(b.get("title","")).begins_with("Oversampled") and b.has("monitors"),label+" starts at monitor beat")
	check(int(app.speed_select.selected)==2 and float(app.state.sim_time)==0.0,label+" 1x and t=0")
	var same:bool=true
	for i in 8:
		if not R.v(b.positions[i]).is_equal_approx(p.poses[i]):same=false
	for k in 3:
		if int(b.monitors[k+1].actor)!=int(p.marked[k]):same=false
	check(same,label+" actual encounter equals local plan copy")
	var beat_started:float=float(app.state.get("beat_started",-1.0))
	var spawn:Vector2=R.v(app.actors[human].pos)
	check(spawn.is_equal_approx(R.v(b.spawn[human])),label+" human at neutral spawn")
	var guide:Vector2=R.v(b.positions[human])
	var goal:Vector2=guide
	if mode=="unmarked":goal=alt.pos
	var marked_plan:Dictionary={}
	if mode in ["marked","wrong_face"]:
		marked_plan=marked_realization(p,human)
		check(bool(marked_plan.found),label+" independent marked legal realization with boundary margin")
		goal=marked_plan.pos
	var face_goal:float=float(b.facing.get(human,0.0))
	if mode=="wrong_face":face_goal+=180.0
	if mode=="missing_cue":
		# Explicit adversarial public-input withdrawal, not ordinary-input proof.
		b.party_statuses.remove_at(0)
	var order_before:String=JSON.stringify(b.get("monitor_preparation",{}).get("order",[]))
	var steps:int=0;var settled:bool=false;var faced:bool=false;var still:int=0
	var settle_pose:Vector2=Vector2.ZERO;var drift:float=0.0;var walk_max:float=0.0;var excess:float=0.0
	var short_frames:int=0;var prep_reached:bool=false;var samples:Array=[];var any_pressed:bool=false
	while bool(app.journal.is_empty()) and bool(app.running) and steps<MAX_STEPS:
		var hp:Vector2=R.v(app.actors[human].pos)
		var dt:float=STEP
		if mode=="none":keys([])
		else:
			var sorting:bool=Prep.sorting(app.current,app.state)
			if sorting:
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
			elif mode in ["marked","wrong_face"] and still<4:
				keys([]);still+=1
			elif mode in ["marked","wrong_face"] and not faced:
				var diff:float=wrapf(face_goal-float(app.actors[human].face),-180.0,180.0)
				if absf(diff)<1.5:
					faced=true;keys([])
				else:
					keys([KEY_E] if diff>0 else [KEY_Q])
					if absf(diff)<3.75:dt=maxf(absf(diff)/150.0,0.001);short_frames+=1
			else:keys([])
		for c in ALL_KEYS:
			if Input.is_physical_key_pressed(c as Key):any_pressed=true
		var before:Vector2=R.v(app.actors[human].pos)
		app._process(dt)
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
	check(not b.has("monitor_preparation"),label+" no borrowed sorting timer")
	check(excess<=0.00001 and float(app.sprint_left)==0.0 and float(app.dash_left)==0.0,label+" walk only <=6m/s, no sprint/dash")
	check(cov.size()==8,label+" actual monitor_resolution coverage found")
	var npc_ok:bool=true
	for i in 8:
		if i!=human and R.v(app.actors[i].pos).distance_to(p.poses[i])>0.2:npc_ok=false
	check((npc_ok or mode=="missing_cue") and JSON.stringify(app.current.get("monitor_preparation",{}).get("order",[]))==order_before,label+" NPC normal rank paths unchanged")
	var all_one:bool=cov.size()==8
	for c2 in cov:
		if int(c2)!=1:all_one=false
	var report:Dictionary=app.report()
	var vp:Dictionary=report.get("verdict_policy",{})
	check(str(vp.get("basis",""))=="actual_attack_status_death" and not bool(vp.get("guide_position_required",true)),label+" verdict_policy actual attack/status/death, guide not required")
	# A single modeled monitor hit is expected to apply these two debuffs.
	# Expired left/right tells may remain as expired entries, never active buffs.
	var status_rows:Array=[];var status_ok:bool=true
	for si in 8:
		var current_status:Dictionary=app.state.statuses[si]
		var active:Array=[]
		for key in current_status:
			if float(current_status[key].get("expires",0.0))>float(app.state.sim_time)+0.0001:active.append(str(key))
		active.sort()
		status_rows.append({"actor":si,"active":active,"entries":current_status.duplicate(true)})
		if active!=["magic_vulnerability","twice_come_ruin"]:status_ok=false
		for expected in [{"key":"magic_vulnerability","duration":5.0},{"key":"twice_come_ruin","duration":7.0}]:
			if not current_status.has(expected.key):status_ok=false
			elif absf(float(current_status[expected.key].expires)-float(app.state.sim_time)-float(expected.duration))>0.001:status_ok=false
	var bad:bool=not jfail.is_empty() or (cov.size()==8 and int(cov[human])!=1)
	if mode in ["none","wrong_face","missing_cue"]:
		check(bad and (not jfail.is_empty() or not (app.all_errors as Array).is_empty()),label+" true actual mechanic failure retained")
		if mode=="none":check(not any_pressed and fin==spawn,label+" no-input human remained at spawn")
		if mode=="wrong_face":check(faced and absf(wrapf(face-float(b.facing.get(human,0.0)),-180,180))>178.0,label+" actual wrong-facing input retained, no rescue")
	else:
		check(status_ok,label+" exact expected active monitor debuffs and durations, no abnormal/missing status")
		check(any_pressed and settled and fin.distance_to(goal)<0.1,label+" human reached planned legal point by real input")
		check(jfail.is_empty() and all_one and int(app.beat_passed)==1 and int(app.beat_failed)==0 and (app.all_errors as Array).is_empty() and (app.state.get("dead",[]) as Array).is_empty(),label+" actual journal PASS coverage 1x8")
		check(drift<0.000001,label+" released human stationary drift<1e-6")
		if layout!="kr_astoh":check(prep_reached,label+" human reached sorting point during t<3")
		if mode in ["marked","wrong_face"]:check(faced and face_err<1.5,label+" QE facing within 1.5deg")
		if mode=="unmarked":check(fin.distance_to(guide)>3.1,label+" off-guide >3.1 coverage predicate")
	if first:
		extra.first_beat_started=beat_started
		extra.first_drift=drift
		check(int(app.state.human_actor)==human,label+" no auto human")
	var alt_row:Dictionary={}
	if mode=="unmarked":
		var ap:Vector2=alt.pos
		alt_row={"pos":[ap.x,ap.y],"radius":alt.radius,"angle":alt.angle,"min_sep":alt.min_sep,"dots":alt.dots,"tried":alt.tried}
	var marked_row:Dictionary={}
	if mode in ["marked","wrong_face"]:marked_row={"pos":[goal.x,goal.y],"margin":marked_plan.margin,"dots":marked_plan.dots,"offset":marked_plan.offset}
	var resolution:Dictionary={}
	for event in app.state.get("timeline",[]):
		if str(event.get("kind",""))=="monitor_resolution":resolution=event.duplicate(true)
	var actual_poses:Array=[]
	for actor in app.actors:
		var ap2:Vector2=R.v(actor.pos)
		actual_poses.append({"pos":[ap2.x,ap2.y],"face":float(actor.face)})
	var mark_offset:float=0.0
	if human in p.marked:mark_offset=float(p.offsets[p.marked.find(human)])
	var row:Dictionary={"label":label,"seed":int(p.seed),"layout":layout,"method_index":s,"boss_angle":float(p.boss),"human":human,"human_role":Enc.ROLES[human],
		"mark_offset":mark_offset,"marked_rank":p.marked.find(human),"mode":mode,"bad":bad,
		"final_pos":[fin.x,fin.y],"face":face,"face_goal":face_goal,"face_err":face_err,"coverage":cov,"errors":jfail,"all_errors":(app.all_errors as Array).duplicate(),
		"walk_max":walk_max,"guide_distance":fin.distance_to(guide),"input_events":case_events,"steps":steps,"short_frames":short_frames,"drift":drift,
		"prep_reached":prep_reached,"beat_started":beat_started,"samples":samples,"alternate":alt_row,"marked_realization":marked_row,"actual_resolution":resolution,"actual_actors":actual_poses,"actual_statuses":status_rows,
		"scope":"actual Main headless Input; one seed/human/layout case; numeric goals are legal test realization, not guide proof"}
	return row

func press_r(app,end_pos:Vector2,human:int,seed_value:int,previously_moved:bool=true)->void:
	keys([])
	var focus=app.get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	send_key(KEY_R,true);Input.flush_buffered_events();await process_frame
	send_key(KEY_R,false);Input.flush_buffered_events();await process_frame
	app.set_process(false)
	var spawn_ok:bool=true
	for i in 8:
		if not R.v(app.actors[i].pos).is_equal_approx(R.v(app.current.spawn[i])):spawn_ok=false
	check(int(app.encounter.seed)==seed_value,"R retains seed")
	check(float(app.state.sim_time)==0.0 and (app.all_errors as Array).is_empty() and (app.journal as Array).is_empty(),"R sim_time0 errors cleared")
	check(not app.state.has("monitor_preparation_observed"),"R clears monitor_preparation_observed")
	check(spawn_ok and (not previously_moved or R.v(app.actors[human].pos).distance_to(end_pos)>1.0),"R neutral spawn; departed prior pose checked only for moved case")
	var hp:Vector2=R.v(app.actors[human].pos)
	extra.r={"seed":int(app.encounter.seed),"sim_time":float(app.state.sim_time),"human_pos":[hp.x,hp.y],"beat_started":float(app.state.get("beat_started",-1.0))}
	if not extra.has("restart_checks"):extra.restart_checks=[]
	extra.restart_checks.append(extra.r.duplicate(true))

func _initialize()->void:call_deferred("run")

# New source branch acceptance only. No source/state/pose/status injection in
# positives or wrongface/noinput cases. missing_cue explicitly withdraws one
# publiccue in a separate adversarial fixture row, never normal-input evidence.
func candidate_plans(app,s:int)->Array:
	var out:Array=[]
	check(choose_method(app,s),"new method selectable%d"%s)
	for seed_value in range(1,513):out.append(plan(app,seed_value))
	return out
func find_plan(plans:Array,sg:int,human:int,marked:bool,offset:int=0)->Dictionary:
	for p in plans:
		if int(p.sign)!=sg:continue
		var rank:int=(p.marked as Array).find(human)
		if marked and rank<0:continue
		if not marked and rank>=0:continue
		if not marked and human==6 and not 7 in p.marked:continue
		if marked and offset!=0 and int(p.offsets[rank])!=offset:continue
		return p
	return {}
func run()->void:
	root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
	var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
	var methods:Dictionary={}
	choose_method(app,1)
	for i in int(app.strategy_select.item_count):
		var meta:Variant=app.strategy_select.get_item_metadata(i)
		if meta is Dictionary:
			var pol:String=str(meta.get("overrides",{}).get("monitor_dps_policy",""))
			if pol in ["fixed_dps","fixed_dps_d3_outer"]:methods[pol]=i
	check(methods.size()==2,"both explicit optional methods")
	var first:bool=true
	for policy in ["fixed_dps","fixed_dps_d3_outer"]:
		if not methods.has(policy):continue
		var mi:int=int(methods[policy]);var plans:Array=candidate_plans(app,mi)
		for sg in [1,-1]:
			# 24 normal marked cases: 2policies x2boss sides x3role classes x2personal sides.
			for human in [2,6,7]:
				for offset in [90,-90]:
					var p:Dictionary=find_plan(plans,sg,human,true,offset)
					check(not p.is_empty(),"marked natural seed found")
					if p.is_empty():continue
					var label:String="%s_s%d_marked_%s_%d"%[policy,sg,Enc.ROLES[human],offset]
					var row:Dictionary=run_case(app,label,mi,p,human,"marked",{},first);rows.append(row)
					if first:
						await press_r(app,R.v(app.actors[human].pos),human,int(p.seed));first=false
			# 16 canonical unmarked cases: healer/tank fillers and both D3/D4.
			for human in [0,2,6,7]:
				var p:Dictionary=find_plan(plans,sg,human,false)
				check(not p.is_empty(),"unmarked natural seed found")
				if p.is_empty():continue
				rows.append(run_case(app,"%s_s%d_unmarked_%s"%[policy,sg,Enc.ROLES[human]],mi,p,human,"canonical",{},false))
			# 4 legal displaced alternatives, independent geometry planner.
			var found:bool=false
			for pd in plans:
				if int(pd.sign)!=sg:continue
				for human in pd.unmarked:
					var alt:Dictionary=plan_alternate(pd,int(human))
					if not bool(alt.found):continue
					rows.append(run_case(app,"%s_s%d_legal_displaced"%[policy,sg],mi,pd,int(human),"unmarked",alt,false));found=true;break
				if found:break
			check(found,"legal displaced alternate exists")
			# 12 true negative cases; no coordinate-only failure criterion.
			for mode in ["wrong_face","none","missing_cue"]:
				var p:Dictionary=find_plan(plans,sg,6,true,90)
				check(not p.is_empty(),"negative natural seed found")
				if p.is_empty():continue
				var row:Dictionary=run_case(app,"%s_s%d_%s"%[policy,sg,mode],mi,p,6,mode,{},false);rows.append(row)
				if mode=="none" and policy=="fixed_dps" and sg==1:
					check(not (app.all_errors as Array).is_empty(),"failure R starts with true errors")
					await press_r(app,R.v(app.actors[6].pos),6,int(p.seed),false)
	keys([])
	check(rows.size()==56,"exact56actualMainrows")
	check(key_mismatch==0,"actual Input state matched events")
	app.queue_free();await process_frame
	print("FIXED_DPS_ACTUAL_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"cases":rows.size(),"rows":rows,"extra":extra,"key_mismatch":key_mismatch,"scope":"56bounded actualMain headless WASD/QE/R rows;44normal/legal positives+8wrongface/noinput negatives+4explicitcuewithdrawal;notWeb/native/manual/fullguide"}))
	quit(1 if not failures.is_empty() or rows.size()!=56 else 0)
