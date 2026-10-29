extends SceneTree
## Integration checks: exact source selection, unit isolation, reverse seek and UI.
const Director=preload("res://scripts/asset_lab_unit.gd")
func _initialize():call_deferred("run")
func _digest(bytes:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func _visual_state(director:Node3D)->Dictionary:
 var report:Dictionary=director.composite.report();var effects:Array=[];var keys:Array=director.composite.active_fx.keys();keys.sort()
 for key in keys:
  var fx:Node3D=director.composite.active_fx[key].fx
  if not fx.visible:continue
  var draws:Array=[];var ids:Array=fx.draws.keys();ids.sort()
  for id in ids:
   var mesh:MeshInstance3D=fx.draws[id]
   if not mesh.visible or mesh.mesh==null:continue
   var surfaces:Array=[]
   for i in mesh.mesh.get_surface_count():
    var arrays:Array=mesh.mesh.surface_get_arrays(i);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    surfaces.append({"vertices_sha":_digest(vertices.to_byte_array()),"vertex_count":vertices.size()})
   draws.append({"key":id,"world":director.composite._matrix_array(mesh.global_transform),"surfaces":surfaces,"color":str(mesh.material_override.get_shader_parameter("particle_color")) if mesh.material_override is ShaderMaterial else ""})
  effects.append({"key":key,"frame":fx.frame,"particles":fx.last_particles.size(),"draws":draws})
 return {"clock":report.clock_ms,"actors":report.actors,"effects":effects}

func run():
 var args:=OS.get_cmdline_user_args();var inputs:Dictionary={}
 for arg in args:
  var parts:=arg.split("=",true,1)
  if parts.size()==2:inputs[parts[0]]=parts[1]
 var data:String=inputs["--source-root"];var attachments:String=inputs["--attachment-data"];var output:String=inputs["--unit-output"]
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,30,50)
 var director:=Director.new();root.add_child(director)
 assert(director.configure(data,camera,"res://data/asset_lab/performances.json",attachments)==OK,director.error)
 director.composite.effects_enabled=false;director.composite.scene_enabled=false
 var accepted:=0;var missing:=0;var rows:Array=[]
 for id in director.selections:
  var err:int=director.select(id)
  if id in ["P6-01a","P6-01b","P6-01c","P6-21","P6-22","P6-23","P1-13"]:
   assert(err==ERR_UNAVAILABLE and director.selected.is_empty() and not director.composite.visible);missing+=1;continue
  assert(err==OK,id+" "+director.error)
  assert(director.duration>0 and director.composite.cue_selection_enabled)
  director.seek(director.duration*.5)
  var expected:float=float(director.selected.review_window_ms[0])+director.duration*500
  assert(absf(director.composite.clock-expected)<.1,id+" relative/source clock mismatch")
  assert(director.composite.cue_selection.size()==director.selected.cue_keys.size())
  accepted+=1;print("TOP_UNIT_ROUTE ",id);rows.append({"unit":id,"clock_ms":director.composite.clock,"source_cue_count":director.selected.cue_keys.size()})
 # Repeated rounds must NOT silently reuse the prior round's original casts.
 var seen:Dictionary={}
 for id in ["P1-03","P1-04","P1-05","P1-06"]:
  for key in director.selections[id].cue_keys:
   if str(key).begins_with("tether/"):continue
   assert(not seen.has(key),"prior round reused "+key);seen[key]=id
 # Actual FX instantiation/switching/absolute rebuild, no visual-fidelity claim.
 var effects:Array=[]
 director.composite.effects_enabled=true
 for id in ["P1-04","P2-05","P1-05","P2-06"]:
  assert(director.select(id)==OK)
  var t:=-1.0;var found_draws:=0
  for cue in director.composite.cues:
   if not director.composite.cue_selection.has(cue.key):continue
   for offset_ms in [1.,33.,100.,300.]:
    var candidate:float=(float(cue.start)+offset_ms-float(director.selected.review_window_ms[0]))/1000
    if candidate<0 or candidate>=director.duration:continue
    director.seek(candidate);var draws:=0
    for entry in director.composite.active_fx.values():
     if entry.fx.visible:
      for mesh in entry.fx.draws.values():
       if mesh.visible and mesh.mesh!=null and mesh.mesh.get_surface_count()>0:draws+=1
    if draws>0:t=candidate;found_draws=draws;break
   if t>=0:break
  assert(t>=0 and found_draws>0,id+" INVALID positive FX check: no actual source geometry sampled")
  director.seek(t);var first:=JSON.stringify(_visual_state(director));var audit_before:=JSON.stringify(director.composite.report())
  director.seek(minf(director.duration-.01,t+.4));director.seek(t)
  var audit_after:=JSON.stringify(director.composite.report());var visual_after:=JSON.stringify(_visual_state(director))
  FileAccess.open(output.get_base_dir().path_join(id+"-reverse-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"before_report":JSON.parse_string(audit_before),"after_report":JSON.parse_string(audit_after),"visual_state_equal":first==visual_after,"before_visual":JSON.parse_string(first),"after_visual":JSON.parse_string(visual_after)}))
  assert(first==visual_after,id+" actual actor/FX world geometry/material reverse drift")
  for key in director.composite.active_fx:assert(director.composite.cue_selection.has(key),"unselected effect leaked from another unit")
  effects.append({"unit":id,"active":director.composite.active_fx.size(),"diagnostics":director.composite.diagnostics.keys(),"reverse_equal":true,"source_draws":found_draws,"sample_seconds":t})
 # The same frozen unit data must reject a different source cache before use.
 var bad:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_lab/performances.json"));bad.source_hashes["record.json"]="incorrect"
 var bad_path:="user://bad-selection.json";FileAccess.open(bad_path,FileAccess.WRITE).store_string(JSON.stringify(bad))
 var rejected:=Director.new();root.add_child(rejected);assert(rejected.configure(data,camera,bad_path,attachments)==ERR_INVALID_DATA);rejected.free()
 director.free();camera.free()
 # Use the actual scene/UI, not a second reimplementation of its routing.
 var ui:Node3D=load("res://scenes/asset_lab.tscn").instantiate();root.add_child(ui);await process_frame
 assert(ui.director!=null,ui.director_error);ui.playing=false
 ui.director.composite.effects_enabled=false;ui.director.composite.scene_enabled=false
 for i in ui.catalog.units.size():
  ui.view_mode.selected=0;ui._unit_selected(i)
  assert(ui.performance_mode and ui.unit.id==ui.catalog.units[i].id)
  if ui.director.selected.is_empty():assert(not ui.load_error.is_empty());continue
  assert(ui.load_error.is_empty(),ui.load_error)
  ui.clock=ui._duration()*.4;ui._sample_at();assert(absf(ui.slider.value-ui.clock)<.002)
 # Switching to/from the existing inspector hides the previous representation.
 ui._unit_selected(0);ui.view_mode.selected=1;ui._unit_selected(0)
 assert(not ui.performance_mode and not ui.director.visible and not ui.sample.is_empty())
 ui.view_mode.selected=0;ui._unit_selected(0)
 assert(ui.performance_mode and ui.current_model==null and ui.director.visible)
 assert(accepted==89 and missing==7)
 var result:={"status":"UNIT_ROUTING_SOURCE_PASS_NOT_VISUAL_ACCEPTANCE","selections":accepted,"missing_source_choreography_rejected":missing,"source_cache_mismatch_rejected":true,"repeat_round_source_isolation":true,"actual_ui_units_checked":96,"inspector_mode_preserved":true,"source_fx_cases":effects,"rows":rows,"all96_accepted":false}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("TOP_UNIT_ROUTING_PASS ",accepted," source selections, ",missing," original cinematic gaps retained")
 ui.free();quit()
