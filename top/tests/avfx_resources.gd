# SPDX-License-Identifier: MIT
extends SceneTree
const Player=preload("res://scripts/avfx_player.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func fixture()->Dictionary:
 return {"schema":1,"groups":{
  "Schd":[{"index":0,"items":[{"values":{"bEna":1,"StTm":0,"TlNo":0},"role":"scheduled_timeline","source_index":0}]}],
  "TmLn":[{"values":{},"items":[{"values":{"bEna":1,"StTm":0,"EdTm":10,"EmNo":0,"ClNo":-1},"role":"timeline_item","source_index":0}]}],
  "Emit":[{"values":{"EVT":0},"curves":{},"axes":{},"color":{},"data":{},"items":[{"values":{"bEnb":1,"TgtB":0,"CrTm":1,"CrCn":1,"CrPr":100,"PICd":2,"PICo":0},"role":"child_particle","source_index":0}]}],
  "Ptcl":[{"values":{"PrVT":8,"RMT":2},"axes":{},"color":{},"data":{},"materials":{},"life":{"enabled":true,"Val":1.0,"ValR":0.0,"Type":0}}],"Bind":[],"Efct":[]},"models":[],"textures":[]}
func _initialize()->void:call_deferred("run")
func run()->void:
 var player:=Player.new();root.add_child(player)
 for iteration in 32:
  check(player.configure(fixture()),"configure repeat %d"%iteration)
  check(player.seek(0) and player.draws.size()==1,"source allocates one live draw")
  if player.draws.is_empty():continue
  var draw:WeakRef=weakref(player.draws.values()[0])
  var mesh:WeakRef=weakref(player.draws.values()[0].mesh)
  var material:WeakRef=weakref(player.draws.values()[0].material_override)
  player.playing=true
  if iteration%2==0:
   check(not player.seek(INF) and not player.playing,"failed seek stops background playback")
  else:player.reset()
  check(player.draws.is_empty() and player.mesh_cache.is_empty() and player.texture_cache.is_empty(),"all owned render caches released")
  check(draw.get_ref()==null and mesh.get_ref()==null and material.get_ref()==null,"draw mesh and material references actually freed")
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():
  var textured:=fixture();textured.textures=["vfx/resource_test.atex"]
  textured.groups.Ptcl[0].materials={"TC1":{"bEna":1,"TxNo":0}}
  player.configure(textured,{"vfx/resource_test.atex":args[0]});player.seek(0)
  check(player.texture_cache.has(0),"actual decoded texture is cached")
  if player.texture_cache.has(0):
   var texture:WeakRef=weakref(player.texture_cache[0]);player.reset()
   check(texture.get_ref()==null,"actual texture reference released on reset")
 player.configure(fixture());player.seek(0)
 var dying:WeakRef=weakref(player.draws.values()[0]);player.free()
 check(dying.get_ref()==null,"exit frees owned child draw")
 print("AVFX_RESOURCES checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)
