# SPDX-License-Identifier: MIT
extends SceneTree
## Real Main draw meshes: tower metadata alone is not a visible colour proof.
const Scene=preload("res://scenes/main.tscn")
var checks:=0
var failures:Array=[]
var rows:Array=[]
var output:=""
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr("HW TOWER PRESENTATION FAIL ",label)
func colours(mesh:Mesh)->Dictionary:
 var counts:={"red":0,"blue":0}
 for surface in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(surface)
  if arrays.size()<=Mesh.ARRAY_COLOR or arrays[Mesh.ARRAY_COLOR]==null:continue
  for c in arrays[Mesh.ARRAY_COLOR]:
   if c.r>.95 and c.g>.38 and c.g<.46 and c.b>.43 and c.b<.52:counts.red+=1
   if c.r>.36 and c.r<.44 and c.g>.61 and c.g<.71 and c.b>.95:counts.blue+=1
 return counts
func advance(app,to:float):
 var n:=0
 while app.running and float(app.state.sim_time)<to-.000001 and n<3000:
  app._process(minf(.05,to-float(app.state.sim_time)));n+=1
 check(absf(float(app.state.sim_time)-to)<.0001,"actual clock reached %.2f"%to)
 app.arena._process(0.0);app.arena.draw_indicators()
func sample(app,label:String,visible:bool):
 var towers:Array=app.arena.visible_damage_shapes.filter(func(s):return s.get("hw_preview",false) and s.get("kind","")=="tower")
 var fills:Dictionary=colours(app.arena.aoe);var signs:Dictionary=colours(app.arena.signs)
 if visible:
  check(towers.size()==4 and towers.filter(func(s):return s.colour=="red").size()==2 and towers.filter(func(s):return s.colour=="blue").size()==2,label+" public fourtower metadata")
  check(fills.red>100 and fills.blue>100,label+" actual triangle mesh has both colours")
  check(signs.red>100 and signs.blue>100,label+" actual line mesh has both colours")
 else:
  check(towers.is_empty(),label+" no public tower")
  check(fills.red==0 and fills.blue==0 and signs.red==0 and signs.blue==0,label+" no early/stale tower geometry")
 rows.append({"label":label,"time":app.state.sim_time,"fills":fills,"signs":signs,"tower_count":towers.size()})
 if output!="" and DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  get_root().get_texture().get_image().save_png(output+"/"+label+".png")
func _initialize():call_deferred("run")
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
 var app=Scene.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(4)
 for n in app.filtered.size():
  if app.filtered[n].id=="p3_hello":app.choose_mechanic(n);app.strategy_select.select(1);app.choose_strategy(1);break
 app.seed_edit.text="17391";app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false;app.arena.set_overhead(true)
 for r in 4:
  var at:=24.0+21.0*r
  advance(app,at-10.1);await sample(app,"round%d-before"%(r+1),false)
  advance(app,at-9.9);await sample(app,"round%d-shown"%(r+1),true)
  advance(app,at+.05);await sample(app,"round%d-after"%(r+1),false)
 check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty() and app.all_errors.is_empty(),"unchanged physical outcomes")
 check(not app.state.get("hw_later_assisted",false),"actual presented channel only")
 app.queue_free();await process_frame
 print("HW_TOWER_PRESENTATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"scope":"actual Main draw meshes + optional native frames; ordinary generated Elemental allNPC, not human/fullguide"}))
 quit(0 if failures.is_empty() else 1)
