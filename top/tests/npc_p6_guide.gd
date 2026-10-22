# SPDX-License-Identifier: MIT
extends SceneTree
const P=preload("res://scripts/p6_patterns.gd")
const C=preload("res://scripts/p6_courses.gd")
const R=preload("res://scripts/rules.gd")
const Runtime=preload("res://scripts/p6_runtime.gd")
const Encounter=preload("res://scripts/encounters.gd")
var assertions:=0
var failures:=0
func check(ok:bool,label:String)->void:
 assertions+=1
 if not ok:failures+=1;print("NPC P6 GUIDE FAIL: ",label)
func near(a:Vector2,b:Vector2)->bool:return a.distance_to(b)<0.001
func _initialize()->void:
 var route:=P.route("cn_moogle")
 check(route.arrow_wave_pairs==[[7,1],[5,3],[4,2],[6,0]],"explicit numbered pairs")
 check(route.clocks==[0,90,270,180,225,135,315,45],"A MT/B ST/C H2/D H1 clocks")
 for center in [false,true]:
  var paired:=C.arrow_goals(route,center,10.0,true)
  for pair_index in route.arrow_wave_pairs.size():
   var expected:=R.direction([45.0,135.0,225.0,315.0][pair_index])*sqrt(2.0)*(3.0 if center else 11.0)
   for actor in route.arrow_wave_pairs[pair_index]:check(near(paired[actor],expected),"pair geometry %s/%d/%d"%[center,pair_index,actor])
  # Independent damage intersection oracle: no static diagonal-radius shortcut.
  for at in [8.0,10.0,12.0]:
   var points:=C.arrow_goals(route,center,at,true)
   var observed:Array=[]
   for actor in 8:observed.append({"pos":points[actor]})
   for event in P.arrow(center):
    if is_equal_approx(float(event.at),at):check(R.hits(event.shape,observed).is_empty(),"paired Arrow goals safe at actual event %.1f center=%s"%[at,center])
  var old_points:Array=[]
  for actor in 8:old_points.append({"pos":R.direction([315.0,45.0,225.0,135.0,225.0,135.0,315.0,45.0][actor])*10.0})
  var counterexample_at:=10.0 if center else 12.0
  check(P.arrow(center).any(func(e):return is_equal_approx(float(e.at),counterexample_at) and not R.hits(e.shape,old_points).is_empty()),"reject static numbered-marker radius10 draft")
  var clocks:=C.arrow_goals(route,center,17.0,true)
  for actor in 8:check(near(clocks[actor].normalized(),R.direction(float(route.clocks[actor]))),"clock geometry %s/%d"%[center,actor])
  check(not near(C.arrow_goals(route,center,10.0,false)[7],paired[7]),"pairs excluded from Dive")
 for seed_value in [1,17,17391]:
  var ctx=Encounter.new();ctx.profile={"id":"cn_moogle"};ctx.rng.seed=seed_value;ctx.positions=C.repeated(Vector2.ZERO);ctx.labels=["","","","","","","",""]
  C.append_arrow(ctx,true)
  check(ctx.beats[0].p6_route.arrow_wave_pairs==route.arrow_wave_pairs,"seeded real course pair contract")
  check(ctx.beats[0].p6_events.any(func(e):return e.kind=="proteans"),"source damage events preserved")
 for start in 8:
  for direction in [-1,1]:
   for dive in [false,true]:
    var ctx=Encounter.new();ctx.profile={"id":"cn_moogle"};ctx.rng.seed=31;ctx.positions=C.repeated(Vector2.ZERO);ctx.labels=["","","","","","","",""]
    C.append_exaflare_family(ctx,dive,start,direction)
    var first:Dictionary=ctx.beats[0]
    var escape:Dictionary=ctx.beats[1]
    check(is_equal_approx(float(first.p6_pattern.exit_offset),67.5),"67.5 relative gap")
    check(near(R.v(first.positions[0]),Vector2.ZERO),"T10 bait begins at origin")
    check(near(R.v(escape.positions[0]),R.direction(start*45.0-direction*67.5)*6.0),"T12 relative gap geometry")
    var state:Dictionary={"sim_time":0.0,"dead":[],"runtime_failures":[],"timeline":[]}
    Runtime.begin(first,state)
    check(state.p6.pending.filter(func(e):return e.kind=="hazard").size()==28 and state.p6.pending.filter(func(e):return e.kind=="bait").size()==6,"runtime gets unchanged 28 exaflares plus six baits")
    check(state.p6.pending.size()==(35 if dive else 37),"runtime also retains actual Dive or two proteans plus charge")
 print("NPC P6 GUIDE assertions=",assertions," failures=",failures)
 quit(1 if failures else 0)
