# SPDX-License-Identifier: MIT
# Pure Aether horizontal conga helpers (Toolbox steps 3/5). No state/beat/RNG/
# ctx.order reads. Not integration, freeze or grading decisions.
extends RefCounted
const Signs=preload("res://scripts/synergy_signs.gd")
const DEFAULT_SHAPES:=["cross","square","circle","triangle"]
# Training-only ambiguity tolerance for same-symbol x ties; NOT a server fact.
const TIE_EPSILON:=0.05

static func _index(value:Variant)->int:
	if value is int:return value if value>=0 and value<8 else -1
	if value is float and is_finite(value) and value==floor(value) and value>=0.0 and value<8.0:return int(value)
	return -1

static func _positions_ok(positions:Variant)->bool:
	if not positions is Array or positions.size()!=8:return false
	for p in positions:
		if not p is Vector2 or not is_finite(p.x) or not is_finite(p.y):return false
	return true

static func _shapes_ok(order:Variant)->bool:
	if not order is Array or order.size()!=4:return false
	var seen:Array=[]
	for s in order:
		if not s is String:return false
		var n:=Signs.symbol_name(s)
		if n not in DEFAULT_SHAPES or n in seen:return false
		seen.append(n)
	return true

static func assign(observed:Array,positions:Array,shape_order:Array=DEFAULT_SHAPES)->Dictionary:
	if observed.size()!=8 or not _positions_ok(positions) or not _shapes_ok(shape_order):return {}
	var shapes:Array=shape_order.map(func(s):return Signs.symbol_name(s))
	var symbols:Array=[];symbols.resize(8)
	for raw in observed:
		if not raw is Dictionary or raw.size()!=2 or not raw.has("actor") or not raw.has("symbol") or not raw.symbol is String:return {}
		var actor:=_index(raw.actor)
		if actor<0 or symbols[actor]!=null:return {}
		var name:=Signs.symbol_name(raw.symbol)
		if name not in DEFAULT_SHAPES:return {}
		symbols[actor]=name
	var sides:Array=[];sides.resize(8)
	var route:Array=[]
	for shape in shapes:
		var owners:Array=range(8).filter(func(a):return symbols[a]==shape)
		if owners.size()!=2:return {}
		var xa:float=positions[owners[0]].x;var xb:float=positions[owners[1]].x
		if absf(xa-xb)<=TIE_EPSILON:return {}
		var left:int=owners[0] if xa<xb else owners[1]
		var right:int=owners[1] if left==owners[0] else owners[0]
		sides[left]=0;sides[right]=1
		route.append(left);route.append(right)
	return {"profile_id":"aether","actor_sides":sides,"route_order":route,"actor_symbols":symbols,"crossed":[]}

# Training layout only; spacing 1.8 does not certify physical reachability.
static func initial_slots(spacing:float=1.8,line_z:float=0.0)->Array:
	if not is_finite(spacing) or spacing<=0.0 or not is_finite(line_z):return []
	var result:Array=[]
	for i in range(8):result.append(Vector2((float(i)-3.5)*spacing,line_z))
	return result

static func npc_line_goals(positions:Array,human:int,previous_order:Array=[])->Dictionary:
	if not _positions_ok(positions) or human<-1 or human>7:return {}
	var prev_rank:Array=[]
	if not previous_order.is_empty():
		if previous_order.size()!=8:return {}
		prev_rank.resize(8)
		for i in range(8):
			var a:=_index(previous_order[i])
			if a<0 or prev_rank[a]!=null:return {}
			prev_rank[a]=i
	var slots:=initial_slots()
	var reserved:=-1
	if human>=0:
		var best:=INF
		for i in range(8):
			var d:=absf(slots[i].x-positions[human].x)
			if d<best:best=d;reserved=i
	var movers:Array=range(8).filter(func(a):return a!=human)
	movers.sort_custom(func(a,b):
		if positions[a].x!=positions[b].x:return positions[a].x<positions[b].x
		if not prev_rank.is_empty() and prev_rank[a]!=prev_rank[b]:return prev_rank[a]<prev_rank[b]
		return a<b)
	var free:Array=range(8).filter(func(i):return i!=reserved)
	var goals:Dictionary={}
	for k in range(movers.size()):goals[movers[k]]=slots[free[k]]
	return {"goals":goals,"reserved_slot":reserved,"npc_order":movers,"slots":slots}
