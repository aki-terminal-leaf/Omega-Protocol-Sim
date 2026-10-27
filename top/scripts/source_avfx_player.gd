# SPDX-License-Identifier: MIT
extends "res://scripts/avfx_player.gd"
## Four-layer (TC1..TC4) material + per-layer UV subset of the source graph, plus planar kind 10.
## Ported from avfx-materials.js / avfx-runtime.js. NOT the original Apricot shader; never
## rendering-complete. Overrides only _material/_animate_material/_mesh/_particle/_schedule*.
const TAGS=["TC1","TC2","TC3","TC4"]
const HEADER="""uniform vec4 particle_color:source_color=vec4(1.0);
uniform bool has_uv2=false;
uniform bool has_custom=false;
uniform int c2a_mode=0;
varying vec4 vertex_color;
varying vec2 uv_a;
varying vec2 uv_b;
varying vec2 uv_c;
varying vec2 uv_d;
float wrap_axis(float x,int m){if(m==1){return clamp(x,0.0,1.0);}if(m==2){return 1.0-abs(1.0-mod(x,2.0));}return fract(x);}
vec2 pick_uv(int n,vec2 a,vec2 b,vec2 c,vec2 d){if(n==1){return b;}if(n==2){return c;}if(n==3){return d;}return a;}
vec2 layer_uv(vec2 v,vec2 sc,vec2 tr,float ro){vec2 q=(v-vec2(0.5))*sc;float c=cos(ro);float s=sin(ro);return mat2(vec2(c,s),vec2(-s,c))*q+vec2(0.5)+tr;}
vec4 apply_c2a(vec4 b,int mode){vec4 r=b;if(mode==0){r.a=b.a*max(b.r,max(b.g,b.b));}else{r.a=dot(b.rgb,vec3(0.298912,0.586611,0.114478));}return r;}
vec4 merge_ink(vec4 a,vec4 b,int co,int ao){vec3 c=a.rgb*b.rgb;if(co==1){c=a.rgb+b.rgb;}else if(co==2){c=a.rgb-b.rgb;}else if(co==3){c=max(a.rgb,b.rgb);}else if(co==4){c=min(a.rgb,b.rgb);}float x=a.a*b.a;if(ao==1){x=max(a.a,b.a);}else if(ao==2){x=min(a.a,b.a);}return vec4(c,x);}
"""
const LAYER_UNIFORMS="uniform sampler2D tex{i}:source_color,{filter},{repeat};uniform bool ena{i}=false;uniform bool c2a{i}=false;uniform int uvn{i}=0;uniform int cop{i}=0;uniform int aop{i}=0;uniform vec2 scale{i}=vec2(1.0);uniform vec2 scroll{i}=vec2(0.0);uniform float rot{i}=0.0;uniform ivec2 wrap{i}=ivec2(0);\n"
const LAYER_SAMPLE="if(ena{i}){vec2 p=layer_uv(pick_uv(uvn{i},uv_a,uv_b,uv_c,uv_d),scale{i},scroll{i},rot{i});{wrapline}vec4 b=texture(tex{i},p);if(c2a{i}){b=apply_c2a(b,c2a_mode);}{combine}}\n"
## "max_multiply": a*=max(r,g,b) (replay JS). "weighted_assign": a=luma(rgb) (older source player).
var color_to_alpha_mode:="max_multiply"
## Replay forces double-sided; default honours the original CulT field.
var force_double_sided:=false
## Blend mode 4 (screen) has no Godot fixed-function equivalent; this is the stated fallback.
var screen_fallback_blend:="blend_mix"
var arena_radius:=20.5
var arena_center:=Vector3.ZERO
var decal_lift:=0.0
## Parent-owned set of binder indices it can attach (keys). Empty = nothing resolvable.
var known_binders:Dictionary={}
var binders_seen:Dictionary={}
var _shader_cache:Dictionary={}
var _item_binders:Dictionary={}
var _active_binder:=-1
func reset()->void:
 _shader_cache.clear();_item_binders.clear();_active_binder=-1;binders_seen.clear()
 super.reset()
func report()->Dictionary:
 var result:=super.report()
 result["rendering_complete"]=false;result["gameplay_eligible"]=false
 result["material_subset"]="TC1..TC4 TxNo-only, RGB op 0-4, alpha op 0-2, per-layer UV/wrap; not the original Apricot shader"
 result["binders"]=binders_seen.keys()
 return result
