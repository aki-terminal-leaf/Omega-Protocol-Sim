# SPDX-License-Identifier: MIT
extends RefCounted
## Encounter damage only. No rotations, automatic healing, or goal-based HP.
## Four successful clears contain distance 0 and 19.292..37.088 samples;
## the interior falloff curve is NOT identifiable from those observations.
const Rules = preload("res://scripts/rules.gd")
const MIN_OBSERVED_FAR_DISTANCE = 19.292

static func flare_bounds(distance: float, owner: bool) -> Dictionary:
	if distance>100: return {"lower":0.0,"upper":0.0,"known":true}
	if owner: return {"lower":52488.0,"upper":84539.0,"known":false,"basis":"observed non-tank self packets, not universal damage bounds"}
	if distance>=MIN_OBSERVED_FAR_DISTANCE:
		return {"lower":0.0,"upper":12917.0,"known":false,"basis":"observed far packets; absorbs and tank defense confound lower bound"}
	return {"lower":0.0,"upper":null,"known":false,"basis":"unsampled falloff interior"}

static func flares(actors: Array, targets: Array, state: Dictionary) -> Array:
	var packets: Array=[]
	for target in targets:
		for actor in actors.size():
			var distance := Rules.v(actors[actor].pos).distance_to(Rules.v(actors[int(target)].pos))
			var bound := flare_bounds(distance,actor==int(target))
			packets.append({"source_actor":int(target),"target_actor":actor,"distance":distance,"bounds":bound})
			if actor!=int(target) and bound.upper==null:
				# Reject the practice result without inventing lethal damage/HP.
				state.runtime_failures.append("P6 close flare: separation %.3f falls inside unmeasured falloff; survival unverified" % distance)
	state.p6.damage_verification="incomplete: no identifiable interior falloff or complete party mitigation/HP replay"
	return packets

static func apply_packet(state: Dictionary, actor: int, amount: float, multiplier := 1.0, invulnerable := false) -> Dictionary:
	# Parent explicitly provides current HP, shields and mitigation per packet.
	# This is separate from empirical flare bounds, which are not exact damage.
	if not state.has("p6_hp") or actor<0 or actor>=state.p6_hp.size(): return {"ok":false,"reason":"HP not configured"}
	if amount<0 or multiplier<0 or multiplier>1: return {"ok":false,"reason":"Invalid damage/mitigation"}
	var hp: Dictionary=state.p6_hp[actor]
	var damage := 0.0 if invulnerable else amount*multiplier
	var absorbed := minf(float(hp.get("shield",0)),damage)
	hp.shield=float(hp.get("shield",0))-absorbed
	hp.hp=maxf(0,float(hp.hp)-(damage-absorbed))
	if float(hp.hp)==0 and actor not in state.dead: state.dead.append(actor)
	return {"ok":true,"damage":damage-absorbed,"absorbed":absorbed,"remaining":hp.hp}
