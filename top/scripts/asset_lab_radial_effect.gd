extends RefCounted
## Numeric source descriptor only: no inferred convolution/projection/blend law.
const Curves = preload("res://scripts/avfx_animation.gd")
const F32_MAX = 3.402823466e38
const FIELDS = ["Len","Str","Gra","IRad","ORad","FSDc","FEDc","FaBP"]
static func number(v: Variant) -> bool:
 return (v is int or v is float) and is_finite(float(v)) and absf(float(v)) <= F32_MAX
static func evaluate(node: Dictionary, age: float, key: String) -> Dictionary:
 var failed := {"kind":"radial_blur","descriptor_valid":false,"rendering_accepted":false,"reason":"invalid radial source","key":key}
 if not number(age) or age < 0: failed.reason="invalid numeric age";return failed
 var values: Variant = node.get("values")
 var data: Variant = node.get("data")
 if not values is Dictionary or not data is Dictionary: failed.reason="missing source dictionaries";return failed
 if values.get("EfVT") != 7 or data.get("radial_schema") != 1: failed.reason="wrong effector type/schema";return failed
 if not data.get("presence") is Dictionary or not data.get("unknown_fields") is Array or not data.get("random_fields") is Array: failed.reason="missing presence/unknown/random metadata";return failed
 if not data.unknown_fields.is_empty() or not data.random_fields.is_empty(): failed.reason="unknown or random source fields";return failed
 for field in ["bAOV","bAGm","LpSt","LpEd","RoOT","CCOT"]:
  if not number(values.get(field)): failed.reason="missing/nonfinite source field";return failed
  if float(values[field]) != floor(float(values[field])): failed.reason="noninteger source field";return failed
 if int(values.bAOV) not in [0,1] or int(values.bAGm) not in [0,1] or values.LpEd > values.LpSt: failed.reason="invalid scope or unsupported effector loop";return failed
 var parameters := {}
 var absent: Array = []
 for field in FIELDS:
  if not data.presence.has(field) or not data.presence[field] is bool: failed.reason="missing presence flag";return failed
  if data.presence[field] != data.has(field): failed.reason="presence/data mismatch";return failed
  if not data.presence[field]:
   absent.append(field)
   if field != "IRad": failed.reason="missing required radial field";return failed
   continue
  if field in ["FSDc","FEDc","FaBP"]:
   if not number(data[field]): failed.reason="nonfinite/f32 overflow scalar";return failed
   if field == "FaBP" and float(data[field]) != floor(float(data[field])): failed.reason="noninteger fade base point";return failed
   parameters[field] = data[field]
  else:
   var curve: Variant = data[field]
   if not curve is Dictionary or curve.get("kind") != "scalar" or curve.get("random_role") != false: failed.reason="wrong curve type";return failed
   if not curve.get("keys") is Array or curve.keys.is_empty(): failed.reason="missing curve keys";return failed
   for item in curve.keys:
    if not item is Dictionary or not number(item.get("time")) or not number(item.get("type")): failed.reason="invalid curve key";return failed
    if float(item.time)!=floor(float(item.time)) or float(item.type)!=floor(float(item.type)): return failed
    if not item.get("data") is Array or item.data.size() != 3: failed.reason="invalid key data width";return failed
    for n in item.data:
     if not number(n): failed.reason="nonfinite/f32 overflow key";return failed
   if not curve.get("unknown_fields") is Array: return failed
   for mode in ["BvPr","BvPo","RanT"]:
    if not number(curve.get(mode)) or float(curve[mode])!=floor(float(curve[mode])): return failed
   var sampled: Variant = Curves.value(curve,age)
   if not number(sampled): failed.reason="unsupported/nonfinite sampled curve";return failed
   parameters[field] = sampled
 if data.get("absent_fields") != absent: failed.reason="absent-field mismatch";return failed
 return {"kind":"radial_blur","descriptor_valid":true,"rendering_accepted":false,"key":key,"emitter_age":age,"parameters":parameters,"presence":data.presence.duplicate(true),"absent_fields":absent,"source_fields":values.duplicate(true),"payload_sha256":data.get("payload_sha256",""),"scope":{"bAOV":int(values.bAOV),"bAGm":int(values.bAGm)},"unresolved":["native radial convolution, projection and blending","IRad absent default/serialization","native host scope and post-effect lifetime","numeric units to seconds"]}
