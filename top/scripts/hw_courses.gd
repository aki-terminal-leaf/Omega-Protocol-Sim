# SPDX-License-Identifier: MIT
extends RefCounted
const P = preload("res://scripts/hw_patterns.gd")

static func append_hw(ctx) -> void:
	var orientations: Array=[]
	for _i in 4: orientations.append(ctx.rng.randi_range(0,7))
	append_family(ctx,orientations,"red" if ctx.rng.randi_range(0,1) else "blue")

static func append_family(ctx, orientations: Array, colour: String) -> void:
	assert(orientations.size()==4 and colour in ["red","blue"])
	var order: Array=ctx.order.duplicate()
	# Public initial-role priority; never rotate initial spawn by future towers.
	var public_order:Array=order.duplicate()
	var public_neutral:Array=P.formation(0,0,public_order)
	for slot in [2,3,6,7]:
		var actor:int=int(public_order[slot])
		public_neutral[actor]=(public_neutral[actor] as Vector2).normalized()*3.0
	var route := P.route(str(ctx.profile.id))
	var inward_remote: bool=route.get("remote_after_handoff","")=="inside_boss"
	var hold_old: bool=route.get("old_rot_after_handoff","")=="hold_at_marker_and_inner_tower_until_expiry"
	var start: int=ctx.beats.size()
	var last := 0.0
	for round_index in 4:
		var round_start: int=ctx.beats.size()
		var at := 24.0+21.0*round_index
		var angle := int(orientations[round_index])
		var points := P.formation(round_index,angle,order)
		if round_index>0:
			transition(ctx,order,round_index,angle,at-last,route)
			points=P.formation(round_index,angle,order)
		else:
			var staging := points.duplicate()
			for slot in [2,3,6,7]: staging[int(order[slot])]=(points[int(order[slot])] as Vector2).normalized()*3.0
			add(ctx,staging,3.0,"Initial Smells: rot moves first, tethers inside",route)
			add(ctx,points,at-3.0,"Hello World 1/4: towers and bugs",route)
		last=at
		if round_index<3:
			add(ctx,points,1.05,"Wait for real bug Magic Vulnerability before Patch",route)
			# Actual contact, no grants on these movement beats.
			for side in 2:
				var sign_x := -1.0 if side==0 else 1.0
				put(points,order,round_index,0,side,Vector2(sign_x*9.899495,-9.899495),angle)
				put(points,order,round_index,6,side,Vector2(sign_x*9.899495,-9.899495),angle)
			add(ctx,points,1.35,"Local collects matching rot first; Remote holds",route)
			for side in 2: put(points,order,round_index,2,side,Vector2((-1.0 if side==0 else 1.0)*5.282728,11.328847),angle)
			add(ctx,points,0.55,"Remote collects matching rot and breaks",route)
			for side in 2:
				var sign_x := -1.0 if side==0 else 1.0
				put(points,order,round_index,0,side,Vector2(sign_x*9.899495,-9.899495) if hold_old else Vector2(sign_x*12.4,-12.4),angle)
				put(points,order,round_index,4,side,Vector2(sign_x*5.282728,11.328847) if hold_old else Vector2(sign_x*6.5,17),angle)
				put(points,order,round_index,2,side,Vector2(sign_x*5.3,4.5) if inward_remote else Vector2(sign_x*16.5,10),angle)
			add(ctx,points,1.05,"Remote first; Local waits for Patch vulnerability",route)
			for side in 2: put(points,order,round_index,6,side,Vector2(-1.1 if side==0 else 1.1,-5),angle)
			add(ctx,points,6.0,"Local converges; hold until the actual old rot expiries",route)
			last=at+10.0
		else:
			# Local breaks on activation on the stack side, then Remote leaves.
			add(ctx,points,1.2,"Fourth: Local first, no handoff",route)
			for side in 2:
				var sign_x := -1.0 if side==0 else 1.0
				put(points,order,round_index,2,side,Vector2(sign_x*7,4.5) if route.get("fourth_remote_exit","")=="inside" else Vector2(sign_x*16.5,10),angle)
				put(points,order,round_index,4,side,Vector2(sign_x*5.282728,11.328847) if route.get("fourth_sync_exit","")=="hold" else Vector2(sign_x*6.5,17),angle)
				if route.get("fourth_local_exit","")=="inside": put(points,order,round_index,6,side,Vector2(sign_x*1.1,3.0),angle)
			add(ctx,points,9.0,"Fourth: Remote last; avoid final rot blasts",route)
			last=at+10.2
		var tower_goals:=P.formation(round_index,angle,order)
		var tower_pairs:Array=[]
		for role in [0,4]:
			var tower_slot:=posmod(role-round_index*2,8)
			var tower_pair:Array=[int(order[tower_slot]),int(order[tower_slot+1])]
			tower_pairs.append({"round":round_index,"actors":tower_pair,"goals":[tower_goals[tower_pair[0]],tower_goals[tower_pair[1]]],"reveal_window":10.0})
		for beat_index in range(round_start,ctx.beats.size()):
			ctx.beats[beat_index].hw_tower_cooperations=tower_pairs.duplicate(true)
			ctx.beats[beat_index].hw_tower_cooperation=tower_pairs[0].duplicate(true)
	# Keep the runtime active through the genuine 21s bad Critical Error expiry.
	add(ctx,ctx.positions,130.0-last,"Critical Error: real Overflow Debugger gate",route)
	var first: Dictionary=ctx.beats[start]
	first.hw_events=P.events(order,orientations,colour); first.hw_duration=130.0; first.hw_initial=[]
	first.spawn=public_neutral.duplicate()
	first.hw_public_firstwave={"neutral":public_neutral.duplicate(),"order":public_order.duplicate()}
	first.hw_pairing_preview=[]
	for kind in ["remote","local"]:
		var slot:=2 if kind=="remote" else 6
		first.hw_pairing_preview.append({"kind":kind,"a":int(order[slot]),"b":int(order[slot+1])})
	for actor in 8: first.hw_initial.append({"actor":actor,"name":"latent_sync","duration":69.0})
	for side in 2:
		for item in [[0,"smell_overflow",3.0],[0,"smell_"+colour,3.0],[4,"smell_sync",3.0],[4,"smell_"+("blue" if colour=="red" else "red"),3.0],[6,"latent_overflow",27.0]]:
			first.hw_initial.append({"actor":int(order[int(item[0])+side]),"name":item[1],"duration":item[2]})
	for round_index in 4:
		for side in 2:
			for role in [2,6]:
				first.hw_initial.append({"actor":int(order[posmod(role-round_index*2,8)+side]),"name":"remote_code_smell" if role==2 else "local_code_smell","duration":23.0+21.0*round_index})
	for index in range(start,ctx.beats.size()):
		ctx.beats[index].hw_pattern={"orientations":orientations.duplicate(),"defamation_colour":colour,"numeric_positions":"training realization; not official coordinates","guide_route_complete":bool(route.get("source_route_audited",false))}

