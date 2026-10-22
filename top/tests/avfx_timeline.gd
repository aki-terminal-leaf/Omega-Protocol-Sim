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
 var player:=Player.new();root.add_child(player)
 check(player._enabled({"flag":true},"flag"),"enabled native bool true")
 check(not player._enabled({"flag":false},"flag"),"enabled native bool false")
 check(player._enabled({"flag":1},"flag"),"enabled integer one")
 check(not player._enabled({"flag":0},"flag"),"enabled integer zero")
 check(player._enabled({"flag":1.0},"flag"),"enabled float one")
 check(not player._enabled({"flag":"1"},"flag"),"enabled rejects string one")
 check(player._enabled({"flag":{"value":1}},"flag"),"enabled unwraps numeric dictionary")
 check(not player._enabled({"flag":{"value":false}},"flag"),"enabled unwraps false dictionary")
 var doc:=document();doc.groups.Schd[0].items[0].values.StTm=0
 doc.groups.TmLn[0].values.LpSt=2;doc.groups.TmLn[0].values.LpEd=7
 doc.groups.TmLn[0].items[0].values.StTm=2;doc.groups.TmLn[0].items[0].values.EdTm=4
 check(player.configure(doc),"configure loop")
 check(player.sample_at(1).is_empty(),"before timeline item")
 check(player.sample_at(2).size()==1,"loop first boundary")
 check(player.sample_at(6).is_empty(),"before wrap")
 check(player.sample_at(7).size()==1,"loop wrap boundary")
 check(player.sample_at(12).size()==1,"second wrap boundary")
 var first:=player.sample_at(7);player.sample_at(12)
 check(player.sample_at(7)==first,"reverse seek reconstructs loop")
 check(player.trigger(0,3),"trigger accepted")
 player.reset();check(player.triggers.is_empty() and player.frame==0.0,"reset clears lifecycle")
 for cycle in 16:
  check(player.configure(doc),"bounded reset configure")
  check(player.sample_at(7).size()==1,"bounded reset sample")
  player.reset()
 var clip_doc:=document();clip_doc.groups.Schd[0].items[0].values.StTm=0;clip_doc.groups.TmLn[0].clips=[{"type":0x52455354}]
 clip_doc.groups.TmLn[0].items=[{"values":{"bEna":{"value":true},"StTm":1,"EdTm":1,"EmNo":-1,"ClNo":0},"source_index":0}]
 player.configure(clip_doc);player.sample_at(1)
 check(player.diagnostics.has("timeline_clip_reset_requires_runtime_state"),"reset clip explicit unsupported")
 for pair in [[0x554C4C50,"timeline_clip_unlock_requires_runtime_state"],[0x46414449,"timeline_clip_fade_requires_runtime_state"],[0x54524720,"timeline_clip_trigger_requires_runtime_state"],[0x4B494C4C,"timeline_clip_stop_requires_runtime_state"]]:
  clip_doc.groups.TmLn[0].clips[0].type=pair[0];player.configure(clip_doc);player.sample_at(1);check(player.diagnostics.has(pair[1]),"clip lifecycle diagnostic "+pair[1])
 var tiny:=document();tiny.groups.Schd[0].items[0].values.StTm=0;tiny.groups.TmLn[0].values.LpSt=0;tiny.groups.TmLn[0].values.LpEd=1;tiny.groups.TmLn[0].items[0].values.StTm=0
 player.configure(tiny);player.sample_at(1000)
 check(player.diagnostics.has("timeline_cycle_limit"),"timeline cycles bounded")
 player.free();print("AVFX_TIMELINE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
