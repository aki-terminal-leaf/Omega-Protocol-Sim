# SPDX-License-Identifier: MIT
extends SceneTree
const Curves=preload("res://scripts/avfx_animation.gd")
const Player=preload("res://scripts/avfx_player.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func curve(values:Array,kind:="scalar",before:=0,after:=0)->Dictionary:
 var keys:Array=[]
 for item in values:keys.append({"time":item[0],"type":item[2] if item.size()>2 else 1,"data":[1.0,1.0,item[1]]})
 return {"keys":keys,"kind":kind,"BvPr":before,"BvPo":after,"RanT":0}
func document()->Dictionary:
 var on:={"value":true}
 return {"schema":1,"groups":{
 "Schd":[{"index":0,"items":[{"values":{"bEna":on,"StTm":3,"TlNo":0},"role":"scheduled_timeline","source_index":0}]}],
 "TmLn":[{"values":{"LpSt":0,"LpEd":0},"items":[{"values":{"bEna":on,"StTm":2,"EdTm":12,"EmNo":0,"ClNo":-1},"role":"timeline_item","source_index":0}]}],
 "Emit":[{"values":{"EVT":0,"LpSt":0,"LpEd":0},"curves":{"CrC":curve([[0,1]]),"CrI":curve([[0,5]])},"axes":{},"color":{},"data":{},"life":{"enabled":true,"Val":20.0,"ValR":0.0,"Type":0},"items":[{"values":{"bEnb":on,"TgtB":0,"CrTm":1,"CrCn":1,"CrPr":100,"PICd":2,"PICo":0},"role":"child_particle","source_index":0}]}],
 "Ptcl":[{"values":{"PrVT":8,"LpSt":0,"LpEd":0,"RMT":2},"axes":{},"color":{},"data":{},"materials":{},"life":{"enabled":true,"Val":4.0,"ValR":0.0,"Type":0}}],"Bind":[],"Efct":[]},"models":[],"textures":[]}
func _initialize()->void:call_deferred("run")
func run()->void:
 var linear:=curve([[0,2],[10,12]])
 check(Curves.value(linear,5)==7.0,"linear interior")
 check(Curves.value(linear,-10)==2.0,"constant pre")
 check(Curves.value(linear,100)==12.0,"constant post")
 var repeat:=linear.duplicate(true);repeat.BvPo=1;repeat.BvPr=1
 check(Curves.value(repeat,15)==7.0,"repeat positive")
 check(Curves.value(repeat,-5)==7.0,"repeat negative")
 var additive:=linear.duplicate(true);additive.BvPo=2;additive.BvPr=2
 check(Curves.value(additive,15)==17.0,"add post")
 check(Curves.value(additive,-5)==-3.0,"add pre")
 var step:=curve([[0,1,2],[10,8]])
 check(Curves.value(step,9.9)==1.0 and Curves.value(step,10)==8.0,"step exact boundary")
 var unsupported:=linear.duplicate(true);unsupported.BvPo=77
 check(Curves.value(unsupported,11)==null,"unknown behavior rejected")
 check(Curves.value(linear,NAN)==null,"nan sample rejected")
 var duplicate:=curve([[0,1],[0,2]])
 check(Curves.value(duplicate,0)==null,"duplicate time rejected")
 var axis:={"ACT":1,"ACTR":0,"axes":{"X":curve([[0,3]])}}
 check(Curves.axes(axis,0,1,"scale",1.0)==Vector3(3,3,3),"axis X to YZ")
 axis.ACT=99;check(Curves.axes(axis,0,1,"scale",1.0)==null,"unknown link rejected")
 var random_curve:=curve([[0,2]])
 for seed_value in 20:
  var x:Variant=Curves.scalar(linear,random_curve,5,seed_value,"sample",0.0)
  check(x>=5.0 and x<=9.0,"random bounded")
  check(x==Curves.scalar(linear,random_curve,5,seed_value,"sample",0.0),"random repeatable")
 check(Curves.life({"enabled":true,"Val":60,"ValR":0,"Type":0},4,"life")==60.0,"zero random life")
 check(Curves.life({"enabled":false},4,"life")==-1.0,"life disabled")
 var player:=Player.new();root.add_child(player)
 check(player.configure(document()),"configure")
 for time in [0,1,2,3,4]:check(player.sample_at(time).is_empty(),"no future emission")
 check(player.sample_at(5).size()==1,"scheduler plus timeline offset")
 check(player.sample_at(8).size()==1,"particle before expiry")
 check(player.sample_at(9).is_empty(),"particle exact expiry")
 check(player.sample_at(10).size()==1,"second emission")
 check(player.sample_at(15).size()==1,"timeline end inclusive emission")
 check(player.sample_at(20).is_empty(),"end stops later emission")
 var first:=player.sample_at(10)
 player.sample_at(500)
 check(player.sample_at(10)==first,"seek backward deterministic")
 check(player.sample_at(INF).is_empty() and player.diagnostics.has("invalid_frame"),"unbounded seek rejected")
 check(player.seek(10),"actual source-driven scene creation")
 check(player.draws.size()==1,"one visible particle")
 player.reset();check(player.draws.is_empty() and player.triggers.is_empty(),"reset clears lifecycle")
 check(player.configure(document()),"reconfigure")
 check(not player.configure({}),"invalid document rejected")
 check(player.sample_at(10).is_empty(),"invalid reconfigure cannot retain previous source")
 player.configure(document())
 var bad:=document();bad.groups.Emit[0].curves.CrI=curve([[0,0]])
 player.configure(bad);player.sample_at(20)
 check(player.diagnostics.has("emission_curve"),"nonpositive interval cannot hang")
 var cycle:=document();cycle.groups.Emit[0].items[0].role="child_emitter"
 cycle.groups.Emit[0].items[0].values.TgtB=0
 player.configure(cycle);check(player.sample_at(5).is_empty() and player.diagnostics.has("budget_exceeded"),"cyclic graph bounded fail closed")
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():
  var dir:=DirAccess.open(args[0])
  if dir!=null:
   for file in dir.get_files():
    if not file.ends_with(".preview.json"):continue
    var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join(file)))
    check(data is Dictionary and player.configure(data),"real AVFX compiler document "+file)
    for time in [0,1,10,30,60,100,150]:
     var sample:=player.sample_at(time)
     check(not player.diagnostics.has("budget_exceeded"),"real corpus bounded "+file)
     check(sample==player.sample_at(time),"real corpus deterministic "+file)
 player.free()
 print("AVFX_RUNTIME checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)
