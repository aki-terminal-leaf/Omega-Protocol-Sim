# SPDX-License-Identifier: MIT
extends SceneTree
## NPC pair priority regression; independent role-name order, no player verdict.
const E=preload("res://scripts/encounters.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
const R=preload("res://scripts/rules.gd")
const ROLES=["MT","ST","H1","H2","D1","D2","D3","D4"]
const EXPECTED=["H1","MT","ST","D1","D2","D3","D4","H2"]
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:
 var profiles:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
 var snapshots:Array=[];var pairs:=0;var d2d4:Array=[]
 for p in profiles:
  for seed_value in range(1,129):
   var e:Dictionary=E.new().build("p2_synergy",seed_value,p)
   var b:Array=e.beats
   snapshots.append(e)
   if p.id!="cn_moogle":continue
   var markers:Array=b[1].party_statuses
   var eye:Vector2=Vector2.ZERO
   for entity in b[4].stage_entities:
    if entity.get("form","")=="optical_unit":eye=R.v(entity.pos)
   var theta:float=atan2(eye.x,-eye.y)
   var symbols:Dictionary={}
   for m in markers:symbols[int(m.actor)]=Signs.symbol_name(m.symbol)
   for shape in ["circle","cross","triangle","square"]:
    var aa:Array=[]
    for a in 8:
     if symbols[a]==shape:aa.append(a)
    check(aa.size()==2,"two glyph actors %d %s"%[seed_value,shape])
    aa.sort_custom(func(a,b2):return EXPECTED.find(ROLES[a])<EXPECTED.find(ROLES[b2]))
    var high_x:float=R.v(b[4].positions[aa[0]]).rotated(-theta).x
    var low_x:float=R.v(b[4].positions[aa[1]]).rotated(-theta).x
    check(high_x<0.0 and low_x>0.0,"CN seed%d %s %s>%s left/right"%[seed_value,shape,ROLES[aa[0]],ROLES[aa[1]]])
    pairs+=1
    if aa==[5,7]:d2d4.append({"seed":seed_value,"shape":shape,"D2_local_x":high_x,"D4_local_x":low_x,"remote":b[2].party_statuses[0].key=="remote_glitch"})
 var snapshot_path:=OS.get_environment("TOP_PRIORITY_SNAPSHOT")
 if not snapshot_path.is_empty():
  var f=FileAccess.open(snapshot_path,FileAccess.WRITE)
  f.store_string(JSON.stringify(snapshots));f.close()
 print("CN_PRIORITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures.size(),"failure_labels":failures,"courses":snapshots.size(),"cn_pairs":pairs,"d2d4":d2d4}))
 quit(1 if not failures.is_empty() else 0)