static func put(points: Array, order: Array, round_index: int, role: int, side: int, point: Vector2, angle: int) -> void:
	points[int(order[posmod(role-2*round_index,8)+side])]=point.rotated(deg_to_rad(angle*45.0))

static func add(ctx, points: Array, duration: float, title: String, route: Dictionary) -> void:
	ctx.positions=points.duplicate()
	var visible_title:=title
	var note:="按當下毒色與連線移動，避免碰到異色毒；毒爆前先與搭檔分開。"
	if title.begins_with("Initial Smells"):visible_title="初始氣味：帶毒先走外側";note="帶毒玩家先到外圈；連線玩家留內圈等候，避免提早碰毒。"
	elif title.begins_with("Hello World"):visible_title=title.replace(": towers and bugs","：塔、大圈與分攤");note="按毒色進對應塔；大圈單獨，分攤與搭檔一起。"
	elif title.begins_with("Wait for"):visible_title="等魔法易傷結束再接毒";note="先等本輪攻擊的魔法易傷消失，再處理斷線。"
	elif title.begins_with("Local collects"):visible_title="綠線先接大圈的同色毒";note="綠線接毒後先別收近；藍線稍後接毒。"
	elif title.begins_with("Remote collects"):visible_title="藍線接分攤的同色毒並拉斷";note="接到同色毒後拉斷藍線，並與舊毒玩家分開。"
	elif title.begins_with("Remote first"):visible_title="藍先綠後：等斷線易傷";note="藍線先斷；綠線等全隊易傷消失再靠近。"
	elif title.begins_with("Local converges"):visible_title="綠線收近，等舊毒到期";note="綠線收近斷線；舊毒到期前避免毒爆擦到其他人。"
	elif title.begins_with("Fourth: Local"):visible_title="第四輪：綠線先斷、不再傳毒";note="綠線先收近；第四輪不再接下一輪的毒。"
	elif title.begins_with("Fourth: Remote"):visible_title="第四輪：藍線最後拉開";note="分攤後藍線最後拉開，依本攻略分開躲最後毒爆。"
	elif title.begins_with("Critical Error"):visible_title="Critical Error：驗證 Overflow Debugger";note="每人都要實際取得 Overflow Debugger，才能抵擋 Critical Error。"
	elif title.begins_with("Reorient:"):visible_title="換輪：帶毒外圈、連線內圈";note="帶毒走外圈，無毒連線玩家先在內圈等候。"
	elif title.begins_with("Reorient to tower"):visible_title="轉向下一輪塔位";note="帶毒沿外圈換位；連線玩家等路線讓開後再出發。"
	var beat: Dictionary=ctx.beat(visible_title,duration,note)
	beat.hello_world=true; beat.hw_route=route.duplicate(true)

