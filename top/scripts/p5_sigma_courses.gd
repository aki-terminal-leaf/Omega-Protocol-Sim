# SPDX-License-Identifier: MIT
extends RefCounted
const R=preload("res://scripts/rules.gd")
const Runtime=preload("res://scripts/p5_sigma_runtime.gd")
static func pair(ctx,values: Array) -> Array:
	var priority:Array=ctx.profile.get("p3_priority",ctx.profile.priority) if ctx.profile.id=="aether" else ctx.profile.priority
	var out:=values.duplicate();out.sort_custom(func(a,b):return priority.find(ctx.ROLES[a])<priority.find(ctx.ROLES[b]));return out
static func append_sigma(ctx) -> void:
	var remote:bool=ctx.profile.get("sigma_remote",bool(ctx.rng.randi_range(0,1)))
	var m_angle:float=ctx.profile.get("sigma_m_angle",ctx.rng.randi_range(0,7)*45.0)
	# The point/gap faces M or the opposite direction, never an independent roll.
	# Forced profile rotations remain available to explicit geometry stress tests.
	var tower_angle:float=ctx.profile.get("sigma_tower_angle",fposmod(m_angle+ctx.rng.randi_range(0,1)*180.0,360.0))
	var f_angle:float=ctx.profile.get("sigma_f_angle",ctx.rng.randi_range(0,7)*45.0)
	var sign_value:int=ctx.profile.get("sigma_direction",1 if ctx.rng.randi_range(0,1) else -1)
	var legs:bool=ctx.profile.get("sigma_legs",bool(ctx.rng.randi_range(0,1)))
	var family:String="cn" if ctx.profile.id=="cn_moogle" else ("kr" if ctx.profile.id=="kr_09stop" else "western")
	var indices:Array=[0,1,2,3];var doubles:Array=ctx.profile.get("sigma_double_pairs",ctx.shuffled(indices).slice(0,2));doubles.sort()
	var singles:Array=[]
	for p in indices:
		if p not in doubles:singles.append(p)
	var pair_actors:Array=[]
	for p in 4:pair_actors.append(pair(ctx,[ctx.at(p*2),ctx.at(p*2+1)]))
	var marked:Array=[];var directions:Dictionary={};var line_up:Array=ctx.positions.duplicate()
	var labels:Array=ctx.labels.duplicate()
	for p in 4:
		for side in 2:
			var actor:int=pair_actors[p][side]
			line_up[actor]=Vector2(-1.0 if side==0 else 1.0,-13.0+p*2.0).rotated(deg_to_rad(m_angle))
			labels[actor]="%s / %s"%[ctx.profile.shapes[p],"LEFT" if side==0 else "RIGHT"]
	for p in doubles:
		var j:=doubles.find(p)
		for side in 2:
			var actor:int=pair_actors[p][side];marked.append(actor)
			directions[actor]=m_angle+([0.0,180.0][side] if j==0 else [270.0,90.0][side])
	for p in singles:
		var j:=singles.find(p);var no_mark:int=ctx.rng.randi_range(0,1)
		if ctx.profile.has("sigma_single_unmarked"):no_mark=int(ctx.profile.sigma_single_unmarked[j])
		var unmarked:int=pair_actors[p][no_mark];var target:int=pair_actors[p][1-no_mark];marked.append(target)
		directions[unmarked]=m_angle+(-45 if j==0 else 45);directions[target]=m_angle+(135 if j==0 else 225)
	var near_far:Array=ctx.profile.get("sigma_world_slots",ctx.shuffled(range(8)).slice(0,2))
	var c:Dictionary={"tower_orientation_scope":"forced_training" if ctx.profile.has("sigma_tower_angle") else "m_or_opposite","id":"sigma_%d"%ctx.beats.size(),"profile":ctx.profile.id,"family":family,"remote":remote,"m_angle":m_angle,"tower_angle":tower_angle,"f_angle":f_angle,"sign":sign_value,"legs":legs,"pairs":pair_actors,"near":ctx.at(near_far[0]),"far":ctx.at(near_far[1]),"priority":ctx.priority.duplicate(),"path_key":"%s_%d_%d"%[family,sign_value,int(legs)]}
	var start:int=ctx.beats.size();ctx.positions=line_up;ctx.labels=labels
	var b:Dictionary=ctx.beat("Sigma · shapes / wait for six markers",10.2,"先以M為北排圖形；炮標出現後，依雙點名／單點名分配八方。")
	b.sigma_config=c;b.spawn=[]
	for actor in 8:b.spawn.append(Vector2((actor-3.5)*0.3,3.0))
	var spread:Array=ctx.positions.duplicate()
	for actor in directions:spread[actor]=R.direction(directions[actor])*(19.0 if remote else 11.0);ctx.labels[actor]+=" / "+("MARK" if actor in marked else "NO MARK")
	ctx.positions=spread
	b=ctx.beat("Sigma · live farthest arm baits",8.9,"兩手臂持續改指最遠者，並非能走過接走的Blaster線。")
	b.sigma_config=c;b.sigma_magic_hits=true
	var first_arms:Array=[R.direction(m_angle+135)*10,R.direction(m_angle+225)*10]
	for source in first_arms:b.shapes.append(arm(source))
	b=ctx.beat("Sigma · six 45-degree Wave Cannons",0.2,"每個炮標讀實際方向；手臂受擊者的易傷尚未消失。")
	b.sigma_config=c;b.sigma_magic_hits=true
	for actor in marked:b.shapes.append({"kind":"cone","pos":Vector2.ZERO,"target":actor,"width":45.0,"radius":100.0,"rule":"count","count":1,"name":"Sigma Wave Cannon"})
	for p in pair_actors:b.checks.append(glitch(ctx,p,remote))
	ctx.positions=[]
	for _i in 8:ctx.positions.append(Vector2.ZERO)
	b=ctx.beat("Sigma · identify actual tower pattern",2.7,"六塔近線／五塔遠線，觀察缺口方向；記住先前實際站過的場地標點。")
	b.sigma_config=c
	var mapping:Dictionary={1:0.0,3:0.0,0:270.0,2:225.0,5:225.0,4:135.0,7:135.0,6:90.0} if remote else {1:337.5,3:22.5,0:247.5,5:247.5,2:202.5,4:157.5,6:112.5,7:112.5}
	if ctx.profile.id=="kr_09stop":
		# Official guide macro faces the four-tower side north, i.e. GapNorth+180.
		mapping={0:135.0,1:135.0,2:225.0,3:225.0,4:270.0,6:90.0,5:0.0,7:0.0} if remote else {0:157.5,2:202.5,4:247.5,3:247.5,6:112.5,1:112.5,5:22.5,7:337.5}
	# Attack geometry/capacities are independent of the coaching assignment.
	var capacities:Dictionary={0.0:2,90.0:1,135.0:2,225.0:2,270.0:1} if remote else {337.5:1,22.5:1,112.5:2,157.5:1,202.5:1,247.5:2}
	var towers:Dictionary={};var actual_caps:Dictionary={};var post:Array=[];post.resize(8)
	for angle in capacities:
		var absolute:float=fposmod(float(angle)+tower_angle,360.0)
		towers[absolute]=[];actual_caps[absolute]=int(capacities[angle])
	for actor in directions:
		var mark:int=posmod(int(round(float(directions[actor])/45.0)),8)
		var angle:float=fposmod(float(mapping[mark])+tower_angle,360.0)
		if ctx.profile.id=="cn_moogle":
			# CN poster: rotateCW22.5; ignore directly-behind tower; adjacent
			# physical-mark towers prefer double capacity, otherwise the single.
			var choices:Array=[]
			for candidate in ([mark*45.0,(mark+1)*45.0] if remote else [mark*45.0-22.5,mark*45.0+67.5]):
				var absolute:float=fposmod(candidate,360.0)
				if actual_caps.has(absolute):choices.append(absolute)
			choices.sort_custom(func(x,y):return actual_caps[x]>actual_caps[y])
			assert(not choices.is_empty(),"CN actual pattern must have an adjacent tower")
			angle=choices[0]
		towers[angle].append(actor)
	for angle in towers:
		var members:Array=towers[angle]
		for i in members.size():post[members[i]]=R.direction(angle)*(19.5 if remote else 17.0)+R.direction(angle+90)*(float(i)-(members.size()-1)*0.5)*0.4
	ctx.positions=[]
	for p in post:ctx.positions.append(p.normalized()*(p.length()-13.0))
	b=ctx.beat("Sigma · Discharger to towers",5.9,"近線踩中心、遠線踩外緣；擊退13後還有時間調整。")
	b.sigma_config=c;b.knockback=13.0
	ctx.positions=post
	b=ctx.beat("Sigma · actual Looper/tower resolution",3.9,"只檢查實際塔內人數、Looper與搭檔距離，不限定攻略建議的踩塔者。")
	b.sigma_config=c;b.sigma_towers=true
	for angle in towers:b.shapes.append({"kind":"tower","pos":R.direction(angle)*17.0,"radius":3.0,"count":actual_caps[angle],"rule":"count","name":"Storage Violation"})
	for p in pair_actors:b.checks.append(glitch(ctx,p,remote))
	# Each coaching trajectory is physically feasible at6/s against all real shots.
	var route:Dictionary=Runtime.paths()[c.path_key]
	var role_ids:Array=Runtime.allocation(c,ctx.initial_stacks("p5_sigma"))
	assert(role_ids.size()==8,"Sigma entry must have a valid6x1/2x0 distribution")
	c.initial_roles=role_ids.duplicate()
	ctx.positions=[]
	for _i in 8:ctx.positions.append(Vector2.ZERO)
	b=ctx.beat("Sigma · F and arms appear",3.0,"塔結算後等待F的新位置；看到姿態與旋轉方向，再分配World工作。")
	b.sigma_config=c;b.hide_main_boss=true
	var last:=34.8
	for point_index in route.roles[0].size():
		var time:=float(route.roles[0][point_index].at)
		ctx.positions=post.duplicate()
		b=ctx.beat("Sigma · %s · %.3fs"%["F LEGS" if legs else "F STAFF",time],time-last,"解F姿態時仍有十四發旋轉雷射；依分工等待、追雷射，再到World站位。")
		b.sigma_config=c;b.sigma_path_index=point_index;Runtime.place(b,c,role_ids,point_index)
		if absf(time-49.3)<0.001:
			b.shapes=female_shapes(f_angle,legs)
		else:
			var shot:=shot_index(time)
			if shot>=0:b.shapes.append({"kind":"line","pos":Vector2.ZERO,"angle":f_angle+sign_value*shot*9.0,"start":-25.0,"length":25.0,"width":12.0,"name":"Rear Power Unit"})
		if absf(time-56.1)<0.001:add_world(b,c,0)
		b.stage_entities=[{"form":"female_p5","pos":R.direction(f_angle)*10,"facing":f_angle+180,"stance":"LEGS" if legs else "STAFF"},{"form":"final","pos":Vector2.ZERO,"facing":0}];b.hide_main_boss=true
		last=time
	b=ctx.beat("Sigma · actual arm targets after World",0.1,"World首擊後手臂才開炮；撞到World易傷會出事。")
	b.sigma_config=c;b.sigma_path_index=route.roles[0].size()-1;b.sigma_magic_hits=true
	for source in [R.direction(f_angle+135)*20,R.direction(f_angle+225)*20]:b.shapes.append(arm(source))
	for pulse in [1,2]:
		b=ctx.beat("Sigma · World jump%d/2"%pulse,0.9 if pulse==1 else 1.0,"這一跳重新選擇當下最近／最遠者；原持有者仍可被跳回。")
		b.sigma_config=c;b.sigma_path_index=route.roles[0].size()-1;add_world(b,c,pulse)
		if pulse==2:b.sigma_finish=true
	for i in range(start,ctx.beats.size()):
		var item:Dictionary=ctx.beats[i]
		if i<start+3:
			item.party_statuses=[]
			for p in pair_actors.size():
				for actor in pair_actors[p]:item.party_statuses.append({"actor":int(actor),"key":"sigma_pair_marker","name":str(ctx.profile.shapes[p]),"symbol":str(ctx.profile.shapes[p]),"icon":0,"status_id":0,"marker":true,"remaining":-1})
			if i==start+1:
				for actor in marked:item.party_statuses.append({"actor":int(actor),"key":"sigma_cannon_marker","name":"炮標","symbol":"cannon","icon":0,"status_id":0,"marker":true,"remaining":-1})
		if not item.has("stage_entities"):
			item.stage_entities=[{"form":"male_p5","pos":R.direction(m_angle)*20,"facing":m_angle+180}];item.hide_main_boss=true
