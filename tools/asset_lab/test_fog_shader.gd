extends SceneTree
var failures:int=0
func _initialize() -> void:
 call_deferred("run_tests")
func check(value:bool,message:String) -> void:
 if not value:failures+=1;push_error(message)
func run_tests() -> void:
 var packed=load("res://scenes/fog_shader_preview.tscn") as PackedScene
 check(packed!=null,"serialized load")
 if packed==null:quit(1);return
 var preview=packed.instantiate();root.add_child(preview)
 await process_frame
 check(not preview.playing and preview.playhead==0,"first state paused")
 check(not preview.surfaces.is_empty(),"original surfaces")
 for node in preview.surfaces:check(node.visible and node.material_override!=null,"material attached")
 preview.seek_to(8);preview.seek_to(2)
 for node in preview.surfaces:check(abs(node.material_override.get_shader_parameter("source_clock")-0.002)<0.000001,"reverse sourceclock")
 preview.select_scene(0);check(not preview.playing and preview.playhead==0,"select pauses zero")
 preview.toggle_play();preview._process(11);check(not preview.playing and preview.playhead==10,"stop chosen end")
 var node=preview.surfaces[0]
 var binding=load("res://scripts/original_verticalfog.gd")
 var valid:Dictionary=preview.scene_data.fixture.duplicate(true)
 for j in 3:valid["sampler"+str(j)]=node.material_override.get_shader_parameter("sampler"+str(j))
 for key in ["camera_cb","common_cb","fog_cb","parameter_cb","material_cb","instance_cb","sampler0","sampler1","sampler2","source_clock","native_sv_position","provenance","branch"]:
  check(binding.attach(node,valid).ok,"reattach valid")
  var bad=valid.duplicate(true);bad.erase(key)
  check(not binding.attach(node,bad).ok and not node.visible and node.material_override==null,"missing/stale "+key)
 for key in ["camera_cb","common_cb","fog_cb","parameter_cb"]:
  var bad=valid.duplicate(true);bad[key][0][0]=NAN
  check(not binding.attach(node,bad).ok and not node.visible,"nonfinite "+key)
  bad=valid.duplicate(true);bad[key].pop_back()
  check(not binding.attach(node,bad).ok,"cardinality "+key)
 var malformed=valid.duplicate(true);malformed.source_clock=INF
 check(not binding.attach(node,malformed).ok,"nonfinite clock")
 var bad_image=Image.create(1,1,false,Image.FORMAT_RGBAF);bad_image.set_pixel(0,0,Color(NAN,0,0,1))
 malformed=valid.duplicate(true);malformed.sampler2=ImageTexture.create_from_image(bad_image)
 check(not binding.attach(node,malformed).ok and not node.visible,"nonfinite texture")
 # GDScript float is f64; GPU buffers/Vector4 and float uniforms are f32.
 for key in binding.COUNTS:
  var bad=valid.duplicate(true);bad[key][0][0]=1e39
  check(not binding.attach(node,bad).ok and not node.visible and node.material_override==null,"f32 overflow "+key)
 for key in ["source_clock","inspection_exposure"]:
  var bad=valid.duplicate(true);bad[key]=1e39
  check(not binding.attach(node,bad).ok and not node.visible and node.material_override==null,"f32 overflow scalar "+key)
 for key in ["render_origin","native_sv_position"]:
  var bad=valid.duplicate(true);bad[key][0]=1e39
  check(not binding.attach(node,bad).ok and not node.visible and node.material_override==null,"f32 overflow vector "+key)
 var integer_scalar=valid.duplicate(true);integer_scalar.source_clock=1
 check(binding.attach(node,integer_scalar).ok,"int source clock accepted with explicit float upload")
 check(node.material_override.get_shader_parameter("source_clock") is float,"typed scalar upload")
 var triangle_mesh=node.mesh
 var points=ArrayMesh.new();var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2]);points.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS,arrays)
 node.mesh=points
 check(not binding.attach(node,valid).ok and not node.visible and node.material_override==null,"point primitive rejected")
 node.mesh=triangle_mesh
 var result=binding.attach(node,{})
 check(not result.ok and not node.visible and node.material_override==null,"stale failclosed")
 print("FOG_SERIALIZED_SCENE_AND_CLOCK_PASS; HEADLESS_NOT_RASTER")
 preview.queue_free();await process_frame;quit(1 if failures else 0)
