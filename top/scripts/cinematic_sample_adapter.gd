extends RefCounted
# Raw native MODEL poses; clip.index is an identifier, never an array offset.
static func convert(raw: Dictionary, selected: int) -> Dictionary:
	if raw.get("layout") != "Translation4 Scale4 Rotation4" or raw.get("pose_space") != "model (upstream convention)":
		return {"error":"schema/space"}
	var names = raw.get("names")
	var parents = raw.get("parents")
	if not names is Array or not parents is Array or names.is_empty() or parents.size() != names.size() or raw.get("bone_count") != names.size():
		return {"error":"bone dimensions"}
	var bones: Array = []
	var seen: Dictionary = {}
	for i in names.size():
		if not names[i] is String or names[i].is_empty() or seen.has(names[i]): return {"error":"bone names"}
		seen[names[i]] = true
		if not number(parents[i]) or int(parents[i]) != parents[i] or parents[i] < -1 or parents[i] >= names.size(): return {"error":"parent range"}
		bones.append({"name":names[i],"parent":int(parents[i])})
	for i in names.size():
		var chain: Dictionary = {}
		var j: int = i
		while j != -1:
			if chain.has(j): return {"error":"parent cycle"}
			chain[j] = true
			j = int(parents[j])
	if not valid_frame(raw.get("reference_local"), names.size()): return {"error":"reference dimensions/finite"}
	var clips = raw.get("clips")
	if not clips is Array: return {"error":"clips"}
	var found: Dictionary = {}
	var ids: Dictionary = {}
	for clip in clips:
		if not clip is Dictionary or not number(clip.get("index")) or int(clip.index) != clip.index or ids.has(clip.index): return {"error":"clip index"}
		ids[clip.index] = true
		var times = clip.get("times")
		var query = clip.get("native_query_times")
		var frames = clip.get("frames")
		if not times is Array or not query is Array or not frames is Array or times.size()<2 or times.size()!=query.size() or times.size()!=frames.size() or clip.get("bone_count")!=names.size(): return {"error":"clip dimensions"}
		if not number(clip.get("duration")) or clip.duration<=0: return {"error":"duration"}
		for k in times.size():
			if not number(times[k]) or not number(query[k]): return {"error":"finite times"}
			if k>0 and (times[k]<=times[k-1] or query[k]<=query[k-1] or PackedFloat32Array([query[k]])[0]<=PackedFloat32Array([query[k-1]])[0]): return {"error":"strict times"}
			if PackedFloat32Array([times[k]])[0] != PackedFloat32Array([query[k]])[0]: return {"error":"float32 query mismatch"}
			if not valid_frame(frames[k],names.size()): return {"error":"frame dimensions/finite/quaternion"}
		if times[0]!=0 or query[0]!=0 or times[-1]!=clip.duration or query[-1]!=clip.duration: return {"error":"endpoint"}
		if int(clip.index)==selected: found=clip
	if found.is_empty(): return {"error":"selected clip.index absent"}
	var converted: Array = []
	for frame in found.frames:
		var poses: Array = []
		for row in frame:
			poses.append({"translation":row.slice(0,3),"scale":row.slice(4,7),"rotation":row.slice(8,12)})
		converted.append(poses)
	return {"bones":bones,"animations":[{"name":found.name,"duration":found.duration,"times":found.times,"frames":converted}],"native_query_times":found.native_query_times,"clip_index":selected}

static func number(v) -> bool:
	return (v is float or v is int) and is_finite(float(v))

static func valid_frame(f, n: int) -> bool:
	if not f is Array or f.size()!=n: return false
	for row in f:
		if not row is Array or row.size()!=12: return false
		for x in row:
			if not number(x): return false
		if Quaternion(row[8],row[9],row[10],row[11]).length_squared()<1e-16: return false
	return true


