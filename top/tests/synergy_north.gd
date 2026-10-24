# SPDX-License-Identifier: MIT
extends SceneTree
## Pure gate for the public new-North classifier/receipt (synergy_north.gd).
## Uses generated actual P2 courses for context; not Main/native/Web/manual.
## Prints SYNERGY_NORTH_RESULT {checks,failures,rows}; nonzero exit on failure.
const Encounter=preload("res://scripts/encounters.gd")
const N=preload("res://scripts/synergy_north.gd")
const Prep=preload("res://scripts/synergy_preparation.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var failed:Array=[]
var rows:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failed.size()<40:failed.append(label)
		print("SYNERGY NORTH FAIL ",label)
## Public geometry: five M at r on N,N+/-45,N+/-135, optional centre F.
func geom(north:float,with_f:=true,r:=13.0,vectors:=false)->Array:
	var out:Array=[]
	for off in [0.0,45.0,-45.0,135.0,-135.0]:
		var p:Vector2=R.direction(north+off)*r
		out.append({"form":"male","pos":p if vectors else [p.x,p.y]})
	if with_f:out.append({"form":"female","pos":Vector2.ZERO if vectors else [0.0,0.0]})
	return out
func pentagon()->Array:
	var out:Array=[]
	for k in 5:
		var q:Vector2=R.direction(72.0*k)*13.0
		out.append({"form":"male","pos":[q.x,q.y]})
	return out
func near(a:float,b:float,tol:=0.01)->bool:
	return absf(N.angle_diff(a,b))<=tol
func pure()->void:
	for k in 8:
		var n:=45.0*k
		var c:=N.classify(geom(n))
		check(c.ok and near(c.north,n),"rotation %d"%k)
		check(N.classify(geom(n,false)).ok,"missing F classifies %d"%k)
	for n in [359.5,0.4,17.3,191.7,-0.2]:
		var c:=N.classify(geom(n,true,13.0,true))
		check(c.ok and near(c.north,fposmod(n,360.0)),"vectors near-wrap/non-grid %s"%str(n))
		var j:Variant=JSON.parse_string(JSON.stringify(geom(n)))
		check(N.classify(j).ok and near(N.classify(j).north,fposmod(n,360.0)),"JSON round trip %s"%str(n))
	check(near(359.9,0.1,0.25) and absf(N.angle_diff(0.0,360.0))<0.000001,"circular 0/360 compare")
	# Perturbation inside/outside implementation tolerances.
	var g:=geom(30.0);g[1].pos=[R.direction(75.0+2.0).x*13.5,R.direction(77.0).y*13.5];g[3].pos=(R.direction(165.0)*12.4).rotated(0.0)
	g[3].pos=[g[3].pos.x,g[3].pos.y]
	check(N.classify(g).ok,"perturbation within tolerance")
	var far:=geom(30.0);var fp:Vector2=R.direction(75.0)*14.0;far[1].pos=[fp.x,fp.y]
	check(N.classify(far).get("reason","")=="invalid_geometry","radius outside tolerance")
	var skew:=geom(30.0);var sp:Vector2=R.direction(75.0+5.0)*13.0;skew[1].pos=[sp.x,sp.y]
	check(N.classify(skew).get("reason","")=="wrong_complete","angle outside tolerance")
	# Order/extra-private keys/non-mutation.
	var base:=geom(135.0);var shuffled:=base.duplicate(true);shuffled.reverse()
	for o in shuffled:o.merge({"north":0.0,"id":"main_f","stance":"SHIELD","role":"MT","truepair":3,"positions":[1,2]})
	var before:=JSON.stringify(shuffled)
	var c2:=N.classify(shuffled)
	check(c2.ok and near(c2.north,135.0),"order/extra private keys ignored")
	check(JSON.stringify(shuffled)==before,"classifier non-mutation")
	# Invalid inputs.
	var four:=geom(90.0);four.remove_at(2)
	check(N.classify(four).get("reason","")=="partial","partial four M")
	check(N.classify([]).get("reason","")=="absent","true absence")
	check(N.classify([{"form":"optical_unit","pos":[0,-40]}]).get("reason","")=="absent","non-body entity ignored")
	var dup:=geom(90.0);dup.append({"form":"male","pos":dup[0].pos.duplicate()})
	check(N.classify(dup).get("reason","")=="duplicate","duplicate")
	var six:=geom(90.0);var p6:Vector2=R.direction(270.0)*13.0;six.append({"form":"male","pos":[p6.x,p6.y]})
	check(N.classify(six).get("reason","")=="excess","excess M")
	var ff:=geom(90.0);ff.append({"form":"female","pos":[0.3,0.2]})
	check(N.classify(ff).get("reason","")=="excess","excess F")
	var foff:=geom(90.0);foff[5].pos=[3.0,0.0]
	check(N.classify(foff).get("reason","")=="invalid_geometry","off-centre F")
	var nan:=geom(90.0);nan[0].pos=[NAN,1.0]
	check(N.classify(nan).get("reason","")=="malformed","nonfinite")
	var inf:=geom(90.0);inf[0].pos=[INF,1.0]
	check(N.classify(inf).get("reason","")=="malformed","infinite")
	check(N.classify(geom(90.0)+[7]).get("reason","")=="malformed","non-dictionary")
	check(N.classify([{"form":3,"pos":[0,0]}]).get("reason","")=="malformed","non-string form")
	check(N.classify({"a":1}).get("reason","")=="malformed","non-array")
	check(N.classify(pentagon()).get("reason","")=="wrong_complete","complete wrong pentagon")
	check(not N.classify([{"form":"male","pos":[0,0]}]).ok,"no (0,0) success fallback")
	rows.append({"kind":"pure_classifier"})
func course(profile:Dictionary,north:float)->Dictionary:
	var p:=profile.duplicate(true);p.merge({"p2_late_f_angle":north},true)
	return Encounter.new().build("p2_synergy",17391,p)
func phase_beat(enc:Dictionary,phase:String)->Dictionary:
	for b in enc.beats:
		if b.has("synergy_public") and str(b.synergy_public.get("phase",""))==phase:return b
	return {}
func fresh(cast:Dictionary)->Dictionary:
	var s:={"sim_time":0.0,"beat_started":0.0}
	Prep.begin(cast,s);N.begin(cast,s)
	return s
func lifecycle(profile:Dictionary,north:float)->void:
	var pid:=str(profile.id)
	var enc:=course(profile,north)
	var cast:=phase_beat(enc,"cast");var remember:=phase_beat(enc,"remember");var knock:=phase_beat(enc,"knock");var stack:=phase_beat(enc,"stack");var fire:=phase_beat(enc,"fire")
	check(not cast.is_empty() and not knock.is_empty() and not stack.is_empty(),"%s generated beats"%pid)
	if cast.is_empty() or knock.is_empty() or stack.is_empty():return
	var frozen:=JSON.stringify([knock.synergy_public,knock.stage_entities,knock.positions,knock.shapes])
	var s:=fresh(cast)
	check(s.get(N.KEY,{}).get("receipt",null)=={},"%s fresh cast empty receipt"%pid)
	# Observe real public glyphs/stack signs before isolating the North gate.
	var acts:Array=[]
	for i in 8:acts.append({"pos":Vector2(i,1.0),"face":0.0})
	var glyph_poses:Array=Prep.aether_spawn() if pid=="aether" else acts
	s.sim_time=3.2;s.beat_started=3.0;Prep.begin(remember,s,glyph_poses)
	s.sim_time=30.0;s.beat_started=29.0;Prep.begin(knock,s,acts);N.begin(knock,s)
	var prep:Dictionary=Prep.memory(stack,s)
	check(not prep.is_empty() and prep.get("glyphs",[]).size()==8 and prep.get("stacks",[]).size()==2 and not Prep.assignment_of(prep.get("glyphs",[]),prep,pid).is_empty(),"%s North gate has valid public glyph/stack assignment"%pid)
	# Before the reveal: actual stage geometry is partial (no main M yet).
	var early:=N.entity_observations(knock,s)
	check(N.classify(early).get("reason","")=="partial","%s pre-reveal headless geometry partial"%pid)
	N.observe_headless(knock,s)
	check(N.receipt(knock,s).is_empty(),"%s missing before first: no receipt"%pid)
	var positive:=s.duplicate(true)
	N.publish(stack,positive,geom(north),N.HEADLESS)
	check(not N.receipt(stack,positive).is_empty() and Prep.goal(3,stack,acts,positive).distance_to(Vector2(3,1.0))>1.0,"%s same valid assignment with North actively plans"%pid)
	check(Prep.goal(3,stack,acts,s)==Vector2(3,1.0),"%s only missing North holds actual pose"%pid)
	var snapshot:=s.duplicate(true)
	s.sim_time=32.0;s.beat_started=29.0
	N.observe_headless(knock,s)
	var r:=N.receipt(knock,s)
	check(not r.is_empty() and str(r.basis)==N.HEADLESS and near(float(r.north),fposmod(north,360.0),0.01),"%s headless receipt follows public geometry"%pid)
	check(JSON.stringify([knock.synergy_public,knock.stage_entities,knock.positions,knock.shapes])==frozen,"%s beat unchanged by observation"%pid)
	# Retry snapshot taken before first cannot import the later receipt.
	check(N.receipt(knock,snapshot).is_empty(),"%s retry snapshot before first"%pid)
	# Displayed basis rejected while not presenting; headless rejected while presenting.
	var t:=s.duplicate(true);t.erase(N.KEY);t[N.KEY]=snapshot[N.KEY].duplicate(true)
	N.publish(knock,t,geom(north),N.DISPLAYED)
	check(N.receipt(knock,t).is_empty(),"%s displayed basis needs presentation"%pid)
	var shown:=t.duplicate(true);shown[N.PRESENTATION_FLAG]=true
	N.observe_headless(knock,shown);N.publish(knock,shown,geom(north),N.HEADLESS)
	check(N.receipt(knock,shown).is_empty(),"%s headless blocked when presenting"%pid)
	N.publish(knock,shown,geom(north),N.DISPLAYED)
	check(str(N.receipt(knock,shown).get("basis",""))==N.DISPLAYED,"%s displayed receipt"%pid)
	# JSON restore keeps a valid receipt; corruption invalidates.
	var restored:Dictionary=JSON.parse_string(JSON.stringify(s))
	check(not N.receipt(knock,restored).is_empty(),"%s JSON restore valid"%pid)
	for mutate in ["future","negative","nan","basis","origin","prep_origin","obs","version","profile"]:
		var bad:Dictionary=JSON.parse_string(JSON.stringify(s))
		match mutate:
			"future":bad[N.KEY].receipt.at=999.0
			"negative":bad.sim_time=-1.0
			"nan":bad[N.KEY].receipt.north="nan"
			"basis":bad[N.KEY].receipt.basis=N.DISPLAYED
			"origin":bad[N.KEY].receipt.origin=5.0
			"prep_origin":bad["synergy_preparation"].origin=7.0
			"obs":bad[N.KEY].receipt.observations=[{"form":"male","pos":[0,0]}]
			"version":bad[N.KEY].receipt.version=2
			"profile":bad[N.KEY].profile_id="cn_moogle"
		check(N.receipt(knock,bad).is_empty(),"%s restored %s rejected"%[pid,mutate])
	var bad_json:Dictionary=JSON.parse_string(JSON.stringify(s));bad_json[N.KEY]="x"
	check(N.receipt(knock,bad_json).is_empty(),"%s malformed cache rejected"%pid)
	# Non-planning phase never exposes it; fire publication is a no-op.
	check(fire.is_empty() or N.receipt(fire,s).is_empty(),"%s fire phase no receipt"%pid)
	# Absence/partial after first remembers; repeats never poison.
	var keep:=s.duplicate(true);keep.sim_time=33.0
	N.publish(stack,keep,[],N.HEADLESS);N.publish(stack,keep,geom(north).slice(0,2),N.HEADLESS);N.publish(stack,keep,geom(north+1.0),N.HEADLESS)
	check(not N.receipt(stack,keep).is_empty() and keep[N.KEY].blocked=="","%s absence/partial/repeat retains"%pid)
	check(keep[N.KEY].rejects.size()<=N.MAX_REJECTS,"%s rejects bounded"%pid)
	for i in 40:N.publish(stack,keep,[],N.HEADLESS)
	check(keep[N.KEY].rejects.size()<=N.MAX_REJECTS,"%s rejects bounded after flood"%pid)
	# Complete contradictions revoke and block the epoch (no hidden repair).
	for variant in ["changed","duplicate","malformed","wrong","excess"]:
		var v:=s.duplicate(true);v.sim_time=33.0
		var obs:Array=geom(north)
		if variant=="changed":obs=geom(north+90.0)
		elif variant=="duplicate":obs.append(obs[0].duplicate(true))
		elif variant=="malformed":obs[0].pos=[NAN,0]
		elif variant=="wrong":obs=pentagon()
		elif variant=="excess":
			var e:Vector2=R.direction(north+180.0)*13.0
			obs.append({"form":"male","pos":[e.x,e.y]})
		N.publish(stack,v,obs,N.HEADLESS)
		check(N.receipt(stack,v).is_empty() and v[N.KEY].blocked!="","%s %s after valid revokes"%[pid,variant])
		N.publish(stack,v,geom(north),N.HEADLESS)
		check(N.receipt(stack,v).is_empty(),"%s %s no hidden repair"%[pid,variant])
		var control:=v.duplicate(true);control[N.KEY]=keep[N.KEY].duplicate(true)
		check(not Prep.memory(stack,v).is_empty() and not N.receipt(stack,control).is_empty() and Prep.goal(2,stack,acts,control).distance_to(Vector2(2,1.0))>1.0,"%s %s identical valid assignment actively plans with North restored"%[pid,variant])
		check(Prep.goal(2,stack,acts,v)==Vector2(2,1.0),"%s %s only revoked North holds actual pose"%[pid,variant])
	# Before first, invalid input cannot plan but valid later data may form it.
	var w:=snapshot.duplicate(true);w.sim_time=32.0
	N.publish(knock,w,geom(north+90.0)+[geom(north)[0]],N.HEADLESS)
	check(N.receipt(knock,w).is_empty() and w[N.KEY].blocked=="","%s invalid before first: no plan, not blocked"%pid)
	N.publish(knock,w,geom(north+90.0),N.HEADLESS)
	check(near(float(N.receipt(knock,w).get("north",NAN)),fposmod(north+90.0,360.0)),"%s changed complete before first follows public geometry"%pid)
	# Fresh cast clears everything, including assisted flag.
	var a:=snapshot.duplicate(true);a.sim_time=32.0
	N.publish_assisted(knock,a)
	check(str(N.receipt(knock,a).get("basis",""))==N.ASSISTED and a.get(N.ASSISTED_FLAG,false)==true,"%s explicit assisted receipt"%pid)
	var a2:=a.duplicate(true);a2.erase(N.ASSISTED_FLAG)
	check(N.receipt(knock,a2).is_empty(),"%s assisted needs flag"%pid)
	a.sim_time=40.0;Prep.begin(cast,a);N.begin(cast,a)
	check(a[N.KEY].receipt.is_empty() and a[N.KEY].rejects.is_empty() and not a.has(N.ASSISTED_FLAG),"%s fresh cast clears"%pid)
	# Private north metadata never affects selection or receipt.
	var priv:=stack.duplicate(true);priv.synergy_public.north="garbage"
	check(not Prep.selection(priv).is_empty() and N.receipt(priv,s)==N.receipt(stack,s),"%s private north ignored"%pid)
	rows.append({"profile":pid,"north":north,"receipt_north":float(r.get("north",NAN)) if not r.is_empty() else null})
func _initialize()->void:call_deferred("run")
func run()->void:
	pure()
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var supported:=0
	for profile in profiles:
		var pid:=str(profile.get("id",""))
		if pid in N.PROFILES:
			supported+=1
			for k in 8:lifecycle(profile,45.0*k)
		elif pid in ["cn_moogle","kr_09stop"]:
			var enc:=course(profile,0.0)
			var any:bool=enc.beats.any(func(b):return b.has("synergy_public"))
			var s:={"sim_time":1.0,N.KEY:{"version":1}}
			for b in enc.beats:N.begin(b,s)
			check(not any and not s.has(N.KEY),"%s unchanged/open: no north import"%pid)
	check(supported==3,"three supported profiles found")
	print("SYNERGY_NORTH_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures==0 and checks>0,"failed":failed,"rows":rows,"scope":"pure classifier/receipt on generated P2 course context; current simulator geometry only; not Main/native/Web/original-game certification"}))
	quit(1 if failures or checks==0 else 0)