static func shot_index(time: float) -> int:
	for j in 14:
		if absf(time-(46.2+(0.0 if j==0 else 0.625+(j-1)*0.58)))<0.001:return j
	return -1
static func female_shapes(angle: float,legs: bool) -> Array:
	var origin:=R.direction(angle)*10;var result:Array=[]
	if legs:
		for side in [-90,90]:result.append({"kind":"line","pos":origin,"angle":angle+180+side,"start":4.0,"length":40.0,"width":80.0,"name":"Superliminal Steel"})
	else:
		for side in [0,90]:result.append({"kind":"line","pos":origin,"angle":angle+side,"start":-100.0,"length":100.0,"width":10.0,"name":"Optimized Blizzard"})
	return result
static func arm(pos: Vector2) -> Dictionary:
	return {"kind":"line","pos":pos,"dynamic_actor":{"selector":"furthest","ordinal":0,"pos":pos},"dynamic_aim":true,"width":6.0,"length":100.0,"rule":"count","count":1,"name":"Hyper Pulse"}
static func glitch(ctx,p: Array,remote: bool) -> Dictionary:
	return ctx.glitch_pair(p[0],p[1],remote,"Sigma Glitch")
static func add_world(beat: Dictionary,c: Dictionary,pulse: int) -> void:
	var check:Dictionary={"kind":"world_pulse","chain_id":str(c.id)+"_world","pulse":pulse,"near":int(c.near),"far":int(c.far),"near_path":[c.initial_roles[0],c.initial_roles[2],c.initial_roles[3]],"far_path":[c.initial_roles[1],c.initial_roles[4],c.initial_roles[5]],"holder_radius":8.0,"jump_radius":4.0}
	beat.checks.append(check);beat.world=check
