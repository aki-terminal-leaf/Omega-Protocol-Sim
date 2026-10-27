extends SceneTree
const O=preload("res://scripts/hw_firstwave_observation.gd")
const P=preload("res://scripts/hw_patterns.gd")
const R=preload("res://scripts/rules.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("HW_LATER_UNIT_FAIL ",label)
func shapes(orientation:int)->Array:
 var out:Array=[]
 for t in P.towers(orientation,"red"):out.append({"kind":"tower","hw_preview":true,"pos":R.v(t.pos),"radius":t.radius,"colour":t.colour})
 return out
func fixture(r:int)->Dictionary:
 var neutral:Array=[];var actors:Array=[]
 for i in 8:
  var pos:=R.direction(float(i)*45.0+22.5)*20.0
  neutral.append(P.xy(pos));actors.append({"pos":pos})
 var state:Dictionary={"sim_time":0.0,"human_actor":-1,"hw_firstwave_presentation_required":true,"hw":{"start":0.0,"pending":[]},"statuses":[],"dead":[]}
 for i in 8:state.statuses.append({})
 for i in [0,1]:state.statuses[i]={"smell_overflow":{"expires":3.0},"smell_red":{"expires":3.0}}
 for i in [4,5]:state.statuses[i]={"smell_sync":{"expires":3.0},"smell_blue":{"expires":3.0}}
 var first:Dictionary={"hello_world":true,"hw_events":[],"hw_public_firstwave":{"neutral":neutral,"order":range(8)},"hw_tower_cooperation":{"round":0}}
 O.begin(first,actors,state);state.hw.first_public.mapping=range(8)
 # Synthetic current public states derived from the real 34.9/55.9/76.9 samples.
 state.statuses=[]
 var tower:=24.0+21.0*float(r)
 for i in 8:
  var role:=posmod(i+2*r,8);role-=role%2
  var buffs:Dictionary={}
  if role==0:buffs={"overflow":{"expires":tower},"red":{"expires":tower+8.2}}
  elif role==4:buffs={"sync":{"expires":tower},"blue":{"expires":tower+8.725}}
  else:buffs["remote_code_smell" if role==2 else "local_code_smell"]={"expires":tower-1.0}
  state.statuses.append(buffs)
 state.sim_time=tower-10.5
 # Later rounds need the previously observed public chain, not an authored order.
 if r>1:state.hw.later_public={"origin":0.0,"rounds":{str(r-1):{"final_chain":range(8)}}}
 var beat:Dictionary={"hello_world":true,"hw_route":P.route("elemental"),"hw_tower_cooperation":{"round":r,"actors":[7,0],"goals":[[99,99],[98,98]]},"positions":neutral,"hw_path":[],"hw_pattern":{"orientations":[7,7,7,7]}}
 return {"state":state,"actors":actors,"beat":beat}
func prepare(f:Dictionary,r:int):
 for i in 8:O.goal(i,f.beat,f.actors,f.state)
 return f.state.hw.later_public.rounds[str(r)]
func _init():
 for r in [1,2,3]:
  var f:=fixture(r);var rc=prepare(f,r)
  check(rc.valid,"current public role snapshot valid r%d"%r)
  var before:Array=[]
  for i in 8:before.append(O.goal(i,f.beat,f.actors,f.state))
  f.beat.positions=[];f.beat.hw_path=[{"at":999,"positions":[]}];f.beat.hw_pattern.orientations=[0,1,2,3];f.state.hw.pending=[{"kind":"towers","round":r,"at":24+21*r,"towers":shapes(4)}]
  var after:Array=[]
  for i in 8:after.append(O.goal(i,f.beat,f.actors,f.state))
  check(before==after,"hidden authored/pending changes cannot alter pre-reveal goals r%d"%r)
  O.publish(f.beat,f.state,shapes(2));check(rc.receipt is Dictionary,"four actual presented towers accepted r%d"%r)
  var saved=rc.receipt.duplicate(true);O.publish(f.beat,f.state,shapes(6));check(rc.receipt==saved,"receipt immutable r%d"%r)
  var clone:Dictionary=JSON.parse_string(JSON.stringify(f.state));var g=O.goal(0,f.beat,f.actors,f.state);check(g==O.goal(0,f.beat,f.actors,clone),"JSON restores actual goal r%d"%r)
  rc.receipt.at=999.0;check(O.goal(0,f.beat,f.actors,f.state)==R.v(rc.anchors[0]),"future receipt fails closed r%d"%r)
  rc.receipt=saved.duplicate(true);rc.receipt.round=r-1;check(O.goal(0,f.beat,f.actors,f.state)==R.v(rc.anchors[0]),"wrong-round receipt fails closed r%d"%r)
  rc.receipt=saved.duplicate(true);rc.receipt.towers[0].radius=5.0;check(O.goal(0,f.beat,f.actors,f.state)==R.v(rc.anchors[0]),"corrupt snapshot fails closed r%d"%r)
  f=fixture(r);f.state.dead=[0];rc=prepare(f,r);check(not rc.valid,"actual dead array rejected r%d"%r)
  f=fixture(r);var remote:=posmod(2-2*r,8);f.state.statuses[remote].remote_code_smell.expires+=21.0;rc=prepare(f,r);check(not rc.valid,"future code-smell expiry cannot stand in for current r%d"%r)
 # Valid non-center actual tower choice, outside formation-point tolerance.
 var f:=fixture(1);var human:=6;var partner:=7;f.state.human_actor=human
 var rc=prepare(f,1);O.publish(f.beat,f.state,shapes(0));O.goal(partner,f.beat,f.actors,f.state)
 var alloc:Array=rc.alloc;var targets:Array=P.formation(1,0,alloc)
 var red:Array=rc.receipt.towers.filter(func(t):return t.colour=="red")
 var t:Dictionary=red[0] if R.v(red[0].pos).distance_to(targets[partner])<R.v(red[1].pos).distance_to(targets[partner]) else red[1]
 var center:=R.v(t.pos);var hp:Vector2=center+(center-targets[partner]).normalized()*5.8
 check(hp.distance_to(center)<6.0 and hp.distance_to(targets[partner])>6.0,"fixture is legal actual footprint but outside formation target radius")
 f.actors[human].pos=hp;var unchanged:=hp
 O.goal(partner,f.beat,f.actors,f.state);f.state.sim_time+=0.2;O.goal(partner,f.beat,f.actors,f.state)
 check(rc.swaps.values().has(true),"legal non-center occupancy establishes alternate")
 check(O.goal(human,f.beat,f.actors,f.state)==unchanged and f.actors[human].pos==unchanged,"human not steered or mutated")
 f.actors[human].pos=targets[human];f.state.sim_time+=0.1;O.goal(partner,f.beat,f.actors,f.state)
 check(not rc.swaps.values().has(true),"return to own actual tower reverses choice")
 boundary_checks()
 print("HW_LATER_UNIT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"synthetic source/schema/public-state isolation and footprint controls, not physics/full guide proof"}))
 quit(1 if failures else 0)

func boundary_checks():
 var f:=fixture(1)
 for invalid in [1.5,4,-1,"1",null]:
  f.beat.hw_tower_cooperation.round=invalid
  check(O.goal(0,f.beat,f.actors,f.state)==f.actors[0].pos,"malformed round strict-holds actual pose: "+str(invalid))
 # Non-identity slot->actor mapping composed with a real firstwave choice.
 f=fixture(1)
 var order:Array=[3,5,1,7,4,2,6,0]
 f.state.hw.first_public.order=order.duplicate();f.state.hw.first_public.mapping=range(8)
 f.state.hw.first_public.mapping[3]=5;f.state.hw.first_public.mapping[5]=3
 var expected:Array=order.duplicate();expected[0]=5;expected[1]=3
 check(O._chain_base(f.state,f.state.hw.first_public,1)==expected,"non-identity actor mapping composes slot ownership correctly")
 f.state.human_actor=3;f.state.hw.hw_tower_choice_0_3=1
 check(O._chain_base(f.state,f.state.hw.first_public,1)==order,"observed human double-swap restores original non-identity chain")
 # Pre-tower observed chain remains available before a post-tower goal call.
 f=fixture(1);f.state.human_actor=6
 var rc=prepare(f,1);O.publish(f.beat,f.state,shapes(0));O.goal(7,f.beat,f.actors,f.state)
 var alloc:Array=rc.alloc;var goals:Array=P.formation(1,0,alloc)
 f.actors[6].pos=goals[7];f.actors[7].pos=goals[7]
 rc.lanes["7"]="in";rc.lane_targets["7"]=P.xy(goals[7])
 O.goal(7,f.beat,f.actors,f.state);f.state.sim_time+=0.2
 var changed=O.goal(7,f.beat,f.actors,f.state)
 check(changed is Vector2 and absf(changed.length()-18.0)<0.001,"changed carrier responsibility resets out-lane instead of direct chord")
 check(rc.observed_chain!=alloc and rc.final_chain==null,"human choice saved as observed, not falsely final before judgment")
 check(O._chain_base(f.state,f.state.hw.first_public,2)==rc.observed_chain,"next public chain preserves observed swap when final was not materialized")
 # Final Critical Error beat must not read a deliberately contradictory authored endpoint.
 f=fixture(3);rc=prepare(f,3);O.publish(f.beat,f.state,shapes(0));O.goal(0,f.beat,f.actors,f.state)
 f.state.sim_time=87.1;O.goal(0,f.beat,f.actors,f.state)
 f.state.sim_time=100.0
 var terminal:Dictionary={"hello_world":true,"hw_route":P.route("elemental"),"positions":[[99,99],[99,99],[99,99],[99,99],[99,99],[99,99],[99,99],[99,99]]}
 var goal=O.goal(0,terminal,f.actors,f.state)
 check(goal is Vector2 and goal!=Vector2(99,99),"terminal beat retains observed fourth-wave route, no authored fallback")
 var frozen=goal;terminal.positions=[];check(O.goal(0,terminal,f.actors,f.state)==frozen,"terminal authored endpoint mutations cannot change observed goal")
