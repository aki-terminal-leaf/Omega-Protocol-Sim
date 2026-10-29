# SPDX-License-Identifier: MIT
extends Node3D
## Absolute original-record composition. No claim of complete encounter fidelity.
const Motion=preload("res://scripts/asset_lab_motion.gd")
const FX=preload("res://scripts/asset_lab_effect.gd")
const Lifetime=preload("res://scripts/asset_lab_lifetime.gd")
const Curves=preload("res://scripts/avfx_animation.gd")
var data_root:=""
var manifest:Dictionary={}
var record:Dictionary={}
var plan:Dictionary={}
var full:Dictionary={}
var scene_data:Dictionary={}
var weapons:Dictionary={}
var eid:Dictionary={}
var view:Camera3D
var clock:=0.0
var configured:=false
var effects_enabled:=true
# Preparation ownership is original; native launch/stop semantics remain unknown.
# Only isolated inspection may opt in, never normal unit playback or acceptance.
var provisional_precast_enabled:=false
var provisional_precast:Dictionary={}
var scene_enabled:=true
var diagnostics:Dictionary={}
var actor_slots:Dictionary={}
var prototypes:Dictionary={}
var motion_sources:Dictionary={}
var active_fx:Dictionary={}
var lifetime_cache:Dictionary={}
var wanted_fx:Dictionary={}
var lifecycle_state:Dictionary={}
var cues:Array=[]
var texture_paths:Dictionary={}
var packs:Dictionary={}
var precast_source_positions:Dictionary={}
var reconstructed_preparations:Dictionary={}
var omega_start:=INF
var hidden_helpers:Dictionary={}
var effective_windows:Dictionary={}
var scene_root:Node3D
var actor_root:Node3D
var effect_root:Node3D
var phase:=0
# Static visual cache identity is independent of the report clock.
var _scene_phase:=-1
var _scene_diagnostics:Dictionary={}
var _scene_asset_diagnostics:Dictionary={}
var _building_scene:=false
var _building_scene_asset:=""
var source_window:=Vector2.ZERO
var allowed_actions:Array=[]
var verified_stops:Dictionary={}
var cue_selection:Dictionary={}
var cue_selection_enabled:=false
var bone_cache:Dictionary={}
var external_bone_pose:Callable
var hidden_player_slots:Dictionary={}
var player_attachment_provenance:Dictionary={}
func _problem(reason:String)->void:
 diagnostics[reason]=true
 if _building_scene:
  _scene_diagnostics[reason]=true
  if not _building_scene_asset.is_empty():
   if not _scene_asset_diagnostics.has(_building_scene_asset):_scene_asset_diagnostics[_building_scene_asset]={}
   _scene_asset_diagnostics[_building_scene_asset][reason]=true
func _path(relative:String)->String:
 var clean:=relative.replace("\\","/")
 if clean.is_empty() or clean.is_absolute_path() or clean.contains(":") or ".." in clean.split("/"):
  _problem("rejected_asset_path/"+relative);return ""
 return data_root.path_join(clean).simplify_path()
func _json(name:String)->Dictionary:
 var path:=_path(name+".json")
 if path.is_empty() or not FileAccess.file_exists(path):_problem("missing_data/"+name);return {}
 var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not value is Dictionary:_problem("invalid_data/"+name);return {}
 return value
func configure(root:String,camera:Camera3D)->Error:
 dispose();data_root=root;view=camera
 manifest=_json("manifest");record=_json("record");plan=_json("motion-plan");full=_json("full-data");scene_data=_json("scene-data");weapons=_json("weapon-data")
 if FileAccess.file_exists(_path("attachment-data.json")):eid=_json("attachment-data")
 if not manifest.has("native_assets") or not plan.get("actors") is Dictionary or not record.has("tracks"):return ERR_INVALID_DATA
 if plan.actors.size()>256 or full.get("cues",[]).size()>8192:return ERR_OUT_OF_MEMORY
 actor_root=Node3D.new();actor_root.name="Original NPCs";add_child(actor_root)
 effect_root=Node3D.new();effect_root.name="Original source effects";add_child(effect_root)
 for id in plan.actors:
  if record.get("actors",{}).get(id,{}).get("friendly",false) or record.actors.get(id,{}).get("player",false):continue
  var holder:=Node3D.new();holder.name="Actor_"+str(id).replace(":","_");actor_root.add_child(holder)
  actor_slots[str(id)]={"root":holder,"rigs":{},"form":"","visible":false}
 _index_static_preparations()
 for event in record.get("events",[]):
  if event.get("type") in ["begincast","cast"] and int(event.get("a",0))==32789:omega_start=minf(omega_start,float(event.t))
 for path in full.get("textures",{}):texture_paths[path]=_path(str(manifest.native_assets[full.textures[path]].file))
 for path in weapons.get("textures",{}):texture_paths[path]=_path(str(manifest.native_assets[weapons.textures[path]].file))
 for cue in full.get("cues",[]):
  if not record.get("actors",{}).get(str(cue.get("source","")),{}).get("friendly",false):cues.append(cue.duplicate(true))
 for cue in full.get("bodyCues",[]):cues.append(cue.duplicate(true))
 _weapon_cues()
 for event in full.get("tether_events",[]):
  var path:String=full.get("channeling",{}).get(str(int(event.get("tetherID",0))),"")
  if path.is_empty():_problem("missing_channeling/"+str(event.get("tetherID")));continue
  var cue:={"key":"tether/"+str(int(event.event_index)),"source":str(event.s),"target":str(event.d),"start":event.t,"anchor":event.t,"path":path,"tetherID":event.tetherID,"ability":0,"recorded_end":event.get("end"),"lifecycle_basis":event.get("lifetime_status","")}
  cues.append(cue)
 cues.sort_custom(func(a,b):return str(a.key)<str(b.key) if float(a.start)==float(b.start) else float(a.start)<float(b.start))
 configured=true;return OK
