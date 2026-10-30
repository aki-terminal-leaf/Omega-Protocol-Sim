# SPDX-License-Identifier: MIT
extends "res://scripts/source_avfx_player.gd"
## Endpoint-connected source type-6 ribbon subset; screen-facing geometry is approximate.
const RadialEffect=preload("res://scripts/asset_lab_radial_effect.gd")
const CameraEffect=preload("res://scripts/asset_lab_camera_effect.gd")
# Original meteor graph measures 2,516 live particles / 63,563 work ticks.
# Lab-only headroom, not truncation, unlimited execution or fidelity acceptance.
func _work_limit()->int:return 128000
func _particle_limit()->int:return 4096
var camera_effects:Array=[]
var radial_effects:Array=[]
func reset()->void:
 camera_effects.clear();radial_effects.clear()
 super.reset()
## Verified host release stops emission, not existing particle tails. INF = unknown.
var emission_stop_frame:=INF
var endpoint_provider:Callable
var endpoint_start:=Vector3(-8,1.5,0)
var endpoint_end:=Vector3(8,1.5,0)
var camera_position:=Vector3(0,10,20)
func _particle(index:int,birth:float,now:float,ancestors:Array,key:String,result:Array,influence:Dictionary)->void:
 var node:=_node("Ptcl",index)
 if node.is_empty() or int(node.values.get("PrVT",-1))!=6:
  super._particle(index,birth,now,ancestors,key,result,influence);return
 if not _tick():return
 var age:=now-birth+float(influence.get("StFr",0))
 var life:Variant=CurveRuntime.life(node.get("life",{}),seed_value,key)
 if _enabled(influence,"bOvr"):life=float(influence.get("OvrV",0))+CurveRuntime.unit(seed_value,key+"/override")*float(influence.get("OvrR",0))
 if life==null:diagnostics["life"]=true;return
 var looped:=float(node.values.get("LpEd",0))>float(node.values.get("LpSt",0))
 if age<0 or (not looped and float(life)>=0 and age>=float(life)):return
 var chain:=ancestors.duplicate();chain.append({"group":"Ptcl","index":index,"birth":birth,"influence":influence,"key":key})
 var tint:Variant=_chain_color(chain,now)
 if tint==null:diagnostics["polyline_curve"]=true;return
 if result.size()>=_particle_limit():diagnostics["budget_exceeded"]=true;return
 var spec:={"key":key,"index":index,"kind":6,"age":_local(node,age),"transform":Transform3D.IDENTITY,"color":tint}
 _tag_binder(spec);result.append(spec)
func _mesh(spec:Dictionary)->Mesh:
 if int(spec.kind)==6:return _ribbon(spec)
 return super._mesh(spec)
func seek(at_frame:float)->bool:
 camera_effects.clear();radial_effects.clear()
 if not is_finite(at_frame) or absf(at_frame)>3.402823466e38:return false
 var ok:=super.seek(at_frame)
 if not ok:camera_effects.clear();radial_effects.clear();return false
 for spec in last_particles:
  if int(spec.kind)==6:
   var instance:MeshInstance3D=draws[spec.key]
   instance.mesh=_ribbon(spec);instance.transform=Transform3D.IDENTITY
   instance.material_override.set_shader_parameter("particle_color",Color.WHITE)
 return true
