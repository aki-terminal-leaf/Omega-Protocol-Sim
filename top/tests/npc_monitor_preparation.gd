# SPDX-License-Identifier: MIT
extends SceneTree
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const M=preload("res://scripts/monitor_preparation.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var courses:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("MONITOR_PREP FAIL ",label)
func fixture(method:int):
	var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var p:Dictionary=profiles[[0,1,2,3,3,4][method]].duplicate(true)
	p.monitor_layout=["astoh","aether","lpdu","cn_fixed","cn_mirror","kr_astoh"][method]
	if method in [3,4]:p.p3_priority=["H1","MT","ST","D1","D2","D3","D4","H2"]
	return E.new().build("p3_monitors",17391,p,0,-1)
func exercise(method:int,human:int,wrong:bool=false)->void:
	var ctx=fixture(method);var b:Dictionary=ctx.beats[0].duplicate(true)
	check(ctx.beats.size()==1 and is_equal_approx(float(b.duration),10.1),"original cast deadline no synthetic extra beat")
	var actors:Array=[]
	for actor in 8:actors.append({"role":E.ROLES[actor],"pos":b.spawn[actor],"face":0.0})
	var live:Dictionary={"sim_time":0.0,"human_actor":human}
	I.begin(b,actors,live)
	var original:Array=b.positions.duplicate(true)
	for step in 101:
		var previous:=actors.duplicate(true)
		for actor in 8:
			var target:=I.bot_goal(actor,b,actors,live)
			if actor==human:
				# Explicit replayed player inputs, never application auto-movement.
				target=M.point(actor,b) if M.sorting(b,live) else R.v(b.positions[actor])+Vector2(0,0.15)
				actors[actor].face=float(b.facing.get(actor,0.0))+(180.0 if wrong else 0.0)
			else:actors[actor].face=float(b.facing.get(actor,0.0))
			actors[actor].pos=R.v(actors[actor].pos).move_toward(target,0.6)
		I.tick(b,actors,previous,live,0.1)
	check(b.positions==original,"goals remain source-ranked, not mutable human-slot reassignment")
	var result:=R.evaluate(b,actors,live);courses+=1
	check(not result.is_empty() if wrong else result.is_empty(),"actual human%d method%d wrong%s: %s" % [human,method,wrong,str(result)])
	if human>=0 and b.has("monitor_preparation") and not wrong:check(live.get("monitor_preparation_observed",{}).get("sort_observed",false),"actual human staged; no fabricated preparation receipt")
func _initialize()->void:
	for method in 6:
		exercise(method,-1)
		for human in 8:exercise(method,human)
		var ctx=fixture(method);var b:Dictionary=ctx.beats[0]
		for source in b.monitors:
			if source.has("actor"):exercise(method,int(source.actor),true)
	# Retrying a beat must erase observed prior human staging.
	var b:Dictionary=fixture(0).beats[0]
	var actors:Array=[]
	for actor in 8:actors.append({"role":E.ROLES[actor],"pos":b.spawn[actor],"face":0.0})
	var live:Dictionary={"sim_time":0.0,"human_actor":0,"monitor_preparation_observed":{"actor":7,"sort_observed":true}}
	I.begin(b,actors,live);check(not live.has("monitor_preparation_observed"),"retry clears previous role's preparation")
	live.monitor_preparation_observed={"actor":7,"sort_observed":true};live.human_actor=2
	I.begin(fixture(5).beats[0],actors,live);check(not live.has("monitor_preparation_observed"),"prepared to KR / changed human clears receipt")
	print("NPC_MONITOR_PREPARATION checks=",checks," courses=",courses," failures=",failures)
	quit(1 if failures else 0)
