# CUTB native bindings ? partial structural acceptance

Base: `6e11e44c4009f095148e0c15520d25a8b8aeccd2`; four frozen seed files,
not a new source commit. All 96 remain **OPEN**, `all96_accepted=false`.
Pins, exact addresses/formulas, both actual results and compact joins are in
[cutb-native-bindings.json](cutb-native-bindings.json).

The decoder now reads selector-15 fields and three bounded CTPA table levels.
These are offline rawbyte-derived windows, not native execution. Windows can
include adjacent functions/data/fragments; lookup tables are data and pdata
fragment ends do not establish logical function ends.

Observed static evidence:
- `1418c35f3/35f9` read record+4/u8 selector. Tables `1418c4028/3ff0`
  map selector 15 (index 14) to slot 5 and `1418c366f`.
- Packed identity is `(u32[record+4]<<32)|(selector<<8)|0xfe`.
  Reuse branch `1418c368c/3693` copies it to object+78, hence +7c.
  **Correction:** staged `141bf10e0..1133` calls `1418c3480` at `141bf10e9`;
  it does not show the allocating identity copy. That base constructor is absent.
  Equality joins below do not prove every allocating/runtime branch.
- `141bf1240/12f0` establish record+34 subselector and +3c/+40 field reads.
  Full staged 12f0 window and both switch tables were inspected. Neither the
  integers nor selectors 2/3/4 independently identify ModelChara/tablekind.
- `1418d1580/1590` store/get controller+c0. Callers `141c075d3/07812`
  lead to count=i32[payload+4], entries=payload+i32[payload], stride 12.
  Entry u32[0] compares with eventdata+8 (semantic name UNKNOWN).
- Entry count=i32[entry+8], subtable=entry+i32[entry+4], stride 12;
  subentry u32[0] compares with object+7c. Matched subentry flows through
  `141900860` into `141c304d0`: count=i32[subentry+8], final table=
  subentry+i32[subentry+4], stride 12, calling `141c93d20`.
- Final record kind=u32[0]; string=record+i32[record+8], bounded NUL.
  Kinds 0/1/2/3 have inspected request branches; record+4 remains UNKNOWN.
  Kind 0 is rewrite-capable only; static predicate uses byte length>45 and bytes
  [6]/[37]/[41]=h/c/m. candidate_request_calls never proves execution;
  kind 1 may dedupe-skip and all kinds may lack runtime context. Literal equality is not proof
  of the final resolved path, actual body, SKLB, or playback.

Actual probes, separate from synthetic tests:
- bosomg00210: 22 selector-15 CTAL records; 6 CTPA entries, 54 actor tuples,
  5 resources; 4 literal occurrences match the pinned m0110 PAP.
- bosomg00220: 29 selector-15 CTAL records; 9 entries, 74 actor tuples,
  25 resources; 9 occurrences match pinned m0771/m0424/m8277 PAPs.
- All 128 tuples have local CTAL identity matches in these inputs. NO_SELECTOR15_STATIC_MATCH
  means no supported local equality, not actor absence.
  Exact `raw/` + literal equality must match a manifest PAP in the source's
  owning directory; no roots or models are inferred from filenames.
- CTAL rows are local record/object mappings, not final retained controller
  state: overwrite/reallocation remains possible. File order is not dispatch order.

Validation: 4 seed pins and 23 input pins verified before probes; 27 tests pass
(13 unchanged safety tests plus 14 nested/identity/claim regressions). Both CLI
outputs are only in ignored `probe-output`; saved results match them. All 23
source pins are unchanged afterward. Binary instruction verification is separate parent evidence, not runtime.
Limits: 16 MiB/file, 4096/row or table count, 8192 aggregate records and join
references, 2048 bytes/NUL string, 1 MiB aggregate strings; signed displacements,
per-read bounds, unknown selector/kind preservation. Negative counts/invalid UTF-8 fail closed, stricter than native.

Next shortest dependency: stage `1418c3480` only to close allocating identity
provenance. Model/tablekind and SKLB remain independent missing links.
No runtime, desktop, import/export, commit, push, or deployment was performed.
