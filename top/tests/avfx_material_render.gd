# SPDX-License-Identifier: MIT
extends SceneTree
## Real pixels: independent depth/culling/wrapping probes, not original-game fidelity.
const Player=preload("res://scripts/avfx_player.gd")
var checks:=0
var failures:=0
var snapshots:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func pixels()->Color:
 for _i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var img:=root.get_texture().get_image()
 var color:=img.get_pixel(img.get_width()/2,img.get_height()/2)
 snapshots.append([color.r,color.g,color.b,color.a])
 return color
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(320,240)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.2,0.2,0.2)
 world.add_child(environment)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.0;camera.position=Vector3(0,0,10);camera.look_at(Vector3.ZERO);camera.current=true
 var player:=Player.new();world.add_child(player)
 var first:={"values":{"PrVT":8,"RMT":0,"CulT":0,"DsDt":1,"DsDw":1,"DwPr":0},"materials":{},"uv_sets":[]}
 var second:=first.duplicate(true);second.values.DsDw=0;second.values.DwPr=1
 player.document={"groups":{"Ptcl":[first,second]},"textures":["vfx/synthetic.atex"]}
 var front:=MeshInstance3D.new();front.mesh=QuadMesh.new();front.mesh.size=Vector2(2,2);world.add_child(front)
 var back:=MeshInstance3D.new();back.mesh=QuadMesh.new();back.mesh.size=Vector2(2,2);back.position.z=-1.0;world.add_child(back)
 front.material_override=player._material({"index":0});front.material_override.set_shader_parameter("particle_color",Color.RED)
 back.material_override=player._material({"index":1});back.material_override.set_shader_parameter("particle_color",Color.BLUE)
 var color:Color=await pixels()
 check(color.r>0.9 and color.b<0.1,"depth write blocks later higher-priority farther transparent draw")
 second.values.DsDt=0;back.material_override=player._material({"index":1});back.material_override.set_shader_parameter("particle_color",Color.BLUE)
 color=await pixels();check(color.b>0.9 and color.r<0.1,"depth-test-disabled draw is actually visible behind blocker")
 front.visible=false;second.values.DsDt=1;second.values.CulT=1
 back.material_override=player._material({"index":1});back.material_override.set_shader_parameter("particle_color",Color.BLUE)
 color=await pixels();check(absf(color.r-color.b)<0.05 and color.b<0.8,"front-face culling removes front-facing quad")
 second.values.CulT=2;back.material_override=player._material({"index":1});back.material_override.set_shader_parameter("particle_color",Color.BLUE)
 color=await pixels();check(color.b>0.9 and color.r<0.1,"back-face culling preserves front-facing quad")
 back.visible=false;front.visible=true
 var image:=Image.create(2,1,false,Image.FORMAT_RGBA8);image.set_pixel(0,0,Color.RED);image.set_pixel(1,0,Color.BLUE)
 player.texture_cache[0]=ImageTexture.create_from_image(image);image=null
 first.materials={"TC1":{"bEna":1,"TxNo":0,"TFT":0,"TBUT":0,"TBVT":0}}
 front.material_override=player._material({"index":0});front.material_override.set_shader_parameter("uv_scroll",Vector2(0.75,0.0))
 color=await pixels();check(color.r>0.9 and color.b<0.1,"repeat sampler actually wraps shifted UV to red texel")
 first.materials.TC1.TBUT=1;first.materials.TC1.TBVT=1
 front.material_override=player._material({"index":0});front.material_override.set_shader_parameter("uv_scroll",Vector2(0.75,0.0))
 color=await pixels();check(color.b>0.9 and color.r<0.1,"clamp sampler actually samples blue edge instead of wrapping")
 # Original alpha discard must happen before depth write, not merely
 # produce a nearly transparent fragment that still blocks later particles.
 first.materials={};front.material_override=player._material({"index":0});front.material_override.set_shader_parameter("particle_color",Color(1,0,0,0.002))
 back.visible=true;second.values.DsDt=1;second.values.CulT=2
 back.material_override=player._material({"index":1});back.material_override.set_shader_parameter("particle_color",Color.BLUE)
 color=await pixels();check(color.b>0.9 and color.r<0.1,"sub-1/255 alpha fragment is discarded before it can write depth")
 back.visible=false;first.materials={"TC1":{"bEna":1,"TxNo":0,"TFT":0,"TBUT":1,"TBVT":1}}
 # Original Apricot textured variants derive alpha from weighted RGB,
 # not max(RGB) multiplied by the stored texture alpha.
 environment.environment.background_color=Color.BLACK
 first.materials.TC1.bC2A=1
 for probe in [[Color(1,0,0,0.2),0.298912,0],[Color(0,1,0,0.2),0.586611,1],[Color(0,0,1,0.2),0.114478,2]]:
  image=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(probe[0]);player.texture_cache[0]=ImageTexture.create_from_image(image);image=null
  front.material_override=player._material({"index":0})
  color=await pixels()
  check(absf(color[int(probe[2])]-float(probe[1]))<0.012,"actual weighted RGB alpha, independent of stored texture alpha")
 first.materials={}
 for probe in [[0,Color.WHITE,Color(1,0,0,0.5),Color(1,0.5,0.5)],[1,Color(0,1,1),Color.RED,Color.BLACK],[2,Color(0,1,1),Color.RED,Color.WHITE],[3,Color.WHITE,Color.RED,Color(0,1,1)]]:
  first.values.RMT=probe[0];environment.environment.background_color=probe[1]
  front.material_override=player._material({"index":0});front.material_override.set_shader_parameter("particle_color",probe[2])
  color=await pixels();var expected:Color=probe[3]
  check(maxf(absf(color.r-expected.r),maxf(absf(color.g-expected.g),absf(color.b-expected.b)))<0.012,"actual mix/multiply/add/subtract framebuffer equation")
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():
  DirAccess.make_dir_recursive_absolute(args[0])
  root.get_texture().get_image().save_png(args[0].path_join("material-last-case.png"))
  var out:=FileAccess.open(args[0].path_join("material-pixels.json"),FileAccess.WRITE)
  out.store_string(JSON.stringify({"checks":checks,"failures":failures,"pixels":snapshots,"original_game_equivalence":false},"  "));out.close()
 front.material_override=null;back.material_override=null;player.reset();world.free()
 print("AVFX_MATERIAL_RENDER checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
