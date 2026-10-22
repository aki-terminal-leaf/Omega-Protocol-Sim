# SPDX-License-Identifier: MIT
extends RefCounted
const P=preload("res://scripts/p2_limitless_patterns.gd")
const R=preload("res://scripts/rules.gd")
static func append_limitless(ctx)->void:
	# Preserve measured JOINT layouts; independent angle rolls invented unverified
	# combinations and a fictitious shield+120-degree Flare relationship.
	var observed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/spawn_observations.json"))
	var sample:Dictionary=observed.limitless[ctx.rng.randi_range(0,observed.limitless.size()-1)]
	var family:int=posmod(int(round((float(sample.male_angle)-45.0)/90.0)),4)
	var start:int=ctx.beats.size()
	append_family(ctx,family,float(sample.arrow_angle),float(sample.shield_angle),ctx.rng.randi_range(0,1),0,float(sample.flare_angle))
	ctx.beats[start].limitless_config.spawn_scope="verified_joint_capture_subset"
	ctx.beats[start].limitless_config.spawn_capture=str(sample.report)+"/"+str(sample.fight)
static func append_family(ctx,family:int,arrow_angle:float,shield_angle:float,defense_rank:int,pitch_rank:int,flare_angle:float=-999.0)->void:
	var route:=P.route(str(ctx.profile.id))
	var sources:Array=[P.xy(R.direction(45+family*90)*22.0),P.xy(R.direction(225+family*90)*22.0)]
	var non_tanks:Array=ctx.order.filter(func(i):return int(i)>=2)
	var flare_order:Array=ctx.order.slice(0,3)
	var config:Dictionary={"id":"limitless","route":route,"sources":sources,"arrow_source":P.xy(R.direction(arrow_angle)*22.0),"shield_source":P.xy(R.direction(shield_angle)*22.0),"flare_source":P.xy(R.direction(shield_angle+120 if flare_angle==-999.0 else flare_angle)*22.0),"spawn_scope":"forced_training_superset","arrow_target":int(non_tanks[ctx.rng.randi_range(0,non_tanks.size()-1)]),"pitch_policy":"closest_reference" if pitch_rank==0 else "closest_two_stress_unverified","defense_rank":defense_rank,"pitch_rank":pitch_rank,"flare_targets":flare_order}
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
