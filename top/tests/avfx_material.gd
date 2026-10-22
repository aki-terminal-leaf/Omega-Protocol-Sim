# SPDX-License-Identifier: MIT
extends SceneTree
const Player=preload("res://scripts/avfx_player.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var player:=Player.new();root.add_child(player)
 var node:={"index":0,"values":{"PrVT":8,"RMT":0,"CulT":0,"DsDt":1,"DsDw":0},"materials":{"TC1":{"bEna":1,"TLst":[0]}},"uv_sets":[]}
 player.document={"groups":{"Ptcl":[node]},"textures":["vfx/mask.atex"]}
 var material:=player._material({"index":0})
 check(player.diagnostics.has("tc1_mask_requires_apricot_shader"),"source mask list is not silently treated as primary texture")
 check(not material.get_shader_parameter("textured"),"missing TxNo cannot fall back to TLst first entry")
 check(not player.diagnostics.has("missing_texture/0"),"mask must not even be requested as base sample")
 for blend in [0,1,2,3]:
  node.values.RMT=blend
  for cull in [0,1,2]:
   node.values.CulT=cull;material=player._material({"index":0})
   check(material.shader.code.contains(["blend_mix","blend_mul","blend_add","blend_sub"][blend]),"explicit blend code")
   check(material.shader.code.contains(["cull_disabled","cull_front","cull_back"][cull]),"explicit cull code")
 node.values.DsDt=0;node.values.DsDw=1;node.values.DwPr=12
 material=player._material({"index":0})
 check(material.shader.code.contains("depth_test_disabled") and material.shader.code.contains("depth_draw_always"),"source depth disabled/write enabled")
 check(material.render_priority==12,"source draw priority")
 node.values.DsDt=1;node.values.DsDw=0
 material=player._material({"index":0})
 check(not material.shader.code.contains("depth_test_disabled") and material.shader.code.contains("depth_draw_never"),"source depth enabled/write disabled")
 node.materials.TC1={"TFT":0,"TBUT":1,"TBVT":1}
 material=player._material({"index":0})
 check(material.shader.code.contains("filter_nearest,repeat_disable"),"clamp and nearest are not forced to repeated linear")
 node.materials.TC1={"TFT":1,"TBUT":0,"TBVT":0}
 material=player._material({"index":0})
 check(material.shader.code.contains("filter_linear,repeat_enable"),"repeat and linear mapped independently")
 node.values.RMT=11;node.values.CulT=3;node.values.DsSp=1
 player._material({"index":0})
 check(player.diagnostics.has("blend_mode/11") and player.diagnostics.has("culling_mode/3") and player.diagnostics.has("soft_particle_requires_apricot_shader"),"unknown rendering states remain diagnosed")
 material=null;player.free()
 print("AVFX_MATERIAL checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
