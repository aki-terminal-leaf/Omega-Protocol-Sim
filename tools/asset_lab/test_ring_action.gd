extends SceneTree
const Action = preload("res://scripts/original_ring_action.gd")
const Preview = preload("res://scripts/ring_action_preview.gd")
var failures: Array = []
func check(value: bool, label: String) -> void:
 if not value: failures.append(label)
func snapshot(a: Node3D) -> Array:
 var rows: Array = []
 for spec in a.effect.last_particles:
  var mesh: MeshInstance3D = a.effect.draws[spec.key]
  var material: ShaderMaterial = mesh.material_override
  var layers: Array = []
  for i in 4:
   var tex: Variant = material.get_shader_parameter("tex%d" % i)
   layers.append({"enabled":material.get_shader_parameter("ena%d" % i),"texture_size":str(tex.get_size()) if tex is Texture2D else "none","scroll":str(material.get_shader_parameter("scroll%d" % i)),"scale":str(material.get_shader_parameter("scale%d" % i))})
  rows.append({"key":spec.key,"index":spec.index,"kind":spec.kind,"age":spec.age,"transform":str(mesh.transform),"world":str(mesh.global_transform),"color":str(spec.color),"surfaces":mesh.mesh.get_surface_count(),"bounds":str(mesh.get_aabb()),"layers":layers})
 return rows
func radial_oracle(time: float, raw: Dictionary) -> Dictionary:
 var result := {}
 for field in raw:
  if not raw[field] is Array:
   result[field]=raw[field]
   continue
  var keys: Array = raw[field]
  var value := float(keys[-1].value)
  if time <= float(keys[0].time): value=float(keys[0].value)
  else:
   for i in range(1,keys.size()):
    if time <= float(keys[i].time):
     var u := (time-float(keys[i-1].time))/(float(keys[i].time)-float(keys[i-1].time))
     value=float(keys[i-1].value)+(float(keys[i].value)-float(keys[i-1].value))*u
     break
  result[field]=value
 return result
func _initialize() -> void:
 create_timer(20.0).timeout.connect(func(): quit(1))
 call_deferred("run")
