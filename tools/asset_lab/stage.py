#!/usr/bin/env python3
"""Create a standalone Godot lab project. Does not modify the practice main scene."""
import argparse,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument("--out",type=Path,required=True);a=ap.parse_args()
if a.out.exists():raise SystemExit("Fresh staging output required")
a.out.mkdir(parents=True)
for directory,names in {
 "scripts":["asset_lab.gd","asset_lab_motion.gd","asset_lab_lifetime.gd","asset_lab_effect.gd","asset_lab_camera_effect.gd","asset_lab_composite.gd","asset_lab_unit.gd","source_avfx_player.gd","avfx_player.gd","avfx_animation.gd","avfx_color_stage.gd","avfx_mesh_stage.gd"],
 "scenes":["asset_lab.tscn"],"data/asset_lab":["catalog.json","performances.json"],"fonts":["NotoSansCJKtc-Regular.otf","CJK-OFL.txt"]}.items():
 for name in names:
  dst=a.out/directory/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/"top"/directory/name,dst)
(a.out/"project.godot").write_text('''config_version=5
[application]
config/name="TOP Asset Lab - Godot"
run/main_scene="res://scenes/asset_lab.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=1440
window/size/viewport_height=900
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0.04, 0.06, 0.11, 1)
''')
(a.out/"export_presets.cfg").write_text('''[preset.0]
name="Windows"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path=""
[preset.0.options]
binary_format/embed_pck=true
texture_format/bptc=false
texture_format/s3tc=true
[preset.1]
name="Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path=""
[preset.1.options]
binary_format/embed_pck=true
texture_format/bptc=false
texture_format/s3tc=true
''')
print(a.out)

