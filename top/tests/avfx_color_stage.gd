# SPDX-License-Identifier: MIT
extends SceneTree
const MeshStage=preload("res://scripts/avfx_mesh_stage.gd")
const Stage=preload("res://scripts/avfx_color_stage.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func plan()->Dictionary:
 var layers:Array=[]
 for i in 4:layers.append({"number":i+1,"enabled":i==0,"sample_required":true,"color_to_alpha":false,"decode_semantic":"TextureColor%d_Decode_Off"%(i+1),"uv_index":0,"color_op":"DynamicMul" if i==0 else "Mul","alpha_op":"DynamicMul" if i==0 else "Mul"})
 return {"status":"verified_color_stage","rendering_complete":false,"requires_model_fresnel":false,"layers":layers,"bytecode_sha256":"6f371f4b36697057d24590c42dd1740c1f5ac2112625389686b357ce31b37bff","bindings_sha256":"f15ec22f1d67793a81b52300adb762d7777dfcd5345b41afbc1f88643ceefe11","review_equation":"shape1","nonnegative_clamp":"after_common","discard_threshold_bits":"0x3B808081","color_equation_sha256":"65fed9f68757e14282d7dd06fba47954c6acd89b9480f6410d026913ff40ab5a"}
func context()->Dictionary:
 var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(image)
 return {"calculate_color":1.,"calculate_alpha":1.,"common_factor":Color.WHITE,"model_fresnel_included":false,"samples":[{"texture":texture,"filter":"nearest","wrap":"repeat","uv_source":0,"source_uv_index":0,"uv_row0":Vector3(1,0,0),"uv_row1":Vector3(0,1,0),"decoded_samples":true},null,null,null]}
func _initialize()->void:
 var p:=plan();var c:=context();var result:=Stage.create(p,c)
 check(result.status=="verified_color_stage","explicit reviewed section can build")
 var weak_material:WeakRef=weakref(result.material);var weak_shader:WeakRef=weakref(result.material.shader);var weak_texture:WeakRef=weakref(c.samples[0].texture)
 result.clear();c.clear()
 check(weak_material.get_ref()==null and weak_shader.get_ref()==null and weak_texture.get_ref()==null,"caller release frees shader, material and texture")
 for key in ["calculate_color","calculate_alpha","common_factor","model_fresnel_included","samples"]:
  c=context();c.erase(key);check(Stage.create(p,c).status=="unsupported","no guessed context "+key)
 c=context();c.samples[0].uv_source=0.0;result=Stage.create(p,c);check(result.status=="verified_color_stage","JSON numeric UV source accepted");result.clear()
 c=context();c.samples[0].uv_source=0.5;check(Stage.create(p,c).status=="unsupported","fractional UV source rejected")
 for source_uv in [2,3]:
  c=context();c.samples[0].uv_source=source_uv
  check(Stage.create(p,c).status=="unsupported","custom UV cannot silently sample missing channels")
  c.source_mesh=ArrayMesh.new();check(Stage.create(p,c).status=="unsupported","empty source mesh cannot supply custom UV")
  var source:={"vertices":[],"triangles":[[0,1,2]]}
  for point in [Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(0,1,0)]:source.vertices.append({"position":[point.x,point.y,point.z,1.],"color":[255,255,255,255],"uv":[[0.,0.],[.5,0.],[0.,.5],[.5,.5]]})
  var built:=MeshStage.create(source);c.source_mesh=built.mesh;result=Stage.create(p,c)
  check(result.status=="verified_color_stage","four-UV source mesh supplies custom channel "+str(source_uv));result.clear();built.clear()
 c=context();c.calculate_alpha=NAN;check(Stage.create(p,c).status=="unsupported","reject nonfinite controls")
 c=context();p.requires_model_fresnel=true;check(Stage.create(p,c).status=="unsupported","model Fresnel must be explicit");p.requires_model_fresnel=false
 for key in ["texture","filter","wrap","uv_source","uv_row0","uv_row1","decoded_samples","source_uv_index"]:
  c=context();c.samples[0].erase(key);check(Stage.create(p,c).status=="unsupported","no guessed sample "+key)
 c=context();c.samples[0].uv_row0=Vector3(INF,0,0);check(Stage.create(p,c).status=="unsupported","reject nonfinite UVs")
 for edit in ["status","layers","number","decode","operation","hash","layout","clamp","equation","threshold","valid_equation_mutation","missing_signature"]:
  p=plan();c=context()
  match edit:
   "status":p.status="ambiguous"
   "layers":p.layers.pop_back()
   "number":p.layers[0].number=3
   "decode":p.layers[0].decode_semantic="unknown"
   "operation":p.layers[0].color_op="guess"
   "hash":p.bytecode_sha256="unreviewed"
   "layout":p.bindings_sha256="unreviewed"
   "clamp":p.nonnegative_clamp="before_common"
   "equation":p.review_equation="powder1"
   "threshold":p.discard_threshold_bits="0x3B808080"
   "valid_equation_mutation":p.layers[0].color_to_alpha=true
   "missing_signature":p.erase("color_equation_sha256")
  check(Stage.create(p,c).status=="unsupported","reject invalid plan "+edit)
 p.clear();c.clear();result.clear()
 print("AVFX_COLOR_STAGE_CONTRACT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
