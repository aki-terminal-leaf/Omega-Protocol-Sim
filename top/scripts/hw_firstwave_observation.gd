# SPDX-License-Identifier: MIT
extends RefCounted
## First HW tower wave: coaching goals derived only from publicly presented
## state (prestaged neutral spots, captured order, actual initial rot colour
## and the tower shapes actually drawn). Never reads hidden orientations,
## pending tower geometry, hw_pattern or beat.positions for wave one.
## Only chooses goals; never writes actor positions/statuses/events/beats.
## Mutates only state.hw.first_public, state.hw.later_public (rounds 1..3)
## and, through hw_cooperation, its existing hw_tower_choice_* keys.
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
    state.erase("hw_later_assisted")
    hw.erase("later_public")
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
    if _later_round(beat)>0: _store_later(beat,state,shapes,"arena_presented"); return
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
    var later_round := _later_round(beat)
    if later_round>0: return _later_goal(actor,later_round,beat,actors,state)
    if bool(beat.get("hello_world",false)) and _required(state):
        # Final Critical Error beat has no cooperation metadata. Retain the
        # last observed wave's public chain rather than an authored endpoint.
        var cache_end=_cache(state)
        if cache_end!=null and _now(state)>=float(cache_end.origin)+float(_window(3)[1])-EPS:
            return _later_goal(actor,3,beat,actors,state)
        # Malformed/unsupported metadata is not permission to read base_goal.
        var c=beat.get("hw_tower_cooperation",null)
        if (not beat.has("hw_tower_cooperation") and not beat.has("hw_public_firstwave")) or (beat.has("hw_tower_cooperation") and (not (c is Dictionary) or not _num(c.get("round",null)) or float(c.round)!=0.0)):
            return _vec(actors[actor].get("pos",null)) if actor>=0 and actor<actors.size() and actors[actor] is Dictionary else Vector2.ZERO
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

# ---------- later rounds 1..3 (player-facing waves 2..4) ----------
# Dispatch uses validated round metadata only; never authored actors/goals,
# hw_pattern, beat.positions/hw_path, pending towers or future events.
# State lives in state.hw.later_public, keyed by hw.start and round.
const ROUND_STEP := 21.0
const TETHER_LANE := 3.0

static func _later_round(beat: Dictionary) -> int:
    if not bool(beat.get("hello_world",false)): return -1
    var c=beat.get("hw_tower_cooperation",null)
    if not (c is Dictionary) or not _num(c.get("round",null)): return -1
    var r := float(c.round)
    if r!=floor(r) or r<1.0 or r>3.0: return -1
    return int(r)

static func _tower_at(r: int) -> float:
    return TOWER_PHASE+ROUND_STEP*r

static func _window(r: int) -> Array:
    return [_tower_at(r-1)+10.0,_tower_at(r)+(10.2 if r==3 else 10.0)]

static func _required(state: Dictionary) -> bool:
    return bool(state.get("hw_later_presentation_required",state.get("hw_firstwave_presentation_required",false)))

static func _later(state: Dictionary, cache: Dictionary, r: int) -> Dictionary:
    var hw=_hw(state)
    var root=hw.get("later_public",null)
    if not (root is Dictionary) or not _num(root.get("origin",null)) or absf(float(root.origin)-float(cache.origin))>EPS or not (root.get("rounds",null) is Dictionary):
        # New attempt/retry: never reuse an older lifecycle.
        root={"origin":float(cache.origin),"rounds":{}}
        hw.later_public=root
    var rc=root.rounds.get(str(r),null)
    if rc is Dictionary and int(rc.get("round",-1))==r and _num(rc.get("origin",null)) and absf(float(rc.origin)-float(cache.origin))<=EPS: return rc
    rc={"round":r,"origin":float(cache.origin),"valid":false,"reason":"","chain":null,"colour":"","anchors":null,"receipt":null,"alloc":null,"swaps":{},"final_chain":null,"lanes":{},"lane_targets":{}}
    root.rounds[str(r)]=rc
    return rc