func _num(values:Dictionary,field:String,fallback:float)->float:
 var value:Variant=values.get(field)
 if value is Dictionary:value=value.get("value")
 return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
# ---- binder metadata: JS item.BdNo (>=0) else timeline BnNo, applied to particles emitted by that item.
func _schedule(values:Dictionary,start:float,now:float,key:String,result:Array)->void:
 _item_binders.clear()
 if _enabled(values,"bEna") and int(values.get("TlNo",-1))>=0:
  var node:=_node("TmLn",int(values.TlNo))
  if not node.is_empty():
   for item in node.items:
    var v:Dictionary=item.values
    if not _enabled(v,"bEna") or int(v.get("EmNo",-1))<0:continue
    var own:=int(_num(v,"BdNo",-1.0))
    _item_binders[key+"/i%d"%item.source_index]=own if own>=0 else int(_num(node.values,"BnNo",-1.0))
 super._schedule(values,start,now,key,result)
func _schedule_item(emitter:int,timeline_birth:float,item_start:float,item_end:float,now:float,key:String,result:Array)->void:
 var previous_binder:=_active_binder
 var found:Variant=_item_binders.get(key)
 if found==null:
  var cut:=key.rfind("/c")
  if cut>=0 and key.substr(cut+2).is_valid_int():found=_item_binders.get(key.substr(0,cut))
 _active_binder=int(found) if found!=null else previous_binder
 super._schedule_item(emitter,timeline_birth,item_start,item_end,now,key,result)
 _active_binder=previous_binder
func _particle(index:int,birth:float,now:float,ancestors:Array,key:String,result:Array,influence:Dictionary)->void:
 var node:=_node("Ptcl",index)
 if not node.is_empty() and int(node.values.get("PrVT",-1))==10:
  _planar_particle(node,index,birth,now,ancestors,key,result,influence);return
 var before:=result.size()
 super._particle(index,birth,now,ancestors,key,result,influence)
 if result.size()>before:_tag_binder(result[-1])
func _tag_binder(spec:Dictionary)->void:
 spec["binder"]=_active_binder;spec["binder_attached"]=false
 if _active_binder<0:return
 binders_seen[_active_binder]=true
 if known_binders.is_empty():diagnostics["binder_external_attachment_required/%d"%_active_binder]=true
 elif not known_binders.has(_active_binder):diagnostics["unknown_binder/%d"%_active_binder]=true
# Kind 10: same lifetime/pose/colour rules as the base _particle, only the kind gate differs.
func _planar_particle(node:Dictionary,index:int,birth:float,now:float,ancestors:Array,key:String,result:Array,influence:Dictionary)->void:
 if not _tick():return
 var age:=now-birth+float(influence.get("StFr",0))
 var life:Variant=CurveRuntime.life(node.get("life",{}),seed_value,key)
 if _enabled(influence,"bOvr"):
  life=float(influence.get("OvrV",0))+CurveRuntime.unit(seed_value,key+"/override")*float(influence.get("OvrR",0))
 if life==null:diagnostics["life"]=true;return
 var looped:=float(node.values.get("LpEd",0))>float(node.values.get("LpSt",0))
 if age<0 or (not looped and float(life)>=0 and age>=float(life)):return
 var chain:=ancestors.duplicate();chain.append({"group":"Ptcl","index":index,"birth":birth,"influence":influence,"key":key})
 var pose:Variant=_chain_transform(chain,now)
 var tint:Variant=_chain_color(chain,now)
 if pose==null or tint==null:return
 if result.size()>=MAX_PARTICLES:diagnostics["budget_exceeded"]=true;return
 var spec:={"key":key,"index":index,"kind":10,"age":_local(node,age),"transform":pose,"color":tint}
 _tag_binder(spec);result.append(spec)
func _mesh(spec:Dictionary)->Mesh:
 if int(spec.kind)!=10:return super._mesh(spec)
 diagnostics["flat_arena_decal_projection"]=true
 diagnostics["planar_decal_reconstruction_not_original_screen_projection"]=true
 if mesh_cache.has("kind10"):return mesh_cache["kind10"]
 var plane:=PlaneMesh.new();plane.size=Vector2.ONE;mesh_cache["kind10"]=plane;return plane
