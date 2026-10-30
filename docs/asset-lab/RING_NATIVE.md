# Native radial runtime boundary

**STATIC_PARTIAL.** The typed runtime chain now reaches the scalar evaluator and
caller-side host argument. The sentinel's initialized header and the downstream
host formula remain unproved. Rendering/all96 remain false; no shader is authorized
by this evidence alone.

## New runtime source facts

1. Runtime factories `0x1403be220` and `0x1403cc560` select signed descriptor
   byte `+4`, range-check against 9, and use tables `0x1403be4cc` / `0x1403ccc70`.
   Entry 7 reaches `0x1403be301` / `0x1403cc665`: allocate `0x248`, pass the same
   descriptor as argument 5, call `0x1403c9b80`. Both select a `0x18`-stride
   descriptor from resource `+0x48`; original runtime activation is unobserved.
2. Constructor `0x1403c9b80` forwards that descriptor through base constructor
   `0x1403c6c10`, which stores it at runtime `+0x228` (`0x1403c6c7e`). It installs
   vtable `0x142161700` and calls sampler `0x1403c9c40`, using runtime float
   `+0x1c8/+0x1cc` inputs. Their clock units/epoch are not established.
3. Sampler reads `outer=[runtime+0x228]`, `radial=[outer+0x10]`. For IRad,
   `0x1403c9d06` loads `[radial+0x18]`; `0x1403c9d0a` passes the **slot address**
   in RCX. Dword curve header bits 7–8 select table `0x14215cc10`;
   call `0x1403c9d1b` returns XMM0, stored by MOVSS at runtime `+0x23c`
   (`0x1403c9d27`). Len/Str/Gra/ORad similarly populate `+0x230/+0x234/+0x238/+0x240`.
4. Vtable slot `+0xf8` points to `0x1403c9d80`, which resamples, then tests
   bit 13 of word `[[runtime+0x1f8]+0x4a8]`. When enabled, `0x1403c9f00` loads
   IRad from `+0x23c`; `0x1403c9f4c` writes caller RSP+0x20; `0x1403c9f5a`
   calls `0x1403b64a0`. Thus IRad is **argument 5** (callee entry RSP+0x28).
   CHAININFO joins callback fragments `0x1403c9dbc` and `0x1403c9f7f` to
   `0x1403c9d80`; they are not standalone functions.

The host call receives RCX from `0x1403b4f80`, Len/Str/Gra in XMM1/2/3,
IRad/ORad in arguments 5/6, then a position-related pointer, a base-position
pointer, FSDc, FEDc and a context dword. FaBP=0 takes TLS position fields;
FaBP=1 tries a virtual position call and falls back to TLS on failure; other
values leave the initialized zero base vector. This is caller-side evidence,
not identification of the final shader parameter or its formula.

## Evaluator contract and counterevidence

| Header selector `(header >> 7) & 3` | Exact observed behavior |
|---|---|
| 0 | `0x140396bd0`: MOVAPS XMM0,XMM3; RET. Radial sampler supplies XMM3=+0.0f. |
| 1 | `0x140396be0`: curve=*RCX; MOVSS XMM0,[curve+4]; RET. |
| 2 | `0x140396bf0`: time/key wrapper; downstream evaluators not followed. |
| 3 | Not validated: fourth qword after the three pointers is string data. No safety fallback proved. |

Selector 2 chooses incoming XMM1 when header bits 2–3 are below 2, otherwise
XMM2. It masks key times with `0x3fff`, converts to float, uses COMISS/JBE,
and dispatches pre/post/in-range paths. The wrapper uses scalar single-precision
SSE; complete interpolation/extrapolation order, FP environment and exceptional
input behavior are unresolved. The JSON retains exact instruction/table joins.

**No unconditional absent-IRad numeric default follows.** If the shared
`0x142aa7d78` header selects 0 at consumption, the original absent IRad yields
+0.0f and passes that value as host argument 5 when enabled. Its initialized
header is still unknown; PE zero-fill and loader header flag processing do not
supply that proof. A selector-1 curve instead returns stored data, and selector 2
uses time/key evaluation. Constructor storage, evaluation and render acceptance
are distinct.

## Remaining join and next method

Stop this trace at host call `0x1403b64a0`; inspect its bounded pdata/chained
body next, tracing incoming argument 5 to exact writes or forwarded arguments.
Separately establish the sentinel initializer/header before choosing a numeric
default. Reuse these typed targets instead of more sentinel loader references or
named-host strings. Actual callback scheduling, gate meaning, action31567 active
samples, lifetime, normalization/fade/projection and shader acceptance remain open.

## Scope and validation

Frozen handoff SHA256:
`3435f02483bfcd52c5fd91754c99f7b63f0ffb4f7786862a775b2f11392b67a5`.
All 103 protected LF source pins, 86 raw readonly pins and original 55 native spans
were verified before use; initial native pins and source findings remain intact.
Binary identity remains SHA256
`46a52ab1dbe80b9a8d6c4d4531bf66693904200c5135facacd053ef28a5de14a`;
no product-version resource was extracted. Capstone 5.0.6.

One operand locator over `0x140360000..0x140430000` produced 54 candidates;
this is neither exhaustive xrefs nor a complete control-flow analysis. The two
runtime factories were then followed through bounded direct call/table/field
joins. No global scan, oversized host function, desktop, game, export or commit.
Private raw bytes, disassembly, exact VA/size/SHA, unwind records, guarded receipts
and scope ledger are under `top/assets/official/top-ring-runtime-50976`.
The factory pdata span contains an inline jump table; its decoded table bytes
are not code evidence. The second factory is explicitly a partial function.

The POSIX work guard is unavailable here. Serial children used the pinned
Windows Job Object runner, 45 seconds each, 1.5 GiB cap and 8 GiB free floor.
A private filename initially shadowed Python's inspect import, repeating only
readonly preflight reads during the sole locator; it was renamed, with logs
preserved. No native child failure/timeout occurred. Existing failed UUIDs in
prior evidence remain readonly. The verifier establishes pins/spans, not semantics.

Current verifier result UUID `22b69071-86cf-4f80-9f5b-af6fe296efbf`: **PASS**
103 protected source pins and 89 native spans (11 new code spans, 2,863 code
bytes; 23 new table/pdata/unwind records). Cumulative guarded children through
the verifier and document extension: 4.7248 seconds; final review separately
receipted. This is a pin/span gate, not semantic acceptance.

The earlier snapshot below is retained verbatim except its heading. Its
first-runtime-consumer uncertainty is superseded by the new joins above;
its numeric-default and render limitations still apply.

---

# Accepted loader evidence (historical snapshot)

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
