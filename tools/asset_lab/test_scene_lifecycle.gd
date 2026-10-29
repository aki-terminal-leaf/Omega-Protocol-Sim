# SPDX-License-Identifier: MIT
extends SceneTree
## Synthetic, static visual lifecycle only; no original media or native rules.
const Composite=preload("res://scripts/asset_lab_composite.gd")
class Fixture:
 extends "res://scripts/asset_lab_composite.gd"
 var fixture:Dictionary={}
 # Exercise real configure/dispose without external JSON or original media.
 func _json(key:String)->Dictionary:return fixture.get(key,{}).duplicate(true)

var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func matrix(x:float=0)->Array:return [1,0,0,0,0,1,0,0,0,0,1,0,x,0,0,1]
func row(key:String,x:float=0,asset:String="box")->Dictionary:
 return {"key":key,"asset":asset,"worldMatrix":matrix(x)}
func meshes(node:Node)->int:
 var count:=0
 if node is MeshInstance3D and node.is_visible_in_tree():count+=1
 for child in node.get_children():count+=meshes(child)
 return count
func packed_box()->PackedScene:
 var model:=Node3D.new()
 var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();model.add_child(mesh);mesh.owner=model
 var packed:=PackedScene.new();check(packed.pack(model)==OK,"pack real BoxMesh")
 model.free();return packed
func run()->void:
 var scene:=Fixture.new();root.add_child(scene)
 var boss:=row("boss",9);boss.source={"rootLayer":"p1_boss"}
 var filtered_floor:=row("filtered_floor",10);filtered_floor.source={"rootLayer":"p1_boss"}
 scene.fixture={
  "manifest":{"native_assets":{}},"motion-plan":{"actors":{}},
  "record":{"tracks":{},"actors":{},"phase_markers":[{"t":0,"id":1},{"t":100,"id":2},{"t":200,"id":3},{"t":300,"id":4}]},
  "scene-data":{"phases":{
   "1":{"nodes":[row("one",1),boss],"floor_nodes":[row("floor_one",-1)]},
   "2":{"nodes":[row("two",2),boss],"floor_nodes":[row("floor_two",-2),filtered_floor]},
   "3":{"nodes":[row("missing",0,"absent")]},
   "4":{"nodes":[]}}}}
 check(scene.configure("user://scene_lifecycle_nonexistent",null)==OK,"configure synthetic fixture")
 scene.effects_enabled=false;scene.source_window=Vector2(0,1000)
 scene.prototypes.box=packed_box()
 check(scene.seek(0) and meshes(scene)==3,"P1 includes boss and floor")
 var first:Node3D=scene.scene_root
 var first_mesh:Node=first.get_child(0).get_child(0)
 check(scene.seek(50) and scene.scene_root==first and first.get_child(0).get_child(0)==first_mesh,"successful same phase reuses real instances")
 scene.scene_enabled=false
 check(scene.seek(150) and meshes(scene)==0,"disable across phases hides all meshes")
 check(scene.report().phase==2,"disabled report follows clock")
 scene.scene_enabled=true
 check(scene.seek(150) and meshes(scene)==2,"reenable builds P2 and floor, filters p1_boss")
 check(not is_instance_valid(first),"previous phase root freed")
 check(scene.scene_root.get_node_or_null("boss")==null and scene.scene_root.get_node_or_null("filtered_floor")==null,"P2 filter applies to nodes and floors")
 check(scene.scene_root.get_node("two").position==Vector3(2,0,0),"P2 transform matches absolute selection")
 var second:Node3D=scene.scene_root
 scene.scene_enabled=false;scene.seek(150)
 check(meshes(scene)==0,"same phase disable uses tree visibility")
 scene.scene_enabled=true;scene.seek(150)
 check(scene.scene_root==second and meshes(scene)==2,"same phase toggle restores cached instances")
 check(scene.seek(0) and meshes(scene)==3 and scene.scene_root.get_node("one").position==Vector3(1,0,0),"reverse seek restores P1 geometry and transform")
 scene.scene_enabled=false;scene.seek(150);scene.seek(0);scene.scene_enabled=true
 check(scene.seek(0) and meshes(scene)==3,"disabled forward and reverse restore matching phase")
 check(not scene.seek(250) and meshes(scene)==0,"failed load removes previous phase geometry")
 var problems:Dictionary=scene.diagnostics.duplicate()
 check(problems.has("missing_glb/absent"),"failed load explicit diagnostic")
 for tick in [250,251,299]:
  check(not scene.seek(tick) and scene.diagnostics==problems and meshes(scene)==0,"repeated failed load remains failure at "+str(tick))
 scene.scene_enabled=false;scene.seek(250);scene.scene_enabled=true
 check(not scene.seek(250) and scene.diagnostics==problems,"failure survives disabled same phase toggle")
 check(scene.seek(0) and scene.diagnostics.is_empty(),"valid reverse phase clears unrelated failure")
 # Each bad matrix occupies a fresh cache build; all 16 entries are validated.
 var invalid:Array=[[1,2],"not an array"]
 for component in range(16):
  var nonfinite:=matrix();nonfinite[component]=NAN;invalid.append(nonfinite)
 for value in [INF,-INF,"bad",true,null]:
  var malformed:=matrix();malformed[12]=value;invalid.append(malformed)
 for component in [3,7,11,15]:
  var perspective:=matrix();perspective[component]=2;invalid.append(perspective)
 var overflow:=matrix();overflow[12]=1.0e100;invalid.append(overflow)
 for index in invalid.size():
  scene.seek(0)
  var bad:=row("bad");bad.worldMatrix=invalid[index]
  scene.scene_data.phases["4"].nodes=[bad]
  check(not scene.seek(350) and meshes(scene)==0 and scene.diagnostics.has("invalid_source_scene_matrix/bad"),"reject malformed matrix "+str(index))
  check(not scene.seek(351) and scene.diagnostics.has("invalid_source_scene_matrix/bad"),"cached matrix failure "+str(index))
 check(scene.seek(0) and meshes(scene)==3,"valid phase after matrix failures")
 var old:Node3D=scene.scene_root
 scene.dispose()
 check(not is_instance_valid(old) and meshes(scene)==0 and scene.scene_root==null,"dispose removes geometry")
 check(not scene.seek(0) and scene.diagnostics.is_empty(),"disposed seek rejected")
 scene.fixture["scene-data"]={"phases":{"1":{"nodes":[row("replacement",7)]}}}
 check(scene.configure("user://scene_lifecycle_nonexistent",null)==OK,"reconfigure same phase")
 scene.prototypes.box=packed_box();scene.source_window=Vector2(0,1000)
 check(scene.seek(0) and meshes(scene)==1 and scene.scene_root.get_node("replacement").position==Vector3(7,0,0),"reconfigure invalidates geometry and failures")
 old=scene.scene_root
 check(scene.configure("user://scene_lifecycle_nonexistent",null)==OK and not is_instance_valid(old) and meshes(scene)==0,"configure disposes live cache")
 scene.prototypes.box=packed_box()
 check(scene.seek(0) and meshes(scene)==1,"live reconfigure rebuilds same report phase")
 scene.dispose();scene.free()
 print(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"scope":"synthetic static scene lifecycle","all96_accepted":false,"raster_acceptance":false}))
 quit(0 if failures.is_empty() else 1)
