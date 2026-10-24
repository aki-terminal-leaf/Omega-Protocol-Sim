# SPDX-License-Identifier: MIT
extends RefCounted
## Original 901ea5a six layouts, priorities, RNG and physical checks preserved.
static func append_monitors(ctx) -> void:
	var saved_order: Array = ctx.order.duplicate()
	var p3_roles: Array = ctx.profile.get("p3_priority", ctx.profile.priority)
	var m_holders: Array = ctx.order.slice(0, 3)
	var non_holders: Array = ctx.order.slice(3, 8)
	m_holders.sort_custom(func(a, b): return p3_roles.find(ctx.ROLES[a]) < p3_roles.find(ctx.ROLES[b]))
	non_holders.sort_custom(func(a, b): return p3_roles.find(ctx.ROLES[a]) < p3_roles.find(ctx.ROLES[b]))
	ctx.order = m_holders + non_holders
	var sign_x = 1 if ctx.rng.randi_range(0, 1) else -1
	var canonical = [Vector2(-7,-11),Vector2(-13,-5),Vector2(-13,5),Vector2(0,-16),Vector2(3,0),Vector2(15,0),Vector2(0,9),Vector2(0,18)]
	var layout: String = ctx.profile.get("monitor_layout",ctx.profile.id if ctx.profile.id in ["aether","lpdu"] else "astoh")
	if layout == "aether": canonical = [Vector2(-11,-9),Vector2(-11,9),Vector2(10,11),Vector2(1,-15),Vector2(10,-11),Vector2(15,-4),Vector2(15,4),Vector2(1,15)]
	# LPDU source step5 places N4 inside N5. Engineering spacing keeps N4
	# off M1's halfplane boundary; these are not official calibrated metres.
	elif layout == "lpdu": canonical = [Vector2(10,-11),Vector2(-11,-9),Vector2(-11,9),Vector2(1,-15),Vector2(15,-4),Vector2(15,4),Vector2(7,10.5),Vector2(1,15)]
	if layout=="cn_mirror":canonical=[Vector2(-7,-13),Vector2(-13,-5),Vector2(-13,5),Vector2(0,-9),Vector2(3,0),Vector2(16,0),Vector2(0,9),Vector2(0,18)]
	elif layout=="kr_astoh":canonical=[Vector2(-7,-11),Vector2(-13,-5),Vector2(-13,5),Vector2(-0.7,-16),Vector2(3,0),Vector2(15,0),Vector2(-0.7,9),Vector2(-0.7,18)]
	elif layout=="cn_fixed":canonical=[Vector2(-8 if sign_x==1 else 8,-17),Vector2(-11,-5.5),Vector2(-11,5.5),Vector2(-sign_x,-8),Vector2(6,0),Vector2(18,0),Vector2(-sign_x,8),Vector2(-sign_x,18)]
	for i in 8:
		ctx.pos(i,canonical[i] if layout=="cn_fixed" else Vector2(canonical[i].x*sign_x,canonical[i].y))
		ctx.label(i, "MONITOR %d" % (i + 1) if i < 3 else "No monitor %d" % (i - 2))
	var layout_name: String={"astoh":"Astoh","aether":"Aether · 第三檢知南側","lpdu":"LPDU · 第一檢知北側","cn_fixed":"莫古力 · 固定左側","cn_mirror":"莫古力 · 鏡像換邊","kr_astoh":"09STOP"}.get(layout,layout)
	var b = ctx.beat("Oversampled Wave Cannon · %s · %s" % [layout_name,"EAST" if (sign_x == 1) == (layout not in ["aether","lpdu"]) else "WEST"],10.1,"每個檢知隨機命中其半場兩人，不足時補選其他人；還要避開半徑7的受擊小圓。Q/E 或右鍵調整朝向。")
	# Start the independent drill at the visible cast, not already on its answers.
	b.spawn=[]
	for actor in 8:b.spawn.append(Vector2((actor-3.5)*0.35,6.0))
	b.monitor_layout = layout
	var sources: Array = [{"kind": "half", "angle": (270 if layout in ["aether","lpdu"] else 90) * sign_x, "radius": 45, "name": "Boss monitor"}]
	var goals = [270.0 * sign_x, 0.0, 180.0]
	if layout=="cn_fixed":goals=[270.0 if sign_x==1 else 98.5,0.0,180.0]
	if layout == "aether": goals = [0.0,180.0,90.0 * sign_x]
	elif layout == "lpdu": goals = [90.0 * sign_x,0.0,180.0]
	for i in 3:
		var offset = 90.0 if ctx.rng.randi_range(0, 1) else -90.0
		b.facing[ctx.at(i)] = goals[i] - offset
		sources.append({"kind": "half", "actor": ctx.at(i), "face_actor": ctx.at(i), "offset": offset, "radius": 45, "exclude": [ctx.at(i)], "name": "Player monitor"})
	b.checks.append({"kind": "monitors", "sources": sources, "splash_radius":7.0,"name": "Oversampled Wave Cannon"})
	b.monitors = sources
	b.party_statuses=[]
	for source in sources:
		if source.has("actor"): b.party_statuses.append({"actor":int(source.actor),"key":"monitor_right" if float(source.offset)>0 else "monitor_left","remaining":-1})
	# Only the ordering is source-backed. Numeric line spacing and the 3s
	# teaching window are training choreography within the unchanged10.1s cast.
	# Never exchange source-priority ranks when a human stands in the wrong slot.
	if layout!="kr_astoh":
		b.monitor_preparation={"order":ctx.order.duplicate(),"priority":p3_roles.duplicate(),"sort_until":3.0,"layout":layout,"source_scope":"published priority; schematic sorting geometry/timing, not missing CN figure1"}
		b.note="先按本攻略優先序排位，再依Boss半場散開；排序線位置為訓練示意，不代替原攻略缺圖。"+b.note
	ctx.order = saved_order
