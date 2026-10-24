# SPDX-License-Identifier: MIT
extends RefCounted
## P2 normalized cast-start clock. Source: pinned TOPStates + four public clears.
## Icon/appearance boundaries are guide-order presentation cues, not measured frames.
const Prep=preload("res://scripts/synergy_preparation.gd")
const Assign=preload("res://scripts/synergy_assignment.gd")
const Clones=preload("res://scripts/clone_patterns.gd")
const Conga=preload("res://scripts/aether_conga.gd")
const CnLineup=preload("res://scripts/synergy_cn_lineup.gd")
static func append_synergy(ctx) -> void:
	var sword:=bool(ctx.profile.get("p2_sword",ctx.rng.randi_range(0,1)))
	var legs:=bool(ctx.profile.get("p2_legs",ctx.rng.randi_range(0,1)))
	var clone_angle:=float(ctx.profile.get("p2_clone_angle",22.5+ctx.rng.randi_range(0,7)*45.0))
	var north:=float(ctx.profile.get("p2_late_f_angle",ctx.rng.randi_range(0,7)*45.0))
	var remote:=bool(ctx.profile.get("p2_remote",ctx.rng.randi_range(0,1)))
	var eye_angle:=float(ctx.profile.get("p2_eye_angle",ctx.angle))
	var symbols:Array=ctx.profile.shapes
	var eye:Dictionary={"id":"optical","form":"optical_unit","pos":ctx.polar(eye_angle,45),"facing":eye_angle+180,"height":4.0,"label":""}
	var mains:Array=[{"id":"main_m","form":"male","pos":Vector2.ZERO,"facing":180.0,"stance":""},{"id":"main_f","form":"female","pos":ctx.polar(north,13),"facing":north+180,"stance":""}]
	var pair:Array=Clones.pair_entities(clone_angle,sword,legs)
	pair[0].id="helper_m";pair[1].id="helper_f"
	var all_clones:Array=mains.duplicate(true)+pair.duplicate(true)
	var glitch:Array=[];var markers:Array=[]
	for i in 4:
		for side in 2:
			var actor:int=ctx.at(i*2+side)
			glitch.append({"actor":actor,"key":"remote_glitch" if remote else "mid_glitch","expires":33.1})
			markers.append({"actor":actor,"key":"synergy_marker","name":str(symbols[i]),"status_id":0,"icon":0,"remaining":-1,"marker":true,"symbol":str(symbols[i])})
	# Preserve random mechanic pairs/order; derive only the guide route separately.
	var assignment:Dictionary={}
	var route:Array=ctx.order.duplicate()
	var prep_config:Dictionary=Prep.config(str(ctx.profile.id))
	if not prep_config.is_empty():
		var public_glyphs:Array=[]
		for raw in markers:public_glyphs.append({"actor":raw.actor,"symbol":raw.symbol})
		if Prep.is_conga(prep_config.profile_id):
			# Demo/oracle fixture only: independent default line + actual markers.
			# No RNG draw added/removed; ordinary NPCs never read this route.
			assignment=Conga.assign(public_glyphs,Prep.aether_spawn(),prep_config.shape_order)
		else:
			assignment=Assign.assign(public_glyphs,prep_config)
		assert(not assignment.is_empty())
		route=assignment.route_order.duplicate()
	# Real symbols are remembered BEFORE the genuine/decoy pair is read.
	for i in 8:ctx.pos(i,Vector2(-3.0 if i%2==0 else 3.0,-5.0+float(i/2)*3.0))
	var cast:Dictionary=ctx.beat("Party Synergy · cast",3.0,"準備排隊，稍後記住頭上的圖案與左右組。")
	cast.stage_entities=mains.duplicate(true);cast.hide_main_boss=true
	# Before the icons exist, role lineup cannot encode future random pairings.
	var lineup_priority:Array=ctx.profile.get("p2_lineup_priority",[2,3,0,1,4,5,6,7])
	for side in 2:
		var members:Array=[0,2,4,6] if side==0 else [1,3,5,7]
		members.sort_custom(func(a,b):return lineup_priority.find(a)<lineup_priority.find(b))
		for rank in 4:cast.positions[int(members[rank])]=Vector2(-3.0 if side==0 else 3.0,-5.0+rank*3.0)
	if not assignment.is_empty():
		for actor in 8:cast.positions[actor]=Prep.queue_goal(actor,{},str(ctx.profile.id))
	cast.spawn=cast.positions.duplicate()
	if str(ctx.profile.id)==CnLineup.PROFILE_ID:
		# CN poster fixed role rank facing A. Neutral spawn above stays exact; the
		# human must walk into the row. No RNG draw; later beats/ctx.positions untouched.
		cast[CnLineup.KEY]=CnLineup.metadata()
		cast.positions=CnLineup.default_slots()
		cast.note="面向A點，由左到右依優先級 H1 MT ST D1 D2 D3 D4 H2 橫排排隊；請自己走到自己職能的位置，之後記住頭上的圖案。"
	if not assignment.is_empty():
		for actor in 8:ctx.positions[actor]=Prep.queue_goal(actor,assignment)
	var mark:Dictionary=ctx.beat("Party Synergy · remember symbols",3.1,"記住自己的圖案與組別；圖案會消失，之後不能再靠文字讀答案。")
	mark.stage_entities=mains.duplicate(true)+[eye.duplicate(true)];mark.hide_main_boss=true;mark.party_statuses=markers.duplicate(true)
	var appear:Dictionary=ctx.beat("Party Synergy · two M / two F",2.2,"兩男兩女出場；找外側男與其正對面的女，不能用中心那組判斷安全區。")
	appear.stage_entities=all_clones.duplicate(true)+[eye.duplicate(true)];appear.hide_main_boss=true
	for entity in appear.stage_entities:
		if str(entity.get("id","")).begins_with("helper_"):entity.stance="NEUTRAL"
	appear.party_statuses=glitch.duplicate(true)
	var shapes:Array=Clones.pair_shapes(clone_angle,sword,legs)
	var safe:Vector2=ctx.find_safe(shapes)
	for i in 8:ctx.pos(i,safe)
	var dodge:Dictionary=ctx.beat("Party Synergy · double AOEs",5.1,"只讀真正一組的武器姿態；此時不要求搭檔距離。")
	dodge.shapes=shapes;dodge.stage_entities=all_clones.duplicate(true)+[eye.duplicate(true)];dodge.hide_main_boss=true;dodge.party_statuses=glitch.duplicate(true)
	# Harmless public marker only (version/profile); no weapons/angle/targets.
	dodge.synergy_weapon_public=preload("res://scripts/synergy_weapons.gd").meta(str(ctx.profile.id))
	# Subject Simulation (~T12.6) only prepares transformation. Actual visual
	# disappear/swap/reappear events are ~T14.6/18.8/22.9; do not swap early.
	var late:Array=[{"id":"main_m","form":"female","pos":Vector2.ZERO,"facing":180.0,"stance":""},{"id":"main_f","form":"male","pos":ctx.polar(north,13),"facing":north+180,"stance":"SWORD"}]
	for k in 4:late.append({"id":"late_%d"%k,"form":"male","pos":ctx.polar(north+45+k*90,13),"facing":north+225+k*90,"stance":"SWORD","spawn_delay":0.8})
	# Fire III and Laser are distinct snapshots; eye remains visible without hints.
	for i in 4:
		var z:float=-12.0+i*8.0
		var x:float=sqrt(18.0*18.0-z*z) if remote else 11.0
		ctx.positions[int(route[i*2])]=ctx.rotated(Vector2(-x,z),eye_angle)
		var other_z:float=-z if remote and ctx.profile.get("remote_full_cross",true) else z
		if remote and not ctx.profile.get("remote_full_cross",true):other_z=-z if i in [0,3] else z
		ctx.positions[int(route[i*2+1])]=ctx.rotated(Vector2(x,other_z),eye_angle)
	var fire:Dictionary=ctx.beat("Optimized Fire III",6.4,"以場外眼睛為北：散開火圈，同時滿足搭檔距離。")
	ctx.spread(fire,range(8),float(ctx.Params.parameter("p2_fire_radius")))
	for shape in fire.shapes:shape.hit_status="magic_vulnerability";shape.hit_status_duration=2.0
	for i in 4:fire.checks.append(ctx.glitch_pair(ctx.at(i*2),ctx.at(i*2+1),remote,"Glitch at Fire III"))
	fire.stage_entities=mains.duplicate(true)+late.slice(2).duplicate(true)+[eye.duplicate(true)];fire.hide_main_boss=true;fire.party_statuses=glitch.duplicate(true)
	fire.entity_transitions=[{"at":1.2,"id":"main_m","visible":false},{"at":1.2,"id":"main_f","visible":false},{"at":5.4,"id":"main_m","form":"female"},{"at":5.4,"id":"main_f","form":"male","stance":"SWORD"}]
	var laser:Dictionary=ctx.beat("Optical Laser",0.4,"火圈先結算，接著眼睛發射雷射。")
	laser.shapes.append({"kind":"line","pos":ctx.polar(eye_angle,45),"angle":eye_angle+180,"width":float(ctx.Params.parameter("p2_optical_width")),"start":0.0,"length":100.0,"name":"Optical Laser"})
	laser.stage_entities=settled(late)+[eye.duplicate(true)];laser.hide_main_boss=true;laser.party_statuses=glitch.duplicate(true)
	for entity in laser.stage_entities:
		if str(entity.get("id","")).begins_with("main_"):entity.visible=false
	var left:Array=[];var right:Array=[]
	for i in 4:left.append(int(route[i*2]));right.append(int(route[i*2+1]))
	var targets:Array=ctx.shuffled(range(8)).slice(0,2)
	if (targets[0] in left)==(targets[1] in left):
		var candidates:Array=targets.duplicate()
		candidates.sort_custom(func(a,b):return ctx.rotated(ctx.positions[a],-eye_angle).y<ctx.rotated(ctx.positions[b],-eye_angle).y)
		var chosen:int=candidates[0] if ctx.profile.stack_flex=="north" else candidates[-1]
		var symbol_index:int=route.find(chosen)/2
		var partner:int=int(route[symbol_index*2+(1 if chosen in left else 0)])
		left.erase(chosen);right.erase(chosen);left.erase(partner);right.erase(partner)
		if route.find(chosen)%2==0:right.append(chosen);left.append(partner)
		else:left.append(chosen);right.append(partner)
	ctx.group_goals(left,ctx.polar(270,4.8),0.06);ctx.group_goals(right,ctx.polar(90 if remote else 180,4.8),0.06)
	var knock:Dictionary=ctx.beat("Discharger · two safe gaps",6.9,"以外圈新男分身（三男正中間）為北。女分身在中心擊退13；左組西、右組近南／遠東。")
	knock.knockback=13.0;knock.synergy_north_reveal=2.7;ctx.rotate_beat(knock,north)
	knock.stage_entities=settled(late)+[eye.duplicate(true)];knock.hide_main_boss=true;knock.party_statuses=glitch.duplicate(true)
	for entity in knock.stage_entities:
		if str(entity.get("id","")).begins_with("main_"):entity.spawn_delay=2.7
	for target in targets:knock.party_statuses.append({"actor":target,"key":"spotlight_marker","name":"Spotlight","remaining":-1,"marker":true,"visible_from":0.6,"symbol":"stack"})
	for i in 8:ctx.positions[i]=knock.positions[i]+knock.positions[i].normalized()*13.0
	var stack:Dictionary=ctx.beat("Spotlight · two four-player stacks",4.3,"擊退後可調整；兩個分攤先結算，緊接五男的劍擊。")
	for target in targets:
		var share:Dictionary=ctx.targeted(target,float(ctx.Params.parameter("p2_spotlight_radius")),4,"Spotlight")
		share.hit_status="magic_vulnerability";share.hit_status_duration=2.0;stack.shapes.append(share)
	for i in 4:stack.checks.append(ctx.glitch_pair(ctx.at(i*2),ctx.at(i*2+1),remote,"Glitch at Spotlight"))
	stack.stage_entities=settled(late)+[eye.duplicate(true)];stack.hide_main_boss=true;stack.party_statuses=glitch.duplicate(true)
	for target in targets:stack.party_statuses.append({"actor":target,"key":"spotlight_marker","name":"Spotlight","remaining":-1,"marker":true,"symbol":"stack"})
	var blades:Dictionary=ctx.beat("Efficient Bladework · five M clones",0.1,"五個男分身各自發出半徑10的圓；中心女分身不是第六個圓。")
	for entity in late:
		if entity.form=="male":blades.shapes.append(ctx.circle(entity.pos,10.0,"Efficient Bladework"))
	blades.stage_entities=settled(late)+[eye.duplicate(true)];blades.hide_main_boss=true;blades.party_statuses=glitch.duplicate(true)
	var expiry:Dictionary=ctx.beat("Party Synergy · Glitch expires",1.6,"等待故障狀態自然解除。")
	expiry.stage_entities=settled(late)+[eye.duplicate(true)];expiry.hide_main_boss=true;expiry.party_statuses=glitch.duplicate(true)
	expiry.consume_party_signals=glitch.map(func(raw):return {"actor":raw.actor,"key":raw.key})
	var finish:Dictionary=ctx.beat("Party Synergy · M/F reappear",1.5,"男女交換後返回戰鬥；本練習到此結束，不自動接續LB。")
	finish.stage_entities=settled(late.slice(0,2))+[eye.duplicate(true)];finish.hide_main_boss=true
	var clock:=0.0
	var phase_index:=0
	for b in ctx.beats:
		if not assignment.is_empty():
			b.synergy_public=prep_config.duplicate(true)
			b.synergy_public.merge({"phase":Prep.PHASES[phase_index],"eye_angle":eye_angle,"remote":remote,"north":north})
		phase_index+=1
		b.synergy_start=clock;b.synergy_clock="cast_start";b.hide_predictive_aoes=true;clock+=float(b.duration)
		b.timing_basis="community nominal + finite four-clear observations; icon frame timing unmeasured"
static func settled(entities:Array) -> Array:
	var result:Array=entities.duplicate(true)
	for entity in result:entity.erase("spawn_delay")
	return result
