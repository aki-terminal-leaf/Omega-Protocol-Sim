# SPDX-License-Identifier: MIT
extends RefCounted
## Original Delta event specification. Durable values are JSON-native.
const R = preload("res://scripts/rules.gd")

static func xy(p: Vector2) -> Array: return [p.x,p.y]
static func turn(p: Vector2, eye: float) -> Array: return xy(p.rotated(deg_to_rad(eye)))
static func sorted(events: Array) -> Array:
	events.sort_custom(func(a,b): return float(a.at)<float(b.at) if not is_equal_approx(float(a.at),float(b.at)) else int(a.get("sequence",0))<int(b.get("sequence",0)))
	return events

static func parameters() -> Dictionary:
	return {
		"local_distance":10.0,"remote_distance":10.0,
		"distance_provenance":"Provisional 10y model. Interpolated break samples support order of magnitude, not exact thresholds; see DELTA_FIDELITY.md.",
		"fist_chase_speed":6.0,"fist_chase_provenance":"Explicit unmeasured NPC motion parameter; not server speed.",
		"fist_overlap_distance":3.0,"fist_overlap_provenance":"Provisional center-in-opposite-radius criterion; exact collision tolerance unmeasured.",
		"patch_ruin":0.96,"patch_magic":0.96,"world_vulnerability":5.0,
		"monitor_magic":4.96,"twice_ruin":6.96,"contact_step":0.02}

static func route(id: String) -> Dictionary:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/p5_delta_routes.json"))
	assert(data.routes.has(id),"Unknown Delta route; no silent regional fallback")
	return data.routes[id].duplicate(true)

static func assignment(order: Array, near_side := 0, far_side := 0, near_pair := 0) -> Dictionary:
	assert(order.size()==8)
	var ids: Array=[]
	for a in order:
		assert(int(a)>=0 and int(a)<8 and int(a) not in ids)
		ids.append(int(a))
	var pairs: Array=[]
	for i in 4: pairs.append({"id":"delta_pair_%d"%i,"a":ids[2*i],"b":ids[2*i+1],"kind":"remote" if i<2 else "local","status_id":1673 if i<2 else 1672})
	return {"order":ids,"pairs":pairs,"near":ids[2*near_pair+near_side],"far":ids[2*(1-near_pair)+far_side]}

static func valid_assignment(a: Dictionary) -> bool:
	var used: Array=[]; var blue: Array=[]; var green := 0
	for pair in a.get("pairs",[]):
		for value in [pair.a,pair.b]:
			var actor:=int(value)
			if actor<0 or actor>=8 or actor in used: return false
			used.append(actor)
		if pair.kind=="remote": blue.append([int(pair.a),int(pair.b)])
		elif pair.kind=="local": green+=1
		else: return false
	if used.size()!=8 or blue.size()!=2 or green!=2: return false
	var near_pair := -1; var far_pair := -1
	for i in 2:
		if int(a.near) in blue[i]: near_pair=i
		if int(a.far) in blue[i]: far_pair=i
	return near_pair>=0 and far_pair>=0 and near_pair!=far_pair

static func fist_families() -> Array:
	# Each tether-colour group contains two fists of each colour. Enumerate
	# all six arrangements per group rather than force a guide's example.
	var choices: Array=[]
	for mask in 16:
		var colours: Array=[]; var total:=0
		for bit in 4:
			var colour: int=(mask>>bit)&1; colours.append(colour); total+=colour
		if total==2: choices.append(colours)
	var result: Array=[]
	for blue in choices:
		for green in choices: result.append(blue+green)
	return result

static func config(a: Dictionary, eye := 0.0, safe := 1, monitor_side := 1, monitor := 0, defence_choice := 0, colours: Array = []) -> Dictionary:
	assert(valid_assignment(a))
	var c := {"id":"delta","assignment":a.duplicate(true),"eye":eye,"safe":safe,"monitor_side":monitor_side,"monitor_hand":monitor_side,"monitor":monitor,"defense_choice":defence_choice,"parameters":parameters(),"colours":colours.duplicate(),"arm_turns":[20,-20,20,-20,20,-20]}
	if c.colours.is_empty(): c.colours=[0,1,1,0,0,1,1,0]
	c.beetle=turn(Vector2(-20,0),eye); c.final=turn(Vector2(20,0),eye); c.eye_pos=turn(Vector2(0,-45),eye)
	# Caster at the beetle edge; 210-degree cone points along relative N/S.
	# Its safe boundary slopes 15 degrees, unlike a center-origin half-plane.
	c.swivel={"kind":"cone","pos":c.beetle,"angle":eye+(0 if safe==1 else 180),"width":210.0,"radius":60.0,"name":"Swivel Cannon"}
	c.swivel_provenance="Beetle r20 source resource positions + primary diagram 14/15-degree sloped boundary; rotation derived, not stale proxy facing."
	return c

static func events(c: Dictionary) -> Array:
	var result: Array=[
		{"at":7.244,"kind":"fists_spawn"},
		{"at":10.241,"kind":"arms_spawn"},
		{"at":17.976,"kind":"tethers_live"},
		{"at":20.120,"kind":"hazard","shape":{"kind":"line","pos":c.eye_pos,"angle":float(c.eye)+180,"width":16.0,"length":100.0,"name":"Optical Laser"}},
		{"at":20.120,"kind":"fists_lock","sequence":1},
		{"at":20.298,"kind":"monitor_loading"},
		{"at":23.114,"kind":"fists_resolve"},
		{"at":25.527,"kind":"arms_lock"},
		{"at":25.617,"kind":"defense"},
		{"at":30.445,"kind":"monitors"},
		{"at":30.980,"kind":"pile_pitch"},
		{"at":33.395,"kind":"swivel_cast"},
		{"at":43.366,"kind":"hazard","shape":c.swivel.duplicate(true)},
		{"at":44.080,"kind":"world","pulse":0},
		{"at":45.107,"kind":"world","pulse":1},
		{"at":46.092,"kind":"world","pulse":2},
		{"at":53.976,"kind":"finish"}]
	# Observed NA intervals; other captures agree to about 0.1s. Nominal 0.6.
	for i in 6: result.append({"at":[27.988,28.613,29.196,29.775,30.355,30.935][i],"kind":"arms_fire","pulse":i})
	return sorted(result)

static func entities(c: Dictionary) -> Array:
	return [
		{"id":"delta_beetle","form":"beetle","pos":c.beetle,"facing":float(c.eye)+90,"stance":"SWIVEL","spawn_delay":0.0},
		{"id":"delta_final","form":"final","pos":c.final,"facing":float(c.eye)+270,"stance":"MONITOR","spawn_delay":0.0},
		{"id":"delta_eye","form":"optical_unit","pos":c.eye_pos,"facing":float(c.eye)+180,"stance":"LASER","spawn_delay":0.0,"asset_status":"optional model; procedural fallback is not official"}]
