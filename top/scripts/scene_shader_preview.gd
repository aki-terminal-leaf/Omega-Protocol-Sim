extends Node3D
const Binding=preload("res://scripts/original_lightshaft.gd")
var playhead:float=0.0
var playing:bool=false
var selected:int=0
var scene_data:Dictionary
var surfaces:Array[MeshInstance3D]=[]
var status:Label
var camera:Camera3D
var root_path:String="res://data"
func _ready() -> void:
 camera=Camera3D.new();add_child(camera);camera.position=Vector3(300,240,550);camera.look_at(Vector3(0,180,0));camera.far=4000
 camera.current=true
 var canvas=CanvasLayer.new();add_child(canvas)
 var box=VBoxContainer.new();canvas.add_child(box)
 status=Label.new();box.add_child(status)
 var select=OptionButton.new();select.add_item("All three source shafts");select.add_item("Shaft 1");select.add_item("Shaft 2");select.add_item("Shaft 3");select.item_selected.connect(select_scene);box.add_child(select)
 var play=Button.new();play.text="Play / Pause (1x)";play.pressed.connect(toggle_play);box.add_child(play)
 var seek=HSlider.new();seek.min_value=0;seek.max_value=10;seek.step=0.01;seek.custom_minimum_size.x=420;seek.value_changed.connect(seek_to);box.add_child(seek)
 scene_data=JSON.parse_string(FileAccess.get_file_as_string(root_path+"/scene.json"))
 if scene_data.is_empty():return
 seek.max_value=scene_data.inspection.duration
 load_surfaces()
 seek_to(0)
func load_surfaces() -> void:
 for model in scene_data.models:
  for s in model.surfaces:
   var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
   var p=PackedVector3Array();var n=PackedVector3Array();var uv=PackedVector2Array();var colors=PackedColorArray()
   for v in s.position:p.append(Vector3(v[0],v[1],v[2]))
   var source_normals=PackedFloat32Array()
   for v in s.normal:
    n.append(Vector3(v[0],v[1],v[2]));source_normals.append_array(PackedFloat32Array(v))
   for v in s.uv:uv.append(Vector2(v[0],v[1]))
   for v in s.color:colors.append(Color(v[0]/255.0,v[1]/255.0,v[2]/255.0,v[3]/255.0))
   arrays[Mesh.ARRAY_VERTEX]=p;arrays[Mesh.ARRAY_NORMAL]=n;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(s.indices)
   arrays[Mesh.ARRAY_CUSTOM0]=source_normals
   var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
   var node=MeshInstance3D.new();node.mesh=mesh;add_child(node);surfaces.append(node)
   # Shader transforms vertices explicitly, so culling bounds also cover source placement.
   node.extra_cull_margin=2000
   var i=[[1,0,0,100],[0,1,0,model.y],[0,0,1,100],[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,scene_data.inspection.i6w],scene_data.inspection.i7rgb+[0],[0,0,0,0],[0,0,0,0]]
   var c={"M":s.M,"I":i,"camera_cb2":camera.global_basis.z,"original_world_offset":Vector3(100,0,100),"common3x":scene_data.inspection.common3x,"source_clock":scene_data.inspection.clock_origin,"inspection_exposure":scene_data.inspection.exposure,"provenance":"INSPECTION_FIXTURE"}
   for pair in [["sampler0","557626425"],["sampler1","1446741167"]]:
    var im=Image.new();var err=im.load_png_from_buffer(FileAccess.get_file_as_bytes(root_path+"/"+s.textures[pair[1]].png))
    if err==OK:c[pair[0]]=ImageTexture.create_from_image(im)
   var diagnostic=Binding.attach(node,c)
   if not diagnostic.ok:push_error(JSON.stringify(diagnostic))
func select_scene(index:int) -> void:
 selected=index;playing=false;seek_to(0)
 for k in surfaces.size():surfaces[k].visible=selected==0 or selected==k+1
func toggle_play() -> void:
 if playhead>=float(scene_data.inspection.duration):seek_to(0)
 playing=not playing
func seek_to(value:float) -> void:
 if scene_data.is_empty() or not is_finite(value):return
 playhead=clampf(value,0,float(scene_data.inspection.duration))
 var clock_value:float=scene_data.inspection.clock_origin+playhead*scene_data.inspection.clock_rate
 for node in surfaces:
  if node.material_override:node.material_override.set_shader_parameter("source_clock",clock_value)
 if status:status.text="INSPECTION_FIXTURE | %.3fs | source clock %.6f\nChosen additive/exposure; native blend/depth/clock unknown" % [playhead,clock_value]
func _process(delta:float) -> void:
 if playing:
  seek_to(playhead+delta)
  if playhead>=float(scene_data.inspection.duration):playing=false
