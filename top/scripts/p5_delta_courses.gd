# SPDX-License-Identifier: MIT
extends RefCounted
## Parent entry point: append_delta(ctx). Does not call the legacy ctx.delta().
const P = preload("res://scripts/p5_delta_patterns.gd")
const R = preload("res://scripts/rules.gd")

static func append_delta(ctx) -> void:
	var family: Array=P.fist_families()[ctx.rng.randi_range(0,35)]
	var a:=P.assignment(ctx.order,ctx.rng.randi_range(0,1),ctx.rng.randi_range(0,1),ctx.rng.randi_range(0,1))
	var c:=P.config(a,ctx.rng.randi_range(0,3)*90.0,1 if ctx.rng.randi_range(0,1) else -1,1 if ctx.rng.randi_range(0,1) else -1,int(ctx.order[ctx.rng.randi_range(0,3)]),ctx.rng.randi_range(0,1),family)
	c.monitor_hand=1 if ctx.rng.randi_range(0,1) else -1
	c.arm_forms=ctx.shuffled(["arm_left","arm_left","arm_left","arm_right","arm_right","arm_right"])
	for arm in 6: c.arm_turns[arm]=20 if ctx.rng.randi_range(0,1) else -20
	append_family(ctx,c)

static func append_family(ctx, config: Dictionary) -> void:
	var c:=config.duplicate(true)
	c.route=P.route(str(ctx.profile.id)); c.id="delta_%d"%ctx.beats.size()
	# Aether assigns lanes from actual debuffs. Swap the guide order and
	# actor-associated fist colours together; never rewrite statuses/tethers.
	if c.route.id=="aether" and int(c.assignment.near) in [int(c.assignment.order[2]),int(c.assignment.order[3])]:
		for side in 2:
			var actor=c.assignment.order[side];c.assignment.order[side]=c.assignment.order[side+2];c.assignment.order[side+2]=actor
			var colour=c.colours[side];c.colours[side]=c.colours[side+2];c.colours[side+2]=colour
	c.guide_provenance="Source semantic route; numeric positions are original training constructions. Read route unknowns."
	var times: Array=[7.244,17.976,20.120,25.527,25.617,30.980,33.395,43.366,46.092,51.2,53.976]
	var last:=0.0
	for time in times:
		ctx.positions=goals(c,last,{})
		var b: Dictionary=ctx.beat("Delta / %s / %.3fs"%[c.route.name,float(time)],float(time)-last,"Live overlapping mechanics. "+str(c.route.unknown))
		b.delta_guide=true; b.delta_family=c.duplicate(true); b.delta_route_complete=false
		if last==0:
			b.delta_config=c.duplicate(true); b.delta_events=P.events(c)
		last=float(time)

static func sides(c: Dictionary) -> Array:
	var result: Array=[-1,1,-1,1,-1,1,-1,1]
	for base in [0,4]:
		if int(c.colours[base])==int(c.colours[base+2]):
			var adjustable: int=base if c.route.adjust=="inner" else base+2
			result[adjustable]=1; result[adjustable+1]=-1
	return result

static func arm_map(c: Dictionary) -> Dictionary:
	# Arm index CCW from eye. Green inner N/S; outer Final NE/SE.
	# CN's inner-green Defense means blue short takes N/S arms instead.
	var map: Dictionary={}
	var side:=sides(c)
	var defence: String=c.route.defense_pair
	for slot in 8:
		var n: bool=int(side[slot])<0
		if slot>=6: map[slot]=5 if n else 4
		elif slot>=4:
			if defence!="inner_green": map[slot]=0 if n else 3
		elif defence=="inner_green": map[slot]=(0 if n else 3) if slot<2 else (1 if n else 2)
		elif (slot<2 and defence=="outer") or (slot>=2 and defence=="inner"): map[slot]=1 if n else 2
	return map