func set_sample_window(start:float,end:float,actions:Array=[],stops:Dictionary={})->Error:
 if not is_finite(start) or not is_finite(end) or end<=start:return ERR_INVALID_PARAMETER
 for key in stops:
  if not stops[key] is Dictionary or not stops[key].has("time_ms") or str(stops[key].get("evidence","")).is_empty():return ERR_INVALID_DATA
  if not is_finite(float(stops[key].time_ms)) or stops[key].get("mode") not in ["release","kill"]:return ERR_INVALID_DATA
 var canonical_actions:Array=[]
 for action in actions:
  if typeof(action) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(action)) or float(int(action))!=float(action) or int(action)<0:return ERR_INVALID_DATA
  canonical_actions.append(int(action))
 source_window=Vector2(start,end);allowed_actions=canonical_actions;verified_stops=stops.duplicate(true);return OK
func select_cues(keys:Array)->Error:
 var known:Dictionary={}
 for cue in cues:known[str(cue.key)]=true
 var chosen:Dictionary={}
 for key in keys:
  if not key is String or not known.has(key):return ERR_INVALID_DATA
  chosen[key]=true
 cue_selection=chosen;cue_selection_enabled=true;return OK
func _own(node:Node,root:Node)->void:
 for child in node.get_children():child.owner=root;_own(child,root)
func _prototype(asset:String)->PackedScene:
 if prototypes.has(asset):return prototypes[asset]
 var spec:Dictionary=manifest.get("native_assets",{}).get(asset,{})
 if spec.get("kind")!="glb":_problem("missing_glb/"+asset);return null
 var path:=_path(str(spec.get("file","")))
 if path.is_empty():return null
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 if doc.append_from_file(path,state)!=OK:_problem("gltf_import/"+asset);return null
 var model:=doc.generate_scene(state)
 if model==null:_problem("gltf_scene/"+asset);return null
 var motion:=Motion.new()
 if not motion.configure(path,model):model.free();_problem("source_motion/"+asset);return null
 if asset.begins_with("female") and weapons.has("legClip"):motion.add_supplement(weapons.legClip)
 _background_materials(model,motion.document,asset);_own(model,model)
 var packed:=PackedScene.new()
 if packed.pack(model)!=OK:model.free();_problem("prototype_pack/"+asset);return null
 model.free();motion.skeletons.clear();motion.parents.clear();motion.model=null
 prototypes[asset]=packed;motion_sources[asset]=motion;return packed
func _background_materials(root:Node,doc:Dictionary,asset:String)->void:
 if not asset.begins_with("scene_"):return
 var unsupported:Dictionary={}
 for material in doc.get("materials",[]):
  var shader:String=material.get("extras",{}).get("original_shader","")
  if shader.contains("lightshaft") or shader.contains("verticalfog"):unsupported[str(material.get("name",""))]=true
 _hide_unsupported(root,unsupported)
func _hide_unsupported(node:Node,names:Dictionary)->void:
 if node is MeshInstance3D and node.mesh!=null:
  for i in node.mesh.get_surface_count():
   var material:Material=node.get_active_material(i)
   if material!=null and names.has(material.resource_name):node.visible=false;_problem("source_volumetric_shader/"+material.resource_name)
 for child in node.get_children():_hide_unsupported(child,names)
