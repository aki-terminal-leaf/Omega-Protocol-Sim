# SPDX-License-Identifier: MIT
extends RefCounted
## Executable reviewed texture section only. No invented host/UV/default factors.
## No global caches: the caller owns the returned material and all bound textures.
const WEIGHTS=[0.298911988735199,0.5866109728813171,0.11447799950838089]
const DISCARD_THRESHOLD=0.003921568859368563
const REGISTRY="res://data/apricot_verified_color_programs.json"
const OPS=["Mul","Add","Sub","Max","Min","None"]
static func failure(reason:String)->Dictionary:
 return {"status":"unsupported","diagnostics":[reason],"rendering_complete":false}
static func rgba(value:Variant)->bool:
 if not value is Color:return false
 return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
static func row(value:Variant)->bool:
 return value is Vector3 and is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
static func operation(previous:String,sample:String,mode:String)->String:
 match mode:
  "Mul":return "(%s*%s)"%[previous,sample]
  "Add":return "(%s+%s)"%[previous,sample]
  "Sub":return "(%s-%s)"%[previous,sample]
  "Max":return "max(%s,%s)"%[previous,sample]
  "Min":return "min(%s,%s)"%[previous,sample]
 return previous
static func expression(mode:String,terms:Array)->Variant:
 if mode=="None":return terms[0]
 if mode in ["Mul","Add"]:
  var flat:Array=[];var identity:int=1 if mode=="Mul" else 0
  for term in terms:
   if term is int and term==identity:continue
   if term is Array and term[0]==mode:flat.append_array(term.slice(1))
   else:flat.append(term)
  if flat.is_empty():return identity
  if flat.size()==1:return flat[0]
  flat.sort_custom(func(a:Variant,b:Variant)->bool:return JSON.stringify(a)<JSON.stringify(b))
  var result:Array=[mode];result.append_array(flat);return result
 if mode in ["Min","Max"] and typeof(terms[0])==typeof(terms[1]) and terms[0]==terms[1]:return terms[0]
 var result:Array=[mode];result.append_array(terms);return result
static func first(sample:Variant,control:String)->Variant:
 return 1 if sample is int and sample==1 else ["LerpOne",sample,control]
static func equation_signature(layers:Array)->String:
 var rgb:Variant=1;var alpha:Variant=1
 for layer in layers:
  if not layer.enabled:continue
  var n:int=int(layer.number)
  var color:Variant=1 if layer.color_to_alpha else ["RGB",n]
  var a:Array=["Luma" if layer.color_to_alpha else "Alpha",n]
  if n==1:rgb=first(color,"CalculateColor");alpha=first(a,"CalculateAlpha")
  else:rgb=expression(layer.color_op,[rgb,color]);alpha=expression(layer.alpha_op,[alpha,a])
 return JSON.stringify([rgb,alpha]).sha256_text()
