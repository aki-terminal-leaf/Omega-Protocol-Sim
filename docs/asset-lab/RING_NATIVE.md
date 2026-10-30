# Native radial source boundary

**STATIC_PARTIAL.** The EfVT=7 selector-to-loader join is proven; the first
runtime consumer and its numeric fallback remain open. No rendering/all96 acceptance.
Binary SHA256: `46a52ab1dbe80b9a8d6c4d4531bf66693904200c5135facacd053ef28a5de14a`.

## Source facts

Enclosing loader entry `0x1403ab860` reads EfVT into outer byte `+4` at
`0x1403ab919..0x1403ab91e`. Data dispatch at `0x1403ab926..0x1403ab93f`
indexes the image-relative table `0x1403ac2f0`; entry 7 is `0x003abb25`.
Thus type 7 reaches `0x1403abb25`. Its unwind entry has CHAININFO to
`0x1403ab860`; the fragment is not a standalone function.

The materializing path allocates `0x38` bytes and stores its pointer into outer
`+0x10`. The separate size-count path writes a null outer pointer; that does not
describe the materialized curve slots.

| Radial offset | Width | Field / initialization |
|---|---|---|
| +0, +8, +0x10 | 8 each | Len, Str, Gra: shared pointer |
| +0x18, +0x20 | 8 each | IRad, ORad: shared pointer |
| +0x28 | 4 | FSDc: bits `0x42480000` (50.0) |
| +0x2c | 4 | FEDc: bits `0x42960000` (75.0) |
| +0x30 | 4 | FaBP: zero; present field loads signed i8 into i32 |

**Absent IRad retains `0x142aa7d78`, not a null pointer or a proven numeric zero.**
R10 is defined by LEA at `0x1403ab8a1`, restored at `0x1403abacb`, and stored
at radial `+0x18` by `0x1403abbb5`. No intervening call lies on that dispatch
path. Only a present IRad sends that slot through `0x1403abc30` to the common
curve loader `0x140396660` (call `0x1403abbe6`).

That helper allocates curve storage, writes a qword pointer to the slot, or
preserves the existing pointer when no allocation is produced
(`0x14039682c..0x14039686f`). It then reads the pointed-to header and updates
key-count flags. This confirms pointer-backed storage; it is **not** the first
render consumer of absent IRad, since absence skips this helper for that field.

The pinned original has EfVT `07000000`, no IRad, and four-byte FaBP `00000000`.
Native `0x1403abc36` uses `movsx eax, byte ptr [rbx]`, then stores a dword at
`+0x30`. Preserve that signed-i8/native versus serialized-i32 distinction;
the current zero sample cannot establish general equivalence.

## Hypothesis and unresolved join

The common address plausibly denotes a shared default/empty curve. It falls
in virtual-only `.data`; file zero-fill does not prove runtime contents or
the evaluator's result. A raw read correctly failed and was retained.

The exact missing join is **outer +0x10 -> radial +0x18 -> first runtime curve
evaluator -> host IRad parameter**. No direct consumer reference was obtained
within the bounded supplied paths. Determine what that evaluator returns for
`0x142aa7d78`, including prior initialization, before assigning any numeric
default. Next render question: which host parameter receives that result and
which normalization/fade/projection formula uses it? RadialBlur string names
do not establish this handoff. No shader, lifetime or clock claim follows.

## Evidence and verification

Frozen handoff SHA256 `eec3bfec12233788d62c6d65f98ca4bc3ecfe3b5438d4ad09a66be0f260174cf`;
all 103 LF-normalized source pins and 15 raw readonly pins verified unchanged.
The locator file actually lists ten candidates (the request says nine); only
those supplied entries, their enclosing/chained fragments, dispatch table and
direct curve-helper path were inspected. No broad binary/reference scan.

`ring-native.json` records exact raw VA/length/SHA spans. Private evidence in
`top/assets/official/top-ring-native-50976` includes Capstone 5.0.6 byte/instruction
lines, unwind joins, table, source inventory, exact guarded command receipts and
`trace-ledger.json`. Failed UUID `fb44b990-65e4-427b-af8f-3591316290e9` records
the non-file-backed address read; follow-up omitted it and recorded PE sections.
Windows children use the pinned 1.5 GiB Job Object / 8 GiB free floor and 45-second
limit, serially. The POSIX work guard is unavailable on this Windows host.

The staged verifier checks source pins and spans only; semantic claims require
parent review. No commit, publication, game or desktop operation was performed.

Verifier command: `C:/Python314/python.exe -B D:/Dev/OpenClawCodexBridge/probes/top-ring-native-50976/accept.py --worktree D:/Dev/OpenClawCodexBridge/worktrees/top-ring-native-50976`.
Result UUID `1d760d06-9678-4f35-a1ae-83ee53cf89d9`:
`PASS_PINNED_SOURCE103_AND_NATIVE_SPANS_ONLY_NOT_SEMANTIC_ACCEPTANCE`;
55 spans, 14,700 bytes. Six native probe children (including the failed read)
used 1.5441 seconds; verifier child used 0.1567 seconds. The 55 unique records
comprise ten supplied candidates, 32 enclosing/unwind records, and 13 further
records along the bounded dispatch/helper path. No third-hop consumer was found.