func _source_channels(node:Dictionary,kind:int)->bool:
 var model_index:=-1
 if kind==5:
  var indices:Array=node.get("data",{}).get("MdNo",[])
  if not indices.is_empty():model_index=int(indices[0])
 elif kind==13:model_index=int(node.get("data",{}).get("MNO",-1))
 return model_index>=0 and model_index<document.get("models",[]).size()
func _shader_for(states:PackedStringArray,filters:PackedStringArray,hardware_repeat:Array,decal:bool)->Shader:
 var cache_key:="%s|%s|%s|%s"%[",".join(states),",".join(filters),str(hardware_repeat),str(decal)]
 if _shader_cache.has(cache_key):return _shader_cache[cache_key]
 var code:="shader_type spatial;\nrender_mode "+", ".join(states)+";\n"+HEADER
 if decal:code+="uniform float arena_radius=20.5;\nuniform vec3 arena_center=vec3(0.0);\nuniform float decal_lift=0.0;\nvarying vec3 world_pos;\n"
 for i in 4:
  code+=LAYER_UNIFORMS.replace("{filter}",filters[i]).replace("{repeat}","repeat_enable" if hardware_repeat[i] else "repeat_disable").replace("{i}",str(i))
 code+="void vertex(){vertex_color=COLOR;uv_a=UV;uv_b=has_uv2?UV2:UV;uv_c=has_custom?CUSTOM0.xy:UV;uv_d=has_custom?CUSTOM0.zw:UV;"
 code+="VERTEX.y+=decal_lift;world_pos=VERTEX;}\n" if decal else "}\n"
 code+="void fragment(){\n"
 if decal:code+="if(length((world_pos-arena_center).xz)>arena_radius){discard;}\n"
 code+="vec4 ink=vec4(1.0);\n"
 for i in 4:
  var wrapline:="" if hardware_repeat[i] else "p=vec2(wrap_axis(p.x,wrap{i}.x),wrap_axis(p.y,wrap{i}.y));"
  var combine:="ink=b;" if i==0 else "ink=merge_ink(ink,b,cop{i},aop{i});"
  code+=LAYER_SAMPLE.replace("{wrapline}",wrapline).replace("{combine}",combine).replace("{i}",str(i))
 code+="ALBEDO=max(particle_color.rgb*vertex_color.rgb*ink.rgb,vec3(0.0));ALPHA=clamp(particle_color.a*vertex_color.a*ink.a,0.0,1.0);if(ALPHA<1.0/255.0){discard;}\n}\n"
 var shader:=Shader.new();shader.code=code;_shader_cache[cache_key]=shader;return shader
