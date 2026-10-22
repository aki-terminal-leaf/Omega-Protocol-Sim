extends SceneTree
const E=preload("res://scripts/encounters.gd")
const R=preload("res://scripts/rules.gd")
const Runtime=preload("res://scripts/p5_sigma_runtime.gd")
const I=preload("res://scripts/interactions.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("SIGMA PREPARATION FAIL ",label)
func json_safe(value):
 if value is Vector2:return [value.x,value.y]
 if value is Vector3:return [value.x,value.y,value.z]
 if value is Array:
  var result:Array=[]
  for item in value:result.append(json_safe(item))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[str(key)]=json_safe(value[key])
  return result
 return value
func signature(shapes:Array)->Array:
 var out:Array=[]
 for s in shapes:out.append([snappedf(R.v(s.pos).x,0.001),snappedf(R.v(s.pos).y,0.001),int(s.get("count",s.get("capacity",0)))])
 out.sort_custom(func(a,b):return str(a)<str(b));return out
func actors_at(points:Array)->Array:
 var out:Array=[]
 for i in 8:out.append({"pos":R.v(points[i]),"role":E.ROLES[i],"face":0.0})
 return out
func heading(point)->int:return posmod(int(round(rad_to_deg(R.v(point).angle())+90.0)),360)
func live_state(c:Dictionary,given:=false)->Dictionary:
 var statuses:Array=[]
 for _i in 8:statuses.append({"looper":{"expires":999.0}} if given else {})
 return {"sigma":{"id":c.id,"given":given,"expired":false,"cleansed":[false,false,false,false,false,false,false,false],"roles":[],"history":[]},"statuses":statuses,"sim_time":0.0,"dynamis":[1,1,1,1,1,1,0,0],"dead":[],"spent":[],"events":[],"timeline":[],"runtime_failures":[],"paired_tethers":[],"streams":[]}
func _initialize()->void:call_deferred("run")
func run()->void:
 var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
 for base in profiles:
  for remote in [false,true]:
   for rotation in 8:
    for opposite in [false,true]:
     for doubles in [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]:
      var tower_rotation:float=rotation*45.0+(180.0 if opposite else 0.0)
      var p:Dictionary=base.duplicate(true);p.merge({"sigma_remote":remote,"sigma_m_angle":rotation*45.0,"sigma_tower_angle":tower_rotation,"sigma_double_pairs":doubles,"sigma_single_unmarked":[0,1]},true)
      var e:Dictionary=E.new().build("p5_sigma",49181,p)
      var identify:Dictionary=e.beats.filter(func(b):return b.get("sigma_tell",false))[0]
      var resolution:Dictionary=e.beats.filter(func(b):return b.get("sigma_towers",false))[0]
      check(signature(identify.shapes)==signature(resolution.shapes),"tell equals resolution")
      check(identify.shapes.all(func(s):return s.decorative and s.cue_type=="persistent" and s.sigma_tell and s.sigma_capacity and not s.has("rule")),"tell inert persistent capacity metadata")
      check(resolution.shapes.all(func(s):return s.rule=="count" and s.sigma_capacity and not s.get("decorative",false)),"resolution alone judges")
      var c:Dictionary=e.beats[0].sigma_config
      if base.id=="cn_moogle":
       for shape_index in 4:
        var upper:int=int(c.pairs[shape_index][0]);var lower:int=int(c.pairs[shape_index][1])
        var u:=R.v(e.beats[0].positions[upper]).rotated(-deg_to_rad(float(c.m_angle)));var l:=R.v(e.beats[0].positions[lower]).rotated(-deg_to_rad(float(c.m_angle)))
        check(is_equal_approx(u.x,-6.0+shape_index*4.0) and is_equal_approx(l.x,u.x) and u.y<l.y,"CN actual first-beat horizontal upper/lower")
       var rightmost:int=maxi(int(doubles[0]),int(doubles[1]));var cannon:Dictionary=e.beats[2];var headings:Dictionary={}
       for cone in cannon.shapes:headings[int(cone.target)]=heading(cannon.positions[int(cone.target)])
       check(headings[int(c.pairs[rightmost][0])]==posmod(int(c.m_angle)-90,360) and headings[int(c.pairs[rightmost][1])]==posmod(int(c.m_angle)+90,360),"CN actual rightmost double upperW/lowerE")
      else:check(str(e.beats[0].labels[0]).contains("LEFT") or str(e.beats[0].labels[0]).contains("RIGHT"),"non-CN staging unchanged")
      var state:=live_state(c,false);var tell_actors:=actors_at(identify.positions)
      check(R.evaluate(identify,tell_actors,state).is_empty() and Runtime.snapshot(identify,tell_actors,state).is_empty(),"tell has no collision/runtime damage")
      check(state.sigma.cleansed.count(true)==0 and not state.sigma.given,"tell does not cleanse/grant Looper")
      var json_beat:Dictionary=JSON.parse_string(JSON.stringify(json_safe(identify)));Runtime.sync(json_beat,state)
      check(signature(state.sigma.visible_towers)==signature(identify.shapes),"JSON-native tell sync preserves tower signature")
      var restored:Dictionary=JSON.parse_string(JSON.stringify(json_safe(state)));Runtime.sync(json_beat,restored)
      check(signature(restored.sigma.visible_towers)==signature(identify.shapes),"tell survives JSON restore with tower signature")
      var invalid:=actors_at(resolution.positions);invalid[0].pos=Vector2.ZERO
      check(not R.evaluate(resolution,invalid,live_state(c,true)).is_empty(),"actual resolution enforces capacities")
      var resolving:=live_state(c,true)
      check(Runtime.snapshot(resolution,actors_at(resolution.positions),resolving).is_empty() and resolving.sigma.cleansed.count(true)==8,"actual resolution cleanses valid capacities")
      Runtime.sync(resolution,restored);check(restored.sigma.has("visible_towers"),"tell persists through resolution")
      Runtime.sync({"shapes":[]},restored);check(not restored.sigma.has("visible_towers"),"tell clears after source lifecycle")
 # Production dispatcher, not only direct helper calls, must project and clear.
 var profile:Dictionary=profiles[0].duplicate(true);profile.sigma_remote=false
 var integrated:Dictionary=E.new().build("p5_sigma",49181,profile)
 var initial:Dictionary=integrated.beats[0]
 var reveal:Dictionary=integrated.beats.filter(func(b):return b.get("sigma_tell",false))[0]
 var resolved:Dictionary=integrated.beats.filter(func(b):return b.get("sigma_towers",false))[0]
 var following:Dictionary=integrated.beats.filter(func(b):return str(b.title).contains("F and arms appear"))[0]
 var active:Dictionary={"sim_time":0.0,"dynamis":integrated.initial_dynamis.duplicate(),"human_actor":4}
 var people:=actors_at(initial.spawn)
 I.begin(initial,people,active)
 check(not active.sigma.has("visible_towers"),"production pre-reveal state has no towers")
 active.sim_time=19.3;I.begin(reveal,people,active)
 check(active.sigma.get("visible_towers",[]).size()==6,"production dispatcher publishes revealed capacity")
 var restored_active:Dictionary=JSON.parse_string(JSON.stringify(json_safe(active)))
 I.sync(resolved,restored_active)
 check(restored_active.sigma.get("visible_towers",[]).size()==6,"production restored resolution retains observed capacity")
 I.begin(following,people,restored_active)
 check(not restored_active.sigma.has("visible_towers"),"production F transition clears observed towers")
 I.begin(initial,people,active)
 check(not active.sigma.has("visible_towers"),"same-source initial retry clears old presentation")
 var hidden:=live_state({"id":"hidden"},false);Runtime.sync({"shapes":[]},hidden)
 check(not hidden.sigma.has("visible_towers"),"hidden before identify has no tell/late preview")
 print("SIGMA_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"all profiles, both distances, all8 M and M/opposite towers, all6 double pairs; actual geometry/runtime/JSON lifecycle"}))
 quit(1 if failures else 0)
