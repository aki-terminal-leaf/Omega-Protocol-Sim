"""Synthetic safety/schema regression scope only; real closure is probed separately."""
import struct
import unittest
from unittest.mock import patch
from contextlib import redirect_stderr
from io import StringIO

from tools.asset_lab.decode_cutb_bindings import DecodeError, Reader, decode, main


def fixture():
    b = bytearray(96)
    b[:4] = b"CUTB"
    struct.pack_into("<I", b, 8, 1)
    b[12:16] = b"CTAL"
    struct.pack_into("<ii", b, 16, 16, 12)  # payload = 20 + 12 = 32
    struct.pack_into("<ii", b, 40, 16, 2)  # table = payload + 16 = 48
    struct.pack_into("<ii", b, 48, 16, 24)  # records = 64, 72 (NOT 76)
    return b


class CutbBindingsTests(unittest.TestCase):
    def test_table_base_and_unknown_semantics(self):
        result = decode(fixture())
        p = result["rows"][0]["payload"]
        self.assertEqual(p["offset"], 32)
        self.assertEqual([x["record_offset"] for x in p["records"]], [64, 72])
        self.assertEqual(p["records"][1]["known_fields"], {})
        self.assertEqual(result["actor_model_pap_join"], "UNKNOWN")

    def test_valid_negative_relative_offset(self):
        b = fixture()
        struct.pack_into("<i", b, 52, -16)
        self.assertEqual(decode(b)["rows"][0]["payload"]["records"][1]["record_offset"], 32)

    def test_negative_target(self):
        b = fixture()
        struct.pack_into("<i", b, 20, -100)
        with self.assertRaises(DecodeError):
            decode(b)

    def test_bad_stride(self):
        for stride in [0, -16, 4, 8, 1000, 0x7fffffff]:
            with self.subTest(stride=stride):
                b = fixture()
                struct.pack_into("<i", b, 16, stride)
                with self.assertRaises(DecodeError):
                    decode(b)

    def test_huge_and_negative_counts(self):
        for field in [8, 44]:
            for count in [0xffffffff, 0x7fffffff, 4097]:
                with self.subTest(field=field, count=count):
                    b = fixture()
                    struct.pack_into("<I", b, field, count)
                    with self.assertRaises(DecodeError):
                        decode(b)

    def test_truncated_reads(self):
        for length in [0, 3, 11, 19, 23, 43, 47, 51, 64]:
            with self.subTest(length=length), self.assertRaises(DecodeError):
                decode(fixture()[:length])

    def test_wrong_magic(self):
        b = fixture()
        b[:4] = b"NOPE"
        with self.assertRaises(DecodeError):
            decode(b)

    def test_address_overflow_and_negative_size(self):
        r = Reader(b"1234")
        for offset, size in [(2**63 - 1, 1), (-1, 1), (0, -1)]:
            with self.subTest(offset=offset, size=size), self.assertRaises(DecodeError):
                r.bounds(offset, size)

    def test_ctpa_anchor_does_not_claim_resource(self):
        b = fixture()
        b[12:16] = b"CTPA"
        p = decode(b)["rows"][0]["payload"]
        self.assertEqual(p["offset"], 32)
        self.assertEqual(p["resource_path_link"], "UNKNOWN")

    def test_cttl_requires_tmlb(self):
        b = fixture()
        b[12:16] = b"CTTL"
        with self.assertRaises(DecodeError):
            decode(b)
        b[32:36] = b"TMLB"
        struct.pack_into("<I", b, 40, 0)
        self.assertEqual(decode(b)["rows"][0]["payload"]["tag"], "TMLB")

    def test_global_limits(self):
        with patch("tools.asset_lab.decode_cutb_bindings.MAX_BYTES", 32):
            with self.assertRaises(DecodeError):
                decode(fixture())
        with patch("tools.asset_lab.decode_cutb_bindings.MAX_RECORDS", 1):
            with self.assertRaises(DecodeError):
                decode(fixture())

    def test_opaque_tag_never_resolves_unknown_pointer(self):
        b = fixture()
        b[12:16] = b"ZZZZ"
        struct.pack_into("<i", b, 20, -2147483648)
        self.assertEqual(decode(b)["rows"][0]["payload"], "UNKNOWN")

    def test_cli_rejects_source_output_alias_before_write(self):
        with patch("pathlib.Path.write_text") as write, redirect_stderr(StringIO()):
            with self.assertRaises(SystemExit) as error:
                main(["--input", __file__, "--output", __file__])
            self.assertEqual(error.exception.code, 2)
            write.assert_not_called()


