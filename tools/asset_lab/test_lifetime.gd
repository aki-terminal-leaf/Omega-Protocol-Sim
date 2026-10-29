extends SceneTree
const Lifetime=preload("res://scripts/asset_lab_lifetime.gd")
const Composite=preload("res://scripts/asset_lab_composite.gd")
const Effect=preload("res://scripts/asset_lab_effect.gd")
var failures:Array=[]
var vectors:Array=[]
func _initialize():call_deferred("run")
func node(v:Dictionary={},life:float=5)->Dictionary:
 return {"values":v,"life":{"enabled":true,"Val":life,"ValR":0,"Type":0},"items":[],"axes":{},"curves":{},"data":{}}
func document()->Dictionary:
 var emitter:=node({"EVT":0},10)
 emitter.items=[{"role":"child_particle","source_index":0,"values":{"bEnb":true,"TgtB":0,"CrTm":1,"CrPr":100,"CrCn":1}}]
 return {"schema":1,"groups":{"Schd":[{"index":0,"items":[{"role":"scheduled_timeline","source_index":0,"values":{"bEna":true,"TlNo":0}}]}],"TmLn":[{"values":{},"items":[{"source_index":0,"values":{"bEna":true,"EmNo":0,"StTm":0,"EdTm":-1}}]}],"Emit":[emitter],"Ptcl":[node({"PrVT":1})]}}
func check(name:String,doc:Dictionary,expected:Variant,release:float=INF)->void:
 var result:=Lifetime.upper_bound(doc,release)
 var ok:bool=not result.finite if expected==null else result.finite and absf(float(result.frames)-float(expected))<.000001
 vectors.append({"name":name,"result":result,"expected":expected,"ok":ok})
 if not ok:failures.append(vectors[-1])
func run():
 var d:=document();check("last particle tail",d,15.)
 d=document();d.groups.Emit[0].items[0].values.StFr=-2;check("negative initial age",d,17.)
 d=document();d.groups.Emit[0].items[0].values.GenD=8;check("delayed tail after stop",d,23.)
 d=document();d.groups.Emit[0].items[0].values.merge({"GenD":2,"bGD":true,"CrCn":4},true);check("per child delay",d,21.)
 d=document();d.groups.Emit[0].items[0].values.CrTm=20;check("first generation after death",d,0.)
 d=document();d.groups.Ptcl[0].life.ValR=-10;d.groups.Ptcl[0].life.Type=2;check("negative amplitude negative-only RNG",d,25.)
 d=document();d.groups.Ptcl[0].life.ValR=10;check("random range crossing infinite life",d,null)
 d=document();d.groups.Ptcl[0].life.enabled=false;check("disabled infinite particle life",d,null)
 d=document();d.groups.Ptcl[0].values.merge({"LpSt":0,"LpEd":1});check("looped particle",d,null)
 d=document();d.groups.Schd[0].items.append({"role":"trigger_timeline","values":{"bEna":true,"TlNo":-1}});check("unused trigger",d,15.)
 d.groups.Schd[0].items[-1].values.TlNo=0;check("future host trigger",d,null)
 d=document();d.groups.TmLn[0].items.append({"values":{"bEna":true,"ClNo":0}});check("runtime clip",d,null)
 d=document();d.groups.Emit[0].items[0].role="child_emitter";d.groups.Emit[0].items[0].values.TgtB=1
 var child:=node({"EVT":0},3);child.items=[{"role":"child_particle","source_index":0,"values":{"bEnb":true,"TgtB":0}}];d.groups.Emit.append(child);check("nested source tails",d,18.)
 d.groups.Emit[0].items[0].values.GenD=100;check("late child does not erase earlier children",d,19.,14.)
 d=document();check("verified release preserves tails",d,9.,4.)
 d=document();d.groups.Emit[0].values.EVT=4;check("unsupported emitter not an empty proof",d,null)
 d=document()
 var fx:=Effect.new();root.add_child(fx);fx.configure(d,{},1);fx.emission_stop_frame=4
 var before:=fx.sample_at(8.999);var after:=fx.sample_at(9.001)
 if before.is_empty() or not after.is_empty():failures.append({"release_trail_counts":[before.size(),after.size()]})
 var again:=fx.sample_at(8.999)
 if again!=before:failures.append({"reverse_release_drift":true})
 fx.free()
 controller_checks()
 delayed_child_counterexample()
 var args:=OS.get_cmdline_user_args();var packs:Array=[]
 if args.size()>=2:
  var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("manifest.json")))
  var full:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("full-data.json")))
  for path in full.packs:
   var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join(manifest.native_assets[full.packs[path]].file)))
   var bound:=Lifetime.upper_bound(doc);var row:={"path":path,"bound":bound}
   if bound.finite and bound.frames<Effect.MAX_FRAME:
    var sample:=Effect.new();root.add_child(sample);sample.configure(doc,{},71)
    sample.camera_effects.clear();var particles:=sample.sample_at(bound.frames+.001)
    if not particles.is_empty() or not sample.camera_effects.is_empty():failures.append({"source_tail_outside_bound":path,"bound":bound,"particles":particles.size(),"camera":sample.camera_effects.size()})
    row["sample_diagnostics"]=sample.diagnostics.keys()
    row["runtime_bound_check"]="INVALID_DIAGNOSTICS" if sample.diagnostics.keys().any(func(x):return x not in ["experimental_preview_not_game_equivalence","source_child_limit_active_policy"]) else "PASS_EMPTY_AFTER_BOUND"
    sample.free()
   packs.append(row)
 var independent_cases:=0
 if args.size()>=3:
  var cases:Array=JSON.parse_string(FileAccess.get_file_as_string(args[2]))
  for case in cases:
   independent_cases+=1
   var bound:=Lifetime.upper_bound(case.document)
   if not bound.finite or float(bound.frames)+.000001<float(case.exact_death):failures.append({"independent_exact_death_case":case.case,"exact_death":case.exact_death,"bound":bound})
 var result:={"independent_exact_death_cases":independent_cases,"status":"PASS" if failures.is_empty() else "FAIL","vectors":vectors,"source_packs":packs,"failures":failures,"visual_or_all96_acceptance":false}
 if args.size()>=2:FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(result))
 print("TOP_SOURCE_LIFETIME ",result.status," vectors=",vectors.size()," source_packs=",packs.size()," failures=",failures)
 quit(0 if failures.is_empty() else 1)

