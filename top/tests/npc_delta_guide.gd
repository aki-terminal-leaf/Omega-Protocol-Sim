# SPDX-License-Identifier: MIT
extends SceneTree
const P=preload("res://scripts/p5_delta_patterns.gd")
const C=preload("res://scripts/p5_delta_courses.gd")
const R=preload("res://scripts/rules.gd")
const Encounter=preload("res://scripts/encounters.gd")
var assertions:=0
var failures:=0
func check(ok:bool,label:String)->void:
 assertions+=1
 if not ok:failures+=1;print("NPC DELTA GUIDE FAIL: ",label)
func nearest(points:Array,origin:Vector2)->int:
 var result:=0
 for i in range(1,points.size()):
  if R.v(points[i]).distance_squared_to(origin)<R.v(points[result]).distance_squared_to(origin):result=i
 return result
func _initialize()->void:
 var route:=P.route("cn_moogle")
 check(route.defense_pair=="inner_blue","CN Defense metadata")
 for order in [range(8),[6,2,5,1,7,0,4,3]]:
  var c:=P.config(P.assignment(order,0,1,0),0.0,1,1,int(order[2]),0,[0,1,1,0,0,1,1,0])
  c.route=route;c.arm_turns=[20,-20,20,-20,20,-20]
  var initial:=C.goals(c,10.0,{})
  for slot in 4:check(R.v(initial[int(order[slot])]).x>0,"blue stages Final +X shuffled")
  for slot in range(4,8):check(R.v(initial[int(order[slot])]).x<0,"green stages Beetle -X shuffled")
  var locked:=C.goals(c,25.526,{})
  var expected:={2:5,3:4,4:0,5:3,6:1,7:2}
  for slot in expected:
   check(nearest(locked,R.direction(-float(expected[slot])*60.0)*20.0)==int(order[slot]),"actual nearest arm target slot %d"%slot)
  var center_order:Array=range(8)
  center_order.sort_custom(func(x,y):return R.v(locked[x]).length_squared()<R.v(locked[y]).length_squared())
  check(center_order.slice(0,2).all(func(actor):return actor in [int(order[0]),int(order[1])]),"actual closest Defense pair is blue inner")
  var ctx=Encounter.new();ctx.profile={"id":"cn_moogle"};ctx.rng.seed=37;ctx.positions=C.goals(c,0.0,{})
  C.append_family(ctx,c)
  check(ctx.beats[0].delta_config.route.defense_pair=="inner_blue","real course carries corrected runtime branch")
  check(ctx.beats[0].delta_events.any(func(e):return e.kind=="defense"),"real course retains Defense event")
 # Independent splash regression for the real seed43 failure class.
 for eye in [0.0,90.0,180.0,270.0]:
  for monitor_side in [-1,1]:
   for monitor in 4:
    for victim in [0,1]:
     var c:=P.config(P.assignment(range(8)),eye,1,monitor_side,monitor,victim,[0,1,1,0,0,1,1,0]);c.route=route
     var points:=C.goals(c,30.445,{"delta":{"defense_target":victim}})
     var actors:Array=[]
     for actor in 8:actors.append({"pos":R.v(points[actor])})
     for target in range(4,8):check(victim not in R.hits({"actor":target,"radius":7.0},actors),"Defense isolated from unchanged actual7y monitor splash")
 var rejected:Array=[{"pos":Vector2(-10,2.5)},{"pos":R.direction(240.0)*13.0}]
 check(0 in R.hits({"actor":1,"radius":7.0},rejected),"negative control catches old Beetle-side Defense retreat")
 check(not C.sprint_authorized({"route":route,"assignment":P.assignment(range(8)),"monitor":0}),"CN Sprint remains unauthorized")
 print("NPC DELTA GUIDE assertions=",assertions," failures=",failures)
 quit(1 if failures else 0)
