# SPDX-License-Identifier: MIT
extends Node3D
## Bounded source-graph preview. NOT an original-game renderer certification.
## Frames are native numeric units; the viewer chooses an explicit preview rate.
const CurveRuntime=preload("res://scripts/avfx_animation.gd")
const MAX_FRAME=1800.0
const MAX_WORK=16000
const MAX_PARTICLES=2048
const MAX_DEPTH=16
const MAX_TIMELINE_CYCLES=256
const CLIP_KILL=0x4B494C4C
const CLIP_RESET=0x52455354
const CLIP_END=0x454E4420
const CLIP_FADE_IN=0x46414449
const CLIP_UNLOCK_LOOP=0x554C4C50
const CLIP_TRIGGER=0x54524720
const CLIP_RANDOM_TRIGGER=0x52545247
var document:Dictionary={}
var seed_value:=1
var preview_rate:=30.0
var frame:=0.0
var playing:=false
var diagnostics:Dictionary={}
var triggers:Array=[]
var draws:Dictionary={}
var mesh_cache:Dictionary={}
var texture_cache:Dictionary={}
var texture_paths:Dictionary={}
var work:=0
var last_particles:Array=[]
func configure(data:Dictionary,paths:Dictionary={},random_seed:int=1)->bool:
 reset()
 if int(data.get("schema",0))!=1 or not data.get("groups") is Dictionary:
  diagnostics["invalid_document"]=true;return false
 document=data;texture_paths=paths.duplicate();seed_value=random_seed
 # Rendering completion is deliberately never inferred from successful parsing.
 diagnostics["experimental_preview_not_game_equivalence"]=true
 return true
func reset()->void:
 playing=false;frame=0.0;triggers.clear();last_particles.clear();diagnostics.clear();document={};texture_paths.clear()
 for node in draws.values():node.free()
 draws.clear();mesh_cache.clear();texture_cache.clear()
func trigger(slot:int,at_frame:float)->bool:
 if slot<0 or slot>=12 or not is_finite(at_frame) or at_frame<0 or at_frame>MAX_FRAME:return false
 triggers.append({"slot":slot,"frame":at_frame});return true
func _process(delta:float)->void:
 if playing:
  if not seek(minf(MAX_FRAME,frame+delta*preview_rate)):playing=false
  if frame>=MAX_FRAME:playing=false
func seek(at_frame:float)->bool:
 var particles:=sample_at(at_frame)
 if diagnostics.has("budget_exceeded") or diagnostics.has("invalid_frame"):
  playing=false;last_particles.clear()
  for node in draws.values():node.free()
  draws.clear();mesh_cache.clear();texture_cache.clear()
  return false
 frame=at_frame;last_particles=particles
 var visible_ids:={}
 for spec in particles:
  var key:String=spec.key;visible_ids[key]=true
  if not draws.has(key):
   var instance:=MeshInstance3D.new();instance.mesh=_mesh(spec);instance.material_override=_material(spec);add_child(instance);draws[key]=instance
  var instance:MeshInstance3D=draws[key]
  if int(spec.kind)==12:instance.mesh=_disc(spec)
  instance.transform=spec.transform
  _animate_material(instance.material_override,spec)
  if instance.material_override is ShaderMaterial:instance.material_override.set_shader_parameter("particle_color",spec.color)
 for key in draws.keys():
  if not visible_ids.has(key):draws[key].free();draws.erase(key)
 return true
func sample_at(at_frame:float)->Array:
 diagnostics.erase("invalid_frame");diagnostics.erase("budget_exceeded");work=0
 if not is_finite(at_frame) or at_frame<0 or at_frame>MAX_FRAME:
  diagnostics["invalid_frame"]=true;return []
 var result:Array=[]
 var schedulers:Array=document.get("groups",{}).get("Schd",[])
 for scheduler in schedulers:
  var slot:=0
  for item in scheduler.items:
   var values:Dictionary=item.values
   if item.role=="trigger_timeline":
    for event in triggers:
     if int(event.slot)==slot:_schedule(values,float(event.frame),at_frame,"s%d/t%d/%s"%[scheduler.index,slot,event.frame],result)
    slot+=1
   else:_schedule(values,0.0,at_frame,"s%d/%d"%[scheduler.index,item.source_index],result)
 if diagnostics.has("budget_exceeded"):return []
 return result