func controller_checks()->void:
 var camera:=Camera3D.new();root.add_child(camera)
 var scene:=Composite.new();root.add_child(scene)
 scene.configured=true;scene.scene_enabled=false;scene.view=camera
 scene.effect_root=Node3D.new();scene.add_child(scene.effect_root)
 scene.source_window=Vector2(0,100000)
 scene.packs["fixture"]=document()
 scene.cues=[{"key":"fixture","start":0.,"anchor":0.,"source":"fixture","source_pos":[0,0,0],"path":"fixture"}]
 if not scene.seek(14.5/.03) or scene.active_fx.size()!=1:failures.append({"controller_live_tail_lost":scene.report()})
 var before:Dictionary=scene.active_fx.fixture.fx.report().duplicate(true)
 if not scene.seek(15.001/.03) or not scene.active_fx.is_empty():failures.append({"controller_dead_graph_retained":scene.report()})
 if not scene.seek(14.5/.03) or scene.active_fx.size()!=1 or scene.active_fx.fixture.fx.report()!=before:failures.append({"controller_reverse_eviction_drift":scene.report()})
 if scene.set_sample_window(0,100000,[],{"fixture":{"time_ms":4/.03,"evidence":"synthetic verified release; NOT original source evidence","mode":"release"}})!=OK:failures.append({"fixture_release_rejected":true})
 if not scene.seek(8.9/.03) or scene.active_fx.size()!=1 or scene.active_fx.fixture.fx.last_particles.is_empty():failures.append({"controller_release_tail_lost":scene.report()})
 if not scene.seek(9.001/.03) or not scene.active_fx.is_empty():failures.append({"controller_release_tail_not_evicted":scene.report()})
 scene.set_sample_window(0,100000,[],{"fixture":{"time_ms":4/.03,"evidence":"synthetic kill only","mode":"kill"}})
 if not scene.seek(5/.03) or not scene.active_fx.is_empty():failures.append({"controller_verified_kill_not_applied":scene.report()})
 if not scene.seek(3/.03) or scene.active_fx.size()!=1:failures.append({"controller_reverse_kill_drift":scene.report()})
 scene.cues[0]["node"]={"bind_1":{"origin":1,"type":0,"id":-1},"bind_2":{"origin":2,"type":0,"id":-1}}
 if not scene.seek(3/.03):failures.append({"valid_original_TMB_host_rejected":scene.report()})
 scene.cues[0].node.bind_1.origin=2
 if scene.seek(3/.03) or scene.active_fx.fixture.fx.visible:failures.append({"unsupported_TMB_host_silently_drawn":true})
 scene.record={"actors":{},"tracks":{"fixture":[[0,0,0,0]]}}
 var prop:={"BPT":0,"BPTP":0,"CoUF":-1}
 scene.diagnostics.clear()
 if not scene._attachment(scene.cues[0],prop,0,"fixture") is Transform3D:failures.append({"default_binder_pose_missing":true})
 for update_frame in [0,1,60]:
  prop.CoUF=update_frame
  if scene._attachment(scene.cues[0],prop,0,"fixture")!=null:failures.append({"unverified_coordinate_update_silently_accepted":update_frame})
 scene.dispose();scene.free();camera.free()

func delayed_child_counterexample()->void:
 var d:=document();d.groups.TmLn[0].items[0].values.EdTm=10
 var constant:={"kind":"scalar","BvPr":0,"BvPo":0,"keys":[{"time":0,"type":1,"data":[1,1,100]}]}
 d.groups.Emit[0].life.Val=100;d.groups.Emit[0].curves.CrI=constant
 d.groups.Emit[0].items[0].role="child_emitter"
 d.groups.Emit[0].items[0].values.merge({"TgtB":1,"CrCn":2,"GenD":6,"bGD":true},true)
 var child:=node({"EVT":0},100);child.curves.CrI=constant
 child.items=[{"role":"child_particle","source_index":0,"values":{"bEnb":true,"TgtB":0,"CrTm":3,"CrCn":1,"CrPr":100}}]
 d.groups.Emit.append(child);d.groups.Ptcl[0].life.Val=50
 check("Sonnet delayed-child CrTm counterexample",d,60.)
 var fx:=Effect.new();root.add_child(fx);fx.configure(d,{},1)
 var alive:=fx.sample_at(57)
 if alive.is_empty():failures.append({"review_counterexample_not_reproduced":fx.diagnostics})
 var bound:=Lifetime.upper_bound(d)
 if bound.finite and float(bound.frames)<57 and not alive.is_empty():failures.append({"PROVEN_TOO_EARLY_BOUND":bound,"live_at_frame":57,"particle_count":alive.size()})
 fx.free()
