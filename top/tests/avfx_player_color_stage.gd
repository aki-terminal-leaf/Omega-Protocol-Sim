# SPDX-License-Identifier: MIT
extends SceneTree
const Player=preload("res://scripts/avfx_player.gd")
const Stage=preload("res://scripts/avfx_color_stage.gd")
var checks:=0;var failures:=0
var probe_context:Dictionary={}
var mutation:=""
var probe_player:Node3D
func check(ok:bool,s:String)->void:
 checks+=1
 if not ok:
  failures+=1;printerr("FAIL "+s)
func curve(v:float)->Dictionary:return {"keys":[{"time":0,"type":1,"data":[1.,1.,v]}],"kind":"scalar","BvPr":0,"BvPo":0,"RanT":0}
func doc(kind:=8)->Dictionary:
 var on:={"value":true};var particle:={"values":{"PrVT":kind,"LpSt":0,"LpEd":0,"RMT":2,"CulT":0,"DsDt":on,"DsDw":on,"DwPr":3},"axes":{},"color":{},"data":{},"materials":{},"life":{"enabled":true,"Val":1000.,"ValR":0.,"Type":0}}
 return {"schema":1,"groups":{"Schd":[{"index":0,"items":[{"values":{"bEna":on,"StTm":0,"TlNo":0},"role":"scheduled_timeline","source_index":0}]}],"TmLn":[{"values":{"LpSt":0,"LpEd":0},"items":[{"values":{"bEna":on,"StTm":0,"EdTm":1000,"EmNo":0,"ClNo":-1},"role":"timeline_item","source_index":0}]}],"Emit":[{"values":{"EVT":0,"LpSt":0,"LpEd":0},"curves":{"CrC":curve(1),"CrI":curve(2000)},"axes":{},"color":{},"data":{},"life":{"enabled":true,"Val":1000.,"ValR":0.,"Type":0},"items":[{"values":{"bEnb":on,"TgtB":0,"CrTm":1,"CrCn":1,"CrPr":100,"PICd":2,"PICo":0},"role":"child_particle","source_index":0}]}],"Ptcl":[particle],"Bind":[],"Efct":[]},"models":[],"textures":[]}
func plan()->Dictionary:
 var layers:Array=[]
 for i in 4:layers.append({"number":i+1,"enabled":i==0,"sample_required":true,"color_to_alpha":false,"decode_semantic":"TextureColor%d_Decode_Off"%(i+1),"uv_index":0,"color_op":"DynamicMul" if i==0 else "Mul","alpha_op":"DynamicMul" if i==0 else "Mul"})
 return {"status":"verified_color_stage","rendering_complete":false,"requires_model_fresnel":false,"layers":layers,"bytecode_sha256":"6f371f4b36697057d24590c42dd1740c1f5ac2112625389686b357ce31b37bff","bindings_sha256":"f15ec22f1d67793a81b52300adb762d7777dfcd5345b41afbc1f88643ceefe11","review_equation":"shape1","nonnegative_clamp":"after_common","discard_threshold_bits":"0x3B808081","color_equation_sha256":"65fed9f68757e14282d7dd06fba47954c6acd89b9480f6410d026913ff40ab5a"}
func provide(_request:Dictionary)->Dictionary:
 if mutation=="trigger":probe_player.trigger(0,0.)
 elif mutation=="seek":probe_player.seek(0.)
 elif mutation=="reset":probe_player.reset()
 elif mutation=="configure":probe_player.configure(doc())
 return probe_context
func context_for(texture:Texture2D)->Dictionary:
 return {"calculate_color":.5,"calculate_alpha":.7,"common_factor":Color(.2,.3,.4,.8),"model_fresnel_included":false,"factor_includes_particle_color":true,"factor_includes_mesh_color":true,"samples":[{"texture":texture,"filter":"nearest","wrap":"repeat","uv_source":0,"source_uv_index":0,"uv_row0":Vector3(1,0,0),"uv_row1":Vector3(0,1,0),"decoded_samples":true},null,null,null]}
func setup(player:Node3D,data:Dictionary)->bool:
 player.reset();return player.configure(data) and player.configure_color_stage_bindings({0:{"plan":plan(),"context_provider":Callable(self,"provide")}})