func _schedule(values:Dictionary,start:float,now:float,key:String,result:Array)->void:
 if not _enabled(values,"bEna") or int(values.get("TlNo",-1))<0:return
 var birth:=start+float(values.get("StTm",0))
 if now<birth:return
 var node:=_node("TmLn",int(values.TlNo))
 if node.is_empty():return
 for item in node.items:
  var v:Dictionary=item.values
  if not _enabled(v,"bEna"):continue
  var clip_index:=int(v.get("ClNo",-1) if v.get("ClNo")!=null else -1)
  if clip_index>=0:
   _clip(node,clip_index,birth+float(v.get("StTm",0)),now)
   continue
  var emitter:int=int(v.get("EmNo",-1))
  if emitter<0:continue
  var item_start:=float(v.get("StTm",0));var item_end:=float(v.get("EdTm",-1))
  _schedule_item(emitter,birth,item_start,item_end,now,key+"/i%d"%item.source_index,result)
  var loop_start:=float(node.values.get("LpSt",0));var loop_end:=float(node.values.get("LpEd",0))
  if loop_end<=loop_start or item_start<loop_start or item_start>=loop_end:continue
  diagnostics["timeline_loop_preview_policy"]=true
  var period:=loop_end-loop_start;var cycle:=1
  while cycle<=MAX_TIMELINE_CYCLES:
   var shifted_start:=item_start+period*cycle
   if birth+shifted_start>now:break
   if not _tick():return
   _schedule_item(emitter,birth,shifted_start,item_end+period*cycle if item_end>=0.0 else -1.0,now,key+"/i%d/c%d"%[item.source_index,cycle],result)
   cycle+=1
  if cycle>MAX_TIMELINE_CYCLES and birth+item_start+period*cycle<=now:
   diagnostics["timeline_cycle_limit"]=true;diagnostics["budget_exceeded"]=true;return
func _schedule_item(emitter:int,timeline_birth:float,item_start:float,item_end:float,now:float,key:String,result:Array)->void:
 var emitter_birth:=timeline_birth+item_start
 if now<emitter_birth:return
 var stop:=timeline_birth+item_end if item_end>=0.0 else INF
 _emit(emitter,emitter_birth,now,[],key,result,0,stop,{})
func _clip(timeline:Dictionary,index:int,at:float,now:float)->void:
 var clips:Array=timeline.get("clips",[])
 if index<0 or index>=clips.size():diagnostics["invalid_timeline_clip_reference"]=true;return
 if now<at:return
 var kind:=int(clips[index].get("type",0))
 if kind in [CLIP_KILL,CLIP_END]:diagnostics["timeline_clip_stop_requires_runtime_state"]=true
 elif kind==CLIP_RESET:diagnostics["timeline_clip_reset_requires_runtime_state"]=true
 elif kind==CLIP_UNLOCK_LOOP:diagnostics["timeline_clip_unlock_requires_runtime_state"]=true
 elif kind==CLIP_FADE_IN:diagnostics["timeline_clip_fade_requires_runtime_state"]=true
 elif kind in [CLIP_TRIGGER,CLIP_RANDOM_TRIGGER]:diagnostics["timeline_clip_trigger_requires_runtime_state"]=true
 else:diagnostics["timeline_clip_unknown/%d"%kind]=true
func _enabled(values:Dictionary,field:String)->bool:
 var value:Variant=values.get(field)
 if value is Dictionary:value=value.get("value")
 if value is bool:return value
 return value==1 if value is int or value is float else false
