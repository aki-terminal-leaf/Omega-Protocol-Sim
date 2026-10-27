# SPDX-License-Identifier: MIT
extends RefCounted
## Applies original-game sampled PAP poses to an existing GLB Skeleton3D.
##
## Source samples are raw MODEL-space translation/rotation/scale per bone (NOT parent-local).
## Each bone's pose is M = T * R * S in the model frame (the GLB instance node, a direct child
## of `root`), applied as a Skeleton3D global pose override. Parent matrices are never
## multiplied, so non-uniform scale does not turn into shear errors. The model node's own
## scale / 180 yaw stay on the node; no world transform is baked into any bone.
##
## Usage: var b := configure(root, sample); if b.ok: seek(b, t); ... clear(b)
## Sample: {bones:[{name,parent}|String], animations:[{name,duration,times:[s],
##   frames:[ per-frame Array(by bone index) | Dictionary(by bone name) of
##   {translation:[3], rotation:[x,y,z,w], scale:[3]} ]  (or tracks:{bone:{translation,rotation,scale}} flat arrays)}]}

const OWNER_META := "_source_animation_owner"
static var _next_id := 1

static func configure(root: Node3D, sample: Dictionary) -> Dictionary:
	var b := {"ok": false, "active": false, "error": "", "diagnostics": {}, "source": {}}
	if root == null or not is_instance_valid(root):
		return _fail(b, "root is null or invalid")
	var parsed := _parse(sample)
	if parsed.has("error"):
		return _fail(b, str(parsed["error"]))
	var names: PackedStringArray = parsed["bones"]

	# Locate the single Skeleton3D containing every source bone (exact names, no guessing).
	var skeletons: Array = []
	_collect(root, skeletons)
	var matches: Array = []
	var best_missing := 1 << 30
	var best_missing_names := PackedStringArray()
	for s in skeletons:
		var missing := PackedStringArray()
		for n in names:
			if (s as Skeleton3D).find_bone(n) < 0:
				missing.append(n)
		if missing.is_empty():
			matches.append(s)
		elif missing.size() < best_missing:
			best_missing = missing.size()
			best_missing_names = missing
	if matches.is_empty():
		var shown := ", ".join(best_missing_names.slice(0, 8)) if not best_missing_names.is_empty() else "no Skeleton3D under root"
		return _fail(b, "no Skeleton3D contains all %d source bones; missing %d (e.g. %s)" % [names.size(), best_missing, shown])
	if matches.size() > 1:
		return _fail(b, "ambiguous: %d skeletons contain all source bones" % matches.size())
	var skel: Skeleton3D = matches[0]
	if not skel.has_method("set_bone_global_pose_override"):
		return _fail(b, "Skeleton3D.set_bone_global_pose_override unavailable in this engine build")
	if skel.has_meta(OWNER_META):
		return _fail(b, "skeleton already owned by another source animation binding")

	# Verify source hierarchy against the existing GLB skeleton where the source states it.
	var parents: Array = parsed["parents"]
	var ids := PackedInt32Array()
	var mismatches := PackedStringArray()
	for i in names.size():
		var id := skel.find_bone(names[i])
		ids.append(id)
		var p = parents[i]
		if p is String:
			var pid := skel.get_bone_parent(id)
			var actual := skel.get_bone_name(pid) if pid >= 0 else ""
			if p != actual and (p == "" or skel.find_bone(p) >= 0):
				mismatches.append("%s: source parent '%s' vs skeleton '%s'" % [names[i], p, actual])
	if not mismatches.is_empty():
		return _fail(b, "bone hierarchy mismatch (%d), e.g. %s" % [mismatches.size(), mismatches[0]])

	# Model frame = root's direct child containing the skeleton (or root itself).
	var frame: Node3D = skel
	while frame.get_parent() != root and frame != root:
		var up := frame.get_parent() as Node3D
		if up == null:
			return _fail(b, "skeleton is not under root through Node3D parents")
		frame = up
	var rel := Transform3D.IDENTITY # model frame -> skeleton local, no world involved
	var node: Node3D = skel
	while node != frame:
		rel = node.transform * rel
		node = node.get_parent() as Node3D
		if node == null:
			return _fail(b, "cannot resolve skeleton transform relative to model frame")

	var players: Array = []
	_collect_players(frame, players)

	var id_val := _next_id
	_next_id += 1
	b["id"] = id_val
	b["skeleton"] = skel
	b["model"] = frame
	b["bone_names"] = names
	b["bone_ids"] = ids
	b["frame_to_skeleton"] = rel.affine_inverse()
	b["times"] = parsed["times"]
	b["pos"] = parsed["pos"]
	b["rot"] = parsed["rot"]
	b["scl"] = parsed["scl"]
	b["player_nodes"] = players
	b["player_states"] = []
	b["source"] = {"name": parsed["name"], "duration": parsed["duration"], "frames": (parsed["times"] as PackedFloat64Array).size(),
		"bones": names.size(), "pose_space": "model", "layout": parsed["layout"]}
	b["diagnostics"] = {
		"skeleton_path": str(root.get_path_to(skel)), "model_frame_path": str(root.get_path_to(frame)),
		"skeleton_bones": skel.get_bone_count(), "unsourced_bones": skel.get_bone_count() - names.size(),
		"resident_players": players.size(), "time_min": (parsed["times"] as PackedFloat64Array)[0],
		"time_max": (parsed["times"] as PackedFloat64Array)[(parsed["times"] as PackedFloat64Array).size() - 1],
		"duration_mismatch": parsed["duration_mismatch"], "last_seek": null}
	b["ok"] = true
	return b