# Public chain: root order with the observed first-wave mapping, then each
# round's final (human-influenced) chain. Never the authored swapped order.
static func _chain_base(state: Dictionary, cache: Dictionary, r: int) -> Array:
    if r>1:
        var prev=_hw(state).later_public.rounds.get(str(r-1),null)
        if prev is Dictionary:
            for key in ["final_chain","observed_chain","alloc","chain"]:
                var c := _order(prev.get(key,null))
                if not c.is_empty(): return c
    var chain := _order(cache.order)
    var mapping := _order(cache.get("mapping",null))
    if not mapping.is_empty():
        for s in 8: chain[s]=mapping[int(chain[s])]
    # Apply the actual round-zero human swap retained by firstwave cooperation.
    # The key is public observed choice, not authored tower order or geometry.
    var human := int(state.get("human_actor",-1))
    var initial := _order(cache.order)
    for base in [0,4]:
        var pair:Array=[initial[base],initial[base+1]]
        if human in pair:
            var choice_key := "hw_tower_choice_0_%d"%mini(pair[0],pair[1])
            if _hw(state).has(choice_key) and int(_hw(state)[choice_key])==1-pair.find(human):
                var a=chain[base];chain[base]=chain[base+1];chain[base+1]=a
    return chain

static func _slot_role(slot: int, r: int) -> int:
    var role := posmod(slot+2*r,8)
    return role-role%2

static func _active_status(buffs, name:String, now:float, expected_expiry:float=-1.0)->bool:
    if not (buffs is Dictionary):return false
    var status=buffs.get(name,null)
    if not (status is Dictionary) or not _num(status.get("expires",null)):return false
    var expiry:=float(status.expires)
    return expiry>now+EPS and (expected_expiry<0.0 or absf(expiry-expected_expiry)<0.01)

# Freeze public roles and the radial staging anchor once per round. Invalid
# combinations are rejected (retried next frame), never silently solved.
static func _later_prepare(rc: Dictionary, cache: Dictionary, r: int, actors: Array, state: Dictionary) -> void:
    if bool(rc.valid): return
    var chain := _chain_base(state,cache,r)
    if chain.is_empty(): rc.reason="no public chain"; return
    var buffs=state.get("statuses",null)
    if not (buffs is Array) or buffs.size()!=8: rc.reason="statuses unavailable"; return
    var cs := posmod(-2*r,8); var ss := posmod(4-2*r,8); var rs := posmod(2-2*r,8); var ls := posmod(6-2*r,8)
    var now:=_now(state)
    var tower_time:=float(rc.origin)+_tower_at(r)
    var colour := _colour_of(buffs[chain[cs]])
    if colour=="" or _colour_of(buffs[chain[cs+1]])!=colour: rc.reason="overflow pair rot colour not public"; return
    var other := "blue" if colour=="red" else "red"
    for k in 2:
        if not _active_status(buffs[chain[cs+k]],"overflow",now,tower_time) or not _active_status(buffs[chain[cs+k]],colour,now):rc.reason="overflow pair status/expiry mismatch";return
        if not _active_status(buffs[chain[ss+k]],"sync",now,tower_time) or not _active_status(buffs[chain[ss+k]],other,now):rc.reason="sync pair status/expiry mismatch";return
        # Multiple future smell codes coexist. Validate the current pair's
        # public expiry instead of incorrectly requiring exactly two globally.
        if not _active_status(buffs[chain[rs+k]],"remote_code_smell",now,tower_time-1.0):rc.reason="remote tether pair expiry mismatch";return
        if not _active_status(buffs[chain[ls+k]],"local_code_smell",now,tower_time-1.0):rc.reason="local tether pair expiry mismatch";return
    var anchors: Array=[]
    for actor in 8:
        if actor in state.get("dead",[]) or not (actors[actor] is Dictionary): rc.reason="dead/missing actor"; return
        var p=_vec(actors[actor].get("pos",null))
        if p==null: rc.reason="pose unavailable"; return
        var role := _slot_role(chain.find(actor),r)
        var lane := CARRIER_LANE if role==0 else (SYNC_LANE if role==4 else TETHER_LANE)
        anchors.append(P.xy((p.normalized() if p.length()>0.001 else Vector2.UP)*lane))
    rc.chain=chain; rc.colour=colour; rc.anchors=anchors; rc.reason=""; rc.valid=true
    # Existing reporting keys mirror the observed policy; they never decide it.
    # Capture round-zero public choice into chain before clearing old reports.
    if int(state.hw.get("cooperation_round",-1))!=r:
        for old_key in state.hw.keys():
            if str(old_key).begins_with("hw_tower_choice_"):state.hw.erase(old_key)
        state.hw.cooperation_round=r

