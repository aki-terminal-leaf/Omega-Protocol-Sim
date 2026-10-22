# SPDX-License-Identifier: MIT
"""Synthetic format fixtures; no copied game data or network dependency."""
import base64
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import avfx_preview_pack as preview
from test_avfx_graph import block,number,document,emitter

def curve(value=2):
    return number("KeyC",1)+number("BvPr",0)+number("BvPo",0)+number("RanT",0)+block("Keys",struct.pack("<hHfff",0,1,1,1,value))
def particle(extra=b"",kind=8):
    return number("PrVT",kind)+number("RMT",2)+number("RBDT",10)+extra
class PreviewPackTests(unittest.TestCase):
    def test_source_roundtrip_unknown_root(self):
        source=document(("Emit",emitter()+number("EVT",0)),extra=block("ZZZ",b"opaque"))
        result=preview.compile_pack(source)
        self.assertEqual(base64.b64decode(result["raw_avfx_base64"]),source)
        self.assertFalse(result["rendering_complete"])
        self.assertFalse(result["gameplay_eligible"])
    def test_curve_unknown_metadata_is_not_removed(self):
        source=document(("Ptcl",particle(block("Pos",number("ACT",0)+number("ACTR",0)+block("X",curve()+number("ZZZ",99))))))
        result=preview.compile_pack(source)
        self.assertEqual(result["groups"]["Ptcl"][0]["axes"]["Pos"]["axes"]["X"]["unknown_fields"][0]["tag"],"ZZZ")
    def test_texture_byte_indices_are_not_int32(self):
        source=document(("Ptcl",particle(block("TC1",number("bEna",1)+block("TLst",bytes([0,1]))))),
                        ("Tex",b"vfx/a.atex\0"),("Tex",b"vfx/b.atex\0"))
        result=preview.compile_pack(source)
        self.assertEqual(result["groups"]["Ptcl"][0]["materials"]["TC1"]["TLst"],[0,1])
    def test_emission_vertices_not_draw_vertices(self):
        payload=block("VEmt",struct.pack("<6f4B",1,2,3,0,1,0,10,20,30,40))+block("VNum",struct.pack("<H",0))
        result=preview.compile_pack(document(("Modl",payload)))
        self.assertEqual(result["models"][0]["emission_vertices"][0]["position"],[1,2,3])
        self.assertEqual(result["models"][0]["emission_vertices"][0]["color"],[10,20,30,40])
        self.assertEqual(result["models"][0]["vertices"],[])
    def test_nonfinite_emission_vertex_rejected(self):
        payload=block("VEmt",struct.pack("<6f4B",float("nan"),2,3,0,1,0,0,0,0,0))+block("VNum",b"\0\0")
        with self.assertRaisesRegex(ValueError,"Nonfinite emission"):preview.compile_pack(document(("Modl",payload)))
    def test_unsupported_type_and_layer_are_explicit(self):
        source=document(("Ptcl",particle(block("TC2",number("bEna",1)),kind=6)))
        reasons={x["reason"] for x in preview.compile_pack(source)["unsupported"]}
        self.assertIn("particle_type",reasons);self.assertIn("layered_material",reasons)
    def test_malformed_structure_rejected(self):
        for source in [b"",document()[:-1],document().replace(number("Ver",preview.mesh.VERSION),number("Ver",99))]:
            with self.subTest(source=source),self.assertRaises(ValueError):preview.compile_pack(source)
    def test_cli_exclusive_output_keeps_previous_file(self):
        with tempfile.TemporaryDirectory() as temp:
            source=Path(temp)/"input.avfx";output=Path(temp)/"output.json"
            source.write_bytes(document());output.write_text("previous evidence")
            r=subprocess.run([sys.executable,preview.__file__,"--input",str(source),"--output",str(output)],capture_output=True,timeout=10)
            self.assertNotEqual(r.returncode,0);self.assertEqual(output.read_text(),"previous evidence")
if __name__=="__main__":unittest.main()
