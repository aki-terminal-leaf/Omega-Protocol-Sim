# SPDX-License-Identifier: MIT
extends RefCounted
## P2 Party Synergy new North from PUBLIC body geometry only (five outer M at
## r13: N, N+/-45, N+/-135; optional centre F that never supplies direction).
## Never reads private north, roles/IDs, true pairs/RNG, weapon stance,
## beat.positions/shapes or planned goals. Scope: current simulator geometry
## for Elemental/Aether/LPDU only; tolerances are implementation tolerances,
## not original-game-certified. CN/KR unchanged/open; LPDU weapon side OPEN.
const KEY:="synergy_north"
const VERSION:=1
const PROFILES:=["elemental","aether","lpdu"]
const OBSERVE_PHASES:=["knock","stack","blades","expiry","finish"]
const PLAN_PHASES:=["knock","stack","blades","expiry","finish"]
const DISPLAYED:="displayed_physical_bodies"
const HEADLESS:="headless_public_entity_geometry_not_displayed"
const ASSISTED:="assisted_checkpoint_not_observed"
const PRESENTATION_FLAG:="synergy_north_presentation_required"
const ASSISTED_FLAG:="synergy_north_checkpoint_assisted"
const RADIUS:=13.0
const RADIUS_TOL:=0.75
const CENTRE_TOL:=0.75
const ANGLE_TOL:=3.0
const DUP:=0.05
const MALES:=5
const OFFSETS:=[45.0,-45.0,135.0,-135.0]
const MAX_OBSERVATIONS:=64
const MAX_REJECTS:=16
## Absence/partial disappearance retains a legitimate past; these revoke it.
const REVOKING:=["malformed","duplicate","invalid_geometry","excess","wrong_complete","ambiguous","changed_direction"]
const EPS:=0.000001

static func number(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))

## Profile/phase context only (lazy load avoids a preload cycle with Prep).
static func context(beat:Dictionary)->Dictionary:
	var chosen:Dictionary=load("res://scripts/synergy_preparation.gd").selection(beat)
	if chosen.is_empty() or not str(chosen.get("profile_id","")) in PROFILES:return {}
	return {"profile_id":str(chosen.profile_id),"phase":str(chosen.phase)}

static func finite_pos(raw:Variant)->Variant:
	if raw is Vector2:
		return raw if is_finite(raw.x) and is_finite(raw.y) else null
	if raw is Array and raw.size()==2 and number(raw[0]) and number(raw[1]):
		return Vector2(float(raw[0]),float(raw[1]))
	return null

static func base_form(raw:Variant)->String:
	if not raw is String and not raw is StringName:return "?"
	var f:=str(raw)
	if f.begins_with("female"):return "female"
	if f.begins_with("male"):return "male"
	return ""

static func angle_of(p:Vector2)->float:
	return fposmod(rad_to_deg(atan2(p.x,-p.y)),360.0)

## Circular difference in (-180,180]; 0/360 compare equal.
static func angle_diff(a:float,b:float)->float:
	var d:=fposmod(a-b,360.0)
	return d-360.0 if d>180.0 else d

static func fail(reason:String)->Dictionary:
	return {"ok":false,"reason":reason}

