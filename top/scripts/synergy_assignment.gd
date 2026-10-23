# P2 Party Synergy light-party assignment (Elemental profile only).
# Pure: reads only the caller-supplied published glyphs and public initial queues.
# Source: ffxiv.tuufless.com/elemental/top/02_omega_mf/#party-synergy Step1/Step2/FAQ.
# Same-side repeated symbol -> only the lower (later in initial queue) player crosses.
const Signs=preload("res://scripts/synergy_signs.gd")
const SHAPES:=["circle","cross","triangle","square"]

static func _index(value:Variant)->int:
	if not (value is int or value is float):return -1
	var number:=float(value)
	if not is_finite(number) or number!=floorf(number) or number<0.0 or number>7.0:return -1
	return int(number)

static func _queue(raw:Variant)->Array:
	if not raw is Array or raw.size()!=4:return []
	var result:Array=[]
	for value in raw:
		var index:=_index(value)
		if index<0 or index in result:return []
		result.append(index)
	return result

static func assign(observed:Array,config:Dictionary)->Dictionary:
	if str(config.get("profile_id",""))!="elemental" or not config.get("profile_id") is String:return {}
	var left:=_queue(config.get("left"))
	var right:=_queue(config.get("right"))
	if left.is_empty() or right.is_empty():return {}
	for actor in left:
		if actor in right:return {}
	var order_raw:Variant=config.get("shape_order")
	if not order_raw is Array or order_raw.size()!=4:return {}
	var shape_order:Array=[]
	for value in order_raw:
		if not value is String or value not in SHAPES or value in shape_order:return {}
		shape_order.append(value)
	if observed.size()!=8:return {}
	var symbols:Array=["","","","","","","",""]
	for record in observed:
		if not record is Dictionary or record.size()!=2 or not record.has("actor") or not record.has("symbol"):return {}
		var actor:=_index(record.actor)
		if actor<0 or not str(symbols[actor]).is_empty() or not record.symbol is String:return {}
		var shape:=Signs.symbol_name(record.symbol)
		if shape not in SHAPES:return {}
		symbols[actor]=shape
	for shape in SHAPES:
		if symbols.count(shape)!=2:return {}
	var sides:Array=[0,0,0,0,0,0,0,0]
	for actor in right:sides[actor]=1
	var crossed:Array=[]
	for queue in [left,right]:
		var seen:Array=[]
		for actor in queue:
			if symbols[actor] in seen:crossed.append(actor)
			else:seen.append(symbols[actor])
	for actor in crossed:sides[actor]=1-int(sides[actor])
	crossed.sort()
	var route:Array=[]
	for shape in shape_order:
		var pair:Array=[-1,-1]
		for actor in range(8):
			if symbols[actor]==shape:
				if pair[sides[actor]]!=-1:return {}
				pair[sides[actor]]=actor
		if -1 in pair:return {}
		route.append_array(pair)
	return {"profile_id":"elemental","actor_sides":sides,"crossed":crossed,"route_order":route,"actor_symbols":symbols}
