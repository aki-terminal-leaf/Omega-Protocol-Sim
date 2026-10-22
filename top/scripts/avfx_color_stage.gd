# SPDX-License-Identifier: MIT
extends RefCounted
## Executable reviewed texture section only. No invented host/UV/default factors.
## No global caches: the caller owns the returned material and all bound textures.
const WEIGHTS=[0.298911988735199,0.5866109728813171,0.11447799950838089]
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
static func create(plan:Dictionary,context:Dictionary)->Dictionary:
 if plan.get("status")!="verified_color_stage" or plan.get("rendering_complete")!=false:return failure("reviewed color section required")
 var layers:Variant=plan.get("layers")
 if not layers is Array or layers.size()!=4:return failure("exactly four ordered layers required")
 var cc:Variant=context.get("calculate_color");var ca:Variant=context.get("calculate_alpha")
 if not (cc is float or cc is int) or not (ca is float or ca is int) or not is_finite(float(cc)) or not is_finite(float(ca)):return failure("finite explicit CalculateColor/Alpha required")
 if not rgba(context.get("common_factor")):return failure("explicit combined vertex/document/model factor required")
 if not context.has("model_fresnel_included") or not context.model_fresnel_included is bool:return failure("explicit model-factor provenance required")
 if plan.get("requires_model_fresnel",false) and not context.model_fresnel_included:return failure("model Fresnel factor not supplied")
 var samples:Variant=context.get("samples")
 if not samples is Array or samples.size()!=4:return failure("four explicit sample contexts required")
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
   if not (source is int or source is float) or (source!=0 and source!=1):return failure("only explicit mesh UV/UV2 inputs supported")
   if sample.get("filter") not in ["nearest","linear"] or sample.get("wrap") not in ["repeat","clamp"]:return failure("unreviewed sampler state")
   if not sample.get("decoded_samples") is bool or not sample.decoded_samples:return failure("explicit decoded numeric samples required")
   declarations+="uniform sampler2D tex%d:filter_%s,%s;\nuniform vec3 uv%d_row0;\nuniform vec3 uv%d_row1;\n"%[i,sample.filter,"repeat_enable" if sample.wrap=="repeat" else "repeat_disable",i,i]
   var uv:="UV" if sample.uv_source==0 else "UV2"
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
 var shader:=Shader.new()
 # Diagnostic output selects the same computed alpha for an opaque pixel probe;
 # it is never a substitute for validating the complete original render graph.
 shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
uniform float calculate_color;
uniform float calculate_alpha;
uniform vec4 common_factor;
uniform bool diagnostic_alpha=false;
%s
void fragment(){
%s
ink*=common_factor;
ink.rgb=max(ink.rgb,vec3(0.0));ink.a=clamp(ink.a,0.0,1.0);
if(diagnostic_alpha){ALBEDO=vec3(0.25+0.5*ink.a);ALPHA=1.0;}
else{if(ink.a<1.0/255.0){discard;}ALBEDO=ink.rgb;ALPHA=ink.a;}
}
"""%[declarations,body]
 var material:=ShaderMaterial.new();material.shader=shader
 material.set_shader_parameter("calculate_color",float(cc));material.set_shader_parameter("calculate_alpha",float(ca));material.set_shader_parameter("common_factor",context.common_factor)
 for i in 4:
  if layers[i].enabled and layers[i].sample_required:
   for key in ["texture","uv_row0","uv_row1"]:
    material.set_shader_parameter("tex%d"%i if key=="texture" else "uv%d_%s"%[i,key.trim_prefix("uv_")],samples[i][key])
 return {"status":"verified_color_stage","material":material,"rendering_complete":false,"scope":"reviewed decoded texture section; explicit host factors/UV only"}
