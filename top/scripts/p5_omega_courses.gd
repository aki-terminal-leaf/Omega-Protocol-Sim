# SPDX-License-Identifier: MIT
extends RefCounted
const R=preload("res://scripts/rules.gd")
const Runtime=preload("res://scripts/p5_omega_runtime.gd")
static func append_omega(ctx) -> void:
	var start:int=ctx.beats.size()
	var monitor_angle:float=ctx.profile.get("omega_monitor_angle",90.0 if ctx.rng.randi_range(0,1) else 270.0)
	var beetle_angle:float=ctx.profile.get("omega_beetle_angle",ctx.rng.randi_range(0,3)*90.0)
	var c:Dictionary={"id":"omega_%d"%start,"profile":ctx.profile.id,"first":[ctx.at(4),ctx.at(5)],"second":[ctx.at(0),ctx.at(6)],"priority":ctx.priority.duplicate(),"monitor_angle":monitor_angle,"beetle_angle":beetle_angle,"far_side":ctx.profile.get("omega_far_side",270 if ctx.profile.id=="cn_moogle" else 90),"standalone":ctx.mechanic_id=="p5_omega"}
	ctx.omega_dodges()
	for i in range(start,ctx.beats.size()):ctx.beats[i].omega_config=c
	ctx.beats[start].spawn=[]
	for _i in 8:ctx.beats[start].spawn.append(Vector2.ZERO)
	var first:Array=Runtime.choose(c,ctx.initial_stacks("p5_omega"),false)
	var b:Dictionary=ctx.beat("Omega · F disappears / wait for actual monitor side",3.3,"檢知方向尚未出現，先等待；不預先按未公開的左右側走位。")
	b.omega_config=c;b.stage_entities=[{"form":"final","pos":Vector2.ZERO,"facing":0.0}];b.hide_main_boss=true
	b=stage(ctx,c,"first",first,"Omega · first World holders",9.6);world(b,c,false,0,first)
	b=stage(ctx,c,"first",first,"Omega · actual monitor targets / radius7 splashes",0.5);b.omega_monitor=true
	b.monitors=[{"kind":"half","angle":monitor_angle,"radius":100.0,"name":"Omega monitor"}]
	b=stage(ctx,c,"first",first,"Omega · first World jump1/2",0.5);world(b,c,false,1,first)
	b=stage(ctx,c,"first",first,"Omega · first World jump2/2",1.0);world(b,c,false,2,first);b.omega_first_finish=true
	# This build-time forecast supplies only preview labels. Runtime reallocates
	# from actual Dynamis after the real first World; it never grants stacks.
	var forecast:Array=ctx.initial_stacks("p5_omega")
	for slot in range(6):forecast[first[slot]]=mini(3,int(forecast[first[slot]])+1)
	var second:Array=Runtime.choose(c,forecast,true)
	b=ctx.beat("Omega · wait for beetle to appear",2.1,"甲蟲在隨機正方向出現前，不預先揭露方向或追未出現的線。")
	b.omega_config=c;b.hide_main_boss=true;b.stage_entities=[]
	b=stage(ctx,c,"second",second,"Omega · physically collect Blaster / explosion",12.2)
	var source:Vector2=R.direction(beetle_angle)*20.0
	b.bot_sprint=range(8) #one actual10s/60s Sprint for the coordinated beetle handoff
	b.transfers={"group":str(c.id)+"_blaster","sources":[source,source],"initial":ctx.shuffled(range(8)).slice(0,2),"wanted":[second[6],second[7]],"holders":[]}
	for k in 2:b.shapes.append({"actor":second[6+k],"tether_index":k,"radius":15.0,"rule":"omega_blaster","name":"Omega Blaster"})
	for pulse in 3:
		b=stage(ctx,c,"second",second,"Omega · second World "+("holders" if pulse==0 else "jump%d/2"%pulse),1.7 if pulse==0 else 1.0)
		world(b,c,true,pulse,second)
		if pulse==2:b.checks.append({"kind":"dynamis","value":[3,3,3,3,3,3,3,3],"name":"Actual P6 entry"})
static func stage(ctx,c:Dictionary,phase:String,roles:Array,title:String,duration:float) -> Dictionary:
	var points:=Runtime.goals(c,phase=="second")
	for slot in 8:ctx.positions[int(roles[slot])]=points[slot]
	var b:Dictionary=ctx.beat(title,duration,"分工依當下層數更新；World每跳、檢知與實際持線者獨立判定。")
	b.omega_config=c;b.omega_phase=phase;Runtime.place(b,c,roles,phase=="second")
	b.stage_entities=[{"id":"omega_source","form":"beetle" if phase=="second" else "final","pos":R.direction(float(c.beetle_angle))*20 if phase=="second" else Vector2.ZERO,"facing":float(c.beetle_angle)+180 if phase=="second" else 0.0}];b.hide_main_boss=true
	return b
static func world(b:Dictionary,c:Dictionary,second:bool,pulse:int,roles:Array) -> void:
	var check:Dictionary={"kind":"world_pulse","chain_id":str(c.id)+("_second" if second else "_first"),"pulse":pulse,"near":roles[0],"far":roles[1],"near_path":[roles[0],roles[2],roles[3]],"far_path":[roles[1],roles[4],roles[5]],"holder_radius":8.0,"jump_radius":4.0}
	b.checks.append(check);b.world=check