static func seek(binding: Dictionary, seconds: float) -> bool:
	if not binding.get("ok", false):
		return false
	if not is_finite(seconds):
		binding["error"] = "seek time is not finite"
		return false
	var skel = binding.get("skeleton")
	if not is_instance_valid(skel) or not skel.has_meta(OWNER_META) and binding.get("active", false):
		binding["error"] = "skeleton no longer valid or ownership lost"
		return false
	if skel.has_meta(OWNER_META) and skel.get_meta(OWNER_META) != binding["id"]:
		binding["error"] = "skeleton owned by a different binding"
		return false
	var names: PackedStringArray = binding["bone_names"]
	var ids: PackedInt32Array = binding["bone_ids"]
	for i in names.size():
		if ids[i] >= skel.get_bone_count() or skel.get_bone_name(ids[i]) != names[i]:
			binding["error"] = "skeleton bones changed since configure"
			return false

	var times: PackedFloat64Array = binding["times"]
	var count := times.size()
	var t := clampf(seconds, times[0], times[count - 1])
	var lo := 0
	var hi := count
	while lo < hi:
		var m := (lo + hi) >> 1
		if times[m] <= t: lo = m + 1
		else: hi = m
	var i0 := lo - 1
	var i1 := i0
	var f := 0.0
	if i0 < count - 1:
		i1 = i0 + 1
		f = (t - times[i0]) / (times[i1] - times[i0]) # times[i1] > t >= times[i0]

	var bone_total := names.size()
	var pos: PackedVector3Array = binding["pos"]
	var rot: Array = binding["rot"]
	var scl: PackedVector3Array = binding["scl"]
	var to_skel: Transform3D = binding["frame_to_skeleton"]
	var poses: Array = []
	for k in bone_total:
		var a := i0 * bone_total + k
		var c := i1 * bone_total + k
		var tr := pos[a].lerp(pos[c], f)
		var sc := scl[a].lerp(scl[c], f)
		var q: Quaternion = (rot[a] as Quaternion).slerp(rot[c], f).normalized()
		var model_xf := Transform3D(Basis(q) * Basis.from_scale(sc), tr)
		var xf := to_skel * model_xf
		if not _finite_xf(xf):
			binding["error"] = "non-finite pose for bone " + names[k]
			return false
		poses.append(xf)

	if not binding.get("active", false):
		_activate(binding, skel)
	for k in bone_total:
		skel.call("set_bone_global_pose_override", ids[k], poses[k], 1.0, true)
	# Bone-bound VFX reads this same frame even if the retained source rig is hidden.
	if skel.has_method("force_update_all_bone_transforms"):
		skel.call("force_update_all_bone_transforms")
	(binding["diagnostics"] as Dictionary)["last_seek"] = {"requested": seconds, "applied": t, "clamped": t != seconds, "frame_a": i0, "frame_b": i1, "blend": f}
	return true