static func _later_receipt(rc: Dictionary, now: float):
    var rec=rc.get("receipt",null)
    if not (rec is Dictionary) or not is_finite(now): return null
    if not _num(rec.get("at",null)) or not _num(rec.get("orientation",null)) or not _num(rec.get("round",null)) or float(rec.round)!=float(rc.round): return null
    var w := _window(int(rc.round))
    var at := float(rec.at)
    if at>now+EPS or at<float(rc.origin)+float(w[0])-EPS or at>=float(rc.origin)+_tower_at(int(rc.round)): return null
    if not (str(rec.get("source_kind","")) in ["arena_presented","synthetic_runtime_fixture"]): return null
    if bool(rec.get("assisted",false))!=(str(rec.source_kind)=="synthetic_runtime_fixture"):return null
    if float(rec.orientation)!=floor(float(rec.orientation)) or int(rec.orientation)<0 or int(rec.orientation)>7:return null
    if str(rec.get("colour",""))!=str(rc.colour) or not (rec.get("towers",null) is Array):return null
    var shapes:Array=[]
    for tower in rec.towers:
        if not (tower is Dictionary):return null
        var shape:Dictionary=tower.duplicate(true);shape.kind="tower";shape.hw_preview=true;shapes.append(shape)
    var observed_axis=_tower_axis(shapes,str(rc.colour))
    if observed_axis==null or int(observed_axis)!=int(rec.orientation):return null
    return rec

static func _store_later(beat: Dictionary, state: Dictionary, shapes, source_kind: String) -> bool:
    var r := _later_round(beat)
    var cache=_cache(state)
    if r<1 or cache==null: return false
    var now := _now(state)
    var w := _window(r)
    # Only before this round's towers resolve; late/early/foreign clocks fail closed.
    if not is_finite(now) or now<float(cache.origin)+float(w[0])-EPS or now>=float(cache.origin)+_tower_at(r): return false
    var rc := _later(state,cache,r)
    if not bool(rc.valid): return false
    if rc.receipt!=null: return _later_receipt(rc,now)!=null  # immutable once accepted
    var orientation=_tower_axis(shapes,str(rc.colour))
    if orientation==null: return false
    var towers: Array=[]
    for s in shapes:
        if s is Dictionary and str(s.get("kind",""))=="tower" and s.get("hw_preview",false)==true:
            towers.append({"pos":P.xy(_vec(s.pos)),"colour":str(s.colour),"radius":float(s.radius)})
    rc.receipt={"round":r,"at":snappedf(now,0.000000001),"orientation":int(orientation),"colour":str(rc.colour),"towers":towers,"source_kind":source_kind,"assisted":source_kind!="arena_presented","source_onset":"source_unknown"}
    rc.alloc=null; rc.swaps={}; rc.lanes={}; rc.lane_targets={}
    return true

# Same-colour side allocation from actual observed pose; strict-less-than tie.
static func _alloc(rc: Dictionary, r: int, orientation: int, actors: Array) -> Array:
    var stored := _order(rc.get("alloc",null))
    if not stored.is_empty(): return stored
    var chain := _order(rc.chain)
    var goals := P.formation(r,orientation,chain)
    for role in [0,4]:
        var slot := posmod(role-2*r,8)
        var a: int=chain[slot]; var b: int=chain[slot+1]
        var pa=_vec(actors[a].get("pos",null)) if actors[a] is Dictionary else null
        var pb=_vec(actors[b].get("pos",null)) if actors[b] is Dictionary else null
        if pa==null or pb==null: continue
        var keep := maxf(absf(angle_difference(pa.angle(),goals[a].angle())),absf(angle_difference(pb.angle(),goals[b].angle())))
        var swap := maxf(absf(angle_difference(pa.angle(),goals[b].angle())),absf(angle_difference(pb.angle(),goals[a].angle())))
        if swap<keep-EPS: chain[slot]=b; chain[slot+1]=a
    rc.alloc=chain
    return chain

