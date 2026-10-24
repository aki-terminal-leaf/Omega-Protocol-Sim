# SPDX-License-Identifier: MIT
extends SceneTree
## Independent pinned Python oracle vs runtime/public-cue behavior. Synthetic,
## NOT actual Main, movement, Web/native, original coordinate calibration.
const F=preload("res://scripts/monitor_fixed_dps.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const ROLES=["MT","ST","H1","H2","D1","D2","D3","D4"]
const SLOTS=["M1","M2","M3","N1","N2","N3","N4","N5"]
const KR=[Vector2(-7,-11),Vector2(-13,-5),Vector2(-13,5),Vector2(-0.7,-16),Vector2(3,0),Vector2(15,0),Vector2(-0.7,9),Vector2(-0.7,18)]
var checks:int=0
var failures:Array=[]
var combinations:int=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures.append(label)
  if failures.size()<50:print("FIXED_DPS_CONTRACT FAIL ",label)
func actors()->Array:
 var out:Array=[]
 for i in 8:out.append({"role":ROLES[i],"pos":Vector2((i-3.5)*0.35,6),"face":37.0})
 return out
func state()->Dictionary:
 var s:Dictionary={"sim_time":1.0,"beat_started":0.0,"human_actor":-1,"dead":[],"statuses":[]}
 for i in 8:s.statuses.append({})
 return s
func beat(marked:Array,policy:String,sx:int,mask:int)->Dictionary:
 var b:Dictionary={"duration":10.1,"monitor_layout":"kr_astoh","monitor_fixed_dps":{"policy":policy},"monitors":[{"kind":"half","angle":90*sx,"radius":45}],"party_statuses":[],"positions":[],"facing":{}}
 for i in 8:
  # Deliberately wrong generated solutions. Public steering must not use them.
  b.positions.append(Vector2(900+i,900));b.facing[i]=999.0
 for i in 3:
  b.party_statuses.append({"actor":int(marked[i]),"key":"monitor_right" if mask&(1<<i) else "monitor_left","remaining":-1})
  b.monitors.append({"kind":"half","actor":(int(marked[i])+1)%8,"offset":0,"radius":45})
 return b
func held(b:Dictionary,a:Array,s:Dictionary,label:String)->void:
 var before:String=JSON.stringify([b,a,s])
 for i in 8:
  ck(I.bot_goal(i,b,a,s).is_equal_approx(a[i].pos),label+" holdpos%d"%i)
  ck(is_equal_approx(float(I.bot_facing(i,b,a,s)),float(a[i].face)),label+" holdface%d"%i)
 ck(before==JSON.stringify([b,a,s]),label+" read-only")
func run()->void:
 var oracle_path:String=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--oracle="):oracle_path=arg.trim_prefix("--oracle=")
 var oracle:Variant=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
 ck(oracle is Array and oracle.size()==224,"sealed oracle224")
 if not oracle is Array:quit(1);return
 for row in oracle:
  var marked:Array=[];var expected:Array=[]
  for role in row.marked:marked.append(ROLES.find(str(role)))
  expected.resize(8)
  for role in row.role_slot:expected[SLOTS.find(str(row.role_slot[role]))]=ROLES.find(str(role))
  ck(F.allocate(marked,str(row.policy))==expected,"oracleallocation "+str(row.marked)+str(row.policy))
  for mask in 8:
   combinations+=1
   var b:Dictionary=beat(marked,str(row.policy),int(row.sign_x),mask)
   var a:Array=actors();var s:Dictionary=state();var before:String=JSON.stringify([b,a,s])
   for i in 8:
    var rank:int=expected.find(i)
    var want:Vector2=KR[rank];want.x*=int(row.sign_x)
    ck(I.bot_goal(i,b,a,s).is_equal_approx(want),"publicgoal %d/%d"%[combinations,i])
    var aim:float=37.0
    if rank<3:
     var mi:int=marked.find(i)
     var side:float=90.0 if mask&(1<<mi) else -90.0
     aim=float([270*int(row.sign_x),0,180][rank])-side
    ck(absf(wrapf(float(I.bot_facing(i,b,a,s))-aim,-180,180))<0.0001,"publicface %d/%d"%[combinations,i])
   ck(before==JSON.stringify([b,a,s]),"publicdecisions read-only%d"%combinations)
   s.human_actor=6
   ck(I.bot_goal(6,b,a,s)==a[6].pos and float(I.bot_facing(6,b,a,s))==float(a[6].face),"human no-op%d"%combinations)
 for bad in [[],[0,1],[0,1,2,3],[0,0,1],[-1,0,1],[0,1,8]]:ck(F.allocate(bad,"fixed_dps").is_empty(),"allocatorreject "+str(bad))
 ck(F.allocate([0,1,2],"typo").is_empty(),"invalidpolicy")
 var m:Array=[1,4,6]
 for variant in ["missing","future","expired","consumed","duplicate","conflict","dead","role","bossmissing","bossduplicate","bossinvalid","runtimeexpired","stalevalid"]:
  var b:Dictionary=beat(m,"fixed_dps",1,3);var a:Array=actors();var s:Dictionary=state()
  match variant:
   "missing":b.party_statuses.remove_at(0)
   "future":b.party_statuses[0].visible_from=2.0
   "expired":b.party_statuses[0].expires=0.9
   "consumed":s.consumed_party_signals={"1":[b.party_statuses[0].key]}
   "duplicate":b.party_statuses.append(b.party_statuses[0].duplicate(true))
   "conflict":b.party_statuses.append({"actor":1,"key":"monitor_left","remaining":-1})
   "dead":s.dead=[1]
   "role":a[0].role="H1"
   "bossmissing":b.monitors.remove_at(0)
   "bossduplicate":b.monitors.append(b.monitors[0].duplicate(true))
   "bossinvalid":b.monitors[0].angle=0
   "runtimeexpired":s.statuses[1][b.party_statuses[0].key]={"expires":0.9}
   "stalevalid":
    for i in 8:I.bot_goal(i,b,a,s)
    b.party_statuses.clear()
  held(b,a,s,variant)
 # A cached valid observation must not survive expiry or a subsequent beat.
 var b:Dictionary=beat(m,"fixed_dps",1,3);var a:Array=actors();var s:Dictionary=state()
 for raw in b.party_statuses:raw.expires=2.0
 I.bot_goal(0,b,a,s);s.sim_time=2.1
 held(b,a,s,"expired-after-valid")
 print("FIXED_DPS_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"abstract_rows":224,"public_polarity_combinations":combinations,"scope":"pure synthetic public decisions vs sealed112allocation oracle x2sides x8polarities; notMain/movement/damage/native/Web"}))
 quit(1 if not failures.is_empty() or combinations!=1792 else 0)
func _initialize()->void:call_deferred("run")
