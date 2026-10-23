# SPDX-License-Identifier: MIT
extends RefCounted
## P2 Party Synergy dodge: NPC route from PUBLIC physical weapon tells only.
## Never reads beat.positions/beat.shapes/RNG/profile weapons. Limited scope:
## single-point legacy grid-scan endpoint; LPDU6 group-side placement OPEN.
const R=preload("res://scripts/rules.gd")
const Clones=preload("res://scripts/clone_patterns.gd")
const KEY:="synergy_weapons"
const META:="synergy_weapon_public"
const VERSION:=1
const PROFILES:=["elemental","aether","lpdu","cn_moogle","kr_09stop"]
const DISPLAYED:="displayed_physical_parts"
const HEADLESS:="headless_public_stances_not_displayed"
const ASSISTED:="assisted_checkpoint_not_observed"
const PAIR_TOL:=0.5
const CENTRE:=1.0
const DUP:=0.05
const MALE:={"SWORD":true,"SHIELD":false}
const FEMALE:={"LEGS":true,"STAFF":false}

static func meta(profile_id:String)->Dictionary:
	return {"version":VERSION,"profile_id":profile_id}

static func origin_of(beat:Dictionary)->String:
	return "%s@%s"%[str(beat.get("title","")),str(beat.get("synergy_start",""))]

static func valid_meta(beat:Dictionary)->bool:
	var m:Variant=beat.get(META,null)
	return m is Dictionary and int(m.get("version",-1))==VERSION and str(m.get("profile_id","")) in PROFILES

## Fresh cache each beat/run; non-weapon beats drop any old cache.
static func begin(beat:Dictionary,state:Dictionary)->void:
	state.erase(KEY)
	if not valid_meta(beat):return
	state[KEY]={"profile":str(beat[META].profile_id),"origin":origin_of(beat),"started":float(state.get("sim_time",0)),"receipt":{},"blocked":"","rejects":[],"target":null}

static func finite_pos(raw:Variant)->Variant:
	if raw is Vector2:
		return raw if is_finite(raw.x) and is_finite(raw.y) else null
	if raw is Array and raw.size()==2 and typeof(raw[0]) in [TYPE_FLOAT,TYPE_INT] and typeof(raw[1]) in [TYPE_FLOAT,TYPE_INT]:
		var p:=Vector2(float(raw[0]),float(raw[1]))
		return p if is_finite(p.x) and is_finite(p.y) else null
	return null

static func base_form(raw:Variant)->String:
	var f:=str(raw)
	if f.begins_with("female"):return "female"
	if f.begins_with("male"):return "male"
	return ""

## Observations: [{"form","pos":[x,z],"weapon"}]; weapon "" means no coherent tell.
## Returns {"ok":true,"m":Vector2,"sword","legs"} or {"ok":false,"reason"}.
static func classify(observations:Variant)->Dictionary:
	if not observations is Array:return {"ok":false,"reason":"malformed"}
	var males:Array=[];var females:Array=[];var all:Array=[]
	for o in observations:
		if not o is Dictionary:return {"ok":false,"reason":"malformed"}
		var form:=base_form(o.get("form",""))
		if form=="":continue
		var p:Variant=finite_pos(o.get("pos",null))
		if p==null:return {"ok":false,"reason":"malformed"}
		for q in all:
			if (q as Vector2).distance_to(p)<DUP:return {"ok":false,"reason":"duplicate"}
		all.append(p)
		var item:={"pos":p,"weapon":str(o.get("weapon","")),"invalid_tell":bool(o.get("invalid_tell",false))}
		if form=="male":males.append(item)
		else:females.append(item)
	var pairs:Array=[]
	for m in males:
		var mp:Vector2=m.pos
		if mp.length()<=CENTRE:continue
		for f in females:
			var fp:Vector2=f.pos
			if fp.distance_to(-mp)<=PAIR_TOL:pairs.append([m,f])
	if pairs.is_empty():return {"ok":false,"reason":"no_pair"}
	if pairs.size()>1:return {"ok":false,"reason":"ambiguous"}
	var m0:Dictionary=pairs[0][0];var f0:Dictionary=pairs[0][1]
	if m0.invalid_tell or f0.invalid_tell:return {"ok":false,"reason":"invalid_tell"}
	if not MALE.has(m0.weapon) or not FEMALE.has(f0.weapon):
		if (not MALE.has(m0.weapon) and str(m0.weapon) not in ["","NEUTRAL"]) or (not FEMALE.has(f0.weapon) and str(f0.weapon) not in ["","NEUTRAL"]):return {"ok":false,"reason":"invalid_tell"}
		return {"ok":false,"reason":"no_tell"}
	return {"ok":true,"m":m0.pos,"sword":MALE[m0.weapon],"legs":FEMALE[f0.weapon]}

static func allowed_basis(state:Dictionary,basis:String)->bool:
	if basis==DISPLAYED:return bool(state.get("synergy_weapons_presentation_required",false))
	if basis==ASSISTED:return bool(state.get("synergy_weapons_checkpoint_assisted",false))
	if basis==HEADLESS:return not bool(state.get("synergy_weapons_presentation_required",false))
	return false

