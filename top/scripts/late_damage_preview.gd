# SPDX-License-Identifier: MIT
extends RefCounted
## Separate timed encounter tells from the optional late damage footprint.
## Presentation only: neither changes collision geometry or snapshot timing.
const WINDOW_SECONDS := 0.5
const EPSILON := 0.000001
static func is_telegraph(shape: Dictionary) -> bool:
	return shape.get("cue_type", "") == "telegraph"
static func is_cue(shape: Dictionary) -> bool:
	return is_telegraph(shape) or shape.get("kind", "") == "tower" or shape.get("selectable", false) or shape.get("cue_type", "") in ["marker", "persistent"]
static func in_window(remaining: float) -> bool:
	return remaining >= -EPSILON and remaining <= WINDOW_SECONDS + EPSILON
static func visible(shape: Dictionary, beat: Dictionary, state: Dictionary, elapsed: float, guide := false) -> bool:
	if is_telegraph(shape):
		# An explicit source window is required: never reveal a future source or
		# use a nearby UI checkpoint as its onset/expiry. JSON retries keep it.
		if not shape.has("telegraph_at") or not shape.has("damage_at"): return false
		var now := float(state.get("sim_time", 0))
		return now + EPSILON >= float(shape.telegraph_at) and now <= float(shape.damage_at) + EPSILON
	if is_cue(shape): return true
	if shape.get("instructional", false) and not guide: return false
	if shape.has("damage_at"): return in_window(float(shape.damage_at) - float(state.get("sim_time", 0)))
	# Decorative event previews must identify their own event, not a checkpoint.
	if shape.get("decorative", false): return false
	return in_window(float(beat.get("duration", 0)) - elapsed)
static func shapes(beat: Dictionary, state: Dictionary, elapsed: float, guide := false, upcoming: Array = [], actors: Array = []) -> Array:
	var result: Array = []
	for shape in beat.get("shapes", []):
		if visible(shape, beat, state, elapsed, guide): result.append(shape)
	# Some snapshots are only 0.1/0.4s apart. Their last0.5s starts in the
	# preceding beat; do not shorten the configured window at UI checkpoints.
	var until := maxf(0, float(beat.get("duration", 0)) - elapsed)
	for next in upcoming:
		until += float(next.duration)
		if until > WINDOW_SECONDS + EPSILON: break
		for source in next.get("shapes", []):
			if source.get("decorative", false) or is_cue(source) or (source.get("instructional", false) and not guide): continue
			var shape: Dictionary = source.duplicate(true)
			# A future position snapshot is provisional until it actually locks.
			if shape.has("snapshot_position_actor") and not actors.is_empty(): shape.pos = actors[int(shape.snapshot_position_actor)].pos
			if shape.has("snapshot_direction_actor") and not actors.is_empty():
				var axis: Vector2 = load("res://scripts/rules.gd").v(actors[int(shape.snapshot_direction_actor)].pos) - load("res://scripts/rules.gd").v(shape.get("pos", Vector2.ZERO))
				shape.angle = rad_to_deg(atan2(axis.x, -axis.y))
			result.append(shape)
	return result
