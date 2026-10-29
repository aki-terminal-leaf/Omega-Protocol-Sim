extends SceneTree
## Field-validation gate, not native CoUF or raster-fidelity acceptance.
const Composite=preload("res://scripts/asset_lab_composite.gd")
var count:=0
func _initialize():call_deferred("run")
func _rejected(c:Node3D,cue:Dictionary,prop:Dictionary,reason:String):
 c.diagnostics.clear()
 assert(c._attachment(cue,prop,0,"field-gate")==null,"malformed binder accepted: "+reason)
 assert(c.diagnostics.has(reason),str(c.diagnostics))
 count+=1
func run():
 var inputs:Dictionary={}
 for arg in OS.get_cmdline_user_args():
  var parts:=arg.split("=",true,1)
  if parts.size()==2:inputs[parts[0]]=parts[1]
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(inputs["--fixture"]))
 var c:=Composite.new();root.add_child(c)
 c.record={"tracks":{"source":fixture.track,"target":fixture.target_track}}
 c.clock=float(fixture.clock_ms)
 var cue:={"source":"source","target":"target"}
 var original:Dictionary=fixture.positive_property
 var actual:Transform3D=c._attachment(cue,original,0,"field-gate")
 var expected:Transform3D=c._track("source",c.clock,false)
 assert(actual.is_equal_approx(expected) and c.diagnostics.is_empty());count+=1
 # JSON float literals must remain valid, not just native integer fixtures.
 var floating:=original.duplicate(true)
 for field in ["BPT","BPTP","CoUF","GenD","bRng"]:floating[field]=float(floating[field])
 assert(c._attachment(cue,floating,0,"field-gate").is_equal_approx(expected));count+=1
 for field in ["BPT","BPTP","CoUF","GenD","bRng"]:
  var missing:=original.duplicate(true);missing.erase(field)
  _rejected(c,cue,missing,"missing_original_binder_field/"+field)
  for bad in [null,true,"-1",.5,NAN,INF]:
   var malformed:=original.duplicate(true);malformed[field]=bad
   _rejected(c,cue,malformed,"invalid_original_binder_field/"+field)
 # Preserve unknown native semantics even when a provided track is stationary.
 for value in [-2,0,1,60,400]:
  var timed:=original.duplicate(true);timed.CoUF=value
  _rejected(c,cue,timed,"source_coordinate_update_frame_semantics_unverified/"+str(value))
 _rejected(c,cue,fixture.weapon_property,"source_coordinate_update_frame_semantics_unverified/0")
 var moved:Array=fixture.track.duplicate(true);moved.append([c.clock-1,42,13,57]);c.record.tracks.source=moved
 _rejected(c,cue,fixture.weapon_property,"source_coordinate_update_frame_semantics_unverified/0")
 c.record.tracks.source=fixture.track
 var offset:=original.duplicate(true);offset.Pos.unknown_fields=["UNKN"]
 _rejected(c,cue,offset,"unsupported_original_binder_offset")
 for bad in [null,1,"",{}]:
  var malformed:=original.duplicate(true);malformed.Pos.unknown_fields=bad
  _rejected(c,cue,malformed,"unsupported_original_binder_offset")
 var empty:=original.duplicate(true);empty.erase("Pos")
 _rejected(c,cue,empty,"unsupported_original_binder_offset")
 _rejected(c,{},original,"missing_original_binder_actor")
 var target:=original.duplicate(true);target.BPT=1
 assert(c._attachment(cue,target,0,"field-gate").is_equal_approx(c._track("target",c.clock,false)));count+=1
 var bone:=original.duplicate(true);bone.BPTP=3;bone.erase("BPID")
 _rejected(c,cue,bone,"invalid_original_binder_field/BPID")
 c.clock=float(fixture.clock_ms)+10001
 _rejected(c,cue,original,"original_binder_pose_unavailable/source")
 # ACT/ACTR are axis links, not enable flags: a sourced nonzero link is valid.
 c.clock=float(fixture.clock_ms);var linked:=original.duplicate(true);linked.Pos.ACT=1;linked.Pos.ACTR=1
 assert(c._attachment(cue,linked,0,"field-gate").is_equal_approx(expected));count+=1
 var receipt:={"status":"STRICT_BINDER_FIELDS_PASS_NOT_NATIVE_SEMANTICS","checks":count,"source_positive":fixture.positive_source,"source_weapon":fixture.weapon_source,"CoUF0_accepted":false,"all96_accepted":false}
 FileAccess.open(inputs["--output"],FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
 print(JSON.stringify(receipt));c.free();quit()