func run() -> void:
 var a := Action.new()
 var b := Action.new()
 root.add_child(a)
 root.add_child(b)
 a.set_process(false)
 b.set_process(false)
 check(a.configure() and b.configure(),"configure")
 if not is_instance_valid(a.effect):
  finish({"failures":["configure failed",a.error]})
  return
 var data: Dictionary = a.data.duplicate(true)
 var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://radial-oracle.json"))
 var radial_forward: Dictionary = {}
 var samples: Array = []
 var forward: Dictionary = {}
 var nonzero := 0
 var diagnostic_union: Dictionary = {}
 for step in range(int(a.end_frame*2)+1):
  var t := step/2.0
  check(a.seek(t),"forward seek %s" % t)
  for diagnostic in a.effect.report().diagnostics: diagnostic_union[diagnostic] = true
  var rows := snapshot(a)
  var radial := a.radial_descriptors()
  radial_forward[str(t)]=radial
  if t >= 15 and t <= 32:
   check(radial.size()==1,"live radial %s" % t)
   if radial.size()==1:
    check(radial[0].emitter_age==t-15 and radial[0].birth==15,"emitter relative offset")
    check(radial[0].parameters==radial_oracle(t-15,raw),"independent raw radial sample %s" % t)
    check(radial[0].presence.IRad==false and not radial[0].parameters.has("IRad"),"absent IRad preserved")
    check(radial[0].scope=={"bAOV":0,"bAGm":0},"raw scope bits")
  else: check(radial.is_empty(),"radial outside emitter interval %s" % t)
  forward[str(t)] = rows
  if not rows.is_empty(): nonzero += 1
  samples.append({"time":t,"count":rows.size(),"particles":rows,"radial":a.radial_descriptors()})
 check(nonzero>10,"nonzero frames")
 check(forward["0.0"].size()==1 and forward["15.0"].size()==10 and forward["89.5"].size()==1,"exact start/motion/last tail counts")
 check(diagnostic_union.has("unsupported_host_effector/7.0"),"active effector diagnostic retained")
 check(forward["20.0"]!=forward["21.0"],"actual source motion")
 check(snapshot(a).is_empty(),"supported after-empty")
 for step in range(int(a.end_frame*2),-1,-1):
  var t := step/2.0
  check(a.seek(t),"reverse seek")
  check(a.radial_descriptors()==radial_forward[str(t)],"reverse radial %s" % t)
  check(snapshot(a)==forward[str(t)],"reverse deterministic %s" % t)
 check(a.seek(20) and b.seek(40),"two clocks")
 var before := snapshot(b)
 check(a.seek(35) and snapshot(b)==before,"instance isolation")
 check(a.seek(17) and b.seek(21),"simultaneous radial clocks")
 var saved := b.radial_descriptors()
 if a.radial_descriptors().is_empty() or saved.is_empty():
  finish({"failures":failures,"debug_radial":a.effect.RadialEffect.evaluate(a.effect.document.groups.Efct[0],2,"debug"),"diagnostics":a.effect.report()})
  return
 check(a.radial_descriptors()[0].emitter_age==2 and saved[0].emitter_age==6,"separate descriptor ages")
 a.pause()
 var paused := a.radial_descriptors()
 check(a.advance(1) and a.radial_descriptors()==paused,"paused radial immutable")
 var external := a.radial_descriptors()
 external[0].parameters.Str=999
 check(a.radial_descriptors()==paused,"consumer snapshot detached")
 check(a.seek(16) and b.radial_descriptors()==saved,"radial sibling isolation")
 var direct_samples: Array = []
 var ages := [0.0,2.0,6.0,17.0,20.0,20.5]
 for local_age in ages:
  var direct: Dictionary = a.effect.RadialEffect.evaluate(a.effect.document.groups.Efct[0],local_age,"raw-direct")
  check(direct.descriptor_valid and direct.parameters==radial_oracle(local_age,raw),"raw curve entry/peak/last/postend")
  direct_samples.append(direct)
 ages.reverse()
 for i in ages.size():
  check(a.effect.RadialEffect.evaluate(a.effect.document.groups.Efct[0],ages[i],"raw-direct")==direct_samples[direct_samples.size()-1-i],"direct curve reverse")
 var original: Dictionary = a.effect.document.groups.Efct[0].duplicate(true)
 for fault in ["missing","nan","inf","overflow","type","unknown","presence","curve_type","fractional_key","random","loop","scope","nan_type"]:
  var broken := original.duplicate(true)
  match fault:
   "missing": broken.data.erase("Str")
   "nan": broken.data.Str.keys[0].data[2]=NAN
   "inf": broken.data.FSDc=INF
   "overflow": broken.data.Str.keys[0].data[2]=1.0e39
   "type": broken.values.EfVT=123
   "unknown": broken.data.unknown_fields.append({"tag":"ZZZ"})
   "presence": broken.data.presence.IRad=true
   "curve_type": broken.data.Str="bad"
   "fractional_key": broken.data.Str.keys[0].type=1.5
   "random": broken.data.random_fields.append("StrR")
   "loop": broken.values.LpEd=10
   "scope": broken.values.bAGm=2
   "nan_type": broken.values.EfVT=NAN
  a.effect.document.groups.Efct[0]=broken
  check(a.seek(17) and a.radial_descriptors().is_empty(),"bad radial clears "+fault)
  a.effect.document.groups.Efct[0]=original.duplicate(true)
 check(a.seek(17),"restore radial")
 a.effect.emission_stop_frame=16
 check(a.seek(17) and a.radial_descriptors().is_empty(),"explicit emission stop descriptor clear")
 a.effect.emission_stop_frame=INF
 check(a.configure() and a.radial_descriptors().is_empty(),"replacement zero clears radial")
 var simultaneous := {"first":snapshot(a),"second":before}
 check(a.seek(a.end_frame) and a.play() and a.age==0 and a.playing,"restart same action")
 a.pause()
 check(a.advance(1) and a.age==0,"pause")
 check(a.play() and a.advance(100) and not a.playing and a.age==a.end_frame,"inspection end stops")
 check(not a.lifetime.finite and a.lifetime.reason=="unsupported effector","lifetime blocker retained")
 var source_report: Dictionary = b.report().duplicate(true)
 source_report["diagnostics_all_frames"] = diagnostic_union.keys()
 # Compare every embedded mesh vertex/color/UV/index to the actual engine ArrayMesh.
 var geometry: Array = []
 for model in b.effect.document.models:
  var made: Dictionary = b.effect.MeshStage.create(model)
  check(made.status=="source_geometry","source mesh creation")
  var arrays: Array = made.mesh.surface_get_arrays(0)
  check(arrays[Mesh.ARRAY_VERTEX].size()==model.vertices.size(),"vertex cardinality")
  for i in model.vertices.size():
   var v: Dictionary = model.vertices[i]
   check(arrays[Mesh.ARRAY_VERTEX][i]==Vector3(v.position[0],v.position[1],v.position[2]),"original position")
   check(arrays[Mesh.ARRAY_TEX_UV][i]==Vector2(v.uv[0][0],v.uv[0][1]),"original UV0")
   check(arrays[Mesh.ARRAY_TEX_UV2][i]==Vector2(v.uv[1][0],v.uv[1][1]),"original UV1")
   check(arrays[Mesh.ARRAY_COLOR][i].is_equal_approx(Color(v.color[0]/255.0,v.color[1]/255.0,v.color[2]/255.0,v.color[3]/255.0)),"original vertex color")
  var custom := PackedFloat32Array()
  for v in model.vertices: custom.append_array(PackedFloat32Array([v.uv[2][0],v.uv[2][1],v.uv[3][0],v.uv[3][1]]))
  check(arrays[Mesh.ARRAY_CUSTOM0]==custom,"original UV2/UV3")
  var expected_indices: Array = []
  for triangle in model.triangles:
   for index in triangle: expected_indices.append(int(index))
  check(Array(arrays[Mesh.ARRAY_INDEX])==expected_indices,"original triangles")
  geometry.append({"vertices":model.vertices.size(),"triangles":model.triangles.size(),"channels":"positions/colors/all four UV pairs/indices compared"})
 var bad: Dictionary = data.duplicate(true)
 bad.assets[bad.pack].sha256 = "00"
 write_json("res://bad-pin.json",bad)
 check(not a.configure("res://bad-pin.json") and not a.visible and a.effect==null and not a.play(),"stale pin failure closed")
 bad = data.duplicate(true)
 bad.textures[bad.textures.keys()[0]] = "res://raw/missing.png"
 write_json("res://bad-texture.json",bad)
 check(not a.configure("res://bad-texture.json") and a.effect==null,"missing texture closed")
 for invalid in [-1.0,NAN,INF,1.0e39]:
  check(a.configure(),"restore before invalid")
  check(not a.seek(invalid) and a.effect==null and not a.visible,"invalid clock fail closed")
 check(a.configure() and a.seek(15),"replace")
 a.release()
 check(a.effect==null and not a.visible and not a.playing and a.radial_descriptors().is_empty(),"release clears")
 var ui := Preview.new()
 root.add_child(ui)
 ui.set_process(false)
 ui.action.set_process(false)
 check(ui.action.age==0 and not ui.action.playing and ui.button.text=="Play","initial paused zero")
 ui.toggle_play()
 check(ui.action.playing and ui.button.text=="Pause","UI play")
 ui.toggle_play()
 check(not ui.action.playing and ui.button.text=="Play","UI pause")
 ui.action.seek(ui.action.end_frame)
 ui.toggle_play()
 check(ui.action.age==0 and ui.action.playing,"UI restart")
 ui.action.advance(100)
 ui._refresh()
 check(not ui.action.playing and ui.button.text=="Play","UI end")
 var result := {"failures":failures,"samples":samples,"nonzero_frames":nonzero,"reverse_samples":forward.size(),"simultaneous":simultaneous,"source_report":source_report,"geometry":geometry,"radial_forward_reverse_samples":radial_forward.size(),"radial_oracle":raw,"direct_radial_samples":direct_samples,"controls_pass":true,"failure_cases":7,"rendering_accepted":false,"all96_accepted":false}
 ui.free()
 a.free()
 b.free()
 finish(result)
func write_json(path: String, value: Variant) -> void:
 var f := FileAccess.open(path,FileAccess.WRITE)
 f.store_string(JSON.stringify(value))
 f.close()
func finish(value: Dictionary) -> void:
 var args := OS.get_cmdline_user_args()
 write_json(args[0],value)
 quit(0 if value.failures.is_empty() else 1)
