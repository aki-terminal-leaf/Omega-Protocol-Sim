# SPDX-License-Identifier: MIT
extends "res://tests/avfx_player_color_stage_render.gd"
## All tested particles are configured and drawn by the actual preview Player.
var state_plan:Dictionary={}
var state_texture:Texture2D
func bind_player(player:Node3D,values:Dictionary,factor:Color,wrap:="clamp",cc:=0.0,shift:=0.0)->void:
 player.reset()
 var d:=document()
 for field in values:d.groups.Ptcl[0].values[field]=values[field]
 check(player.configure(d),"state configure")
 active_context={"samples":[{"texture":state_texture,"filter":"nearest","wrap":wrap,"uv_source":0,"source_uv_index":0,"uv_row0":Vector3(1,0,shift),"uv_row1":Vector3(0,1,0),"decoded_samples":true},null,null,null],"calculate_color":cc,"calculate_alpha":0.0,"common_factor":factor,"model_fresnel_included":false}
 check(player.configure_color_stage_bindings({0:{"plan":state_plan,"context_provider":Callable(self,"provide")}}),"state binding")
 check(player.seek(5),"state seek")
func expect_pixel(got:Color,want:Color,label:String)->void:
 var error:=maxf(absf(got.r-want.r),maxf(absf(got.g-want.g),absf(got.b-want.b)))
 check(error<0.015,label+" got="+str(got)+" want="+str(want))
 snapshots.append({"label":label,"got":[got.r,got.g,got.b],"expected":[want.r,want.g,want.b],"error":error})
func run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:quit(2);return
 var fixtures:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 for fixture in fixtures:
  if fixture.plan.review_equation=="shape1":state_plan=fixture.plan;break
 if state_plan.is_empty():quit(2);return
 root.size=Vector2i(320,240)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;world.add_child(environment)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.;camera.position=Vector3(0,0,10);camera.look_at(Vector3.ZERO);camera.current=true
 var front:=Player.new();world.add_child(front)
 var back:=Player.new();world.add_child(back);back.position.z=-1.
 var image:=Image.create(2,1,false,Image.FORMAT_RGBA8);image.set_pixel(0,0,Color.RED);image.set_pixel(1,0,Color.BLUE)
 state_texture=ImageTexture.create_from_image(image);image=null
 for probe in [[0,Color.WHITE,Color(1,0,0,.5),Color(1,.5,.5)],[1,Color(0,1,1),Color.RED,Color.BLACK],[2,Color(0,1,1),Color.RED,Color.WHITE],[3,Color.WHITE,Color.RED,Color(0,1,1)]]:
  environment.environment.background_color=probe[1]
  bind_player(front,{"RMT":probe[0]},probe[2])
  expect_pixel(await pixels(),probe[3],"actual player blend "+str(probe[0]))
 environment.environment.background_color=Color.BLACK
 for cull in [1,2]:
  bind_player(front,{"CulT":cull},Color.RED)
  expect_pixel(await pixels(),Color.BLACK if cull==1 else Color.RED,"actual player cull "+str(cull))
 bind_player(front,{"DsDw":1},Color.RED)
 bind_player(back,{"DwPr":1},Color.BLUE)
 expect_pixel(await pixels(),Color.RED,"depth write blocks later farther draw")
 bind_player(back,{"DwPr":1,"DsDt":0},Color.BLUE)
 expect_pixel(await pixels(),Color.BLUE,"disabled depth test permits farther draw")
 bind_player(front,{"DsDw":0},Color.RED)
 bind_player(back,{"DwPr":1},Color.BLUE)
 expect_pixel(await pixels(),Color.BLUE,"disabled depth write permits farther draw")
 bind_player(front,{"DsDw":1},Color(1,0,0,.002))
 expect_pixel(await pixels(),Color.BLUE,"discard precedes depth write")
 back.reset()
 for wrap in ["repeat","clamp"]:
  bind_player(front,{},Color.WHITE,wrap,1.,.75)
  expect_pixel(await pixels(),Color.RED if wrap=="repeat" else Color.BLUE,"actual player shifted UV "+wrap)
 bind_player(front,{},Color.RED)
 var material:ShaderMaterial=front.draws.values()[0].material_override
 var shader:Shader=material.shader
 expect_pixel(await pixels(),Color.RED,"animated factor before")
 active_context.common_factor=Color.BLUE
 check(front.seek(6),"animated seek")
 check(front.draws.values()[0].material_override==material and material.shader==shader,"animated seek preserves material and shader")
 expect_pixel(await pixels(),Color.BLUE,"animated factor after")
 active_context.calculate_color=1.;active_context.common_factor=Color.WHITE
 active_context.samples[0].uv_row0=Vector3(1,0,.75)
 check(front.seek(7),"animated controls and UV seek")
 expect_pixel(await pixels(),Color.BLUE,"animated controls and UV row reach framebuffer")
 var wr:WeakRef=weakref(state_texture);material=null;shader=null
 front.reset();back.reset();active_context.clear();provider_requests.clear();state_texture=null
 for _i in 4:await process_frame
 check(wr.get_ref()==null,"state texture released")
 world.free()
 DirAccess.make_dir_recursive_absolute(args[1])
 var out:=FileAccess.open(args[1].path_join("player-state-pixels.json"),FileAccess.WRITE)
 out.store_string(JSON.stringify({"checks":checks,"failures":failures,"pixels":snapshots,"original_game_equivalence":false},"  "));out.close()
 print("AVFX_PLAYER_STATE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
