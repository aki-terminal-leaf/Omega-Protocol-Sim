extends SceneTree
## Headless source/gate checks only. No raster/native equivalence claim.
const Composite=preload("res://scripts/asset_lab_composite.gd")
func _initialize():call_deferred("run")
func count_draws(c:Node3D)->int:
 var total:=0
 for entry in c.active_fx.values():
  if not entry.fx.visible:continue
  for mesh in entry.fx.draws.values():
   if mesh.visible and mesh.mesh!=null and mesh.mesh.get_surface_count()>0:total+=1
 return total
func run():
 var inputs:Dictionary={}
 for arg in OS.get_cmdline_user_args():
  var parts:=arg.split("=",true,1)
  if parts.size()==2:inputs[parts[0]]=parts[1]
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,30,50)
 var results:Array=[]
 for ability in [31491,31539,31650]:
  var c:=Composite.new();root.add_child(c)
  assert(c.configure(inputs["--source-root"],camera)==OK);c.scene_enabled=false
  c.eid=JSON.parse_string(FileAccess.get_file_as_string(inputs["--attachment-data"]))
  var selected:Dictionary={};var identities:Dictionary={}
  for cue in c.cues:
   assert(not identities.has(cue.key),"duplicate source cue key");identities[cue.key]=true
   if cue.get("kind")=="cast_prepare" and int(cue.ability)==ability and selected.is_empty():selected=cue
  assert(not selected.is_empty(),"missing original prepare source "+str(ability))
  assert(c.select_cues([selected.key])==OK)
  assert(c.set_sample_window(float(selected.start),float(selected.start)+20000,[ability],{})==OK)
  assert(not c.provisional_precast_enabled)
  assert(not c.seek(float(selected.start)+100))
  assert(c.active_fx.is_empty(),"unverified timing was enabled by default")
  assert(c.diagnostics.has("source_prepare_disabled_unverified_host_timing/"+str(selected.key)))
  c.provisional_precast_enabled=true
  var samples:Array=[];var maximum_draws:=0;var maximum_particles:=0
  for offset in [33.,300.,1000.]:
   assert(not c.seek(float(selected.start)+offset),"provisional host timing cannot PASS")
   assert(c.diagnostics.has("source_prepare_host_timing_unverified/"+str(selected.key)))
   assert(c.verified_stops.is_empty(),"synthesized cast-duration stop")
   var particles:=0
   for entry in c.active_fx.values():particles+=entry.fx.last_particles.size()
   var draws:=count_draws(c);maximum_draws=maxi(maximum_draws,draws);maximum_particles=maxi(maximum_particles,particles)
   samples.append({"offset_ms":offset,"source_draws":draws,"source_particles":particles,"audit":c.report()})
  assert(maximum_draws>0 and maximum_particles>0,"INVALID positive sample: no original visible geometry")
  c.seek(float(selected.start)+300);var before:=JSON.stringify(c.report())
  c.seek(float(selected.start)+1000);c.seek(float(selected.start)+300)
  assert(before==JSON.stringify(c.report()),"provisional reverse-seek audit drift")
  c.provisional_precast_enabled=false;c.seek(float(selected.start)+300)
  assert(c.active_fx.is_empty(),"disabling provisional sampling left stale FX")
  results.append({"ability":ability,"key":selected.key,"max_source_draws":maximum_draws,"max_source_particles":maximum_particles,"default_off":true,"explicit_sampling_never_accepted":true,"reverse_audit_equal":true,"samples":samples,"performance_accepted":false})
  c.free()
 var report:={"status":"SCOPED_PRECAST_GATING_PASS_NOT_PERFORMANCE_ACCEPTANCE","cases":results,"all96_accepted":false,"visual_or_native_acceptance":false}
 FileAccess.open(inputs["--precast-output"],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 camera.free();print("TOP_PRECAST_SCOPED_GATING_PASS");quit()
