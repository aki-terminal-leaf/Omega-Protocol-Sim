# Independent review regressions using published attack data and observed formations.
extends SceneTree
const E=preload("res://scripts/encounters.gd")
const R=preload("res://scripts/rules.gd")
const I=preload("res://scripts/interactions.gd")
const S=preload("res://scripts/statuses.gd")
var assertions:=0
var failures:=0
func check(ok: bool,text: String) -> void:
	assertions+=1
	if not ok:failures+=1;print("REVIEW FAIL: ",text)
func party(beat: Dictionary={}) -> Array:
	var result: Array=[]
	for i in 8:result.append({"role":E.ROLES[i],"pos":beat.positions[i] if beat.has("positions") else Vector2(10,10)+Vector2(i*0.1,0),"face":beat.get("facing",{}).get(i,0.0)})
	return result
func state() -> Dictionary:
	return {"sim_time":0.0,"dynamis":[0,0,0,0,0,0,0,0],"spent":[],"lb":"","aggro":0}
func _initialize() -> void:
	var profiles: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	for profile in profiles.slice(0,3):
		for seed_value in range(1,25):
			var b: Dictionary=E.new().build("p3_monitors",seed_value,profile).beats[0]
			var actors:=party(b)
			check(R.evaluate(b,actors,state()).is_empty(),"actual monitor coverage "+profile.id)
			if profile.id=="aether":
				var third: int=b.labels.find("MONITOR 3")
				check(third>=0 and is_equal_approx(b.positions[third].y,11.0),"Aether third monitor is south")
			elif profile.id=="lpdu":
				var first: int=b.labels.find("MONITOR 1")
				check(first>=0 and is_equal_approx(b.positions[first].y,-11.0),"LPDU first monitor is north")
			var holder: int=b.facing.keys()[0];actors[holder].face+=180
			check(not R.evaluate(b,actors,state()).is_empty(),"wrong real facing fails "+profile.id)
	for sword in [false,true]:
		for legs in [false,true]:
			var shapes: Array=E.new().clone_shapes(sword,legs)
			var safe: Vector2=(Vector2(4,0) if sword else Vector2(-11,0)) if legs else (Vector2(0,8) if sword else Vector2(-11,6))
			check(shapes.all(func(shape):return not R.contains(shape,safe,[])),"independent P2 stance safe coordinate")
	var p2_shapes: Array=E.new().clone_shapes(false,false)
	check(not R.contains(p2_shapes[0],Vector2(-3,0),[]) and R.contains(p2_shapes[0],Vector2(0,0),[]),"P2 shield inner radius is ten, not seven")
	check(R.contains(p2_shapes[1],Vector2(0,4.9),[]) or R.contains(p2_shapes[2],Vector2(0,4.9),[]),"P2 cross full width ten")
	var builder=E.new()
	check(builder.glitch_pair(0,1,false,"test").min==20 and builder.glitch_pair(0,1,false,"test").max==26,"observed Mid band")
	check(builder.glitch_pair(0,1,true,"test").min==34 and builder.glitch_pair(0,1,true,"test").max==50,"observed Remote band")
	var actors:=party();actors[4].pos=Vector2(-15,0);actors[0].pos=Vector2(-8,8);actors[1].pos=Vector2(-8,-8)
	var runtime:=state()
	var hit: Dictionary={"kind":"spread","actor":0,"dynamic_actor":{"selector":"closest","ordinal":0,"pos":Vector2(-16,0)},"radius":5.0,"rule":"beyond_defense"}
	check(R.evaluate({"shapes":[hit]},actors,runtime).is_empty() and runtime.defense_victims==[4],"Defense hits real closest candidate, not preset tank")
	actors=party();actors[1].pos=Vector2(-10,0);actors[2].pos=Vector2(-9,0);actors[3].pos=Vector2(-10,1);actors[4].pos=Vector2(12,-8)
	var pitch: Dictionary={"kind":"stack","dynamic_actor":{"selector":"closest","pos":Vector2(-16,0)},"radius":6.0,"min_count":3,"rule":"pile_pitch"}
	check(R.evaluate({"shapes":[pitch]},actors,runtime).is_empty(),"legal three-person Pitch need not match guide seven-stack")
	runtime.defense_victims=[4];actors[4].pos=Vector2(-9,-1)
	check(str(R.evaluate({"shapes":[pitch]},actors,runtime)).contains("Defense victim"),"actual Defense victim cannot join Pitch")
	runtime=state();runtime.defense_victims=[4]
	var follow: Dictionary={"positions":[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],"defense_followup":true}
	I.begin(follow,actors,runtime)
	check(follow.positions[4]==Vector2(-12,-10) and follow.positions[0]!=Vector2(-12,-10),"follow-up guide follows actual victim")
	var limitless: Dictionary=E.new().build("p2_limitless",17,profiles[0]).beats[0]
	check(limitless.shapes[0].width==90.0,"Bladedance cone is ninety degrees")
	var delta: Dictionary=E.new().build("p5_delta",17,profiles[0])
	var pulses: Array=delta.beats.filter(func(b):return b.title.begins_with("Delta · Hyper Pulse"))
	check(pulses.size()==6,"six actual Hyper Pulse snapshots")
	check(pulses[0].shapes[0].width==8.0 and is_equal_approx(pulses[0].shapes[0].pos.length(),20.0),"arm radius twenty / laser width eight")
	check(is_equal_approx(pulses[0].duration,2.5) and is_equal_approx(pulses[1].duration,0.6),"first cast and subsequent cadence")
	var app=load("res://scripts/main.gd").new()
	var bait: Dictionary=delta.beats[delta.beats.find(pulses[0])-1]
	actors=party(bait);runtime=state()
	var first: Dictionary=pulses[0].duplicate(true);app.bind_snapshot_geometry(first,actors,runtime)
	var locked: float=first.shapes[0].angle
	actors[first.rotation_sources[0].target].pos=Vector2.ZERO
	var second: Dictionary=pulses[1].duplicate(true);app.bind_snapshot_geometry(second,actors,runtime)
	check(is_equal_approx(wrapf(second.shapes[0].angle-locked,-180,180),second.rotation_sources[0].turn),"later arm pulses retain real first bait, not re-aim at new position")
	for pulse in pulses:
		check(R.evaluate(pulse,party(pulse),state()).is_empty(),"published width/rotation has a legal inward dodge")
	app.free()
	var sigma: Dictionary=E.new().build("p5_sigma",17,profiles[0])
	var shots: Array=sigma.beats.filter(func(b):return b.title.contains("rotating Rear Power Unit"))
	check(shots.size()==14 and shots[0].shapes[0].width==12.0 and is_equal_approx(shots[1].duration,0.6),"fourteen width-twelve shots at 0.6 seconds")
	var streams: Array=E.exaflare_streams(0)
	check(is_equal_approx(streams[0].advance.length(),8.0) and is_equal_approx(streams[0].interval,1.1) and streams[0].remaining==7,"observed exaflare advance, interval and count")
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	check(catalog.size()==20 and not catalog.any(func(c):return c.id=="p5_full"),"product keeps twenty independent mechanics")
	print("REVIEW ASSERTIONS ",assertions," FAILURES ",failures)
	quit(1 if failures else 0)
