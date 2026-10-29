extends SceneTree
const Composite=preload("res://scripts/asset_lab_composite.gd")
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args();var camera:=Camera3D.new();root.add_child(camera)
 var scene:=Composite.new();root.add_child(scene);scene.effects_enabled=false;scene.scene_enabled=false
 if scene.configure(args[0],camera)!=OK:printerr("TARGET_CONFIGURATION_FAILED");quit(1);return
 scene.eid=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
 var rows:Array=[];var failures:Array=[]
 for id in scene.record.actors:
  if not scene.record.actors[id].get("player",false):continue
  var track:Array=scene.record.tracks.get(id,[])
  if track.size()<4:failures.append({"missing_track":id});continue
  var times:Array=[track[1][0],track[int(track.size()/3)][0],track[int(track.size()*2/3)][0],track[-2][0],track[1][0]]
  var initial:Array=[]
  for index in times.size():
   var t:=float(times[index]);scene.clock=t;scene.bone_cache.clear();scene.player_attachment_provenance.clear()
   var points:Array=[]
   var family:String=scene.eid.byForm.player
   for binding in scene.eid.families[family].rows:
    var eid:=int(binding.id)
    var pose:Variant=scene.bone_pose(id,eid,t)
    if not pose is Transform3D:failures.append({"id":id,"eid":eid,"time":t,"diagnostics":scene.diagnostics.keys()});continue
    points.append({"eid":eid,"matrix":scene._matrix_array(pose)})
   if index==0:initial=points.duplicate(true)
   elif index==times.size()-1 and initial!=points:failures.append({"reverse_drift":id})
   var slot:Dictionary=scene.hidden_player_slots.get(id,{})
   if not slot.is_empty() and slot.root.is_visible_in_tree():failures.append({"rendered_player_body":id})
   rows.append({"id":id,"t":t,"points":points,"provenance":scene.player_attachment_provenance.get(id,{}).duplicate(true)})
 var result:={"status":"PASS" if failures.is_empty() else "FAIL","samples":rows,"failures":failures,"actual_player_race_or_pose_acceptance":false,"all96_acceptance":false}
 FileAccess.open(args[2],FileAccess.WRITE).store_string(JSON.stringify(result))
 print("TOP_HIDDEN_SOURCE_TARGET ",result.status," samples=",rows.size()," failure_count=",failures.size()," first_failures=",failures.slice(0,3))
 scene.dispose();scene.free();camera.free();quit(0 if failures.is_empty() else 1)
