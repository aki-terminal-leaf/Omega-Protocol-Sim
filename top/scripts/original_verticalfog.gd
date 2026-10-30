extends RefCounted
const ShaderSource=preload("res://materials/original_verticalfog.gdshader")
const COUNTS={"material_cb":5,"camera_cb":59,"parameter_cb":3,"instance_cb":1,"common_cb":4,"fog_cb":10}
static func finite_f32(x:Variant) -> bool:
 return (x is float or x is int) and is_finite(float(x)) and absf(float(x))<=3.4028234663852886e38
static func finite_rows(v:Variant,count:int,width:int) -> bool:
 if not v is Array or v.size()!=count:return false
 for row in v:
  if not row is Array or row.size()!=width:return false
  for x in row:
   if not finite_f32(x):return false
 return true
static func attach(node:MeshInstance3D,c:Dictionary) -> Dictionary:
 # Transaction starts by clearing all stale output, including on malformed input.
 node.material_override=null;node.visible=false
 if c.get("branch","")!="CONDITIONAL_AddLayer0_VS0_PS0":return {"ok":false,"error":"conditional branch provenance"}
 if c.get("provenance","")=="" or c.get("sampler_provenance","")=="":return {"ok":false,"error":"missing provenance"}
 for key in COUNTS:
  if not finite_rows(c.get(key),COUNTS[key],4):return {"ok":false,"error":"finite typed buffer "+key}
 for key in ["source_clock","inspection_exposure"]:
  if not c.has(key) or not finite_f32(c[key]):return {"ok":false,"error":"finite scalar "+key}
 if not finite_rows([c.get("render_origin")],1,3) or not finite_rows([c.get("native_sv_position")],1,4):return {"ok":false,"error":"explicit render origin/native SV_POSITION"}
 for key in ["sampler0","sampler1","sampler2"]:
  if not c.get(key) is Texture2D or c[key].get_width()<=0 or c[key].get_height()<=0:return {"ok":false,"error":"missing sampler "+key}
  var image:Image=c[key].get_image()
  if image==null or image.is_empty():return {"ok":false,"error":"unreadable supplied sampler "+key}
  if image.get_format() in [Image.FORMAT_RF,Image.FORMAT_RGF,Image.FORMAT_RGBF,Image.FORMAT_RGBAF,Image.FORMAT_RH,Image.FORMAT_RGH,Image.FORMAT_RGBH,Image.FORMAT_RGBAH]:
   for y in image.get_height():
    for x in image.get_width():
     var pixel=image.get_pixel(x,y)
     if not is_finite(pixel.r) or not is_finite(pixel.g) or not is_finite(pixel.b) or not is_finite(pixel.a):return {"ok":false,"error":"nonfinite supplied sampler "+key}
 if not node.mesh is ArrayMesh or node.mesh.get_surface_count()==0:return {"ok":false,"error":"original ArrayMesh required"}
 for index in node.mesh.get_surface_count():
  if node.mesh.surface_get_primitive_type(index)!=Mesh.PRIMITIVE_TRIANGLES:return {"ok":false,"error":"triangle primitive required"}
  var a:Array=node.mesh.surface_get_arrays(index)
  if a[Mesh.ARRAY_VERTEX]==null or a[Mesh.ARRAY_VERTEX].is_empty():return {"ok":false,"error":"POSITION required by VS0"}
  for p in a[Mesh.ARRAY_VERTEX]:
   if not p.is_finite():return {"ok":false,"error":"nonfinite POSITION"}
  if a[Mesh.ARRAY_INDEX]==null or a[Mesh.ARRAY_INDEX].size()%3!=0:return {"ok":false,"error":"triangle indices"}
  for i in a[Mesh.ARRAY_INDEX]:
   if i<0 or i>=a[Mesh.ARRAY_VERTEX].size():return {"ok":false,"error":"index cardinality"}
 var material=ShaderMaterial.new();material.shader=ShaderSource
 for key in COUNTS:
  var data=PackedVector4Array()
  for row in c[key]:data.append(Vector4(row[0],row[1],row[2],row[3]))
  material.set_shader_parameter(key,data)
 for key in ["source_clock","inspection_exposure"]:material.set_shader_parameter(key,float(c[key]))
 for key in ["sampler0","sampler1","sampler2"]:material.set_shader_parameter(key,c[key])
 var origin:Array=c.render_origin;material.set_shader_parameter("render_origin",Vector3(origin[0],origin[1],origin[2]))
 var sv:Array=c.native_sv_position;material.set_shader_parameter("native_sv_position",Vector4(sv[0],sv[1],sv[2],sv[3]))
 node.material_override=material;node.visible=true
 return {"ok":true,"native_state_verified":false}