static func transition(ctx, order: Array, round_index: int, angle: int, duration: float, route: Dictionary) -> void:
	var initial: Array=ctx.positions.duplicate()
	# Equivalent partners may choose either same-colour tower. Minimize the
	# longer outside arc; the tie-break is explicit training choreography.
	for role in [0,4]:
		var slot := posmod(role-round_index*2,8)
		var goals := P.formation(round_index,angle,order)
		var a := int(order[slot]); var b := int(order[slot+1])
		var direct := maxf(absf(angle_difference(initial[a].angle(),goals[a].angle())),absf(angle_difference(initial[b].angle(),goals[b].angle())))
		var swapped := maxf(absf(angle_difference(initial[a].angle(),goals[b].angle())),absf(angle_difference(initial[b].angle(),goals[a].angle())))
		if swapped<direct: order[slot]=b; order[slot+1]=a
	var target := P.formation(round_index,angle,order)
	var stage: Array=initial.duplicate()
	for role in [0,2,4,6]:
		for side in 2:
			var actor := int(order[posmod(role-round_index*2,8)+side])
			if role==0:
				stage[actor]=initial[actor].normalized()*18.0
			elif role==4: stage[actor]=initial[actor].normalized()*12.5
			else: stage[actor]=initial[actor].normalized()*3.0
	# Carriers first take separate outside lanes; tether players wait inside.
	add(ctx,stage,3.0,"Reorient: rot outside, tethers wait inside",route)
	var moved: Array=stage.duplicate()
	var elapsed := 0.0
	var path:Array=[]
	while elapsed<duration-3.0-0.00001:
		var dt := minf(0.25,duration-3.0-elapsed)
		elapsed+=dt
		for role in [0,2,4,6]:
			for side in 2:
				var actor := int(order[posmod(role-round_index*2,8)+side])
				if role in [0,4]:
					var radius := 18.0 if role==0 else 12.5
					var delta := angle_difference(stage[actor].angle(),target[actor].angle())
					var travel := minf(absf(delta),6.0*elapsed/radius)*signf(delta)
					var lane: Vector2=Vector2.from_angle(stage[actor].angle()+travel)*radius
					if absf(travel-delta)<0.0001:
						var remaining := maxf(0.0,elapsed-absf(delta)*radius/6.0)
						lane=lane.move_toward(target[actor],remaining*6.0)
					moved[actor]=lane
				elif elapsed>=5.0: moved[actor]=(moved[actor] as Vector2).move_toward(target[actor],dt*6.0)
		path.append({"at":elapsed,"positions":moved.duplicate()})
	add(ctx,moved,duration-3.0,"Reorient to tower wave %d: outside lanes / inside wait" % (round_index+1),route)
	ctx.beats[-1].hw_path=path

static func coaching_goal(actor:int,beat:Dictionary,actors:Array,state:Dictionary)->Vector2:
	var observed_goal=load("res://scripts/hw_firstwave_observation.gd").goal(actor,beat,actors,state)
	if observed_goal is Vector2:return observed_goal
	var replacement=load("res://scripts/hw_cooperation.gd").replacement_actor(actor,beat,actors,state)
	if replacement is int:
		return load("res://scripts/hw_cooperation.gd").walking_goal(actor,base_goal(int(replacement),beat,state),beat,actors,state)
	return base_goal(actor,beat,state)

static func base_goal(actor:int,beat:Dictionary,state:Dictionary)->Vector2:
	var now:=float(state.get("sim_time",0))-float(state.get("beat_started",0))
	for item in beat.get("hw_path",[]):
		if now<float(item.at)-0.000001:return load("res://scripts/rules.gd").v(item.positions[actor])
	return load("res://scripts/rules.gd").v(beat.positions[actor])
