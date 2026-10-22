# SPDX-License-Identifier: MIT
extends RefCounted
## Source-local geometry transport, not original vertex-shader execution.
## Four original half-float UV pairs: UV, UV2, CUSTOM0.xy and CUSTOM0.zw.
const MAX_VERTICES=65536
const MAX_TRIANGLES=262144
static func failure(reason:String)->Dictionary:
 return {"status":"unsupported","diagnostics":[reason],"rendering_complete":false}
static func finite_vector(value:Variant,size:int)->bool:
 if not value is Array or value.size()!=size:return false
 for x in value:
  if not (x is float or x is int) or not is_finite(float(x)):return false
 return true
static func create(source:Dictionary)->Dictionary:
 var rows:Variant=source.get("vertices");var faces:Variant=source.get("triangles")
 if not rows is Array or rows.is_empty() or rows.size()>MAX_VERTICES:return failure("bounded nonempty source vertices required")
 if not faces is Array or faces.is_empty() or faces.size()>MAX_TRIANGLES:return failure("bounded nonempty source triangles required")
 var vertices:=PackedVector3Array();var uv0:=PackedVector2Array();var uv1:=PackedVector2Array();var uv23:=PackedFloat32Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
 for v in rows:
  if not v is Dictionary or not finite_vector(v.get("position"),4):return failure("finite source XYZW required")
  var uv:Variant=v.get("uv");var color:Variant=v.get("color")
  if not uv is Array or uv.size()!=4:return failure("exactly four original UV pairs required")
  for pair in uv:
   if not finite_vector(pair,2):return failure("finite source UV pairs required")
  if not finite_vector(color,4):return failure("four source color bytes required")
  for channel in color:
   if float(channel)!=floor(float(channel)) or channel<0 or channel>255:return failure("color channel outside byte range")
  vertices.append(Vector3(v.position[0],v.position[1],v.position[2]))
  uv0.append(Vector2(uv[0][0],uv[0][1]));uv1.append(Vector2(uv[1][0],uv[1][1]))
  uv23.append_array(PackedFloat32Array([uv[2][0],uv[2][1],uv[3][0],uv[3][1]]))
  colors.append(Color(color[0]/255.0,color[1]/255.0,color[2]/255.0,color[3]/255.0))
 for face in faces:
  if not finite_vector(face,3):return failure("source triangles required")
  for index in face:
   if float(index)!=floor(float(index)) or index<0 or index>=rows.size():return failure("triangle index outside original vertex buffer")
   indices.append(int(index))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv0;arrays[Mesh.ARRAY_TEX_UV2]=uv1;arrays[Mesh.ARRAY_CUSTOM0]=uv23;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
 return {"status":"source_geometry","mesh":mesh,"rendering_complete":false,"uv_channels":["UV","UV2","CUSTOM0.xy","CUSTOM0.zw"],"scope":"source local XYZ, indices, color and four UVs; W/packed normals/tangents remain in source, not original shader semantics"}
