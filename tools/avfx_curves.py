#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Bounded AVFX curve decoding and reference-editor scalar math, not playback.

Only explicitly mapped Emit/Ptcl fields are traversed. Unknown bytes are retained
in raw_avfx_base64, exactly as in avfx_meshes; never guess TLV in opaque buffers.
"""
from __future__ import annotations

import argparse
import base64
from bisect import bisect_left
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

try:
    from .avfx_meshes import MAX_BYTES, VERSION, COUNTS, REFERENCE, blocks, integer, unique
except ImportError:
    from avfx_meshes import MAX_BYTES, VERSION, COUNTS, REFERENCE, blocks, integer, unique

KEY = struct.Struct("<hHfff")
KEY_TYPES = {0: "spline", 1: "linear", 2: "step"}
BEHAVIORS = {0: "Const", 1: "Repeat", 2: "Add", 0xffffffff: "None"}
RANDOM_TYPES = dict(enumerate(("FirstPlusMinus", "FirstPlus", "FirstMinus",
                              "AlwaysPlusMinus", "AlwaysPlus", "AlwaysMinus")))
AXIS_LINKS = dict(enumerate(("None", "X_YZ", "X_Y", "X_Z", "Y_XZ",
                            "Y_X", "Y_Z", "Z_XY", "Z_X", "Z_Y")))
COMMON = frozenset(("Gra", "GraR", "ARs", "ARsR"))
SCALARS = {
    "Emit": COMMON | frozenset(("CrC", "CrCR", "CrI", "CrIR", "IAX", "IAXR",
                                "IAY", "IAYR", "IAZ", "IAZR", "VRX", "VRY", "VRZ")),
    "Ptcl": COMMON | frozenset(("VRX", "VRXR", "VRY", "VRYR", "VRZ", "VRZR")),
}
COLOR_FIELDS = frozenset(("RGB", "A", "SclR", "SclG", "SclB", "SclA",
                          "Bri", "RanR", "RanG", "RanB", "RanA", "RBri"))
RANDOM_FIELDS = frozenset(("GraR", "ARsR", "CrCR", "CrIR", "IAXR", "IAYR",
                           "IAZR", "VRXR", "VRYR", "VRZR",
                           "XR", "YR", "ZR", "RanR", "RanG", "RanB", "RanA", "RBri"))


class UnsupportedCurve(ValueError):
    """Data can be retained, but this layer cannot sample its semantics."""


def _raw(data):
    return base64.b64encode(data).decode("ascii")


def _optional_int(rows, tag):
    return None if unique(rows, tag, False) is None else integer(rows, tag)


def _unknown(rows, known):
    return [{"tag": tag, "raw_base64": _raw(value)}
            for tag, value in rows if tag not in known]


def decode_keys(data: bytes, count: int, kind="scalar"):
    """Decode actual 16-byte keys; time stays signed native units."""
    if kind not in ("scalar", "angle", "rgb"):
        raise ValueError("Unknown curve kind")
    if len(data) > MAX_BYTES or count < 0 or count > MAX_BYTES // KEY.size:
        raise ValueError("Key count/size exceeds budget")
    if len(data) != count * KEY.size:
        raise ValueError("KeyC/Keys length mismatch")
    keys = []
    for time, key_type, x, y, z in KEY.iter_unpack(data):
        if not all(math.isfinite(n) for n in (x, y, z)):
            raise ValueError("Non-finite key data")
        key = {"time": time, "type": key_type, "data": [x, y, z]}
        if kind == "rgb":
            key["rgb"] = [x, y, z]
        else:
            key["controls"] = [x, y]
            key["value"] = z
        keys.append(key)
    return keys


def decode_curve(payload: bytes, kind="scalar", random_role=False):
    rows = blocks(payload)
    count = integer(rows, "KeyC")
    data = unique(rows, "Keys", False)
    if data is None:
        if count:
            raise ValueError("Missing Keys")
        data = b""
    result = {
        "kind": kind, "random_role": bool(random_role),
        "BvPr": _optional_int(rows, "BvPr"),
        "BvPo": _optional_int(rows, "BvPo"),
        "RanT": _optional_int(rows, "RanT"),
        "keys": decode_keys(data, count, kind),
        "unknown_fields": _unknown(rows, {"KeyC", "Keys", "BvPr", "BvPo", "RanT"}),
        "raw_payload_base64": _raw(payload),
    }
    result["unsupported"] = curve_issues(result)
    return result


def _monotone(left, right):
    # x'(u)/3 is a quadratic Bezier with these three differences.
    # Check its minimum analytically, including the interior vertex.
    half = (right["time"] - left["time"]) / 2
    h1 = left["time"] + left["data"][0] * half
    h2 = right["time"] - left["data"][1] * half
    a, b, c = h1 - left["time"], h2 - h1, right["time"] - h2
    qa, qb = a - 2*b + c, 2*(b-a)
    values = [a, c]
    if qa > 0:
        u = -qb / (2*qa)
        if 0 < u < 1:
            values.append((qa*u + qb)*u + a)
    return min(values) >= 0


def curve_issues(curve):
    """Explicit unsupported metadata; outside behavior never inferred."""
    issues = []
    keys = curve["keys"]
    if curve["kind"] == "rgb":
        issues.append("rgb_sampling")
    if not keys:
        issues.append("empty_keys")
    if any(k["type"] not in KEY_TYPES for k in keys):
        issues.append("key_type")
    if any(a["time"] >= b["time"] for a, b in zip(keys, keys[1:])):
        issues.append("non_increasing_times")
    elif curve["kind"] != "rgb" and any(
            a["type"] == 0 and not _monotone(a, b) for a, b in zip(keys, keys[1:])):
        issues.append("non_monotone_spline")
    if curve["random_role"] or curve["RanT"] is not None:
        issues.append("random_playback")
    if curve["unknown_fields"]:
        issues.append("unknown_fields")
    # Even Const is deliberately outside this interval-only API.
    issues.extend(("outside_pre_behavior", "outside_post_behavior"))
    return issues


def sample_scalar(curve, time):
    """Evaluate editor line geometry only, within the original key interval.