func _rig(slot:Dictionary,form:String,scale_value:float)->Dictionary:
 if slot.rigs.has(form):return slot.rigs[form]
 var packed:=_prototype(form)
 if packed==null:return {}
 var model:Node3D=packed.instantiate();slot.root.add_child(model);model.scale=Vector3.ONE*scale_value;model.visible=false
 var original:RefCounted=motion_sources[form];var sampler:=Motion.new()
 sampler.document=original.document;sampler.bytes=original.bytes;sampler.binary_offset=original.binary_offset;sampler.accessors=original.accessors;sampler.clips=original.clips;sampler.node_rest=original.node_rest;sampler.model=model;sampler._walk(model)
 var rig:={"root":model,"motion":sampler};slot.rigs[form]=rig;return rig
func _track(id:String,t:float,smooth:=true)->Variant:
 for row in precast_source_positions.get(id,[]):
  if float(row.start)<=t and t<=float(row.end):
   reconstructed_preparations[id]=row
   var point:Array=row.position
   return Transform3D(Basis(Vector3.UP,PI/2-float(point[2])/100),Vector3(point[0],0,point[1]))
 var rows:Array=record.get("tracks",{}).get(id,[])
 var lo:=0;var hi:=rows.size()
 while lo<hi:
  var mid:=int((lo+hi)/2)
  if float(rows[mid][0])<=t:lo=mid+1
  else:hi=mid
 if lo==0:
  for row in precast_source_positions.get(id,[]):
   if float(row.start)<=t and t<=float(row.end):
    reconstructed_preparations[id]=row
    var v:Array=row.position
    return Transform3D(Basis(Vector3.UP,PI/2-float(v[2])/100),Vector3(v[0],0,v[1]))
  return null
 var a:Array=rows[lo-1];var age:=t-float(a[0])
 if age>10000:return null
 var p:=Vector3(float(a[1]),0,float(a[2]));var heading:=float(a[3])
 if smooth and lo<rows.size():
  var b:Array=rows[lo];var dt:=float(b[0])-float(a[0]);var q:=Vector3(float(b[1]),0,float(b[2]))
  if dt>0 and dt<=1500 and p.distance_to(q)<=12*dt/1000:p=p.lerp(q,clampf(age/dt,0,1))
 return Transform3D(Basis(Vector3.UP,PI/2-heading/100),p)
func _index_static_preparations()->void:
 # These stationary LP apparatus casts expose coordinates at resolve, but
 # the source tether/begincast proves their earlier preparation window.
 # Preserve that reconstruction provenance; never label it a position packet.
 var waiting:Dictionary={}
 for event in record.get("events",[]):
  if int(event.get("a",0)) not in [31539,31540,31541]:continue
  var id:=str(event.get("s",""));var key:=id+"/"+str(event.a)
  if not plan.actors.has(id):continue
  if event.get("type")=="begincast" and event.get("castSuccessful",false):waiting[key]=event
  elif event.get("type")=="cast" and waiting.has(key):
   var begin:Dictionary=waiting[key];var point:Variant=event.get("source_pos")
   if point is Array and point.size()>=3 and float(event.t)-float(begin.t)<=10000:
    var start:=float(begin.t)
    for interval in plan.actors[id].get("windows",[]):
     if float(interval[0])<=start and start-float(interval[0])<=250:start=float(interval[0])
    if not precast_source_positions.has(id):precast_source_positions[id]=[]
    precast_source_positions[id].append({"start":start,"end":event.t,"position":point,"ability":event.a,"evidence":"recorded stationary LP cast resolve coordinates + same-instance source tether/begincast interval; not a sampled prep-position packet"})
   waiting.erase(key)
 for id in plan.actors:
  var form:String=plan.actors[id].get("form","")
  if form not in ["optical","arm_left","arm_right","rear_unit"]:continue
  var intervals:Array=plan.actors[id].get("windows",[]).duplicate(true)
  if form in ["arm_left","arm_right"]:
   for i in range(intervals.size()-1):
    if float(intervals[i][0])==float(intervals[i][1]) and float(intervals[i+1][0])-float(intervals[i][1])<=15000:
     intervals[i][1]=intervals[i+1][1]
  effective_windows[id]=intervals
  for interval in intervals:
   for row in record.get("tracks",{}).get(id,[]):
    if float(interval[0])<=float(row[0]) and float(row[0])<=float(interval[1]):
     if not precast_source_positions.has(id):precast_source_positions[id]=[]
     precast_source_positions[id].append({"start":interval[0],"end":row[0],"position":[row[1],row[2],row[3]],"evidence":"stationary source apparatus: same observed activity/cast window and that window's first recorded placement; never reuse a prior phase placement; arm headmarker-to-rotation intervals remain continuous"})
     break
func _segment(id:String,t:float)->Dictionary:
 var result:Dictionary={}
 for value in plan.actors[id].get("motions",[]):
  if float(value.start)>t:break
  result=value
 return result
