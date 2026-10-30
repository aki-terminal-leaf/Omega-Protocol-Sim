extends Node3D
const Binding=preload("res://scripts/original_verticalfog.gd")
var playing:bool=false
var playhead:float=0.0
var scene_data:Dictionary={}
var surfaces:Array[MeshInstance3D]=[]
var status:Label
var slider:HSlider
func _ready() -> void:
 var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/scene.json"))
 if not parsed is Dictionary:push_error("missing source scene");return
 scene_data=parsed
 var camera=Camera3D.new();add_child(camera)
 var bounds=AABB();var first=true
 for s in scene_data.surfaces:
  for v in s.position:
   var p=Vector3(v[0],v[1],v[2])
   if first:bounds=AABB(p,Vector3.ZERO);first=false
   else:bounds=bounds.expand(p)
 var radius=maxf(bounds.size.length(),20.0)
 camera.position=bounds.get_center()+Vector3(0.65,0.55,0.85)*radius
 camera.look_at(bounds.get_center());camera.far=maxf(4000,radius*8);camera.near=0.1;camera.current=true
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.035,0.055,0.085);add_child(env)
 var canvas=CanvasLayer.new();add_child(canvas);var box=VBoxContainer.new();canvas.add_child(box)
 status=Label.new();box.add_child(status)
 var select=OptionButton.new();select.add_item("Original z3oe_a1_vfg01 | conditional AddLayer0 VS0/PS0");select.item_selected.connect(select_scene);box.add_child(select)
 var play=Button.new();play.text="Play / Pause (1x)";play.pressed.connect(toggle_play);box.add_child(play)
 slider=HSlider.new();slider.max_value=10;slider.step=0.001;slider.custom_minimum_size.x=600;slider.value_changed.connect(seek_to);box.add_child(slider)
 for s in scene_data.surfaces:
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);var positions=PackedVector3Array()
  for v in s.position:positions.append(Vector3(v[0],v[1],v[2]))
  arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(s.indices)
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var node=MeshInstance3D.new();node.mesh=mesh;node.extra_cull_margin=radius*4;add_child(node);surfaces.append(node)
  var c:Dictionary=scene_data.fixture.duplicate(true)
  for j in 3:
   var im=Image.new();var bytes=FileAccess.get_file_as_bytes("res://data/"+scene_data.fixture_textures[j].file)
   if im.load_png_from_buffer(bytes)==OK:c["sampler"+str(j)]=ImageTexture.create_from_image(im)
  var result=Binding.attach(node,c)
  if not result.ok:push_error(JSON.stringify(result))
 seek_to(0)
func select_scene(_index:int) -> void:
 playing=false;seek_to(0)
func toggle_play() -> void:
 if playhead>=10:return
 playing=not playing
func seek_to(value:float) -> void:
 if not is_finite(value):return
 playhead=clampf(value,0,10)
 for node in surfaces:
  if node.material_override:node.material_override.set_shader_parameter("source_clock",playhead*0.001)
 if slider:slider.set_value_no_signal(playhead)
 if status:status.text="INSPECTION_FIXTURE | paused/play 1x | %.3fs\nProcedural depth/sky/LUT; chosen blend/exposure/camera. Native environment unresolved."%playhead
func _process(delta:float) -> void:
 if playing:
  seek_to(playhead+delta)
  if playhead>=10:playing=false
