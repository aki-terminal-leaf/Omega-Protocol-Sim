extends SceneTree
const Preview=preload("res://scripts/scene_shader_preview.gd")
const Binding=preload("res://scripts/original_lightshaft.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label)
func _initialize()->void:call_deferred("test")
func test()->void:
 var watchdog=Timer.new();root.add_child(watchdog);watchdog.wait_time=12;watchdog.one_shot=true;watchdog.timeout.connect(func():quit(2));watchdog.start()
 var packed=load("res://scenes/scene_shader_preview.tscn")
 check(packed is PackedScene,"serialized standalone scene parses")
 if not packed is PackedScene:quit(1);return
 var p=packed.instantiate();root.add_child(p)
 await process_frame
 check(p.surfaces.size()==3,"three actual surfaces")
 for k in p.surfaces.size():
  var s=p.surfaces[k];var data=p.scene_data.models[k].surfaces[0];var a=s.mesh.surface_get_arrays(0)
  check(a[Mesh.ARRAY_VERTEX].size()==data.position.size(),"all vertices")
  for j in data.position.size():
   var v=data.position[j];check(a[Mesh.ARRAY_VERTEX][j]==Vector3(v[0],v[1],v[2]),"position")
   var normal=data.normal[j];var raw_normal:PackedFloat32Array=a[Mesh.ARRAY_CUSTOM0]
   for axis in 3:check(raw_normal[j*3+axis]==PackedFloat32Array([normal[axis]])[0],"exact custom source normals")
   var uv=data.uv[j];check(a[Mesh.ARRAY_TEX_UV][j]==Vector2(uv[0],uv[1]),"native UV retained")
   check(abs(a[Mesh.ARRAY_COLOR][j].a-data.color[j][3]/255.0)<0.000001,"source alpha")
  check(s.material_override is ShaderMaterial,"actual material")
  check(s.material_override.get_shader_parameter("original_world_offset")==Vector3(100,0,100),"offset uniform")
  for key in data.textures:
   var t=data.textures[key];var im=Image.new();check(im.load_png_from_buffer(FileAccess.get_file_as_bytes("res://data/"+t.png))==OK,"PNG decode")
   im.convert(Image.FORMAT_RGBA8);check(im.get_data()==FileAccess.get_file_as_bytes("res://data/"+t.rgba),"all original texture channels")
 p.select_scene(2);check(not p.playing and p.playhead==0,"select pauses zero")
 p.toggle_play();p._process(1.0);check(p.playhead==1.0,"one x")
 p.toggle_play();p._process(1.0);check(p.playhead==1.0,"pause")
 p.seek_to(0.25);check(p.surfaces[0].material_override.get_shader_parameter("source_clock")==0.00025,"reverse explicit clock")
 p.seek_to(10);p.toggle_play();check(p.playhead==0 and p.playing,"restart same selection")
 p._process(11);check(not p.playing and p.playhead==10 and p.selected==2,"stop no next")
 for pair in [[-2.5,-2],[-1.5,-2],[-0.5,0],[0.5,0],[1.5,2],[2.5,2]]:check(Binding.round_ne(pair[0])==pair[1],"ties even")
 # Texture row contract: direct ImageTexture retains top-to-bottom image data.
 # This is numerical upload evidence; GPU raster orientation is a separate gate.
 var image=Image.create(2,2,false,Image.FORMAT_RGBA8)
 image.set_pixel(0,0,Color(1,0,0,0.25));image.set_pixel(0,1,Color(0,0,1,0.75))
 var texture=ImageTexture.create_from_image(image)
 check(texture.get_image().get_pixel(0,0).r==1 and texture.get_image().get_pixel(0,1).b==1,"texture row orientation")
 for missing in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:
  var arrays=p.surfaces[0].mesh.surface_get_arrays(0);arrays[missing]=null
  var bad=ArrayMesh.new()
  var flags=0 if missing==Mesh.ARRAY_CUSTOM0 else Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
  bad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
  check(not Binding.mesh_contract(bad).ok,"missing vertex source channel rejected")
 var arrays=p.surfaces[0].mesh.surface_get_arrays(0);var packed_bytes=PackedByteArray();packed_bytes.resize(arrays[Mesh.ARRAY_VERTEX].size()*4);arrays[Mesh.ARRAY_CUSTOM0]=packed_bytes
 var bad=ArrayMesh.new();bad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA8_UNORM<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
 check(not Binding.mesh_contract(bad).ok,"quantized normal channel rejected")
 var invalid=Binding.attach(p.surfaces[0],{});check(not invalid.ok and p.surfaces[0].material_override==null and not p.surfaces[0].visible,"stale clear")
 print(JSON.stringify({"failures":failures,"headless_only":true}))
 p.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
