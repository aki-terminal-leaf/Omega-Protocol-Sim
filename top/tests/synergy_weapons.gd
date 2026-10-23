# SPDX-License-Identifier: MIT
extends SceneTree
## Pure helper gate for P2 public physical-weapon receipts (synergy_weapons.gd).
## Headless basis only; not rendered/Main/native/full-P2/full-guide evidence.
const SW=preload("res://scripts/synergy_weapons.gd")
const Clones=preload("res://scripts/clone_patterns.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var rows:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("SYNERGY WEAPONS FAIL ",label)
## Independent oracle: original encounters.find_safe scan on the generated truth.
func oracle(angle:float,sword:bool,legs:bool)->Vector2:
	var shapes:Array=Clones.pair_shapes(angle,sword,legs)
	for y in range(-16,17):
		for x in range(-16,17):
			var p:=Vector2(x,y)
			if p.length()>17:continue
			var ok:=true
			for s in shapes:
				if R.contains(s,p,[]):ok=false
			if ok:return p
	return Vector2.ZERO
func entities(angle:float,sword:bool,legs:bool,north:float=0.0)->Array:
	var mains:Array=[{"id":"main_m","form":"male","pos":Vector2.ZERO,"stance":""},{"id":"main_f","form":"female","pos":R.direction(north)*13.0,"stance":""}]
	return mains+Clones.pair_entities(angle,sword,legs)
func beat(profile:String,ents:Array,start:float=5.0)->Dictionary:
	return {"title":"Party Synergy · double AOEs","synergy_start":start,"synergy_weapon_public":SW.meta(profile),"stage_entities":ents,"positions":[],"shapes":[]}
func actors()->Array:
	var a:Array=[]
	for i in 8:a.append({"pos":Vector2(i,-1)})
	return a
func state()->Dictionary:
	return {"sim_time":10.0,"beat_started":10.0}
func run_headless(b:Dictionary,s:Dictionary,dt:float=0.05)->void:
	SW.begin(b,s);s.sim_time=float(s.sim_time)+dt;SW.observe_headless(b,s)
func _initialize()->void:
	var a:=actors()
	# Positive: all 5 profiles × 4 weapon combos × 8 angles.
	var positives:=0
	for profile in SW.PROFILES:
		for sword in [true,false]:
			for legs in [true,false]:
				for k in 8:
					var angle:=22.5+k*45.0
					var b:=beat(profile,entities(angle,sword,legs,float(k)*45.0))
					var s:=state();run_headless(b,s)
					var r:=SW.receipt(b,s)
					var want:=oracle(angle,sword,legs)
					var got:=SW.goal(3,b,a,s)
					var ok:bool=not r.is_empty() and r.sword==sword and r.legs==legs and got==want
					# Poison privileged fields: goal must be unchanged.
					b.positions=[]
					for i in 8:b.positions.append(Vector2(99,99))
					b.shapes=[{"kind":"circle","pos":Vector2.ZERO,"radius":50.0}]
					s[SW.KEY].target=null
					ok=ok and SW.goal(3,b,a,s)==want
					check(ok,"positive %s sword%s legs%s angle%s"%[profile,sword,legs,angle])
					if ok:positives+=1
	rows.append({"case":"positive_matrix","passed":positives,"of":160})
	# Neutral / absent / both / neither tells: no receipt and NPC holds pose.
	for variant in ["NEUTRAL","","BOTH","SHIELD_ON_F"]:
		var ents:=entities(22.5,true,true)
		if variant=="SHIELD_ON_F":ents[3].stance="SHIELD"
		else:ents[2].stance=variant;ents[3].stance=variant
		var b:=beat("lpdu",ents);var s:=state();run_headless(b,s)
		check(SW.receipt(b,s).is_empty() and SW.goal(2,b,a,s)==R.v(a[2].pos),"invalid tell %s holds"%variant)
	# Absent entities (hidden by spawn_delay or visible=false) hold.
	var hidden:=entities(67.5,false,true);hidden[2].visible=false
	var hb:=beat("kr_09stop",hidden);var hs:=state();run_headless(hb,hs)
	check(SW.receipt(hb,hs).is_empty() and SW.goal(0,hb,a,hs)==R.v(a[0].pos),"absent genuine male holds")
	# Ambiguous: a second genuine-looking antipodal pair.
	var amb:=entities(22.5,true,true)+Clones.pair_entities(112.5,false,false)
	check(SW.classify(SW.entity_observations(beat("cn_moogle",amb),state())).reason=="ambiguous","ambiguous pairs rejected")
	# Decoy: centre male + non-opposite female never form the genuine pair.
	var decoy:Array=[{"form":"male","pos":[0.0,0.0],"weapon":"SWORD"},{"form":"female","pos":[0.0,13.0],"weapon":"LEGS"}]
	check(SW.classify(decoy).reason=="no_pair","centre decoys are not a pair")
	# Malformed / duplicate positions.
	check(SW.classify([{"form":"male","pos":[NAN,1.0],"weapon":"SWORD"}]).reason=="malformed","NaN rejected")
	check(SW.classify([{"form":"male","pos":"x","weapon":"SWORD"}]).reason=="malformed","string pos rejected")
	check(SW.classify("bad").reason=="malformed","non-array rejected")
	var dup:Array=SW.entity_observations(beat("aether",entities(22.5,true,true)),state());dup.append(dup[2].duplicate())
	check(SW.classify(dup).reason=="duplicate","duplicate positions rejected")
	# Cross-profile / origin / future / basis.
	var b1:=beat("elemental",entities(22.5,true,false));var s1:=state();run_headless(b1,s1)
	var b2:=b1.duplicate(true);b2.synergy_weapon_public=SW.meta("aether")
	check(not SW.receipt(b1,s1).is_empty() and SW.receipt(b2,s1).is_empty(),"cross-profile receipt rejected")
	var b3:=b1.duplicate(true);b3.synergy_start=99.0
	check(SW.receipt(b3,s1).is_empty(),"cross-origin receipt rejected")
	var sf:=s1.duplicate(true);sf[SW.KEY].receipt.at=999.0
	check(SW.receipt(b1,sf).is_empty(),"future receipt rejected")
	var sb:=s1.duplicate(true);sb.synergy_weapons_presentation_required=true
	check(SW.receipt(b1,sb).is_empty(),"headless basis rejected when presentation required")
	var sp:=state();sp.synergy_weapons_presentation_required=true;SW.begin(b1,sp);sp.sim_time=10.1;SW.observe_headless(b1,sp)
	check(SW.receipt(b1,sp).is_empty(),"no headless publish under presentation flag")
	SW.publish(b1,sp,SW.entity_observations(b1,sp),SW.DISPLAYED)
	check(not SW.receipt(b1,sp).is_empty(),"displayed basis accepted under presentation flag")
	var sa:=sp.duplicate(true);sa[SW.KEY].receipt.basis=SW.ASSISTED
	check(SW.receipt(b1,sa).is_empty(),"assisted basis needs explicit assisted flag")
	var bad_meta:=b1.duplicate(true);bad_meta.synergy_weapon_public={"version":2,"profile_id":"lpdu"}
	var sm:=state();SW.begin(bad_meta,sm)
	check(not sm.has(SW.KEY),"bad metadata version creates no cache")
	check(SW.meta("cn_moogle").keys().size()==2,"metadata has only version/profile")
	# JSON roundtrip of the frozen receipt.
	var j:Variant=JSON.parse_string(JSON.stringify(s1[SW.KEY].receipt))
	check(j is Dictionary and str(j.basis)==SW.HEADLESS and (j.m as Array).size()==2 and bool(j.legs)==false,"receipt JSON roundtrip")
	# Repeat frozen / disappearing cue remembered / contradiction blocks / reset.
	var rb:=beat("lpdu",entities(157.5,false,true));var rs:=state();run_headless(rb,rs)
	var g0:=SW.goal(1,rb,a,rs)
	rs.sim_time=10.2;SW.observe_headless(rb,rs)
	check(SW.goal(1,rb,a,rs)==g0 and str(rs[SW.KEY].blocked)=="","consistent repeat keeps frozen receipt")
	rb.stage_entities[3].stance="NEUTRAL";rs.sim_time=10.3;SW.observe_headless(rb,rs)
	check(SW.goal(1,rb,a,rs)==g0,"seen cue later disappearing stays remembered")
	rb.stage_entities[3].stance="STAFF";rs.sim_time=10.4;SW.observe_headless(rb,rs)
	check(SW.receipt(rb,rs).is_empty() and SW.goal(1,rb,a,rs)==R.v(a[1].pos) and str(rs[SW.KEY].blocked)=="contradiction","contradicting repeat blocks and holds")
	SW.begin(rb,rs);check(SW.receipt(rb,rs).is_empty() and str(rs[SW.KEY].blocked)=="","begin resets cache")
	SW.begin({"title":"other"},rs);check(not rs.has(SW.KEY),"non-weapon beat drops cache")
	# Missing cue negative: removed before first receipt => hold for whole beat.
	var mb:=beat("aether",entities(202.5,true,true));mb.stage_entities[2].stance="NEUTRAL";mb.stage_entities[3].stance="NEUTRAL"
	var ms:=state();SW.begin(mb,ms)
	for t in 10:ms.sim_time=10.0+t*0.1;SW.observe_headless(mb,ms)
	check(SW.receipt(mb,ms).is_empty() and SW.goal(5,mb,a,ms)==R.v(a[5].pos),"missing cue before receipt holds")
	# Complete contradictions after a valid receipt must revoke it, not silently
	# keep a previous answer. True disappearance/neutral above remains remembered.
	for negative in ["malformed","duplicate","ambiguous","invalid_tell","wrong_category"]:
		var cb:=beat("lpdu",entities(22.5,true,true));var cs:=state();run_headless(cb,cs)
		check(not SW.receipt(cb,cs).is_empty(),"valid receipt before "+negative)
		var observed:Array=SW.entity_observations(cb,cs)
		match negative:
			"malformed":observed[2].pos=[NAN,1.0]
			"duplicate":observed.append(observed[2].duplicate(true))
			"ambiguous":observed.append_array(SW.entity_observations(beat("lpdu",Clones.pair_entities(112.5,false,false)),cs))
			"invalid_tell":observed[2].weapon="";observed[2].invalid_tell=true
			"wrong_category":observed[3].weapon="SHIELD"
		cs.sim_time=10.2;SW.publish(cb,cs,observed,SW.HEADLESS)
		check(SW.receipt(cb,cs).is_empty() and SW.goal(2,cb,a,cs)==R.v(a[2].pos) and str(cs[SW.KEY].blocked)=="contradiction","post-receipt "+negative+" revokes old target")
	print("SYNERGY_WEAPONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures==0 and checks>0,"rows":rows,"scope":"pure helper, headless public-stance basis only; legacy single-point grid endpoint; not rendered physical parts/Main/input/native/full-P2/full-guide; LPDU6 group-side and sourceUnknown OPEN"}))
	quit(1 if failures or checks==0 else 0)