func _parts(node:Node,form:String,stance:String)->void:
 if node is MeshInstance3D:
  var name:=str(node.name)
  if name.contains("atr_parts_a"):node.visible=stance==("SHIELD" if form.begins_with("male") else "LEGS")
  elif name.contains("atr_parts_b"):node.visible=(stance!="NEUTRAL" and stance!="SHIELD") if form.begins_with("male") else stance!="LEGS"
  elif form.begins_with("female") and name.contains("atr_bv_c"):node.visible=stance!="LEGS"
 for child in node.get_children():_parts(child,form,stance)
func _pose_actor(id:String,t:float,attachment_only:=false)->Dictionary:
 if not actor_slots.has(id):return {}
 var slot:Dictionary=actor_slots[id];var binding:Dictionary=plan.actors[id];var inside:=false
 for interval in effective_windows.get(id,binding.get("windows",[])):
  if float(interval[0])<=t and t<=float(interval[1]):inside=true;break
 for rig in slot.rigs.values():rig.root.visible=false
 slot.visible=false
 if not inside and not attachment_only:return {}
 var initial_form:String=binding.get("form","")
 # Damage/tether helpers retain the immutable old arm NPC identity after Sigma.
 # Omega has M/F, Final and beetle mechanics, not physical outer-arm models.
 if not attachment_only and initial_form in ["arm_left","arm_right","rear_unit"] and _phase_at(t)==5 and t>=omega_start:
  hidden_helpers[id]="non-rendered Omega helper; original actor/endpoint identity retained";return {}
 var position:Variant=_track(id,t)
 if position==null:_problem("stale_actor_track/"+id);return {}
 var motion:=_segment(id,t)
 if motion.is_empty():_problem("missing_motion_segment/"+id);return {}
 var form:String=motion.get("form",binding.form);var rig:=_rig(slot,form,float(binding.get("scale",manifest.get("scales",{}).get(form,1))))
 if rig.is_empty():return {}
 slot.form=form;slot.root.transform=position
 var clip:String=motion.get("clip","")
 if not rig.motion.clips.is_empty():
  if not rig.motion.clips.has(clip):_problem("missing_original_clip/"+id+"/"+clip);return {}
  var duration:float=rig.motion.duration(clip);var period:=float(motion.get("period",0))
  if period<=0:period=duration
  var seconds:float=(t-float(motion.get("anchor",0)))/1000*float(motion.get("rate",1))+float(motion.get("offset",0))
  var sample_time:=clampf(seconds,0,maxf(0,duration-.00001)) if bool(motion.get("once",false)) else fposmod(seconds,maxf(.00001,period))
  if not rig.motion.sample(clip,sample_time):_problem("source_pose_rejected/"+id+"/"+clip);return {}
 _parts(rig.root,form,str(motion.get("stance","NEUTRAL")))
 rig.root.visible=inside and not attachment_only;slot.visible=rig.root.visible
 return rig
func _phase_at(t:float)->int:
 var value:=1
 for marker in record.get("phase_markers",[]):
  if float(marker.t)<=t:value=int(marker.id)
 return value
func _matrix(values:Array)->Transform3D:
 return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[4],values[5],values[6]),Vector3(values[8],values[9],values[10])),Vector3(values[12],values[13],values[14]))
func _scene(at_phase:int)->void:
 if _scene_phase==at_phase and is_instance_valid(scene_root):
  scene_root.visible=true
  diagnostics.merge(_scene_diagnostics,true)
  return
 if is_instance_valid(scene_root):scene_root.free()
 _scene_phase=at_phase;_scene_diagnostics.clear();_building_scene=true
 scene_root=Node3D.new();scene_root.name="Original scene P"+str(at_phase);add_child(scene_root)
 var source:Dictionary=scene_data.get("phases",{}).get(str(at_phase),{})
 var rows:Array=source.get("nodes",[]).duplicate();rows.append_array(source.get("floor_nodes",[]))
 for row in rows:
  if at_phase==2 and row.get("source",{}).get("rootLayer")=="p1_boss":continue
  if not _valid_scene_matrix(row.get("worldMatrix")):_problem("invalid_source_scene_matrix/"+str(row.get("key")));continue
  _building_scene_asset=str(row.asset)
  for reason in _scene_asset_diagnostics.get(_building_scene_asset,{}):_problem(reason)
  var packed:=_prototype(_building_scene_asset)
  if packed==null:_scene_asset_diagnostics.erase(_building_scene_asset)
  _building_scene_asset=""
  if packed==null:continue
  var instance:Node3D=packed.instantiate();scene_root.add_child(instance);instance.name=str(row.get("key","source"));instance.transform=_matrix(row.worldMatrix)
 _building_scene=false