def nested_fixture():
    b = bytearray(320)
    b[:4] = b"CUTB"
    struct.pack_into("<I", b, 8, 2)
    b[12:16] = b"CTAL"
    struct.pack_into("<ii", b, 16, 12, 20)  # payload 40
    b[24:28] = b"CTPA"
    struct.pack_into("<ii", b, 28, 12, 128)  # payload 160
    struct.pack_into("<ii", b, 48, 16, 1)
    struct.pack_into("<i", b, 56, 24)  # actor 80
    b[80] = 15
    struct.pack_into("<I", b, 84, 123)
    struct.pack_into("<ii", b, 160, 16, 1)  # entries 176
    struct.pack_into("<Iii", b, 176, 7, 16, 1)  # subentry 192
    struct.pack_into("<Iii", b, 192, 123, 16, 1)  # resource 208
    struct.pack_into("<IIi", b, 208, 0, 999, 16)
    b[224:230] = b"a.pap\0"
    return b


class NestedResourceTests(unittest.TestCase):
    def test_identity_match_and_mismatch(self):
        b = nested_fixture()
        j = decode(b)["actor_resource_joins"][0]
        self.assertEqual(j["ctal_matches"], [{"ctal_row": 0, "actor_index": 0, "record_offset": 80}])
        struct.pack_into("<I", b, 192, 124)
        j = decode(b)["actor_resource_joins"][0]
        self.assertEqual(j["match_status"], "NO_SELECTOR15_STATIC_MATCH")
        self.assertEqual(j["resource_offsets"], [208])

    def test_nested_counts_and_bad_tables(self):
        for field in (164, 184, 200):
            for count in (-1, 4097, 0x7fffffff):
                b = nested_fixture()
                struct.pack_into("<i", b, field, count)
                with self.subTest(field=field, count=count), self.assertRaises(DecodeError):
                    decode(b)
        for field in (160, 180, 196):
            b = nested_fixture()
            struct.pack_into("<i", b, field, 310)
            with self.subTest(field=field), self.assertRaises(DecodeError):
                decode(b)

    def test_negative_nested_and_string_offsets(self):
        b = nested_fixture()
        b[64:76] = b[176:188]
        struct.pack_into("<i", b, 160, -96)
        struct.pack_into("<i", b, 68, 128)
        b[152:158] = b"b.pap\0"
        struct.pack_into("<i", b, 216, -56)
        p = decode(b)["rows"][1]["payload"]
        self.assertEqual(p["entries"][0]["actors"][0]["resources"][0]["literal_path"], "b.pap")
        for field in (160, 68, 196, 216):
            bad = b.copy()
            struct.pack_into("<i", bad, field, -1000)
            with self.subTest(field=field), self.assertRaises(DecodeError):
                decode(bad)

    def test_unterminated_and_string_budgets(self):
        b = nested_fixture()
        b[224:] = b"x" * (len(b) - 224)
        with self.assertRaises(DecodeError):
            decode(b)
        for name, limit in (("MAX_STRING", 3), ("MAX_STRING_TOTAL", 3)):
            with patch("tools.asset_lab.decode_cutb_bindings." + name, limit), self.assertRaises(DecodeError):
                decode(nested_fixture())

    def test_nested_aggregate_and_join_budgets(self):
        for name, limit in (("MAX_RECORDS", 3), ("MAX_JOINS", 0)):
            with patch("tools.asset_lab.decode_cutb_bindings." + name, limit), self.assertRaises(DecodeError):
                decode(nested_fixture())

    def test_unknown_kind_does_not_read_pointer_or_claim_pap(self):
        b = nested_fixture()
        struct.pack_into("<I", b, 208, 99)
        struct.pack_into("<i", b, 216, -1000)
        resource = decode(b)["rows"][1]["payload"]["entries"][0]["actors"][0]["resources"][0]
        self.assertEqual(resource["literal_path"], "UNKNOWN")
        self.assertNotIn("candidate_request_calls", resource)

    def test_unknown_selector_has_no_speculative_minimum(self):
        b = fixture()[:65]
        struct.pack_into("<i", b, 52, 16)
        b[64] = 99
        records = decode(b)["rows"][0]["payload"]["records"]
        self.assertEqual(records[0]["actor_fields"]["identity_u32"], "UNKNOWN")

    def test_supported_selector_requires_each_field(self):
        b = nested_fixture()[:140]
        struct.pack_into("<I", b, 8, 1)
        with self.assertRaises(DecodeError):
            decode(b)

    def test_valid_negative_subtable_and_resource_table(self):
        b = nested_fixture()
        b[64:76] = b[192:204]  # subentry precedes entry
        struct.pack_into("<i", b, 180, -112)
        struct.pack_into("<i", b, 68, 144)
        self.assertEqual(decode(b)["actor_resource_joins"][0]["subentry_offset"], 64)
        b = nested_fixture()
        b[64:76] = b[208:220]  # final resource precedes subentry
        struct.pack_into("<i", b, 196, -128)
        struct.pack_into("<i", b, 72, 160)
        self.assertEqual(decode(b)["actor_resource_joins"][0]["resource_offsets"], [64])

    def test_nested_count_bomb_with_valid_table_spans(self):
        b = nested_fixture()
        b.extend(b"\0" * (400 + 4096 * 12 - len(b)))
        struct.pack_into("<ii", b, 160, 240, 4096)
        # Both arrays fit in the file, but their aggregate plus CTAL exceeds cap.
        struct.pack_into("<Iii", b, 400, 7, 0, 4096)
        with self.assertRaisesRegex(DecodeError, "aggregate record"):
            decode(b)

    def test_all_supported_resource_kinds(self):
        for kind in range(4):
            b = nested_fixture()
            struct.pack_into("<I", b, 208, kind)
            resource = decode(b)["rows"][1]["payload"]["entries"][0]["actors"][0]["resources"][0]
            self.assertEqual(resource["literal_path"], "a.pap")
            self.assertEqual(resource["kind0_rewrite_capable"], kind == 0)


