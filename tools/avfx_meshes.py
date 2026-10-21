#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Extract ORIGINAL embedded AVFX mesh data; not a particle-graph renderer.

Format reference: MIT Dalamud-VFXEditor, commit
05f6eb0cce19a6a91ae275bce609299d573914b3, AvfxModel/AvfxVertexes/AvfxIndexes.
No plugin, game process, Rust toolchain or game assets are bundled/required.
Unknown graph payloads remain opaque and losslessly retained in graph.json.
"""
from __future__ import annotations
import argparse
import base64
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

MAX_BYTES = 16 * 1024 * 1024
VERSION = 0x20110913
COUNTS = {"ScCn": "Schd", "TlCn": "TmLn", "EmCn": "Emit",
          "PrCn": "Ptcl", "EfCn": "Efct", "BdCn": "Bind",
          "TxCn": "Tex", "MdCn": "Modl"}
REFERENCE = "https://github.com/0ceal0t/Dalamud-VFXEditor/tree/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat"


def blocks(data: bytes):
    """Strict little-endian, 4-byte-aligned tagged blocks (no guessed recursion)."""
    if len(data) > MAX_BYTES:
        raise ValueError("AVFX exceeds supported size budget")
    result = []
    offset = 0
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError("Truncated AVFX block header")
        raw_name, size = struct.unpack_from("<4sI", data, offset)
        name_bytes = raw_name.rstrip(b"\0")
        if not name_bytes or any(not (32 <= c < 127) for c in name_bytes) or b"\0" in name_bytes:
            raise ValueError("Invalid AVFX tag")
        name = name_bytes[::-1].decode("ascii")
        start = offset + 8
        end = start + size
        aligned = end + (-size % 4)
        if aligned > len(data):
            raise ValueError(f"Truncated {name} payload/padding")
        result.append((name, data[start:end]))
        offset = aligned
    return result


def unique(rows, name, required=True):
    matches = [value for tag, value in rows if tag == name]
    if len(matches) != 1:
        if not matches and not required:
            return None
        raise ValueError(f"Expected one {name} block, found {len(matches)}")
    return matches[0]


def integer(rows, name):
    value = unique(rows, name)
    if len(value) != 4:
        raise ValueError(f"Invalid scalar size for {name}")
    return struct.unpack("<I", value)[0]


def mesh(payload):
    fields = blocks(payload)
    raw_vertices = unique(fields, "VDrw", False) or b""
    raw_indices = unique(fields, "VIdx", False) or b""
    if len(raw_vertices) % 36 or len(raw_indices) % 6:
        raise ValueError("Misaligned AVFX vertex or triangle buffer")
    vertices = []
    for offset in range(0, len(raw_vertices), 36):
        position = list(struct.unpack_from("<4e", raw_vertices, offset))
        normal = [x - 128 for x in raw_vertices[offset + 8:offset + 12]]
        tangent = [x - 128 for x in raw_vertices[offset + 12:offset + 16]]
        color = list(raw_vertices[offset + 16:offset + 20])
        uv = [list(struct.unpack_from("<2e", raw_vertices, offset + 20 + i * 4)) for i in range(4)]
        if not all(math.isfinite(x) for x in position + [x for pair in uv for x in pair]):
            raise ValueError("Non-finite AVFX vertex/UV")
        vertices.append({"position": position, "normal_packed": normal,
                         "tangent_packed": tangent, "color": color, "uv": uv})
    triangles = [list(row) for row in struct.iter_unpack("<3H", raw_indices)]
    if any(i >= len(vertices) for row in triangles for i in row):
        raise ValueError("AVFX triangle index outside vertex buffer")
    emit = unique(fields, "VEmt", False) or b""
    numbers = unique(fields, "VNum", False) or b""
    if len(emit) % 28 or len(numbers) % 2 or len(emit) // 28 != len(numbers) // 2:
        raise ValueError("Mismatched AVFX emission vertex buffers")
    return {"vertices": vertices, "triangles": triangles,
            "emit_vertex_count": len(emit) // 28,
            "source_payload_sha256": hashlib.sha256(payload).hexdigest()}


def inspect(data: bytes):
    roots = blocks(data)
    if len(roots) != 1 or roots[0][0] != "AVFX":
        raise ValueError("Expected exactly one AVFX root")
    rows = blocks(roots[0][1])
    version = integer(rows, "Ver")
    if version != VERSION:
        raise ValueError(f"Unsupported AVFX version {version:#x}")
    counts = Counter(tag for tag, _ in rows)
    for counter, tag in COUNTS.items():
        if integer(rows, counter) != counts[tag]:
            raise ValueError(f"AVFX {counter}/{tag} count mismatch")
    models = [mesh(value) for tag, value in rows if tag == "Modl"]
    textures = []
    for tag, value in rows:
        if tag == "Tex":
            if not value.endswith(b"\0") or b"\0" in value[:-1]:
                raise ValueError("Invalid AVFX texture string")
            textures.append(value[:-1].decode("ascii"))
    particles = []
    for tag, value in rows:
        if tag != "Ptcl":
            continue
        fields = blocks(value)
        record = {"type": integer(fields, "PrVT"), "draw_mode": integer(fields, "RMT"),
                  "rotation_base": integer(fields, "RBDT")}
        if record["type"] == 5:
            fields_data = blocks(unique(fields, "Data"))
            indices = unique(fields_data, "MdNo", False) or b""
            # AvfxIntList is a BYTE list despite its name (not int32).
            record["model_indices"] = list(indices)
            if any(i >= len(models) and i != 255 for i in record["model_indices"]):
                raise ValueError("Particle model reference outside model list")
        particles.append(record)
    return {"schema": 1, "version": version, "source_sha256": hashlib.sha256(data).hexdigest(),
            "format_reference": REFERENCE, "rendering_complete": False,
            "scope": "Original embedded geometry only; no scheduler/emission/curve/material playback",
            "counts": {tag: counts[tag] for tag in COUNTS.values()},
            "textures": textures, "particles": particles, "models": models,
            "raw_avfx_base64": base64.b64encode(data).decode("ascii")}


def export_glb(model, path):
    # Reuse the existing original-model glTF writer, not another format library.
    from export_official_models import GLB
    glb = GLB()
    verts = model["vertices"]
    attributes = {"POSITION": glb.accessor([v["position"][:3] for v in verts], 3, bounds=True),
                  "COLOR_0": glb.accessor([[x / 255.0 for x in v["color"]] for v in verts], 4)}
    for uv_index in range(4):
        attributes[f"TEXCOORD_{uv_index}"] = glb.accessor([v["uv"][uv_index] for v in verts], 2)
    normals = [v["normal_packed"][:3] for v in verts]
    if all(sum(x*x for x in n) > 0 for n in normals):
        attributes["NORMAL"] = glb.accessor([[x / math.sqrt(sum(y*y for y in n)) for x in n] for n in normals], 3)
    primitive = {"attributes": attributes, "indices": glb.accessor([i for t in model["triangles"] for i in t], 1, "I", 34963)}
    glb.doc["meshes"].append({"primitives": [primitive]})
    glb.doc["nodes"].append({"mesh": 0, "name": path.stem})
    glb.doc["scenes"][0]["nodes"].append(0)
    glb.doc["asset"]["extras"] = {"scope": "unmaterialed source-local mesh; not a rendered AVFX",
                                  "source_payload_sha256": model["source_payload_sha256"],
                                  "coordinate_policy": "source XYZ and index winding retained; no world-placement claim",
                                  "precision": "All packed data, position W and four UV sets preserved in graph.json"}
    glb.save(path)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path, help="New directory; existing output is never overwritten")
    a = p.parse_args()
    if a.input.stat().st_size > MAX_BYTES:
        p.error("Input exceeds size budget")
    graph = inspect(a.input.read_bytes())
    a.output.mkdir(parents=True, exist_ok=False)
    for i, model in enumerate(graph["models"]):
        if model["vertices"] and model["triangles"]:
            target = a.output / f"model_{i:03}.glb"
            export_glb(model, target)
            model["glb"] = target.name
            model["glb_sha256"] = hashlib.sha256(target.read_bytes()).hexdigest()
    (a.output / "graph.json").write_text(json.dumps(graph, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"models": len(graph["models"]), "particles": len(graph["particles"]),
                      "glbs": sum("glb" in m for m in graph["models"]), "rendering_complete": False}))


if __name__ == "__main__":
    main()
