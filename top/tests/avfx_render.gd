# SPDX-License-Identifier: MIT
extends SceneTree
const Player=preload("res://scripts/avfx_player.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()<3:printerr("Need preview document, texture map, output directory");quit(2);return
 root.size=Vector2i(960,640)
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();var sky:=Environment.new();sky.background_mode=Environment.BG_COLOR;sky.background_color=Color(0.025,0.035,0.055);sky.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;sky.ambient_light_color=Color.WHITE;sky.ambient_light_energy=0.5;env.environment=sky;world.add_child(env)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(16,14,23);camera.look_at(Vector3(0,3,0));camera.current=true
 var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(40,40);floor_mesh.mesh=plane
 var material:=StandardMaterial3D.new();material.albedo_color=Color(0.07,0.09,0.12);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;floor_mesh.material_override=material;floor_mesh.position.y=-0.2;world.add_child(floor_mesh)
 var player:=Player.new();world.add_child(player)
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]));var textures:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
 if not data is Dictionary or not textures is Dictionary or not player.configure(data,textures):quit(2);return
 var caption:=Label.new();caption.position=Vector2(18,14);caption.add_theme_font_size_override("font_size",20);root.add_child(caption)
 DirAccess.make_dir_recursive_absolute(args[2])
 var reports:Array=[]
 for f in [0.0,10.0,30.0,60.0,100.0]:
  if not player.seek(f):printerr("Seek failed");quit(1);return
  caption.text="EXPERIMENTAL AVFX PREVIEW | frame %d | %d particles\nOriginal renderer fidelity NOT verified"%[int(f),player.last_particles.size()]
  for _i in 3:await process_frame
  await RenderingServer.frame_post_draw
  var screenshot:=root.get_texture().get_image();var result:=screenshot.save_png(args[2].path_join("frame-%03d.png"%int(f)))
  if result!=OK:printerr("PNG save failed");quit(1);return
  reports.append(player.report())
 var output:=FileAccess.open(args[2].path_join("report.json"),FileAccess.WRITE);output.store_string(JSON.stringify(reports,"  "));output.close()
 print("AVFX_RENDER frames=%d"%reports.size());quit(0)
