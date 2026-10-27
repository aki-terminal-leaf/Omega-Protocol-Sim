# SPDX-License-Identifier: MIT
extends SceneTree
const Official=preload("res://scripts/official_models.gd")
const Pose=preload("res://scripts/source_animation.gd")
var checks:=0
var failures:=0
var max_error:=0.0
var evidence:Array=[]
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;print("SOURCE_ANIMATION FAIL ",message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/official/source/catalog.json"))
 for form in ["beetle","male","female","final","alpha","arm_left","arm_right","male_p5","female_p5"]:
  var keys:Array=catalog.animations.keys().filter(func(k):return str(k).begins_with(form+"|"))
  if keys.is_empty():continue
  var model:=Official.instantiate(form);root.add_child(model);await process_frame
  model.position=Vector3(5,2,-4);model.rotation_degrees.y=39
  var spec:Dictionary=catalog.animations[keys[0]]
  var data:=FileAccess.get_file_as_bytes(spec.file).decompress_dynamic(32*1024*1024,FileAccess.COMPRESSION_GZIP)
  var sample:Dictionary=JSON.parse_string(data.get_string_from_utf8())
  var clip:Dictionary=sample.animations[0]
  var binding:=Pose.configure(model,sample)
  check(binding.get("ok",false),form+" configure "+str(binding.get("error","")))
  if not binding.get("ok",false):model.queue_free();await process_frame;continue
  var times:Array=clip.times
  for index in [0,times.size()/2,times.size()-1,0]:
   var frame_index:=int(index);check(Pose.seek(binding,float(times[frame_index])),form+" seek")
   await process_frame
   var skel:Skeleton3D=binding.skeleton
   var convert:Transform3D=binding.frame_to_skeleton.affine_inverse()
   for bi in sample.bones.size():
    var bone:Dictionary=clip.frames[frame_index][bi]
    var t:Array=bone.translation;var q:Array=bone.rotation;var s:Array=bone.scale
    var want:=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized())*Basis.from_scale(Vector3(s[0],s[1],s[2])),Vector3(t[0],t[1],t[2]))
    var actual:=convert*skel.get_bone_global_pose(skel.find_bone(sample.bones[bi].name))
    var error:=maxf(actual.origin.distance_to(want.origin),maxf(actual.basis.x.distance_to(want.basis.x),maxf(actual.basis.y.distance_to(want.basis.y),actual.basis.z.distance_to(want.basis.z))))
    max_error=maxf(max_error,error);check(error<0.0001,form+" raw MODEL bone "+str(sample.bones[bi].name)+" error "+str(error))
  var resident:=Official.find_animation(model)
  Pose.clear(binding);await process_frame
  check(not binding.active and not binding.ok,form+" clear")
  check(resident==null or resident.active,form+" resident restored")
  evidence.append({"form":form,"sample":spec.file,"bones":sample.bones.size(),"clip":clip.name})
  model.queue_free();await process_frame
 var result:Dictionary={"checks":checks,"failures":failures,"max_model_matrix_error":max_error,"cases":evidence,"scope":"actual imported Godot skeleton global overrides vs original model-space PAP; non-identity world transform and reverse seek; not visual fidelity"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--proof="):var f=FileAccess.open(arg.trim_prefix("--proof="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ")+"\n")
 print("SOURCE_ANIMATION_RESULT ",JSON.stringify(result));quit(1 if failures else 0)
