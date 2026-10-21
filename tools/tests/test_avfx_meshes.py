# SPDX-License-Identifier: MIT
import base64
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import avfx_meshes as av


def block(tag, payload):
    return tag[::-1].encode("ascii").ljust(4, b"\0") + struct.pack("<I", len(payload)) + payload + b"\0" * (-len(payload) % 4)


def number(tag, value):
    return block(tag, struct.pack("<I", value))


def vertex(x=0, y=0, z=0):
    return (struct.pack("<4e", x, y, z, 1) + bytes([128, 255, 128, 128]) +
            bytes([255, 128, 128, 255]) + bytes([255, 120, 0, 64]) + struct.pack("<8e", 0, 1, 2, 3, 4, 5, 6, 7))


def model(vertices=None, triangle=None, extra=b""):
    vertices = vertex() + vertex(1) + vertex(0, 1) if vertices is None else vertices
    triangle = struct.pack("<3H", 0, 1, 2) if triangle is None else triangle
    return block("Modl", block("VDrw", vertices) + block("VIdx", triangle) + extra)


def source(models=None, particle=None, extra=b"", version=av.VERSION):
    models = [model()] if models is None else models
    particle = (number("PrVT", 5) + number("RMT", 2) + number("RBDT", 2) +
                block("Data", block("MdNo", b"\0"))) if particle is None else particle
    data = number("Ver", version)
    counts = {tag: 0 for tag in av.COUNTS.values()}
    counts["Modl"] = len(models); counts["Ptcl"] = 1
    for counter, tag in av.COUNTS.items():
        data += number(counter, counts[tag])
    return block("AVFX", data + b"".join(models) + block("Ptcl", particle) + extra)


class OriginalAvfxMeshTests(unittest.TestCase):
    def test_original_half_vertex_and_byte_model_reference(self):
        raw = source()
        graph = av.inspect(raw)
        self.assertEqual(base64.b64decode(graph["raw_avfx_base64"]), raw)
        self.assertFalse(graph["rendering_complete"])
        self.assertEqual(graph["particles"][0]["model_indices"], [0])
        v = graph["models"][0]["vertices"][1]
        self.assertEqual(v["position"], [1, 0, 0, 1])
        self.assertEqual(v["normal_packed"], [0, 127, 0, 0])
        self.assertEqual(v["tangent_packed"], [127, 0, 0, 127])
        self.assertEqual(v["color"], [255, 120, 0, 64])
        self.assertEqual(v["uv"], [[0, 1], [2, 3], [4, 5], [6, 7]])
        self.assertEqual(graph["models"][0]["triangles"], [[0, 1, 2]])

    def test_real_uint16_indices_over_signed_short_limit(self):
        m = av.mesh(block("VDrw", vertex() * 32769) + block("VIdx", struct.pack("<3H", 0, 1, 32768)))
        self.assertEqual(m["triangles"][0][-1], 32768)

    def test_emitter_only_model_is_not_invented_geometry(self):
        m = block("Modl", block("VNum", b"\0\0") + block("VEmt", b"\0" * 28))
        graph = av.inspect(source(models=[m]))
        self.assertEqual(graph["models"][0]["vertices"], [])
        self.assertEqual(graph["models"][0]["emit_vertex_count"], 1)

    def test_unknown_graph_payload_preserved_not_recursively_guessed(self):
        raw = source(extra=block("ZZ", b"not a graph\0\xff"))
        self.assertEqual(base64.b64decode(av.inspect(raw)["raw_avfx_base64"]), raw)

    def test_reject_corrupt_headers_padding_and_duplicate_root(self):
        raw = source()
        for bad in [raw[:7], raw[:-1], raw + raw, raw + b"x", b"AB\0C" + raw[4:], block("NOPE", raw)]:
            with self.subTest(bad=bad[:8]):
                with self.assertRaises(ValueError): av.inspect(bad)

    def test_reject_count_and_version_mismatches(self):
        for raw in [source(version=99), source(extra=number("MdCn", 1)),
                    source().replace(number("MdCn", 1), number("MdCn", 2))]:
            with self.assertRaises(ValueError): av.inspect(raw)

    def test_reject_nonfinite_vertex_uv(self):
        for off in [0, 20]:
            bad = bytearray(vertex() * 3); bad[off:off + 2] = struct.pack("<e", float("inf"))
            with self.assertRaises(ValueError): av.inspect(source(models=[model(vertices=bytes(bad))]))

    def test_reject_stride_indices_emit_count_and_duplicate_vertex(self):
        for m in [model(vertices=vertex() + b"x"), model(triangle=b"x"),
                  model(triangle=struct.pack("<3H", 0, 1, 3)),
                  model(extra=block("VNum", b"\0\0")),
                  model(extra=block("VDrw", vertex()))]:
            with self.assertRaises(ValueError): av.inspect(source(models=[m]))

    def test_reject_model_reference_outside_list(self):
        p = number("PrVT", 5) + number("RMT", 2) + number("RBDT", 2) + block("Data", block("MdNo", b"\1"))
        with self.assertRaises(ValueError): av.inspect(source(particle=p))

    def test_glb_source_positions_uvs_and_triangle_data(self):
        m = av.inspect(source())["models"][0]
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp)/"model.glb"; av.export_glb(m, p); raw = p.read_bytes()
        self.assertEqual(struct.unpack_from("<III", raw), (0x46546C67, 2, len(raw)))
        n = struct.unpack_from("<I", raw, 12)[0]
        doc = json.loads(raw[20:20+n])
        binary = raw[20+n+8:]
        primitive = doc["meshes"][0]["primitives"][0]
        def values(accessor, code):
            v = doc["bufferViews"][doc["accessors"][accessor]["bufferView"]]
            return struct.unpack("<" + code, binary[v["byteOffset"]:v["byteOffset"]+v["byteLength"]])
        self.assertEqual(values(primitive["attributes"]["POSITION"], "9f"), (0, 0, 0, 1, 0, 0, 0, 1, 0))
        self.assertEqual(values(primitive["indices"], "3I"), (0, 1, 2))
        self.assertEqual(values(primitive["attributes"]["TEXCOORD_3"], "6f"), (6, 7, 6, 7, 6, 7))
        self.assertIn("not a rendered AVFX", doc["asset"]["extras"]["scope"])


if __name__ == "__main__": unittest.main()