static func clear(binding: Dictionary) -> void:
	var skel = binding.get("skeleton")
	if binding.get("active", false) and is_instance_valid(skel) and skel.get_meta(OWNER_META, -1) == binding.get("id"):
		var ids: PackedInt32Array = binding["bone_ids"]
		for id in ids:
			if id >= 0 and id < skel.get_bone_count():
				skel.call("set_bone_global_pose_override", id, Transform3D.IDENTITY, 0.0, false)
		skel.remove_meta(OWNER_META)
	if binding.get("active", false):
		for st in binding.get("player_states", []):
			_restore_player(st)
	binding["player_states"] = []
	if binding.get("ok", false) or binding.get("active", false):
		binding["error"] = "cleared"
	binding["active"] = false
	binding["ok"] = false

# --- internals ---

static func _activate(binding: Dictionary, skel: Skeleton3D) -> void:
	skel.set_meta(OWNER_META, binding["id"])
	var states: Array = []
	for p in binding["player_nodes"]:
		if not is_instance_valid(p):
			continue
		var pl: AnimationPlayer = p
		var st := {"player": pl, "active": pl.active, "clip": String(pl.current_animation),
			"position": pl.current_animation_position, "playing": pl.is_playing()}
		if pl.is_playing():
			pl.pause()
		pl.active = false
		states.append(st)
	binding["player_states"] = states
	binding["active"] = true

static func _restore_player(st: Dictionary) -> void:
	var pl = st["player"]
	if not is_instance_valid(pl):
		return
	# A newer animator request belongs to its caller; never rewind it on release.
	var clip: String = st["clip"]
	if String(pl.current_animation) != clip:
		pl.active = st["active"]
		return
	pl.active = st["active"]
	if clip != "" and pl.has_animation(clip):
		pl.play(clip)
		pl.seek(st["position"], true)
		if not st["playing"]:
			pl.pause()

static func _fail(b: Dictionary, msg: String) -> Dictionary:
	b["ok"] = false
	b["error"] = msg
	return b

static func _collect(node: Node, out: Array) -> void:
	if node is Skeleton3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)

static func _collect_players(node: Node, out: Array) -> void:
	if node is AnimationPlayer:
		out.append(node)
	for c in node.get_children():
		_collect_players(c, out)

static func _finite_xf(x: Transform3D) -> bool:
	for v in [x.basis.x, x.basis.y, x.basis.z, x.origin]:
		if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
			return false
	return true

static func _is_num(v) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))

