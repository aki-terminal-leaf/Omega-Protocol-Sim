# SPDX-License-Identifier: MIT
extends RefCounted
## Mechanic facts only. Coordinates in persistent events are JSON arrays.
static func xy(p: Vector2) -> Array: return [p.x,p.y]
static func sorted(events: Array) -> void:
	events.sort_custom(func(a,b): return float(a.at)<float(b.at))
static func beam(target: int) -> Dictionary:
	return {"kind":"line","pos":[0,0],"target":target,"width":6.0,"length":50.0,"name":"Wave Cannon Kyrios"}
static func panto(order: Array, orientation: int, direction: int, facing := 0.0) -> Array:
	assert(orientation>=0 and orientation<6 and direction in [-1,1])
	var events: Array=[]
	for n in 14:
		for side in 2:
			events.append({"kind":"hazard","ability_id":31501 if n==0 else 32368,"at":6.1+2*n,"pulse":n,"shape":{"kind":"cone","pos":[0,0],"angle":facing+orientation*30+direction*n*30+side*180,"width":60.0,"radius":65.0,"name":"Flamethrower"}})
	for n in 10: events.append({"kind":"bait","ability_id":31500,"at":9.7+2*n,"bait":n,"delay":3.0,"radius":5.0})
	for n in 4:
		var beam_number: int=[3,4,1,2][n]
		events.append({"kind":"missile_beam","missile_id":31502,"beam_id":31503,"at":12.1+6*n,"number":n+1,"missiles":order.slice(n*2,n*2+2),"beams":order.slice((beam_number-1)*2,beam_number*2),"beam_number":beam_number})
	sorted(events)
	return events
static func cannons(marked: Array, lead := 6.0) -> Array:
	marked=marked.map(func(i):return int(i))
	var events: Array=[]
	for t in [0.0,2.1,4.1,6.2,8.3]: events.append({"kind":"cleaves","ability_id":31504,"at":lead+t})
	var other: Array=[]
	for i in range(2,8):
		if i not in marked: other.append(i)
	events.append({"kind":"proteans","ability_id":31505,"at":lead,"targets":marked.duplicate()})
	events.append({"kind":"proteans","ability_id":31505,"at":lead+9.0,"targets":other})
	sorted(events)
	return events
