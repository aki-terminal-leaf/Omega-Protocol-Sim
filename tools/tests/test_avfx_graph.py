# SPDX-License-Identifier: MIT
"""Original synthetic fixtures only; no game data or network access."""
import base64
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import avfx_graph as graph


def block(tag, value, pad=b"\0"):
    return tag[::-1].encode().ljust(4, b"\0") + struct.pack("<I", len(value)) + value + pad * (-len(value) % 4)


def number(tag, value):
    return block(tag, struct.pack("<i", value))


def document(*nodes, extra=b""):
    counts = Counter(tag for tag, _ in nodes)
    return block("AVFX", number("Ver", graph.VERSION) + b"".join(
        number(counter, counts[tag]) for counter, tag in graph.COUNTS.items()) +
        extra + b"".join(block(tag, value) for tag, value in nodes))


def sched_item(index=0):
    return number("bEna", 1) + number("StTm", -7) + number("TlNo", index)


def timeline_item(emitter=None, clip=None, extras=b""):
    return (number("bEna", 1) + number("StTm", -4) + number("EdTm", 23) +
            (b"" if emitter is None else number("EmNo", emitter)) +
            (b"" if clip is None else number("ClNo", clip)) + extras)


def emitter_item(target=0, size=312):
    # All 26 source fields occupy 12 bytes. Tail omission models older variants.
    tags = "bEnb TgtB LoDr CrTm CrCn CrPr PICd PICo ICbS ICbR ICbP ICbB ICSK IPbV IPbL bOvr OvrV OvrR PrLk StFr bStN BIAX BIAY BIAZ GenD bGD".split()
    return b"".join(number(tag, target if tag == "TgtB" else -1 if tag == "PrLk" else 0)
                    for tag in tags[:size // 12])


def emitter(particles=(), children=(), cumulative=True):
    output = number("PrCn", len(particles)) + number("EmCn", len(children))
    for i in range(len(particles)):
        output += block("ItPr", b"".join(particles[:i + 1] if cumulative else particles[i:i + 1]))
    for i in range(len(children)):
        output += block("ItEm", b"".join(list(particles) + list(children[:i + 1])))
    return output


class TopologyTests(unittest.TestCase):
    def test_cumulative_emitter_dedup_and_particle_prefix(self):
        data = document(("Emit", emitter([emitter_item(0), emitter_item(1)], [emitter_item(0)])),
                        ("Ptcl", b""), ("Ptcl", b""))
        result = graph.inspect(data)
        self.assertEqual(result["summary"]["edge_roles"], {"child_emitter": 1, "child_particle": 2})
        items = result["nodes"][0]["items"]
        self.assertEqual([i["source_index"] for i in items], [0, 1, 2])
        self.assertEqual([i["selected_index"] for i in items], [0, 1, 0])
        self.assertEqual(result["nodes"][0]["containers"][0]["container_count"], 2)
        self.assertFalse(result["execution_implemented"])

    def test_noncumulative_count_is_corrupt(self):
        with self.assertRaisesRegex(ValueError, "PrCn"):
            graph.inspect(document(("Emit", emitter([emitter_item(), emitter_item()], cumulative=False)), ("Ptcl", b"")))

    def test_timeline_last_and_source_emitters(self):
        a, b = timeline_item(0), timeline_item(1)
        timeline = number("TICn", 2) + number("CpCn", 0) + block("Item", a) + block("Item", a + b)
        result = graph.inspect(document(("TmLn", timeline), ("Emit", emitter()), ("Emit", emitter())))
        self.assertEqual([e["index"] for e in result["edges"]], [0, 1])
        self.assertTrue(all(e["role"] == "source_emitter" for e in result["edges"]))
        with self.assertRaisesRegex(ValueError, "TICn"):
            graph.inspect(document(("TmLn", timeline.replace(block("Item", a + b), block("Item", b)))))

    def test_scheduler_final_items_and_last_twelve_triggers(self):
        first = sched_item()
        triggers = sched_item(-1) * 11 + sched_item(0)
        scheduler = number("ItCn", 2) + number("TrCn", 12) + block("Item", first) + block("Item", first * 2)
        scheduler += block("Trgr", first * 2 + triggers[:36]) + block("Trgr", first * 2 + triggers)
        result = graph.inspect(document(("Schd", scheduler), ("TmLn", number("TICn", 0) + number("CpCn", 0))))
        self.assertEqual(result["summary"]["edge_roles"], {"scheduled_timeline": 2, "trigger_timeline": 1})
        self.assertEqual(len(result["nodes"][0]["items"]), 14)
        self.assertEqual(result["nodes"][0]["items"][-1]["source_index"], 13)
        with self.assertRaisesRegex(ValueError, "12 trailing"):
            graph.inspect(document(("Schd", number("ItCn", 0) + number("TrCn", 1) + block("Trgr", first))))

    def test_typed_signed_reference_boundaries(self):
        for index in (-2, 1, 255):
            with self.subTest(index=index), self.assertRaisesRegex(ValueError, "outside Ptcl"):
                graph.inspect(document(("Emit", emitter([emitter_item(index)])), ("Emit", emitter()), ("Ptcl", b"")))
        result = graph.inspect(document(("Emit", emitter([emitter_item(-1)]))))
        self.assertEqual(result["edges"], [])
        self.assertEqual(next(r for r in result["references"] if r["field"] == "TgtB")["state"], "sentinel")
        with self.assertRaisesRegex(ValueError, "outside Emit"):
            graph.inspect(document(("Emit", emitter(children=[emitter_item(1)])), ("Ptcl", b""), ("Ptcl", b"")))

    def test_observed_clip_negative_binder_scope_is_opaque_not_array_index(self):
        clip=block("Clip",struct.pack("<5i4f",0x4B494C4C,0,0,0,0,0,0,0,0)+bytes(128))
        timeline=number("TICn",1)+number("CpCn",1)+clip+block("Item",timeline_item(-1,0,number("BdNo",-2)))
        result=graph.inspect(document(("TmLn",timeline)))
        ref=next(x for x in result["references"] if x["field"]=="BdNo")
        self.assertEqual(ref["state"],"opaque_scope")
        self.assertIn("unresolved_negative_binder_scope",{x["reason"] for x in result["unsupported"]})
        self.assertEqual(result["nodes"][0]["clips"][0]["type"],0x4B494C4C)
        # The exception must not loosen ordinary signed array references.
        bad=number("TICn",1)+number("CpCn",0)+block("Item",timeline_item(-1,None,number("BdNo",-2)))
        with self.assertRaisesRegex(ValueError,"outside Bind"):
            graph.inspect(document(("TmLn",bad)))

    def test_model_byte_list_and_unsigned_sentinel(self):
        particle = number("PrVT", 5) + block("Data", block("MdNo", bytes([0, 255, 0, 255])))
        result = graph.inspect(document(("Ptcl", particle), ("Modl", b"opaque")))
        self.assertEqual([r["index"] for r in result["references"]], [0, 255, 0, 255])
        self.assertEqual(len(result["edges"]), 2)
        for value in (1, 254):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "outside Modl"):
                graph.inspect(document(("Ptcl", number("PrVT", 5) + block("Data", block("MdNo", bytes([value])))), ("Modl", b"")))

    def test_emitter_model_index_is_signed_scalar_not_byte_list(self):
        for value in (-1, 0):
            result = graph.inspect(document(("Emit", emitter() + number("EVT", 5) + block("Data", number("MdNo", value))), ("Modl", b"")))
            ref = next(r for r in result["references"] if r["field"] == "MdNo")
            self.assertEqual(ref["index"], value)
            self.assertEqual(ref["state"], "sentinel" if value == -1 else "linked")
        for value in (-2, 1, 255):
            with self.subTest(value=value), self.assertRaises(ValueError):
                graph.inspect(document(("Emit", emitter() + number("EVT", 5) + block("Data", number("MdNo", value))), ("Modl", b"")))

    def test_selected_container_only_no_validation_of_obsolete_links(self):
        # The source replaces earlier containers; their bytes are retained, not linked.
        timeline = number("TICn", 1) + number("CpCn", 0)
        timeline += block("Item", timeline_item(500)) + block("Item", timeline_item(-1))
        result = graph.inspect(document(("TmLn", timeline)))
        self.assertEqual(result["edges"], [])
        old = result["nodes"][0]["containers"][0]["superseded"][0]
        self.assertEqual(base64.b64decode(old["raw_base64"]), timeline_item(500))

    def test_nullable_bool_uses_first_byte_without_inventing_false(self):
        result = graph.inspect(document(("Bind", block("bStG", b"\xff\0\0\0") + block("bVSc", b"\x01\xff\xff\xff"))))
        values = result["nodes"][0]["values"]
        self.assertEqual(values["bStG"], {"value": None, "byte": 255})
        self.assertEqual(values["bVSc"], {"value": True, "byte": 1})
        self.assertIsNone(values["bVSd"])

    def test_missing_is_not_zero_and_unknown_type_is_not_opened(self):
        missing = graph.inspect(document(("Emit", emitter()), ("Efct", b"")))
        zero = graph.inspect(document(("Emit", emitter() + number("EfNo", 0)), ("Efct", b"")))
        self.assertEqual(missing["edges"], [])
        self.assertEqual(zero["edges"][0]["index"], 0)
        for selector in (b"", number("PrVT", 999)):
            result = graph.inspect(document(("Ptcl", selector + block("Data", b"not TLV"))))
            self.assertEqual(result["edges"], [])
            self.assertEqual(base64.b64decode(result["nodes"][0]["opaque_data"]["raw_base64"]), b"not TLV")

    def test_invalid_and_duplicate_scalars(self):
        for payload in (number("Life", 1) * 2, block("Life", b"123"), block("Life", b""), block("Life", b"12345678")):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                graph.inspect(document(("Bind", payload)))
        for value, encoded in ((255, b"\xff"), (-1, b"\xff\xff"), (-1, b"\xff" * 4)):
            result = graph.inspect(document(("Bind", block("Life", encoded))))
            self.assertEqual(result["nodes"][0]["values"]["Life"], value)
        with self.assertRaisesRegex(ValueError, "StTm"):
            graph.inspect(document(("TmLn", number("TICn", 1) + number("CpCn", 0) + block("Item", timeline_item(extras=number("StTm", 2))))))

    def test_opaque_never_guessed_and_deterministic_roundtrip(self):
        opaque = block("EmNo", struct.pack("<i", 9000)) + b"not aligned"
        data = document(("Bind", number("Life", -1) + block("Data", opaque, b"Z")), extra=block("ZZ", b"x", b"Q"))
        result = graph.inspect(data)
        self.assertEqual(base64.b64decode(result["raw_avfx_base64"]), data)
        self.assertEqual(result["source_sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(base64.b64decode(result["nodes"][0]["opaque_fields"][0]["raw_base64"]), opaque)
        self.assertEqual(json.dumps(result, sort_keys=True), json.dumps(graph.inspect(data), sort_keys=True))
        self.assertNotIn("timestamp", result)

    def test_cycles_and_loops_retained(self):
        result = graph.inspect(document(("Emit", emitter(children=[emitter_item(1)]) + number("LpSt", 20) + number("LpEd", 10)),
                                        ("Emit", emitter(children=[emitter_item(0)]))))
        self.assertEqual([e["index"] for e in result["edges"]], [1, 0])
        self.assertEqual(result["nodes"][0]["values"]["LpSt"], 20)
        self.assertEqual(result["nodes"][0]["values"]["LpEd"], 10)
        self.assertFalse(result["rendering_complete"])

    def test_clip_binary_layout_local_reference_and_count(self):
        clip = struct.pack("<5i4f", 0x4b494c4c, -4, 2, 3, 1, -1, 0, 0.5, 2) + bytes(range(128))
        timeline = number("TICn", 1) + number("CpCn", 1) + block("Item", timeline_item(clip=0)) + block("Clip", clip)
        result = graph.inspect(document(("TmLn", timeline)))
        self.assertEqual(result["nodes"][0]["clips"][0]["integers"], [-4, 2, 3, 1])
        self.assertEqual(result["edges"][0]["target_scope"], "AVFX/TmLn[0]")
        for changed in (timeline.replace(number("ClNo", 0), number("ClNo", 1)),
                        timeline.replace(number("CpCn", 1), number("CpCn", 0)),
                        timeline.replace(block("Clip", clip), block("Clip", clip[:-1]))):
            with self.subTest(), self.assertRaises(ValueError):
                graph.inspect(document(("TmLn", changed)))

    def test_record_widths_and_nonfinite(self):
        for size in (276, 288, 300, 312):
            result = graph.inspect(document(("Emit", emitter([emitter_item(-1, size)]))))
            self.assertEqual(len(result["nodes"][0]["items"]), 1)
        with self.assertRaises(ValueError):
            graph.records(b"x" * 277, "emitter")
        with self.assertRaises(ValueError):
            graph.records(block("bEna", b"\x01"), "timeline")
        with self.assertRaises(ValueError):
            graph.inspect(document(("Bind", block("bVSb", struct.pack("<f", float("nan"))))))

    def test_root_version_counts_and_size(self):
        data = document()
        for changed in (data[:-1], data.replace(number("Ver", graph.VERSION), number("Ver", 1)),
                        data.replace(number("EmCn", 0), number("EmCn", 1)), b"x" * (graph.MAX_BYTES + 1)):
            with self.subTest(), self.assertRaises(ValueError):
                graph.inspect(changed)

    def test_actual_cli_status_and_stdout(self):
        root = Path(__file__).resolve().parents[2]
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        with tempfile.TemporaryDirectory(dir=root) as directory:
            path = Path(directory) / "synthetic.avfx"
            data = document(("Bind", number("Life", -1)))
            path.write_bytes(data)
            command = [sys.executable, "-B", "-X", "utf8", str(root / "tools/avfx_graph.py"), "--input", str(path)]
            a = subprocess.run(command, capture_output=True, timeout=20, env=env)
            b = subprocess.run(command, capture_output=True, timeout=20, env=env)
            self.assertEqual(a.returncode, 0, a.stderr)
            self.assertEqual(a.stdout, b.stdout)
            self.assertEqual(path.read_bytes(), data)
            self.assertEqual(base64.b64decode(json.loads(a.stdout)["raw_avfx_base64"]), data)
            self.assertNotIn(str(path).encode(), a.stdout)
            path.write_bytes(b"bad")
            bad = subprocess.run(command, capture_output=True, timeout=20, env=env)
            self.assertEqual(bad.returncode, 2)
            self.assertEqual(bad.stdout, b"")
            self.assertNotIn(str(path).encode(), bad.stderr)


if __name__ == "__main__":
    unittest.main()
