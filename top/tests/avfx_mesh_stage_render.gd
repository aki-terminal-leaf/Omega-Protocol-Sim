# SPDX-License-Identifier: MIT
extends SceneTree
const Stage=preload("res://scripts/avfx_mesh_stage.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func source()->Dictionary:
 var rows:Array=[]
 for point in [Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(1,1,0),Vector3(-1,1,0)]:
  rows.append({"position":[point.x,point.y,point.z,1.],"color":[255,255,255,255],"uv":[[.25,.25],[.75,.25],[.25,.75],[.75,.75]]})
 return {"vertices":rows,"triangles":[[0,1,2],[0,2,3]]}
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(320,240)
 var world:=Node3D.new();root.add_child(world)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.position=Vector3(0,0,5);camera.look_at(Vector3.ZERO);camera.current=true
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;world.add_child(environment)
 var result:=Stage.create(source());check(result.status=="source_geometry","four original UV mesh built")
 if result.status!="source_geometry":world.free();quit(1);return
 var quad:=MeshInstance3D.new();quad.mesh=result.mesh;world.add_child(quad)
 var image:=Image.create(2,2,false,Image.FORMAT_RGBA8);var palette:=[Color.RED,Color.GREEN,Color.BLUE,Color.WHITE]
 for i in 4:image.set_pixel(i%2,i/2,palette[i])
 var texture:=ImageTexture.create_from_image(image)
 var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D test_texture:filter_nearest,repeat_disable;
uniform int source_uv=0;
varying vec4 original_uv23;
void vertex(){original_uv23=CUSTOM0;}
void fragment(){vec2 uv=source_uv==0?UV:(source_uv==1?UV2:(source_uv==2?original_uv23.xy:original_uv23.zw));ALBEDO=texture(test_texture,uv).rgb;}
"""
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("test_texture",texture);quad.material_override=material
 var snapshots:Array=[]
 for i in 4:
  material.set_shader_parameter("source_uv",i)
  for _frame in 8:await process_frame
  await RenderingServer.frame_post_draw
  var canvas:=root.get_texture().get_image();var pixel:=canvas.get_pixel(canvas.get_width()/2,canvas.get_height()/2)
  var expected:Color=palette[i];var error:=maxf(absf(pixel.r-expected.r),maxf(absf(pixel.g-expected.g),absf(pixel.b-expected.b)))
  check(error<0.01,"original UV%d sampled its independent texel"%i)
  snapshots.append({"source_uv":i,"actual":[pixel.r,pixel.g,pixel.b],"expected":[expected.r,expected.g,expected.b]})
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():
  DirAccess.make_dir_recursive_absolute(args[0]);root.get_texture().get_image().save_png(args[0].path_join("four-uv-canvas.png"))
  var file:=FileAccess.open(args[0].path_join("four-uv-pixels.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"pixels":snapshots,"engine":Engine.get_version_info().string,"rendering_complete":false},"  "));file.close()
 var mesh_ref:WeakRef=weakref(quad.mesh);var material_ref:WeakRef=weakref(material);var shader_ref:WeakRef=weakref(shader);var texture_ref:WeakRef=weakref(texture)
 quad.mesh=null;quad.material_override=null;result.clear();material=null;shader=null;texture=null;world.free()
 for _frame in 4:await process_frame
 check(mesh_ref.get_ref()==null and material_ref.get_ref()==null and shader_ref.get_ref()==null and texture_ref.get_ref()==null,"all GPU probe resource references released")
 print("AVFX_MESH_STAGE_RENDER checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
