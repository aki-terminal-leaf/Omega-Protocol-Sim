extends SceneTree
const Runtime=preload("res://scripts/avfx_animation.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func close_to(got:Variant,expected:float)->bool:
 return got!=null and is_finite(float(got)) and absf(float(got)-expected)<1.0e-10
func curve(p1:float,p2:float,equal_values:bool=false)->Dictionary:
 return {"keys":[{"time":0.0,"type":0,"data":[2.0*p1,2.0*(1.0-p2),0.0]},
 {"time":1.0,"type":1,"data":[0.0,0.0,0.0 if equal_values else 1.0]}],"BvPr":0,"BvPo":0}
func _initialize()->void:
 # Synthetic public geometry only; no original assets or private oracle data.
 check(close_to(Runtime.value(curve(1.5,1.0),0.68),0.104),"unique nonmonotone inverse u=.2")
 check(Runtime.value(curve(1.5,-0.5),0.5)==null,"three distinct roots")
 check(Runtime.value(curve(1.5,-0.5,true),0.5)==null,"equal y endpoints do not bypass ambiguity")
 var tangent:=(7.0-sqrt(7.0))/14.0
 var at:=Runtime._spline_x(tangent,1.5,-0.5,1.0)
 check(Runtime.value(curve(1.5,-0.5),at)==null,"shared tangent boundary fails closed")
 check(Runtime.value(curve(1.5,-0.5),at+1.0e-16)==null,"unresolved near tangent")
 check(Runtime.value(curve(1.5,1.0),1.0e-16)==null,"unresolved near endpoint")
 check(close_to(Runtime.value(curve(1.5,-0.5),0.0),0.0),"exact first key preserved")
 check(close_to(Runtime.value(curve(1.5,-0.5),1.0),1.0),"exact final key preserved")
 check(close_to(Runtime._unique_inverse(0.0,3.0,4.0,3.0,1.875),0.25),"linear derivative partition")
 check(close_to(Runtime._unique_inverse(0.0,1.0,2.0,3.0,0.75),0.25),"constant derivative")
 check(Runtime._unique_inverse(0.0,1.0,2.0,0.0,0.0)==null,"degenerate span")
 check(Runtime._unique_inverse(0.0,INF,2.0,3.0,0.75)==null,"nonfinite geometry")
 check(close_to(Runtime.value(curve(0.0,1.0),0.5),0.5),"existing monotone path")
 # Full double literals, independent public geometry; never JSON-round source
 # controls. Mirroring exercises exact stationary endpoints at both ends.
 var overshoot:=1.6300000000000003
 var sample:=3.0*0.8*0.8*0.2*overshoot+3.0*0.8*0.2*0.2+0.2*0.2*0.2
 check(close_to(Runtime.value(curve(overshoot,1.0),sample),0.104),"exact right endpoint derivative factor")
 check(close_to(Runtime.value(curve(0.0,1.0-overshoot),1.0-sample),0.896),"exact left endpoint derivative factor")
 check(close_to(Runtime._unique_inverse(0.0,0.0,1.0,1.0,0.15625),0.25),"both endpoint derivatives zero")
 check(close_to(Runtime._unique_inverse(0.0,0.0,0.5,1.0,0.0859375),0.25),"left endpoint factor unique inverse")
 # This target has one well-conditioned inverse. Generic near-endpoint
 # handling may reject conservatively OR return the correct value; null is
 # not mandatory merely because an unrelated stationary point is near 1.
 var near_right:Variant=Runtime.value(curve(overshoot,0.9999999999999998),sample)
 check(near_right==null or close_to(near_right,0.104),"near right endpoint unique value or conservative rejection")
 check(Runtime.value(curve(0.0000000000000002220446049250313,1.0-overshoot),1.0-sample)==null,"near left endpoint is not snapped")
 var stationary:=overshoot/(3.0*overshoot-2.0)
 var maximum:=Runtime._spline_x(stationary,overshoot,1.0,1.0)
 check(Runtime._unique_inverse(0.0,overshoot,1.0,1.0,maximum)==null,"factored endpoint tangent fails closed")
 check(Runtime._unique_inverse(0.0,overshoot,1.0,1.0,(maximum+1.0)/2.0)==null,"factored endpoint multiple inverses fail closed")
 print(JSON.stringify({"checks":checks,"failures":failures,"scope":"synthetic editor geometry only"}))
 quit(0 if failures.is_empty() else 1)
