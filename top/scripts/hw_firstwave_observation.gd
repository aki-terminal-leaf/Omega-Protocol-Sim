# SPDX-License-Identifier: MIT
extends RefCounted
## First HW tower wave: coaching goals derived only from publicly presented
## state (prestaged neutral spots, captured order, actual initial rot colour
## and the tower shapes actually drawn). Never reads hidden orientations,
## pending tower geometry, hw_pattern or beat.positions for wave one.
## Only chooses goals; never writes actor positions/statuses/events/beats.
## Mutates only state.hw.first_public (and, through hw_cooperation, its
## existing hw_tower_choice_* keys).
const Rules = preload("res://scripts/rules.gd")
const P = preload("res://scripts/hw_patterns.gd")
const C = preload("res://scripts/hw_cooperation.gd")

const TOWER_PHASE := 24.0
const WAIT_AFTER_OBSERVED := 6.0
const CARRIER_LANE := 18.0
const SYNC_LANE := 12.5
const ANGLE_STEP := 0.1
const ANGLE_DONE := 0.03
const EPS := 0.000001

# ---------- safe parsing ----------
static func _num(value) -> bool:
    return (typeof(value)==TYPE_FLOAT or typeof(value)==TYPE_INT) and is_finite(float(value))

static func _vec(value):
    if value is Vector2:
        return value if is_finite(value.x) and is_finite(value.y) else null
    if value is Array and value.size()==2 and _num(value[0]) and _num(value[1]):
        return Vector2(float(value[0]),float(value[1]))
    return null

static func _order(value) -> Array:
    if not (value is Array) or value.size()!=8: return []
    var result: Array=[]
    for item in value:
        if not _num(item) or float(item)!=floor(float(item)): return []
        var i := int(item)
        if i<0 or i>7 or i in result: return []
        result.append(i)
    return result

static func _points(value) -> Array:
    if not (value is Array) or value.size()!=8: return []
    var result: Array=[]
    for item in value:
        var p=_vec(item)
        if p==null: return []
        result.append(p)
    return result

static func _xy(points: Array) -> Array:
    return points.map(func(p):return P.xy(p))

static func _has_any(buffs, names: Array) -> bool:
    if not (buffs is Dictionary): return false
    for n in names:
        if buffs.has(n): return true
    return false

static func _colour_of(buffs) -> String:
    var red := _has_any(buffs,["smell_red","red"]); var blue := _has_any(buffs,["smell_blue","blue"])
    if red==blue: return ""
    return "red" if red else "blue"

static func _hw(state: Dictionary):
    var hw=state.get("hw",null)
    return hw if hw is Dictionary else null

# ---------- begin ----------
static func begin(beat: Dictionary, actors: Array, state: Dictionary) -> void:
    if not beat.has("hw_events"): return
    var hw=_hw(state)
    if hw==null: return
    # New HW state always replaces any previous cache.
    var cache := {"valid":false,"reason":"","origin":0.0,"receipt":null,"mapping":null,"lanes":{}}
    hw.first_public=cache
    state.erase("hw_firstwave_assisted")
    if not _num(hw.get("start",null)): cache.reason="missing hw.start"; return
    cache.origin=float(hw.start)
    if actors.size()!=8: cache.reason="need 8 actors"; return
    var config=beat.get("hw_public_firstwave",null)
    if not (config is Dictionary): cache.reason="missing hw_public_firstwave"; return
    var order := _order(config.get("order",null))
    if order.is_empty(): cache.reason="order must be 8 unique indices 0..7"; return
    var neutral := _points(config.get("neutral",null))
    if neutral.is_empty(): cache.reason="neutral must be 8 finite points"; return
    var buffs=state.get("statuses",null)
    if not (buffs is Array) or buffs.size()!=8: cache.reason="statuses unavailable"; return
    var colour := _colour_of(buffs[order[0]])
    if colour=="" or _colour_of(buffs[order[1]])!=colour: cache.reason="overflow pair rot colour not public"; return
    var other := "blue" if colour=="red" else "red"
    for slot in [0,1]:
        if not _has_any(buffs[order[slot]],["smell_overflow","overflow"]): cache.reason="overflow pair status mismatch"; return
    for slot in [4,5]:
        if not _has_any(buffs[order[slot]],["smell_sync","sync"]) or _colour_of(buffs[order[slot]])!=other: cache.reason="sync pair status mismatch"; return
    cache.order=order; cache.neutral=_xy(neutral); cache.colour=colour; cache.valid=true