static func reject(cache:Dictionary,reason:String)->void:
	if cache.rejects.size()<16:cache.rejects.append(reason)

static func publish(beat:Dictionary,state:Dictionary,observations:Variant,basis:String)->void:
	var cache:Variant=state.get(KEY,null)
	if not cache is Dictionary or not valid_meta(beat):return
	if cache.profile!=str(beat[META].profile_id) or cache.origin!=origin_of(beat):reject(cache,"stale_cache");return
	if cache.blocked!="":return
	if not allowed_basis(state,basis):reject(cache,"basis");return
	var now:=float(state.get("sim_time",0))
	if now+0.000001<float(cache.started):reject(cache,"time");return
	var seen:=classify(observations)
	if not seen.ok:
		# A seen cue later disappearing stays remembered; before receipt: nothing.
		reject(cache,str(seen.reason))
		# Remember only genuine absence/neutral. Complete contradictory inputs,
		# including actual simultaneous physical variants, revoke frozen memory.
		if not cache.receipt.is_empty() and str(seen.reason) in ["malformed","duplicate","ambiguous","invalid_tell"]:
			cache.blocked="contradiction";cache.receipt={};cache.target=null
		return
	var m:Vector2=seen.m
	var fresh:={"profile":cache.profile,"origin":cache.origin,"at":now,"basis":basis,"m":[m.x,m.y],"sword":seen.sword,"legs":seen.legs}
	var old:Dictionary=cache.receipt
	if old.is_empty():
		cache.receipt=fresh;cache.target=null;return
	var om:Vector2=Vector2(float(old.m[0]),float(old.m[1]))
	if om.distance_to(m)>PAIR_TOL or bool(old.sword)!=seen.sword or bool(old.legs)!=seen.legs or str(old.basis)!=basis:
		cache.blocked="contradiction";cache.receipt={};cache.target=null

## Headless (not displayed) public stance observation; never in presentation runs.
static func observe_headless(beat:Dictionary,state:Dictionary)->void:
	if not state.has(KEY) or bool(state.get("synergy_weapons_presentation_required",false)):return
	publish(beat,state,entity_observations(beat,state),HEADLESS)

static func publish_assisted(beat:Dictionary,state:Dictionary)->void:
	if not state.has(KEY):return
	state.synergy_weapons_checkpoint_assisted=true
	publish(beat,state,entity_observations(beat,state),ASSISTED)

static func entity_observations(beat:Dictionary,state:Dictionary)->Array:
	var elapsed:=float(state.get("sim_time",0))-float(state.get("beat_started",0))
	var out:Array=[]
	for e in beat.get("stage_entities",[]):
		if not bool(e.get("visible",true)) or elapsed+0.000001<float(e.get("spawn_delay",0)):continue
		var p:=R.v(e.get("pos",Vector2.ZERO))
		out.append({"form":str(e.get("form","")),"pos":[p.x,p.y],"weapon":str(e.get("stance",""))})
	return out

## Valid current receipt or {}. Revalidates profile/origin/time/basis.
static func receipt(beat:Dictionary,state:Dictionary)->Dictionary:
	var cache:Variant=state.get(KEY,null)
	if not cache is Dictionary or not valid_meta(beat) or cache.blocked!="":return {}
	var r:Dictionary=cache.receipt
	if r.is_empty():return {}
	if r.profile!=str(beat[META].profile_id) or r.origin!=origin_of(beat):return {}
	var at:=float(r.at)
	if not is_finite(at) or at+0.000001<float(cache.started) or at>float(state.get("sim_time",0))+0.000001:return {}
	if not allowed_basis(state,str(r.basis)):return {}
	if finite_pos(r.m)==null:return {}
	return r

static func angle_of(m:Vector2)->float:
	return snappedf(rad_to_deg(atan2(m.x,-m.y)),0.001)

## Same scan order as encounters.find_safe; geometry inferred from the receipt only.
static func safe_from(r:Dictionary)->Vector2:
	var m:Vector2=finite_pos(r.m)
	var shapes:Array=Clones.pair_shapes(angle_of(m),bool(r.sword),bool(r.legs))
	for y in range(-16,17):
		for x in range(-16,17):
			var p:=Vector2(x,y)
			if p.length()>17:continue
			var ok:=true
			for s in shapes:
				if R.contains(s,p,[]):ok=false;break
			if ok:return p
	return Vector2.ZERO

static func goal(actor:int,beat:Dictionary,actors:Array,state:Dictionary)->Vector2:
	var held:=R.v(actors[actor].pos)
	var r:=receipt(beat,state)
	if r.is_empty():return held
	var cache:Dictionary=state[KEY]
	if cache.target==null:
		var t:=safe_from(r);cache.target=[t.x,t.y]
	return Vector2(float(cache.target[0]),float(cache.target[1]))