func _valid_scene_matrix(values:Variant)->bool:
 if not values is Array or values.size()!=16:return false
 for value in values:
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return false
 if values[3]!=0 or values[7]!=0 or values[11]!=0 or values[15]!=1:return false
 # Vector3 components may overflow the engine's real_t even for finite doubles.
 var transform:=_matrix(values)
 return transform.basis.is_finite() and transform.origin.is_finite()
func _row(form:String,bone_id:int)->Dictionary:
 var family:String=eid.get("byForm",{}).get(form,"")
 if family.is_empty():return {}
 for row in eid.get("families",{}).get(family,{}).get("rows",[]):
  if int(row.id)==bone_id:return row
 return {}
func _target_rig(id:String,t:float)->Dictionary:
 # Build directly from the original human skeleton, not a scaled equipped GLB
 # which can omit non-skinned/unused EID nodes. This is a reference-pose proxy.
 var position:Variant=_track(id,t)
 if position==null:_problem("stale_player_target_track/"+id);return {}
 var family:String=eid.get("byForm",{}).get("player","")
 var reference:Dictionary=eid.get("families",{}).get(family,{}).get("reference_skeleton",{})
 var bones:Array=reference.get("bones",[])
 if bones.is_empty() or bones.size()>1024 or str(reference.get("source_sha256","")).length()!=64:_problem("missing_original_player_reference_skeleton");return {}
 if not hidden_player_slots.has(id):
  var holder:=Node3D.new();holder.name="Hidden_target_"+id.replace(":","_");holder.visible=false;actor_root.add_child(holder)
  var sk:=Skeleton3D.new();holder.add_child(sk)
  for i in bones.size():
   var bone:Dictionary=bones[i];var parent:=int(bone.get("parent",-2))
   if parent < -1 or parent>=i:holder.free();_problem("invalid_original_reference_hierarchy");return {}
   sk.add_bone(str(bone.name));sk.set_bone_parent(i,parent)
   var p:Array=bone.translation;var q:Array=bone.rotation;var v:Array=bone.scale
   var position_value:=Vector3(p[0],p[1],p[2]);var rotation_value:=Quaternion(q[0],q[1],q[2],q[3]).normalized();var scale_value:=Vector3(v[0],v[1],v[2])
   sk.set_bone_rest(i,Transform3D(Basis(rotation_value).scaled(scale_value),position_value));sk.set_bone_pose_position(i,position_value);sk.set_bone_pose_rotation(i,rotation_value);sk.set_bone_pose_scale(i,scale_value)
  hidden_player_slots[id]={"root":holder,"skeletons":[sk]}
 var rig:Dictionary=hidden_player_slots[id];rig.root.transform=position;rig.root.visible=false
 player_attachment_provenance[id]={"asset":"original_reference_skeleton","source_family":family,"source_sha256":reference.source_sha256,"extra_scale":1.0,"pose":"original_reference","clock_ms":t,"recorded_race_known":false,"recorded_pose_known":false,"rendered_body":false,"basis":"original human skeleton reference pose/EID + record target track; not this person's recorded race or action pose"}
 _problem("player_attachment_preset_not_recorded_pose/"+id)
 return rig
func _source_node_pose(root:Node,name:String)->Variant:
 var pending:Array=[root];var found:Node3D=null
 while not pending.is_empty():
  var node:Node=pending.pop_back()
  if node is Node3D and str(node.name)==name:
   if found!=null:_problem("ambiguous_original_attachment_node/"+name);return null
   found=node
  pending.append_array(node.get_children())
 return found.global_transform if found!=null else null
func bone_pose(id:String,bone_id:int,t:float)->Variant:
 var key:=id+"|"+str(bone_id)+"|"+str(t)
 if bone_cache.has(key):return bone_cache[key]
 var player:bool=record.get("actors",{}).get(id,{}).get("player",false)
 if player and external_bone_pose.is_valid():return external_bone_pose.call(id,bone_id,t)
 var rig:=_target_rig(id,t) if player else _pose_actor(id,t,true)
 if rig.is_empty():
  if not player:_pose_actor(id,clock)
  return null
 var form:String="player" if player else actor_slots[id].form
 var row:=_row(form,bone_id);var result:Variant=null
 if not row.is_empty():
  var skeletons:Array=rig.skeletons if rig.has("skeletons") else rig.motion.skeletons
  for sk in skeletons:
   var index:int=sk.find_bone(str(row.bone))
   if index<0:continue
   var v:Array=row.get("position",[0,0,0]);var r:Array=row.get("rotation_radians",[0,0,0])
   result=sk.global_transform*sk.get_bone_global_pose(index)*Transform3D(Basis.from_euler(Vector3(r[0],r[1],r[2]),EULER_ORDER_YXZ),Vector3(v[0],v[1],v[2]));break
  if result==null:
   # Unweighted source ancestors (e.g. human n_root) remain real scene nodes,
   # not Skeleton3D bones. Use that source transform, never a guessed height.
   var node_pose:Variant=_source_node_pose(rig.root,str(row.bone))
   if node_pose!=null:
    var v:Array=row.get("position",[0,0,0]);var r:Array=row.get("rotation_radians",[0,0,0])
    result=node_pose*Transform3D(Basis.from_euler(Vector3(r[0],r[1],r[2]),EULER_ORDER_YXZ),Vector3(v[0],v[1],v[2]))
 else:_problem("missing_original_eid/"+form+"/"+str(bone_id))
 if result==null:_problem("original_eid_bone_unavailable/"+form+"/"+str(bone_id))
 if not player:_pose_actor(id,clock)
 bone_cache[key]=result;return result