func _node(group:String,index:int)->Dictionary:
 var nodes:Array=document.get("groups",{}).get(group,[])
 if index<0 or index>=nodes.size():diagnostics["invalid_reference/"+group]=true;return {}
 return nodes[index]
func _tick()->bool:
 work+=1
 if work>MAX_WORK:diagnostics["budget_exceeded"]=true;return false
 return true
func _local(node:Dictionary,age:float)->float:
 var start:=float(node.values.get("LpSt",0));var end:=float(node.values.get("LpEd",0))
 return start+fposmod(age-start,end-start) if end>start and age>=end else age
func _emit(index:int,birth:float,now:float,ancestors:Array,key:String,result:Array,depth:int,stop:float,influence:Dictionary)->void:
 if depth>=MAX_DEPTH or not _tick():diagnostics["budget_exceeded"]=true;return
 var node:=_node("Emit",index)
 if node.is_empty():return
 var life:Variant=CurveRuntime.life(node.get("life",{}),seed_value,key)
 if life==null:diagnostics["life"]=true;return
 var age:=now-birth
 if age<0:return
 var looped:=float(node.values.get("LpEd",0))>float(node.values.get("LpSt",0))
 var end:=minf(now,stop)
 if float(life)>=0 and not looped:end=minf(end,birth+float(life))
 var chain:=ancestors.duplicate();chain.append({"group":"Emit","index":index,"birth":birth,"influence":influence,"key":key})
 var emitter_type:=int(node.values.get("EVT",-1))
 if emitter_type not in [0,5]:diagnostics["emitter_type/%d"%emitter_type]=true;return
 for item in node.items:
  var v:Dictionary=item.values
  if not _enabled(v,"bEnb"):continue
  var generation:=maxf(0.0,float(v.get("CrTm",1))-1.0)
  var event_index:=0
  while birth+generation<=end:
   if not _tick():return
   var clock:=_local(node,generation)
   var interval:Variant=CurveRuntime.scalar(node.curves.get("CrI",{}),node.curves.get("CrIR",{}),clock,seed_value,key+"/interval",1.0)
   var count:Variant=CurveRuntime.scalar(node.curves.get("CrC",{}),node.curves.get("CrCR",{}),clock,seed_value,key+"/count",1.0)
   if interval==null or count==null or float(interval)<=0.0 or float(count)<0.0:
    diagnostics["emission_curve"]=true;break
   if int(v.get("CrCn",1))<0 or float(v.get("CrPr",100))<0 or float(v.get("CrPr",100))>100:
    diagnostics["invalid_emission_item"]=true;return
   var amount:=int(floor(float(count)))*int(v.get("CrCn",1))
   if amount>MAX_PARTICLES:diagnostics["budget_exceeded"]=true;return
   for number in amount:
    if not _tick():return
    var child_key:=key+"/%d/%d/%d"%[int(item.source_index),event_index,number]
    if CurveRuntime.unit(seed_value,child_key+"/chance")*100.0>=float(v.get("CrPr",100)):continue
    var child_birth:=birth+generation+float(v.get("GenD",0))*(number if _enabled(v,"bGD") else 1)
    if child_birth>now:continue
    var child_index:=int(v.get("TgtB",-1))
    if child_index<0:continue
    var child_influence:=v.duplicate()
    if emitter_type==5:child_influence["emission_model"]=int(node.data.get("MdNo",-1));child_influence["emission_number"]=number;child_influence["emission_method"]=int(node.data.get("GeMT",-1))
    if item.role=="child_emitter":_emit(child_index,child_birth,now,chain,child_key,result,depth+1,stop,child_influence)
    elif item.role=="child_particle":_particle(child_index,child_birth,now,chain,child_key,result,child_influence)
   event_index+=1;generation+=maxf(0.01,float(interval))
