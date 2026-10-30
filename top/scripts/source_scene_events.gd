extends RefCounted
## Native coordinates and typed requests only. Caller owns resolution and time.
var event: Dictionary = {}
var target: Dictionary = {}
var attempted := false
var last_clock = null

func reset() -> void:
	event = {}
	target = {}
	attempted = false
	last_clock = null

static func f32(v: float) -> float:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, v)
	return b.decode_float(0)

static func scalar(v: float) -> Dictionary:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, v)
	v = b.decode_float(0)
	return {"bits": b.hex_encode(), "status": "nan" if is_nan(v) else ("infinite" if is_inf(v) else "finite"), "value": v if is_finite(v) else null}

static func descriptor(size: int, fields: Array) -> Dictionary:
	var mask: Array = []
	mask.resize(size)
	mask.fill(false)
	var writes: Array = []
	for field in fields:
		var width: int = {"u8":1,"u16":2,"u32":4,"u64":8,"f32":4}[field[1]]
		for i in range(field[0], field[0] + width):
			mask[i] = true
		writes.append({"offset":field[0],"type":field[1],"width":width,"value":field[2]})
	var unknown: Array = []
	for i in size:
		if not mask[i]: unknown.append(i)
	return {"writes":writes,"valid_bytes":mask,"unknown_padding":unknown}

func fail(message: String, record: Dictionary) -> Dictionary:
	reset()
	return {"error":message,"source_event":record.get("source_event",{}),"namespace":record.get("namespace",[])}

func output(result: Dictionary) -> Dictionary:
	result["source_event"] = event.source_event.duplicate(true)
	result["namespace"] = event.namespace.duplicate(true)
	result["decoded"] = event.duplicate(true)
	result["target"] = target.duplicate(true)
	return result

func begin(record: Dictionary, resolved: Dictionary, epoch) -> Dictionary:
	reset()
	var e: Dictionary = record.get("source_event", {})
	var ns: Array = record.get("namespace", [])
	if e.get("tag") not in ["C018","C196"]: return fail("unsupported tag",record)
	if ns.size() != 8 or str(ns[0]).length() != 64: return fail("namespace",record)
	for i in range(1,8):
		if not (ns[i] is int or ns[i] is float) or ns[i] < 0 or ns[i] != int(ns[i]): return fail("namespace integer",record)
	var raw: PackedByteArray = str(e.get("raw_hex", "")).hex_decode()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(raw)
	if raw.size() != 56 or hash_context.finish().hex_encode() != e.get("sha256"): return fail("raw length/hash",record)
	if raw.slice(0,4).get_string_from_ascii() != e.tag or raw.decode_u32(4) != 56 or e.get("size") != 56 or raw.decode_u16(8) != e.get("id") or raw.decode_u16(10) != e.get("time_u16") or raw.decode_u16(12) != e.get("duration_u16") or ns[6] != e.id or ns[7] != e.offset: return fail("framing",record)
	if not resolved.get("verified",false) or not resolved.get("token") or not resolved.get("context") or resolved.get("epoch") != epoch or resolved.get("namespace") != ns: return fail("source-resolved target required",record)
	event = record.duplicate(true)
	event["raw_words_le"] = []
	for i in range(0,56,4): event.raw_words_le.append(raw.slice(i,i+4).hex_encode())
	event["provenance"] = "native-contracts.md + PARENT_CORRECTIONS.md; finite reference arithmetic, not native bit equivalence"
	target = resolved.duplicate(true)
	if e.tag == "C018":
		var values: Array = []
		for i in range(20,56,4):
			var v := raw.decode_float(i)
			if not is_finite(v): return fail("nonfinite C018",record)
			values.append(v)
		var scale = resolved.get("current_native_scale")
		if not scale is Array or scale.size() != 3: return fail("current native scale required",record)
		for v in scale:
			if not (v is float or v is int) or not is_finite(v): return fail("invalid scale",record)
		event["position"] = values.slice(0,3)
		event["euler"] = values.slice(3,6)
		event["archived_scale"] = values.slice(6,9)
		var sx := sin(values[3]/2.0)
		var sy := sin(values[4]/2.0)
		var sz := sin(values[5]/2.0)
		var cx := cos(values[3]/2.0)
		var cy := cos(values[4]/2.0)
		var cz := cos(values[5]/2.0)
		return output({"type":"native_transform_reference","position":event.position,"scale":scale.duplicate(),"quaternion_xyzw":[sx*cy*cz-cx*sy*sz,cx*sy*cz+sx*cy*sz,cx*cy*sz-sx*sy*cz,cx*cy*cz+sx*sy*sz]})
	var selector := raw.decode_u32(20)
	if selector not in [0,1]: return fail("unsupported selector",record)
	var numerator := raw.decode_float(24)
	var denominator := raw.decode_float(28)
	var ratio: float
	if is_nan(numerator) or is_nan(denominator) or (numerator == 0 and denominator == 0) or (is_inf(numerator) and is_inf(denominator)):
		ratio = NAN
	elif denominator == 0:
		ratio = -INF if ((raw.decode_u32(24) ^ raw.decode_u32(28)) & 0x80000000) else INF
	else: ratio = numerator / denominator
	event.merge({"selector":selector,"numerator":scalar(numerator),"denominator":scalar(denominator),"ratio":scalar(ratio),"initial_arg":raw.decode_u32(32),"later_arg":raw.decode_u32(36),"threshold":raw.decode_s32(40),"threshold_f32":scalar(raw.decode_s32(40))})
	var result := {"type":"initial_scheduler_request","sheet":792,"row":12+selector,"descriptor":descriptor(40,[[0,"u32",12+selector],[4,"u32",0],[8,"u64",0],[16,"f32",event.ratio],[24,"u8",0],[28,"f32",event.denominator],[32,"u32",event.initial_arg],[36,"u32",0]])}
	if resolved.has("state_byte"):
		var state = resolved.state_byte
		if state != int(state) or state < 0 or state > 255: return fail("state byte",record)
		result["state_byte"] = (int(state) & ~0x20) | 0x10 | (selector << 5)
	return output(result)

func update(clock: float, resolved: Dictionary, epoch) -> Dictionary:
	if event.is_empty(): return {"error":"not configured","namespace":[],"source_event":{}}
	if resolved != target or epoch != target.epoch: return fail("stale/remapped target",event.duplicate(true))
	clock = f32(clock)
	if not is_finite(clock) or (last_clock != null and clock < last_clock):
		return output({"error":"nonfinite/rewind; explicit reset required"})
	last_clock = clock
	if event.source_event.tag != "C196" or attempted or clock <= event.threshold_f32.value: return output({"type":"no_request","attempted":attempted})
	attempted = true
	var result := {"type":"queued_action_request","request_type":32,"row_override":10+event.selector,"row_override_present":1,"explicit_target_argument":null,"generic_parser_bypassed":true,"attempted":true,"descriptor":descriptor(28,[[0,"u16",0],[4,"f32",scalar(1)],[8,"u16",0],[12,"u64",0],[20,"u32",event.later_arg],[24,"u32",0]])}
	if target.has("state_byte"): result["state_byte"] = (int(target.state_byte) & ~0x20) | 0x10 | (int(event.selector) << 5)
	return output(result)
