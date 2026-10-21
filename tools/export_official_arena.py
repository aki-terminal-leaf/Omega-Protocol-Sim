#!/usr/bin/env python3
"""Export local TOP BG models, textures and original LGB placements (read-only)."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import export_official_models as models

LAYOUT = "bg/ex2/05_zon_z3/ome/z3oz/level/bg.lgb"

def export(args):
    realm = models.initialize(args)
    try:
        from Lumina.Data.Files import LgbFile
        from Lumina.Data import FileResource
        import hashlib
        layout = realm.GetFile[LgbFile](LAYOUT)
        if layout is None: raise RuntimeError("Missing original TOP scene layout")
        placements = []
        for layer in layout.Layers:
            name = str(layer.Name)
            if name.startswith("cut_") or name == "env_location_": continue
            for obj in layer.InstanceObjects:
                if str(obj.AssetType) != "BG": continue
                data = obj.Object
                field = data.GetType().GetField("AssetPath") if data else None
                if not field: continue
                tr = obj.Transform
                vector = lambda v: [float(v.X), float(v.Y), float(v.Z)]
                placements.append(dict(layer=name, path=str(field.GetValue(data)),
                    translation=vector(tr.Translation), rotation=vector(tr.Rotation), scale=vector(tr.Scale)))
        if not placements: raise RuntimeError("Scene layout contains no background placements")
        raw = realm.GetFile[FileResource](LAYOUT)
        manifest = dict(format=1, provenance="original local-game BG meshes/textures and LGB placements",
            source_layout=LAYOUT, source_sha256=hashlib.sha256(bytes(raw.Data)).hexdigest(),
            models={}, placements=placements,
            limitations=["Static phase layouts; original BG shader, lighting, fog and transitions are approximated"])
        for path in sorted(set(p["path"] for p in placements)):
            name = Path(path).stem
            if name in manifest["models"]: raise ValueError("Ambiguous BG basename: " + name)
            manifest["models"][name] = models.export_model(realm,args,name,{"source_path":path})
            print(name, manifest["models"][name]["bytes"], flush=True)
        (args.output / "manifest.json").write_text(json.dumps(manifest,indent=2) + "\n")
    finally:
        realm.Dispose()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["game-dir","lumina-dir","textools-dir","output"]:
        parser.add_argument("--"+name,type=Path,required=True)
    parser.add_argument("--pythonnet-dir",type=Path)
    parser.add_argument("--max-texture-size",type=int,default=1024)
    args = parser.parse_args()
    if args.max_texture_size < 1: parser.error("Texture limit must be positive")
    args.rig_dir = None; args.bake_colorset = False
    export(args)

if __name__ == "__main__": main()
