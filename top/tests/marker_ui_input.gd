# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Markers=preload("res://scripts/markers.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func mouse(point:Vector2,pressed:bool)->void:
 var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;Input.parse_input_event(e);await process_frame
func key(code:int)->void:
 for pressed in [true,false]:
  var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e);await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false)
 for i in app.filtered.size():
  if app.filtered[i].id=="p1_loop":app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1);break
 app.start_run();app.show_waymark_settings()
 for _i in 3:await process_frame
 print("MARKER_WINDOW ",app.waymark_dialog.position," ",app.waymark_dialog.size," minimum ",app.waymark_dialog.get_contents_minimum_size()," confirm ",app.waymark_dialog.get_ok_button().get_global_rect())
 var confirm_end:Vector2=Vector2(app.waymark_dialog.position)+app.waymark_dialog.get_ok_button().get_global_rect().end
 check(confirm_end.y<=root.size.y and confirm_end.x<=root.size.x,"entire confirmation button is onscreen")
 var before:=JSON.stringify(app.state)
 var editor=app.layout_editor
 var point:Vector2=Vector2(app.waymark_dialog.position)+editor.global_position+editor.screen_point(editor.layout.marks[0].pos)
 await mouse(point,true)
 check(editor.dragging==0,"viewport-routed press reaches mark A")
 var target:=point+Vector2(36,22)
 var motion:=InputEventMouseMotion.new();motion.position=target;motion.global_position=target;motion.relative=target-point;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion);await process_frame
 await mouse(target,false)
 var draft:Dictionary=JSON.parse_string(app.waymark_text.text)
 check(draft.marks[0].pos!=app.waymark_layout.marks[0].pos,"viewport-routed drag edits draft")
 check(editor.dragging==-1 and app.camera_buttons==0,"drag release does not leave camera capture")
 check(JSON.stringify(app.state)==before,"real drag preserves battle state")
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty() and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(args[0])
 app.waymark_dialog.hide();app.return_practice_view();await process_frame
 app.marker_bindings.self=KEY_H;app.save_settings()
 await key(KEY_H);check(Markers.marker_for(app.state,app.player)=="attack1","viewport-routed custom self key")
 await key(KEY_BACKSPACE);check(Markers.marker_for(app.state,app.player)=="","viewport-routed clear")
 await key(KEY_M);check(Markers.marker_for(app.state,app.player)=="","old unbound key stays inactive")
 await key(KEY_B);check(app.marker_popup.visible,"viewport-routed marker panel")
 app.marker_popup.hide();app.show_marker_keys();await process_frame
 if args.size()>1 and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(args[1])
 app.key_dialog.hide();app.queue_free();await process_frame
 print("MARKER_UI_INPUT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