static func create(plan:Dictionary,context:Dictionary)->Dictionary:
 if plan.get("status")!="verified_color_stage" or plan.get("rendering_complete")!=false:return failure("reviewed color section required")
 # Hash/layout-gated semantics shared with the CPU compiler. A label alone is
 # insufficient: powder1 and shape1 have identical section equations.
 var registry:Variant=JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
 if not registry is Dictionary or not registry.get("programs") is Array:return failure("reviewed factor registry unavailable")
 var reviewed:Dictionary={}
 for entry in registry.programs:
  if entry.bytecode_sha256==plan.get("bytecode_sha256") and entry.bindings_sha256==plan.get("bindings_sha256"):reviewed=entry;break
 if reviewed.is_empty() or plan.get("review_equation")!=reviewed.equation_id or plan.get("nonnegative_clamp")!=reviewed.nonnegative_clamp or plan.get("discard_threshold_bits")!="0x3B808081" or reviewed.discard_threshold_bits!="0x3B808081":return failure("factor contract does not match reviewed program identity")
 if reviewed.nonnegative_clamp not in ["before_common","after_common"]:return failure("unreviewed clamp order")
 var layers:Variant=plan.get("layers")
 if not layers is Array or layers.size()!=4:return failure("exactly four ordered layers required")
 var cc:Variant=context.get("calculate_color");var ca:Variant=context.get("calculate_alpha")
 if not (cc is float or cc is int) or not (ca is float or ca is int) or not is_finite(float(cc)) or not is_finite(float(ca)):return failure("finite explicit CalculateColor/Alpha required")
 if not rgba(context.get("common_factor")):return failure("explicit combined vertex/document/model factor required")
 if not context.has("model_fresnel_included") or not context.model_fresnel_included is bool:return failure("explicit model-factor provenance required")
 if plan.get("requires_model_fresnel",false) and not context.model_fresnel_included:return failure("model Fresnel factor not supplied")
 var samples:Variant=context.get("samples")
 if not samples is Array or samples.size()!=4:return failure("four explicit sample contexts required")
 var uses_custom_uv:=false
 var declarations:="";var body:="vec4 ink=vec4(1.0);\n"
 for i in 4:
  var layer:Variant=layers[i]
  if not layer is Dictionary or layer.get("number")!=i+1 or not layer.get("enabled") is bool:return failure("invalid ordered layer")
  if not layer.enabled:continue
  if not layer.get("sample_required") is bool or not layer.get("color_to_alpha") is bool:return failure("explicit sampling/CTA flags required")
  if i>0 and (layer.get("color_op") not in OPS or layer.get("alpha_op") not in ["Mul","Max","Min","None"]):return failure("unknown combiner operation")
  if i==0 and (layer.get("color_op")!="DynamicMul" or layer.get("alpha_op")!="DynamicMul"):return failure("first-layer dynamic controls required")
  # Decode-off is the only reviewed texture decoding mode in this bridge.
  if layer.get("decode_semantic")!="TextureColor%d_Decode_Off"%(i+1):return failure("texture decode mode is not reviewed")
  var label:="c%d"%i
  if layer.sample_required:
   var sample:Variant=samples[i]
   if not sample is Dictionary or not sample.get("texture") is Texture2D:return failure("required texture missing")
   if not row(sample.get("uv_row0")) or not row(sample.get("uv_row1")):return failure("explicit finite UV transform rows required")
   if sample.get("source_uv_index")!=layer.get("uv_index"):return failure("source UV-set provenance does not match reviewed plan")
   var source:Variant=sample.get("uv_source")
   if not (source is int or source is float) or not is_finite(float(source)) or source!=floor(float(source)) or source<0 or source>3:return failure("explicit mesh UV source 0..3 required")
   if source>=2:
    var source_mesh:Variant=context.get("source_mesh")
    if not source_mesh is ArrayMesh or source_mesh.get_surface_count()==0:return failure("custom UVs require the actual source ArrayMesh")
    for surface in source_mesh.get_surface_count():
     var format:int=source_mesh.surface_get_format(surface)
     if not (format&Mesh.ARRAY_FORMAT_CUSTOM0) or ((format>>Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)&Mesh.ARRAY_FORMAT_CUSTOM_MASK)!=Mesh.ARRAY_CUSTOM_RGBA_FLOAT:return failure("custom UVs require RGBA_FLOAT CUSTOM0 on every surface")
    uses_custom_uv=true
   if sample.get("filter") not in ["nearest","linear"] or sample.get("wrap") not in ["repeat","clamp"]:return failure("unreviewed sampler state")
   if not sample.get("decoded_samples") is bool or not sample.decoded_samples:return failure("explicit decoded numeric samples required")
   declarations+="uniform sampler2D tex%d:filter_%s,%s;\nuniform vec3 uv%d_row0;\nuniform vec3 uv%d_row1;\n"%[i,sample.filter,"repeat_enable" if sample.wrap=="repeat" else "repeat_disable",i,i]
   var uv:String=["UV","UV2","original_uv23.xy","original_uv23.zw"][int(source)]
   body+="vec2 uv%d=vec2(dot(vec3(%s,1.0),uv%d_row0),dot(vec3(%s,1.0),uv%d_row1));vec4 %s=texture(tex%d,uv%d);\n"%[i,uv,i,uv,i,label,i,i]
  else:
   # Source optimizer can elide CTA RGB=white/alpha=None samplers.
   if not layer.color_to_alpha and (layer.color_op!="None" or layer.alpha_op!="None"):return failure("missing sampler would change color")
   if layer.alpha_op!="None":return failure("missing sampler would change alpha")
   body+="vec4 %s=vec4(1.0);\n"%label
  if layer.color_to_alpha and layer.sample_required:
   var weights:Variant=plan.get("color_to_alpha_weights")
   if not weights is Array or weights.size()!=3:return failure("reviewed CTA immediate vector required")
   for j in 3:
    if not (weights[j] is float or weights[j] is int) or not is_finite(float(weights[j])) or absf(float(weights[j])-WEIGHTS[j])>1e-14:return failure("unreviewed CTA immediate vector")
   body+="%s=vec4(1.0,1.0,1.0,dot(%s.rgb,vec3(0.298911988735199,0.5866109728813171,0.11447799950838089)));\n"%[label,label]
  if i==0:body+="ink=mix(vec4(1.0),%s,vec4(calculate_color,calculate_color,calculate_color,calculate_alpha));\n"%label
  else:body+="ink=vec4(%s,%s);\n"%[operation("ink.rgb",label+".rgb",layer.color_op),operation("ink.a",label+".a",layer.alpha_op)]
 if plan.get("color_equation_sha256")!=reviewed.get("equation_sha256") or equation_signature(layers)!=reviewed.get("equation_sha256"):return failure("executable layers contradict reviewed program equation")
 if reviewed.nonnegative_clamp=="before_common":body+="ink=max(ink,vec4(0.0));\n"
 body+="ink*=common_factor;\n"
 if reviewed.nonnegative_clamp=="after_common":body+="ink.rgb=max(ink.rgb,vec3(0.0));\n"
 body+="ink.a=clamp(ink.a,0.0,1.0);\n"
 var shader:=Shader.new()
 # Diagnostic output selects the same computed alpha for an opaque pixel probe;
 # it is never a substitute for validating the complete original render graph.
 shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
