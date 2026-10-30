"""Bounded CUTB actor identity/resource metadata; model semantics remain unknown.

Evidence and exact native instruction anchors: docs/asset-lab/CUTB_NATIVE_BINDINGS.md.
Ranges are half-open validated/read spans, never inferred payload extents.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

MAX_BYTES = 16 * 1024 * 1024
MAX_COUNT = 4096
MAX_RECORDS = 8192
MAX_STRING = 2048
MAX_STRING_TOTAL = 1024 * 1024
MAX_JOINS = 8192
MAX_ADDRESS = (1 << 63) - 1
UNKNOWN = "UNKNOWN"


class DecodeError(ValueError):
    """Malformed or unsupported input exceeded a decoder safety boundary."""


class Reader:
    def __init__(self, data):
        if len(data) > MAX_BYTES:
            raise DecodeError("file size limit exceeded")
        self.data = data
        self.records_used = 0
        self.string_bytes = 0

    def bounds(self, offset, size):
        if (offset < 0 or size < 0 or offset > MAX_ADDRESS - size
                or offset + size > len(self.data)):
            raise DecodeError(f"out-of-bounds range at {offset}, size {size}")
        return offset

    def integer(self, offset, signed=False):
        self.bounds(offset, 4)
        return struct.unpack_from("<i" if signed else "<I", self.data, offset)[0]

    def relative(self, field, base, size=1):
        """Read signed LE32 at field; add to explicit base without wrapping.

        Negative displacements are valid when the resulting span is in bounds.
        CTAL table entries are table-relative, NOT entry-relative.
        """
        self.bounds(base, 0)
        displacement = self.integer(field, signed=True)
        return self.bounds(base + displacement, size)

    def count(self, offset, signed=False):
        count = self.integer(offset, signed)
        if not 0 <= count <= MAX_COUNT:
            raise DecodeError(f"count limit at {offset}: {count}")
        return count

    def reserve(self, count):
        self.records_used += count
        if self.records_used > MAX_RECORDS:
            raise DecodeError("aggregate record limit exceeded")

    def string(self, offset):
        self.bounds(offset, 1)
        end = self.data.find(b"\0", offset, min(len(self.data), offset + MAX_STRING))
        if end < 0:
            raise DecodeError("unterminated or oversized resource string")
        self.string_bytes += end - offset + 1
        if self.string_bytes > MAX_STRING_TOTAL:
            raise DecodeError("aggregate string limit exceeded")
        try:
            return self.data[offset:end].decode("utf-8")
        except UnicodeDecodeError as exc:
            raise DecodeError("resource string is not UTF-8") from exc

    def table(self, base, displacement_field, count_field):
        count = self.count(count_field, signed=True)
        self.reserve(count)
        table = self.relative(displacement_field, base, count * 12)
        return range(table, table + count * 12, 12)

    def tag(self, offset):
        self.bounds(offset, 4)
        raw = self.data[offset:offset + 4]
        # FourCC display only; no search for tags inside opaque payloads.
        return raw.decode("ascii") if all(32 <= x < 127 for x in raw) else raw.hex()


def actor_fields(r, record):
    # Only selector 15 has an inspected branch here. No guessed record extent.
    selector = r.data[r.bounds(record, 1)]
    result = {"selector_u8": selector, "identity_u32": UNKNOWN,
              "model_semantics": UNKNOWN}
    if selector == 15:
        result.update({"identity_u32": r.integer(record + 4),
                       "subselector_u32": r.integer(record + 0x34),
                       "field3c_u32": r.integer(record + 0x3c),
                       "field40_u32": r.integer(record + 0x40),
                       "identity_provenance": "record+4 -> packed high32; explicit reuse store 0x1418c3693 -> object+7c; allocating base constructor 0x1418c3480 NOT_STAGED",
                       "confidence": "OBSERVED_STATIC_FIELDS; object reuse branch proved, allocation branch incomplete"})
    return result


def kind0_rewrite_predicate(literal):
    # Native strlen/byte predicates at 0x141c93f26..f47, not Unicode indices.
    raw = literal.encode("utf-8")
    return len(raw) > 0x2d and raw[6] == 0x68 and raw[0x25] == 0x63 and raw[0x29] == 0x6d


def resource_table(r, payload):
    entries = []
    for entry in r.table(payload, payload, payload + 4):
        children = []
        for sub in r.table(entry, entry + 4, entry + 8):
            resources = []
            for record in r.table(sub, sub + 4, sub + 8):
                kind = r.integer(record)
                resource = {"record_offset": record, "kind_u32": kind,
                            "field4_semantics": UNKNOWN, "literal_path": UNKNOWN,
                            "resolved_runtime_path": UNKNOWN}
                # Unknown kinds take the native default branch, without a string read.
                if kind in (0, 1, 2, 3):
                    pointer = r.relative(record + 8, record)
                    literal = r.string(pointer)
                    resource.update({"string_offset": pointer,
                                     "literal_path": literal,
                                     "candidate_request_calls": {0: ["0x141c93ff9", "0x141c94073"],
                                                      1: ["0x141c93ee3"], 2: ["0x141c93e3c"],
                                                      3: ["0x141c93dce"]}[kind],
                                     "kind0_rewrite_capable": kind == 0,
                                     "rewrite_predicate_static": (kind == 0 and kind0_rewrite_predicate(literal)),
                                     "request_execution": UNKNOWN})
                resources.append(resource)
            children.append({"offset": sub, "actor_identity_u32": r.integer(sub),
                             "resources": resources})
        entries.append({"offset": entry, "event_field8_key_u32": r.integer(entry),
                        "key_semantics": UNKNOWN, "actors": children})
    return entries


def resource_joins(rows):
    actors = {}
    for row in rows:
        if row["tag"] == "CTAL":
            for actor in row["payload"]["records"]:
                identity = actor["actor_fields"]["identity_u32"]
                if identity != UNKNOWN:
                    actors.setdefault(identity, []).append({"ctal_row": row["index"],
                        "actor_index": actor["actor_index"], "record_offset": actor["record_offset"]})
    joins = []
    used = 0
    for row in rows:
        if row["tag"] != "CTPA":
            continue
        for entry in row["payload"]["entries"]:
            for sub in entry["actors"]:
                matches = actors.get(sub["actor_identity_u32"], [])
                used += max(1, len(matches))
                if used > MAX_JOINS:
                    raise DecodeError("aggregate join limit exceeded")
                joins.append({"ctpa_row": row["index"], "entry_offset": entry["offset"],
                    "event_field8_key_u32": entry["event_field8_key_u32"],
                    "subentry_offset": sub["offset"], "actor_identity_u32": sub["actor_identity_u32"],
                    "ctal_matches": matches, "match_status": "STATIC_IDENTITY_EQUALITY" if matches else "NO_SELECTOR15_STATIC_MATCH",
                    "resource_offsets": [x["record_offset"] for x in sub["resources"]],
                    "identity_provenance_scope": "selector15 static record+4 equality; reuse object+7c proved, allocation not in this evidence set",
                    "runtime_selection": UNKNOWN})
    return joins


def decode(data):
    """Return compact proved structure, or raise DecodeError; never raw payloads."""
    r = Reader(data)
    r.bounds(0, 12)
    if r.tag(0) != "CUTB":
        raise DecodeError("expected CUTB")
    count = r.count(8)
    result = {
        "status": "PARTIAL", "all96_accepted": False,
        "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
        "tag": "CUTB", "header_range": [0, 12], "row_count": count,
        "rows": [], "observed_actor_array_mappings": [], "candidate_actor_joins": [],
        "actor_model_pap_join": UNKNOWN,
        "range_semantics": "half-open validated spans; full payload/record extents UNKNOWN",
    }
    row = 12
    for index in range(count):
        r.bounds(row, 8)
        tag = r.tag(row)
        stride = r.integer(row + 4, signed=True)
        if stride < 8 or stride > MAX_BYTES:
            raise DecodeError(f"nonprogressing/short/oversized row stride at {row}: {stride}")
        r.bounds(row, stride)
        item = {"index": index, "tag": tag, "row_range": [row, row + stride],
                "stride_i32": stride, "payload": UNKNOWN}
        if tag in ("CTAL", "CTTL", "CTPA", "CTRL", "CTIS"):
            if stride < 12:
                raise DecodeError(f"pointer outside row at {row}")
            size = 16 if tag == "CTAL" else 12 if tag == "CTTL" else 1
            payload = r.relative(row + 8, row + 8, size)
            item["payload"] = {"offset": payload,
                               "validated_range": [payload, payload + size],
                               "full_range": UNKNOWN}
            if tag == "CTAL":
                actors = r.count(payload + 12, signed=True)
                r.reserve(actors)
                table = r.relative(payload + 8, payload, actors * 4)
                records = []
                for actor_index in range(actors):
                    field = table + actor_index * 4
                    record = r.relative(field, table)
                    records.append({"actor_index": actor_index, "offset_field": field,
                                    "record_offset": record, "record_extent": UNKNOWN,
                                    "known_fields": {}, "field_semantics": UNKNOWN,
                                    "actor_fields": actor_fields(r, record)})
                item["payload"].update({"actor_count_i32": actors,
                                         "offset_table_range": [table, table + actors * 4],
                                         "records": records})
                result["observed_actor_array_mappings"].append({
                    "ctal_row": index,
                    "meaning": "table index i -> record pointer -> returned object stored in controller+0x270 array[i]",
                    "actor_count": actors, "model": UNKNOWN, "pap": UNKNOWN})
            elif tag == "CTTL":
                if r.tag(payload) != "TMLB":
                    raise DecodeError(f"CTTL payload is not TMLB at {payload}")
                item["payload"].update({"tag": "TMLB", "row_count_u32": r.count(payload + 8),
                                         "events": "NOT_DECODED"})
            else:
                item["payload"]["downstream_semantics"] = UNKNOWN
                if tag == "CTPA":
                    item["payload"]["resource_path_link"] = UNKNOWN
                    item["payload"]["entries"] = resource_table(r, payload)
        result["rows"].append(item)
        row += stride
    result["actor_resource_joins"] = resource_joins(result["rows"])
    result["state_scope"] = "local CTAL rows only; later overwrite/reallocation possible; file order is not runtime dispatch order"
    result["missing_links"] = [
        "Allocating identity copy via base constructor 0x1418c3480 NOT_STAGED; reuse copy observed",
        "Event data+8 key semantic name and actual runtime selection UNKNOWN",
        "ModelChara/tablekind, body, SKLB, resolved runtime paths and playback UNKNOWN",
    ]
    return result


def decode_file(path):
    with Path(path).open("rb") as stream:
        data = stream.read(MAX_BYTES + 1)
    return decode(data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    # samefile also protects a hardlink alias of the read-only source.
    if (args.input.resolve() == args.output.resolve()
            or (args.input.exists() and args.output.exists()
                and args.input.samefile(args.output))):
        parser.error("output must not alias input")
    try:
        result = decode_file(args.input)
        exit_code = 0
    except (DecodeError, OSError) as exc:
        result = {"status": "INVALID", "all96_accepted": False, "error": str(exc)}
        exit_code = 2
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
