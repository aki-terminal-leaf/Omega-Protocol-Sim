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
 print(JSON.stringify({"checks":checks,"failures":failures,"scope":"synthetic editor geometry only"}))
 quit(0 if failures.is_empty() else 1)