func model_doc()->Dictionary:
 var d:=doc(5);d.groups.Ptcl[0].data={"MdNo":[0]}
 var model:={"vertices":[],"triangles":[[0,1,2]]}
 for p in [Vector3(-1,1,0),Vector3(1,1,0),Vector3(0,-1,0)]:model.vertices.append({"position":[p.x,p.y,p.z,1.],"color":[120,180,220,170],"uv":[[.1,.2],[.3,.4],[.5,.6],[.7,.8]]})
 d.models=[model];return d
func extra_contracts(player:Node3D)->void:
 probe_player=player
 var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
 var tex:=ImageTexture.create_from_image(image)
 for blend in 4:
  for cull in 3:
   for test_depth in [false,true]:
    for write_depth in [false,true]:
     probe_context=context_for(tex);var d:=doc();var values:Dictionary=d.groups.Ptcl[0].values
     values.RMT=blend;values.CulT=cull;values.DsDt=test_depth;values.DsDw=write_depth;values.DwPr=400
     check(setup(player,d) and player.seek(2),"state matrix seek")
     var mat:ShaderMaterial=player.draws.values()[0].material_override;var code:String=mat.shader.code
     check(code.contains(["blend_mix","blend_mul","blend_add","blend_sub"][blend]) and code.contains(["cull_disabled","cull_front","cull_back"][cull]) and code.contains("depth_draw_always" if write_depth else "depth_draw_never") and code.contains("depth_test_disabled")==not test_depth and mat.render_priority==Material.RENDER_PRIORITY_MAX,"state matrix preservation")
 for uv in 4:
  probe_context=context_for(tex);probe_context.samples[0].uv_source=uv
  check(setup(player,model_doc()) and player.seek(2),"model real four UV "+str(uv))
 probe_context=context_for(tex);probe_context.samples[0].uv_source=2;probe_context.source_mesh=player.draws.values()[0].mesh
 check(setup(player,doc()) and not player.seek(2) and player.draws.is_empty(),"provider spoof mesh cannot supply custom UV to real quad")
 probe_context=context_for(tex);check(setup(player,model_doc()) and player.seek(2),"mesh replacement setup")
 player.draws.values()[0].mesh=QuadMesh.new();check(not player.seek(3) and player.last_particles.is_empty(),"postcompile actual mesh replacement rejected")
 for change in ["nonfinite","sampler","route","factor","meshfactor","state","shader","priority","empty_mesh"]:
  probe_context=context_for(tex);check(setup(player,doc()) and player.seek(2),change+" good frame")
  match change:
   "nonfinite":probe_context.calculate_alpha=NAN
   "sampler":probe_context.samples[0].filter="linear"
   "route":probe_context.samples[0].uv_source=1
   "factor":probe_context.factor_includes_particle_color=false
   "meshfactor":probe_context.factor_includes_mesh_color=1
   "state":player.document.groups.Ptcl[0].values.RMT=1
   "shader":player.draws.values()[0].material_override.shader=Shader.new()
   "priority":player.draws.values()[0].material_override.render_priority=1
   "empty_mesh":player.draws.values()[0].mesh=ArrayMesh.new()
  check(not player.seek(3) and player.draws.is_empty() and player.color_stage_draws.is_empty() and player.last_particles.is_empty(),change+" fails with no stale frame")
 for field in ["RMT","CulT","DwPr","DsDt","DsDw"]:
  probe_context=context_for(tex);var d:=doc();d.groups.Ptcl[0].values[field]=.5
  check(setup(player,d) and not player.seek(2),"fractional state rejected "+field)
 probe_context=context_for(tex);check(setup(player,doc()) and player.seek(2),"texture update setup")
 var mat:ShaderMaterial=player.draws.values()[0].material_override;var shader:Shader=mat.shader
 var other:=ImageTexture.create_from_image(image);probe_context.samples[0].texture=other
 check(player.seek(3) and mat.get_shader_parameter("tex0")==other and mat.shader==shader,"runtime texture can update without recompiling sampler")
 for action in ["trigger","seek","reset","configure"]:
  probe_context=context_for(tex);mutation=action
  check(setup(player,doc()) and not player.seek(2) and player.triggers.is_empty() and player.draws.is_empty(),"provider reentrant "+action+" fails closed")
 mutation="";probe_context=context_for(tex);player.reset();check(player.configure(doc()),"rejected configuration setup")
 check(not player.configure_color_stage_bindings({99:{"plan":plan(),"context_provider":Callable(self,"provide")}}) and not player.seek(2),"invalid explicit request cannot fall back to legacy")
 check(setup(player,doc()) and player.seek(2),"expiry setup")
 var weakmat:WeakRef=weakref(player.draws.values()[0].material_override);mat=null;shader=null
 check(player.seek(1000) and player.draws.is_empty() and player.color_stage_draws.is_empty() and weakmat.get_ref()==null,"expiry releases draw material")
 player.reset();probe_context.clear();probe_player=null;tex=null;other=null
