extends SceneTree
const Player=preload("res://scripts/source_avfx_player.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
 checks+=1
 if not ok:failures+=1;print("CHILD_LIMIT FAIL ",why)
func curve(value:float)->Dictionary:return {"kind":"scalar","BvPr":0,"BvPo":0,"RanT":0,"keys":[{"time":0,"type":1,"value":value,"data":[1,1,value]}]}
func item(role:String,index:int,values:Dictionary={})->Dictionary:
 var v:Dictionary={"bEnb":true,"TgtB":0,"CrTm":1,"CrCn":1,"CrPr":100,"GenD":0,"PICd":2,"PICo":0,"StFr":0}
 v.merge(values,true);return {"role":role,"source_index":index,"values":v}
func document(limit:int,items:Array,life:Dictionary={},interval:=1.0)->Dictionary:
 var particle_life:Dictionary={"enabled":true,"Type":0,"Val":2.0,"ValR":0.0};particle_life.merge(life,true)
 return {"schema":1,"models":[],"textures":[],"groups":{"Schd":[{"index":0,"items":[{"role":"scheduled_timeline","source_index":0,"values":{"bEna":true,"TlNo":0,"StTm":0}}]}],"TmLn":[{"values":{"LpSt":0,"LpEd":0,"BnNo":-1},"clips":[],"items":[{"source_index":0,"values":{"bEna":true,"ClNo":-1,"EmNo":0,"StTm":0,"EdTm":1200}}]}],"Emit":[{"values":{"EVT":0,"ClCn":limit,"LpSt":0,"LpEd":0},"life":{"enabled":true,"Type":0,"Val":1200.0,"ValR":0.0},"axes":{},"color":{},"data":{},"curves":{"CrC":curve(1),"CrI":curve(interval)},"items":items}],"Ptcl":[{"values":{"PrVT":1,"LpSt":0,"LpEd":0},"life":particle_life,"axes":{},"color":{},"data":{},"materials":{},"items":[]}]}}
func _initialize()->void:call_deferred("run")
func run()->void:
 var p:=Player.new();root.add_child(p)
 p.configure(document(1,[item("child_particle",0,{"GenD":5}),item("child_particle",1)],{},10.0))
 var first:=p.sample_at(1.0);var later:=p.sample_at(5.0)
 check(first.size()==1 and str(first[0].key).ends_with("/1/0/0"),"earlier birth wins across item order")
 check(later.size()==1 and str(later[0].key).ends_with("/0/0/0"),"expired earlier child releases slot for later item")
 p.configure(document(1,[item("child_particle",0,{"StFr":1})]));var shifted:=p.sample_at(1.0)
 check(shifted.size()==1 and str(shifted[0].key).ends_with("/0/1/0"),"StartFrame-adjusted death releases slot exactly on boundary")
 var bad_life:Dictionary={"enabled":true,"Type":0,"ValR":0.0}
 var doc:=document(1,[item("child_particle",0,{"bOvr":true,"OvrV":2,"OvrR":0})]);doc.groups.Ptcl[0].life=bad_life
 p.configure(doc);check(p.sample_at(0.0).size()==1,"valid particle override supersedes unusable node life")
 p.configure(document(1,[item("unknown",0),item("child_particle",1)]));check(p.sample_at(0.0).size()==1,"unknown role does not steal known-child slot")
 p.configure(document(0,[item("child_particle",0)],{"Val":1200.0}));var start:=Time.get_ticks_usec();var unlimited:=p.sample_at(1000.0);var ms:=(Time.get_ticks_usec()-start)/1000.0
 check(unlimited.size()==1001,"nonpositive-limit preview policy has no artificial positive cap")
 check(not p.diagnostics.has("budget_exceeded"),"uncapped fixture remains within declared work budget")
 var result:Dictionary={"checks":checks,"failures":failures,"unlimited_1001_ms":ms,"scope":"declared-life preview policy boundaries, not native engine equivalence"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--proof="):var f=FileAccess.open(arg.trim_prefix("--proof="),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result));p.free();quit(1 if failures else 0)