func _attachment(cue:Dictionary,prop:Dictionary,age:float,key:String)->Variant:
 # Missing/malformed source fields must not acquire a playable default.
 # JSON numbers may be floats, but source literals are integral.
 for field in ["BPT","BPTP","CoUF","GenD","bRng"]:
  if not prop.has(field):_problem("missing_original_binder_field/"+field);return null
  var value:Variant=prop[field]
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(int(value))!=float(value):
   _problem("invalid_original_binder_field/"+field);return null
 if int(prop.BPT) not in [0,1]:_problem("unknown_original_binder_origin");return null
 if int(prop.CoUF)!=-1:
  _problem("source_coordinate_update_frame_semantics_unverified/"+str(int(prop.CoUF)));return null
 if int(prop.GenD)!=0 or int(prop.bRng)!=0:_problem("source_delayed_or_ring_binder_unimplemented");return null
 var origin:=str(cue.get("target","")) if int(prop.BPT)==1 else str(cue.get("source",""))
 if origin.is_empty():_problem("missing_original_binder_actor");return null
 var at:=clock
 if int(prop.BPTP) not in [0,1,3]:_problem("unsupported_original_binder_point/"+str(prop.BPTP));return null
 if int(prop.BPTP)==3:
  var ident:Variant=prop.get("BPID")
  if typeof(ident) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(ident)) or float(int(ident))!=float(ident):
   _problem("invalid_original_binder_field/BPID");return null
 var offset:Variant=prop.get("Pos")
 if not offset is Dictionary:
  _problem("unsupported_original_binder_offset");return null
 var unknown:Variant=offset.get("unknown_fields",[])
 if not unknown is Array or not unknown.is_empty():
  _problem("unsupported_original_binder_offset");return null
 var pose:Variant=bone_pose(origin,int(prop.BPID),at) if int(prop.BPTP)==3 else _track(origin,at,false)
 if pose==null:_problem("original_binder_pose_unavailable/"+origin);return null
 var point:Variant=Curves.axes(offset,age,_seed(key),key+"/offset",0)
 if point==null:_problem("original_binder_offset_unavailable");return null
 return pose*Transform3D(Basis.IDENTITY,point)
func _seed(key:String)->int:
 var value:=2166136261
 for c in key.to_utf8_buffer():value=((value^int(c))*16777619)&0xffffffff
 return value
func _endpoints(cue:Dictionary,fx:Node3D,spec:Dictionary)->Variant:
 var binds:Array=fx.document.get("groups",{}).get("Bind",[])
 var index:=int(spec.get("binder",-1))
 if index<0 or index>=binds.size():return null
 var props:Dictionary=binds[index].get("properties",{})
 if not props.has("PrpS") or not props.has("PrpG"):return null
 var start:Variant=_attachment(cue,props.PrpS,float(spec.age),str(cue.key)+"/S")
 var end:Variant=_attachment(cue,props.PrpG,float(spec.age),str(cue.key)+"/G")
 if start==null or end==null:return null
 return [fx.to_local(start.origin),fx.to_local(end.origin)]
func _pack(path:String)->Dictionary:
 if packs.has(path):return packs[path]
 if weapons.get("packs",{}).has(path):packs[path]=weapons.packs[path];return packs[path]
 var id:String=full.get("packs",{}).get(path,"")
 if id.is_empty():_problem("missing_source_effect/"+path);return {}
 var file:String=manifest.get("native_assets",{}).get(id,{}).get("file","");var resolved:=_path(file)
 if resolved.is_empty() or not FileAccess.file_exists(resolved):_problem("missing_source_pack/"+path);return {}
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(resolved))
 if not parsed is Dictionary:_problem("invalid_source_pack/"+path);return {}
 packs[path]=parsed;return parsed
