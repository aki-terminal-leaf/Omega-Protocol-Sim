# SPDX-License-Identifier: MIT
extends SceneTree
## Pure unit test for O.diagnostic(). All fixtures are SIMULATED public receipts
## (synthetic debuff partitions and arm-lattice coordinates). They are not scene pixels,
## original encounter data or original timing. Loads only res://scripts.
const O=preload("res://scripts/p3_transition_observation.gd")
const FIELDS=["status","marks_seen","checkpoint_assisted","source_onset","sources_seen","reason_category"]
const FORBIDDEN=["first","first_at","group","orientation","pos","positions","angle","angles","purple","white","id","ids","rank","slot","delay","deadline","late","at","marks_at","timestamp","origin","basis","invalid","sources","raw"]
const REASONS=["","ambiguous_first_wave","inconsistent_source","invalid_presentation","record_inconsistent"]
const SCOPE="pure unit O.diagnostic on simulated public receipts; not Main/HUD/report/export/original onset"
var checks:int=0
var failures:Array=[]

func _init()->void:
 run()
 print("P3_DIAGNOSTIC_RESULT "+JSON.stringify({"checks":checks,"failures":failures.size(),"failure_labels":failures,"scope":SCOPE}))
 quit(1 if checks==0 or not failures.is_empty() else 0)

func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)

func sel()->Dictionary:
 return {"profile_id":"elemental","phase":"outer"}

func beat()->Dictionary:
 return {"p3_transition_public":sel()}

func arm(deg:float)->Array:
 var p:Vector2=Vector2(sin(deg_to_rad(deg)),-cos(deg_to_rad(deg)))*14.0
 return [p.x,p.y]

func base(flag:Variant=false)->Dictionary:
 return {O.KEY:{"version":1,"origin":10.0,"profile_id":"elemental","purple":[],"white":[],"marks_at":null,"sources":{},"first":null,"first_at":null,"basis":"","blocked":false,"invalid":[],"source_onset":"source_unknown"},"sim_time":20.0,"p3_checkpoint_assisted":flag}

func marks(s:Dictionary,at:float=12.0)->Dictionary:
 s[O.KEY].purple=[0,1,2,3];s[O.KEY].white=[4,5];s[O.KEY].marks_at=at
 return s

func source(s:Dictionary,id:String,deg:float,at:float)->Dictionary:
 s[O.KEY].sources[id]={"pos":arm(deg),"group":0 if is_zero_approx(fposmod(deg,120.0)) else 1,"at":at}
 return s

func wave(s:Dictionary,group:int,at:float,prefix:String)->Dictionary:
 for k in 3:source(s,prefix+str(k),float(group)*60.0+120.0*k,at)
 return s

func observed(group:int,both:bool=false,t:float=14.0,basis:String="displayed_model_nodes",flag:Variant=false)->Dictionary:
 var s:Dictionary=wave(marks(base(flag),t-2.0),group,t,"a")
 if both:wave(s,1-group,t+2.0,"b")
 s[O.KEY].first=group;s[O.KEY].first_at=t;s[O.KEY].basis=basis
 return s

func shape_ok(d:Dictionary)->bool:
 if d.size()!=FIELDS.size():return false
 for k in d:
  if not k is String or k not in FIELDS or k in FORBIDDEN:return false
 for k in FIELDS:
  if not d.has(k):return false
 if not d.status is String or d.status not in O.DIAGNOSTIC_STATUSES:return false
 if not d.marks_seen is bool or not d.checkpoint_assisted is bool:return false
 if not d.sources_seen is int or d.sources_seen<0 or d.sources_seen>3:return false
 if not d.source_onset is String or d.source_onset!="source_unknown":return false
 if not d.reason_category is String or d.reason_category not in REASONS:return false
 if d.reason_category!="" and d.status!="blocked":return false
 if d.status in ["inactive","uninitialized","blocked","invalid_record"] and (d.marks_seen or d.sources_seen!=0):return false
 return true

