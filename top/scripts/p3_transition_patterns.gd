# SPDX-License-Identifier: MIT
extends RefCounted
## Original implementation. Geometry/timing evidence is data, not copied behavior code.
const Rules = preload("res://scripts/rules.gd")
static var cache: Dictionary = {}
static func data() -> Dictionary:
	if cache.is_empty(): cache = JSON.parse_string(FileAccess.get_file_as_string("res://data/p3_transition_routes.json"))
	return cache
static func xy(p: Vector2) -> Array: return [p.x,p.y]
static func route(id: String) -> Dictionary: return data().routes[id].duplicate(true)
static func sort_events(events: Array) -> void:
	events.sort_custom(func(a,b): return float(a.at)<float(b.at) or (float(a.at)==float(b.at) and int(a.serial)<int(b.serial)))
static func valid_partition(purple: Array, white: Array) -> bool:
	if purple.size()!=4 or white.size()!=2: return false
	var seen: Array=[]
	for a in purple+white:
		if float(a)!=int(a) or int(a)<0 or int(a)>7 or int(a) in seen: return false
		seen.append(int(a))
	return true
static func family(arm_first: int, sample_index: int, purple: Array, white: Array) -> Dictionary:
	assert(arm_first in [0,1] and sample_index>=0 and sample_index<4 and valid_partition(purple,white))
	var sample: Dictionary=data().samples[sample_index]
	# T0 is debuff application; original first ring cast starts ~0.089s later.
	var shift: float=-float(sample.debuff_gain)
	var observed_north_first: bool=Rules.v(sample.arms[0].pos).y < -13.0
	var rotate: bool=observed_north_first!=(arm_first==0)
	var arms: Array=[]
	for i in 6:
		var a: Dictionary=sample.arms[i].duplicate(true)
		if rotate: a.pos=xy(-Rules.v(a.pos))
		a.at=float(a.at)+shift; a.cue_at=float(a.at)-13.5; a.id="p3_transition_arm_%d"%i
		a.cast_at=float(a.cast_at)+shift
		a.wave=0 if i<3 else 1
		arms.append(a)
	var rings: Array=sample.rings.map(func(t):return float(t)+shift)
	return {"arm_first":arm_first,"sample_index":sample_index,"sample_id":sample.id,"arms":arms,"rings":rings,"sniper":float(sample.sniper)+shift,"purple":purple.map(func(a):return int(a)),"white":white.map(func(a):return int(a)),"void_start":6.1+shift,"void_end":21.4+shift,"duration":23.1+shift}
static func events(f: Dictionary) -> Array:
	var result: Array=[{"kind":"marks","at":0.0,"purple":f.purple.duplicate(),"white":f.white.duplicate(),"expires":f.sniper}]
	for i in 8:
		var ring: int=i%4
		result.append({"kind":"ring","at":f.rings[i],"ability_id":31567+ring,"sequence":i/4,"ring":ring,"shape":{"kind":"circle" if ring==0 else "donut","pos":[0,0],"inner":ring*6.0,"radius":(ring+1)*6.0}})
	for a in f.arms:
		result.append({"kind":"arm_cue","at":a.cue_at,"entity":a.duplicate(true)})
		result.append({"kind":"arm_cast","at":a.cast_at,"id":a.id})
		result.append({"kind":"arm_hit","at":a.at,"id":a.id,"ability_id":31566})
	result.append({"kind":"sniper","at":f.sniper,"ability_ids":[31571,31572]})
	for i in result.size(): result[i].serial=i
	sort_events(result)
	return result
