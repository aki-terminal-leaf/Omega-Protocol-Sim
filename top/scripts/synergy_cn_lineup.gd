# SPDX-License-Identifier: MIT
extends RefCounted
## CN Moogle Party Synergy INITIAL lineup only (cast beat).
## Source: original CN poster (sha256 2b308bdc...4d35), crop cn-p2-fixed-priority:
## 「面向A点 从左往右 按优先级高→低 横排排队」 icons H1 MT ST D1 D2 D3 D4 H2.
## This is a FIXED role rank. Spacing/centre are simulator training choices,
## NOT official game coordinates. Duplicate-glyph pair sides remain UNKNOWN and
## are deliberately not handled here.
const Rules=preload("res://scripts/rules.gd")
const Markers=preload("res://scripts/markers.gd")
const KEY:="synergy_cn_lineup"
const SCHEMA:=1
const PROFILE_ID:="cn_moogle"
## Canonical actor indices (MT ST H1 H2 D1..D4), high -> low priority.
const ORDER:=[2,0,1,4,5,6,7,3]
const SPACING:=1.8
const DEFAULT_A:=Vector2(0.0,-13.0)
const MIN_A_RADIUS:=1.0

static func metadata()->Dictionary:
	return {"schema":SCHEMA,"profile_id":PROFILE_ID,"order":ORDER.duplicate(),"spacing":SPACING,"anchor":"waymark_A","phase":"cast","source":"CN poster fixed role priority; slot coordinates are simulator training choices"}

static func valid_metadata(raw:Variant)->bool:
	if not raw is Dictionary:return false
	var meta:Dictionary=raw
	var schema:Variant=meta.get("schema")
	if not (schema is int or schema is float) or float(schema)!=float(SCHEMA):return false
	if str(meta.get("profile_id",""))!=PROFILE_ID or str(meta.get("anchor",""))!="waymark_A" or str(meta.get("phase",""))!="cast":return false
	var spacing:Variant=meta.get("spacing")
	if not (spacing is int or spacing is float) or not is_finite(float(spacing)) or absf(float(spacing)-SPACING)>0.000001:return false
	var order:Variant=meta.get("order")
	if not order is Array or (order as Array).size()!=ORDER.size():return false
	for i in ORDER.size():
		var value:Variant=order[i]
		if not (value is int or value is float) or float(value)!=float(ORDER[i]):return false
	return true

## Slots for a facing point A; empty Array when A cannot define a direction.
static func slots_for_a(a:Vector2)->Array:
	if not is_finite(a.x) or not is_finite(a.y) or a.length()<MIN_A_RADIUS:return []
	var forward:Vector2=a.normalized()
	var right:=Vector2(-forward.y,forward.x)
	var slots:Array=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
	for rank in ORDER.size():
		slots[int(ORDER[rank])]=right*((float(rank)-3.5)*SPACING)
	return slots

static func default_slots()->Array:
	return slots_for_a(DEFAULT_A)

## Current public waymark A from state.waymark_layout only.
static func public_a(state:Dictionary)->Dictionary:
	if not state.has("waymark_layout"):return {"ok":false,"reason":"missing_layout"}
	var checked:Dictionary=Markers.validate_layout(state.waymark_layout)
	if not bool(checked.get("ok",false)):return {"ok":false,"reason":"invalid_layout"}
	for mark in checked.layout.marks:
		if str(mark.id)!="A":continue
		if not bool(mark.enabled):return {"ok":false,"reason":"disabled_A"}
		var a:Vector2=Rules.v(mark.pos)
		if a.length()<MIN_A_RADIUS:return {"ok":false,"reason":"center_A"}
		return {"ok":true,"pos":a}
	return {"ok":false,"reason":"missing_A"}

static func actual_pose(actor:int,actors:Array)->Dictionary:
	if actors.size()!=8 or actor<0 or actor>=8 or not actors[actor] is Dictionary or not actors[actor].has("pos"):return {"ok":false}
	var raw:Variant=actors[actor].pos
	if not (raw is Vector2 or (raw is Array and (raw as Array).size()==2)):return {"ok":false}
	var p:Vector2=Rules.v(raw)
	if not is_finite(p.x) or not is_finite(p.y):return {"ok":false}
	return {"ok":true,"pos":p}

## {ok, goal, reason}. Never reads beat.positions, assignments, eye, RNG or future beats.
static func resolve(actor:int,beat:Dictionary,actors:Array,state:Dictionary)->Dictionary:
	var pose:=actual_pose(actor,actors)
	if not bool(pose.ok):return {"ok":false,"reason":"invalid_actor"}
	var hold:Vector2=pose.pos
	if not valid_metadata(beat.get(KEY)):return {"ok":false,"goal":hold,"reason":"invalid_metadata"}
	if int(state.get("human_actor",-1))==actor:return {"ok":false,"goal":hold,"reason":"human_owned"}
	var a:=public_a(state)
	if not bool(a.ok):return {"ok":false,"goal":hold,"reason":str(a.reason)}
	var slots:=slots_for_a(a.pos)
	if slots.is_empty():return {"ok":false,"goal":hold,"reason":"center_A"}
	return {"ok":true,"goal":slots[actor],"reason":"public_A"}

## Bot goal. Unreachable invalid-actor case (no pose exists) returns origin
## only because no actual pose can be held; Main only asks for actors 0..7.
static func goal(actor:int,beat:Dictionary,actors:Array,state:Dictionary)->Vector2:
	var r:=resolve(actor,beat,actors,state)
	return r.goal if r.has("goal") else Vector2.ZERO
