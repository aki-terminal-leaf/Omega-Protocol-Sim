# SPDX-License-Identifier: MIT
extends SceneTree
const Stage=preload("res://scripts/avfx_color_stage.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func plan()->Dictionary:
 var layers:Array=[]
 for i in 4:layers.append({"number":i+1,"enabled":i==0,"sample_required":true,"color_to_alpha":false,"decode_semantic":"TextureColor%d_Decode_Off"%(i+1),"uv_index":0,"color_op":"DynamicMul" if i==0 else "Mul","alpha_op":"DynamicMul" if i==0 else "Mul"})
 return {"status":"verified_color_stage","rendering_complete":false,"requires_model_fresnel":false,"layers":layers}
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
 c=context();c.calculate_alpha=NAN;check(Stage.create(p,c).status=="unsupported","reject nonfinite controls")
 c=context();p.requires_model_fresnel=true;check(Stage.create(p,c).status=="unsupported","model Fresnel must be explicit");p.requires_model_fresnel=false
 for key in ["texture","filter","wrap","uv_source","uv_row0","uv_row1","decoded_samples","source_uv_index"]:
  c=context();c.samples[0].erase(key);check(Stage.create(p,c).status=="unsupported","no guessed sample "+key)
 c=context();c.samples[0].uv_row0=Vector3(INF,0,0);check(Stage.create(p,c).status=="unsupported","reject nonfinite UVs")
 for edit in ["status","layers","number","decode","operation"]:
  p=plan();c=context()
  match edit:
   "status":p.status="ambiguous"
   "layers":p.layers.pop_back()
   "number":p.layers[0].number=3
   "decode":p.layers[0].decode_semantic="unknown"
   "operation":p.layers[0].color_op="guess"
  check(Stage.create(p,c).status=="unsupported","reject invalid plan "+edit)
 p.clear();c.clear();result.clear()
 print("AVFX_COLOR_STAGE_CONTRACT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
