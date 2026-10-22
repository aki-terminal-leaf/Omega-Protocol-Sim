# SPDX-License-Identifier: MIT
extends SceneTree
const Stage=preload("res://scripts/avfx_mesh_stage.gd")
const Player=preload("res://scripts/avfx_player.gd")
var checks:=0
var failures:=0
var originals:=0
var original_vertices:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func fixture()->Dictionary:
 return {"vertices":[
  {"position":[-1.,-1.,0.,1.],"color":[255,128,0,64],"uv":[[0.,0.],[.125,.25],[.5,.75],[1.5,-.5]]},
  {"position":[1.,-1.,0.,1.],"color":[0,255,128,255],"uv":[[1.,0.],[.375,.5],[.625,.875],[-2.,3.]]},
  {"position":[0.,1.,0.,1.],"color":[128,0,255,128],"uv":[[.5,1.],[.625,.75],[.75,1.],[-.25,.125]]}],"triangles":[[0,1,2]]}
func verify(source:Dictionary,label:String,expected:Dictionary={})->void:
 var result:=Stage.create(source);check(result.status=="source_geometry",label+" create")
 if result.status!="source_geometry":return
 var mesh:Mesh=result.mesh;check(mesh.get_surface_count()==1,label+" surface")
 var arrays:=mesh.surface_get_arrays(0)
 var uv23:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
 check(uv23.size()==source.vertices.size()*4,label+" all custom UV elements")
 if uv23.size()!=source.vertices.size()*4:return
 var valid:=true
 for i in source.vertices.size():
  var row:Dictionary=source.vertices[i]
  var pos:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var color:Color=arrays[Mesh.ARRAY_COLOR][i]
  valid=valid and pos==Vector3(row.position[0],row.position[1],row.position[2])
  valid=valid and arrays[Mesh.ARRAY_TEX_UV][i]==Vector2(row.uv[0][0],row.uv[0][1]) and arrays[Mesh.ARRAY_TEX_UV2][i]==Vector2(row.uv[1][0],row.uv[1][1])
  for n in 4:valid=valid and uv23[4*i+n]==PackedFloat32Array([row.uv[2+n/2][n%2]])[0]
  for n in 4:valid=valid and absf(color[n]-row.color[n]/255.0)<0.000001
 if not expected.is_empty():
  for slot in ["uv0","uv1","uv23"]:
   var packed:PackedByteArray=uv23.to_byte_array() if slot=="uv23" else arrays[Mesh.ARRAY_TEX_UV if slot=="uv0" else Mesh.ARRAY_TEX_UV2].to_byte_array()
   check(packed==Marshalls.base64_to_raw(expected[slot]),label+" bit-exact raw source "+slot)
 check(valid,label+" exact source XYZ/RGBA/four UVs")
 var expected_indices:=PackedInt32Array()
 for triangle in source.triangles:
  for index in triangle:expected_indices.append(int(index))
 check(arrays[Mesh.ARRAY_INDEX]==expected_indices,label+" source winding")
 var ref:WeakRef=weakref(mesh);mesh=null;result.clear();check(ref.get_ref()==null,label+" released mesh")
func _initialize()->void:call_deferred("run")
func run()->void:
 verify(fixture(),"synthetic")
 for mode in ["uv_count","uv_nan","color_fraction","color_range","position_nan","index_fraction","index_range","empty"]:
  var source:=fixture()
  match mode:
   "uv_count":source.vertices[0].uv.pop_back()
   "uv_nan":source.vertices[0].uv[2][0]=NAN
   "color_fraction":source.vertices[0].color[0]=0.5
   "color_range":source.vertices[0].color[0]=256
   "position_nan":source.vertices[0].position[3]=INF
   "index_fraction":source.triangles[0][0]=0.5
   "index_range":source.triangles[0][0]=3
   "empty":source.vertices=[]
  check(Stage.create(source).status=="unsupported","reject "+mode)
 var player:=Player.new();root.add_child(player)
 player.configure({"schema":1,"groups":{"Ptcl":[{"data":{"MdNo":[0]}}]},"models":[fixture()]})
 var mesh:Mesh=player._mesh({"index":0,"kind":5});var ref:WeakRef=weakref(mesh)
 check(mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2].size()==3,"preview player retains UV2")
 check(mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0].size()==12,"preview player retains UV3/4")
 mesh=null;player.reset();check(ref.get_ref()==null,"preview reset releases all mesh channels");player.free()
 var args:=OS.get_cmdline_user_args()
 var expected:Dictionary={}
 if args.size()>1:expected=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
 if not args.is_empty():
  var folder:=DirAccess.open(args[0]);check(folder!=null,"original directory")
  if folder!=null:
   var files:=folder.get_files();check(files.size()<=64,"bounded original fixture corpus")
   for file in files:
    if not file.ends_with(".preview.json"):continue
    var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join(file)))
    var model_index:=-1
    for source in document.get("models",[]):
     model_index+=1
     if source.vertices.is_empty() or source.triangles.is_empty():continue
     verify(source,file+"/"+str(originals),expected[file][model_index] if expected.has(file) else {});originals+=1;original_vertices+=source.vertices.size()
 print("AVFX_MESH_STAGE checks=%d failures=%d original_models=%d original_vertices=%d"%[checks,failures,originals,original_vertices]);quit(1 if failures else 0)
