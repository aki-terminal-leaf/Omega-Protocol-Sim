# SPDX-License-Identifier: MIT
extends RefCounted
const Rules = preload("res://scripts/rules.gd")
static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/p4_wave_routes.json"))
static func route(id: String) -> Dictionary:
	for item in data().profiles:
		if item.id == id: return item.duplicate(true)
	assert(false,"Unknown P4 route: "+id)
	return {}
static func pairs() -> Array:
	var result: Array=[]
	for a in 8:
		for b in range(a+1,8): result.append([a,b])
	return result
static func xy(p: Vector2) -> Array: return [p.x,p.y]
static func sorted(events: Array) -> Array:
	events.sort_custom(func(a,b):return float(a.at)<float(b.at))
	return events
static func beam(origin: Vector2, target: Vector2) -> Dictionary:
	return {"kind":"line","pos":xy(origin),"angle":rad_to_deg((target-origin).angle())+90.0,"width":6.0,"length":100.0,"start":0.0,"name":"Wave Cannon"}
static func groups(route_data: Dictionary, targets: Array) -> Array:
	var west: Array=route_data.west.map(func(i):return int(i))
	var east: Array=route_data.east.map(func(i):return int(i))
	var marked: Array=targets.map(func(i):return int(i))
	for side in [west,east]:
		if marked.all(func(i):return i in side):
			var lower: int=marked[0] if side.find(marked[0])>side.find(marked[1]) else marked[1]
			var opposite: Array=east if side==west else west
			var melee: int=opposite[-1]
			side[side.find(lower)]=melee
			opposite[opposite.find(melee)]=lower
			break
	return [west,east]
static func events(target_pairs: Array, family: int) -> Array:
	assert(target_pairs.size()==3 and family>=0 and family<4)
	var timing: Dictionary=data().families[family]
	var result: Array=[]
	for cycle in 3:
		assert(target_pairs[cycle].size()==2 and target_pairs[cycle][0]!=target_pairs[cycle][1])
		result.append({"at":timing.markers[cycle],"kind":"markers","targets":target_pairs[cycle].duplicate(),"cycle":cycle})
		result.append({"at":timing.proteans[cycle],"kind":"protean","repeat_at":timing.repeat[cycle],"cycle":cycle,"origin":[0,0]})
		result.append({"at":timing.stacks[cycle],"kind":"stack","cycle":cycle,"origin":[0,0]})
	for i in 8:
		var pulse := i%4
		result.append({"at":timing.rings[i],"kind":"ring","sequence":i/4,"pulse":pulse,"shape":{"kind":"circle" if pulse==0 else "donut","pos":[0,0],"inner":pulse*6.0,"radius":(pulse+1)*6.0,"name":"Wave Repeater %d"%(i+1)}})
	return sorted(result)
