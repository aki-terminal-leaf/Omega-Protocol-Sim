extends SceneTree
## Source-backed placement contracts; coach goals are NOT enemy spawn evidence.
const E=preload("res://scripts/encounters.gd")
const R=preload("res://scripts/rules.gd")
const LB=preload("res://scripts/p6_lb.gd")
const LR=preload("res://scripts/p2_limitless_runtime.gd")
const DP=preload("res://scripts/p5_delta_patterns.gd")
var checks:=0
var failures:=0
var courses:=0
var coverage:Dictionary={}
var observations:Dictionary
var label:=""
func check(ok:bool,why:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<=25:print("SPAWN FAIL ",label," ",why)
func close(a:Variant,b:Variant,tolerance:=0.06)->bool:return R.v(a).distance_to(R.v(b))<tolerance
func bearing(p:Variant)->float:
 var v:=R.v(p)
 return fposmod(rad_to_deg(atan2(v.x,-v.y)),360.0)
func grid(angle:float,step:float,offset:=0.0)->bool:return absf(wrapf(angle-offset,-step/2,step/2))<0.05
func sigma_allowed(c:Dictionary)->bool:return grid(float(c.tower_angle)-float(c.m_angle),180.0)
func lb_allowed(c:Dictionary)->bool:
 for sample in observations.limitless:
  if close(c.sources[0],sample.male) and close(c.sources[1],sample.female) and close(c.arrow_source,sample.arrow) and close(c.shield_source,sample.shield) and close(c.flare_source,sample.flare):return true
 return false
func inspect_course(id:String,e:Dictionary)->void:
 var beats:Array=e.beats
 check(not beats.is_empty(),"active dispatch produces course")
 match id:
  "p1_loop":
   var waves:=0
   for b in beats:
    if not b.has("program_loop"):continue
    var towers:Array=b.shapes.filter(func(s):return s.kind=="tower")
    check(towers.size()==2,"exactly two towers")
    for tower in towers:
     var p:=R.v(tower.pos);var axes:Array=[absf(p.x),absf(p.y)];axes.sort()
     check(absf(axes[0]-3)<0.01 and absf(axes[1]-12)<0.01,"offset slot, never free arena coordinate")
    check(grid(bearing(towers[0].pos)-bearing(towers[1].pos),90.0) and not close(towers[0].pos,towers[1].pos),"same four-slot family, distinct towers")
    waves+=1
   check(waves==4,"four two-tower waves")
  "p1_panto":
   var events:Array=beats[0].p1_events;var flames:Array=events.filter(func(x):return x.kind=="hazard")
   check(flames.size()==28,"14 opposite cone pairs")
   for pulse in 14:
    var pair:Array=flames.filter(func(x):return x.pulse==pulse)
    check(pair.size()==2 and grid(float(pair[0].shape.angle)-float(pair[1].shape.angle),360.0,180.0),"opposite, not independently random cones")
   check(events.filter(func(x):return x.kind=="bait").size()==10,"ten actual-position bait locks")
  "p1_cannons":
   var es:Array=beats[0].p1_events;var proteans:Array=es.filter(func(x):return x.kind=="proteans")
   var targets:Array=proteans[0].targets+proteans[1].targets;targets.sort()
   check(targets==[2,3,4,5,6,7],"complementary non-tank recipients, not random coordinates")
  "p2_synergy":
   var entities:Array=beats[3].stage_entities;var m:Array=entities.filter(func(x):return x.get("id","")=="helper_m");var f:Array=entities.filter(func(x):return x.get("id","")=="helper_f")
   check(m.size()==1 and f.size()==1 and close(m[0].pos,-R.v(f[0].pos)),"genuine M/F always opposite")
   check(absf(R.v(m[0].pos).length()-10.0)<0.01 and grid(bearing(m[0].pos),45.0,22.5),"genuine pair between waymarks, not on eight waymarks")
   var eye:Array=entities.filter(func(x):return x.form=="optical_unit")
   check(eye.size()==1 and absf(R.v(eye[0].pos).length()-45.0)<0.01 and grid(bearing(eye[0].pos),45.0),"eye only eight outside slots")
   var late:Array=beats[6].stage_entities.filter(func(x):return x.form=="male");var angles:Array=[]
   for entity in late:angles.append(bearing(entity.pos));check(absf(R.v(entity.pos).length()-13)<0.01,"five late M at radius13")
   angles.sort();var gaps:Array=[]
   for i in 5:gaps.append(roundi(fposmod(angles[(i+1)%5]-angles[i],360)))
   gaps.sort();check(gaps==[45,45,90,90,90],"four cardinal/intercardinal helpers plus between-slot transformed M")
  "p2_limitless":
   var c:Dictionary=beats[0].limitless_config
   check(lb_allowed(c) and c.spawn_scope=="verified_joint_capture_subset","whole LB tuple comes from one verified clear")
   check(int(c.arrow_target)>=2,"Arrow selects a non-tank")
   var state:Dictionary={"sim_time":0.0};LR.begin(beats[0],state);state.sim_time=6.0;LR.sync(beats[0],state)
   var female:Array=beats[0].stage_entities.filter(func(x):return x.id=="limitless_main_f")
   check(close(female[0].pos,[0,-10],0.001),"actual protected female fixed north10, not outside22")
  "p3_transition":
   var arms:Array=beats[0].p3_transition_events.filter(func(x):return x.kind=="arm_cue")
   check(arms.size()==6,"six arms, not freely sampled positions")
   for a in arms:check(absf(R.v(a.entity.pos).length()-14)<0.03 and grid(bearing(a.entity.pos),60.0),"six fixed hexagonal positions")
   var marks:Dictionary=beats[0].p3_transition_events[0]
   check(marks.purple.size()==4 and marks.white.size()==2 and marks.purple.all(func(a):return a not in marks.white),"four spread/two stack holders, disjoint")
  "p3_hello":
   for event in beats[0].hw_events:
    if event.kind!="towers":continue
    check(event.towers.size()==4,"four HW towers")
    var red:=0;var blue:=0
    for tower in event.towers:
     red+=int(tower.colour=="red");blue+=int(tower.colour=="blue")
     check(absf(R.v(tower.pos).length()-14)<0.01 and grid(bearing(tower.pos),45.0),"HW cardinal/intercardinal slots at14")
    check(red==2 and blue==2,"two towers of each colour")
    var same:Array=event.towers.filter(func(t):return t.colour==event.towers[0].colour)
    check(grid(bearing(same[0].pos)-bearing(same[1].pos),180.0,90.0),"same-colour towers adjacent, not opposite")
  "p3_monitors":
   var sources:Array=beats[0].monitors
   check(sources.size()==4 and grid(float(sources[0].angle),180.0,90.0),"boss monitor E/W plus three player monitors")
   for s in sources.slice(1):check(absf(float(s.offset))==90.0,"player left/right, not free angle")
  "p4_wave":
   for event in beats[0].p4_wave_events:
    if event.kind=="ring":check(close(event.shape.pos,[0,0],0.001),"rings fixed at arena center")
    if event.kind=="markers":check(event.targets.size()==2 and event.targets[0]!=event.targets[1],"two distinct player targets per wave")
  "p5_delta":
   var c:Dictionary=beats[0].delta_config
   check(DP.valid_assignment(c.assignment),"World holders on different blue pairs")
   check(close(c.beetle,-R.v(c.final)) and absf(R.v(c.beetle).length()-20)<0.001,"beetle/final opposite cardinal20")
   check(absf(R.v(c.eye_pos).length()-45)<0.001 and absf(R.v(c.eye_pos).dot(R.v(c.beetle)))<0.001,"eye perpendicular cardinal45")
   for group in [c.colours.slice(0,4),c.colours.slice(4,8)]:check(group.count(0)==2 and group.count(1)==2,"two fists of each colour per tether group")
  "p5_sigma":
   var c:Dictionary=beats[0].sigma_config
   check(sigma_allowed(c) and c.tower_orientation_scope=="m_or_opposite","tower orientation correlated to M, never independent eight-way")
   var tower_beats:Array=beats.filter(func(b):return b.get("sigma_towers",false));var capacities:Array=[]
   for tower in tower_beats[0].shapes:
    capacities.append(int(tower.count));check(absf(R.v(tower.pos).length()-17)<0.001,"tower centers radius17")
   capacities.sort();check(capacities==([1,1,2,2,2] if c.remote else [1,1,1,1,2,2]),"fixed capacity layout conditional on Glitch")
  "p5_omega":
   var first:Dictionary=beats[0].clone_pattern;var second:Dictionary=beats[1].clone_pattern
   check(grid(float(first.m_angle),90.0,45.0) and grid(float(second.m_angle)-float(first.m_angle),180.0,90.0),"two pairs fill four intercardinals")
   check(first.sword!=second.sword or first.legs!=second.legs,"normal posture pair cannot repeat both")
   check(grid(float(beats[0].omega_config.beetle_angle),90.0),"later beetle only cardinal")
  "p5_solar":
   check(beats.size()==2 and beats.all(func(b):return b.shapes.size()==1 and b.shapes[0].has("actor") and not b.shapes[0].has("pos")),"Solar follows tank/aggro, not a random ground spawn")
  "p6_arrow_dive","p6_arrow_wave":
   var events:Array=beats[0].p6_events;var arrows:Array=events.filter(func(x):return x.kind=="hazard")
   check(arrows.size()==42,"fixed two-axis Arrow family")
   for event in arrows:check(grid(float(event.shape.angle),90.0),"Arrow stays on true N/S and E/W axes")
  "p6_exa_wave","p6_exa_dive":
   var events:Array=beats[0].p6_events;var initial:Array=events.filter(func(x):return x.kind=="hazard" and x.pulse==0)
   check(initial.size()==4,"exactly four adjacent exaflare sources")
   var direction:int=int(beats[0].p6_pattern.direction)
   for i in 4:
    check(absf(R.v(initial[i].shape.pos).length()-24)<0.01 and grid(bearing(initial[i].shape.pos),45.0),"Exa starts at one of eight outer24 slots")
    if i>0:check(absf(wrapf(bearing(initial[i].shape.pos)-bearing(initial[i-1].shape.pos)-direction*45,-180,180))<0.01,"adjacent ordered45-degree sources, not four random points")
  "p6_meteors":
   var state:Dictionary={"p6_lb":{"targets":[]}};LB.spawn_meteors(state)
   var comets:Array=state.p6_lb.targets.filter(func(n):return n.npc_id==15727);var meteors:Array=state.p6_lb.targets.filter(func(n):return n.npc_id==15726)
   check(comets.size()==6 and meteors.size()==2,"six small + two large (four captures override five-comet guide typo)")
   for comet in comets:check(observations.meteors.all(func(s):return s.comets.any(func(p):return close(comet.pos,p,0.02))),"comet fixed position matches every capture")
   check(meteors.all(func(n):return close(n.pos,[0,-10],0.001) or close(n.pos,[0,10],0.001)),"large meteors true N/S10, never random")
  "p6_memory","p6_magic":check(not beats[0].has("stage_entities"),"no invented random peripheral enemy positions")
func _initialize()->void:call_deferred("run")
func run()->void:
 observations=JSON.parse_string(FileAccess.get_file_as_string("res://data/spawn_observations.json"))
 var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
 var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
 for item in catalog:
  var id:String=item.id
  for profile in profiles:
   for seed_value in range(1,33):
    label="%s/%s/seed%d"%[id,profile.id,seed_value]
    var e:Dictionary=E.new().build(id,seed_value,profile)
    inspect_course(id,e);courses+=1;coverage[id]=int(coverage.get(id,0))+1
 label="negative source constraints"
 check(not sigma_allowed({"m_angle":0,"tower_angle":45}),"independent45 tower rotation is rejected")
 var e:Dictionary=E.new().build("p2_limitless",7,profiles[0]);var bad:Dictionary=e.beats[0].limitless_config.duplicate(true)
 bad.arrow_source=bad.shield_source.duplicate();check(not lb_allowed(bad),"overlapping invented arrow/shield tuple rejected")
 check(coverage.size()==20 and courses==3200,"all20 ×five profiles ×32 seeds exercised")
 var result:Dictionary={"checks":checks,"failures":failures,"generated_courses":courses,"coverage":coverage,"scope":"source generation contracts; not complete moving courses or exhaustive server RNG"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var report_path:=arg.trim_prefix("--report=");DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
   var f:=FileAccess.open(report_path,FileAccess.WRITE)
   if f==null:failures+=1;print("SPAWN FAIL cannot open report")
   else:f.store_string(JSON.stringify(result,"  "));f.close()
 print("SPAWN_RESULT ",JSON.stringify(result))
 quit(1 if failures else 0)
