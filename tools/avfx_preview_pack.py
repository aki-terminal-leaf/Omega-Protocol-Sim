#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Compile preserved AVFX bytes to a portable experimental playback document.

No game installation/.NET/plugin is required. Source remains embedded losslessly.
This is NOT a complete renderer/fidelity certification. Unsupported features are
reported individually; the gameplay renderer must not silently accept this pack.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
import math
try:
    from . import avfx_meshes as mesh, avfx_graph as graph, avfx_curves as curves
except ImportError:
    import avfx_meshes as mesh, avfx_graph as graph, avfx_curves as curves

SCALARS = {**curves.SCALARS, "Efct": set()}
AXES = {"Pos", "Rot", "Scl"}
COLOR = curves.COLOR_FIELDS
DATA_CURVES = {"Ang", "AngR", "WB", "WBR", "WE", "WER", "RB", "RBR", "RE", "RER", "HBI", "HBIR", "HEI", "HEIR", "HBO", "HBOR", "HEO", "HEOR", "FrC", "FrCR", "NoAn", "Moph", "AnX", "AnY", "AnZ", "AnXR", "AnYR", "AnZR", "IjS", "IjSR"}
DATA_COLORS = {"CEI", "CEO", "ColB", "ColE"}
FLOAT_FIELDS = {"Ptcl": {"NeSt", "NeEd", "FaSt", "FaEd", "DpOf"}, "Bind": {"bVSb"}}
MATERIALS = {"TC1", "TC2", "TC3", "TC4", "TN", "TR", "TD", "TP"}

def strip_raw(value):
    if isinstance(value, dict):
        return {k:strip_raw(v) for k,v in value.items()
                if k not in {"raw_payload_base64", "unsupported"}}
    if isinstance(value, list): return [strip_raw(v) for v in value]
    return value

def literal(payload):
    if len(payload) not in (1,2,4): raise ValueError("Unsupported literal width")
    return struct.unpack({1:"<B",2:"<h",4:"<i"}[len(payload)],payload)[0]

def color(payload):
    rows=mesh.blocks(payload)
    return {t:strip_raw(curves.decode_curve(v,"rgb" if t=="RGB" else "scalar",t in curves.RANDOM_FIELDS))
            for t,v in rows if t in COLOR}

