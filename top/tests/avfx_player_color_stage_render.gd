# SPDX-License-Identifier: MIT
extends SceneTree
## External fixtures carry independent ORIGINAL instruction equations and hashes.
const Player=preload("res://scripts/avfx_player.gd")
const Stage=preload("res://scripts/avfx_color_stage.gd")
var checks:=0
var failures:=0
var snapshots:Array=[]
var weak_resources:Array=[]
var weak_meshes:Array=[]
var active_context:Dictionary={}
var provider_missing:=false
var provider_requests:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func pixels()->Color:
 for _i in 8:await process_frame
 await RenderingServer.frame_post_draw
 var img:=root.get_texture().get_image()
 return img.get_pixel(img.get_width()/2,img.get_height()/2)
# Pinned Godot ed1daf0bf drivers/gles3/shaders/tonemap_inc.glsl, MIT.
# Compatibility converts ALBEDO using these two approximations even unshaded.
func display_transfer(value:float)->float:
 var linear:=value*(value*(value*0.305306011+0.682171111)+0.012522878)
 return maxf(1.055*pow(maxf(linear,0.0),0.416666667)-0.055,0.0)
func curve(value:Variant,kind:="scalar")->Dictionary:
 var data:Array=[1.,1.,value]
 if value is Vector3:data=[value.x,value.y,value.z]
 return {"keys":[{"time":0,"type":1,"data":data}],"kind":"rgb" if value is Vector3 else kind,"BvPr":0,"BvPo":0,"RanT":0}
func document()->Dictionary:
 var on:={"value":true};var model:={"vertices":[],"triangles":[[0,1,2],[0,2,3]]}
 for p in [Vector3(-1,1,0),Vector3(1,1,0),Vector3(1,-1,0),Vector3(-1,-1,0)]:model.vertices.append({"position":[p.x,p.y,p.z,1.],"color":[160,208,112,192],"uv":[[.25,.25],[.75,.75],[.75,.25],[.25,.75]]})
 return {"schema":1,"groups":{"Schd":[{"index":0,"items":[{"values":{"bEna":on,"StTm":0,"TlNo":0},"role":"scheduled_timeline","source_index":0}]}],"TmLn":[{"values":{"LpSt":0,"LpEd":0},"items":[{"values":{"bEna":on,"StTm":0,"EdTm":100,"EmNo":0,"ClNo":-1},"role":"timeline_item","source_index":0}]}],"Emit":[{"values":{"EVT":0,"LpSt":0,"LpEd":0},"curves":{"CrC":curve(1),"CrI":curve(200)},"axes":{},"color":{},"data":{},"life":{"enabled":true,"Val":100.,"ValR":0.,"Type":0},"items":[{"values":{"bEnb":on,"TgtB":0,"CrTm":1,"CrCn":1,"CrPr":100,"PICd":2,"PICo":0},"role":"child_particle","source_index":0}]}],"Ptcl":[{"values":{"PrVT":5,"LpSt":0,"LpEd":0,"RMT":0,"CulT":0,"DsDt":1,"DsDw":0,"DwPr":0},"axes":{},"color":{"RGB":curve(Vector3(.7,.8,.9),"vector3"),"A":curve(.8)},"data":{"MdNo":[0]},"materials":{},"uv_sets":[],"life":{"enabled":true,"Val":100.,"ValR":0.,"Type":0}}],"Bind":[],"Efct":[]},"models":[model],"textures":[]}
func provide(request:Dictionary)->Variant:
 provider_requests.append(request)
 if provider_missing:return null
 var context:=active_context.duplicate(true);context.factor_includes_particle_color=true;context.factor_includes_mesh_color=true;context.erase("source_mesh")
 return context