## observations: Array of {"form","pos":[x,z]|Vector2}; extra keys ignored.
## Returns {"ok":true,"north","m","males","females"} or {"ok":false,"reason"}.
static func classify(observations:Variant)->Dictionary:
	if not observations is Array or observations.size()>MAX_OBSERVATIONS:return fail("malformed")
	var males:Array=[];var females:Array=[];var all:Array=[]
	for o in observations:
		if not o is Dictionary:return fail("malformed")
		var form:=base_form(o.get("form",null))
		if form=="?":return fail("malformed")
		if form=="":continue
		var p:Variant=finite_pos(o.get("pos",null))
		if p==null:return fail("malformed")
		for q in all:
			if (q as Vector2).distance_to(p)<DUP:return fail("duplicate")
		all.append(p)
		if form=="male":males.append(p)
		else:females.append(p)
	for f in females:
		if (f as Vector2).length()>CENTRE_TOL:return fail("invalid_geometry")
	for m in males:
		if absf((m as Vector2).length()-RADIUS)>RADIUS_TOL:return fail("invalid_geometry")
	if males.size()>MALES or females.size()>1:return fail("excess")
	if males.size()<MALES:return fail("absent" if all.is_empty() else "partial")
	var found:Array=[]
	for i in males.size():
		var a:=angle_of(males[i])
		var left:Array=OFFSETS.duplicate()
		var ok:=true
		for j in males.size():
			if j==i:continue
			var d:=angle_diff(angle_of(males[j]),a)
			var hit:=-1
			for k in left.size():
				if absf(angle_diff(d,float(left[k])))<=ANGLE_TOL:hit=k;break
			if hit<0:ok=false;break
			left.remove_at(hit)
		if ok:found.append(i)
	if found.is_empty():return fail("wrong_complete")
	if found.size()>1:return fail("ambiguous")
	var m:Vector2=males[found[0]]
	return {"ok":true,"north":snappedf(angle_of(m),0.001),"m":[m.x,m.y],"males":males.map(func(p):return [p.x,p.y]),"females":females.map(func(p):return [p.x,p.y])}

static func allowed_basis(state:Dictionary,basis:Variant)->bool:
	if basis==DISPLAYED:return state.get(PRESENTATION_FLAG,false)==true
	if basis==HEADLESS:return state.get(PRESENTATION_FLAG,false)!=true
	if basis==ASSISTED:return state.get(ASSISTED_FLAG,false)==true
	return false

static func reject(cache:Dictionary,reason:String)->void:
	if cache.get("rejects",null) is Array and cache.rejects.size()<MAX_REJECTS:cache.rejects.append(reason)

static func prep_origin(state:Dictionary)->Variant:
	var prep:Variant=state.get("synergy_preparation",null)
	if prep is Dictionary and number(prep.get("origin",null)):return float(prep.origin)
	return null

## Fresh cast clears receipt, rejects and the assisted flag. Unsupported/non-P2
## contexts drop any cache so nothing can be imported into them.
static func begin(beat:Dictionary,state:Dictionary)->void:
	var ctx:=context(beat)
	if ctx.is_empty():state.erase(KEY);return
	if ctx.phase=="cast":
		state.erase(ASSISTED_FLAG)
		state[KEY]={"version":VERSION,"profile_id":ctx.profile_id,"origin":float(state.get("sim_time",0.0)),"receipt":{},"blocked":"","rejects":[]}
		return
	var cache:Variant=state.get(KEY,null)
	if cache is Dictionary and cache.get("profile_id","")!=ctx.profile_id:state.erase(KEY)

## Structural/time validation of the per-cast cache (restored JSON included).
static func valid_cache(cache:Variant,ctx:Dictionary,state:Dictionary)->bool:
	if not cache is Dictionary or not number(cache.get("version",null)) or float(cache.version)!=VERSION:return false
	if cache.get("profile_id","")!=ctx.get("profile_id","~") or not number(cache.get("origin",null)) or not cache.get("receipt",null) is Dictionary:return false
	if not cache.get("blocked",null) is String or not cache.get("rejects",null) is Array:return false
	var now:Variant=state.get("sim_time",null)
	if not number(now) or float(now)<0.0 or float(cache.origin)<0.0 or float(now)+EPS<float(cache.origin):return false
	var po:Variant=prep_origin(state)
	if po==null or absf(float(po)-float(cache.origin))>EPS:return false
	return true