func _material(spec:Dictionary)->ShaderMaterial:
 var node:=_node("Ptcl",int(spec.index));var kind:=int(spec.kind);var decal:=kind==10
 var material:=ShaderMaterial.new()
 if node.is_empty():return material
 var values:Dictionary=node.values
 var mode:=int(values.get("RMT",0))
 var blend:String={0:"blend_mix",1:"blend_mul",2:"blend_add",3:"blend_sub"}.get(mode,"")
 if blend.is_empty():
  blend=screen_fallback_blend
  diagnostics["blend_screen_unsupported_fixed_function"if mode==4 else "blend_mode/%d"%mode]=true
 var cull:=int(values.get("CulT",0));var culling:String={0:"cull_disabled",1:"cull_front",2:"cull_back"}.get(cull,"cull_disabled")
 if cull not in [0,1,2]:diagnostics["culling_mode/%d"%cull]=true
 if decal or force_double_sided:
  if cull!=0 or decal:diagnostics["culling_overridden_double_sided"]=true
  culling="cull_disabled"
 var states:=PackedStringArray(["unshaded",blend,culling,"depth_draw_always" if _enabled(values,"DsDw") else "depth_draw_never"])
 if values.has("DsDt") and not _enabled(values,"DsDt"):states.append("depth_test_disabled")
 if decal:states.append("world_vertex_coords")
 if _enabled(values,"DsSp"):diagnostics["soft_particle_requires_apricot_shader"]=true
 if _enabled(node.get("materials",{}).get("TD",{}),"bEna"):diagnostics["uv_distortion_not_reproduced"]=true
 if _enabled(values,"bSCt"):diagnostics["simple_animation_not_reproduced"]=true
 var source_uv:=_source_channels(node,kind)
 var filters:=PackedStringArray();var hardware:Array=[];var infos:Array=[];var aliased:=false
 var params:Array=[]
 for i in 4:
  var tag:String=TAGS[i];var m:Dictionary=node.get("materials",{}).get(tag,{})
  var label:="tc%d"%(i+1)
  var tft:=int(m.get("TFT",1))
  if tft not in [0,1]:diagnostics[label+"_anisotropic_sampler_unimplemented"]=true
  filters.append("filter_nearest" if tft==0 else "filter_linear")
  var bu:=int(m.get("TBUT",0));var bv:=int(m.get("TBVT",0))
  if bu not in [0,1,2] or bv not in [0,1,2]:
   diagnostics[label+"_border_mode_unknown"]=true
   if bu not in [0,1,2]:bu=0
   if bv not in [0,1,2]:bv=0
  hardware.append(bu==0 and bv==0)
  var info:={"slot":i,"active":false,"uvn":0,"uv_set":int(m.get("UvSN",0))}
  infos.append(info)
  if int(m.get("bEna",0))==0:continue
  if not m.get("TLst",[]).is_empty() or not m.get("TxN",{}).is_empty() or not m.get("TxNR",{}).is_empty():diagnostics[label+"_mask_requires_apricot_shader"]=true
  var rgb_op:=int(m.get("TCCT",0));var alpha_op:=int(m.get("TCAT",0))
  if i>0 and (rgb_op<0 or rgb_op>4):diagnostics[label+"_color_operator_unsupported/%d"%rgb_op]=true;continue
  if i>0 and (alpha_op<0 or alpha_op>2):diagnostics[label+"_alpha_operator_unsupported/%d"%alpha_op]=true;continue
  var index:=int(m.get("TxNo",-1))
  if index<0:diagnostics[label+"_no_source_texture_TxNo"]=true;continue
  var texture:=_texture(index)
  if texture==null:
   if index>=document.get("textures",[]).size():diagnostics[label+"_texture_index_invalid"]=true
   continue
  var channel:=int(m.get("UvSN",0))
  if channel<0 or channel>3:diagnostics[label+"_uv_channel_out_of_range"]=true;channel=0
  if channel!=0 and not source_uv:aliased=true
  info.active=true;info.uvn=channel
  params.append([i,texture,int(m.get("bC2A",0))!=0,channel,rgb_op if i>0 else 0,alpha_op if i>0 else 0,Vector2i(bu,bv)])
 if aliased:diagnostics["procedural_mesh_uv_channels_aliased_to_uv0"]=true
 material.shader=_shader_for(states,filters,hardware,decal)
 for p in params:
  var i:int=p[0]
  material.set_shader_parameter("tex%d"%i,p[1]);material.set_shader_parameter("ena%d"%i,true)
  material.set_shader_parameter("c2a%d"%i,p[2]);material.set_shader_parameter("uvn%d"%i,p[3])
  material.set_shader_parameter("cop%d"%i,p[4]);material.set_shader_parameter("aop%d"%i,p[5]);material.set_shader_parameter("wrap%d"%i,p[6])
 material.set_shader_parameter("has_uv2",source_uv);material.set_shader_parameter("has_custom",source_uv)
 material.set_shader_parameter("c2a_mode",1 if color_to_alpha_mode=="weighted_assign" else 0)
 if decal:
  material.set_shader_parameter("arena_radius",arena_radius);material.set_shader_parameter("arena_center",arena_center);material.set_shader_parameter("decal_lift",decal_lift)
 material.set_meta("avfx_layers",infos)
 var priority:=int(values.get("DwPr",0))
 if priority<Material.RENDER_PRIORITY_MIN or priority>Material.RENDER_PRIORITY_MAX:diagnostics["draw_priority_out_of_range"]=true
 material.render_priority=clampi(priority,Material.RENDER_PRIORITY_MIN,Material.RENDER_PRIORITY_MAX)
 return material