func _particle(index:int,birth:float,now:float,ancestors:Array,key:String,result:Array,influence:Dictionary)->void:
 if not _tick():return
 var node:=_node("Ptcl",index)
 if node.is_empty():return
 var age:=now-birth+float(influence.get("StFr",0))
 var life:Variant=CurveRuntime.life(node.get("life",{}),seed_value,key)
 if _enabled(influence,"bOvr"):
  life=float(influence.get("OvrV",0))+CurveRuntime.unit(seed_value,key+"/override")*float(influence.get("OvrR",0))
 if life==null:diagnostics["life"]=true;return
 var looped:=float(node.values.get("LpEd",0))>float(node.values.get("LpSt",0))
 if age<0 or (not looped and float(life)>=0 and age>=float(life)):return
 var kind:=int(node.values.get("PrVT",-1))
 if kind not in [1,2,5,8,12,13]:diagnostics["particle_type/%d"%kind]=true;return
 var chain:=ancestors.duplicate();chain.append({"group":"Ptcl","index":index,"birth":birth,"influence":influence,"key":key})
 var pose:Variant=_chain_transform(chain,now)
 var tint:Variant=_chain_color(chain,now)
 if pose==null or tint==null:return
 if result.size()>=MAX_PARTICLES:diagnostics["budget_exceeded"]=true;return
 result.append({"key":key,"index":index,"kind":kind,"age":_local(node,age),"transform":pose,"color":tint})
func _chain_transform(chain:Array,at_frame:float)->Variant:
 if chain.is_empty():return Transform3D.IDENTITY
 var link:Dictionary=chain[-1];var node:=_node(link.group,int(link.index))
 var influence:Dictionary=link.influence;var age:=_local(node,maxf(0.0,at_frame-float(link.birth)))
 var position:Variant=CurveRuntime.axes(node.axes.get("Pos",{}),age,seed_value,link.key+"/Pos",0.0)
 var rotation:Variant=CurveRuntime.axes(node.axes.get("Rot",{}),age,seed_value,link.key+"/Rot",0.0)
 var scale_value:Variant=CurveRuntime.axes(node.axes.get("Scl",{}),age,seed_value,link.key+"/Scl",1.0)
 if position==null or rotation==null or scale_value==null:diagnostics["transform_curve"]=true;return null
 var rotation_order:=int(node.values.get("ROT" if link.group=="Emit" else "RoOT",0))
 if rotation_order<0 or rotation_order>5:diagnostics["rotation_order"]=true;return null
 var rotating:=Transform3D(Basis.from_euler(rotation,[0,3,4,1,2,5][rotation_order]),Vector3.ZERO)
 var scaling:=Transform3D(Basis.IDENTITY.scaled(scale_value),Vector3.ZERO)
 var translating:=Transform3D(Basis.IDENTITY,position)
 var order:=int(node.values.get("CCOT",0));var local:Transform3D
 match order:
  0:local=translating*rotating*scaling
  1:local=rotating*scaling*translating
  2:local=scaling*translating*rotating
  3:local=scaling*rotating*translating
  4:local=rotating*translating*scaling
  5:local=translating*scaling*rotating
  _:diagnostics["coordinate_order"]=true;return null
 if chain.size()==1:return local
 var previous:=chain.slice(0,-1)
 var mode:=int(influence.get("PICd",2))
 var parent_time:=float(link.birth) if mode in [0,1,3,5] else at_frame
 var inherited:Variant=_chain_transform(previous,parent_time)
 if inherited==null:return null
 if mode==6:inherited=Transform3D.IDENTITY
 elif mode in [4,5,7]:inherited.origin=Vector3.ZERO
 elif mode not in [0,1,2,3]:diagnostics["parent_influence"]=true;return null
 if mode in [1,7]:
  var s:Vector3=inherited.basis.get_scale() if _enabled(influence,"ICbS") else Vector3.ONE
  var r:Basis=inherited.basis.orthonormalized() if _enabled(influence,"ICbR") else Basis.IDENTITY
  inherited.basis=r.scaled(s)
  if not _enabled(influence,"ICbP"):inherited.origin=Vector3.ZERO
 if influence.has("emission_model"):
  var models:Array=document.get("models",[]);var model_index:=int(influence.emission_model)
  if model_index<0 or model_index>=models.size():diagnostics["emission_model"]=true;return null
  var vertices:Array=models[model_index].get("emission_vertices",[])
  var ordering:Array=models[model_index].get("emission_order",[])
  var method:=int(influence.get("emission_method",-1))
  if method!=3 or vertices.is_empty():diagnostics["model_emission_method/%d"%method]=true;return null
  var vertex_index:=int(influence.get("emission_number",0))%vertices.size()
  if not ordering.is_empty():vertex_index=int(ordering[vertex_index%ordering.size()])
  if vertex_index<0 or vertex_index>=vertices.size():diagnostics["emission_order"]=true;return null
  var position_data:Array=vertices[vertex_index].position
  local.origin+=Vector3(position_data[0],position_data[1],position_data[2])
 return inherited*local
