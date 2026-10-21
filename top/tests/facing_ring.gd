# SPDX-License-Identifier: MIT
extends SceneTree
const Ring=preload("res://scripts/facing_ring.gd")
const Arena=preload("res://scripts/arena.gd")
var checks:=0
var failures:=0
func check(ok:bool,title:String)->void:
 checks+=1
 if not ok:failures+=1;print("FACING_RING FAIL ",title)
func _initialize()->void:call_deferred("run")
func run()->void:
 var ring:=Ring.create(0.8,Color.WHITE)
 check(ring.get_meta("rear_gap_degrees")==90.0 and ring.get_meta("display_radius")==0.8,"open rear90 with unchanged display radius")
 var arrays:=ring.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 check(vertices.size()>200 and Array(vertices).all(func(p):return p.y>0 and p.y<0.1),"thin floor-level ring, not a solid character collider")
 var south_covered:=false
 for i in range(0,vertices.size(),3):
  var a:=Vector2(vertices[i].x,vertices[i].z);var b:=Vector2(vertices[i+1].x,vertices[i+1].z);var c:=Vector2(vertices[i+2].x,vertices[i+2].z)
  if Geometry2D.is_point_in_polygon(Vector2(0,0.79),PackedVector2Array([a,b,c])):south_covered=true
 check(not south_covered,"rear positional opening is actually empty geometry")
 ring.free()
 var arena=Arena.new();root.add_child(arena);await process_frame;arena.set_process(false)
 var actors:Array=[]
 for i in 8:actors.append({"role":str(i),"pos":Vector2(i-4,5),"face":90.0})
 arena.update_state(actors,{},0,false,0,{"sim_time":0,"statuses":[{},{},{},{},{},{},{},{}]});arena._process(0.01)
 for i in 8:
  var facing:Vector3=-arena.actor_arrows[i].global_basis.z;var model:Vector3=-arena.actor_models[i].global_basis.z
  check(facing.dot(Vector3.RIGHT)>0.999 and model.normalized().dot(facing)>0.999,"model + ring share authoritative east heading "+str(i))
  check(arena.actor_arrows[i].get_child(0).name=="FacingRing","all eight actual player models have positional rings")
 arena.queue_free();await process_frame;print("FACING_RING checks=",checks," failures=",failures);quit(1 if failures else 0)
