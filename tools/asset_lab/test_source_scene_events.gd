extends SceneTree
const State = preload("res://source_scene_events.gd")
var failures: Array = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cases = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var results: Array = []
	for c in cases:
		var s = State.new()
		var r: Dictionary = s.begin(c.record,c.target,7)
		check(not r.has("error"),"begin")
		if r.has("error"): continue
		check(r.namespace == c.record.namespace,"namespace")
		if c.record.source_event.tag == "C018":
			check(r.scale[0] == 2.0 and r.scale[1] == 3.0 and r.scale[2] == 4.0,"scale")
			var q = r.quaternion_xyzw
			var v = [0.3,-2.0,4.0]
			var tx = 2*(q[1]*v[2]-q[2]*v[1])
			var ty = 2*(q[2]*v[0]-q[0]*v[2])
			var tz = 2*(q[0]*v[1]-q[1]*v[0])
			var rotated = [v[0]+q[3]*tx+q[1]*tz-q[2]*ty,v[1]+q[3]*ty+q[2]*tx-q[0]*tz,v[2]+q[3]*tz+q[0]*ty-q[1]*tx]
			for i in 3: check(abs(rotated[i]-c.vector[i]) < 1e-10,"independent vector")
		else:
			check(r.decoded.ratio.status == c.ratio.status,"ratio status")
			if c.ratio.status != "nan": check(r.decoded.ratio.bits == c.ratio.bits,"ratio bits")
			check(r.descriptor.unknown_padding == [20,21,22,23,25,26,27],"initial padding")
			check(r.state_byte == ((0xCF & ~0x20) | 0x10 | (int(r.decoded.selector) << 5)),"state bits")
			check(r.descriptor.writes[4].width == 1 and r.descriptor.writes[2].width == 8,"initial widths")
			var gate = r.decoded.threshold_f32.value
			if gate == 10:
				check(s.update(1,c.target,7).type == "no_request","duration1 retention")
			check(s.update(gate,c.target,7).type == "no_request","strict equality")
			check(s.update(NAN,c.target,7).has("error"),"NaN clock")
			check(s.update(INF,c.target,7).has("error"),"infinite clock")
			check(s.update(gate-256,c.target,7).has("error"),"rewind")
			var later = s.update(gate+256,c.target,7)
			check(later.type == "queued_action_request" and later.request_type == 32 and later.generic_parser_bypassed,"queued override")
			check(later.descriptor.unknown_padding == [2,3,10,11],"later padding")
			check(later.descriptor.writes[0].width == 2 and later.descriptor.writes[2].width == 2 and later.descriptor.writes[3].width == 8,"later widths")
			check(later.descriptor.writes[4].offset == 20 and later.descriptor.writes[4].value == r.decoded.later_arg,"later argument")
			check(s.update(gate+512,c.target,7).type == "no_request","one shot")
			r["later"] = later
		results.append(r)
		check(s.begin(c.record,{},7).has("error") and s.target.is_empty(),"transactional missing target")
		s.begin(c.record,c.target,7)
		var stale = c.target.duplicate(true)
		stale.token = "remap"
		check(s.update(11,stale,7).has("error") and s.target.is_empty(),"remap")
		s.reset()
		check(s.event.is_empty(),"reset")
		var bad = c.record.duplicate(true)
		bad.source_event.sha256 = "bad"
		check(s.begin(bad,c.target,7).has("error"),"hash")
		bad = c.record.duplicate(true)
		bad.namespace[1] += 1
		check(s.begin(bad,c.target,7).has("error"),"TMLB collision")
		var other_target = c.target.duplicate(true)
		other_target.namespace = bad.namespace.duplicate()
		check(not s.begin(bad,other_target,7).has("error"),"distinct TMLB identity")
		bad = c.record.duplicate(true)
		bad.source_event.tag = "C040"
		check(s.begin(bad,c.target,7).has("error"),"unsupported tag")
		if c.record.source_event.tag == "C196":
			bad = c.record.duplicate(true)
			var bytes: PackedByteArray = bad.source_event.raw_hex.hex_decode()
			bytes.encode_u32(20,2)
			bad.source_event.raw_hex = bytes.hex_encode()
			var hash_context := HashingContext.new()
			hash_context.start(HashingContext.HASH_SHA256)
			hash_context.update(bytes)
			bad.source_event.sha256 = hash_context.finish().hex_encode()
			check(s.begin(bad,c.target,7).has("error") and s.target.is_empty(),"selector invalid")
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"results":results,"count":results.size()}))
	file.close()
	quit(0 if failures.is_empty() else 1)
