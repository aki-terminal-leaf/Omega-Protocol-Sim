# SPDX-License-Identifier: MIT
extends RefCounted
## Original geometry/textures; reconstructed attachments, shader and envelopes.
## This module is NOT a generic/direct AVFX player.
const PACK="res://assets/official/p3/"
static var shader:Shader
static var scenes:Dictionary={}
static var textures:Dictionary={}
static func texture(name:String)->Texture2D:
 if textures.has(name):return textures[name]
 var path:=PACK+name+".png";var result:Texture2D
 if (not FileAccess.file_exists(path) or FileAccess.file_exists(path+".import")) and ResourceLoader.exists(path):result=load(path) as Texture2D
 elif FileAccess.file_exists(path):result=ImageTexture.create_from_image(Image.load_from_file(path))
 textures[name]=result;return result
static func material(name:String,strength:=0.3)->ShaderMaterial:
 if shader==null:
  shader=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D source_texture:source_color,repeat_enable;
uniform vec4 tint:source_color=vec4(0.22,0.60,1.0,1.0);
uniform float strength=0.3;
uniform float source_uv=1.0;
varying vec4 vertex_colour;
void vertex(){vertex_colour=COLOR;}
void fragment(){vec2 uv=UV+vec2(0.5)*source_uv;vec4 ink=texture(source_texture,uv);float mask=max(ink.r,max(ink.g,ink.b));ALBEDO=tint.rgb;ALPHA=clamp(mask*vertex_colour.a*strength,0.0,0.7);}
"""
 var result:=ShaderMaterial.new();result.shader=shader;result.set_shader_parameter("source_texture",texture(name));result.set_shader_parameter("strength",strength);return result
static func apply_material(root:Node3D,ink:ShaderMaterial)->void:
 if root is MeshInstance3D:root.material_override=ink
 for child in root.get_children():
  if child is Node3D:apply_material(child,ink)
static func original(name:String,ink:String,strength:float)->Node3D:
 var path:=PACK+name+".glb";var root:Node3D
 if (not FileAccess.file_exists(path) or FileAccess.file_exists(path+".import")) and ResourceLoader.exists(path):
  if not scenes.has(path):scenes[path]=load(path)
  if scenes[path] is PackedScene:root=scenes[path].instantiate()
 if root==null:
  var fallback:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=0.7;sphere.height=1.4;fallback.mesh=sphere;root=fallback;root.set_meta("original_geometry",false)
 else:root.set_meta("original_geometry",true)
 root.name=name;apply_material(root,material(ink,strength));return root
static func loading(side:=1)->Node3D:
 var root:=Node3D.new();root.name="ObservedMonitorLoading"
 var volume:=original("loading_left_volume" if side<0 else "loading_volume","circuit",0.8);volume.rotation.x=-PI/2;root.add_child(volume)
 var ring:=original("loading_left_ring" if side<0 else "loading_ring","glow",0.45);ring.rotation.x=-PI/2;root.add_child(ring)
 return root
static func pulse(origin:Vector2,target:Vector2,source_actor:int)->Node3D:
 var root:=Node3D.new();root.name="ObservedMonitorPulse";root.set_meta("origin",origin);root.set_meta("target",target);root.set_meta("source_actor",source_actor)
 var from:=Vector3(origin.x,3.0 if source_actor<0 else 1.4,origin.y);var to:=Vector3(target.x,1.0,target.y)
 var beam:=MeshInstance3D.new();beam.name="CannonElectricBeam";var cylinder:=CylinderMesh.new();cylinder.top_radius=0.11;cylinder.bottom_radius=0.24;cylinder.height=maxf(0.01,from.distance_to(to));cylinder.radial_segments=12;cylinder.cap_bottom=false;cylinder.cap_top=false;beam.mesh=cylinder;beam.position=(from+to)*0.5
 var up:Vector3=(to-from).normalized();var side:=up.cross(Vector3.FORWARD).normalized()
 if side.length_squared()<0.01:side=up.cross(Vector3.RIGHT).normalized()
 beam.basis=Basis(side,up,side.cross(up));var ink:=material("electric",0.55);ink.set_shader_parameter("source_uv",0.0);beam.material_override=ink;root.add_child(beam)
 var impact:=original("impact_ring","impact",0.4);impact.name="SourceImpactRing";impact.position=Vector3(target.x,0.06,target.y);root.add_child(impact)
 var halo:=original("impact_sphere","glow",0.14);halo.name="SourceImpactHalo";halo.position=Vector3(target.x,0.8,target.y);root.add_child(halo)
 return root
static func envelope(root:Node3D,age:float)->bool:
 if age>=0.85:return false
 var fade:=clampf(1.0-age/0.85,0,1)
 for child in root.get_children():
  if child.name=="SourceImpactRing":child.scale=Vector3.ONE*lerpf(0.8,7.0,clampf(age/0.5,0,1))
  elif child.name=="SourceImpactHalo":child.scale=Vector3.ONE*lerpf(0.5,1.8,clampf(age/0.4,0,1))
  fade_material(child,fade)
 return true
static func fade_material(root:Node3D,fade:float)->void:
 if root is MeshInstance3D and root.material_override is ShaderMaterial:root.material_override.set_shader_parameter("strength",fade*0.4)
 for child in root.get_children():
  if child is Node3D:fade_material(child,fade)
