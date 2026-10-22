# SPDX-License-Identifier: MIT
extends Control
## Draft-only editor: emitted layouts never directly mutate a live encounter.
signal layout_changed(layout:Dictionary)
const Markers=preload("res://scripts/markers.gd")
var layout:Dictionary=Markers.default_layout()
var dragging:=-1
func _ready()->void:
 custom_minimum_size=Vector2(280,280);mouse_filter=Control.MOUSE_FILTER_STOP;resized.connect(queue_redraw)
func set_layout(value:Dictionary)->bool:
 var checked:=Markers.validate_layout(value)
 if not checked.ok:return false
 if layout==checked.layout:return true
 layout=checked.layout;dragging=-1;queue_redraw();return true
func center()->Vector2:return size*0.5
func unit_scale()->float:return maxf(1.0,minf(size.x,size.y)*0.44/20.0)
func screen_point(point:Array)->Vector2:return center()+Vector2(point[0],point[1])*unit_scale()
func _draw()->void:
 var radius:=20.0*unit_scale();draw_circle(center(),radius,Color(0.06,0.09,0.14));draw_arc(center(),radius,0,TAU,96,Color(0.7,0.23,0.29),2.0,true)
 for x in [-10.0,0.0,10.0]:
  var span:=sqrt(400.0-x*x)
  draw_line(center()+Vector2(x,-span)*unit_scale(),center()+Vector2(x,span)*unit_scale(),Color(0.16,0.2,0.28),1,true)
  draw_line(center()+Vector2(-span,x)*unit_scale(),center()+Vector2(span,x)*unit_scale(),Color(0.16,0.2,0.28),1,true)
 var font:=ThemeDB.fallback_font
 draw_string(font,center()+Vector2(-5,-radius-5),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
 for i in layout.marks.size():
  var mark:Dictionary=layout.marks[i]
  if not bool(mark.enabled):continue
  var point:=screen_point(mark.pos);var idx:=Markers.WAYMARK_IDS.find(str(mark.id));var ink:=Color(Markers.COLOURS[idx])
  draw_circle(point,12.0,ink.darkened(0.35));draw_arc(point,12.0,0,TAU,24,Color.WHITE if i==dragging else ink,2.0,true)
  draw_string(font,point+Vector2(-4.5,5),str(mark.id),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
func _gui_input(event:InputEvent)->void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   var nearest:=15.0;dragging=-1
   for i in layout.marks.size():
    if not bool(layout.marks[i].enabled):continue
    var distance:float=event.position.distance_to(screen_point(layout.marks[i].pos))
    if distance<nearest:nearest=distance;dragging=i
  else:dragging=-1
  queue_redraw();accept_event()
 elif event is InputEventMouseMotion and dragging>=0:
  if (event.button_mask & MOUSE_BUTTON_MASK_LEFT)==0:dragging=-1;queue_redraw();return
  var point:Vector2=((event.position-center())/unit_scale()).limit_length(19.8)
  layout.marks[dragging].pos=[point.x,point.y]
  layout_changed.emit(layout.duplicate(true));queue_redraw();accept_event()
func _notification(what:int)->void:
 if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():dragging=-1