func _initialize()->void:call_deferred("run")
func run()->void:
 var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);var texture:=ImageTexture.create_from_image(image);var player:=Player.new();root.add_child(player)
 check(player.configure(doc()) and player.seek(1) and player.draws.size()==1,"legacy unchanged");player.reset()
 var provider:=func(r:Dictionary)->Dictionary:
  var age:=float(r.age);return {"calculate_color":age/100.,"calculate_alpha":.5,"common_factor":Color(.2+age/1000.,.4,.6,.8),"model_fresnel_included":false,"factor_includes_particle_color":true,"factor_includes_mesh_color":true,"samples":[{"texture":texture,"filter":"nearest","wrap":"repeat","uv_source":0,"source_uv_index":0,"uv_row0":Vector3(1,0,age/100.),"uv_row1":Vector3(0,1,0),"decoded_samples":true},null,null,null]}
 check(player.configure(doc()) and player.configure_color_stage_bindings({0:{"plan":plan(),"context_provider":provider}}) and player.seek(1),"bound seek")
 check(player.draws.size()==1 and player.color_stage_draws.size()==1,"bound draw has no fallback duplicate")
 var key:Variant=player.color_stage_draws.keys()[0];var draw:MeshInstance3D=player.draws[key];var binding:Dictionary=player.color_stage_draws[key];var material:ShaderMaterial=binding.material;var shader:=material.shader
 check(draw.material_override==material,"binding material is actual draw override")
 check(material.get_shader_parameter("particle_color")==null,"no tint double uniform")
 for frame_value in 100:
  check(player.seek(frame_value+1),"seek "+str(frame_value));var current:ShaderMaterial=player.color_stage_draws[key].material;check(is_same(current,material) and is_same(current.shader,shader) and player.draws[key].material_override==current,"identity "+str(frame_value));current=null
 check(material.get_shader_parameter("uv0_row0")==Vector3(1,0,1),"latest UV row");check(not player.configure_color_stage_bindings({}),"live replace rejected")
 player.reset();check(player.configure(doc(12)) and player.configure_color_stage_bindings({0:{"plan":plan(),"context_provider":provider}}),"disc setup");check(not player.seek(2),"dynamic disc rejected")
 for mode in ["missing","fingerprint","render"]:
  var d:=doc();var q:=plan();var fn:=provider
  if mode=="missing":fn=func(_r:Dictionary)->Dictionary:return {}
  if mode=="fingerprint":q.bytecode_sha256="invalid"
  if mode=="render":d.groups.Ptcl[0].values.RMT=99
  player.reset();check(player.configure(d) and player.configure_color_stage_bindings({0:{"plan":q,"context_provider":fn}}),mode+" setup");check(not player.seek(2),mode+" rejected");check(player.draws.is_empty() and player.color_stage_draws.is_empty() and player.last_particles.is_empty() and player.mesh_cache.is_empty() and player.texture_cache.is_empty(),mode+" clears");check(player.diagnostics.keys().any(func(k:Variant)->bool:return str(k).begins_with("verified_color_stage/0/")),mode+" diagnostic");fn=Callable()
 player.reset();check(player.configure(doc()) and player.configure_color_stage_bindings({0:{"plan":plan(),"context_provider":provider}}) and player.seek(3),"release setup");key=player.color_stage_draws.keys()[0];draw=player.draws[key];binding=player.color_stage_draws[key];var wm:WeakRef=weakref(binding.material);var ws:WeakRef=weakref(binding.material.shader);var wmesh:WeakRef=weakref(draw.mesh);var wt:WeakRef=weakref(texture)
 player.reset();check(player.color_stage_bindings.is_empty() and player.color_stage_draws.is_empty(),"reset clears bindings");draw=null;binding.clear();material=null;shader=null;provider=Callable();texture=null;check(wm.get_ref()==null,"reset releases material");check(ws.get_ref()==null,"reset releases shader");check(wmesh.get_ref()==null,"reset releases mesh");check(wt.get_ref()==null,"reset releases texture after caller closures clear")
 extra_contracts(player)
 player.free();print("AVFX_PLAYER_COLOR_STAGE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