class ResourceClaimScopeTests(unittest.TestCase):
    def test_request_is_candidate_not_execution(self):
        b = nested_fixture()
        struct.pack_into("<I", b, 208, 1)
        r = decode(b)["rows"][1]["payload"]["entries"][0]["actors"][0]["resources"][0]
        self.assertEqual(r["candidate_request_calls"], ["0x141c93ee3"])
        self.assertEqual(r["request_execution"], "UNKNOWN")
        self.assertNotIn("request_call", r)

    def test_no_selector15_match_does_not_claim_actor_absence(self):
        b = nested_fixture()
        b[80] = 99
        j = decode(b)["actor_resource_joins"][0]
        self.assertEqual(j["match_status"], "NO_SELECTOR15_STATIC_MATCH")
        self.assertIn("selector15 static", j["identity_provenance_scope"])

    def test_rewrite_uses_native_byte_predicate(self):
        from tools.asset_lab.decode_cutb_bindings import kind0_rewrite_predicate
        self.assertFalse(kind0_rewrite_predicate("bg/foo.pap"))
        raw = bytearray(b"a" * 46)
        raw[6], raw[37], raw[41] = ord("h"), ord("c"), ord("m")
        self.assertTrue(kind0_rewrite_predicate(raw.decode()))
        self.assertFalse(kind0_rewrite_predicate(raw[:45].decode()))
        raw[6] = ord("a")
        self.assertFalse(kind0_rewrite_predicate(raw.decode()))
        # UTF-8 prefix makes codepoint indices differ from the native byte indices.
        raw = bytearray(b"a" * 46)
        raw[:2] = "é".encode()
        raw[6], raw[37], raw[41] = ord("h"), ord("c"), ord("m")
        self.assertTrue(kind0_rewrite_predicate(raw.decode()))


if __name__ == "__main__":
    unittest.main()