func _initialize()->void:call_deferred("run")
func run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:printerr("fixture JSON and evidence directory required");quit(2);return
 var fixtures:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if not fixtures is Array or fixtures.is_empty() or fixtures.size()>256:printerr("bounded fixtures required");quit(2);return
 root.size=Vector2i(320,240)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;world.add_child(environment)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.0;camera.position=Vector3(0,0,10);camera.look_at(Vector3.ZERO);camera.current=true
 var player:=Player.new();world.add_child(player)
 var texture_refs:Array=[]
 for fixture in fixtures:
  var samples:Array=[]
  for i in 4:
   var values:Array=fixture.samples[i]
   var image:=Image.create(1,1,false,Image.FORMAT_RGBAF);image.fill(Color(values[0],values[1],values[2],values[3]))
   if fixture.has("texels"):
    image=Image.create(2,2,false,Image.FORMAT_RGBAF)
    for k in 4:
     var texel:Array=fixture.texels[i][k];image.set_pixel(k%2,k/2,Color(texel[0],texel[1],texel[2],texel[3]))
   var texture:=ImageTexture.create_from_image(image);image=null
   samples.append({"texture":texture,"filter":"nearest","wrap":"clamp","uv_source":0,"uv_row0":Vector3(1,0,0),"uv_row1":Vector3(0,1,0),"decoded_samples":true,"source_uv_index":fixture.plan.layers[i].get("uv_index",0)})
   if fixture.has("uv_rows"):
    var rows:Array=fixture.uv_rows[i];samples[i].uv_row0=Vector3(rows[0][0],rows[0][1],rows[0][2]);samples[i].uv_row1=Vector3(rows[1][0],rows[1][1],rows[1][2]);samples[i].uv_source=fixture.uv_sources[i]
   texture_refs.append(weakref(texture));texture=null
  var f:Array=fixture.factor
  active_context={"samples":samples,"calculate_color":fixture.cc,"calculate_alpha":fixture.ca,"common_factor":Color(f[0],f[1],f[2],f[3]),"model_fresnel_included":true}
  provider_missing=false;provider_requests.clear();var doc:=document()
  check(player.configure(doc),"Player configure "+fixture.label);doc={}
  check(player.configure_color_stage_bindings({0:{"plan":fixture.plan,"context_provider":Callable(self,"provide")}}),"Player binding "+fixture.label)
  var sought:bool=player.seek(5)
  check(sought,"Player seek 5 "+fixture.label)
  if not sought or player.color_stage_draws.is_empty():player.reset();world.free();quit(1);return
  var key:Variant=player.color_stage_draws.keys()[0] if not player.color_stage_draws.is_empty() else null
  var binding:Dictionary=player.color_stage_draws.get(key,{});var instance:MeshInstance3D=player.draws.get(key)
  var material:ShaderMaterial=binding.get("material");weak_resources.append(weakref(material));weak_resources.append(weakref(material.shader));weak_meshes.append(weakref(instance.mesh))
  check(instance.material_override==material,"actual material override "+fixture.label)
  check(provider_requests.size()==1 and provider_requests[0].actual_mesh==instance.mesh and provider_requests[0].particle_color!=Color.WHITE,"provider actual request "+fixture.label)
  var got:Color=await pixels();var expected:Array=fixture.expected;var a:=clampf(expected[3],0,1)
  # The explicit pre-postprocess result over black, without game tone-map/MRT.
  var target:=Color(display_transfer(maxf(0,expected[0]))*a,display_transfer(maxf(0,expected[1]))*a,display_transfer(maxf(0,expected[2]))*a,1)
  if a<Stage.DISCARD_THRESHOLD:target=Color.BLACK
  var delta:=maxf(absf(got.r-target.r),maxf(absf(got.g-target.g),absf(got.b-target.b)))
  check(delta<0.015,"RGB pixel "+fixture.label+" got="+str(got)+" want="+str(target))
  material.set_shader_parameter("diagnostic_alpha",true)
  var alpha:Color=await pixels()
  check(maxf(absf(alpha.r-display_transfer(0.25+0.5*a)),maxf(absf(alpha.g-display_transfer(0.25+0.5*a)),absf(alpha.b-display_transfer(0.25+0.5*a))))<0.008,"alpha pixel "+fixture.label)
  if fixture.get("signed_probe",false):
   material.set_shader_parameter("diagnostic_alpha",false)
   material.set_shader_parameter("diagnostic_signed_rgb",true)
   var signed_pixel:Color=await pixels()
   var signed_target:=Color(display_transfer(0.5+0.25*expected[0]),display_transfer(0.5+0.25*expected[1]),display_transfer(0.5+0.25*expected[2]),1)
   check(maxf(absf(signed_pixel.r-signed_target.r),maxf(absf(signed_pixel.g-signed_target.g),absf(signed_pixel.b-signed_target.b)))<0.008,"encoded signed RGB "+fixture.label)
   material.set_shader_parameter("diagnostic_signed_rgb",false)
   material.set_shader_parameter("diagnostic_discard",true)
   var discard_pixel:Color=await pixels()
   var discard_target:=0.0 if fixture.expected_discard else display_transfer(1.0)
   check(maxf(absf(discard_pixel.r-discard_target),maxf(absf(discard_pixel.g-discard_target),absf(discard_pixel.b-discard_target)))<0.008,"exact discard boundary "+fixture.label)
  material.set_shader_parameter("diagnostic_alpha",false);material.set_shader_parameter("diagnostic_signed_rgb",false);material.set_shader_parameter("diagnostic_discard",false)
  var shader:=material.shader
  var updated_cc:=1.0-float(active_context.calculate_color);var updated_ca:=1.0-float(active_context.calculate_alpha)
  var updated_factor:=Color(.31,.47,.59,.73);var updated_row:=Vector3(.5,0,.125)
  active_context.calculate_color=updated_cc;active_context.calculate_alpha=updated_ca;active_context.common_factor=updated_factor;active_context.samples[0].uv_row0=updated_row
  check(player.seek(6),"Player seek 6 "+fixture.label);check(player.color_stage_draws[key].material==material and material.shader==shader,"no recompile "+fixture.label)
  check(provider_requests.size()==2 and provider_requests[1].age>provider_requests[0].age,"provider updates on later seek "+fixture.label)
  check(is_equal_approx(float(material.get_shader_parameter("calculate_color")),updated_cc) and is_equal_approx(float(material.get_shader_parameter("calculate_alpha")),updated_ca) and material.get_shader_parameter("common_factor")==updated_factor and material.get_shader_parameter("uv0_row0")==updated_row,"animated controls, factor, and UV rows update without recompile "+fixture.label)
  snapshots.append({"label":fixture.label,"rgb":[got.r,got.g,got.b],"alpha":[alpha.r,alpha.g,alpha.b],"expected":expected,"max_rgb_error":delta,"package_sha256":fixture.plan.package_sha256,"pixel_sha256":fixture.plan.bytecode_sha256})
  material=null;shader=null;instance=null;binding={};active_context.clear();samples.clear()
 provider_missing=true;check(not player.seek(7),"missing provider fails seek");check(player.draws.is_empty() and player.color_stage_draws.is_empty(),"missing provider clears draws");check((await pixels()).is_equal_approx(Color.BLACK),"missing provider black framebuffer")
 player.reset();provider_requests.clear()
 # Let render commands relinquish all task-owned material/image references.
 for _i in 4:await process_frame
 for ref in weak_resources:check(ref.get_ref()==null,"released color material/shader")
 for ref in texture_refs:check(ref.get_ref()==null,"released sampled texture")
 var output:=args[1];DirAccess.make_dir_recursive_absolute(output)
 root.get_texture().get_image().save_png(output.path_join("last-player-color-stage.png"))
 world.free()
 for _i in 4:await process_frame
 for ref in weak_meshes:check(ref.get_ref()==null,"released original four-UV source mesh")
 var file:=FileAccess.open(output.path_join("player-color-stage-pixels.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"pixels":snapshots,"fixture_count":fixtures.size(),"rendering_complete":false,"engine":Engine.get_version_info().string,"display_transfer":"ed1daf0bf GLES3 tonemap_inc.glsl approximations; alpha encoded 0.25+0.5*a"},"  "));file.close()
 print("AVFX_PLAYER_COLOR_STAGE checks=%d failures=%d fixtures=%d"%[checks,failures,fixtures.size()]);quit(1 if failures else 0)