func _weapon_cues()->void:
 for cast in record.get("events",[]):
  if cast.get("type")!="cast":continue
  var action:Dictionary=weapons.get("actions",{}).get(str(int(cast.get("a",0))),{})
  if action.is_empty():continue
  for node in action.get("nodes",[]):
   cues.append({"key":"weapon/"+str(int(cast.t))+"/"+str(cast.s)+"/"+str(int(node.id)),"source":str(cast.s),"target":str(cast.get("d",cast.s)),"start":float(cast.t)+float(node.time)/30*1000,"anchor":cast.t,"path":node.path,"ability":cast.a,"node":node,"weapon":true,"source_pos":cast.get("source_pos")})
func _cue_root(cue:Dictionary)->Variant:
 var raw:Variant=cue.get("source_pos")
 if raw is Array and raw.size()>=2:return Transform3D(Basis(Vector3.UP,PI/2-(float(raw[2]) if raw.size()>2 else 0)/100),Vector3(raw[0],0,raw[1]))
 return _track(str(cue.get("source","")),float(cue.anchor),false)
func _source_fx(cue:Dictionary)->void:
 var key:String=cue.key;var start:=float(cue.start)
 if cue_selection_enabled and not cue_selection.has(key):return
 if clock<start:return
 if not allowed_actions.is_empty() and int(cue.get("ability",0))!=0 and int(cue.get("ability")) not in allowed_actions:return
 if cue.get("kind")=="cast_prepare":
  if not provisional_precast_enabled:_problem("source_prepare_disabled_unverified_host_timing/"+key);return
  _problem("source_prepare_host_timing_unverified/"+key)
  provisional_precast[key]=cue.get("prepare_provenance",{}).duplicate(true)
  provisional_precast[key]["partial"]=true
  provisional_precast[key]["unresolved_mesh_binders"]=0
  if cue.get("prepare_provenance",{}).get("cast_successful")!=true:_problem("source_prepare_interrupted_or_unknown_success/"+key)
 var frame:=(clock-start)*.03
 var release_frame:=INF
 var stop_evidence:Dictionary=verified_stops.get(key,{})
 if not stop_evidence.is_empty():
  var stop_time:=float(stop_evidence.time_ms)
  if stop_time<start:_problem("invalid_host_stop_before_start/"+key);return
  if stop_evidence.mode=="kill" and clock>=stop_time:
   lifecycle_state[key]={"state":"verified_host_kill","evidence":stop_evidence.evidence};return
  if stop_evidence.mode=="release":release_frame=(stop_time-start)*.03
 var doc:=_pack(str(cue.path))
 if doc.is_empty():return
 var bound_key:=str(cue.path)+"|"+str(release_frame)
 if not lifetime_cache.has(bound_key):lifetime_cache[bound_key]=Lifetime.upper_bound(doc,release_frame)
 var bound:Dictionary=lifetime_cache[bound_key]
 if bound.finite and frame>float(bound.frames):
  lifecycle_state[key]={"state":"naturally_quiescent","bound_frames":bound.frames,"host_completion_verified":not stop_evidence.is_empty()};return
 if frame>FX.MAX_FRAME:
  _problem("source_graph_age_outside_verified_budget/"+key);return
 var root_pose:Variant=_cue_root(cue)
 if provisional_precast.has(key):
  var origin:=str(cue.get("source",""))
  provisional_precast[key]["root_source"]="event_source_pos" if cue.get("source_pos") is Array else ("reconstructed_static_preparation" if reconstructed_preparations.has(origin) else "record_track_at_begincast")
 if root_pose==null:_problem("effect_anchor_unavailable/"+key);return
 if not active_fx.has(key):
  if active_fx.size()>=128:_problem("live_effect_budget");return
  var fx:=FX.new();effect_root.add_child(fx)
  if not fx.configure(doc,texture_paths,_seed(key)):fx.free();_problem("source_graph_configuration/"+key);return
  active_fx[key]={"fx":fx,"cue":cue}
 wanted_fx[key]=true
 var fx:Node3D=active_fx[key].fx;fx.transform=root_pose;fx.emission_stop_frame=release_frame
 lifecycle_state[key]={"state":"released_tail" if frame>=release_frame else "running","bound":bound.duplicate(true),"host_completion_verified":not stop_evidence.is_empty()}
 var node:Dictionary=cue.get("node",{})
 for field in ["bind_1","bind_2"]:
  if not node.has(field):continue
  var bind:Dictionary=node[field]
  if int(bind.get("origin",-1))!=(1 if field=="bind_1" else 2) or int(bind.get("type",-1))!=0 or int(bind.get("id",-2))!=-1:
   fx.visible=false;_problem("unsupported_original_TMB_host_binding/"+key+"/"+field);return
 if node.has("scale") and node.has("position") and node.has("rotation_radians"):
  var s:Array=node.scale;var p:Array=node.position;var r:Array=node.rotation_radians
  fx.transform=fx.transform*Transform3D(Basis.from_euler(Vector3(r[0],r[1],r[2]),EULER_ORDER_XYZ).scaled(Vector3(s[0],s[1],s[2])),Vector3(p[0],p[1],p[2]))
 fx.visible=true;fx.camera_position=fx.to_local(view.global_position)
 fx.endpoint_provider=func(spec):return _endpoints(cue,fx,spec)
 if not fx.seek(frame):fx.visible=false;_problem("source_graph_rejected/"+key);return
 for spec in fx.last_particles:
  if int(spec.kind)==6 or int(spec.get("binder",-1))<0:continue
  var index:=int(spec.binder);var binds:Array=doc.get("groups",{}).get("Bind",[])
  if index>=binds.size():continue
  var props:Dictionary=binds[index].get("properties",{})
  if not props.has("PrpS"):continue
  var world:Variant=_attachment(cue,props.PrpS,float(spec.age),key+"/binder/"+str(index))
  var mesh:MeshInstance3D=fx.draws[spec.key]
  if world==null:
   mesh.visible=false;_problem("source_binding_unavailable/"+key+"/"+str(index))
   if provisional_precast.has(key):provisional_precast[key]["unresolved_mesh_binders"]+=1
  else:mesh.visible=true;mesh.transform=fx.global_transform.affine_inverse()*world*spec.transform
 if stop_evidence.is_empty() and not bound.finite:_problem("source_host_stop_requires_verified_event/"+key)