func _animate_material(material:ShaderMaterial,spec:Dictionary)->void:
 var node:=_node("Ptcl",int(spec.index));var sets:Array=node.get("uv_sets",[])
 for info in material.get_meta("avfx_layers",[]):
  if not info.active:continue
  var i:int=info.slot;var index:int=info.uv_set
  if index<0 or index>=sets.size():continue
  var uv:Dictionary=sets[index]
  if int(uv.get("CUvT",0))!=0:diagnostics["pixel_uv"]=true;continue
  var scale_data:Dictionary=uv.get("Scl",{}).duplicate(true);var scroll_data:Dictionary=uv.get("Scr",{}).duplicate(true)
  var bad:=false
  # UV uses AxisConnect2 mapped onto AxisConnect3 indices [0,2,5].
  for data in [scale_data,scroll_data]:
   for tag in ["ACT","ACTR"]:
    var link:=int(data.get(tag,0))
    if link not in [0,1,2]:bad=true
    else:data[tag]=[0,2,5][link]
  if bad:diagnostics["uv_axis_connect"]=true;continue
  var suffix:="" if i==0 else str(i)
  var scaling:Variant=CurveRuntime.axes(scale_data,float(spec.age),seed_value,spec.key+"/uv_scale"+suffix,1.0)
  var scrolling:Variant=CurveRuntime.axes(scroll_data,float(spec.age),seed_value,spec.key+"/uv_scroll"+suffix,0.0)
  var rotating:Variant=CurveRuntime.scalar(uv.get("Rot",{}),uv.get("RotR",{}),float(spec.age),seed_value,spec.key+"/uv_rotation"+suffix,0.0)
  if scaling==null or scrolling==null or rotating==null:diagnostics["uv_curve"]=true;continue
  material.set_shader_parameter("scale%d"%i,Vector2(scaling.x,scaling.y))
  material.set_shader_parameter("scroll%d"%i,Vector2(scrolling.x,scrolling.y))
  material.set_shader_parameter("rot%d"%i,float(rotating))

# Imported PNGs may be remapped inside an exported PCK: ResourceLoader is authoritative.
func _texture(index:int)->Texture2D:
 if texture_cache.has(index):return texture_cache[index]
 var names:Array=document.get("textures",[])
 if index<0 or index>=names.size():return null
 var path:String=texture_paths.get(str(names[index]),"")
 var tex:Texture2D=null
 if not path.is_empty() and ResourceLoader.exists(path):tex=load(path) as Texture2D
 elif not path.is_empty() and FileAccess.file_exists(path):
  var img:=Image.load_from_file(path)
  if img!=null and not img.is_empty():tex=ImageTexture.create_from_image(img)
 if tex==null:diagnostics["missing_texture/%d"%index]=true;return null
 texture_cache[index]=tex;return tex