func _chain_color(chain:Array,at_frame:float)->Variant:
 if chain.is_empty():return Color.WHITE
 var link:Dictionary=chain[-1];var node:=_node(link.group,int(link.index))
 var tint:Variant=CurveRuntime.colour(node.get("color",{}),_local(node,maxf(0.0,at_frame-float(link.birth))),seed_value,link.key+"/color")
 if tint==null:diagnostics["color_curve"]=true;return null
 var mode:=int(link.influence.get("PICo",0))
 if chain.size()>1 and mode!=0:
  var parent:Variant=_chain_color(chain.slice(0,-1),float(link.birth) if mode==1 else at_frame)
  if parent==null:return null
  tint*=parent
 return tint
func _mesh(spec:Dictionary)->Mesh:
 var node:=_node("Ptcl",int(spec.index));var kind:=int(spec.kind)
 var model_index:=-1
 if kind==5:
  var indices:Array=node.data.get("MdNo",[])
  if not indices.is_empty():model_index=int(indices[0])
 elif kind==13:model_index=int(node.data.get("MNO",-1))
 var key:="model%d"%model_index if model_index>=0 else "kind%d"%kind
 if mesh_cache.has(key):return mesh_cache[key]
 var mesh:Mesh
 if model_index>=0 and model_index<document.get("models",[]).size():
  var source:Dictionary=document.models[model_index];var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
  var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
  for v in source.vertices:
   vertices.append(Vector3(v.position[0],v.position[1],v.position[2]));uvs.append(Vector2(v.uv[0][0],v.uv[0][1]));colors.append(Color(v.color[0]/255.0,v.color[1]/255.0,v.color[2]/255.0,v.color[3]/255.0))
  for face in source.triangles:
   for vertex in face:indices.append(int(vertex))
  var actual:=ArrayMesh.new()
  if not vertices.is_empty() and not indices.is_empty():
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices;actual.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh=actual
 elif kind in [1,2,8]:
  var quad:=QuadMesh.new();quad.size=Vector2.ONE;mesh=quad
 elif kind==12:return _disc(spec)
 else:
  diagnostics["model_selection"]=true;mesh=ArrayMesh.new()
 mesh_cache[key]=mesh;return mesh
func _texture(index:int)->Texture2D:
 if texture_cache.has(index):return texture_cache[index]
 var names:Array=document.get("textures",[])
 if index<0 or index>=names.size():return null
 var path:String=texture_paths.get(str(names[index]),"")
 if path.is_empty() or not FileAccess.file_exists(path):diagnostics["missing_texture/%d"%index]=true;return null
 var texture:Texture2D
 if ResourceLoader.exists(path):texture=load(path)
 else:
  var img:=Image.load_from_file(path)
  if img!=null and not img.is_empty():texture=ImageTexture.create_from_image(img)
 texture_cache[index]=texture;return texture
