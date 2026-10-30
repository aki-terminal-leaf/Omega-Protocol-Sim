extends Node3D
const Action = preload("res://scripts/original_ring_action.gd")
var action: Node3D
var button: Button
var status: Label
func _ready() -> void:
 action = Action.new()
 add_child(action)
 var camera := Camera3D.new()
 add_child(camera)
 camera.position = Vector3(0, 22, 28)
 camera.look_at(Vector3.ZERO)
 camera.current = true
 camera.near = 0.05
 camera.far = 200
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color(0.018,0.022,0.035)
 add_child(environment)
 var canvas := CanvasLayer.new()
 add_child(canvas)
 var panel := VBoxContainer.new()
 panel.position = Vector2(24,24)
 canvas.add_child(panel)
 var title := Label.new()
 title.text = "Wave Repeater ? center explosion"
 panel.add_child(title)
 status = Label.new()
 panel.add_child(status)
 button = Button.new()
 button.text = "Play"
 button.pressed.connect(toggle_play)
 panel.add_child(button)
 button.disabled = not action.configure()
 if not button.disabled:
  # Fit the camera to actual transformed source meshes over the entire supported tail.
  # This changes only the view, never the source geometry or root scale.
  var bounds := AABB()
  var first := true
  for frame in range(int(action.end_frame)+1):
   action.seek(float(frame))
   for mesh in action.effect.draws.values():
    var box: AABB = mesh.global_transform * mesh.get_aabb()
    bounds = box if first else bounds.merge(box)
    first = false
  if not first:
   var center := bounds.get_center()
   var radius := maxf(bounds.size.length()*0.5, 0.1)
   camera.position = center + Vector3(0,0.55,1).normalized()*radius*2.5
   camera.far = radius*6.0
   camera.look_at(center)
  action.seek(0.0)
  action.pause()
 _refresh()
func toggle_play() -> void:
 if action.playing: action.pause()
 else: action.play()
 _refresh()
func _process(_delta: float) -> void: _refresh()
func _refresh() -> void:
 if action == null or status == null: return
 button.text = "Pause" if action.playing else "Play"
 status.text = "Source preview ? incomplete material and attachment behavior\nInspection window ? timing conditional ? %.2f / %.2f s" % [action.age/30.0,action.end_frame/30.0]
 if not action.error.is_empty(): status.text = action.error
