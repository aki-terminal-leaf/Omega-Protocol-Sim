# SPDX-License-Identifier: MIT
extends SceneTree
const P=preload("res://scripts/sigma_preparation.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:
  failures+=1
  push_error(label)
func has(r,c):return r.errors.any(func(e):return e.code==c)
func ev(s,a,t,m,d=-1):return {"sequence":s,"actor":a,"target":t,"marker":m,"displaced":d,"source":"player","operation":"clear" if m=="" else "assign"}
func solve(d,m,e=[],h=2,after=0):return P.resolve("cn_moogle",d,0,1,m,e,h,after)
func _initialize():call_deferred("run")
func run():
 var d=[1,1,1,1,1,1,0,0];var m=["","","attack1","attack4","attack2","attack3","ignore2","ignore1"];var e=[ev(1,2,2,"attack1")];var r=solve(d,m,e)
 check(r.complete and r.roles==[0,1,7,6,2,3,4,5],"correct")
 var p=["","","attack3","attack2","attack4","attack1","ignore1","ignore2"];check(solve(d,p,[ev(1,2,2,"attack3")]).complete,"legal permutation")
 var alt=m.duplicate();alt[5]="attack5";r=solve(d,alt,e);check(r.complete and r.normalized.attack3==5 and r.raw[5]=="attack5","attack5 vacancy")
 var two=alt.duplicate();two[4]="";check(has(solve(d,two,e),"ambiguous_attack5"),"attack5 ambiguity")
 var ine=m.duplicate();ine[5]="";ine[6]="attack5";ine[7]="ignore1";r=solve(d,ine,e);check(has(r,"ambiguous_attack5") and has(r,"ineligible_actor"),"attack5 ineligible")
 var extra=m.duplicate();extra[6]="attack5";check(has(solve(d,extra,e),"ambiguous_attack5"),"attack5 extra")
 var miss=m.duplicate();miss[4]="";r=solve(d,miss,e);check(not r.complete and has(r,"missing_required_marker") and r.roles[6]==-1,"missing")
 var wrong=m.duplicate();wrong[4]="bind1";check(has(solve(d,wrong,e),"wrong_marker_id"),"wrong")
 var dis=m.duplicate();dis[2]="";dis[3]="attack1";r=solve(d,dis,[ev(1,2,2,"attack1"),ev(2,3,3,"attack1",2)]);check(not r.complete and r.self_action.observed and not r.self_action.current and r.displaced.size()==1,"displaced")
 check(not solve(d,m,[]).complete,"omitted receipt");check(not solve(d,m,[ev(1,3,2,"attack1")]).complete,"wrong actor receipt")
 var j=JSON.parse_string(JSON.stringify([d,m,[ev(1.0,2.0,2.0,"attack1")]]));check(P.resolve("cn_moogle",j[0],0.0,1.0,j[1],j[2],2.0).complete,"JSON IDs")
 var before=JSON.stringify([d,m,e]);solve(d,m,e);check(before==JSON.stringify([d,m,e]),"nonmutation")
 for profile in ["elemental","aether","lpdu","kr_09stop"]:check(has(P.resolve(profile,d,0,1,m,e,2),"unsupported_source_pending"),"unsupported "+profile)
 check(has(P.expected("cn_moogle",[1,2],0,1),"invalid_observation"),"bad length");check(has(P.expected("cn_moogle",[2,2,1,1,1,1,0,1.5],0,1),"invalid_observation"),"bad number");check(has(P.resolve("cn_moogle",d,0,0,m,e,2),"invalid_observation"),"bad world");check(has(solve(d,m,[ev(1.5,2,2,"attack1")]),"invalid_marker_event"),"bad event");check(not solve(d,m,e,2,1).complete,"history boundary")
 # Actual entry family is six ones/two zeroes; holder eligibility is NOT
 # narrowed beyond current source/generator (World may be one or zero).
 for bad_stacks in [[2,2,1,1,1,1,0,0],[1,1,1,1,1,0,0,0],[1,1,1,1,1,1,1,0],[3,1,1,1,1,1,0,0]]:
  check(has(solve(bad_stacks,m,e),"invalid_entry_dynamis"),"reject impossible entry "+str(bad_stacks))
 var world0=["","ignore1","attack1","attack4","attack2","attack3","","ignore2"]
 r=P.resolve("cn_moogle",d,0,6,world0,e,2)
 check(r.complete and r.roles==[0,6,1,7,2,3,4,5],"zero-stack World is not silently filtered by source inference")
 var dup5=alt.duplicate();dup5[6]="attack5";check(not solve(d,dup5,e).complete,"duplicate attack5")
 var world5=alt.duplicate();world5[0]="attack5";world5[5]="";check(not solve(d,world5,e).complete,"World attack5")
 var again=[ev(1,2,2,"attack1"),ev(2,3,3,"attack1",2),ev(3,2,2,"attack1",3)]
 r=solve(d,m,again);check(r.complete and r.self_action.observed and r.self_action.current and r.displaced.size()==2,"self reassignment after displacement")
 r=solve(d,m,[ev(1,2,2,"attack1"),ev(2,2,2,"attack1")],2,1)
 check(r.complete and r.self_action.events.size()==1,"post-boundary self action")
 for bad_owners in [null,{},[],[""],m.slice(0,7),["","","wrong","attack4","attack2","attack3","ignore2","ignore1"],["","",2,"attack4","attack2","attack3","ignore2","ignore1"]]:
  check(not solve(d,bad_owners,e).complete,"malformed owner input")
 for bad_events in [null,{},[{}],[ev(0,2,2,"attack1")],[ev(1,8,2,"attack1")],[ev(1,2,-1,"attack1")],[ev(1,2,2,"attack1",8)],[ev(2,2,2,"attack1"),ev(1,2,2,"attack1")]]:
  check(not solve(d,m,bad_events).complete,"malformed event input")
 var badop=ev(1,2,2,"attack1");badop.operation="clear";check(not solve(d,m,[badop]).complete,"invalid event operation")
 var badsource=ev(1,2,2,"attack1");badsource.source=1;check(not solve(d,m,[badsource]).complete,"invalid event source")
 var invalid_event=ev(1,2,2,"attack1");invalid_event.erase("marker");check(not solve(d,m,[invalid_event]).complete,"missing event marker")
 for data in [[d,alt,e],[d,dis,[ev(1,2,2,"attack1"),ev(2,3,3,"attack1",2)]],[d,m,[ev(1,2.5,2,"attack1")]]]:
  var roundtrip=JSON.parse_string(JSON.stringify(data))
  var original=solve(data[0],data[1],data[2]);var restored=solve(roundtrip[0],roundtrip[1],roundtrip[2])
  check(original.complete==restored.complete and original.roles==restored.roles and original.self_action.current==restored.self_action.current,"JSON allocation and receipt parity")
 print("SIGMA_PREPARATION cases=",checks," failures=",failures);quit(1 if failures else 0)
