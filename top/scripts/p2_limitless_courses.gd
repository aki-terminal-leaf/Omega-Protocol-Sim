# SPDX-License-Identifier: MIT
extends RefCounted
const P=preload("res://scripts/p2_limitless_patterns.gd")
const R=preload("res://scripts/rules.gd")
static func append_limitless(ctx)->void:
	var family:int=ctx.rng.randi_range(0,3)
	var arrow_angle:int=ctx.rng.randi_range(0,11)*30
	var shield_angle:int=ctx.rng.randi_range(0,11)*30
	append_family(ctx,family,arrow_angle,shield_angle,ctx.rng.randi_range(0,1),0)
static func append_family(ctx,family:int,arrow_angle:float,shield_angle:float,defense_rank:int,pitch_rank:int)->void:
	var route:=P.route(str(ctx.profile.id))
	var sources:Array=[P.xy(R.direction(45+family*90)*22.0),P.xy(R.direction(225+family*90)*22.0)]
	var non_tanks:Array=ctx.order.filter(func(i):return int(i)>=2)
	var flare_order:Array=ctx.order.slice(0,3)
	var config:Dictionary={"id":"limitless","route":route,"sources":sources,"arrow_source":P.xy(R.direction(arrow_angle)*22.0),"shield_source":P.xy(R.direction(shield_angle)*22.0),"flare_source":P.xy(R.direction(shield_angle+120)*22.0),"arrow_target":int(non_tanks[ctx.rng.randi_range(0,non_tanks.size()-1)]),"pitch_policy":"closest_reference" if pitch_rank==0 else "closest_two_stress_unverified","defense_rank":defense_rank,"pitch_rank":pitch_rank,"flare_targets":flare_order}
	var start:int=ctx.beats.size()
	for phase in [["bait",5.45,"Limitless: bait Sagittarius before cast lock"],["tethers",8.15,"Sagittarius and live tank tethers"],["shield",11.05,"Shield: tanks bait the closest two"],["followup",3.2,"Beyond Defense: actual victim leaves; seven share"],["raidwide",10.35,"Cosmo Memory: party mitigation"]]:
		for actor in 8:ctx.positions[actor]=R.v(route.bait) if phase[0] in ["bait","tethers"] else Vector2.ZERO
		if phase[0]=="bait":
			ctx.positions[0]+=Vector2(-3,0);ctx.positions[1]+=Vector2(3,0)
		if phase[0]=="shield":
			var axis:=R.v(config.shield_source).normalized();var normal:=axis.orthogonal()
			ctx.positions[0]=axis*7.0+normal*4.0;ctx.positions[1]=axis*7.0-normal*4.0
		var b:Dictionary=ctx.beat(str(phase[2]),float(phase[1]),"集中 Flare 路線需要團體減傷。依當下接線與突進受擊者調整；箭在施法開始鎖定。")
		b.limitless_route={"phase":phase[0]};b.hide_main_boss=true
		for actor in 8:b.labels[actor]="箭鎖定後進安全區" if int(actor)>=2 else "接線後引導坦克扇形"
		if phase[0] in ["bait","tethers"]:
			b.transfers={"group":"p2_limitless","initial":non_tanks.slice(0,2),"wanted":[0,1],"sources":[R.v(sources[0]),R.v(sources[1])],"activation_delay":5.3 if phase[0]=="bait" else 0.0,"preposition":b.positions.duplicate(),"coaching_assignment":P.tank_sources(sources,str(route.tank_order))}
			if phase[0]=="tethers":
				# Group persistence keeps the actual old holder; no owner assignment.
				b.transfers.erase("activation_delay")
	var first:Dictionary=ctx.beats[start]
	first.limitless_config=config;first.limitless_events=P.events()
	first.spawn=[]
	for actor in 8:first.spawn.append(R.v(route.bait)+Vector2((actor-3.5)*0.1,0))
