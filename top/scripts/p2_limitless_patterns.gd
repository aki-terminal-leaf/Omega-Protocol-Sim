# SPDX-License-Identifier: MIT
extends RefCounted
const R=preload("res://scripts/rules.gd")
static var definitions:Dictionary={}
static func xy(p:Vector2)->Array:return [p.x,p.y]
static func registry()->Dictionary:
	if definitions.is_empty():definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/p2_limitless_routes.json"))
	return definitions
static func route(id:String)->Dictionary:return registry().routes[id].duplicate(true)
static func tank_sources(sources:Array,kind:String)->Array:
	var order:Array=[0,1]
	if kind=="west_east":order.sort_custom(func(a,b):return R.v(sources[a]).x<R.v(sources[b]).x)
	else:order.sort_custom(func(a,b):return R.v(sources[a]).y<R.v(sources[b]).y)
	return order
static func tank_goal(source:Vector2,role:int,route_info:Dictionary,locked_arrow:Dictionary={})->Vector2:
	var preferred:Vector2=Vector2(0,-19.7 if source.y<0 else 19.7) if route_info.pull=="fixed_north_south" else source.normalized().rotated(deg_to_rad(25.0))*19.7
	if locked_arrow.is_empty():return preferred
	var best:=INF;var result:=preferred
	for angle in range(0,360,5):
		var candidate:=R.direction(angle)*19.7
		var expanded:=locked_arrow.duplicate(true);expanded.width=10.4
		if R.contains(expanded,candidate,[]):continue
		var toward:Vector2=(candidate-source).normalized()
		if toward.dot((-source).normalized())>cos(deg_to_rad(52.0)):continue
		var score:=candidate.distance_squared_to(preferred)
		if route_info.pull=="fixed_north_south" and candidate.y*source.y<0:score+=10000.0
		if score<best:best=score;result=candidate
	return result
static func cone(source:Vector2,target:int)->Dictionary:
	return {"kind":"cone","pos":xy(source),"target":target,"width":90.0,"radius":100.0,"name":"Optimized Bladedance"}
static func arrow(source:Vector2,target:Vector2)->Dictionary:
	var delta:=target-source
	return {"kind":"line","pos":xy(source),"angle":rad_to_deg(delta.angle())+90.0,"direction":xy(delta.normalized()),"width":10.0,"length":100.0,"name":"Optimized Sagittarius Arrow"}
static func jump_source(source:Vector2,target:Vector2)->Vector2:
	return target+(source-target).normalized()*minf(5.5,source.distance_to(target))
static func events()->Array:
	return [{"kind":"arrow_lock","at":5.45},{"kind":"arrow","at":13.45},{"kind":"bladedance","at":13.55},{"kind":"flare_markers","at":19.3},{"kind":"defense","at":24.65},{"kind":"flares","at":27.45},{"kind":"pitch","at":27.8},{"kind":"raidwide","at":38.0}]
static func party_goal(c:Dictionary,locked_arrow:Dictionary)->Vector2:
	# Route goals are coaching only. The judge never calls this function.
	var synthetic:Array=[]
	for i in 8:synthetic.append({"pos":Vector2.ZERO})
	var cones:Array=[]
	var assignment:=tank_sources(c.sources,str(c.route.tank_order))
	for role in 2:
		var source:=R.v(c.sources[int(assignment[role])])
		synthetic[role].pos=tank_goal(source,role,c.route,locked_arrow)
		cones.append(cone(source,role))
	if absf(R.v(c.arrow_source).x)<0.1 and c.route.get("pole_arrow_dodge","") in ["tether_number","boss_left_right"]:
		var candidates:Array=[]
		if c.route.pole_arrow_dodge=="tether_number":
			for source in c.sources:candidates.append(R.v(source).normalized()*13.0)
		else:candidates=[Vector2(-6.5,0),Vector2(6.5,0)]
		candidates.sort_custom(func(a,b):return a.distance_squared_to(R.v(c.route.bait))<b.distance_squared_to(R.v(c.route.bait)))
		for point in candidates:
			var expanded:Dictionary=locked_arrow.duplicate(true);expanded.width=10.4
			if R.contains(expanded,point,synthetic):continue
			if cones.any(func(shape):return R.contains(shape,point,synthetic)):continue
			return point
	var best:=INF;var result:=Vector2.ZERO
	for y in range(-15,16):
		for x in range(-15,16):
			var point:=Vector2(x,y)
			if point.length()>15.0:continue
			var expanded:=locked_arrow.duplicate(true);expanded.width=10.4
			if R.contains(expanded,point,synthetic):continue
			var safe:=true
			for shape in cones:
				var margin:Dictionary=shape.duplicate(true);margin.width=92.0
				if R.contains(margin,point,synthetic):safe=false
			if not safe:continue
			# Source guides prefer the hitbox; otherwise the numbered tether lane.
			var score:=point.length_squared()*8.0+point.distance_squared_to(R.v(c.route.bait))
			if point.length()>4.1:score+=1000.0
			if c.route.party_dodge=="perpendicular_lane":score+=point.distance_squared_to(R.v(c.route.bait))*0.5
			if score<best:best=score;result=point
	return result
