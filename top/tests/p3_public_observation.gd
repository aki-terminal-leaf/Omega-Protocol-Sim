# SPDX-License-Identifier: MIT
extends SceneTree
const F=preload("res://tests/p3_transition_fidelity.gd")
const C=preload("res://scripts/p3_transition_courses.gd")
const P=preload("res://scripts/p3_transition_patterns.gd")
const R=preload("res://scripts/rules.gd")
const I=preload("res://scripts/interactions.gd")
const S=preload("res://scripts/statuses.gd")
const O=preload("res://scripts/p3_transition_observation.gd")
var checks:=0
var failures:=0
var courses:=0
var max_arrival_error:=0.0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<25:print("P3 PUBLIC FAIL ",label)
func actors_at(points:Array)->Array:return points.map(func(p):return {"pos":R.v(p)})
func receipts(b:Dictionary)->Array:
 var result:Array=[]
 for entity in b.get("stage_entities",[]):
  if str(entity.get("form","")) in ["arm_left","arm_right"]:result.append({"id":str(entity.id),"pos":entity.pos.duplicate()})
 return result
func simulate(id:String,arm:int,sample:int,purple:Array,white:Array,frame:=0.05,restore:=false)->Dictionary:
 var ctx=F.Context.new(id);C.append_family(ctx,arm,sample,purple,white)
 var state:Dictionary={"sim_time":0.0};var actors:Array=actors_at(ctx.beats[0].spawn)
 for bi in ctx.beats.size():
  var b:Dictionary=ctx.beats[bi];I.begin(b,actors,state)
  var elapsed:=0.0
  while elapsed<float(b.duration)-0.000001:
   var budget:float=minf(frame,float(b.duration)-elapsed)
   while budget>0.000001:
    var dt:float=minf(0.05,budget);var previous:Array=actors.duplicate(true)
    for a in 8:actors[a].pos=R.v(actors[a].pos).move_toward(I.bot_goal(a,b,actors,state),6.0*dt)
    I.tick(b,actors,previous,state,dt);elapsed+=dt;budget-=dt
   # Explicit simulated receipt fixture, NOT actual scene/GPU presentation.
   O.publish(b,state,receipts(b))
   if restore:state=JSON.parse_string(JSON.stringify(state))
  if bi==0:
   var error:=0.0
   for a in 8:error=maxf(error,R.v(actors[a].pos).distance_to(I.bot_goal(a,b,actors,state)))
   max_arrival_error=maxf(max_arrival_error,error)
   check(error<0.001,"asserted outside arrival "+id)
 courses+=1
 check(state.runtime_failures.is_empty(),"physical %s arm%d sample%d frame%.3f %s"%[id,arm,sample,frame,str(state.runtime_failures)])
 check(state.p3_transition.history.filter(func(e):return e.kind=="ring").size()==8 and state.p3_transition.history.filter(func(e):return e.kind=="arm_hit").size()==6,"all ring/arm events")
 check(state.p3_transition.packets.size()==6 and state.p3_transition.packets.all(func(p):return p.hits.size()==(2 if p.ability_id==31572 else 1)),"all sniper packet sizes")
 check(state.p3_transition.pending.is_empty() and state.p3_transition_observation.first!=null,"drained and actually fixture-observed orientation")
 return state