static func _nums(v, n: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if not (v is Array or v is PackedFloat32Array or v is PackedFloat64Array) or v.size() != n:
		return out
	for x in v:
		if not _is_num(x):
			return PackedFloat64Array()
		out.append(float(x))
	return out

## Returns {error} or parsed data. Pose arrays are frame-major: index = frame * bones + bone.
static func _parse(sample: Dictionary) -> Dictionary:
	var raw_bones = sample.get("bones")
	if not raw_bones is Array or raw_bones.is_empty():
		return {"error": "sample.bones missing or empty"}
	var names := PackedStringArray()
	var raw_parents: Array = []
	for e in raw_bones:
		var nm = e.get("name") if e is Dictionary else e
		if not (nm is String or nm is StringName) or str(nm) == "":
			return {"error": "bone entry without a valid name"}
		if names.has(str(nm)):
			return {"error": "duplicate source bone " + str(nm)}
		names.append(str(nm))
		raw_parents.append(e.get("parent") if e is Dictionary else null)
	var parents: Array = []
	for p in raw_parents:
		if p == null:
			parents.append(null) # parent unspecified: not verified
		elif p is String or p is StringName:
			if str(p) != "" and not names.has(str(p)):
				return {"error": "source parent '%s' is not a source bone" % str(p)}
			parents.append(str(p))
		elif _is_num(p):
			var pi := int(p)
			if pi == -1: parents.append("")
			elif pi >= 0 and pi < names.size(): parents.append(names[pi])
			else: return {"error": "source parent index out of range"}
		else:
			return {"error": "unsupported parent value"}

	var anims = sample.get("animations")
	if not anims is Array or anims.is_empty() or not anims[0] is Dictionary:
		return {"error": "sample.animations[0] missing"}
	var anim: Dictionary = anims[0]
	var raw_times = anim.get("times")
	if not raw_times is Array and not raw_times is PackedFloat32Array and not raw_times is PackedFloat64Array:
		return {"error": "animation.times missing"}
	if raw_times.is_empty():
		return {"error": "animation.times empty"}
	var times := PackedFloat64Array()
	for x in raw_times:
		if not _is_num(x) or (not times.is_empty() and float(x) < times[times.size() - 1]):
			return {"error": "animation.times must be finite and non-decreasing"}
		times.append(float(x))
	var duration := 0.0
	if anim.has("duration"):
		if not _is_num(anim["duration"]) or float(anim["duration"]) <= 0.0:
			return {"error": "animation.duration must be finite and > 0"}
		duration = float(anim["duration"])

	var nb := names.size()
	var nf := times.size()
	var pos := PackedVector3Array()
	var rot: Array = []
	var scl := PackedVector3Array()
	var layout := ""
	if anim.get("frames") is Array:
		layout = "frames"
		var frames: Array = anim["frames"]
		if frames.size() != nf:
			return {"error": "frames count %d != times count %d" % [frames.size(), nf]}
		for fi in nf:
			var fr = frames[fi]
			for bi in nb:
				var pose = null
				if fr is Dictionary:
					pose = fr.get(names[bi])
				elif fr is Array and fr.size() == nb:
					pose = fr[bi]
				if not pose is Dictionary:
					return {"error": "frame %d lacks pose for bone %s" % [fi, names[bi]]}
				var r := _push_pose(pose["translation"] if pose.has("translation") else null, pose.get("rotation"), pose.get("scale"), pos, rot, scl)
				if r != "":
					return {"error": "frame %d bone %s: %s" % [fi, names[bi], r]}
	elif anim.get("tracks") is Dictionary:
		layout = "tracks"
		var tracks: Dictionary = anim["tracks"]
		var cols: Array = []
		for bn in names:
			var tk = tracks.get(bn)
			if not tk is Dictionary:
				return {"error": "no track for bone " + bn}
			cols.append(tk)
		for fi in nf:
			for bi in nb:
				var tk: Dictionary = cols[bi]
				var tt := _nums(tk.get("translation"), nf * 3)
				var rr := _nums(tk.get("rotation"), nf * 4)
				var ss := _nums(tk.get("scale"), nf * 3)
				if tt.is_empty() or rr.is_empty() or ss.is_empty():
					return {"error": "track for bone %s has wrong or non-finite sizes" % names[bi]}
				var res := _push_pose(tt.slice(fi * 3, fi * 3 + 3), rr.slice(fi * 4, fi * 4 + 4), ss.slice(fi * 3, fi * 3 + 3), pos, rot, scl)
				if res != "":
					return {"error": "frame %d bone %s: %s" % [fi, names[bi], res]}
	else:
		return {"error": "animation has neither frames nor tracks"}

	var mismatch := duration > 0.0 and absf((times[nf - 1] - times[0]) - duration) > 1e-3
	return {"bones": names, "parents": parents, "times": times, "pos": pos, "rot": rot, "scl": scl,
		"name": str(anim.get("name", "")), "duration": duration, "layout": layout, "duration_mismatch": mismatch}

static func _push_pose(t, r, s, pos: PackedVector3Array, rot: Array, scl: PackedVector3Array) -> String:
	var tv := _nums(t, 3)
	var rv := _nums(r, 4)
	var sv := _nums(s, 3)
	if tv.is_empty(): return "translation must be 3 finite numbers"
	if rv.is_empty(): return "rotation must be 4 finite numbers [x,y,z,w]"
	if sv.is_empty(): return "scale must be 3 finite numbers"
	var q := Quaternion(rv[0], rv[1], rv[2], rv[3])
	if q.length() < 1e-8:
		return "zero-length rotation"
	pos.append(Vector3(tv[0], tv[1], tv[2]))
	rot.append(q.normalized())
	scl.append(Vector3(sv[0], sv[1], sv[2]))
	return ""
