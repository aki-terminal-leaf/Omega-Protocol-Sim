# SPDX-License-Identifier: MIT
import base64
import json
import math
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import avfx_curves as avfx


def block(tag, data):
    return struct.pack("<4sI", tag[::-1].encode().ljust(4, b"\0"), len(data)) + data + b"\0"*(-len(data) % 4)


def uint(tag, value):
    return block(tag, struct.pack("<I", value))


def key(time, kind=1, x=1, y=1, z=0):
    return struct.pack("<hHfff", time, kind, x, y, z)


def curve(*keys, extra=b""):
    return uint("KeyC", len(keys)) + block("Keys", b"".join(keys)) + extra


def root(*nodes):
    counts = {tag: sum(t == tag for t, _ in nodes) for tag in avfx.COUNTS.values()}
    return block("AVFX", uint("Ver", avfx.VERSION)
                 + b"".join(uint(c, counts[t]) for c, t in avfx.COUNTS.items())
                 + b"".join(block(t, v) for t, v in nodes))


class CurveTests(unittest.TestCase):
    def test_actual_codec_signed_time_unsigned_type(self):
        raw = key(-32768, 65535, .25, .75, -2.5)
        self.assertEqual(len(raw), 16)
        k = avfx.decode_keys(raw, 1)[0]
        self.assertEqual((k["time"], k["type"], k["data"]), (-32768, 65535, [.25, .75, -2.5]))

    def test_rgb_is_not_scalar(self):
        k = avfx.decode_keys(key(0, x=.25, y=.5, z=.75), 1, "rgb")[0]
        self.assertEqual(k["rgb"], [.25, .5, .75])
        self.assertNotIn("value", k)
        c = avfx.decode_curve(curve(key(0)), "rgb")
        with self.assertRaises(avfx.UnsupportedCurve):
            avfx.sample_scalar(c, 0)

    def test_linear_native_time_and_boundaries(self):
        c = avfx.decode_curve(curve(key(-10, z=2), key(30, z=10)))
        for t, expected in ((-10, 2), (0, 4), (10, 6), (30, 10)):
            self.assertEqual(avfx.sample_scalar(c, t), expected)

    def test_angle_keeps_radians(self):
        c = avfx.decode_curve(curve(key(0, z=math.pi)), "angle")
        self.assertAlmostEqual(avfx.sample_scalar(c, 0), math.pi, places=6)

    def test_step_exact_interior_and_final_boundary(self):
        c = avfx.decode_curve(curve(key(0, 2, z=2), key(10, 2, z=5), key(20, z=9)))
        for t, expected in ((0, 2), (9.999, 2), (10, 5), (19.999, 5), (20, 9)):
            self.assertEqual(avfx.sample_scalar(c, t), expected)

    def test_asymmetric_spline_inverts_x(self):
        # x controls = 0 and 7.5, endpoint x=10; u=.5 gives x=4.0625,
        # y(.5)=5. Normalizing time directly would incorrectly give ~3.61.
        c = avfx.decode_curve(curve(key(0, 0, x=0, y=.5, z=0),
                                    key(10, 0, x=99, y=99, z=10)))
        self.assertAlmostEqual(avfx.sample_scalar(c, 4.0625), 5, places=12)
        self.assertGreater(abs(avfx.sample_scalar(c, 5)-5), .5)
        self.assertEqual(avfx.sample_scalar(c, 0), 0)
        self.assertEqual(avfx.sample_scalar(c, 10), 10)

    def test_monotone_crossed_handles(self):
        # Ordered handles are sufficient but not necessary: x'=30(1-2u)^2.
        c = avfx.decode_curve(curve(key(0, 0, x=2, y=2), key(10, z=10)))
        self.assertNotIn("non_monotone_spline", c["unsupported"])
        self.assertAlmostEqual(avfx.sample_scalar(c, 4.375), 1.5625, places=10)

    def test_nonmonotone_rejected_even_at_boundary(self):
        for x, y in ((-1, 1), (1, -1), (4, 4)):
            c = avfx.decode_curve(curve(key(0, 0, x=x, y=y), key(10)))
            self.assertIn("non_monotone_spline", c["unsupported"])
            with self.assertRaises(avfx.UnsupportedCurve):
                avfx.sample_scalar(c, 0)

    def test_duplicate_and_decreasing_not_sorted(self):
        for times in ((0, 0), (10, 0)):
            c = avfx.decode_curve(curve(*(key(t) for t in times)))
            self.assertEqual([k["time"] for k in c["keys"]], list(times))
            with self.assertRaises(avfx.UnsupportedCurve):
                avfx.sample_scalar(c, 0)

    def test_unsupported_type_including_last_key(self):
        c = avfx.decode_curve(curve(key(0), key(10, 400)))
        with self.assertRaises(avfx.UnsupportedCurve):
            avfx.sample_scalar(c, 0)

    def test_nonfinite_data_and_time(self):
        for n in (float("nan"), float("inf"), -float("inf")):
            for xyz in ((n, 1, 2), (1, n, 2), (1, 2, n)):
                with self.assertRaises(ValueError):
                    avfx.decode_keys(key(0, x=xyz[0], y=xyz[1], z=xyz[2]), 1)
            with self.assertRaises(ValueError):
                avfx.sample_scalar(avfx.decode_curve(curve(key(0))), n)

    def test_corrupt_counts_lengths_and_duplicate_fields(self):
        bad = (uint("KeyC", 0xffffffff) + block("Keys", b""),
               uint("KeyC", 2) + block("Keys", key(0)),
               uint("KeyC", 1) + block("Keys", key(0)[:-1]),
               uint("KeyC", 1), curve(key(0)) + uint("KeyC", 1),
               block("KeyC", b"\1") + block("Keys", key(0)),
               curve(key(0)) + block("BvPr", b"\0"))
        for payload in bad:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                avfx.decode_curve(payload)
        with self.assertRaises(ValueError):
            avfx.decode_curve(curve(key(0))[:-1])

    def test_empty_and_one_key(self):
        with self.assertRaises(avfx.UnsupportedCurve):
            avfx.sample_scalar(avfx.decode_curve(uint("KeyC", 0)), 0)
        c = avfx.decode_curve(curve(key(2, z=7)))
        self.assertEqual(avfx.sample_scalar(c, 2), 7)
        with self.assertRaises(avfx.UnsupportedCurve):
            avfx.sample_scalar(c, 3)

    def test_all_outside_behavior_unimplemented(self):
        for behavior in (None, 0, 1, 2, 0xffffffff, 99):
            extra = b"" if behavior is None else uint("BvPr", behavior) + uint("BvPo", behavior)
            c = avfx.decode_curve(curve(key(0), key(10, z=10), extra=extra))
            self.assertEqual(c["BvPr"], behavior)
            self.assertEqual(avfx.sample_scalar(c, 5), 5)
            for t in (-1, 11):
                with self.assertRaises(avfx.UnsupportedCurve):
                    avfx.sample_scalar(c, t)

    def test_random_metadata_and_role_not_played(self):
        for n in (0, 1, 2, 3, 4, 5, 99):
            c = avfx.decode_curve(curve(key(0), extra=uint("RanT", n)))
            self.assertEqual(c["RanT"], n)
            with self.assertRaises(avfx.UnsupportedCurve):
                avfx.sample_scalar(c, 0)
        c = avfx.decode_curve(curve(key(0)), random_role=True)
        with self.assertRaises(avfx.UnsupportedCurve):
            avfx.sample_scalar(c, 0)

    def test_life_sentinel_and_values(self):
        self.assertFalse(avfx.decode_life(b"\xff"*4)["enabled"])
        p = block("Val", struct.pack("<f", 30)) + block("ValR", struct.pack("<f", 2)) + uint("Type", 4)
        life = avfx.decode_life(p)
        self.assertEqual((life["Val"], life["ValR"], life["Type"]), (30, 2, 4))
        self.assertIn("random_playback", life["unsupported"])
        for bad in (b"", b"\0"*4, block("Val", b"x"), block("Val", struct.pack("<f", float("nan")))):
            with self.assertRaises(ValueError):
                avfx.decode_life(bad)

    def test_axis_links_and_random_preserved_without_copying(self):
        p = uint("ACT", 7) + uint("ACTR", 99) + block("X", curve(key(0, z=3))) + block("ZR", curve(key(0)))
        a = avfx.decode_axes(p)
        self.assertEqual((a["ACT"], a["ACTR"]), (7, 99))
        self.assertEqual(set(a["axes"]), {"X", "ZR"})
        self.assertIn("random_playback", a["axes"]["ZR"]["unsupported"])
        self.assertEqual(base64.b64decode(a["raw_payload_base64"]), p)

    def test_unknown_bytes_preserved(self):
        p = curve(key(0), extra=block("UNKN", b"\0\xffX"))
        c = avfx.decode_curve(p)
        self.assertEqual(base64.b64decode(c["unknown_fields"][0]["raw_base64"]), b"\0\xffX")
        self.assertEqual(base64.b64decode(c["raw_payload_base64"]), p)
        with self.assertRaises(avfx.UnsupportedCurve):
            avfx.sample_scalar(c, 0)

    def test_inventory_known_paths_only_deterministic(self):
        fake = block("KeyC", b"not a curve")
        data = root(("Modl", fake), ("Tex", b"invalid TLV"),
                    ("Bind", block("Life", b"not curve Life")),
                    ("Ptcl", block("Data", fake) + block("Pos", uint("ACT", 1) + block("X", curve(key(0))))
                     + block("Col", block("RGB", curve(key(0, x=.25, y=.5, z=.75))))
                     + block("Life", b"\xff"*4)))
        result = avfx.inspect(data)
        self.assertEqual(result["summary"]["curves"], 2)
        self.assertEqual(result["summary"]["rgb_keys"], 1)
        self.assertEqual(base64.b64decode(result["raw_avfx_base64"]), data)
        self.assertEqual(json.dumps(result, sort_keys=True, allow_nan=False),
                         json.dumps(avfx.inspect(data), sort_keys=True, allow_nan=False))
        self.assertFalse(result["rendering_complete"])
        self.assertNotIn(str(Path.cwd()), json.dumps(result))

    def test_invalid_roots_version_counts(self):
        for data in (b"", block("Oops", b""), block("AVFX", uint("Ver", 0)),
                     block("AVFX", uint("Ver", avfx.VERSION))):
            with self.assertRaises(ValueError):
                avfx.inspect(data)


if __name__ == "__main__":
    unittest.main()
