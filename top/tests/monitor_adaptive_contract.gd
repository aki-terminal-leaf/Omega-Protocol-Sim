# SPDX-License-Identifier: MIT
extends SceneTree
const E=preload("res://scripts/encounters.gd")
const I=preload("res://scripts/interactions.gd")
const M=preload("res://scripts/monitor_preparation.gd")
const R=preload("res://scripts/rules.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);print("ADAPTIVE_CONTRACT_FAIL ",label)
func fixture()->Dictionary:
 var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
 var p:Dictionary=profiles[0].duplicate(true);p.monitor_layout="astoh"
 var b:Dictionary=E.new().build("p3_monitors",1,p,0,-1).beats[0]
 var actors:Array=[]
 for j in 8:actors.append({"pos":R.v(b.positions[j]),"face":float(b.facing.get(j,0.0)),"role":E.ROLES[j]})
 var h:int=int(b.monitor_preparation.order[1]);actors[h].face+=11.0
 var state:Dictionary={"human_actor":h,"sim_time":20.0}
 I.begin(b,actors,state);state.sim_time=24.0
 return {"beat":b,"actors":actors,"state":state,"human":h,"n3":int(b.monitor_preparation.order[5])}
func compute(f:Dictionary)->Vector2:
 M.goal(f.n3,f.beat,f.state,f.actors);f.state.sim_time+=.4
 return M.goal(f.n3,f.beat,f.state,f.actors)
func _initialize()->void:
 var f:Dictionary=fixture();var canon:Vector2=R.v(f.beat.positions[f.n3]);var before_actors:String=JSON.stringify(f.actors);var before_beat:String=JSON.stringify(f.beat)
 var got:Vector2=compute(f)
 check(got.distance_to(canon)>.1,"actual geometry drives noncanonical goal at nonzero beat_started")
 check(JSON.stringify(f.actors)==before_actors and JSON.stringify(f.beat)==before_beat,"planner mutates neither actors nor beat")
 check(float(f.state.monitor_adaptive.plan.elapsed)<8.85,"beat-local rather than absolute sim time")
 var ordinary:Dictionary=fixture();ordinary.actors[ordinary.human].face-=11.0
 check(compute(ordinary).is_equal_approx(canon),"canonical geometry preserves goal")
 var future:Dictionary=fixture();future.beat.facing[future.human]=12345.0
 check(compute(future).is_equal_approx(got),"future authored human facing cannot alter current-input plan")
 for h in range(-1,8):
  var other:Dictionary=fixture();other.state.human_actor=h
  if h==other.human:continue
  check(compute(other).is_equal_approx(canon) and not other.state.has("monitor_adaptive"),"excluded human role/demo %d exactly original/no private state"%h)
 for lay in ["aether","lpdu","cn_fixed","cn_mirror","kr_astoh"]:
  var other:Dictionary=fixture();other.beat.monitor_preparation.layout=lay
  check(compute(other).is_equal_approx(canon) and not other.state.has("monitor_adaptive"),"excluded layout "+lay)
 for j in 8:
  if j==f.n3:continue
  var other:Dictionary=fixture();other.state.sim_time+=.5
  check(M.goal(j,other.beat,other.state,other.actors).is_equal_approx(R.v(other.beat.positions[j])) and not other.state.has("monitor_adaptive"),"only N3 steered actor%d"%j)
 var missing:Dictionary=fixture();missing.beat.party_statuses=[]
 check(compute(missing).is_equal_approx(canon),"missing published side fails closed")
 var live_missing:Dictionary=fixture();live_missing.state.statuses[live_missing.human].erase("monitor_left");live_missing.state.statuses[live_missing.human].erase("monitor_right")
 check(compute(live_missing).is_equal_approx(got),"no runtime row still projects actual authored public cue")
 var expired:Dictionary=fixture()
 for cue in expired.beat.party_statuses:
  if int(cue.actor)==int(expired.human):expired.state.statuses[expired.human][str(cue.key)]={"expires":23.0}
 var projected:Array=preload("res://scripts/party_statuses.gd").rows(expired.actors,expired.state,expired.beat)[expired.human].effects
 check(not projected.any(func(e):return e.key in ["monitor_left","monitor_right"]),"expiry fixture actually hides HUD cue")
 check(compute(expired).is_equal_approx(canon),"expired current live monitor status fails closed")
 var hidden:Dictionary=fixture()
 for cue in hidden.beat.party_statuses:cue.visible_until=1.0
 check(compute(hidden).is_equal_approx(canon),"hidden current public monitor cue fails closed")
 var consumed:Dictionary=fixture();consumed.state.consumed_party_signals={str(consumed.human):["monitor_left","monitor_right"]}
 check(compute(consumed).is_equal_approx(canon),"consumed current public monitor cue fails closed")
 var cached:Dictionary=fixture();check(compute(cached).distance_to(canon)>.1,"cached adaptive goal established")
 cached.beat.party_statuses=[];cached.actors[cached.human].face+=1.0;cached.state.sim_time+=.4;M.goal(cached.n3,cached.beat,cached.state,cached.actors);cached.state.sim_time+=.4
 check(M.goal(cached.n3,cached.beat,cached.state,cached.actors).is_equal_approx(canon),"malformed source invalidates old plan first tick")
 cached.state.sim_time+=.1
 check(M.goal(cached.n3,cached.beat,cached.state,cached.actors).is_equal_approx(canon),"malformed source cannot revive cached plan next tick")
 var changing:Dictionary=fixture();compute(changing)
 changing.state.consumed_party_signals={str(changing.human):["monitor_left","monitor_right"]};changing.state.sim_time+=.1
 check(M.goal(changing.n3,changing.beat,changing.state,changing.actors).is_equal_approx(canon),"same human pose cannot hide disappeared live cue")
 var malformed:Dictionary=fixture();malformed.actors[malformed.human].face=NAN
 check(compute(malformed).is_equal_approx(canon),"nonfinite public face fails closed")
 var unstable:Dictionary=fixture();M.goal(unstable.n3,unstable.beat,unstable.state,unstable.actors);unstable.state.sim_time+=.1
 check(M.goal(unstable.n3,unstable.beat,unstable.state,unstable.actors).is_equal_approx(canon) and int(unstable.state.monitor_adaptive.searches)==0,"stable .3s window required")
 f.state.sim_time=29.0;M.goal(f.n3,f.beat,f.state,f.actors);var plan_json:String=JSON.stringify(f.state.monitor_adaptive.plan);f.actors[f.human].face+=120.0;f.state.sim_time=29.4
 check(M.goal(f.n3,f.beat,f.state,f.actors).is_equal_approx(got) and JSON.stringify(f.state.monitor_adaptive.plan)==plan_json,"frozen goal ignores late changed public input")
 I.begin(f.beat,f.actors,f.state);check(not f.state.has("monitor_adaptive"),"begin resets private cached plan")
 print("MONITOR_ADAPTIVE_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"pure malformed/cue/scope/reset contract; NOT actual gameplay evidence"}))
 quit(0 if failures.is_empty() else 1)