static func _cache(state: Dictionary):
    var hw=_hw(state)
    if hw==null: return null
    var cache=hw.get("first_public",null)
    if not (cache is Dictionary) or not bool(cache.get("valid",false)): return null
    if not _num(hw.get("start",null)) or not _num(cache.get("origin",null)) or absf(float(hw.start)-float(cache.origin))>EPS: return null
    if _order(cache.get("order",null)).is_empty() or _points(cache.get("neutral",null)).is_empty(): return null
    if not (str(cache.get("colour","")) in ["red","blue"]): return null
    return cache

static func _now(state: Dictionary) -> float:
    var t=state.get("sim_time",0.0)
    return float(t) if _num(t) else NAN

# A complete fresh receipt, or null. Future/malformed receipts are rejected.
static func _receipt(cache: Dictionary, now: float):
    var r=cache.get("receipt",null)
    if not (r is Dictionary) or not is_finite(now): return null
    if not _num(r.get("at",null)) or not _num(r.get("orientation",null)): return null
    var at := float(r.at)
    if at>now+EPS or at<float(cache.origin)-EPS: return null
    if _points(r.get("targets",null)).is_empty(): return null
    if not (str(r.get("source_kind","")) in ["arena_presented","synthetic_runtime_fixture"]): return null
    return r

static func _in_scope(beat: Dictionary) -> bool:
    if not bool(beat.get("hello_world",false)): return false
    var c=beat.get("hw_tower_cooperation",null)
    if c is Dictionary:
        return _num(c.get("round",null)) and int(c.round)==0
    return beat.has("hw_public_firstwave")

# ---------- publish ----------
static func _tower_axis(shapes, colour: String):
    if not (shapes is Array): return null
    var towers: Array=[]
    for s in shapes:
        if s is Dictionary and str(s.get("kind",""))=="tower" and s.get("hw_preview",false)==true: towers.append(s)
    if towers.size()!=4: return null
    var bins: Array=[]; var same := Vector2.ZERO; var opposite := Vector2.ZERO; var reds := 0
    for s in towers:
        var p=_vec(s.get("pos",null))
        if p==null or not _num(s.get("radius",null)) or absf(float(s.radius)-P.TOWER_RADIUS)>0.001: return null
        if absf(p.length()-P.ORIGIN_RADIUS)>0.05: return null
        var deg := rad_to_deg(atan2(p.x,-p.y))
        var k := roundi(deg/45.0)
        if absf(wrapf(deg-45.0*k,-180.0,180.0))>0.5: return null
        k=posmod(k,8)
        if k in bins or (not bins.is_empty() and k%2!=int(bins[0])%2): return null
        bins.append(k)
        var c := str(s.get("colour",""))
        if not (c in ["red","blue"]): return null
        if c=="red": reds+=1
        if c==colour: same+=p.normalized()
        else: opposite+=p.normalized()
    if reds!=2 or same.length()<1.3 or same.normalized().dot(opposite.normalized())>-0.99: return null
    var axis_deg := rad_to_deg(Vector2.UP.angle_to(same))
    return posmod(roundi(axis_deg/45.0),8)

static func _store(beat: Dictionary, state: Dictionary, shapes, source_kind: String) -> bool:
    var cache=_cache(state)
    if cache==null or not _in_scope(beat): return false
    var now := _now(state)
    if not is_finite(now) or now<float(cache.origin)-EPS or now>=float(cache.origin)+TOWER_PHASE: return false
    if _receipt(cache,now)!=null: return true  # retained snapshot; never mutated
    var orientation=_tower_axis(shapes,str(cache.colour))
    if orientation==null: return false
    var order := _order(cache.order)
    cache.receipt={"at":snappedf(now,0.000000001),"orientation":int(orientation),"targets":_xy(P.formation(0,int(orientation),order)),"source_kind":source_kind,"assisted":source_kind!="arena_presented","source_onset":"source_unknown"}
    cache.mapping=null; cache.lanes={}
    return true

