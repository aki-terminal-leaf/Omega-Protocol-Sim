# SPDX-License-Identifier: MIT
extends SceneTree
## Actual unmodified HW judgments, source synthetic public-display fixtures.
const C=preload("res://scripts/hw_courses.gd")
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
var rows:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("HW WALK FAIL ",label)
func run_course(profile:String,colour:String,angles:Array,order:Array):
 var ctx=E.new();ctx.profile={"id":profile};ctx.order=order.duplicate();ctx.positions=[];ctx.labels=[]
 for a in 8:ctx.positions.append(R.direction(a*45.0)*5.0);ctx.labels.append("")
 C.append_family(ctx,angles,colour)
 var actors:Array=[]
 for actor in 8:actors.append({"role":E.ROLES[actor],"pos":ctx.beats[0].spawn[actor],"face":0.0})
 var state:Dictionary={"sim_time":0.0,"human_actor":-1}
 var max_speed:=0.0
 var max_walk_excess:=0.0
 for beat in ctx.beats:
  I.begin(beat,actors,state);var elapsed:=0.0
  while elapsed<float(beat.duration)-.000001:
   var dt:=minf(.1,float(beat.duration)-elapsed);var before:Array=actors.duplicate(true)
   for actor in 8:
    actors[actor].pos=R.v(actors[actor].pos).move_toward(I.bot_goal(actor,beat,actors,state),6.0*dt)
    max_speed=maxf(max_speed,R.v(actors[actor].pos).distance_to(R.v(before[actor].pos))/dt)
    max_walk_excess=maxf(max_walk_excess,R.v(actors[actor].pos).distance_to(R.v(before[actor].pos))-6.0*dt)
   I.tick(beat,actors,before,state,dt);elapsed+=dt
 var history:Array=state.hw.history
 check(state.runtime_failures.is_empty() and state.dead.is_empty(),"full physical %s/%s/%s %s"%[profile,colour,str(angles),str(state.runtime_failures.slice(0,4))])
 check(history.filter(func(e):return e.kind=="hw_tower").size()==16,"all16 tower judgments")
 check(history.filter(func(e):return e.kind=="hw_blast").size()==32,"all32 bug/rot blasts")
 check(history.any(func(e):return e.kind=="hw_critical_error" and e.blocked.size()==8),"all8 actual debugger gate")
 check(max_walk_excess<=0.000004,"actual6dt displacement, Float32worldULP tolerance only")
 check(state.get("hw_firstwave_assisted",false) and state.hw.first_public.receipt.source_kind=="synthetic_runtime_fixture","synthetic receipt explicit, not human/native/Main proof")
 var row:Dictionary={"profile":profile,"colour":colour,"angles":angles,"order":order,"failures":state.runtime_failures,"max_speed":max_speed,"max_walk_excess":max_walk_excess,"scope":"allbot scripted walking, actual contacts/tower/bug/debugger judgments"}
 rows.append(row);print("HW_WALK_COURSE ",JSON.stringify(row))
func _initialize():call_deferred("run")
func run():
 var smoke:bool="--smoke" in OS.get_cmdline_user_args()
 for profile in (["elemental"] if smoke else ["elemental","aether","lpdu","cn_moogle","kr_09stop"]):
  for colour in (["red"] if smoke else ["red","blue"]):
   for angle in ([0,1,2,4] if smoke else range(8)):run_course(profile,colour,[angle,0,0,0],range(8))
  if not smoke:
   for seed_value in [17,35,71,17391]:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var order:Array=range(8)
    for j in range(7,0,-1):var k:=rng.randi_range(0,j);var t=order[j];order[j]=order[k];order[k]=t
    var angles:Array=[]
    for j in 4:angles.append(rng.randi_range(0,7))
    run_course(profile,"red" if seed_value%2==1 else "blue",angles,order)
 print("HW_FIRSTWAVE_WALK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":rows.size(),"scope":"actual HW runtime allbot physical judgments with synthetic current-shape observations, all5profiles first8angles2colours +20 mixed families; not manual/Main/native/Web proof"}))
 quit(1 if failures else 0)
