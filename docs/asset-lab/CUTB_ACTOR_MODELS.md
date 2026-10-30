# CUTB actor to named-sheet candidates

Base `6e11e44c4009f095148e0c15520d25a8b8aeccd2`; source evidence only.
All96 **OPEN**; runtime **NOT_RUN**. Four frozen seeds are unchanged.
[Numeric/source proof](cutb-actor-models.json) includes both actual CUTB SHA256s,
all 37 input/seed pins, 4 PAP hashes, all 13 occurrences and all 6 distinct actors.
Offsets identify source records, not event timelines. Canonical corrected seed
metadata supplies occurrence equality; no CTPA decoding was repeated.

## New join

`root.exl` proves IDs 97=ENpcBase, 96=ENpcResident, 46=BNpcBase,
38=ModelChara. These names are read from the installed source, not inferred
from million-valued keys or model filenames.

CUTB | CTAL index | identity | subselector | field40 / ENpcBase | ModelChara candidate
---|---:|---:|---:|---:|---:
00210 | 2 | 4278190083 | 4 | 1016731 | 327
00210 | 3 | 4278190084 | 4 | 1016731 | 327
00220 | 22 | 4278190103 | 4 | 1026375 | 2328
00220 | 23 | 4278190104 | 4 | 1024748 | 2147
00220 | 24 | 4278190105 | 4 | 1044653 | 3524
00220 | 25 | 4278190106 | 4 | 1044653 | 3524

All six are conditional static joins, with runtime choice unresolved. No actor
with a pinned PAP occurrence was omitted. Subselector 0 remains unsupported;
no such actor occurs in this six-actor subset.

## Exact native scope

Allocation is now closed: 1418c348a saves RDX in RBX; 34af loads [RBX];
34b7 stores object+78. The selector-15 constructor calls this base constructor.
Thus packed record+4 high32 reaches object+7c on allocation as well as reuse.
Record+34/+40 reach object+8c/+94 at 141bf1351..135d.

**Correction to task lead:** 141bf13c5 decrements the subselector before
indexing 141bf2004. Actual table bytes map 2 to 141bf15b6, 3 to 141bf1678,
and **4 to 141bf147f**, not 1678. For 4, nonzero object+94 makes kind 8
at 14cb and copies that key to descriptor+30 at 14da. Zero does not build it.
For 2, kind 8 uses field40 when 14079aff0 returns null or record+44 is nonzero;
otherwise kind 0x25 uses an existing actor key (zero-key fallback retains 0x25).
For 3, runtime context can supply a kind-8 key when 141c03ba0 returns 2 and
141c03be0 result byte+4 is nonzero. Otherwise a valid selected actor with
record+44==0 supplies kind 0x49; kind-8 fallback uses field40 when record+44
is nonzero, or literal 0xfca82 when no selected actor and flag is zero.
Zero descriptor keys are discarded. These are branch predicates, not claims
that runtime context exists or that any branch executed.

141bf1d32 recursively calls 1418c35d0. Kind 8 reaches 1418c3948 and
constructor 141bf3570 installs vtable 142456d40. Exact table bytes give
vtable+178=141bf36c0, which jumps to 141bf38b0. At 1418c3a54 EDX receives
descriptor+30 only when the alternate context/call path at 3a20..3a4a is not
selected. The inner switch uses object+79 minus 8: kind 8 goes to 141bf3993,
then 1408d1600; kind 9 goes to 141bf39c2 and 1408d22a0/BNpcBase.
Key zero or allocation result -1 exits before setup.

1408d1600 writes character kind 3 and key+84, then accesses ENpcBase(key)
via 140836220 and ENpcResident(key-1000000) via 140836260. Both must return
non-null. At 1408d1aae it reads u16[ENpcBase+0xbe]. The default model branch
passes this value at 1b04/1b09 to 1408d0fa0; 0fd6 calls 140837840, whose
sheet ID is 0x26. If r14 exists and 141a1a200 returns false, 1ac7 instead
passes runtime r14+0xac. Therefore the table row is a candidate, not final choice.
The staged setup end 1c00 is a window boundary, not the logical function end.

## Schema correction and limits

Parent resolved the apparent mismatch using pinned upstream
`Lumina.Excel` f79754d7659243cbc2b2a0d9ec55c66319aa42a9,
`SchemaSourceConverter.cs`: fields are matched after ordering EXH columns
by byte offset, then type. Raw EXH column index is NOT schema field index.
The schema commit's `.github/columns.yml` exactly equals all 110 ENpcBase,
27 BNpcBase and 23 ModelChara raw type/offset entries. No guessed reordering.
ENpcBase ModelChara is raw column35/u16/+190. ModelChara fields are
Model=column1/u16/+12, Type=column0/u8/+16, Base=column2/u8/+17,
Variant=column3/u8/+18, AnimationVariant=column5/u8/+19.

Independent raw EXD index/row-byte reads reproduce all ten source hashes:
327 -> type3/model110/base1/variant1; 2147 -> type3/model424/base2/variant1;
2328 -> type3/model8277/base1/variant1; 3524 -> type3/model771/base1/variant1.
AnimationVariant=1 for all four. These are SOURCE TABLE CANDIDATES,
not final runtime selection, exact MDL existence, or skeleton proof.

The original column46/row0 probe and SyntaxError log remain preserved;
the frozen original docs are superseded by this explicit parent correction.
Four seed files remain unchanged. Parent checked all33 inputs, six actors,
13 PAP occurrences and 8668 native instruction-byte records against sources.
No runtime, desktop, conversion, commit, push or deployment occurred.
Next: original MDL/material/SKLB closure and PAP-bone compatibility.
P6-01a/b/c,21/22/23, P1 transition, shaders/camera/sequences/raster/export
and all96 remain OPEN; CoUF units UNKNOWN. No new synthetic tests.
