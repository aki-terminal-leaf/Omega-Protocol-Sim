# SPDX-License-Identifier: MIT
extends RefCounted
## Source CameraQuake=9. No synthetic shake/noise or accumulated camera state.
const SourceCurves=preload("res://scripts/avfx_animation.gd")
static func evaluate(node:Dictionary,frame:float,seed_value:int,key:String,distance:float)->Dictionary:
 var result:={"kind":"camera_quake","supported":false,"position":Vector3.ZERO,"rotation":Vector3.ZERO,"order":int(node.get("values",{}).get("RoOT",0))}
 if int(node.get("values",{}).get("EfVT",-1))!=9:return result
 var data:Dictionary=node.get("data",{})
 if not data.has("Pos") or not data.has("Rot") or not data.has("Att"):return result
 var att:Variant=SourceCurves.scalar(data.Att,data.get("AttR",{}),frame,seed_value,key+"/Att",0)
 var inner:Variant=SourceCurves.scalar(data.get("RdI",{}),data.get("RdIR",{}),frame,seed_value,key+"/RdI",0)
 var outer:Variant=SourceCurves.scalar(data.get("RdO",{}),data.get("RdOR",{}),frame,seed_value,key+"/RdO",0)
 var pos:Variant=SourceCurves.axes(data.Pos,frame,seed_value,key+"/Pos",0)
 var rot:Variant=SourceCurves.axes(data.Rot,frame,seed_value,key+"/Rot",0)
 if att==null or inner==null or outer==null or pos==null or rot==null:return result
 # These four original transformation quakes have identical inner/outer radii
 # and constant unit attenuation. Do not fabricate an unverified falloff law.
 if not is_equal_approx(float(inner),float(outer)) or not is_equal_approx(float(att),1.0):
  result["reason"]="source_distance_falloff_not_yet_verified";return result
 var position:Vector3=pos;var rotation:Vector3=rot
 if not position.is_finite() or not rotation.is_finite():return result
 result.supported=true;result["frame"]=frame;result["radius"]=float(inner)
 if distance<=float(inner):result.position=pos;result.rotation=rot
 return result
static func offset(spec:Dictionary)->Transform3D:
 if not spec.get("supported",false):return Transform3D.IDENTITY
 var order:=int(spec.get("order",0))
 if order<0 or order>5:return Transform3D.IDENTITY
 return Transform3D(Basis.from_euler(spec.rotation,[0,3,4,1,2,5][order]),spec.position)