RanT (including zero) is not a 'no randomness' enum: all explicit random
metadata and random-role curves are rejected. No random/axis composition,
pre/post extension, clamping, sorting or linear fallback is performed.
"""
    if not math.isfinite(time):
        raise ValueError("Non-finite sample time")
    keys = curve["keys"]
    if any(not all(math.isfinite(n) for n in [k["time"], *k["data"]]) for k in keys):
        raise ValueError("Non-finite key data")
    issues = [i for i in curve_issues(curve) if not i.startswith("outside_")]
    if issues:
        raise UnsupportedCurve(", ".join(issues))
    times = [k["time"] for k in keys]
    if time < times[0] or time > times[-1]:
        raise UnsupportedCurve("Outside key interval: pre/post behavior unimplemented")
    index = bisect_left(times, time)
    if index < len(keys) and times[index] == time:
        return keys[index]["data"][2]
    left, right = keys[index-1], keys[index]
    x0, x3 = left["time"], right["time"]
    y0, y3 = left["data"][2], right["data"][2]
    if left["type"] == 2:
        return y0
    if left["type"] == 1:
        return y0 + (y3-y0) * ((time-x0)/(x3-x0))
    half = (x3-x0)/2
    x1 = x0 + left["data"][0]*half
    x2 = x3 - left["data"][1]*half
    lo, hi = 0.0, 1.0
    # Fixed bound: at most 64 bisections; no assumption u == normalized time.
    for _ in range(64):
        u = (lo+hi)/2
        v = 1-u
        x = v*v*v*x0 + 3*v*v*u*x1 + 3*v*u*u*x2 + u*u*u*x3
        if x < time:
            lo = u
        else:
            hi = u
    u = (lo+hi)/2
    return y0 + (y3-y0)*(3*u*u-2*u*u*u)


def decode_axes(payload: bytes, kind="scalar"):
    rows = blocks(payload)
    result = {"ACT": _optional_int(rows, "ACT"), "ACTR": _optional_int(rows, "ACTR"),
              "axes": {}, "unsupported": ["axis_connect_playback"],
              "unknown_fields": _unknown(rows, {"ACT", "ACTR", "X", "Y", "Z", "XR", "YR", "ZR"}),
              "raw_payload_base64": _raw(payload)}
    for tag in ("X", "Y", "Z", "XR", "YR", "ZR"):
        data = unique(rows, tag, False)
        if data is not None:
            result["axes"][tag] = decode_curve(data, kind, tag in RANDOM_FIELDS)
    return result


def decode_life(payload: bytes):
    if payload == b"\xff"*4:
        return {"sentinel": "ffffffff", "enabled": False,
                "raw_payload_base64": _raw(payload)}
    if len(payload) <= 4:
        raise ValueError("Invalid Life sentinel")
    rows = blocks(payload)
    result = {"enabled": True, "Type": _optional_int(rows, "Type"),
              "unsupported": ["life_playback", "random_playback"],
              "unknown_fields": _unknown(rows, {"Val", "ValR", "Type"}),
              "raw_payload_base64": _raw(payload)}
    for tag in ("Val", "ValR"):
        data = unique(rows, tag, False)
        if data is None:
            result[tag] = None
            continue
        if len(data) != 4:
            raise ValueError("Invalid Life scalar size")
        value = struct.unpack("<f", data)[0]
        if not math.isfinite(value):
            raise ValueError("Non-finite Life value")
        result[tag] = value
    return result


def inspect(data: bytes):
    """Inventory a conservative, explicit subset; retain the entire source."""
    roots = blocks(data)
    if len(roots) != 1 or roots[0][0] != "AVFX":
        raise ValueError("Expected exactly one AVFX root")
    rows = blocks(roots[0][1])
    if integer(rows, "Ver") != VERSION:
        raise ValueError("Unsupported AVFX version")
    counts = Counter(t for t, _ in rows)
    for counter, tag in COUNTS.items():
        if integer(rows, counter) != counts[tag]:
            raise ValueError("AVFX root count mismatch")
    curves, axes, lives, opaque = [], [], [], []
    def add_curve(path, payload, kind="scalar", random=False):
        item = decode_curve(payload, kind, random)
        item["path"] = path
        curves.append(item)
    node_indices = Counter()
    for node, payload in rows:
        index = node_indices[node]
        node_indices[node] += 1
        path = f"AVFX/{node}[{index}]"
        if node not in SCALARS:
            if node not in COUNTS and node != "Ver":
                opaque.append({"path": path, "bytes": len(payload)})
            continue
        fields = blocks(payload)
        seen = Counter()
        for tag, value in fields:
            child = f"{path}/{tag}[{seen[tag]}]"
            seen[tag] += 1
            if tag in SCALARS[node]:
                unique(fields, tag)
                random = tag in RANDOM_FIELDS or (node == "Emit" and tag in ("VRX", "VRY", "VRZ"))
                kind = "angle" if tag.startswith("IA") else "scalar"
                add_curve(child, value, kind, random)
            elif tag in ("Pos", "Rot", "Scl"):
                unique(fields, tag)
                item = decode_axes(value, "angle" if tag == "Rot" else "scalar")
                for axis, curve in item.pop("axes").items():
                    curve["path"] = child + "/" + axis
                    curves.append(curve)
                item["path"] = child
                axes.append(item)
            elif tag == "Col":
                unique(fields, tag)
                for ct, cv in blocks(value):
                    if ct in COLOR_FIELDS:
                        unique(blocks(value), ct)
                        add_curve(child + "/" + ct, cv, "rgb" if ct == "RGB" else "scalar",
                                  ct in RANDOM_FIELDS)
                    else:
                        opaque.append({"path": child + "/" + ct, "bytes": len(cv)})
            elif tag == "Life":
                unique(fields, tag)
                item = decode_life(value)
                item["path"] = child
                lives.append(item)
            else:
                opaque.append({"path": child, "bytes": len(value)})
    unsupported = Counter(i for c in curves for i in c["unsupported"])
    unsupported.update(i for a in axes for i in a["unsupported"])
    unsupported.update(i for life in lives for i in life.get("unsupported", []))
    return {
        "schema": 1, "version": VERSION, "format_reference": REFERENCE,
        "scope": "Direct Emit/Ptcl scalar, transform, color and Life fields only; editor math, not game playback",
        "source_sha256": hashlib.sha256(data).hexdigest(),
        "rendering_complete": False, "time_units": "native numeric units",
        "angle_units": "radians",
        "summary": {"curves": len(curves), "keys": sum(len(c["keys"]) for c in curves),
                    "rgb_curves": sum(c["kind"] == "rgb" for c in curves),
                    "rgb_keys": sum(len(c["keys"]) for c in curves if c["kind"] == "rgb"),
                    "axes": len(axes), "life": len(lives), "opaque_fields": len(opaque),
                    "unsupported": dict(sorted(unsupported.items()))},
        "curves": curves, "axes": axes, "life": lives, "opaque_fields": opaque,
        "raw_avfx_base64": _raw(data),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    # stdout permits read-only private probes without writing an asset-derived file.
    args = parser.parse_args(argv)
    try:
        with args.input.open("rb") as stream:
            data = stream.read(MAX_BYTES + 1)
        result = inspect(data)
    except (OSError, ValueError) as exc:
        # Do not expose machine paths through OSError strings.
        parser.exit(2, f"AVFX inventory failed: {type(exc).__name__}\n")
    print(json.dumps(result, sort_keys=True, indent=2, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