static func publish(beat: Dictionary, state: Dictionary, shapes) -> void:
    _store(beat,state,shapes,"arena_presented")

# ---------- goal ----------
static func _mapping(cache: Dictionary, targets: Array, actors: Array) -> Array:
    var stored=_order(cache.get("mapping",null))
    if not stored.is_empty(): return stored
    var order := _order(cache.order)
    var mapping: Array=range(8)
    for pair in [[order[0],order[1]],[order[4],order[5]]]:
        var a:int=pair[0]; var b:int=pair[1]
        var pa=_vec(actors[a].get("pos",null)) if actors[a] is Dictionary else null
        var pb=_vec(actors[b].get("pos",null)) if actors[b] is Dictionary else null
        if pa==null or pb==null: continue
        var keep := maxf(absf(angle_difference(pa.angle(),targets[a].angle())),absf(angle_difference(pb.angle(),targets[b].angle())))
        var swap := maxf(absf(angle_difference(pa.angle(),targets[b].angle())),absf(angle_difference(pb.angle(),targets[a].angle())))
        if swap<keep-EPS: mapping[a]=b; mapping[b]=a
    cache.mapping=mapping
    return mapping

# Motion is observed, never read from the human's intended destination/keys.
# Standing in a legal tower is valid; a brief stationary observation avoids
# interpreting the pre-reveal position as a fresh instruction on frame one.
static func _choice_motion(human:int,hp:Vector2,other:Vector2,cache:Dictionary,state:Dictionary)->bool:
    var now:=_now(state)
    var previous=cache.get("human_motion",{})
    var stable_since:=now
    var anchor:=hp
    var closer:=false
    if previous is Dictionary and int(previous.get("actor",-1))==human and _num(previous.get("at",null)) and float(previous.at)<=now:
        # Compare against the stationary interval anchor, NOT the last frame.
        # Otherwise sufficiently high frame rates misclassify continuous motion.
        var old_anchor=_vec(previous.get("stable_anchor",previous.get("pos",null)))
        if old_anchor!=null and hp.distance_to(old_anchor)<=0.02 and _num(previous.get("stable_since",null)):
            stable_since=float(previous.stable_since)
            anchor=old_anchor
        var dt:=now-float(previous.at)
        if dt>EPS and _num(previous.get("other_distance",null)):
            closer=(float(previous.other_distance)-hp.distance_to(other))/dt>0.1
    cache.human_motion={"actor":human,"at":now,"pos":P.xy(hp),"stable_anchor":P.xy(anchor),"stable_since":stable_since,"other_distance":hp.distance_to(other)}
    return closer or now-stable_since>=0.15-EPS

static func _human_choice(actor:int,beat:Dictionary,actors:Array,state:Dictionary,targets:Array,mapping:Array,cache:Dictionary):
 if not beat.has("hw_tower_cooperation") and not beat.has("hw_tower_cooperations"):return null
 var copy:Dictionary=beat.duplicate(true)
 var choices:Array=[]
 if copy.get("hw_tower_cooperations",null) is Array:choices.append_array(copy.hw_tower_cooperations)
 if choices.is_empty() and copy.get("hw_tower_cooperation",null) is Dictionary:choices.append(copy.hw_tower_cooperation)
 choices=choices.filter(func(c):return c is Dictionary and _num(c.get("round",null)) and float(c.round)==0.0)
 copy.hw_tower_cooperations=choices
 if copy.has("hw_tower_cooperation") and float(copy.hw_tower_cooperation.get("round",-1))!=0.0:copy.erase("hw_tower_cooperation")
 var eligible:=false
 for c in choices:
  if not (c is Dictionary) or int(c.get("round",-1))!=0:continue
  if not (c.get("actors",null) is Array) or c.actors.size()!=2:return null
  var pair:Array=[]
  for v in c.actors:
   if not _num(v) or int(v)<0 or int(v)>7:return null
   pair.append(int(v))
  c.goals=[P.xy(targets[mapping[pair[0]]]),P.xy(targets[mapping[pair[1]]])]
  var human:=int(state.get("human_actor",-1))
  if human not in pair or actor not in pair or actor==human:continue
  var hp=_vec(actors[human].get("pos",null))
  if hp==null:return null
  var own:Vector2=targets[mapping[human]]
  var other:Vector2=targets[mapping[int(pair[1-pair.find(human)])]]
  var key:="hw_tower_choice_0_%d"%mini(pair[0],pair[1])
  if _now(state)<float(state.hw.start)+TOWER_PHASE and hp.distance_to(own)<=5.5 and hp.distance_to(other)>5.5:state.hw.erase(key)
  # A player already near the other tower on the reveal frame may be
  # departing it. Actual approach/hold, not that stale pose, establishes choice.
  eligible=state.hw.has(key) or _choice_motion(human,hp,other,cache,state)
 if not eligible:return null
 var rep=C.replacement_actor(actor,copy,actors,state)
 return rep if rep is int and rep>=0 and rep<8 else null