# VFXEditor pinned05f6eb0c labels ClCn "Child Limit". Honor a positive source
# limit across this emitter instance's direct live children. Stable birth order
# is needed: processing a whole item before the next would starve earlier births.
# Direct particles occupy slots until declared death minus StartFrame; emitter slots
# occupy until declared generation stop. Descendant tails do not retain that slot.
# Each timeline-cycle emitter instance owns its cap. Unsupported children still
# occupy declared slots; malformed emission aborts this emitter fail-closed.
# Native recycling/replacement/effector kills are unknown, not certified.
func _emit(index:int,birth:float,now:float,ancestors:Array,key:String,result:Array,depth:int,stop:float,influence:Dictionary)->void:
 if depth>=MAX_DEPTH or not _tick():diagnostics["budget_exceeded"]=true;return
 var node:=_node("Emit",index)
 if node.is_empty():return
 var life:Variant=CurveRuntime.life(node.get("life",{}),seed_value,key)
 if life==null:diagnostics["life"]=true;return
 if now<birth:return
 var looped:=float(node.values.get("LpEd",0))>float(node.values.get("LpSt",0))
 var end:=minf(now,stop)
 if float(life)>=0 and not looped:end=minf(end,birth+float(life))
 var chain:=ancestors.duplicate();chain.append({"group":"Emit","index":index,"birth":birth,"influence":influence,"key":key})
 var emitter_type:=int(node.values.get("EVT",-1))
 if emitter_type not in [0,5]:diagnostics["emitter_type/%d"%emitter_type]=true;return
 var requests:Array=[]
 for item in node.items:
  if item.role not in ["child_emitter","child_particle"]:diagnostics["unknown_emission_role"]=true;continue
  var v:Dictionary=item.values
  if not _enabled(v,"bEnb"):continue
  var generation:=maxf(0.0,float(v.get("CrTm",1))-1.0)
  var event_index:=0
  while birth+generation<=end:
   if not _tick():return
   var clock:=_local(node,generation)
   var interval:Variant=CurveRuntime.scalar(node.curves.get("CrI",{}),node.curves.get("CrIR",{}),clock,seed_value,key+"/interval",1.0)
   var count:Variant=CurveRuntime.scalar(node.curves.get("CrC",{}),node.curves.get("CrCR",{}),clock,seed_value,key+"/count",1.0)
   if interval==null or count==null or float(interval)<=0.0 or float(count)<0.0:diagnostics["emission_curve"]=true;break
   if int(v.get("CrCn",1))<0 or float(v.get("CrPr",100))<0 or float(v.get("CrPr",100))>100:diagnostics["invalid_emission_item"]=true;return
   var amount:=int(floor(float(count)))*int(v.get("CrCn",1))
   if amount>MAX_PARTICLES:diagnostics["budget_exceeded"]=true;return
   for number in amount:
    if not _tick():return
    var child_key:=key+"/%d/%d/%d"%[int(item.source_index),event_index,number]
    if CurveRuntime.unit(seed_value,child_key+"/chance")*100.0>=float(v.get("CrPr",100)):continue
    var child_birth:=birth+generation+float(v.get("GenD",0))*(number if _enabled(v,"bGD") else 1)
    var child_index:=int(v.get("TgtB",-1))
    if not is_finite(child_birth):diagnostics["nonfinite_birth"]=true;continue
    if child_birth>now or child_index<0:continue
    requests.append({"birth":child_birth,"index":child_index,"key":child_key,"influence":v,"item":int(item.source_index),"number":number,"event":event_index,"role":item.role})
   event_index+=1;generation+=maxf(0.01,float(interval))
 requests.sort_custom(func(a,b):return a.birth<b.birth if a.birth!=b.birth else (a.item<b.item if a.item!=b.item else (a.event<b.event if a.event!=b.event else a.number<b.number)))
 var limit:=int(_num(node.values,"ClCn",0))
 var alive_until:Array=[]
 for job in requests:
  var at:=float(job.birth)
  if limit>0:
   alive_until=alive_until.filter(func(t):return float(t)>at)
   if alive_until.size()>=limit:
    diagnostics["source_child_limit_active_policy"]=true;continue
  var child_influence:Dictionary=job.influence.duplicate()
  var child_group:="Emit" if job.role=="child_emitter" else "Ptcl"
  var child_node:=_node(child_group,int(job.index))
  if child_node.is_empty():continue
  var child_life:Variant=CurveRuntime.life(child_node.get("life",{}),seed_value,str(job.key))
  var child_loop:=float(child_node.values.get("LpEd",0))>float(child_node.values.get("LpSt",0))
  var until:=INF
  if job.role=="child_particle":
   if _enabled(child_influence,"bOvr"):
    child_life=float(child_influence.get("OvrV",0))+CurveRuntime.unit(seed_value,str(job.key)+"/override")*float(child_influence.get("OvrR",0))
   if child_life==null:diagnostics["life"]=true;continue
   if not child_loop and float(child_life)>=0:until=at+float(child_life)-float(child_influence.get("StFr",0))
  else:
   if child_life==null:diagnostics["life"]=true;continue
   if _enabled(child_influence,"bOvr"):diagnostics["child_emitter_life_override_unimplemented"]=true
   until=stop if child_loop or float(child_life)<0 else minf(stop,at+float(child_life))
  if limit>0:alive_until.append(until)
  if emitter_type==5:
   child_influence["emission_model"]=int(node.data.get("MdNo",-1));child_influence["emission_number"]=int(job.number);child_influence["emission_method"]=int(node.data.get("GeMT",-1))
  if job.role=="child_emitter":_emit(int(job.index),at,now,chain,str(job.key),result,depth+1,stop,child_influence)
  elif job.role=="child_particle":_particle(int(job.index),at,now,chain,str(job.key),result,child_influence)
