# SPDX-License-Identifier: MIT
extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const TOWER_RADIUS := 6.0
const ORIGIN_RADIUS := 14.0
const BUG_DURATION := 21.0
const ROT_DURATION := 27.0
const CRITICAL_AT := 108.2

static func xy(p: Vector2) -> Array: return [p.x,p.y]

static func route(id: String) -> Dictionary:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/hw_routes.json"))
	if data.routes.has(id): return data.routes[id].duplicate(true)
	var fallback: Dictionary=data.routes.elemental.duplicate(true)
	fallback.id=id; fallback.complete=false; fallback.source_route_audited=false
	fallback.unknown="Unsupported community: explicitly using the Elemental training realization, not a verified regional route."
	return fallback

static func towers(orientation: int, colour: String) -> Array:
	var result: Array=[]
	for angle in [-45.0,45.0,135.0,225.0]:
		result.append({"pos":xy(Rules.direction(angle+orientation*45.0)*ORIGIN_RADIUS),"radius":TOWER_RADIUS,"colour":colour if angle<90 else ("blue" if colour=="red" else "red")})
	return result

static func events(order: Array, orientations: Array, colour: String) -> Array:
	var result: Array=[]
	for round_index in 4:
		var at := 24.0+21.0*round_index
		for kind in ["remote","local"]:
			var slot := posmod((2 if kind=="remote" else 6)-2*round_index,8)
			result.append({"at":at-1.0,"kind":"regression","id":"hw_%s_%d" % [kind,round_index],"regression":kind,"a":int(order[slot]),"b":int(order[slot+1]),"duration":10.0,"status_id":3530 if kind=="remote" else 3529})
		result.append({"at":at,"kind":"towers","round":round_index,"towers":towers(int(orientations[round_index]),colour)})
	result.append({"at":CRITICAL_AT,"kind":"critical_error"})
	result.sort_custom(func(a,b):return float(a.at)<float(b.at))
	return result

# Numeric realization of the documented radial formation, not official coordinates.
static func formation(round_index: int, orientation: int, order: Array) -> Array:
	var points: Array=[]; points.resize(8)
	for side in 2:
		var sign_x := -1.0 if side==0 else 1.0
		var d := Vector2(sign_x*10.960155,-10.960155)
		var s := Vector2(sign_x*5.282728,11.328847)
		var r := Vector2(sign_x*2.598896,12.226845)
		var l := Vector2(sign_x*14.97185,-4.011695) if round_index<3 else Vector2(sign_x*1.1,13.0)
		for item in [[0,d],[2,r],[4,s],[6,l]]:
			points[int(order[posmod(int(item[0])-round_index*2,8)+side])]=(item[1] as Vector2).rotated(deg_to_rad(orientation*45.0))
	return points