## Calls the diagnostic and checks purity, primitive shape and output freshness.
func diag(b:Dictionary,s:Dictionary,label:String)->Dictionary:
 var sb:String=var_to_str(b);var ss:String=var_to_str(s)
 var d:Dictionary=O.diagnostic(b,s)
 check(var_to_str(b)==sb and var_to_str(s)==ss,label+":no_mutation")
 check(shape_ok(d),label+":primitive_shape")
 var result:Dictionary=d.duplicate(true)
 d.status="tampered";d.sources_seen=99;d.marks_seen=not d.marks_seen
 check(var_to_str(s)==ss and var_to_str(b)==sb,label+":fresh_output")
 return result

func expect(b:Dictionary,s:Dictionary,label:String,status:String,extra:Dictionary={})->Dictionary:
 var d:Dictionary=diag(b,s,label)
 check(d.status==status,label+":status="+str(d.status))
 for k in extra:
  check(d.get(k)==extra[k],label+":"+str(k))
 return d

func run()->void:
 var s:Dictionary
 # inactive only when the selection key is absent.
 expect({},base(),"inactive_empty","inactive",{"marks_seen":false,"sources_seen":0})
 expect({"family":"hidden","events":[1]},observed(0),"inactive_other_beat","inactive",{"sources_seen":0})
 # Present but malformed selection is invalid_record, never inactive.
 for pair in [["string","x"],["empty",{}],["profile",{"profile_id":"bogus","phase":"outer"}],["phase",{"profile_id":"elemental","phase":7}],["null",null]]:
  expect({"p3_transition_public":pair[1]},base(),"selection_"+pair[0],"invalid_record",{})
 s=observed(0);s[O.KEY].blocked=true
 expect({"p3_transition_public":"x"},s,"selection_over_blocked","invalid_record")
 # uninitialized
 s=base();s.erase(O.KEY)
 expect(beat(),s,"uninit_missing","uninitialized",{"marks_seen":false,"sources_seen":0})
 for bad in [[],"x",5,null]:
  s=base();s[O.KEY]=bad
  expect(beat(),s,"uninit_"+type_string(typeof(bad)),"uninitialized",{})
 # valid progression statuses
 expect(beat(),base(),"waiting_marks","waiting_marks",{"marks_seen":false,"sources_seen":0,"checkpoint_assisted":false})
 expect(beat(),marks(base()),"waiting_source","waiting_source",{"marks_seen":true,"sources_seen":0})
 s=source(source(marks(base()),"a0",0.0,14.0),"a1",120.0,14.5)
 expect(beat(),s,"partial_marks","partial_first_wave",{"marks_seen":true,"sources_seen":2})
 expect(beat(),source(base(),"a0",60.0,14.0),"partial_no_marks","partial_first_wave",{"marks_seen":false,"sources_seen":1})
 expect(beat(),observed(0),"observed","observed",{"marks_seen":true,"sources_seen":3})
 expect(beat(),observed(1,true),"observed_six_sources","observed",{"sources_seen":3})
 s=observed(0);s[O.KEY].purple=[];s[O.KEY].white=[];s[O.KEY].marks_at=null
 expect(beat(),s,"observed_no_marks","observed",{"marks_seen":false,"sources_seen":3})
 expect(beat(),observed(0,false,14.0,"assisted_checkpoint_not_observed",true),"assisted","assisted",{"checkpoint_assisted":true,"sources_seen":3})
 expect(beat(),base(true),"checkpoint_before_arms","waiting_marks",{"checkpoint_assisted":true})
 for flag in [1,"true",[true],{"a":1}]:
  expect(beat(),base(flag),"flag_unsafe_waiting_"+type_string(typeof(flag)),"waiting_marks",{"checkpoint_assisted":false})
  expect(beat(),observed(0,false,14.0,"assisted_checkpoint_not_observed",flag),"assisted_unsafe_flag_"+type_string(typeof(flag)),"invalid_record",{"checkpoint_assisted":false})
 expect(beat(),observed(0,false,14.0,"assisted_checkpoint_not_observed",false),"assisted_without_flag","invalid_record",{"sources_seen":0,"marks_seen":false})
 # blocked: priority over observed, closed reason categories, raw strings never echoed.
 s=base();s[O.KEY].blocked=true
 expect(beat(),s,"blocked_flag","blocked",{"reason_category":"record_inconsistent","marks_seen":false,"sources_seen":0})
 var reasons:Dictionary={"first_wave_order_not_observed":"ambiguous_first_wave","duplicate_physical_source":"inconsistent_source","invalid_source_position":"inconsistent_source","source_outside_public_arm_lattice":"inconsistent_source","contradictory_source_position":"inconsistent_source","invalid_or_duplicate_source_id":"inconsistent_source","invalid_presentation_basis":"invalid_presentation","contradictory_or_malformed_source_cache":"record_inconsistent","slot_3_left_first_secret":"record_inconsistent"}
 for reason in reasons:
  s=observed(0,true);s[O.KEY].blocked=true;s[O.KEY].invalid=[{"at":15.0,"reason":reason}]
  var d:Dictionary=expect(beat(),s,"blocked_"+str(reason),"blocked",{"reason_category":reasons[reason],"sources_seen":0,"marks_seen":false})
  check(not JSON.stringify(d).contains(str(reason)),"blocked_"+str(reason)+":no_echo")
 s=observed(0);s[O.KEY].invalid=[{"at":15.0,"reason":"first_wave_order_not_observed"},{"reason":"x"}]
 expect(beat(),s,"blocked_invalid_only","blocked",{"reason_category":"ambiguous_first_wave"})
 for entry in [5,"first_wave_order_not_observed",{"reason":7},{}]:
  s=base();s[O.KEY].invalid=[entry]
  expect(beat(),s,"blocked_malformed_entry_"+type_string(typeof(entry)),"blocked",{"reason_category":"record_inconsistent"})
 # invalid_record: malformed/untrusted caches never look like normal waiting.
 var bad:Array=[]
 s=base();s[O.KEY].version=2;bad.append(["version2",s])
 s=base();s[O.KEY].version="1";bad.append(["version_string",s])
 s=base();s[O.KEY].blocked="no";bad.append(["blocked_string",s])
 s=base();s[O.KEY].invalid="none";bad.append(["invalid_string",s])
 s=base();s[O.KEY].invalid=null;bad.append(["invalid_null",s])
 for field in O.DIAGNOSTIC_FIELDS:
  s=observed(0);s[O.KEY].erase(field);bad.append(["missing_"+field,s])
 s=base();s[O.KEY].profile_id="aether";bad.append(["profile_mismatch",s])
 s=base();s[O.KEY].profile_id=5;bad.append(["profile_int",s])
 s=base();s[O.KEY].origin=null;bad.append(["origin_null",s])
 s=base();s[O.KEY].basis=3;bad.append(["basis_int",s])
 s=marks(base());s[O.KEY].purple=[0,1,2];bad.append(["purple_non_partition",s])
 s=marks(base());s[O.KEY].purple=[0,1,2,4];bad.append(["purple_white_overlap",s])
 s=marks(base());s[O.KEY].purple=[0,1,2,"3"];bad.append(["purple_string",s])
 s=marks(base());s[O.KEY].purple=[0,1,2,3.5];bad.append(["purple_fraction",s])
 s=marks(base());s[O.KEY].purple={};bad.append(["purple_dict",s])
 s=marks(base());s[O.KEY].marks_at=null;bad.append(["marks_at_null_with_purple",s])
 s=marks(base());s[O.KEY].marks_at="12";bad.append(["marks_at_string",s])
 s=base();s[O.KEY].marks_at=12.0;bad.append(["marks_at_without_purple",s])
 bad.append(["future_marks_at",marks(base(),25.0)])
 bad.append(["marks_before_origin",marks(base(),5.0)])
 s=observed(0);s[O.KEY].first_at=30.0;bad.append(["future_first_at",s])
 bad.append(["future_source_at",source(marks(base()),"a0",0.0,25.0)])
 bad.append(["source_at_inf",source(marks(base()),"a0",0.0,INF)])
 s=base();s.sim_time=5.0;bad.append(["sim_before_origin",s])
 s=base();s.erase("sim_time");bad.append(["sim_missing",s])
 s=base();s.sim_time="20";bad.append(["sim_string",s])
 s=base();s.sim_time=NAN;bad.append(["sim_nan",s])
 s=base();s[O.KEY].sources=[];bad.append(["sources_array",s])
 s=base();s[O.KEY].sources={"a0":5};bad.append(["source_non_dict",s])
 s=base();s[O.KEY].sources={7:{"pos":arm(0.0),"group":0,"at":14.0}};bad.append(["source_int_id",s])
 s=base();s[O.KEY].sources={"":{"pos":arm(0.0),"group":0,"at":14.0}};bad.append(["source_empty_id",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.pos=["x",1];bad.append(["source_pos_string",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.pos=[1.0,2.0];bad.append(["source_off_radius",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.pos=arm(30.0);bad.append(["source_off_angle",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.pos=[0.0,-14.0,0.0];bad.append(["source_pos_size",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.erase("pos");bad.append(["source_pos_missing",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.group=1;bad.append(["source_group_mismatch",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.group="0";bad.append(["source_group_string",s])
 s=source(base(),"a0",0.0,14.0);s[O.KEY].sources.a0.erase("at");bad.append(["source_at_missing",s])
 bad.append(["duplicate_point",source(source(base(),"a0",0.0,14.0),"a1",0.0,14.0)])
 bad.append(["four_same_group",source(wave(marks(base()),0,14.0,"a"),"a3",0.0,14.0)])
 bad.append(["mixed_groups_no_first",source(source(marks(base()),"a0",0.0,14.0),"b0",60.0,14.0)])
 # memory() currently accepts this; the diagnostic must not report partial 3/3 or ready.
 bad.append(["first_null_three_sources",wave(marks(base()),0,14.0,"a")])
 bad.append(["first_null_three_no_marks",wave(base(),1,14.0,"a")])
 s=source(marks(base()),"a0",0.0,14.0);s[O.KEY].first_at=14.0;bad.append(["first_at_without_first",s])
 s=source(marks(base()),"a0",0.0,14.0);s[O.KEY].basis="displayed_model_nodes";bad.append(["basis_without_first",s])
 s=observed(0);s[O.KEY].first=2;bad.append(["first_two",s])
 s=observed(0);s[O.KEY].first="0";bad.append(["first_string",s])
 s=observed(0);s[O.KEY].basis="";bad.append(["first_without_basis",s])
 s=observed(0);s[O.KEY].basis="guess";bad.append(["first_unknown_basis",s])
 s=observed(0);s[O.KEY].first_at=null;bad.append(["first_without_first_at",s])
 s=observed(0);s[O.KEY].first=1;bad.append(["first_witness_mismatch",s])
 s=wave(observed(0),1,14.0,"b");bad.append(["second_wave_within_first_at",s])
 for pair in bad:
  expect(beat(),pair[1],"invalid_"+str(pair[0]),"invalid_record",{"marks_seen":false,"sources_seen":0,"reason_category":""})
 # JSON restore turns ints into floats; status must be unchanged.
 for pair in [["observed",observed(1,true)],["partial",source(marks(base()),"a0",0.0,14.0)],["assisted",observed(0,false,14.0,"assisted_checkpoint_not_observed",true)],["waiting_source",marks(base())]]:
  var before:Dictionary=O.diagnostic(beat(),pair[1])
  var restored:Variant=JSON.parse_string(JSON.stringify(pair[1]))
  var restored_beat:Variant=JSON.parse_string(JSON.stringify(beat()))
  check(restored is Dictionary and restored_beat is Dictionary,"json_"+str(pair[0])+":parse")
  if restored is Dictionary and restored_beat is Dictionary:
   var after:Dictionary=diag(restored_beat,restored,"json_"+str(pair[0]))
   check(var_to_str(after)==var_to_str(before),"json_"+str(pair[0])+":same")
 # Hidden metadata / pending / full beat vs reduced public selection, before and after observed.
 var hidden_a:Dictionary={"p3_transition_public":sel(),"stage_entities":[{"id":"arm","pos":[0.0,-14.0]}],"events":[{"at":99.0,"kind":"arm","first":1}],"family":"family_a","positions":{"0":[1.0,2.0]},"labels":["L"],"routes":{"x":1},"pending":[{"first":0}],"seed":123}
 var hidden_b:Dictionary={"p3_transition_public":sel(),"stage_entities":[],"events":[{"at":15.0,"kind":"arm","first":0}],"family":"family_b","positions":{"0":[-9.0,3.0]},"labels":["R"],"routes":{"y":2},"pending":[{"first":1}],"seed":456}
 s=base();s[O.KEY].blocked=true
 for pair in [["waiting_marks",base()],["waiting_source",marks(base())],["partial",source(marks(base()),"a0",0.0,14.0)],["observed",observed(0,true)],["assisted",observed(1,false,14.0,"assisted_checkpoint_not_observed",true)],["blocked",s],["first_null_three",wave(marks(base()),0,14.0,"a")]]:
  var reduced:String=var_to_str(diag({"p3_transition_public":sel()},pair[1],"reduced_"+str(pair[0])))
  check(var_to_str(diag(hidden_a,pair[1],"hidden_a_"+str(pair[0])))==reduced,"noninterference_a_"+str(pair[0]))
  check(var_to_str(diag(hidden_b,pair[1],"hidden_b_"+str(pair[0])))==reduced,"noninterference_b_"+str(pair[0]))
 # Both first-wave orientations yield the same coarse diagnostic.
 check(var_to_str(diag(beat(),observed(0),"twin_0"))==var_to_str(diag(beat(),observed(1),"twin_1")),"twins_observed")
 check(var_to_str(diag(beat(),observed(0,true),"twin_both_0"))==var_to_str(diag(beat(),observed(1,true),"twin_both_1")),"twins_observed_both")
 check(var_to_str(diag(beat(),source(marks(base()),"a0",0.0,14.0),"twin_partial_0"))==var_to_str(diag(beat(),source(marks(base()),"a0",60.0,14.0),"twin_partial_1")),"twins_partial")
 check(var_to_str(diag(beat(),observed(0,false,14.0,"assisted_checkpoint_not_observed",true),"twin_assisted_0"))==var_to_str(diag(beat(),observed(1,false,14.0,"assisted_checkpoint_not_observed",true),"twin_assisted_1")),"twins_assisted")
 # No assumption about original timing: shifted simulated receipt times give identical output.
 check(var_to_str(diag(beat(),observed(0,true,12.0),"timing_early"))==var_to_str(diag(beat(),observed(0,true,18.0),"timing_late")),"timing_observed")
 check(var_to_str(diag(beat(),marks(base(),10.0),"timing_marks_origin"))==var_to_str(diag(beat(),marks(base(),19.9),"timing_marks_late")),"timing_waiting_source")
 # Repeated calls stay pure.
 s=observed(0,true);var snapshot:String=var_to_str(s)
 for i in 50:O.diagnostic(beat(),s)
 check(var_to_str(s)==snapshot,"repeat_calls_pure")
