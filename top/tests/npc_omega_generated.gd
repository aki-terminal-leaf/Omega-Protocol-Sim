extends SceneTree
const E=preload("res://scripts/encounters.gd")
const Runtime=preload("res://scripts/p5_omega_runtime.gd")
var failures:=0;var assertions:=0
func check(ok:bool,label:String)->void:
 assertions+=1
 if not ok:failures+=1;print("OMEGA GENERATED FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"));var cn:Dictionary=profiles.filter(func(p):return p.id=="cn_moogle")[0]
 for family in 3:
  var p:=cn.duplicate(true);p.omega_training_family=family
  var encounter:Dictionary=E.new().build("p5_omega",49181+family,p);var cfg:Dictionary=encounter.beats[0].omega_config;var setup:Dictionary=cfg.setup
  var restored:Dictionary=JSON.parse_string(JSON.stringify(setup))
  check(restored.id==setup.id and int(restored.family)==family and restored.first.map(func(a):return int(a))==setup.first and restored.second.map(func(a):return int(a))==setup.second and restored.initial_stacks.map(func(a):return int(a))==setup.initial_stacks and restored.server_frequency_claim==false,"generated setup JSON preserves semantic IDs and counts")
  check(setup.family==family,"forced family persisted");check(setup.initial_stacks==encounter.initial_dynamis,"runtime uses generated stacks")
  check(cfg.setup_id==setup.id and cfg.training_family==family and cfg.first==setup.first and cfg.second==setup.second,"production config persists exact generated setup")
  check(setup.first.all(func(a):return encounter.initial_dynamis[int(a)]==1),"I1 actual one-stack")
  check(setup.second.filter(func(a):return encounter.initial_dynamis[int(a)]==2).size()==family,"actual mandatory count")
  check(setup.second.all(func(a):return a not in setup.first),"disjoint World pairs")
  var first:=Runtime.choose(cfg,encounter.initial_dynamis,false);check(first.size()==8,"production first allocation")
  check(Runtime.choose(JSON.parse_string(JSON.stringify(cfg)),JSON.parse_string(JSON.stringify(encounter.initial_dynamis)),false)==first,"JSON-restored generated config drives same production allocation")
  var actual:Array=encounter.initial_dynamis.duplicate()
  for actor in first.slice(0,6):actual[int(actor)]+=1
  var second:=Runtime.choose(cfg,actual,true);check(second.size()==8,"production second allocation")
  check(Runtime.choose(JSON.parse_string(JSON.stringify(cfg)),JSON.parse_string(JSON.stringify(actual)),true)==second,"JSON-restored generated second allocation matches actual gains")
  for actor in second.slice(0,6):actual[int(actor)]+=1
  check(actual==[3,3,3,3,3,3,3,3],"final8x3")
  check(encounter.beats.all(func(b):return not b.has("replace_dynamis")),"no post-build replacement")
  check(encounter.beats.all(func(b):return not b.has("initial_dynamis")),"beats do not manufacture generated stacks")
  check(E.new().build("p5_omega",49181+family,p).beats[0].omega_config.setup==setup,"same seed setup")
 # Family overrides must not reroll already seeded clone tells or real initial line owners.
 for seed in [1,7,17391]:
  var reference:Dictionary={}
  for family in 3:
   var same:=cn.duplicate(true);same.omega_training_family=family
   var item:Dictionary=E.new().build("p5_omega",seed,same)
   var source:Dictionary={"clones":item.beats.filter(func(b):return b.has("clone_pattern")).map(func(b):return b.clone_pattern),"initial_line_owners":item.beats.filter(func(b):return b.has("transfers"))[0].transfers.initial,"monitor":item.beats[0].omega_config.monitor_angle,"beetle":item.beats[0].omega_config.beetle_angle}
   if family==0:reference=source
   else:check(source==reference,"training family does not shift clone/source/line RNG seed%d"%seed)
 for profile in profiles:
  if profile.id=="cn_moogle":continue
  var unchanged:Dictionary=E.new().build("p5_omega",9,profile)
  check(not unchanged.beats[0].omega_config.has("setup"),"other community keeps existing config")
 var continuous:Dictionary=E.new().build("p5_full",9,cn)
 check(continuous.beats.filter(func(b):return b.has("omega_config")).all(func(b):return not b.omega_config.has("setup")),"continuous actual Sigma path never samples standalone setup")
 var seen:Dictionary={}
 for seed in range(1,80):
  var e:Dictionary=E.new().build("p5_omega",seed,cn);seen[int(e.beats[0].omega_config.training_family)]=true
 check(seen.size()==3,"normal seeds reach all families")
 var base:Dictionary=E.new().build("p5_omega",9,cn);var s:Array=base.initial_dynamis;var twos:Array=[];var ones:Array=[]
 for a in 8:(twos if s[a]==2 else ones).append(a)
 var p:=cn.duplicate(true);p.omega_setup_override={"family":1,"first":[ones[0],ones[1]],"second":[twos[0],ones[2]]}
 check(E.new().build("p5_omega",9,p).beats[0].omega_config.second==[twos[0],ones[2]],"explicit holder fixture")
 print("OMEGA GENERATED assertions=",assertions," failures=",failures);quit(1 if failures else 0)
