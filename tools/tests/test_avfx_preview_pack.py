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
    def test_source_float_parameters_are_not_integer_bit_patterns(self):
        source=document(("Ptcl",particle(block("DpOf",struct.pack("<f",0.125))+block("NeEd",struct.pack("<f",1.0)))))
        values=preview.compile_pack(source)["groups"]["Ptcl"][0]["values"]
        self.assertEqual(values["DpOf"],0.125)
        self.assertEqual(values["NeEd"],1.0)
        with self.assertRaisesRegex(ValueError,"Nonfinite float"):
            preview.compile_pack(document(("Ptcl",particle(block("DpOf",struct.pack("<f",float("inf")))))))

    def test_radial_type_presence_and_widths(self):
        payload=block("Len",curve(.15))+block("Str",curve(1))+block("FSDc",struct.pack("<f",50))+number("FaBP",2)
        data,unknown=preview.decode_effector_data(payload,7)
        self.assertEqual(data["FSDc"],50);self.assertEqual(data["FaBP"],2)
        self.assertFalse(data["presence"]["IRad"]);self.assertNotIn("IRad",data)
        self.assertEqual(unknown,[])
        for kind in [9,123]:
            wrong,unknown=preview.decode_effector_data(payload,kind)
            self.assertNotIn("Len",wrong);self.assertEqual(len(unknown),4)
    def test_radial_malformed_nonfinite_duplicate_unknown_random(self):
        cases=[block("FSDc",b"x"),block("FaBP",b"xx"),block("Len",b"x"),block("Str",curve(float("nan"))),block("FEDc",struct.pack("<f",float("inf"))),number("FaBP",0)+number("FaBP",1),block("Len",curve())+block("Len",curve())]
        for payload in cases:
            with self.subTest(payload=payload),self.assertRaises(ValueError): preview.decode_effector_data(payload,7)
        data,unknown=preview.decode_effector_data(block("LenR",curve())+number("ZZZ",3),7)
        self.assertEqual(data["random_fields"],["LenR"]);self.assertEqual(len(unknown),2)
        data,_=preview.decode_effector_data(block("Len",curve()+number("ZZZ",1)),7)
        self.assertEqual(data["Len"]["unknown_fields"][0]["tag"],"ZZZ")
    def test_effector_compiler_discriminates_and_rejects_duplicate_type(self):
        for kind in [7,9,123]:
            source=document(("Efct",number("EfVT",kind)+block("Data",block("Len",curve()))))
            data=preview.compile_pack(source)["groups"]["Efct"][0]["data"]
            self.assertEqual("Len" in data,kind==7)
        source=document(("Efct",number("EfVT",7)+number("EfVT",9)+block("Data",b"")))
        with self.assertRaises(ValueError):preview.compile_pack(source)
    def test_type9_camera_data_preserved(self):
        data,unknown=preview.decode_effector_data(block("Att",curve(1))+block("RdI",curve(5)),9)
        self.assertEqual(data["Att"]["keys"][0]["value"],1);self.assertEqual(unknown,[])

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
