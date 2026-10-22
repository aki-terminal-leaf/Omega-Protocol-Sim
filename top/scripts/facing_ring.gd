# SPDX-License-Identifier: MIT
extends RefCounted
## Game-style target-ring design: front notch, 270-degree arc, open rear90.
## Display only; collision/attack sizes remain entirely in Rules/runtime.
static func direction(degrees:float)->Vector3:
 var angle:=deg_to_rad(degrees);return Vector3(sin(angle),0,-cos(angle))
static func create(radius:float,colour:Color)->MeshInstance3D:
 var node:=MeshInstance3D.new();node.name="FacingRing"
 node.set_meta("front",Vector3.FORWARD);node.set_meta("rear_gap_degrees",90.0);node.set_meta("display_radius",radius)
 var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var width:=clampf(radius*0.035,0.025,0.16)
 for i in 90:
  var a:=225.0+3.0*i;var b:=a+3.0
  var inner_a:=direction(a)*(radius-width);var outer_a:=direction(a)*radius;var inner_b:=direction(b)*(radius-width);var outer_b:=direction(b)*radius
  for vertex in [inner_a,outer_a,outer_b,inner_a,outer_b,inner_b]:mesh.surface_add_vertex(vertex+Vector3.UP*0.045)
 # Forward arrow is attached to the same transform as the ring/model heading.
 var arrow_width:=minf(radius*0.16,0.75)
 var arrow_base:=radius+minf(radius*0.05,0.12)
 var arrow_tip:=radius+minf(radius*0.28,0.7)
 for vertex in [Vector3(-arrow_width,0.045,-arrow_base),Vector3(arrow_width,0.045,-arrow_base),Vector3(0,0.045,-arrow_tip)]:mesh.surface_add_vertex(vertex)
 mesh.surface_end();node.mesh=mesh
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.albedo_color=colour;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return node
static func tint(node:Node3D,colour:Color)->void:
 if node is MeshInstance3D and node.material_override is StandardMaterial3D:node.material_override.albedo_color=colour
