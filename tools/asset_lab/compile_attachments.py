#!/usr/bin/env python3
"""Merge private original EID tables with original reference skeletons, preserving sources."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--eid',type=Path,required=True);p.add_argument('--skeleton-manifest',type=Path,required=True);p.add_argument('--references',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
if a.out.exists():raise SystemExit('Fresh output required')
d=json.loads(a.eid.read_text());manifest=json.loads(a.skeleton_manifest.read_text())
for source in manifest['files']:
 if not source.get('exists'):continue
 family=Path(source['file']).stem
 if family not in d['families']:continue
 reference=json.loads((a.references/(family+'.reference.json')).read_text());bones=reference['bones'];assert 0<len(bones)<1024
 for i,bone in enumerate(bones):assert -1<=bone['parent']<i
 d['families'][family]['reference_skeleton']={'bones':bones,'source_path':source['path'],'source_sha256':source['sha256'],'reader':'existing Godbert hkAnimationInterop 32-bit reference pose API; no GUI','pose_policy':'original skeleton reference pose; recorded player race/action pose unknown'}
a.out.write_text(json.dumps(d,indent=2))
