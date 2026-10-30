extends SceneTree
var report: Dictionary={"status":"BLOCKED","models":[],"color_mapping":"normalized byte RGBA; direct Mesh readback","uv2_mapping":"TEXCOORD_1 to ARRAY_TEX_UV2","raster_acceptance":false}
var destination: String
func _initialize() -> void:
 call_deferred("run")
func fail(message: String) -> void:
 report["blocker"]=message
 FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 printerr(message)
 quit(1)
func collect(node: Node, meshes: Array, skeletons: Array) -> void:
 if node is MeshInstance3D: meshes.append(node)
 if node is Skeleton3D: skeletons.append(node)
 for child in node.get_children(): collect(child,meshes,skeletons)
func run() -> void:
 var args=OS.get_cmdline_user_args()
 destination=args[1]
 if Engine.get_version_info().string!="4.7.2-stable (official)":
  if Engine.get_version_info().major!=4 or Engine.get_version_info().minor!=7 or Engine.get_version_info().patch!=2: fail("engine version"); return
 var cases=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if not cases is Array or cases.size()!=4: fail("missing cases"); return
 for entry in cases:
  var r: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(entry.result))
  var base: String=entry.result.get_base_dir()
  var state=GLTFState.new()
  var document=GLTFDocument.new()
  if document.append_from_file(r.glb,state)!=OK: fail("GLTFDocument import"); return
  var scene=document.generate_scene(state)
  if scene==null: fail("generate scene"); return
  root.add_child(scene)
  var meshes: Array=[]
  var skeletons: Array=[]
  collect(scene,meshes,skeletons)
  if meshes.size()!=r.parts.size() or skeletons.size()!=1: fail("mesh/skeleton identities"); return
  var skel: Skeleton3D=skeletons[0]
  if skel.get_bone_count()!=r.bone_names.size(): fail("bone count"); return
  for name in r.bone_names:
   if skel.find_bone(name)<0: fail("bone identity "+name); return
  var baseline_state=GLTFState.new()
  var baseline_document=GLTFDocument.new()
  if baseline_document.append_from_file(r.baseline_glb,baseline_state)!=OK: fail("baseline import"); return
  var baseline_scene=baseline_document.generate_scene(baseline_state)
  if baseline_scene==null: fail("baseline scene"); return
  root.add_child(baseline_scene)
  var baseline_meshes: Array=[]
  var baseline_skeletons: Array=[]
  collect(baseline_scene,baseline_meshes,baseline_skeletons)
  if baseline_skeletons.size()!=1: fail("baseline skeleton"); return
  for i in skel.get_bone_count():
   if skel.get_bone_name(i)!=baseline_skeletons[0].get_bone_name(i) or skel.get_bone_parent(i)!=baseline_skeletons[0].get_bone_parent(i) or skel.get_bone_rest(i)!=baseline_skeletons[0].get_bone_rest(i): fail("rest/hierarchy changed"); return
  var checked: Array=[]
  var vertices: int=0
  var max_color: float=0.0
  var max_uv: float=0.0
  for part in r.parts:
   var matches=meshes.filter(func(x): return str(x.name)==part.name)
   if matches.size()!=1: fail("exact mesh name "+part.name); return
   var mesh: MeshInstance3D=matches[0]
   if mesh.skin==null or mesh.get_node_or_null(mesh.skeleton)!=skel or mesh.mesh.get_surface_count()!=1: fail("skin/surface binding"); return
   var arrays: Array=mesh.mesh.surface_get_arrays(0)
   var originals=baseline_meshes.filter(func(x): return str(x.name)==part.name)
   if originals.size()!=1: fail("baseline part identity"); return
   var old_arrays: Array=originals[0].mesh.surface_get_arrays(0)
   for attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_INDEX]:
    if arrays[attribute]!=old_arrays[attribute]: fail("existing imported attribute changed "+str(attribute)); return
   var colors=arrays[Mesh.ARRAY_COLOR]
   var uvs=arrays[Mesh.ARRAY_TEX_UV2]
   var oracle=FileAccess.get_file_as_bytes(base.path_join(part.oracle))
   if oracle.size()!=int(part.vertices)*12 or colors==null or uvs==null or colors.size()!=int(part.vertices) or uvs.size()!=int(part.vertices): fail("missing vertex arrays"); return
   for i in int(part.vertices):
    var expected=Color(float(oracle[i*12])/255.0,float(oracle[i*12+1])/255.0,float(oracle[i*12+2])/255.0,float(oracle[i*12+3])/255.0)
    var actual: Color=colors[i]
    var ce: float=maxf(maxf(absf(actual.r-expected.r),absf(actual.g-expected.g)),maxf(absf(actual.b-expected.b),absf(actual.a-expected.a)))
    max_color=maxf(max_color,ce)
    var uv=Vector2(oracle.decode_float(i*12+4),oracle.decode_float(i*12+8))
    var ue: float=maxf(absf(uv.x-uvs[i].x),absf(uv.y-uvs[i].y))
    max_uv=maxf(max_uv,ue)
    if ce>0.0000001 or ue>0.0000001: fail("vertex mapping mismatch %s vertex %s color %s uv %s"%[part.name,i,ce,ue]); return
   if arrays[Mesh.ARRAY_VERTEX].size()!=int(part.vertices) or arrays[Mesh.ARRAY_BONES].size()!=int(part.vertices)*8: fail("existing attribute cardinality"); return
   vertices+=int(part.vertices)
   checked.append(part.name)
  var bindings: Array=[]
  var nonopaque: int=0
  for material in r.materials:
   for tex in material.textures:
    var image=Image.new()
    if image.load_png_from_buffer(FileAccess.get_file_as_bytes(base.path_join(tex.png)))!=OK: fail("PNG decode"); return
    image.convert(Image.FORMAT_RGBA8)
    var raw=FileAccess.get_file_as_bytes(base.path_join(tex.rgba))
    if image.get_data()!=raw or image.get_width()!=int(tex.width) or image.get_height()!=int(tex.height): fail("PNG channel corruption "+tex.path); return
    bindings.append([material.path,tex.path,tex.sampler_id])
    nonopaque+=int(tex.nonopaque_alpha)
  report.models.append({"model":r.model,"parts":checked,"vertices":vertices,"bindings":bindings,"nonopaque_alpha":nonopaque,"max_color_error":max_color,"max_uv2_error":max_uv})
  baseline_scene.free()
  scene.free()
 report.status="PASS"
 FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 quit(0)