func _material(spec:Dictionary)->ShaderMaterial:
 var node:=_node("Ptcl",int(spec.index));var first:Dictionary=node.materials.get("TC1",{})
 var mode:=int(node.values.get("RMT",0))
 var blend:String={0:"blend_mix",1:"blend_mul",2:"blend_add",3:"blend_sub"}.get(mode,"blend_mix")
 if mode not in [0,1,2,3]:diagnostics["blend_mode/%d"%mode]=true
 var cull:=int(node.values.get("CulT",0))
 var culling:String={0:"cull_disabled",1:"cull_front",2:"cull_back"}.get(cull,"cull_disabled")
 if cull not in [0,1,2]:diagnostics["culling_mode/%d"%cull]=true
 var states:Array[String]=["unshaded",blend,culling,"depth_draw_always" if _enabled(node.values,"DsDw") else "depth_draw_never"]
 if node.values.has("DsDt") and not _enabled(node.values,"DsDt"):states.append("depth_test_disabled")
 if _enabled(node.values,"DsSp"):diagnostics["soft_particle_requires_apricot_shader"]=true
 var filtering:="filter_nearest" if int(first.get("TFT",1))==0 else "filter_linear"
 if int(first.get("TFT",1)) not in [0,1]:diagnostics["anisotropic_sampler_unimplemented"]=true
 var border_u:=int(first.get("TBUT",0));var border_v:=int(first.get("TBVT",0))
 var wrapping:="repeat_disable" if border_u==1 and border_v==1 else "repeat_enable"
 if border_u!=border_v or border_u not in [0,1]:diagnostics["sampler_border_requires_apricot_mapping"]=true
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode %s;
uniform vec4 particle_color:source_color=vec4(1.0);
uniform sampler2D base_texture:source_color,%s,%s;
uniform bool textured=false;
uniform bool color_to_alpha=false;
uniform vec2 uv_scale=vec2(1.0);
uniform vec2 uv_scroll=vec2(0.0);
uniform float uv_rotation=0.0;
varying vec4 vertex_color;
void vertex(){vertex_color=COLOR;}
void fragment(){vec2 p=(UV-vec2(0.5))*uv_scale;float c=cos(uv_rotation);float s=sin(uv_rotation);vec2 uv=mat2(vec2(c,s),vec2(-s,c))*p+vec2(0.5)+uv_scroll;vec4 ink=textured?texture(base_texture,uv):vec4(1.0);if(color_to_alpha){ink.a=dot(ink.rgb,vec3(0.298912,0.586611,0.114478));}ALBEDO=max(particle_color.rgb*vertex_color.rgb*ink.rgb,vec3(0.0));ALPHA=clamp(particle_color.a*vertex_color.a*ink.a,0.0,1.0);if(ALPHA<1.0/255.0){discard;}}
"""%[", ".join(states),filtering,wrapping]
 var material:=ShaderMaterial.new();material.shader=shader
 # TLst is a MASK list in the source, never a fallback base-texture index.
 var indices:Array=first.get("TLst",[]);var index:=int(first.get("TxNo",-1))
 if not indices.is_empty() or not first.get("TxN",{}).is_empty() or not first.get("TxNR",{}).is_empty():
  diagnostics["tc1_mask_requires_apricot_shader"]=true
 if int(first.get("bEna",0))!=0:
  var texture:=_texture(index)
  if texture!=null:material.set_shader_parameter("base_texture",texture);material.set_shader_parameter("textured",true)
 material.set_shader_parameter("color_to_alpha",int(first.get("bC2A",0))!=0)
 var priority:=int(node.values.get("DwPr",0))
 if priority<Material.RENDER_PRIORITY_MIN or priority>Material.RENDER_PRIORITY_MAX:diagnostics["draw_priority_out_of_range"]=true
 material.render_priority=clampi(priority,Material.RENDER_PRIORITY_MIN,Material.RENDER_PRIORITY_MAX)
 return material
func _animate_material(material:ShaderMaterial,spec:Dictionary)->void:
 var node:=_node("Ptcl",int(spec.index));var first:Dictionary=node.materials.get("TC1",{})
 var sets:Array=node.get("uv_sets",[]);var index:=int(first.get("UvSN",0))
 if index<0 or index>=sets.size():return
 var uv:Dictionary=sets[index]
 if int(uv.get("CUvT",0))!=0:diagnostics["pixel_uv"]=true;return
 var scale_data:Dictionary=uv.get("Scl",{}).duplicate(true);var scroll_data:Dictionary=uv.get("Scr",{}).duplicate(true)
 # UV uses AxisConnect2, not AxisConnect3.
 for data in [scale_data,scroll_data]:
  for tag in ["ACT","ACTR"]:
   var link:=int(data.get(tag,0))
   if link not in [0,1,2]:diagnostics["uv_axis_connect"]=true;return
   data[tag]=[0,2,5][link]
 var scaling:Variant=CurveRuntime.axes(scale_data,float(spec.age),seed_value,spec.key+"/uv_scale",1.0)
 var scrolling:Variant=CurveRuntime.axes(scroll_data,float(spec.age),seed_value,spec.key+"/uv_scroll",0.0)
 var rotating:Variant=CurveRuntime.scalar(uv.get("Rot",{}),uv.get("RotR",{}),float(spec.age),seed_value,spec.key+"/uv_rotation",0.0)
 if scaling==null or scrolling==null or rotating==null:diagnostics["uv_curve"]=true;return
 material.set_shader_parameter("uv_scale",Vector2(scaling.x,scaling.y))
 material.set_shader_parameter("uv_scroll",Vector2(scrolling.x,scrolling.y))
 material.set_shader_parameter("uv_rotation",rotating)
func _disc(spec:Dictionary)->ArrayMesh:
 var node:=_node("Ptcl",int(spec.index));var data:Dictionary=node.data;var values:={}
 for field in ["Ang","WB","WE","RB","RE","HBI","HEI","HBO","HEO"]:
  var value:Variant=CurveRuntime.scalar(data.get(field,{}),data.get(field+"R",{}),float(spec.age),seed_value,spec.key+"/disc/"+field,TAU if field=="Ang" else 0.0)
  if value==null:diagnostics["disc_curve"]=true;return ArrayMesh.new()
  values[field]=float(value)
 var segments:=int(data.get("PCnV",0));var radial:=int(data.get("PCnU",0))
 if segments<1 or segments>256 or radial<1 or radial>32 or absf(values.Ang)>TAU*16:
  diagnostics["disc_budget"]=true;return ArrayMesh.new()
 var inner:Variant=CurveRuntime.colour(data.get("CEI",{}),float(spec.age),seed_value,spec.key+"/inner")
 var outer:Variant=CurveRuntime.colour(data.get("CEO",{}),float(spec.age),seed_value,spec.key+"/outer")
 if inner==null or outer==null:return ArrayMesh.new()
 var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
 for i in range(segments+1):
  var u:=float(i)/segments;var angle:float=values.Ang*u
  var radius:=lerpf(values.RB,values.RE,u);var width:=lerpf(values.WB,values.WE,u)
  for j in range(radial+1):
   var v:=float(j)/radial;var r:=radius+width*(v-0.5)
   var h:=lerpf(lerpf(values.HBI,values.HEI,u),lerpf(values.HBO,values.HEO,u),v)
   vertices.append(Vector3(cos(angle)*r,h,sin(angle)*r));uvs.append(Vector2(u,v));colors.append(inner.lerp(outer,v))
 for i in segments:
  for j in radial:
   var a:=i*(radial+1)+j;var b:=a+radial+1
   for n in [a,b,a+1,a+1,b,b+1]:indices.append(n)
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func report()->Dictionary:
 return {"source_sha256":document.get("source_sha256",""),"frame":frame,"seed":seed_value,"preview_rate":preview_rate,"particles":last_particles.size(),"work":work,"diagnostics":diagnostics.keys(),"source_unsupported":document.get("unsupported",[]),"rendering_complete":false,"gameplay_eligible":false}