func _ribbon(spec:Dictionary)->Mesh:
 var data:Dictionary=_node("Ptcl",int(spec.index)).get("data",{})
 if not _enabled(data,"bCtg"):diagnostics["polyline_not_endpoint_connected"]=true;return null
 var count:=int(data.get("PnC",0))
 if count<2:diagnostics["polyline_point_count"]=true;return null
 if count>64:count=64;diagnostics["polyline_point_count_capped"]=true
 for field in ["bSpl","bLcl","bEdg","bNtB","BWpT","LnCT","NBBA","PnED"]:
  if _num(data,field,0)!=0:diagnostics["polyline_field_not_reproduced/"+field]=true
 var widths:Dictionary={}
 for field in ["Wd","WdB","WdC","WdE"]:
  if data.get(field,{}).is_empty():diagnostics["polyline_missing_data/"+field]=true;return null
  var value:Variant=CurveRuntime.scalar(data[field],data.get(field+"R",{}),spec.age,seed_value,spec.key+"/polyline/"+field,0)
  if value==null:diagnostics["polyline_curve"]=true;return null
  widths[field]=maxf(0,value)
 var cols:Dictionary={}
 for field in ["ColB","ColC","ColE"]:
  cols[field]=CurveRuntime.colour(data.get(field,{}),spec.age,seed_value,spec.key+"/polyline/"+field)
  if cols[field]==null:return null
 var start:=endpoint_start;var end:=endpoint_end
 if endpoint_provider.is_valid():
  var points:Variant=endpoint_provider.call(spec)
  if not points is Array or points.size()!=2 or not points[0] is Vector3 or not points[1] is Vector3:diagnostics["polyline_endpoint_unavailable"]=true;return null
  start=points[0];end=points[1]
 var a:=end if _enabled(data,"bCtr") else start
 var b:=start if _enabled(data,"bCtr") else end
 var axis:=b-a
 if axis.length()<.0001:diagnostics["polyline_degenerate_endpoints"]=true;return null
 var center:=float(data.get("PnCC",-1))/float(data.get("PnC",1))
 if center<=0 or center>=1:center=.5;diagnostics["polyline_center_assumed_half"]=true
 var positions:=PackedVector3Array();var colors:=PackedColorArray();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
 for i in count:
  var t:=float(i)/float(count-1);var p:=a.lerp(b,t);var side:=axis.cross(camera_position-p)
  if side.length_squared()<.00000001:side=axis.cross(Vector3.UP if absf(axis.normalized().y)<.9 else Vector3.RIGHT)
  side=side.normalized()
  var f:=t/center if t<=center else (t-center)/(1-center)
  var width:float=widths.Wd*lerpf(widths.WdB if t<=center else widths.WdC,widths.WdC if t<=center else widths.WdE,f)
  var c:Color=(cols.ColB if t<=center else cols.ColC).lerp(cols.ColC if t<=center else cols.ColE,f)*spec.color
  for j in 2:positions.append(p+side*width*(-.5 if j==0 else .5));colors.append(c);uv.append(Vector2(t,j))
  if i<count-1:
   var v:=i*2;indices.append_array(PackedInt32Array([v,v+1,v+2,v+1,v+3,v+2]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 diagnostics["polyline_camera_facing_approximation"]=true
 return mesh


func _emit(index:int,birth:float,now:float,ancestors:Array,key:String,result:Array,depth:int,stop:float,influence:Dictionary)->void:
 stop=minf(stop,emission_stop_frame)
 if birth>stop:return
 var node:=_node("Emit",index)
 if not node.is_empty() and depth<MAX_DEPTH:
  var age:=now-birth
  var life:Variant=CurveRuntime.life(node.get("life",{}),seed_value,key)
  var looped:=float(node.values.get("LpEd",0))>float(node.values.get("LpSt",0))
  if life!=null and age>=0 and now<=stop and (looped or float(life)<0 or age<float(life)):
   var index_ef:=int(node.values.get("EfNo",-1))
   if index_ef>=0:
    var eff:=_node("Efct",index_ef)
    var kind:Variant=eff.get("values",{}).get("EfVT",-1)
    if RadialEffect.number(kind) and kind==9:
     var spec:=CameraEffect.evaluate(eff,_local(eff,age),seed_value,key+"/effector/"+str(index_ef),camera_position.length())
     spec["emitter"]=index;spec["source_index"]=index_ef;camera_effects.append(spec)
    elif RadialEffect.number(kind) and kind==7:
     var spec:=RadialEffect.evaluate(eff,age,key+"/effector/"+str(index_ef))
     if spec.descriptor_valid:
      spec["emitter"]=index;spec["source_index"]=index_ef;spec["birth"]=birth;spec["global_age"]=now
      spec["descriptor_stop"]=minf(stop,birth+float(life)) if float(life)>=0 and not looped else null
      radial_effects.append(spec)
     else:diagnostics["invalid_radial_descriptor"]=true
     diagnostics["unsupported_host_effector/7.0"]=true
    else:diagnostics["unsupported_host_effector/"+str(eff.get("values",{}).get("EfVT",-1))]=true
 super._emit(index,birth,now,ancestors,key,result,depth,stop,influence)
func report()->Dictionary:
 var value:=super.report();var rows:Array=[]
 for source in camera_effects:
  var row:Dictionary=source.duplicate();var v:Vector3=row.position;var rot:Vector3=row.rotation
  row.position=[v.x,v.y,v.z];row.rotation=[rot.x,rot.y,rot.z];rows.append(row)
 value["camera_effects"]=rows;value["radial_effects"]=radial_effects.duplicate(true);return value
