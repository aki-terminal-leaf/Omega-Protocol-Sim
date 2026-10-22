# SPDX-License-Identifier: MIT
extends SceneTree
## External fixtures carry independent ORIGINAL instruction equations and hashes.
const Stage=preload("res://scripts/avfx_color_stage.gd")
var checks:=0
var failures:=0
var snapshots:Array=[]
var weak_resources:Array=[]
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
 var quad:=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2);world.add_child(quad)
 var texture_refs:Array=[]
 for fixture in fixtures:
  var samples:Array=[]
  if fixture.has("uv_rows"):
   var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
   arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,1,0),Vector3(1,1,0),Vector3(1,-1,0),Vector3(-1,-1,0)])
   arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(.25,.25),Vector2(.25,.25),Vector2(.25,.25),Vector2(.25,.25)])
   arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array([Vector2(.75,.75),Vector2(.75,.75),Vector2(.75,.75),Vector2(.75,.75)])
   arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
   var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);quad.mesh=mesh
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
  var context:={"samples":samples,"calculate_color":fixture.cc,"calculate_alpha":fixture.ca,"common_factor":Color(f[0],f[1],f[2],f[3]),"model_fresnel_included":true}
  var result:Dictionary=Stage.create(fixture.plan,context)
  check(result.status=="verified_color_stage","build "+fixture.label)
  if result.status!="verified_color_stage":printerr(result);samples.clear();context.clear();continue
  var material:ShaderMaterial=result.material;weak_resources.append(weakref(material));weak_resources.append(weakref(material.shader));quad.material_override=material
  var got:Color=await pixels();var expected:Array=fixture.expected;var a:=clampf(expected[3],0,1)
  # The explicit pre-postprocess result over black, without game tone-map/MRT.
  var target:=Color(display_transfer(maxf(0,expected[0]))*a,display_transfer(maxf(0,expected[1]))*a,display_transfer(maxf(0,expected[2]))*a,1)
  if a<1.0/255.0:target=Color.BLACK
  var delta:=maxf(absf(got.r-target.r),maxf(absf(got.g-target.g),absf(got.b-target.b)))
  check(delta<0.015,"RGB pixel "+fixture.label+" got="+str(got)+" want="+str(target))
  material.set_shader_parameter("diagnostic_alpha",true)
  var alpha:Color=await pixels()
  check(maxf(absf(alpha.r-display_transfer(0.25+0.5*a)),maxf(absf(alpha.g-display_transfer(0.25+0.5*a)),absf(alpha.b-display_transfer(0.25+0.5*a))))<0.008,"alpha pixel "+fixture.label)
  snapshots.append({"label":fixture.label,"rgb":[got.r,got.g,got.b],"alpha":[alpha.r,alpha.g,alpha.b],"expected":expected,"max_rgb_error":delta,"package_sha256":fixture.plan.package_sha256,"pixel_sha256":fixture.plan.bytecode_sha256})
  quad.material_override=null;material=null;result.clear();context.clear();samples.clear()
 # Let render commands relinquish all task-owned material/image references.
 for _i in 4:await process_frame
 for ref in weak_resources:check(ref.get_ref()==null,"released color material/shader")
 for ref in texture_refs:check(ref.get_ref()==null,"released sampled texture")
 var output:=args[1];DirAccess.make_dir_recursive_absolute(output)
 root.get_texture().get_image().save_png(output.path_join("last-color-stage.png"))
 var file:=FileAccess.open(output.path_join("color-stage-pixels.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"pixels":snapshots,"fixture_count":fixtures.size(),"rendering_complete":false,"engine":Engine.get_version_info().string,"display_transfer":"ed1daf0bf GLES3 tonemap_inc.glsl approximations; alpha encoded 0.25+0.5*a"},"  "));file.close()
 world.free();print("AVFX_COLOR_STAGE checks=%d failures=%d fixtures=%d"%[checks,failures,fixtures.size()]);quit(1 if failures else 0)