func seek(t:float)->bool:
 if not configured or not is_finite(t) or t<source_window.x or t>=source_window.y:return false
 clock=t;provisional_precast.clear();bone_cache.clear();diagnostics.clear();reconstructed_preparations.clear();hidden_helpers.clear();player_attachment_provenance.clear();wanted_fx.clear();lifecycle_state.clear()
 phase=_phase_at(t)
 if scene_enabled:_scene(phase)
 elif is_instance_valid(scene_root):scene_root.visible=false
 for id in actor_slots:_pose_actor(id,t)
 for entry in active_fx.values():entry.fx.visible=false
 if effects_enabled:
  for cue in cues:
   if float(cue.start)>clock:break
   _source_fx(cue)
 # View-state eviction is not a source host kill; reverse seek reconstructs it.
 for key in active_fx.keys():
  if not wanted_fx.has(key):active_fx[key].fx.free();active_fx.erase(key)
 return diagnostics.is_empty()
func _matrix_array(t:Transform3D)->Array:
 return [t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
func report()->Dictionary:
 var actors:Array=[];var effects:Array=[]
 for id in actor_slots:
  var slot:Dictionary=actor_slots[id]
  if slot.visible and slot.rigs.has(slot.form):actors.append({"id":id,"form":slot.form,"world":_matrix_array(slot.root.global_transform),"scale":slot.rigs[slot.form].root.scale.x,"motion":slot.rigs[slot.form].motion.report()})
 for key in active_fx:
  var fx:Node3D=active_fx[key].fx
  if fx.visible:effects.append({"key":key,"report":fx.report()})
 return {"clock_ms":clock,"phase":phase,"cue_selection_enabled":cue_selection_enabled,"selected_cues":cue_selection.keys(),"actors":actors,"effects":effects,"hidden_target_presets":player_attachment_provenance.duplicate(true),"lifecycle":lifecycle_state.duplicate(true),"reconstructed_preparations":reconstructed_preparations.duplicate(true),"hidden_helpers":hidden_helpers.duplicate(true),"diagnostics":diagnostics.keys(),"provisional_precast_enabled":provisional_precast_enabled,"provisional_precast":provisional_precast.duplicate(true),"full_recreation_accepted":false}
func dispose()->void:
 _scene_phase=-1;_scene_diagnostics.clear();_scene_asset_diagnostics.clear();_building_scene=false;_building_scene_asset=""
 for node in [scene_root,actor_root,effect_root]:
  if is_instance_valid(node):node.free()
 scene_root=null;actor_root=null;effect_root=null;actor_slots.clear();prototypes.clear();motion_sources.clear();active_fx.clear();hidden_player_slots.clear();player_attachment_provenance.clear();lifetime_cache.clear();wanted_fx.clear();lifecycle_state.clear();cues.clear();packs.clear();bone_cache.clear();precast_source_positions.clear();reconstructed_preparations.clear();phase=0;omega_start=INF;effective_windows.clear();hidden_helpers.clear();verified_stops.clear();allowed_actions.clear();cue_selection.clear();cue_selection_enabled=false;configured=false;provisional_precast_enabled=false;provisional_precast.clear();diagnostics.clear()
