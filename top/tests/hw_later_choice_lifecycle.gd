# SPDX-License-Identifier: MIT
extends SceneTree
const C=preload("res://scripts/hw_cooperation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("LATER CHOICE FAIL ",label)
func fixture(round_index:int,human:int)->Dictionary:
 var actors:Array=[];var buffs:Array=[]
 for i in 8:actors.append({"pos":Vector2(0,-18)});buffs.append({})
 actors[6].pos=Vector2(-10,-10);actors[7].pos=Vector2(10,-10)
 buffs[6]={"red":{"expires":99},"overflow":{"expires":99}};buffs[7]=buffs[6].duplicate(true)
 var at:=24.0+21.0*round_index
 var c:Dictionary={"round":round_index,"actors":[6,7],"goals":[Vector2(-10,-10),Vector2(10,-10)],"reveal_window":10.0}
 return {"actors":actors,"beat":{"hw_tower_cooperations":[c],"hw_tower_cooperation":c},"state":{"human_actor":human,"sim_time":at-9,"statuses":buffs,"hw":{"start":0.0,"pending":[{"kind":"towers","round":round_index,"at":at}]}}}
func rep(f:Dictionary,actor:int):return C.replacement_actor(actor,f.beat,f.actors,f.state)
func _initialize():
 for round_index in [1,2,3]:
  for human in [6,7]:
   var peer:int=13-int(human);var hi:int=0 if human==6 else 1;var ni:int=1-hi
   var f:Dictionary=fixture(round_index,human);var key:="hw_tower_choice_%d_6"%round_index
   var own:Vector2=f.beat.hw_tower_cooperation.goals[hi];var other:Vector2=f.beat.hw_tower_cooperation.goals[ni]
   check(rep(f,peer)==null and not f.state.hw.has(key),"ordinary default has no synthetic choice")
   f.actors[human].pos=other
   check(rep(f,peer)==human and int(f.state.hw[key])==ni,"exclusive alternate creates real swap")
   f.actors[human].pos=Vector2(0,-10)
   check(rep(f,peer)==human,"outside both exclusive margins retains last legal choice")
   f.actors[human].pos=own
   check(rep(f,peer)==peer and int(f.state.hw[key])==hi,"return to own restores default before judgment")
   f.actors[human].pos=other
   check(rep(f,peer)==human,"second side change stays reversible")
   check(rep(f,human)==null,"human is never a recipient of NPC steering")
   check(rep(f,0)==null,"non-pair NPC never redirected")
   f.state.hw.pending=[];f.actors[human].pos=own
   check(rep(f,peer)==human,"actual completed tower freezes chosen swap through handoff")
   var g:Dictionary=fixture(round_index,human);g.actors[human].pos=other;g.state.sim_time-=2.0
   check(rep(g,peer)==null and not g.state.hw.has(key),"no alternate capture before existing public reveal window")
   g=fixture(round_index,human);g.actors[human].pos=other;g.state.statuses[peer].erase("overflow")
   check(rep(g,peer)==null and not g.state.hw.has(key),"missing genuine peer bug cannot authorize swap")
   g=fixture(round_index,human);g.actors[human].pos=other;g.state.statuses[peer].erase("red");g.state.statuses[peer].blue={}
   check(rep(g,peer)==null,"opposite rot cannot authorize swap")
   g=fixture(round_index,human);g.actors[human].pos=other;g.state.human_actor=-1
   check(rep(g,peer)==null,"allNPC configuration unchanged")
   g=fixture(round_index,human);g.actors[human].pos=other;g.state.hw.cooperation_round=round_index-1;g.state.hw['hw_tower_choice_%d_6'%(round_index-1)]=1
   check(rep(g,peer)==human and not g.state.hw.has('hw_tower_choice_%d_6'%(round_index-1)),"new round retires prior choice")
   g=fixture(round_index,human);g.actors[human].pos=other;rep(g,peer);g.state.sim_time=g.state.hw.pending[0].at;g.actors[human].pos=own
   check(rep(g,peer)==human,"exact pending.at==now boundary freezes selected swap before event removal")
   g=fixture(round_index,human);g.actors[human].pos=other;rep(g,peer);g.actors[human].pos=own;rep(g,peer);g.state.hw.pending=[];g.actors[human].pos=other
   check(rep(g,peer)==peer,"post-judgment tracked default is frozen as well")
   # Side epoch resets only on responsibility change, never on every evolving path waypoint.
   f=fixture(round_index,human);f.actors[human].pos=other;rep(f,peer);f.actors[peer].pos=Vector2(0,-18)
   var lane:="hw_cooperation_lane_%d_%d"%[round_index,peer]
   C.walking_goal(peer,Vector2(-10,-10),f.beat,f.actors,f.state)
   f.state.hw[lane]="in"
   check(C.walking_goal(peer,Vector2(-10.2,-10.2),f.beat,f.actors,f.state)==Vector2(-10.2,-10.2) and f.state.hw[lane]=="in","same-side changing waypoint does not reset an existing lane")
   f.actors[human].pos=own;rep(f,peer);f.actors[peer].pos=Vector2(-10,-10)
   var goal:Vector2=C.walking_goal(peer,Vector2(10,-10),f.beat,f.actors,f.state)
   check(f.state.hw[lane]=="out" and absf(goal.length()-18.0)<.001,"side reversal retires stale in phase and first takes outside lane")
   f.state.hw.pending=[]
   check(C.walking_goal(peer,Vector2(10,-10),f.beat,f.actors,f.state)==Vector2(10,-10),"post-tower handoff uses existing route target without lane detention")
 print("HW_LATER_CHOICE_LIFECYCLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rounds":[1,2,3],"human_pair_orders":[6,7],"scope":"focused helper lifecycle, not Main/physics/publicreceipt/fullguide"}))
 quit(1 if failures else 0)
