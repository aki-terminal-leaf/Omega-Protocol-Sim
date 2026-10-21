# SPDX-License-Identifier: MIT
extends RefCounted
## Compatibility-renderer boundary visualization. No collision blocks entry.
## Standalone practice starts at an already-active boundary, not P6 cutscene T0.
const RADIUS:=20.0
static func create(phase:int)->Node3D:
	var root:=Node3D.new();root.name="DeathWall";root.set_meta("radius",RADIUS);root.set_meta("phase",phase);root.set_meta("original_avfx",false)
	var mesh:=CylinderMesh.new();mesh.top_radius=RADIUS;mesh.bottom_radius=RADIUS;mesh.height=3.4;mesh.radial_segments=192;mesh.cap_top=false;mesh.cap_bottom=false
	var node:=MeshInstance3D.new();node.name="LethalBoundary";node.mesh=mesh;node.position.y=1.7;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 wall_colour:source_color = vec4(0.15,0.55,1.0,1.0);
varying float height_fraction;
void vertex(){height_fraction=(VERTEX.y+1.7)/3.4;}
void fragment(){
 float fade=pow(1.0-clamp(height_fraction,0.0,1.0),1.8);
 float grid=pow(abs(sin(UV.x*603.185+sin(UV.y*12.0+TIME*1.1)*0.4)),24.0);
 float pulse=0.55+0.45*sin(UV.y*48.0-TIME*3.2+UV.x*60.0);
 float base=exp(-height_fraction*32.0);
 ALBEDO=wall_colour.rgb;
 ALPHA=clamp(fade*(0.11+grid*0.30+pulse*0.07)+base*0.7,0.0,0.8);
}
"""
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("wall_colour",Color("ffc26b") if phase==6 else Color("668ee9"));node.material_override=material;root.add_child(node)
	return root