# Human legal choice: membership of the receipt's actual drawn same-colour
# circles only. Reversible until tower resolution; never moves the human.
static func _later_chain(rc: Dictionary, r: int, orientation: int, alloc: Array, actors: Array, state: Dictionary) -> Array:
    var chain := alloc.duplicate()
    var human := int(state.get("human_actor",-1))
    var hs := chain.find(human)
    if hs>=0 and _slot_role(hs,r) in [0,4] and actors[human] is Dictionary:
        var base := hs-posmod(hs+2*r,8)%2
        var partner: int=chain[base+(1 if hs==base else 0)]
        var targets := P.formation(r,orientation,alloc)
        var hp=_vec(actors[human].get("pos",null))
        var key := str(base)
        if hp!=null and _now(state)<float(rc.origin)+_tower_at(r) and human not in state.get("dead",[]) and partner not in state.get("dead",[]):
            var now:=_now(state)
            var buffs:Array=state.get("statuses",[])
            var colour:=_colour_of(buffs[human]) if buffs.size()==8 else ""
            var bug:="overflow" if _slot_role(hs,r)==0 else "sync"
            if colour!="" and _active_status(buffs[human],colour,now) and _active_status(buffs[partner],colour,now) and _active_status(buffs[human],bug,now) and _active_status(buffs[partner],bug,now):
                var own:Vector2=targets[human];var other:Vector2=targets[partner]
                var towers:Array=rc.receipt.towers.filter(func(t):return str(t.colour)==colour)
                if towers.size()==2:
                    var oi:=0 if own.distance_to(Rules.v(towers[0].pos))<own.distance_to(Rules.v(towers[1].pos)) else 1
                    var ai:=0 if other.distance_to(Rules.v(towers[0].pos))<other.distance_to(Rules.v(towers[1].pos)) else 1
                    if oi!=ai:
                        var inside_own:bool=hp.distance_to(Rules.v(towers[oi].pos))<=float(towers[oi].radius)
                        var inside_other:bool=hp.distance_to(Rules.v(towers[ai].pos))<=float(towers[ai].radius)
                        if inside_own and not inside_other:rc.swaps[key]=false
                        elif inside_other and not inside_own and _choice_motion(human,hp,other,rc,state):rc.swaps[key]=true
        if rc.swaps.has(key):
            var report_key:="hw_tower_choice_%d_%d"%[r,mini(human,partner)]
            var hi:=hs-base
            state.hw[report_key]=1-hi if bool(rc.swaps[key]) else hi
        if bool(rc.swaps.get(key,false)): chain[base]=alloc[base+1]; chain[base+1]=alloc[base]
    return chain

static func _later_goal(actor: int, r: int, beat: Dictionary, actors: Array, state: Dictionary):
    if actors.size()!=8 or actor<0 or actor>7: return null
    var here=_vec(actors[actor].get("pos",null)) if actors[actor] is Dictionary else null
    var strict := _required(state)
    if here==null: return Vector2.ZERO if strict else null
    var cache=_cache(state)
    # Main: strict hold. Explicit non-Main legacy fixture: keep legacy route.
    if cache==null: return here if strict else null
    var now := _now(state)
    var w := _window(r)
    if not is_finite(now) or now<float(cache.origin)+float(w[0])-EPS or (r<3 and now>=float(cache.origin)+float(w[1])): return here if strict else null
    var rc := _later(state,cache,r)
    _later_prepare(rc,cache,r,actors,state)
    if not bool(rc.valid): return here if strict else null
    if actor==int(state.get("human_actor",-1)): return here
    if rc.receipt==null and not strict:
        # Explicit legacy non-Main fixture: never ordinary/human source proof.
        if _store_later(beat,state,beat.get("shapes",[]),"synthetic_runtime_fixture"): state.hw_later_assisted=true
    var anchors := _points(rc.anchors)
    var receipt=_later_receipt(rc,now)
    # Withheld/missing publication: hold the frozen public staging anchor.
    if receipt==null: return anchors[actor]
    if bool(receipt.get("assisted",false)): state.hw_later_assisted=true
    var orientation := int(receipt.orientation)
    var tower_time := float(rc.origin)+_tower_at(r)
    var chain: Array
    if now>=tower_time:
        if _order(rc.get("final_chain",null)).is_empty():
            var observed:=_order(rc.get("observed_chain",null))
            rc.final_chain=observed if not observed.is_empty() else _later_chain(rc,r,orientation,_alloc(rc,r,orientation,actors),actors,state)
        chain=_order(rc.final_chain)
        var route=beat.get("hw_route",{})
        var stages: Array=load("res://scripts/hw_courses.gd").post_tower_stages(r,orientation,chain,route if route is Dictionary else {})
        var p=load("res://scripts/hw_courses.gd").sample_post_tower(stages,now-tower_time,actor)
        return p if p is Vector2 else anchors[actor]
    chain=_later_chain(rc,r,orientation,_alloc(rc,r,orientation,actors),actors,state)
    rc.observed_chain=chain.duplicate()
    var target: Vector2=P.formation(r,orientation,chain)[actor]
    var role := _slot_role(chain.find(actor),r)
    if role in [2,6]:
        var release := minf(float(receipt.at)+WAIT_AFTER_OBSERVED,tower_time-3.0)
        return anchors[actor] if now<release else target
    return _lane_goal(actor,here,target,CARRIER_LANE if role==0 else SYNC_LANE,rc)
