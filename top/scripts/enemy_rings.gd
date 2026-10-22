# SPDX-License-Identifier: MIT
extends RefCounted
## Captured actor hitbox radii; display only, never collision or attack geometry.
const Ring = preload("res://scripts/facing_ring.gd")
static var profiles: Dictionary = {}
static func profile(form: String) -> Dictionary:
	if profiles.is_empty():
		profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_ring_profiles.json")).profiles
	return profiles.get(form, {})
static func attach(root: Node3D, form: String) -> void:
	var info := profile(form)
	if info.is_empty(): return
	var ring := Ring.create(float(info.radius), Color("e59074"))
	ring.set_meta("source_bnpcbase", int(info.bnpcbase))
	root.add_child(ring)
	root.set_meta("ring_profile", form)
static func configure(root: Node3D, entity: Dictionary) -> void:
	# Legacy P4 uses face; all other course entities use facing. Both are north=0/CW.
	root.rotation_degrees.y = -float(entity.get("facing", entity.get("face", 0.0)))
	var ring := root.get_node_or_null("FacingRing")
	if ring == null: return
	var info := profile(str(root.get_meta("ring_profile", "")))
	var radius := float(entity.get("hitbox_radius", info.get("radius", 0.0)))
	if radius <= 0.0 or is_equal_approx(radius, float(ring.get_meta("display_radius"))): return
	# A state-specific radius changes only this display mesh, not the model scale.
	root.remove_child(ring); ring.queue_free()
	var replacement := Ring.create(radius, Color("e59074"))
	replacement.set_meta("source_bnpcbase", int(info.bnpcbase)); root.add_child(replacement)
