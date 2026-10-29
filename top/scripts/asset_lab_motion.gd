# SPDX-License-Identifier: MIT
extends RefCounted
## Exact exported GLB channels, independent of engine AnimationPlayer interpolation.
## PAP action channels are model-space; resident clips remain hierarchy-local.
var document:Dictionary={}
var bytes:PackedByteArray
var binary_offset:=0
var accessors:Dictionary={}
var clips:Dictionary={}
var node_rest:Dictionary={}
var skeletons:Array=[]
var parents:Dictionary={}
var model:Node3D
var error:=""
func configure(path:String,root:Node3D)->bool:
 bytes=FileAccess.get_file_as_bytes(path)
 if bytes.size()<28 or bytes.decode_u32(0)!=0x46546c67:return false
 var length:=bytes.decode_u32(12)
 if length+28>bytes.size():return false
 var parsed:Variant=JSON.parse_string(bytes.slice(20,20+length).get_string_from_utf8())
 if not parsed is Dictionary or not parsed.get("nodes") is Array:return false
 document=parsed
 binary_offset=28+length;model=root
 for n in document.get("nodes",[]):
  node_rest[str(n.get("name",""))]={"translation":n.get("translation",[0,0,0]),"rotation":n.get("rotation",[0,0,0,1]),"scale":n.get("scale",[1,1,1])}
 for a in document.get("animations",[]):clips[str(a.name)]=a
 _walk(root)
 return true
func add_supplement(data:Variant)->void:
 if not data is Dictionary or not data.has("bones"):return
 var key:=-1;accessors[key]=PackedFloat32Array(data.times);var animation:={"samplers":[],"channels":[]}
 for bone in data.bones:
  var node_index:=-1
  for i in document.nodes.size():
   if document.nodes[i].get("name","")==bone.name:node_index=i;break
  if node_index<0:continue
  for path in ["translation","rotation","scale"]:
   key-=1;accessors[key]=PackedFloat32Array(bone[path])
   animation.samplers.append({"input":-1,"output":key,"interpolation":"LINEAR"})
   animation.channels.append({"sampler":animation.samplers.size()-1,"target":{"node":node_index,"path":path}})
 clips[str(data.name)]=animation
func _walk(n:Node)->void:
 if n is AnimationPlayer:n.stop();n.active=false
 if n is Skeleton3D:
  skeletons.append(n);var pp:Array=[]
  for i in n.get_bone_count():pp.append(n.get_bone_parent(i))
  parents[n.get_instance_id()]=pp
 for c in n.get_children():_walk(c)
func _access(index:int)->PackedFloat32Array:
 if accessors.has(index):return accessors[index]
 if index<0 or index>=document.get("accessors",[]).size():error="Invalid animation accessor";return PackedFloat32Array()
 var a:Dictionary=document.accessors[index]
 if int(a.get("componentType",0))!=5126 or a.has("sparse") or not str(a.get("type","")) in ["SCALAR","VEC3","VEC4"]:error="Unsupported animation accessor";return PackedFloat32Array()
 if int(a.get("bufferView",-1))<0 or int(a.bufferView)>=document.get("bufferViews",[]).size():error="Invalid animation buffer view";return PackedFloat32Array()
 var view:Dictionary=document.bufferViews[int(a.bufferView)]
 var width:int={"SCALAR":1,"VEC3":3,"VEC4":4}[str(a.type)]
 var start:=binary_offset+int(view.get("byteOffset",0))+int(a.get("byteOffset",0))
 var stride:=int(view.get("byteStride",width*4));var out:=PackedFloat32Array()
 if int(a.count)<1 or stride<width*4 or start<0 or start+(int(a.count)-1)*stride+width*4>bytes.size():error="Animation accessor bounds";return out
 for i in int(a.count):
  for j in width:out.append(bytes.decode_float(start+i*stride+j*4))
 accessors[index]=out;return out
func duration(clip:String)->float:
 if not clips.has(clip):return 0
 var result:=0.0
 for sampler in clips[clip].samplers:
  var times:=_access(int(sampler.input))
  if not times.is_empty():result=maxf(result,times[-1])
 return result
func sample(clip:String,seconds:float)->bool:
 if not clip.is_empty() and not clips.has(clip):return false
 var values:Dictionary={}
 for channel in (clips[clip].channels if not clip.is_empty() else []):
  var sam:Dictionary=clips[clip].samplers[int(channel.sampler)]
  var times:=_access(int(sam.input));var output:=_access(int(sam.output));var target:Dictionary=channel.target
  if times.is_empty() or not target.get("path","") in ["translation","rotation","scale"]:return false
  if int(target.get("node",-1))<0 or int(target.node)>=document.nodes.size():return false
  var name:String=document.nodes[int(target.node)].get("name","")
  if not node_rest.has(name):return false
  if not values.has(name):values[name]=node_rest[name].duplicate(true)
  var width:=4 if target.path=="rotation" else 3
  if output.size()!=times.size()*width:return false
  var lo:=0;var hi:=times.size()
  while lo<hi:
   var mid:=int((lo+hi)/2)
   if times[mid]<=seconds:lo=mid+1
   else:hi=mid
  var a:=clampi(lo-1,0,times.size()-1);var b:=mini(a+1,times.size()-1)
  var f:=0.0 if a==b or sam.get("interpolation","LINEAR")=="STEP" else clampf((seconds-times[a])/(times[b]-times[a]),0,1)
  if not sam.get("interpolation","LINEAR") in ["LINEAR","STEP"]:error="Unsupported source interpolation";return false
  if width==4:
   var qa:=Quaternion(output[a*4],output[a*4+1],output[a*4+2],output[a*4+3])
   var qb:=Quaternion(output[b*4],output[b*4+1],output[b*4+2],output[b*4+3]);var q:=qa.slerp(qb,f)
   values[name][target.path]=[q.x,q.y,q.z,q.w]
  else:
   var v:Array=[]
   for j in 3:v.append(lerpf(output[a*3+j],output[b*3+j],f))
   values[name][target.path]=v
 for sk in skeletons:
  var pp:Array=parents[sk.get_instance_id()]
  for i in sk.get_bone_count():
   var parent:=-1 if clip.begins_with("action_") else int(pp[i])
   if sk.get_bone_parent(i)!=parent:sk.set_bone_parent(i,parent)
   var name:=str(sk.get_bone_name(i));var v:Dictionary=values.get(name,node_rest.get(name,{}))
   if v.is_empty():continue
   var p:Array=v.translation;var s:Array=v.scale;var q:Array=v.rotation
   sk.set_bone_pose_position(i,Vector3(p[0],p[1],p[2]))
   sk.set_bone_pose_rotation(i,Quaternion(q[0],q[1],q[2],q[3]).normalized())
   sk.set_bone_pose_scale(i,Vector3(s[0],s[1],s[2]))
 return true
func report()->Dictionary:
 var rows:Array=[]
 for sk in skeletons:
  var bones:Dictionary={}
  for i in sk.get_bone_count():
   var t:Transform3D=sk.get_bone_global_pose(i)
   bones[str(sk.get_bone_name(i))]=[t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
  rows.append(bones)
 return {"skeletons":rows,"source_clips":clips.size(),"space_policy":"action model-space / resident local"}