static func _lane_goal(actor: int, here: Vector2, target: Vector2, lane: float, cache: Dictionary) -> Vector2:
    if not (cache.get("lanes",null) is Dictionary): cache.lanes={}
    if not (cache.get("lane_targets",null) is Dictionary): cache.lane_targets={}
    var key := str(actor)
    var prior_target=_vec(cache.lane_targets.get(key,null))
    if prior_target==null or prior_target.distance_to(target)>0.001:
        cache.lanes[key]="out"
        cache.lane_targets[key]=P.xy(target)
    var phase := str(cache.lanes.get(key,"out"))
    if phase=="in": return target
    if phase=="out":
        if absf(here.length()-lane)>0.2:
            return (here.normalized() if here.length()>0.001 else Vector2.UP)*lane
        phase="around"; cache.lanes[key]=phase
    var difference := angle_difference(here.angle(),target.angle())
    if absf(difference)>ANGLE_DONE:
        return Vector2.from_angle(here.angle()+clampf(difference,-ANGLE_STEP,ANGLE_STEP))*lane
    cache.lanes[key]="in"
    return target

## Returns a Vector2 coaching goal, or null to keep the existing legacy route.
static func goal(actor: int, beat: Dictionary, actors: Array, state: Dictionary):
    if not _in_scope(beat) or actors.size()!=8 or actor<0 or actor>7: return null
    var here=_vec(actors[actor].get("pos",null)) if actors[actor] is Dictionary else null
    if here==null: return Vector2.ZERO
    var cache=_cache(state)
    # A broken observation must never fall through to solved future goals.
    if cache==null: return here
    var now := _now(state)
    if not is_finite(now) or now<float(cache.origin)-EPS: return here
    if actor==int(state.get("human_actor",-1)): return here
    if _receipt(cache,now)==null and not bool(state.get("hw_firstwave_presentation_required",false)):
        # Explicit legacy non-Main fixture: never ordinary/human source proof.
        if _store(beat,state,beat.get("shapes",[]),"synthetic_runtime_fixture"): state.hw_firstwave_assisted=true
    var receipt=_receipt(cache,now)
    var neutral := _points(cache.neutral)
    if receipt==null: return neutral[actor]
    if bool(receipt.get("assisted",false)): state.hw_firstwave_assisted=true
    var targets := _points(receipt.targets)
    var mapping := _mapping(cache,targets,actors)
    var human_rep=_human_choice(actor,beat,actors,state,targets,mapping,cache)
    var effective: int=mapping[actor]
    if human_rep!=null: effective=mapping[int(human_rep)]
    if now>=float(cache.origin)+TOWER_PHASE:
        return load("res://scripts/hw_courses.gd").base_goal(effective,beat,state)
    var slot := _order(cache.order).find(actor)
    var target: Vector2=targets[effective]
    if slot in [2,3,6,7]:
        return neutral[actor] if now<float(receipt.at)+WAIT_AFTER_OBSERVED else target
    return _lane_goal(actor,here,target,CARRIER_LANE if slot<2 else SYNC_LANE,cache)