static func goals(c: Dictionary, t: float, state: Dictionary) -> Array:
	var local: Array=[]; local.resize(8); local.fill(Vector2.ZERO)
	var side:=sides(c); var arms:=arm_map(c)
	var victim:=int(state.get("delta",{}).get("defense_target",-1))
	var victim_slot: int=-1
	for slot in 8:
		if int(c.assignment.order[slot])==victim: victim_slot=slot
	var replacement: int=-1
	if c.route.id=="cn_moogle" and victim_slot in [4,5]:
		# The poster puts inner greens on Defense. A green Defense victim
		# cannot also receive a monitor (Twice-come Ruin). This conditional
		# replacement is a legal training realization, not stated poster text.
		for slot in 4:
			if int(side[slot])==int(side[victim_slot]) and int(c.assignment.order[slot])!=int(c.monitor): replacement=slot; break
	for slot in 8:
		var s:=float(side[slot]); var original: float=-1.0 if slot%2==0 else 1.0
		if t<7.244:
			local[slot]=Vector2(-13,original*4) if slot<2 else (Vector2(-11,original*12) if slot<4 else Vector2(9 if slot<6 else 13,original*11))
		elif t<17.976:
			local[slot]=Vector2(-13,s*4) if slot<2 else (Vector2(-11,s*12) if slot<4 else Vector2(11,s*11))
		elif t<20.120:
			local[slot]=Vector2(-13,s*4) if slot<4 else Vector2(11,s*11)
		elif t<25.527:
			if arms.has(slot):
				var index:=int(arms[slot]); var spin:=float(c.arm_turns[index])
				local[slot]=R.direction(-index*60.0-spin*0.15)*19.0
			else: local[slot]=Vector2(0,s*6)
		elif t<33.395:
			if t<28.01:
				local[slot]=R.direction(-int(arms[slot])*60.0)*9.0 if arms.has(slot) else Vector2(0,s*6)
				continue
			if slot>=4: local[slot]=Vector2(-7 if slot<6 else 7,s*13)
			else:
				var actor:=int(c.assignment.order[slot])
				var monitor: bool=actor==int(c.monitor)
				local[slot]=Vector2(0,(5.0 if monitor else 2.5)*int(c.monitor_side))
				if actor==victim: local[slot].x=10.0 if monitor else -10.0
		else:
			local=world_goals(c)
			break
	if c.route.id=="cn_moogle" and t>=28.01 and t<33.395 and replacement>=0:
		local[replacement]=Vector2(-7,13*int(side[victim_slot]))
		local[victim_slot]=Vector2(-10,2.5*int(c.monitor_side))
	if c.route.id=="cn_moogle" and t>=33.395 and t<37.95 and victim_slot in [4,5]:
		for slot in range(4,6): local[slot]=Vector2(-10,2.5*int(c.monitor_side)) if slot==victim_slot else Vector2(-7,13*int(side[slot]))
	# Hold the unbroken green across Worlds; only begin convergence late enough
	# that a normal 6/s approach cannot cut before the final 5s vulnerability.
	if t>=49.5:
		for slot in 8:
			if slot>=4: local[slot]=Vector2(0,12*int(c.safe))
	var result: Array=[]; result.resize(8)
	for slot in 8: result[int(c.assignment.order[slot])]=R.v(local[slot]).rotated(deg_to_rad(float(c.eye)))
	return result

static func world_goals(c: Dictionary) -> Array:
	var result: Array=[]; result.resize(8)
	var side:=sides(c); var safe:=int(c.safe)
	for slot in 8:
		var actor:=int(c.assignment.order[slot])
		if actor==int(c.assignment.near): result[slot]=Vector2(0,6*safe)
		elif actor==int(c.assignment.far): result[slot]=Vector2(0,19*safe)
		elif slot<4: result[slot]=Vector2(9+(slot%2)*0.4,15*safe)
		elif slot<6: result[slot]=Vector2(-10,(12 if int(side[slot])==safe else 6)*safe)
		else: result[slot]=Vector2(15,11*safe) if int(side[slot])==safe else Vector2(-18,2*safe)
	if c.route.world_layout=="cn_poster":
		# Original poster: broken green SAFE stays nearer the initial holder;
		# dangerous-side partner crosses to the edge, reversing Saus ordering.
		for slot in range(4,6):
			result[slot]=Vector2(-9,8*safe) if int(side[slot])==safe else Vector2(-12,12*safe)
	if c.route.world_layout=="kr_338":
		# Figure 338 has Far center and Near at beetle intercardinal. The two
		# unmarked BLUES receive Near; outer green pair are the idle two.
		var idle_blue:=0
		for slot in 8:
			var actor:=int(c.assignment.order[slot])
			if actor==int(c.assignment.near): result[slot]=Vector2(-10,12*safe)
			elif actor==int(c.assignment.far): result[slot]=Vector2(0,5.8*safe)
			elif slot<4:
				result[slot]=Vector2(-3 if idle_blue==0 else 3,17*safe); idle_blue+=1
			elif slot<6: result[slot]=Vector2(15,11*safe) if int(side[slot])==safe else Vector2(-18,2*safe)
			else: result[slot]=Vector2(10+(slot%2)*0.4,12*safe)
	return result

static func guide(beat: Dictionary, state: Dictionary) -> void:
	if not beat.get("delta_guide",false): return
	var c: Dictionary=state.delta.config
	beat.positions=goals(c,float(state.sim_time)-float(state.delta.start),state)
	# Facing is expressed in the same local frame as movement. It aims the
	# player monitor into the opposite half from Final's monitor.
	beat.facing={int(c.monitor):float(c.eye)+(180 if int(c.monitor_side)==1 else 0)-90*int(c.monitor_hand)}
	beat.delta_motion={"walk":6.0,"sprint":7.5,"sprint_actor":int(c.monitor),"sprint_start":float(state.delta.start)+25.527,"sprint_end":float(state.delta.start)+31.0,"sprint_authorized":sprint_authorized(c),"source":"LPDU step 10 blue arm baiter with monitor; other cases require explicit parent/user authorization"}

static func sprint_authorized(c: Dictionary) -> bool:
	if c.route.id!="lpdu": return false
	var arms:=arm_map(c)
	for slot in arms:
		if int(c.assignment.order[slot])==int(c.monitor): return true
	return false
