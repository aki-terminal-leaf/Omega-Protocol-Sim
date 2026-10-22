# SPDX-License-Identifier: MIT
extends SceneTree
const Settings=preload("res://scripts/marker_settings.gd")
const Markers=preload("res://scripts/markers.gd")
const Main=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var library:={"schema":1,"layouts":[]}
 var layout:=Markers.default_layout()
 var saved:=Settings.store(library,layout,"Practice")
 check(saved.ok and saved.library.layouts.size()==1,"save named layout")
 check(library.layouts.is_empty(),"save does not mutate caller on validation path")
 var copy:=Settings.store(saved.library,layout,"Practice",true)
 check(copy.ok and copy.library.layouts[1].name=="Practice (2)","copy unique name")
 var overwritten:=Settings.store(copy.library,Markers.default_layout(18),"Practice")
 check(overwritten.ok and overwritten.library.layouts.size()==2 and overwritten.library.layouts[0].marks[0].pos[1]==-18.0,"explicit named replace")
 for bad in [{"schema":1.5,"layouts":[]},{"schema":"1","layouts":[]},{"schema":1,"layouts":[layout,layout]},null]:
  check(not Settings.validate_library(bad).ok,"invalid library rejected")
 for version in [1.5,"1",true,null]:check(not Markers.validate_layout({"schema":version,"marks":[]}).ok,"strict layout schema")
 var bad_layout:=layout.duplicate(true);bad_layout.marks[0].pos=[NAN,0]
 var before:=JSON.stringify(saved.library)
 check(not Settings.store(saved.library,bad_layout,"Broken").ok and JSON.stringify(saved.library)==before,"invalid save cannot corrupt existing library")
 var full:={"schema":1,"layouts":[]}
 for i in Settings.MAX_LAYOUTS:
  var item:=layout.duplicate(true);item.name="%d"%i;full.layouts.append(item)
 check(not Settings.store(full,layout,"Extra").ok,"library bounded")
 check(Settings.store(full,layout,"0").ok,"full library permits explicit replacement")
 var rotated:=Settings.rotated(layout,90)
 check(rotated.ok and Vector2(rotated.layout.marks[0].pos[0],rotated.layout.marks[0].pos[1]).distance_to(Vector2(13,0))<0.0001,"rotation about fixed north")
 check(layout.marks[0].pos==[0.0,-13.0],"rotation leaves input immutable")
 check(not Settings.rotated(layout,INF).ok,"nonfinite rotation rejected")
 var keys:=Settings.defaults();check(Settings.validate_keys(keys).ok,"default keys valid")
 var duplicate:=keys.duplicate();duplicate.self=duplicate.next
 check(not Settings.validate_keys(duplicate).ok,"duplicate key conflict")
 var reserved:=keys.duplicate();reserved.self=KEY_W
 check(not Settings.validate_keys(reserved).ok,"movement key reserved")
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
 for i in app.filtered.size():
  if app.filtered[i].id=="p1_loop":app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1);break
 app.start_run();app.stop_failure.button_pressed=false
 var combat:=JSON.stringify(app.state);var actors:=JSON.stringify(app.actors)
 app.show_waymark_settings();await process_frame
 app.layout_name.text="My draft";app.save_library_draft(false)
 check(app.marker_library.layouts.size()==1,"actual UI saves named draft")
 check(JSON.stringify(app.state)==combat and JSON.stringify(app.actors)==actors,"draft/library save does not rewrite live battle")
 var editor=app.layout_editor
 var start:Vector2=editor.screen_point(editor.layout.marks[0].pos)
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=start;editor._gui_input(down)
 var motion:=InputEventMouseMotion.new();motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.position=start+Vector2(30,20);editor._gui_input(motion)
 var draft:Dictionary=JSON.parse_string(app.waymark_text.text)
 check(draft.marks[0].pos!=app.waymark_layout.marks[0].pos,"drag updates JSON draft not active layout")
 motion.position=Vector2(9000,9000);editor._gui_input(motion)
 check(Vector2(editor.layout.marks[0].pos[0],editor.layout.marks[0].pos[1]).length()<20.0,"drag cannot leave wall")
 check(JSON.stringify(app.state)==combat,"drag cannot change combat state")
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=motion.position;editor._gui_input(up)
 check(editor.dragging==-1,"drag release clears capture")
 app.waymark_dialog.hide();app.return_practice_view()
 check(app.practice_view and not app.paused,"real return-to-practice resumes controls")
 var original:=Settings.defaults();app.marker_bindings=original.duplicate();app.marker_bindings.self=KEY_H;app.save_settings()
 var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_M;app._unhandled_key_input(event)
 check(Markers.marker_for(app.state,app.player)=="","old key stops self marking")
 event.physical_keycode=KEY_H;app._unhandled_key_input(event)
 check(Markers.marker_for(app.state,app.player)=="attack1","new self key works in actual Main")
 event.physical_keycode=KEY_BACKSPACE;app._unhandled_key_input(event)
 app.open_practice_settings();app.show_setup_tools();await process_frame
 app.seed_edit.grab_focus();check(app.seed_edit.has_focus(),"seed editor is actually focused in settings")
 event.physical_keycode=KEY_H;app._unhandled_key_input(event)
 check(Markers.marker_for(app.state,app.player)=="","text entry blocks marker hotkeys")
 app.seed_edit.release_focus();app.tools_dialog.hide();app.return_practice_view()
 var config:=ConfigFile.new();config.load("user://settings.cfg");config.set_value("future","preserved",123);config.save("user://settings.cfg")
 app.save_settings();config=ConfigFile.new();config.load("user://settings.cfg")
 check(config.get_value("future","preserved")==123,"save merges unrelated config sections")
 check(config.get_value("settings","marker_keys").self==KEY_H,"key stored")
 app.marker_bindings=original;app.marker_library={"schema":1,"layouts":[]};app.load_settings()
 check(app.marker_bindings.self==KEY_H and app.marker_library.layouts.size()==1,"keys and library reload")
 check(app.report().controls.marker_keys.self==KEY_H,"report records actual key settings")
 app.queue_free();await process_frame
 print("MARKER_LIBRARY checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