uniform float calculate_color;
uniform float calculate_alpha;
uniform vec4 common_factor;
uniform bool diagnostic_alpha=false;
uniform bool diagnostic_signed_rgb=false;
uniform bool diagnostic_discard=false;
%s
void fragment(){
%s
if(diagnostic_alpha){ALBEDO=vec3(0.25+0.5*ink.a);ALPHA=1.0;}
else if(diagnostic_signed_rgb){ALBEDO=vec3(0.5)+0.25*ink.rgb;ALPHA=1.0;}
else{if(ink.a<0.003921568859368563){discard;}if(diagnostic_discard){ALBEDO=vec3(1.0);ALPHA=1.0;}else{ALBEDO=ink.rgb;ALPHA=ink.a;}}
}
"""%[declarations+("varying vec4 original_uv23;\nvoid vertex(){original_uv23=CUSTOM0;}\n" if uses_custom_uv else ""),body]
 var material:=ShaderMaterial.new();material.shader=shader
 material.set_shader_parameter("calculate_color",float(cc));material.set_shader_parameter("calculate_alpha",float(ca));material.set_shader_parameter("common_factor",context.common_factor)
 for i in 4:
  if layers[i].enabled and layers[i].sample_required:
   for key in ["texture","uv_row0","uv_row1"]:
    material.set_shader_parameter("tex%d"%i if key=="texture" else "uv%d_%s"%[i,key.trim_prefix("uv_")],samples[i][key])
 return {"status":"verified_color_stage","material":material,"rendering_complete":false,"scope":"reviewed decoded texture section; explicit host factors/UV only"}
