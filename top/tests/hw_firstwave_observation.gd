extends SceneTree
## Pure unit checks for hw_firstwave_observation. All fixtures below are
## SYNTHETIC public-state fixtures (labelled source_kind), not capture data.
const O = preload("res://scripts/hw_firstwave_observation.gd")
const P = preload("res://scripts/hw_patterns.gd")
const R = preload("res://scripts/rules.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
    assertions+=1
    if not ok: failures+=1; print("HW FIRSTWAVE FAIL: ",message)

func neutral() -> Array:
    var result: Array=[]
    for i in 8: result.append(P.xy(R.direction(i*45.0+22.5)*20.0))
    return result

func fixture_beat() -> Dictionary:
    return {"hello_world":true,"hw_events":[],"shapes":[],"positions":neutral(),"hw_public_firstwave":{"neutral":neutral(),"order":[0,1,2,3,4,5,6,7],"source":"synthetic_public_fixture"},
        "hw_tower_cooperation":{"round":0,"actors":[0,1],"goals":[[99,99],[98,98]],"reveal_window":10.0}}

func fixture_state(required := true) -> Dictionary:
    var state := {"sim_time":10.0,"human_actor":-1,"hw_firstwave_presentation_required":required,"hw":{"start":10.0,"pending":[]},"statuses":[]}
    for i in 8: state.statuses.append({})
    for a in [0,1]: state.statuses[a]["smell_overflow"]={"expires":13.0}; state.statuses[a]["smell_red"]={"expires":13.0}
    for a in [4,5]: state.statuses[a]["smell_sync"]={"expires":13.0}; state.statuses[a]["smell_blue"]={"expires":13.0}
    return state

func actors_at(points: Array) -> Array:
    var result: Array=[]
    for p in points: result.append({"pos":R.v(p)})
    return result

func towers(orientation: int) -> Array:
    var result: Array=[]
    for t in P.towers(orientation,"red"): result.append({"kind":"tower","pos":R.v(t.pos),"radius":t.radius,"colour":t.colour,"hw_preview":true})
    return result

func _init() -> void:
    var nb := neutral()
    # Missing / invalid configuration never unlocks.
    var beat := fixture_beat(); beat.erase("hw_public_firstwave")
    var state := fixture_state(); var actors := actors_at(nb)
    O.begin(beat,actors,state)
    check(O.goal(2,beat,actors,state)==actors[2].pos,"missing config holds actual pose, never solved legacy route")
    beat=fixture_beat(); beat.hw_public_firstwave.order=[0,1,2,3,4,5,6,6]
    state=fixture_state(); O.begin(beat,actors,state)
    check(O.goal(2,beat,actors,state)==actors[2].pos,"duplicate order fails closed")
    beat=fixture_beat(); state=fixture_state(); state.statuses[1].erase("smell_red")
    O.begin(beat,actors,state)
    check(O.goal(2,beat,actors,state)==actors[2].pos,"overflow pair colour mismatch fails closed")
    # Both cardinal and intercardinal squares are actual legal displayed families.
    for orientation in 8:
        var pb=fixture_beat();var ps=fixture_state();O.begin(pb,actors,ps);ps.sim_time=25.0
        O.publish(pb,ps,towers(orientation))
        check(ps.hw.first_public.receipt is Dictionary and int(ps.hw.first_public.receipt.orientation)==orientation,"all eight actual source orientations %d"%orientation)
    # Valid begin; before receipt everybody holds neutral regardless of hidden orientation.
    for hidden in [0,3]:
        beat=fixture_beat(); beat.hw_events=P.events(range(8),[hidden,1,2,3],"red")
        state=fixture_state(); state.hw.pending=beat.hw_events.duplicate(true)
        O.begin(beat,actors,state)
        state.sim_time=25.0
        check(R.v(O.goal(0,beat,actors,state)).is_equal_approx(R.v(nb[0])),"neutral before reveal (hidden %d)" % hidden)
    # Partial / malformed receipts are not enough.
    var partial := towers(2); partial.pop_back()
    O.publish(beat,state,partial)
    check(state.hw.first_public.receipt==null,"partial receipt rejected")
    var bad := towers(2); bad[0].radius=5.0
    O.publish(beat,state,bad)
    check(state.hw.first_public.receipt==null,"wrong radius rejected")
    var colours := towers(2); colours[0].colour="red"; colours[1].colour="red"; colours[2].colour="red"
    O.publish(beat,state,colours)
    check(state.hw.first_public.receipt==null,"colour split rejected")
    var nan := towers(2); nan[0].pos=Vector2(NAN,0)
    O.publish(beat,state,nan)
    check(state.hw.first_public.receipt==null,"non-finite rejected")
    check(not state.has("hw_firstwave_assisted"),"ordinary path never synthesises")
    # Valid presented receipt determines axis from public colours only.
    var beat_before := beat.duplicate(true)
    O.publish(beat,state,towers(2))
    var receipt=state.hw.first_public.receipt
    check(receipt is Dictionary and int(receipt.orientation)==2 and receipt.source_kind=="arena_presented","presented receipt orientation 2")
    check(receipt.source_onset=="source_unknown","source onset stays unknown")
    O.publish(beat,state,towers(5))
    check(int(state.hw.first_public.receipt.orientation)==2,"snapshot retained, not mutated")
    var targets: Array=P.formation(0,2,range(8))
    # Waiting tether slots hold neutral until observed_at+6.
    check(R.v(O.goal(2,beat,actors,state)).is_equal_approx(R.v(nb[2])),"tether waits")
    state.sim_time=31.5
    check(R.v(O.goal(2,beat,actors,state)).is_equal_approx(targets[2]),"tether moves after 6s")
    # Carrier lanes: radial then bounded angular steps.
    var g=O.goal(0,beat,actors,state)
    check(g is Vector2 and absf(g.length()-18.0)<0.01,"carrier goes to outer 18 lane")
    var g4=O.goal(4,beat,actors,state)
    check(g4 is Vector2 and absf(g4.length()-12.5)<0.01,"sync goes to 12.5 lane")
    actors[0].pos=R.v(nb[0]).normalized()*18.0
    g=O.goal(0,beat,actors,state)
    var t0: Vector2=targets[int(state.hw.first_public.mapping[0])]
    check(absf(angle_difference(actors[0].pos.angle(),g.angle()))<=0.1001 or g.is_equal_approx(t0),"short angular step")
    var m: Array=state.hw.first_public.mapping
    check(int(m[2])==2 and int(m[6])==6 and (int(m[0]) in [0,1]) and (int(m[4]) in [4,5]),"mapping only within same-colour pairs")
    check(beat.hash()==beat_before.hash(),"source beat unchanged by publish/goal")
    # Human is never steered.
    state.human_actor=1
    actors[1].pos=Vector2(3,4)
    check(O.goal(1,beat,actors,state)==Vector2(3,4),"human returns actual position")
    # Omission: human stays near own course -> no redirect recorded.
    var key := "hw_tower_choice_0_0"
    state.hw.pending=[{"kind":"towers","round":0,"at":34.0}]
    state.statuses[0]["red"]={"expires":99.0}; state.statuses[0]["overflow"]={"expires":99.0}
    state.statuses[1]["red"]={"expires":99.0}; state.statuses[1]["overflow"]={"expires":99.0}
    O.goal(0,beat,actors,state)
    check(not state.hw.has(key),"omission does not redirect")
    # Valid alternative: human stands on the NPC's mapped target.
    var npc_target: Vector2=targets[int(m[0])]
    actors[1].pos=npc_target;state.sim_time+=0.025
    O.goal(0,beat,actors,state)
    check(state.hw.has(key),"valid alternate recorded via hw_cooperation")
    check(beat.hash()==beat_before.hash(),"duplicate beat used for human choice")
    actors[1].pos=targets[int(m[1])];state.sim_time+=0.025
    O.goal(0,beat,actors,state)
    check(not state.hw.has(key),"actual return to own legal tower before resolution releases transient alternate")
    actors[1].pos=npc_target;state.sim_time+=0.025;O.goal(0,beat,actors,state)
    check(state.hw.has(key),"human can make the alternative again from real position")
    state.sim_time=34.1;actors[1].pos=targets[int(m[1])];state.sim_time+=0.025
    O.goal(0,beat,actors,state)
    check(state.hw.has(key),"after actual tower deadline final observed side persists for handoff")
    state.sim_time=31.5
    check(str(state.hw.first_public.lanes.get("0",""))=="out" or str(state.hw.first_public.lanes.get("0",""))=="around","changed human target restarts safe outside lane")
    # JSON roundtrip of cache.
    var restored=JSON.parse_string(JSON.stringify(state))
    var a1=O.goal(2,beat,actors,state); var a2=O.goal(2,beat,actors,restored)
    check(a2 is Vector2 and R.v(a1).is_equal_approx(a2),"JSON roundtrip goal stable")
    # Future timestamp is rejected.
    restored.hw.first_public.receipt.at=999.0
    check(R.v(O.goal(2,beat,actors,restored)).is_equal_approx(R.v(nb[2])),"future receipt rejected")
    # Other rounds untouched.
    var later := fixture_beat(); later.hw_tower_cooperation.round=1
    check(O.goal(2,later,actors,state)==actors[2].pos,"round 1 strict Main cannot fall back to hidden route")
    var legacy:Dictionary=state.duplicate(true);legacy.erase("hw_firstwave_presentation_required")
    check(O.goal(2,later,actors,legacy)==null,"round 1 explicit legacy invalid-window fallback remains separate")
    # Synthetic fixture path is labelled assisted.
    beat=fixture_beat(); beat.shapes=towers(4); state=fixture_state(false); actors=actors_at(nb)
    O.begin(beat,actors,state); state.sim_time=25.0
    O.goal(3,beat,actors,state)
    check(state.get("hw_firstwave_assisted",false)==true and state.hw.first_public.receipt.source_kind=="synthetic_runtime_fixture","synthetic fixture assisted")
    check(not fine_step_choice(true),"fine dt moving away from old alternate never looks stationary")
    check(fine_step_choice(false),"same fine dt legal stationary occupancy still establishes choice")
    print("HW_FIRSTWAVE_UNIT_RESULT ",JSON.stringify({"checks":assertions,"failures":failures,"scope":"synthetic presented-source/schema/isolation/choice fixtures, not physical/native/Web proof"}))
    quit(1 if failures>0 else 0)

func fine_step_choice(moving:bool)->bool:
 var nb:Array=P.formation(0,0,range(8))
 for slot in [2,3,6,7]:nb[slot]=R.v(nb[slot]).normalized()*3.0
 var b:=fixture_beat();b.hw_public_firstwave.neutral=nb
 var st:=fixture_state();var a:=actors_at(nb)
 st.human_actor=1;st.hw.pending=[{"kind":"towers","round":0,"at":34.0}]
 for n in [0,1]:st.statuses[n].red={"expires":99.0};st.statuses[n].overflow={"expires":99.0}
 O.begin(b,a,st);st.sim_time=25.0;O.publish(b,st,towers(2))
 var start:Vector2=R.v(a[1].pos)
 for frame in 100:
  st.sim_time=25.0+float(frame)/480.0
  a[1].pos=start+start.normalized()*(6.0*float(frame)/480.0 if moving else 0.0)
  O.goal(0,b,a,st)
 return st.hw.has("hw_tower_choice_0_0")
