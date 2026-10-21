#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Source-backed, lossless AVFX topology inventory; no graph execution."""
from __future__ import annotations

import argparse
import base64
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


def raw(data):
    return {"raw_base64": base64.b64encode(data).decode("ascii"),
            "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}


def scalar(rows, tag, kind="int"):
    """Literal widths follow ParsedInt; byte values are unsigned, shorts signed."""
    data = unique(rows, tag, False)
    if data is None:
        return None
    if kind == "float":
        if len(data) != 4:
            raise ValueError(f"Invalid scalar width: {tag}")
        value = struct.unpack("<f", data)[0]
        if not math.isfinite(value):
            raise ValueError(f"Nonfinite scalar: {tag}")
        return value
    if len(data) not in (1, 2, 4):
        raise ValueError(f"Invalid scalar width: {tag}")
    if kind == "bool":
        return {"value": {0: False, 1: True}.get(data[0]), "byte": data[0]}
    return struct.unpack({1: "<B", 2: "<h", 4: "<i"}[len(data)], data)[0]


def fields(payload, ints="", bools="", floats="", containers=()):
    rows = blocks(payload)
    values = {}
    known = set(containers)
    for tags, kind in ((ints, "int"), (bools, "bool"), (floats, "float")):
        for tag in tags.split():
            known.add(tag)
            values[tag] = scalar(rows, tag, kind)
    opaque = [{"field_index": i, "tag": tag, **raw(value)}
              for i, (tag, value) in enumerate(rows) if tag not in known]
    return rows, {"values": values, "opaque_fields": opaque, **raw(payload)}


def records(payload, kind):
    """Only source-defined record boundaries; never recurse into unknown data."""
    if kind == "timeline":
        rows = blocks(payload)
        if any(len(v) != 4 for _, v in rows):
            raise ValueError("Timeline item fields must occupy 12 bytes")
        starts = [0] + [i * 12 for i, (t, _) in enumerate(rows) if i and t == "bEna"]
        return [payload[a:b] for a, b in zip(starts, starts[1:] + [len(payload)])] if payload else []
    sizes = (36,) if kind == "scheduler" else (312, 300, 288, 276)
    size = next((n for n in sizes if len(payload) % n == 0), None)
    if size is None:
        raise ValueError(f"Unsupported/malformed {kind} record size")
    return [payload[i:i + size] for i in range(0, len(payload), size)]


def selected(rows, tag, kind):
    matches = [(i, value) for i, (name, value) in enumerate(rows) if name == tag]
    if not matches:
        return [], {"tag": tag, "selected_field_index": None, "container_count": 0}
    index, payload = matches[-1]
    return records(payload, kind), {"tag": tag, "selected_field_index": index,
                                  "container_count": len(matches),
                                  "superseded": [{"field_index": i, **raw(v)} for i, v in matches[:-1]],
                                  **raw(payload)}


def check_count(values, tag, actual, issues):
    count = values[tag]
    if count is None:
        issues.append("missing_count:" + tag)
    elif count < 0 or count != actual:
        raise ValueError(f"{tag} selected list count mismatch")


def inspect(data: bytes):
    """Pure API: deterministic JSON-compatible inventory, all original bytes retained."""
    roots = blocks(data)
    if len(roots) != 1 or roots[0][0] != "AVFX":
        raise ValueError("Expected exactly one AVFX root")
    rows = blocks(roots[0][1])
    if integer(rows, "Ver") != VERSION:
        raise ValueError("Unsupported AVFX version")
    occurrences = Counter(t for t, _ in rows)
    counts = {tag: occurrences[tag] for tag in COUNTS.values()}
    for counter, tag in COUNTS.items():
        if integer(rows, counter) != counts[tag]:
            raise ValueError(f"{counter}/{tag} count mismatch")
    nodes, edges, references, unsupported = [], [], [], []

    def issue(path, reason):
        unsupported.append({"path": path, "reason": reason})

    def reference(owner, path, tag, value, target, role, limit=None, sentinel=-1, scope=None):
        state = "missing" if value is None else "sentinel" if value == sentinel else "linked"
        ref = {"owner": owner, "path": path, "field": tag, "index": value,
               "target_group": target, "target_scope": scope, "role": role, "state": state}
        references.append(ref)
        if state == "missing":
            issue(path + "/" + tag, "missing_selector")
        elif state == "linked":
            bound = counts[target] if limit is None else limit
            if value < 0 or value >= bound:
                raise ValueError(f"Reference outside {target}: {tag}")
            edges.append(dict(ref))

    def finish(record, path):
        for field in record["opaque_fields"]:
            issue(f"{path}/{field['tag']}@{field['field_index']}", "opaque_mapping")

    indices = Counter()
    root_opaque = []
    for root_index, (group, payload) in enumerate(rows):
        if group not in counts:
            if group not in COUNTS and group != "Ver":
                root_opaque.append({"field_index": root_index, "tag": group, **raw(payload)})
                issue(f"AVFX/{group}@{root_index}", "opaque_mapping")
            continue
        index = indices[group]
        indices[group] += 1
        path = f"AVFX/{group}[{index}]"
        node = {"group": group, "source_index": index, "path": path, "root_field_index": root_index}
        nodes.append(node)
        if group == "Schd":
            rr, record = fields(payload, "ItCn TrCn", containers=("Item", "Trgr"))
        elif group == "TmLn":
            rr, record = fields(payload, "LpSt LpEd BnNo TICn CpCn", containers=("Item", "Clip"))
        elif group == "Emit":
            rr, record = fields(payload, "LpSt LpEd ClCn EfNo PrCn EmCn EVT", containers=("ItPr", "ItEm", "Data"))
        elif group == "Bind":
            rr, record = fields(payload, "Life BnVr RoTp bTSc",
                                "bStG bVSc bVSd bVSi bTSd bTSi bFTO bDSE bATS bIFY bBET", "bVSb")
        elif group == "Ptcl":
            rr, record = fields(payload, "LpSt LpEd PrVT", containers=("Data",))
        else:
            node.update(raw(payload))
            issue(path, "opaque_group_payload")
            continue
        node.update(record)
        finish(record, path)
        values = record["values"]
        local_issues = []
        node["containers"] = []
        node["items"] = []

        def add_items(items, selection, kind, role, target=None, start=0):
            node["containers"].append(selection)
            for item_index, part in enumerate(items):
                item_path = f"{path}/{selection['tag']}@{selection['selected_field_index']}/record[{start + item_index}]"
                if kind == "scheduler":
                    _, item = fields(part, "StTm TlNo", "bEna")
                    refs = [("TlNo", "TmLn", role)]
                elif kind == "timeline":
                    _, item = fields(part, "StTm EdTm BdNo EfNo EmNo Plfm ClNo", "bEna")
                    refs = [("BdNo", "Bind", "binder"), ("EfNo", "Efct", "effector"),
                            ("EmNo", "Emit", "source_emitter")]
                else:
                    _, item = fields(part, "TgtB LoDr CrTm CrCn CrPr PICd PICo OvrV OvrR PrLk StFr GenD",
                                     "bEnb ICbS ICbR ICbP ICbB IPbV IPbL bOvr bStN bGD", "ICSK BIAX BIAY BIAZ")
                    refs = [("TgtB", target, role)]
                    if item["values"]["PrLk"] is not None:
                        issue(item_path + "/PrLk", "parameter_link_semantics")
                item.update(path=item_path, source_index=start + item_index, selected_index=item_index, role=role)
                node["items"].append(item)
                finish(item, item_path)
                for tag, dest, ref_role in refs:
                    reference(path, item_path, tag, item["values"][tag], dest, ref_role)
                if kind == "timeline":
                    reference(path, item_path, "ClNo", item["values"]["ClNo"], "Clip", "clip",
                              limit=len(node["clips"]), scope=path)

        if group == "Schd":
            items, selection = selected(rr, "Item", "scheduler")
            check_count(values, "ItCn", len(items), local_issues)
            add_items(items, selection, "scheduler", "scheduled_timeline")
            triggers, selection = selected(rr, "Trgr", "scheduler")
            if selection["container_count"] and len(triggers) < 12:
                raise ValueError("Scheduler final Trgr requires 12 trailing records")
            offset = max(0, len(triggers) - 12)
            selection["excluded_prefix_records"] = offset
            triggers = triggers[offset:]
            check_count(values, "TrCn", len(triggers), local_issues)
            add_items(triggers, selection, "scheduler", "trigger_timeline", start=offset)
        elif group == "TmLn":
            node["clips"] = []
            for field_index, (tag, value) in enumerate(rr):
                if tag != "Clip":
                    continue
                if len(value) != 164:
                    raise ValueError("Invalid Clip width")
                clip_type, *ints = struct.unpack_from("<5i", value)
                floats = list(struct.unpack_from("<4f", value, 20))
                if not all(math.isfinite(v) for v in floats):
                    raise ValueError("Nonfinite Clip float")
                node["clips"].append({"source_index": len(node["clips"]), "field_index": field_index,
                                      "type": clip_type, "integers": ints, "floats": floats,
                                      "reserved": raw(value[36:]), **raw(value)})
                issue(f"{path}/Clip[{len(node['clips']) - 1}]", "clip_execution")
            check_count(values, "CpCn", len(node["clips"]), local_issues)
            reference(path, path, "BnNo", values["BnNo"], "Bind", "binder")
            items, selection = selected(rr, "Item", "timeline")
            check_count(values, "TICn", len(items), local_issues)
            add_items(items, selection, "timeline", "timeline_item")
        elif group == "Emit":
            reference(path, path, "EfNo", values["EfNo"], "Efct", "effector")
            particles, selection = selected(rr, "ItPr", "emitter")
            check_count(values, "PrCn", len(particles), local_issues)
            add_items(particles, selection, "emitter", "child_particle", "Ptcl")
            emitters, selection = selected(rr, "ItEm", "emitter")
            offset = len(particles) if selection["container_count"] else 0
            if len(emitters) < offset:
                raise ValueError("ItEm shorter than particle prefix")
            selection["excluded_prefix_records"] = offset
            emitters = emitters[offset:]
            check_count(values, "EmCn", len(emitters), local_issues)
            add_items(emitters, selection, "emitter", "child_emitter", "Emit", offset)
        if group in ("Emit", "Ptcl"):
            selector = "EVT" if group == "Emit" else "PrVT"
            part = unique(rr, "Data", False)
            if values[selector] is None:
                issue(path + "/" + selector, "missing_type_selector")
            elif values[selector] != 5:
                issue(path + "/" + selector, "unsupported_type_mapping")
            if part is not None:
                if values[selector] == 5:
                    dr, model = fields(part, "MdNo" if group == "Emit" else "", containers=("MdNo",))
                    node["model_data"] = model
                    finish(model, path + "/Data")
                    if group == "Emit":
                        reference(path, path + "/Data", "MdNo", model["values"]["MdNo"], "Modl", "model")
                    else:
                        value = unique(dr, "MdNo", False)
                        model["model_indices"] = None if value is None else list(value)
                        if value is None:
                            reference(path, path + "/Data", "MdNo", None, "Modl", "model", sentinel=255)
                        else:
                            for slot, number in enumerate(value):
                                reference(path, path + f"/Data/MdNo[{slot}]", "MdNo", number, "Modl", "model", sentinel=255)
                else:
                    node["opaque_data"] = raw(part)
                    issue(path + "/Data", "opaque_type_data")
            elif values[selector] == 5:
                issue(path + "/Data", "missing_model_data")
        for reason in local_issues:
            issue(path, reason)
    reasons = Counter(x["reason"] for x in unsupported)
    roles = Counter(x["role"] for x in edges)
    return {"schema": 1, "version": VERSION, "format_reference": REFERENCE,
            "source_sha256": hashlib.sha256(data).hexdigest(),
            "raw_avfx_base64": base64.b64encode(data).decode("ascii"),
            "rendering_complete": False, "execution_implemented": False,
            "time_units": "native numeric units; no conversion or execution",
            "counts": counts, "nodes": nodes, "edges": edges, "references": references,
            "opaque_root_fields": root_opaque, "unsupported": unsupported,
            "summary": {"nodes": len(nodes), "groups": len(counts),
                        "nonempty_groups": sum(n > 0 for n in counts.values()), "edges": len(edges),
                        "edge_roles": dict(sorted(roles.items())),
                        "unsupported": dict(sorted(reasons.items()))}}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        with args.input.open("rb") as stream:
            result = inspect(stream.read(MAX_BYTES + 1))
    except (OSError, ValueError) as exc:
        parser.exit(2, f"AVFX topology inventory failed: {type(exc).__name__}\n")
    print(json.dumps(result, sort_keys=True, indent=2, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
