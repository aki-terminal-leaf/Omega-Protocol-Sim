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
 var samples: Array = []
 var forward: Dictionary = {}
 var nonzero := 0
 var diagnostic_union: Dictionary = {}
 for step in range(int(a.end_frame*2)+1):
  var t := step/2.0
  check(a.seek(t),"forward seek %s" % t)
  for diagnostic in a.effect.report().diagnostics: diagnostic_union[diagnostic] = true
  var rows := snapshot(a)
  forward[str(t)] = rows
  if not rows.is_empty(): nonzero += 1
  samples.append({"time":t,"count":rows.size(),"particles":rows})
 check(nonzero>10,"nonzero frames")
 check(forward["0.0"].size()==1 and forward["15.0"].size()==10 and forward["89.5"].size()==1,"exact start/motion/last tail counts")
 check(diagnostic_union.has("unsupported_host_effector/7.0"),"active effector diagnostic retained")
 check(forward["20.0"]!=forward["21.0"],"actual source motion")
 check(snapshot(a).is_empty(),"supported after-empty")
 for step in range(int(a.end_frame*2),-1,-1):
  var t := step/2.0
  check(a.seek(t),"reverse seek")
  check(snapshot(a)==forward[str(t)],"reverse deterministic %s" % t)
 check(a.seek(20) and b.seek(40),"two clocks")
 var before := snapshot(b)
 check(a.seek(35) and snapshot(b)==before,"instance isolation")
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
 check(a.effect==null and not a.visible and not a.playing,"release clears")
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
 var result := {"failures":failures,"samples":samples,"nonzero_frames":nonzero,"reverse_samples":forward.size(),"simultaneous":simultaneous,"source_report":source_report,"geometry":geometry,"controls_pass":true,"failure_cases":7,"rendering_accepted":false,"all96_accepted":false}
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