static func publish(beat:Dictionary,state:Dictionary,observations:Variant,basis:String)->void:
	var ctx:=context(beat)
	if ctx.is_empty() or not ctx.phase in OBSERVE_PHASES:return
	var cache:Variant=state.get(KEY,null)
	if not cache is Dictionary:return
	if not valid_cache(cache,ctx,state):
		reject(cache,"stale_cache");return
	if cache.blocked!="":return
	if not allowed_basis(state,basis):reject(cache,"basis");return
	var seen:=classify(observations)
	var has_past:bool=not cache.receipt.is_empty()
	if not seen.ok:
		reject(cache,str(seen.reason))
		# Before the first valid receipt nothing can plan; wait for actual data.
		if has_past and str(seen.reason) in REVOKING:
			cache.blocked=str(seen.reason);cache.receipt={}
		return
	if has_past:
		if receipt(beat,state).is_empty():
			reject(cache,"malformed_receipt");cache.blocked="malformed_receipt";cache.receipt={};return
		# Same valid geometry again (any allowed basis) never poisons the past.
		if absf(angle_diff(float(seen.north),float(cache.receipt.get("north",NAN))))>ANGLE_TOL:
			reject(cache,"changed_direction");cache.blocked="changed_direction";cache.receipt={}
		return
	var frozen:Array=[]
	for p in seen.males:frozen.append({"form":"male","pos":[float(p[0]),float(p[1])]})
	for p in seen.females:frozen.append({"form":"female","pos":[float(p[0]),float(p[1])]})
	cache.receipt={"version":VERSION,"profile_id":cache.profile_id,"origin":float(cache.origin),"at":float(state.sim_time),"basis":basis,"north":float(seen.north),"observations":frozen}

## Headless runs only; uses visible/spawn/transition-filtered public geometry.
static func observe_headless(beat:Dictionary,state:Dictionary)->void:
	if state.get(PRESENTATION_FLAG,false)==true or not state.get(KEY,null) is Dictionary:return
	publish(beat,state,entity_observations(beat,state),HEADLESS)

## Explicit oracle/checkpoint synthetic past, never a displayed receipt.
static func publish_assisted(beat:Dictionary,state:Dictionary)->void:
	if not state.get(KEY,null) is Dictionary:return
	state[ASSISTED_FLAG]=true
	publish(beat,state,entity_observations(beat,state),ASSISTED)

static func entity_observations(beat:Dictionary,state:Dictionary)->Array:
	var elapsed:=float(state.get("sim_time",0))-float(state.get("beat_started",0))
	var entities:Array=beat.get("stage_entities",[]).duplicate(true)
	for transition in beat.get("entity_transitions",[]):
		if transition is Dictionary and number(transition.get("at",null)) and elapsed+EPS>=float(transition.at):
			for entity in entities:
				if str(entity.get("id",""))==str(transition.get("id","")):entity.merge(transition,true)
	var out:Array=[]
	for e in entities:
		if not e is Dictionary or not bool(e.get("visible",true)) or str(e.get("stance",""))=="RESOLVED" or elapsed+EPS<float(e.get("spawn_delay",0)):continue
		var form:=base_form(e.get("form",""))
		if form in ["","?"]:continue
		var p:Variant=finite_pos(e.get("pos",null))
		if p==null:p=Vector2(NAN,NAN)
		out.append({"form":form,"pos":[(p as Vector2).x,(p as Vector2).y]})
	return out

## Read-only valid receipt or {} (revalidated: profile/origin/time/basis/geometry).
static func receipt(beat:Dictionary,state:Dictionary)->Dictionary:
	var ctx:=context(beat)
	if ctx.is_empty() or not ctx.phase in PLAN_PHASES:return {}
	var cache:Variant=state.get(KEY,null)
	if not valid_cache(cache,ctx,state) or cache.blocked!="":return {}
	var r:Dictionary=cache.receipt
	if r.is_empty():return {}
	if not number(r.get("version",null)) or float(r.version)!=VERSION or r.get("profile_id","")!=ctx.profile_id:return {}
	if not number(r.get("origin",null)) or absf(float(r.origin)-float(cache.origin))>EPS:return {}
	if not number(r.get("at",null)) or float(r.at)+EPS<float(cache.origin) or float(r.at)>float(state.sim_time)+EPS:return {}
	if not allowed_basis(state,r.get("basis",null)) or not number(r.get("north",null)):return {}
	var again:=classify(r.get("observations",null))
	if not again.ok or absf(angle_diff(float(again.north),float(r.north)))>ANGLE_TOL:return {}
	return r.duplicate(true)

static func north(beat:Dictionary,state:Dictionary)->Variant:
	var r:=receipt(beat,state)
	return null if r.is_empty() else float(r.north)
