extends RefCounted
const SHADER = preload("res://materials/original_lightshaft.gdshader")
static func finite_buffer(value: Variant, count: int) -> bool:
 if not value is Array or value.size()!=count: return false
 for row in value:
  if not row is Array or row.size()!=4: return false
  for x in row:
   if not (x is float or x is int) or not is_finite(float(x)): return false
 return true
static func mesh_contract(mesh: Mesh) -> Dictionary:
 if not mesh is ArrayMesh or mesh.get_surface_count()==0: return {"ok":false,"code":"UNSUPPORTED_MESH"}
 for surface in mesh.get_surface_count():
  var flags:int=mesh.surface_get_format(surface)
  var custom_format:int=(flags>>Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)&Mesh.ARRAY_FORMAT_CUSTOM_MASK
  if (flags&Mesh.ARRAY_FORMAT_CUSTOM0)==0 or custom_format!=Mesh.ARRAY_CUSTOM_RGB_FLOAT: return {"ok":false,"code":"SOURCE_NORMAL_FORMAT","surface":surface}
  if (flags&Mesh.ARRAY_FORMAT_COLOR)==0 or (flags&Mesh.ARRAY_FORMAT_TEX_UV)==0: return {"ok":false,"code":"MISSING_VERTEX_CHANNEL","surface":surface}
  var a:Array=mesh.surface_get_arrays(surface)
  var count:int=a[Mesh.ARRAY_VERTEX].size()
  if count==0 or not a[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array or a[Mesh.ARRAY_CUSTOM0].size()!=count*3 or a[Mesh.ARRAY_COLOR].size()!=count or a[Mesh.ARRAY_TEX_UV].size()!=count: return {"ok":false,"code":"VERTEX_CARDINALITY","surface":surface}
  for value in a[Mesh.ARRAY_VERTEX]:
   if not value.is_finite(): return {"ok":false,"code":"NONFINITE_VERTEX","surface":surface}
  for value in a[Mesh.ARRAY_CUSTOM0]:
   if not is_finite(value): return {"ok":false,"code":"NONFINITE_SOURCE_NORMAL","surface":surface}
  for value in a[Mesh.ARRAY_TEX_UV]:
   if not value.is_finite(): return {"ok":false,"code":"NONFINITE_UV","surface":surface}
  for value in a[Mesh.ARRAY_COLOR]:
   if not is_finite(value.r) or not is_finite(value.g) or not is_finite(value.b) or not is_finite(value.a): return {"ok":false,"code":"NONFINITE_COLOR","surface":surface}
 return {"ok":true}
static func attach(target: MeshInstance3D, c: Dictionary) -> Dictionary:
 target.material_override=null
 target.visible=false
 for key in ["M","I","camera_cb2","original_world_offset","common3x","source_clock","inspection_exposure","sampler0","sampler1","provenance"]:
  if not c.has(key): return {"ok":false,"code":"MISSING_INPUT","field":key}
 if c.provenance!="INSPECTION_FIXTURE" or not finite_buffer(c.M,5) or not finite_buffer(c.I,10): return {"ok":false,"code":"UNSUPPORTED_BUFFER"}
 for key in ["camera_cb2","original_world_offset"]:
  if not c[key] is Vector3 or not c[key].is_finite(): return {"ok":false,"code":"INVALID_VECTOR","field":key}
 for key in ["common3x","source_clock","inspection_exposure"]:
  if not (c[key] is float or c[key] is int) or not is_finite(float(c[key])): return {"ok":false,"code":"INVALID_SCALAR","field":key}
 for key in ["sampler0","sampler1"]:
  if not c[key] is Texture2D or c[key].get_width()<=0: return {"ok":false,"code":"MISSING_TEXTURE","field":key}
 if target.mesh==null: return {"ok":false,"code":"MISSING_MESH"}
 var mesh_result=mesh_contract(target.mesh)
 if not mesh_result.ok:return mesh_result
 var material=ShaderMaterial.new()
 material.shader=SHADER
 for key in ["M","I","camera_cb2","original_world_offset","common3x","source_clock","inspection_exposure","sampler0","sampler1"]:
  if key in ["M","I"]:
   var buffer:Array[Vector4]=[]
   for row in c[key]: buffer.append(Vector4(row[0],row[1],row[2],row[3]))
   material.set_shader_parameter(key,buffer)
  elif key in ["common3x","source_clock","inspection_exposure"]: material.set_shader_parameter(key,float(c[key]))
  else: material.set_shader_parameter(key,c[key])
 target.material_override=material
 target.visible=true
 return {"ok":true,"code":"INSPECTION_ONLY","native_blend_depth":"UNKNOWN"}
static func round_ne(x: float) -> float:
 var lo=floor(x)
 if x-lo<0.5:return lo
 if x-lo>0.5:return lo+1.0
 return lo if fposmod(lo,2.0)==0.0 else lo+1.0