func contract()->void:
 var ctx=F.Context.new("elemental");C.append_family(ctx,0)
 var b:Dictionary=ctx.beats[0];var actors:Array=actors_at(b.spawn);var state:Dictionary={"sim_time":0.0};I.begin(b,actors,state)
 for a in 8:check(I.bot_goal(a,b,actors,state)==R.v(actors[a].pos),"pre-mark holds actual pose")
 var previous:Array=actors.duplicate(true);I.tick(b,actors,previous,state,.05);O.publish(b,state,[])
 var neutral:Array=[]
 for a in 8:neutral.append(I.bot_goal(a,b,actors,state))
 var hidden:Dictionary=b.duplicate(true);hidden.positions=hidden.positions.map(func(_p):return Vector2(999,999));hidden.p3_transition_family.arm_first=1
 for e in state.p3_transition.pending:
  if e.kind=="arm_cue":e.entity.pos=[999,999]
 for a in 8:check(I.bot_goal(a,hidden,actors,state)==neutral[a],"hidden goal/family/pending noninterference")
 var triple:Array=[{"id":"opaque_z","pos":[0.0,-14.0]},{"id":"opaque_a","pos":[-12.12,7.0]},{"id":"opaque_m","pos":[12.12,7.0]}]
 O.publish(b,state,[triple[0]]);check(state.p3_transition_observation.first==null,"partial first source no guess")
 O.publish(b,state,[triple[1]]);O.publish(b,state,[]);check(state.p3_transition_observation.first==null,"missing frame keeps incomplete sources")
 O.publish(b,state,[triple[2]]);check(int(state.p3_transition_observation.first)==0,"union of three opaque IDs observes orientation")
 var after:Array=[]
 for a in 8:after.append(I.bot_goal(a,b,actors,state))
 check(after!=neutral,"test discriminates post-cue route from pre-cue route")
 state=JSON.parse_string(JSON.stringify(state))
 for a in 8:check(I.bot_goal(a,b,actors,state).distance_to(after[a])<.00001,"JSON preserves observation decision")
 for a in 8:state.statuses[a]={}
 for a in 8:check(I.bot_goal(a,b,actors,state).distance_to(after[a])<.00001,"marks retained after sniper erasure")
 O.publish(b,state,[{"id":"late_other","pos":[0.0,14.0]}]);check(int(state.p3_transition_observation.first)==0,"second wave cannot overwrite first")
 var fresh:Dictionary={"sim_time":0.0};I.begin(b,actors,fresh);check(fresh.p3_transition_observation.first==null,"same-origin restart clears memory")
 previous=actors.duplicate(true);I.tick(b,actors,previous,fresh,.05);O.publish(b,fresh,[])
 O.publish(b,fresh,[triple[0],{"id":"other","pos":[0.0,14.0]}]);check(fresh.p3_transition_observation.blocked,"mixed initially observed waves fail closed")
 for bad in [[{"id":"boss","pos":[0.0,0.0]}],[triple[0],triple[0]],[{"id":"x","pos":[INF,0]}],[{"id":"x","pos":[0]}]]:
  fresh={"sim_time":0.0};I.begin(b,actors,fresh);O.publish(b,fresh,bad);check(fresh.p3_transition_observation.blocked,"malformed receipt fails closed")
 var missing:Dictionary=b.duplicate(true);missing.p3_transition_public.erase("phase")
 for a in 8:check(I.bot_goal(a,missing,actors,state)==R.v(actors[a].pos),"missing phase no oracle fallback")
func twins()->void:
 var contexts:Array=[];var states:Array=[];var actors:Array=[]
 for arm in 2:
  var ctx=F.Context.new("elemental");C.append_family(ctx,arm,2,[7,2,5,0],[6,3]);contexts.append(ctx)
  actors.append(actors_at(ctx.beats[0].spawn));states.append({"sim_time":0.0});I.begin(ctx.beats[0],actors[arm],states[arm])
 for tick in 82:
  for arm in 2:
   var b:Dictionary=contexts[arm].beats[0];var previous:Array=actors[arm].duplicate(true)
   for a in 8:actors[arm][a].pos=R.v(actors[arm][a].pos).move_toward(I.bot_goal(a,b,actors[arm],states[arm]),.3)
   I.tick(b,actors[arm],previous,states[arm],.05)
   O.publish(b,states[arm],[]) # raw published arms are deliberately NOT presented yet
  check(range(8).all(func(a):return R.v(actors[0][a].pos).distance_to(R.v(actors[1][a].pos))<.00001),"real branch-input twin trajectories, including unpublished arm events")
 for arm in 2:O.publish(contexts[arm].beats[0],states[arm],receipts(contexts[arm].beats[0]))
 check(range(8).any(func(a):return I.bot_goal(a,contexts[0].beats[0],actors[0],states[0]).distance_to(I.bot_goal(a,contexts[1].beats[0],actors[1],states[1]))>.1),"post-publication twins choose different legal pockets")
func _initialize()->void:call_deferred("run")
func run()->void:
 var started:=Time.get_ticks_msec();contract();twins()
 for id in P.data().routes:
  for arm in 2:
   for sample in 4:simulate(id,arm,sample,[7,2,5,0],[6,3])
 for frame in [.1,.3,.5]:
  for id in P.data().routes:
   for arm in 2:simulate(id,arm,2,[7,2,5,0],[6,3],frame)
 simulate("elemental",0,2,[7,2,5,0],[6,3],.05,true)
 if "--partitions" in OS.get_cmdline_user_args():
  for mask in 256:
   var purple:Array=[];var rest:Array=[]
   for a in 8:
    if mask&(1<<a):purple.append(a)
    else:rest.append(a)
   if purple.size()!=4:continue
   for i in 4:
    for j in range(i+1,4):
     for id in P.data().routes:
      for arm in 2:simulate(id,arm,2,purple,[rest[i],rest[j]],.1)
 print("P3_PUBLIC_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":courses,"max_outside_arrival_error":max_arrival_error,"elapsed_ms":Time.get_ticks_msec()-started,"scope":"actual Interactions/Statuses walking and runtime judgments with explicit simulated presentation fixtures; not actual scene/pixels/native or fullguide"}))
 quit(1 if failures else 0)
