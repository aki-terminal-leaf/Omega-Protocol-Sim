# SPDX-License-Identifier: MIT
extends SceneTree
## Geometry/lifecycle regression only; not Main, player-win or full-guide proof.
const C=preload("res://scripts/hw_cooperation.gd")
const P=preload("res://scripts/hw_patterns.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("TOWER GEOMETRY FAIL ",label)
func fixture(round_index:int,human:int,orientation:int,bug:String,top_colour:String)->Dictionary:
 var actors:Array=[];var buffs:Array=[]
 for i in 8:actors.append({"pos":Vector2(0,-18)});buffs.append({})
 var formation:Array=P.formation(round_index,orientation,[0,1,2,3,4,5,6,7])
 var slot:int=posmod((0 if bug=="overflow" else 4)-round_index*2,8)
 var goals:Array=[formation[slot],formation[slot+1]]
 var colour:String=top_colour if bug=="overflow" else ("blue" if top_colour=="red" else "red")
 buffs[6]={colour:{"expires":99.0},bug:{"expires":99.0}};buffs[7]=buffs[6].duplicate(true)
 var towers:Array=P.towers(orientation,top_colour)
 var same:Array=towers.filter(func(t):return t.colour==colour)
 # Oracle uses the source-defined side ordering: left/right for overflow,
 # right/left in the generated list for sync. It does not mirror nearest-goal mapping.
 var centres:Array=[R.v(same[0].pos),R.v(same[1].pos)]
 if bug=="sync":centres.reverse()
 var hi:int=0 if human==6 else 1;var ni:int=1-hi
 actors[6].pos=centres[0];actors[7].pos=centres[1]
 var at:=24.0+21.0*round_index
 var c:Dictionary={"round":round_index,"actors":[6,7],"goals":goals,"reveal_window":10.0}
 return {"actors":actors,"beat":{"hw_tower_cooperations":[c],"hw_tower_cooperation":c},"state":{"human_actor":human,"sim_time":at-9.0,"statuses":buffs,"hw":{"start":0.0,"pending":[{"kind":"towers","round":round_index,"at":at,"towers":towers}]}},"human":human,"peer":13-human,"hi":hi,"ni":ni,"centres":centres,"key":"hw_tower_choice_%d_6"%round_index,"at":at}
func rep(f:Dictionary):return C.replacement_actor(int(f.peer),f.beat,f.actors,f.state)
func rim(f:Dictionary,side:int,distance:float)->Vector2:
 var centre:Vector2=f.centres[side];var goal:Vector2=f.beat.hw_tower_cooperation.goals[side]
 return centre+(centre-goal).normalized()*distance
func fresh(f:Dictionary)->Dictionary:return f.duplicate(true)
func _initialize():
 for round_index in [1,2,3]:
  for human in [6,7]:
   for orientation in [0,1,2,3,4,5,6,7]:
    for bug in ["overflow","sync"]:
     for top_colour in ["red","blue"]:
      var base:Dictionary=fixture(round_index,human,orientation,bug,top_colour)
      check(rep(base)==null and not base.state.hw.has(base.key),"default actual tower needs no forced choice")
      for boundary in [[5.85,true],[6.0,true],[6.0005,true],[6.002,false],[7.0,false]]:
       var f:Dictionary=fresh(base);f.actors[human].pos=rim(f,int(f.ni),float(boundary[0]))
       var actual=rep(f)
       check((actual==human if boundary[1] else actual==null),"actual tower radius membership %s %s r%d h%d o%d %s"%[boundary[0],boundary[1],round_index,human,orientation,bug])
       check(f.state.hw.has(f.key)==bool(boundary[1]),"radius result persists only exclusive actual membership")
      var f:Dictionary=fresh(base);f.actors[human].pos=rim(f,int(f.ni),5.85)
      check(rep(f)==human,"noncentre exclusive swap")
      f.actors[human].pos=(f.centres[0]+f.centres[1])*0.5
      check(rep(f)==human,"equidistant outside both retains previous choice")
      f.actors[human].pos=rim(f,int(f.hi),5.85)
      check(rep(f)==f.peer and int(f.state.hw[f.key])==int(f.hi),"noncentre own membership reverses choice")
      f.actors[human].pos=rim(f,int(f.ni),5.85)
      check(rep(f)==human,"noncentre side can be chosen again")
      f.state.sim_time=f.at;f.actors[human].pos=f.centres[f.hi]
      check(rep(f)==human,"exact actual event time freezes chosen side")
      f.state.hw.pending=[]
      check(rep(f)==human,"after removal chosen side stays frozen")
      f=fresh(base);f.state.sim_time=f.at-10.001;f.actors[human].pos=f.centres[f.ni]
      check(rep(f)==null and not f.state.hw.has(f.key),"no capture before public reveal")
      f.state.sim_time=f.at-10.0
      check(rep(f)==human,"exact public reveal window admits capture")
      f=fresh(base);f.state.hw.pending[0].round=round_index+1;f.actors[human].pos=f.centres[f.ni]
      check(rep(f)==null,"different round pending event does not reveal this round")
      for missing in ["peer_bug","peer_colour","human_bug","human_colour"]:
       f=fresh(base);f.actors[human].pos=f.centres[f.ni]
       var who:int=int(f.peer) if missing.begins_with("peer") else human
       var colour:String=top_colour if bug=="overflow" else ("blue" if top_colour=="red" else "red")
       f.state.statuses[who].erase(bug if missing.ends_with("bug") else colour)
       check(rep(f)==null and not f.state.hw.has(f.key),"missing actual state "+missing)
      f=fresh(base);f.actors[human].pos=f.centres[f.ni];f.state.human_actor=-1
      check(rep(f)==null,"allNPC configuration has no human choice")
      f=fresh(base);f.actors[human].pos=f.centres[f.ni]
      check(C.replacement_actor(human,f.beat,f.actors,f.state)==null,"human never receives automatic steering")
      check(C.replacement_actor(0,f.beat,f.actors,f.state)==null,"unrelated NPC never redirected")
      f=fresh(base);f.state.hw.pending[0].towers.reverse();f.actors[human].pos=rim(f,int(f.ni),5.85)
      check(rep(f)==human,"tower payload order does not choose responsibility")
      f=fresh(base)
      for tower in f.state.hw.pending[0].towers:tower.radius=0.25
      f.actors[human].pos=f.beat.hw_tower_cooperation.goals[f.ni]
      check(rep(f)==null and not f.state.hw.has(f.key),"actual payload membership overrides near formation target")
 # Synthetic overlap exercises nonexclusive membership (not a claimed live layout).
 var f:Dictionary=fixture(1,6,0,"overflow","red")
 var same:Array=f.state.hw.pending[0].towers.filter(func(t):return t.colour=="red")
 same[0].pos=[-2.0,-10.0];same[1].pos=[2.0,-10.0]
 f.beat.hw_tower_cooperation.goals=[Vector2(-2,-10),Vector2(2,-10)]
 f.actors[6].pos=Vector2(0,-10)
 check(rep(f)==null and not f.state.hw.has(f.key),"inside both actual towers is not exclusive")
 f.state.hw[f.key]=1
 check(rep(f)==6 and int(f.state.hw[f.key])==1,"nonexclusive overlap retains prior side")
 print("HW_TOWER_GEOMETRY_LIFECYCLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rounds":[1,2,3],"human_pair_orders":[6,7],"rotation_stress_values":8,"bugs":["overflow","sync"],"primary_colours":["red","blue"],"scope":"focused actual-payload geometry/lifecycle, synthetic rotation/overlap stress NOT Main/manual/publicreceipt/fullguide"}))
 quit(1 if failures else 0)