def compile_pack(data):
    topology=graph.inspect(data)
    geometry=mesh.inspect(data)
    root=mesh.blocks(mesh.blocks(data)[0][1])
    result={"schema":1,"source_sha256":hashlib.sha256(data).hexdigest(),
            "raw_avfx_base64":base64.b64encode(data).decode(),
            "format_reference":mesh.REFERENCE,"time_units":"native AVFX numeric units",
            "rendering_complete":False,"gameplay_eligible":False,"compiler_revision":3,
            "execution_policy":"experimental deterministic preview; not game equivalence",
            "groups":{},"models":geometry["models"],"textures":geometry["textures"],
            "unsupported":[]}
    def issue(path,reason): result["unsupported"].append({"path":path,"reason":reason})
    # Source-defined 28-byte VEmt: float3 position, float3 normal, RGBA bytes.
    for model,payload in zip(result["models"],(v for t,v in root if t=="Modl")):
        fields=mesh.blocks(payload)
        raw=mesh.unique(fields,"VEmt",False) or b""
        model["emission_vertices"]=[]
        for position in range(0,len(raw),28):
            values=struct.unpack_from("<6f4B",raw,position)
            if not all(__import__("math").isfinite(x) for x in values[:6]):
                raise ValueError("Nonfinite emission vertex")
            model["emission_vertices"].append({"position":list(values[:3]),"normal":list(values[3:6]),"color":list(values[6:])})
        numbers=mesh.unique(fields,"VNum",False) or b""
        model["emission_order"]=[x[0] for x in struct.iter_unpack("<H",numbers)]
    by_id={(n["group"],n["source_index"]):n for n in topology["nodes"]}
    for group in ["Schd","TmLn","Emit","Ptcl","Bind","Efct"]:
        nodes=[]
        for index,payload in enumerate(v for t,v in root if t==group):
            path=f"{group}[{index}]"
            source=by_id[(group,index)]
            node={"index":index,"values":source.get("values",{}),
                  "items":[{"values":i["values"],"role":i["role"],"source_index":i["source_index"]}
                           for i in source.get("items",[])],
                  "clips":source.get("clips",[]),"curves":{},"axes":{},"materials":{},"uv_sets":[],"data":{}}
            fields=mesh.blocks(payload)
            if group=="Bind":
                # Preserve source bytes, including internal padding; no runtime semantics.
                binder_blocks=[]
                for tag,value in fields:
                    block={"tag":tag,"payload_base64":base64.b64encode(value).decode("ascii"),
                           "sha256":hashlib.sha256(value).hexdigest()}
                    if tag=="Data":
                        block["child_tags"]=[t for t,_ in mesh.blocks(value)]
                        issue(path+"/Data","binder_data_semantics_unverified")
                    binder_blocks.append(block)
                node["binder_source"]={"schema":1,"payload_base64":base64.b64encode(payload).decode("ascii"),
                                       "sha256":hashlib.sha256(payload).hexdigest(),"blocks":binder_blocks}
            for tag,value in fields:
                if tag in FLOAT_FIELDS.get(group,()):
                    if len(value)!=4: raise ValueError("Invalid float width: "+path+"/"+tag)
                    number=struct.unpack("<f",value)[0]
                    if not math.isfinite(number): raise ValueError("Nonfinite float: "+path+"/"+tag)
                    node["values"][tag]=number
                elif tag in SCALARS.get(group,()):
                    node["curves"][tag]=strip_raw(curves.decode_curve(value,"angle" if tag.startswith("IA") else "scalar"))
                elif tag in AXES and group in SCALARS:
                    node["axes"][tag]=strip_raw(curves.decode_axes(value,"angle" if tag=="Rot" else "scalar"))
                elif tag=="Col" and group in SCALARS:node["color"]=color(value)
                elif tag=="Life" and group=="Bind":node["values"][tag]=literal(value)
                elif tag=="Life" and group in SCALARS:node["life"]=strip_raw(curves.decode_life(value))
                elif tag=="UvSt" and group=="Ptcl":
                    uv={}
                    for t,v in mesh.blocks(value):
                        if t in {"Scl","Scr"}:uv[t]=strip_raw(curves.decode_axes(v))
                        elif t in {"Rot","RotR"}:uv[t]=strip_raw(curves.decode_curve(v,"angle"))
                        elif t=="CUvT":uv[t]=literal(v)
                        else:issue(path+"/UvSt/"+t,"uv_field")
                    node["uv_sets"].append(uv)
                elif tag in MATERIALS and group=="Ptcl":
                    material={}
                    for t,v in mesh.blocks(value):
                        if t=="TLst":material[t]=list(v)
                        elif t in {"TxN","TxNR"}:material[t]=strip_raw(curves.decode_curve(v))
                        elif len(v) in (1,2,4):material[t]=literal(v)
                        else:issue(path+"/"+tag+"/"+t,"material_field")
                    node["materials"][tag]=material
                elif tag=="Data" and group=="Efct":
                    for t,v in mesh.blocks(value):
                        if t in {"Pos","Rot"}:node["data"][t]=strip_raw(curves.decode_axes(v,"angle" if t=="Rot" else "scalar"))
                        elif t in {"Att","AttR","RdO","RdOR","RdI","RdIR"}:node["data"][t]=strip_raw(curves.decode_curve(v,"scalar",t.endswith("R")))
                        else:issue(path+"/Data/"+t,"effector_data")
                elif tag=="Data" and group in SCALARS:
                    for t,v in mesh.blocks(value):
                        if t=="FrRt":node["data"][t]=strip_raw(curves.decode_axes(v,"angle"))
                        elif t in DATA_CURVES:node["data"][t]=strip_raw(curves.decode_curve(v))
                        elif t in DATA_COLORS:node["data"][t]=color(v)
                        elif t in {"MdNo","MNO"}:
                            node["data"][t]=list(v) if group=="Ptcl" and t=="MdNo" else literal(v)
                        elif t=="PIFU" and node["values"].get("PrVT")==12:
                            if len(v)!=4: raise ValueError("Invalid disc interval float")
                            interval=struct.unpack("<f",v)[0]
                            if not math.isfinite(interval): raise ValueError("Nonfinite disc interval")
                            node["data"][t]=interval
                        elif len(v) in (1,2,4):node["data"][t]=literal(v)
                        else:issue(path+"/Data/"+t,"type_data")
                elif len(value) in (1,2,4) and tag not in {"Life"}:
                    node["values"][tag]=literal(value)
                elif tag not in {"Item","ItPr","ItEm","Clip","Col","Life","Data"}:
                    issue(path+"/"+tag,"unexecuted_field")
            if group=="Ptcl" and node["values"].get("PrVT") not in (1,2,5,8,12,13):issue(path,"particle_type")
            if group=="Emit" and node["values"].get("EVT") not in (0,5):issue(path,"emitter_type")
            if group in {"Bind","Efct"}:issue(path,"external_attachment" if group=="Bind" else "effector")
            if node["clips"]:issue(path,"timeline_clips")
            if group=="Ptcl":
                # The preview can display a base texture. Never certify the
                # omitted original lighting, distortion or layered shader.
                for tag,m in node["materials"].items():
                    if tag!="TC1" and m.get("bEna",0):issue(path+"/"+tag,"layered_material")
                if node["values"].get("bSCt",0):issue(path,"simple_animation")
            nodes.append(node)
        result["groups"][group]=nodes
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    a=p.parse_args()
    with a.input.open("rb") as f:data=f.read(mesh.MAX_BYTES+1)
    result=compile_pack(data)
    # Exclusive creation protects an existing source/previous proof file.
    with a.output.open("x",encoding="utf-8") as f:
        json.dump(result,f,ensure_ascii=False,separators=(",",":"),allow_nan=False)
    print(json.dumps({"source_sha256":result["source_sha256"],"unsupported":len(result["unsupported"]),"rendering_complete":False}))
if __name__=="__main__":main()
