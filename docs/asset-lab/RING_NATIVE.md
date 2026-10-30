## GPU follow-up: bounded typed query (schema 1)

**STATIC_PARTIAL; rendering_accepted=false; all96_accepted=false.** This addendum
supersedes only the historical allocation-writer blocker below. All accepted
findings and native history are retained; no implementation or tests changed.

The successful `0x1403920e0..0x14039227a` path allocates 0x260 bytes, retains
RAX in RBX, installs vtable **0x14215fac0** at 392138, initializes fields and
publishes RBX to `[0x142aa75d8]` at 392226. Failure publishes zero. These are
pointer/type facts, not GPU binding or runtime timing.

The one completed exact-G query covered **8,455 pdata fragments / 1,890,576
bytes**, range `[0x140300000,0x140500000)`: 74 exact RIP loads, 83 typed memory
accesses, 17 radial writes and two radial reads. At `38a5d0`, RCX receives G;
`38a5db` reads f32 `[RCX+46ac]` and `38a5e3` multiplies by f32 `[RCX+46a4]`.
These are the accepted CPU arbitration path. No downstream radial GPU reader
was proved. No typed access overlapping the actual bit9 word G+4470/4471 was
found in the retained accesses. This negative is confined to the query.

Provenance propagates 64-bit MOV aliases and unindexed LEAs, distinguishes
READ/WRITE/LEA and width, and dies on overwrite, call, branch, return, or local
branch target. It does not cross fragments, spill slots, calls or branches,
or interpret arbitrary pointer arithmetic/scalar bit propagation. Selected
fragments decoded fully. No claim excludes a consumer outside this coverage.

The installed vtable's first 16 qwords (slots 0..78) were inspected; its total
length is unknown. Slot0 `4095d0` cleans up and conditionally frees size260;
slot28 `40cfe0` jumps through `[this+28]`; the other inspected entries handle
flags, callbacks, synchronization and this+80/+d0 storage. None proves a
radial-field/GPU join. The four small outside-subsystem slot targets were read
directly; no recursive call expansion or name survey was made.

One concrete typed G hop is `38989b -> 3898af -> 3630c0`: RCX retains G into
the tailcall, `3630cf` loads `[G+4c8]`, and `3630df` dereferences that pointer.
Later TLS-array writes are a resource candidate only: their radial relevance,
resource identity and bytecode selection remain unknown. The +1498/88038
allocation and the 3889a0 same-offset counterexample remain excluded.

**Actual contract:** allocation/vtable identity and the existing CPU packet.
**Conditional contract:** resource, constant buffer, selected bytecode,
textures, convolution, projection and blend are all unknown. No numeric
IRad/default/clock/lifetime or reset-timing claim is added.

**Smallest blocker:** the radial-packet-to-GPU join. Exact next source needed:
pdata/unwind continuation at **0x14036a565**, following G->RBX at **0x14036a550**
in fragment **0x14036a540**, with call/branch-aware provenance review. The
captured prefix ends after LEA RCX,[RBP-40]; this is an entry lead, not an
asserted radial consumer. Do not repeat the equivalent subsystem scan.

The frozen handoff `fbfcd1dd0bad972865e73bb0426a1caea9be62ec3e97591d140f49e5f1dd5cef`
passed all105 initial LF files, all173 native records and all311 raw readonly
pins before analysis. Exact commands, spans, hashes, aliases, widths and guard
receipts are in `ring-native.json` / `gpu_contract_audit`; private evidence is
under `top/assets/official/top-ring-gpu-50976`. Children were serial, capped at
45s, with the pinned 1.5GiB Windows Job Object, 8GiB free floor and pycache off.
The retained import-path failure occurred before the query; the leaf-reader
failure was corrected to recognize a tail-jump, retaining earlier captures.
No failed logs were removed. The initial shell display truncation was avoided
for verification by full JSON parsing. Gates check pins/spans only, not semantics
or runtime acceptance. No commit, export, game, desktop or browser operation.

---

# Native radial target binding checkpoint (schema 1)

**STATIC_PARTIAL; review_required=true; rendering_accepted=false; all96_accepted=false.**
The owner-slot-to-CPU-consumer join is now explicit. The target allocation's
constructor and original GPU resource/shader contract remain unproved. No product
behavior changed, no native game execution occurred, and no original action sample
was observed. This is a source checkpoint for parent review, not a renderer contract.

## Newly proved joins

- Registration entry is `0x1403b7b50`. Unwind records at `0x142612044`,
  `0x142611ff4`, `0x142611fdc`, `0x142611fd0` chain the setter fragment through
  `0x1403b7bd1` and `0x1403b7b7c` to that entry. At `0x1403b7b63`, RSI receives
  argument 2 (RDX); R15 receives owner RCX at `0x1403b7b69`. Entry saves RDX at
  entryRSP+0x10. CurrentRSP is entryRSP-0x68, so the loop's restoration from
  currentRSP+0x78 at `0x1403b7d1e` restores the same argument pointer. The successful
  path loads `[RSI+8]` at `0x1403b7d78` and stores it to owner+0x1490 at
  `0x1403b7d83`. Early registration failure paths remain conditional.
- Wrapper `0x140379200` preserves its caller's descriptor, calls owner getter
  `0x1403b4f80`, then passes owner in RCX and descriptor in RDX to registration
  by tail jump `0x14037922f`. A concrete second caller at `0x140392539` passes
  owner `0x142aa7e00` and descriptor `0x142aa75e0`. Instructions `0x140392491`
  and `0x140392498` copy `[0x142aa75d8]` to descriptor+8 (`0x142aa75e8`). The
  writer/constructor establishing that source global remains unknown.
- Consumer caller `0x1403795d0` gets that same singleton owner, retains it in
  RBX, performs dispatch, then **loads RCX=[owner+0x1490] at `0x1403795f3` and
  tail-jumps to `0x14038a580` at `0x1403795ff`**. The independent path
  `0x140393547 -> 0x140393564 -> 0x140393574` does the same. Wrapper
  `0x1403b8af0` also forwards its incoming owner's +0x1490 at `0x1403b8b0b`.
  These explicit pointer transfers supersede the earlier offset-only candidate
  qualification. They prove static owner-slot identity, not a particular live
  allocation/address, registration timing, or absence of replacement between calls.

The unrelated `0x88038` allocation remains owner+0x1498. It is not the radial
target. `0x1403889a0` remains a counterexample to inferring identity from offsets.
The host's conditional field packet, nullable curve/evaluator facts, exceptional
SSE behavior, and UNKNOWN actual absent IRad are unchanged.

## Render boundary and smallest blocker

The now-connected consumer still only copies CPU parameters into
`G=[0x14290e498]` and toggles bits through `0x14035c490`. The captured consumer
returns without a proved GPU upload or resource-selection call. The intervening
`0x14040cff0` stores context/callback at +0x20/+0x28, invokes dispatch helpers and
an indirect +0x18 slot, then clears those fields. Its supplied callback
`0x1403b5b90` uses owner+0x1498, TLS fields and virtual +0x78. These are concrete
scheduling boundaries, not shader bindings or lifetime proof; their untraced
callees are not claimed absent or irrelevant to the wider renderer.

Two exact missing inputs remain: the allocation writer for `[0x142aa75d8]`, and
a typed render-context entry consuming G's radial fields and binding an original
resource/constant buffer/shader. No texture, CB slot/layout, shader key/constant,
branch selection, convolution, projection or blend law is inferred. Next method:
obtain a parent-provided exact writer/constructor or typed render-context/vtable
receipt, then trace that bounded target into original bytecode/reflection. Do not
repeat this call-reference search or substitute another offset/name survey.

The descriptor/player and pinned maintained VFXEditor references were read; they
provide source fields and a numeric descriptor, not the missing shader contract.
Source clock/lifetime remain OPEN. Parent CRT evidence is a separate readonly
lead: 1152 nonzero absolute VA entries and file dispatch
`14210de90 -> 1421060b0 -> [14210de88]=142106090 -> JMP RAX`. Runtime guard patching
is unobserved, and the prior prefix locator is not absence proof. No initializer
work was repeated here.

## Evidence and checks

Frozen input SHA256:
`ba8208e0d8122006440a5765098d14faa08920608beab6033b59993fa546786e`.
Preflight verified all 105 initial LF files, all 245 raw readonly files, binary
identity and all 137 initial native spans before tracing. All 103 protected files
and previous span records remain intact.

Exactly one direct CALL/JMP-immediate search used executable pdata fragments in
`[0x140300000,0x140500000)`: 8,455 entries, 1,890,576 input bytes, targets
`0x1403b7b50` and `0x14038a580`, five retained hits. Indirect calls, other ranges,
leaf gaps and aliases were not searched; there is no absence claim. Only one
external typed direct hop (`0x14040cff0`) was followed, without recursive expansion.
Explicit aligned captures have fixed limits and may include chained fragments or
padding; they do not assert complete function coverage.

Added 15 CODE spans / 4,309 bytes and 21 metadata records; cumulative acceptance
inventory is 173 records / 40,330 bytes. Exact addresses, byte hashes, disassembly,
commands, resource receipts and artifact hashes are in `ring-native.json` and
ignored `top/assets/official/top-ring-binding-50976`. Serial pinned Windows Job
Object children use 45 seconds, 1.5 GiB cap, 8 GiB available floor and pycache off.
No native child failed; earlier failed probes remain immutable. The first shell
manifest display was truncated; structured preflight verified every entry.

Staged pin gate command:
`C:/Python314/python.exe -B D:/Dev/OpenClawCodexBridge/probes/top-ring-binding-50976/accept.py --worktree D:/Dev/OpenClawCodexBridge/worktrees/top-ring-binding-50976`.
Its result is recorded in the JSON after execution; it checks protected source and
native byte hashes only. Parent independent semantic review remains required.
No commit, push, merge, export, game, browser, desktop, input or audio action.

---

The following accepted history is retained. Its unresolved consumer/RSI statements
are superseded only by the joins above; allocation/GPU/runtime caveats remain.


# Native radial host packet and render boundary (schema 1)

**STATIC_PARTIAL; review_required=true. rendering_accepted=false; all96_accepted=false.**
The host's conditional CPU field packet is now specified from instructions and
original constant bytes. A coherent downstream CPU parameter consumer is located,
but its input-object identity and GPU upload/resource/shader join remain unproved.
The actual absent-IRad initialized header/value is still unknown. Product behavior
has not changed; this is not an implementable complete renderer contract.

## Verified inputs and source boundary

Frozen handoff SHA256 `cbc09d61caeffac20d6068cf937401b84ea270b6727217ddeb8d5f8959e38466`.
Preflight verified all 105 initial files (103 protected LF hashes plus both native
documents against the frozen seed), 160 raw readonly files, binary identity and
all 89 initial native spans. All accepted findings/spans below remain retained.
The corrected parent v4 host input is the pinned
`parent-host-07f4885e-56c3-4dd3-a4b4-d3859bc7d238/source/spans.json`, alongside
`parent-host-adjudication-v1.json`; the first incomplete captures were not used
as replacement evidence. Host range `[0x1403b64a0,0x1403b68ad)` is 1,037 bytes.
Seven pdata fragments chain to its entry; `0x142611ce8` requires 36 unwind bytes.

Inspected protected `original_ring_action.gd`, `asset_lab_radial_effect.gd` and
`source_avfx_player.gd`, plus pinned maintained VFXEditor Enums/Effector/RadialBlur
sources. The radial evaluator preserves absence and exposes a numeric descriptor;
`original_ring_action.radial_descriptors()` exposes it without a native renderer.
The maintained labels identify Len/Str/Gra/IRad/ORad/FSDc/FEDc/FaBP, not shader
semantics. No source or test implementation was edited.

## Conditional host packet

Getter `0x1403b4f80` returns owner `0x142aa7e00`, with lazy construction through
`0x1403b4a40`. That constructor zeros owner+0x1490. Setter `0x1403b7d83` later
copies `[RSI+8]` into `[R15+0x1490]`; the supplier's construction/registration is
not established. Do not call the owner's unrelated `0x88038` allocation the
radial target allocation. Host selects `target=[owner+0x1490]`.

Push RDI/sub RSP,0xd0 gives currentRSP=entryRSP-0xd8. Arguments: RCX=owner;
XMM1/2/3=Len/Str/Gra (saved current+e8/f0/f8); stack IRad/ORad at +100/+108,
point/base pointers +110/+118, FSDc/FEDc +120/+128, unsigned selection dword +130.

Let T be the pointer loaded from the indexed TLS slot +0x2e0, P=(x,y,z).
T+0x1c8 must be nonzero. Below each mul/add/sub/div is a **separate scalar
binary32 SSE operation**, in written parentheses order; no FMA or double algebra:

```
X = (((y*T[f8]) + (x*T[e8])) + (z*T[108])) + T[118]
Y = (((x*T[ec]) + (y*T[fc])) + (z*T[10c])) + T[11c]
Z = (((x*T[f0]) + (y*T[100])) + (z*T[110])) + T[120]
W = (((x*T[f4]) + (y*T[104])) + (z*T[114])) + T[124]
```

COMISS W,+0 / JBE skips W<=0 and unordered (assuming masked exceptions).
Distance subtracts base from y,x,z separately, squares separately, adds `(dy²+dx²)+dz²`,
then SQRTSS. UCOMISS 0,sum / JA instead calls `0x141de72c8` for an ordered negative
sum; that helper was not followed. Effective end E is MAXSS(FEDc,FSDc+epsilon).
COMISS E,distance / JB skips beyond E and unordered. Matrix semantics, TLS provenance
beyond these fields, MXCSR and actual action samples remain unobserved.

| Original constant VA | Little-endian bytes | Meaning |
|---|---|---|
| 0x14211dd84 | 0ad7233c | epsilon bits 0x3c23d70a, 0.009999999776482582 |
| 0x14211dea0 | 00000040 | +2f |
| 0x14211dfac | 000000c0 | -2f |
| 0x14211de28 | 0000003f | 0.5f |
| 0x14211de88 | 0000803f | 1f |
| 0x14211e080 | ffffff7f repeated four times | sign-clear mask |

For ordinary finite inputs, u=X/W, v=Y/W; ex=1-abs(clamp(u,-2,2)*0.5),
ey=1-abs(clamp(v,-2,2)*0.5). Fade is 1 when FSDc>distance, otherwise
`1-((distance-FSDc)/(E-FSDc))`. Output Len is `(((ex*Len)*ey)*fade)`.
Center is `(u*0.5+0.5, 0.5-v*0.5)`. Z/W and W/W are computed but do not reach
this selected field group. These are instruction-derived formulas, not numeric
emulation or observed game behavior.

The IAT slots `0x14210d648/+8` resolve to KERNEL32 EnterCriticalSection and
LeaveCriticalSection. They receive target+0x200. Inside that section, unsigned
arg11 below target+0x1f8 skips writes; equality overwrites. The selected writes are:

| Target offset | Width | Value |
|---|---|---|
| +0x148 / +0x14c | dword / byte | mode 0 / enabled 1 |
| +0x150 | f32 | attenuated Len |
| +0x154 / +0x158 | f32 each | original Str / Gra bit copies |
| +0x160 / +0x164 | f32 each | center x / y |
| +0x170 / +0x174 | f32 each | same IR=MAXSS(+0,IRad) |
| +0x178 / +0x17c | f32 each | ORad if COMISS IR,ORad / JB; else IR+epsilon |
| +0x1f8 | dword | arg11 |

`0x140379580` resets target+0x1f8 to zero; `0x1403b88d0` clears target+0x14c
and global Len/Str. Their scheduling is not established: this is not lifetime proof.
Exceptional behavior must retain operand order: MAXSS selects its source operand
on equal/unordered, including signed zero/NaN; unordered edge comparisons select
+2, while raw center divisions can remain NaN. COMISS may trap under another MXCSR.
Very large IR+epsilon can round back to IR. A mathematical max/clamp substitution
would not preserve all these cases.

## Downstream candidate and smallest missing render join

`0x14038a580` saves input RCX in RBX and tests input+0x14c; CHAININFO connects
`0x14038a5a1`. It compares input Len*Str against the current global pair, toggles
bit9 through `0x14035c490`, and copies mode0/1 parameters into
`G=[0x14290e498]`. Exact CPU mapping:

| Input offsets | G offsets |
|---|---|
| +148 | +469c (mode) |
| +150 / +154 | +46a4 / +46ac (Str comparison-clamped 0..1) |
| +158 | +46b0 |
| +160 / +164 | +46b4 / +46b8 |
| +170 / +174 | +46bc / +46c0 |
| +178 / +17c | +46c4 / +46c8 |

This is a strong **structural candidate**, not yet proof that this RCX is the
same allocation as owner+1490. Mode2 consumes different fields. `0x14035c490`
with EDX=9 sets/clears G+4470 bit9; that is not an upload. No resource identity,
constant-buffer layout, shader selection, texture input, convolution or blend law
has been established. Offset matches also occur in unrelated mapped-buffer code
`0x1403889a0`, a concrete counterexample to equating offsets with typed identity.

Next method: trace the supplier `[RSI+8]` at `0x1403b7d83` through construction
and registration/vtable records to prove the consumer instance, then follow that
identified resource binding to shader bytecode/constant reflection. Do not repeat
a RadialBlur string scan or another subsystem offset locator.

## Actual absent-curve state and changed initializer method

Accepted pointer/slot/evaluator/host-arg5 joins remain below. The actual initialized
header at `0x142aa7d78` is **unknown**, so actual absent-IRad is **unknown**.
Selector0 conditionally returns caller +0f; selector1 returns curve+4; selector2
is still incomplete. PE zero-fill does not choose among them.

New concrete startup evidence: entry `0x141da03c0` reaches `0x141da01c8`, which
passes `[0x14210dea0,0x1421102a8)` to `0x141e18654`. That loop reads qwords and
calls through `0x14210de90`; raw table bytes and dispatch instructions are pinned.
Their initializer representation/dispatch target has not been resolved to a
sentinel write. TLS directory names callback `0x141da0b6c`, which checks thread
flag +203c4 and its initializer interval; this is not sentinel initialization proof.
No initializer was attributed from the table's numeric entries.

The sole new operand locator covered pdata-contained code in
`0x140360000..0x140430000`, including exact direct-RIP targets in the small
`[0x142aa7d58,0x142aa7d98)` neighborhood. Those returned LEAs, not a proven
initializer. This is nonexhaustive: aliases, overlapping writes from other bases,
code outside the range and indirect startup remain open. Scanning stops here.
Next method is CRT table/indirect-dispatch interpretation with initializer-specific
write provenance for sentinel bytes 0..7. If static provenance cannot be obtained,
the parent needs separately authorized startup-write evidence; no game execution
is authorized or performed in this iteration.

## Guarded results and limits

All private scripts/ASM/receipts are under ignored
`top/assets/official/top-ring-host-50976`. WindowsJobObject children are serial,
45s, 1.5GiB hard limit, 8GiB available floor, pycache suppressed; POSIX work_guard
is unavailable on Windows. One locator only. 22 unique new CODE spans / 6,710
bytes are retained, including one salvaged failed-child span; explicit chained or
leaf ranges are labeled partial. Parent host input is separate. Initial 89 pins
plus additions total 137 native spans (including six import descriptor/name/thunk pins). No broad negative-absence claim follows.

Two failed containment checks are preserved in
`native_audit-1793350024271644500` and `typed_meta-1793350041644651300`.
They exposed absent directory entries for chained/leaf starts; recovery used
unwind-derived starts and explicit bounded aligned ranges, not a wider scan.
The first failed outputs were not overwritten. Shell rg was unavailable; switched
to Select-String. Historical cp950/import-shadow/incomplete32-byte receipts remain
readonly. First staged gate passed at `66ecbb30-d68a-4f53-8efa-b424ab752d18`: 103 source pins / 131 spans. Six import identity pins were subsequently added; the final gate reruns against all 137 spans. Review and guarded receipts are recorded with the JSON.
No commits, pushes, merges, exports, game, desktop, browser, input or audio actions.

The following accepted runtime/loader history is retained. Its host-stop question
is superseded by this audit; its actual-sentinel and renderer caveats still apply.

---

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


## Function-aware frozen-seed audit (schema 1, 2026-10-30)

**STATIC_PARTIAL; GPU contract remains UNKNOWN.** `rendering_accepted=false`,
`all96_accepted=false`. No product, renderer, test, publication or runtime change.
All earlier text and JSON history are preserved; this section scopes the new result.

The frozen 74 exact G-load seeds resolve to 35 unwind roots. New normal-flow CFG
analysis covers 19 selected roots / 18,537 bytes, prioritizing the eight roots
with nonvolatile G aliases. It yields 89 typed unindexed accesses and **zero new
radial-packet or 4470/4471-word overlaps**. This is bounded coverage, not global
absence. The prior two CPU arbitration reads are not GPU evidence. Root36a540,
its seven fragments and the constructor/allocation/vtable paths were not replayed.

Only instruction fallthrough and actual direct branches connect the CFG;
unwind-parent relationships merely group fragments. Register facts intersect
at joins and iterate to a fixed point. Full-width MOV aliases and unindexed
64-bit LEAs preserve the exact displacement/load-site provenance; any other
register overwrite kills it, including partial-register writes. Under ordinary
Win64 normal-return ABI assumptions, calls preserve tracked nonvolatile GPRs
only. Scalars/SIMD values, stack spills and general indexed addresses are not
propagated. G_at_load is not proof of a current live singleton or stable fields.
READ, WRITE and LEA remain distinct; requested dwords and the flag word use
byte-range overlap. Example: seed36c792 in R14 survives call36c9e0 and supports
the READ at36c9e5 of G_at_load+4688. That is a counterexample to kill-at-call,
not radial proof.

One concrete external hop was discharged: seed430476 loads G; ADD RCX,9d0 at
430486 reaches call4304d3 ->34b740 with no intervening RCX write or call. The
callee has no pdata entry. Exact-target recursive normal-flow decoding reaches
its RETs within105 bytes. Its unsigned index guard admits only0..255. Three
indexed dword writes address G+09d8+12*i, +09dc+12*i, +09e0+12*i; two indexed
reads address G+3e98+4*(i>>5) and +3eb8+4*(i>>5). Envelopes [09d8,15d8) and
[3e98,3ed8) exclude the radial packet/word. These five accesses were independently
adjudicated and are separate from the89 generic accesses. No GPU call occurs.

The missing join remains a G-proven radial READ into an actual resource/CB
upload and selected original shader/textures/formula. No selected bytecode was
established for reflection. A concrete analysis boundary is369c5b -> R13 save
at369d54 [RSP+20] -> calls/overwrite -> reload369f98; this register-only model
cannot prove the memory round trip. Its later44dc/e0/e4 literals are not radial
proof or a proposed radial lead. Fifteen other non-excluded frozen-seed roots
remain listed in JSON. No arbitrary function prefix is proposed. Sentinel,
clock and lifetime remain UNKNOWN; constructor target260 is distinct from G.

Initial checks verified105 LF files (103 protected plus two parent snapshots),
394 raw readonly files and195 native spans. New evidence adds20 code spans
(18,642 bytes) and38 metadata spans, with no overlap against initial spans;
cumulative253 records /64,136 bytes. All3,991 new instruction rows match the
pinned binary. Nine private analyzer checks cover alias width, overwrite, ABI,
intersection/loop and overlap behavior. These are pin/span/tool checks, not
semantic or runtime acceptance. Capture stopped below all caps.

Private evidence: `top/assets/official/top-ring-dataflow-50976`. Schema1 JSON
links exact roots, CFG edges, aliases, joins, calls, access kinds, commands,
SHA256 hashes and guard receipts. Handoff SHA256:
`fe13cb7c115f91bdfbd2e210a72a5b6c30928c6eb1296ff21e9ae4f2373d8ecf`.
Children ran serially with the pinned45s /1.5GiB JobObject /8GiB free-floor guard,
UTF-8 and pycache disabled. The failed no-pdata hop resolver log is retained;
the changed leaf-decoding approach passed. One shell `rg`-unavailable failure
was handled with Select-String. No caps were increased and no game/desktop ran.

Final verification initially caught a live publication-log hash recorded before
child termination. The terminal log was re-pinned; the failed verifier script,
log and receipt are retained. Active output directories are excluded from the
evidence inventory. Successful finalcheck evidence separately verifies history,
protected/raw pins, all253 spans and normal CFG edges.


## Actual receiving singleton context (static, 2026-10-30)

STATIC_PARTIAL. The successful allocation branch requests48c0 at0d07e9,
calls352420 with the returned pointer, and publishes its returned RAX to the
actual slot14290e498 at0d0808 before calling352af0. Constructor352420 saves
incoming RCX in nonvolatile RBX at35244c and returns that same pointer at352993.
It installs14215bd88 at G+0 and14215bd90 at G+8. This is source identity on a
normal successful path, not observed allocation or a live type/lifetime claim.
It is distinct from radial target260/global142aa75d8.

Init preserves the receiver in RDI and passes it directly at3537e7 to35b830,
then3537ef to35b9d0. The first is a no-call flag-reset leaf: its deterministic
counter path reads/writes G dword4470 and clears bits0..19, including bit9,
preserving20..31. This is not a bit9 enable test or GPU path. The second writes
all requested packet offsets (35be44..35bea9):469c/46a4/46ac/46bc/46c0 get zero;
46b0/46b4/46b8 get float0.5;46c4/46c8 get float1. Qword stores are accounted
for by half-open byte overlap. These receiver initialization values do not
establish IRad sentinel fallback selection, clock, lifetime or live values.

Installed primary vtable[0] is377d20. Secondary vtable[0] is377a4c, an exact
SUB RCX,8 / JMP377d20 thunk. The method performs subobject cleanup and G+8
unregistration, with a conditional size48c0 deallocation-shaped call. Parent
destruction loads actualG at0d17e6 and invokes slot0 at0d17fa. This dispatch is
conditional on the installed table remaining present; it is not rendering.
Adjacent pointer words were retained as untyped metadata, not table-extent or
typed-method proof. No adjacent target was decoded.

The smallest missing edge is a concrete typed dispatch/call into a method that
READs this receiver's radial packet and carries it into an actual GPU upload.
No such READ, CB/resource, selected shader/textures or formula is established.
Scalar/vector propagation beyond the explicit reset stores, stack-spill
recovery, bulk-copy semantics, indexed/implicit accesses and selected-resource
joins remain outside this register-only scope. Sentinel defaults, clock and
lifetime remain UNKNOWN; rendering_accepted=false, all96_accepted=false.

Verified105 initial LF files,469 raw readonly files and253 prior native records.
New evidence:6 code spans (7,431 bytes),10 metadata records; cumulative269
records/71,727 bytes. Five normal method CFGs contain1,318 verified instruction
rows and1,432 edges; the separate thunk has2 instructions. Full64-bit this
aliases survive conforming Win64 calls and intersect at branches. Pdata roots
were resolved without treating unwind as normal flow. A private34-case bit
basis evaluator checks the flag-reset trace; these are static tool checks,
not semantic/runtime rendering acceptance. Four typed hops beyond constructor/
init were inspected; no old global-reader survey was repeated.

Schema1 `actual_receiver_context` in ring-native.json records exact source
hashes, native spans, commands, limitations and terminal45s JobObject receipts.
Private evidence is under `top/assets/official/top-ring-context-50976`.
Frozen handoff SHA256:
`41e5d5065a9be914f074a9e85334cb5b6185e37482a37e2e802550c16cd5cb67`.
Binary SHA256:
`46a52ab1dbe80b9a8d6c4d4531bf66693904200c5135facacd053ef28a5de14a`.
History is preserved. Only these two documents receive semantic edits.


## Radial sink audit — 2026-10-30 (schema 1)

**STATIC_PARTIAL.** The actual singleton-to-packet-to-buffer-staging path is now
established. Exact selected bytecode/resource-instance identity and GPU submission
remain open. `rendering_accepted=false`, `all96_accepted=false`. Historical text
above is preserved; this appendix narrows its earlier missing-reader conclusion.

### Actual receiver and normal call path

`1402bb01c` loads RCX directly from **G14290e498**; `1402bb023` calls
`14035e680`. At `14035e6ad`, R15 receives incoming RCX. It is the sole R15
definition in the captured caller body before the sink; intervening normal calls
preserve it under the Windows x64 nonvolatile-register ABI. This is not
radialtarget260/global142aa75d8 identity inferred from equal offsets.

The supplied fragment `14035e6eb..140361cd9` chains through unwind entries
35e6e6,35e6dd,35e6d5,35e6c5 to root35e680. Separately, a 342-instruction normal
CFG witness reaches the call, including its actual branch. Three outgoing edges
leave the capture: 362519,361e24,361cd9; no complete-method CFG claim is made.

`140361487` reads `[R15+4470]`; SHR9 / TEST1 / JE3614cc skips the packet call
when bit9 is clear. On the set path, `14036149e` passes **P=G+469c** in RDX;
RCX is **C=[[G+570]+8]** and `1403614a9` directly calls `1403702d0`.
The setter saves P in RDI and C in R12, reads the packet and stores its mode at
C+6e0. It is not a register-only search: by-reference callee reads and stack
vectors are traced explicitly.

### Implementation-ready staging layout

Let pNN denote f32 at P+hex(NN), except p00 is u32 mode. For ordinary finite
inputs, with each operation rounded as scalar SSE: a=p08/p0c; b=a/p0c.
No divisor clamp occurs here. Mode0 enters 370944; mode1 enters370760;
mode2 enters37042a; other modes skip these named updates.

| Mode0 destination | Name | Bytes | Payload |
|---|---|---:|---|
| C+a0 | cRadialBlurParam | 16 | p18,p1c,p04,b |
| C+140 | cRadialBlurParam | 16 | p18,p1c,p04,a |
| C+1e0 | cRadialBlurParam | 16 | p18,p1c,p04,p08 |
| C | cDonutMergeParam | 32 | p20/2,p24/2,p28/2,p2c/2; p18,p1c,0.5/q,p10 |

q is epsilon if COMISS(epsilon,p14) takes JA, otherwise p14. Epsilon is exactly
bits **3a83126f** at14211dd64 (approximately0.001). This conditional preserves
unordered operand behavior; mathematical max is not substituted. The four half
scales come from vector bits3f000000 at1421416a0. Existing CPU evidence maps
p08 to attenuated Len, p10 to comparison-clamped Str, p14 to Gra, p18/1c to
center, p20/24 to the IR-derived pair and p28/2c to the OR-derived pair.
**p04/p0c semantics and defaults are not fabricated.** Original absent-IRad
fallback, default clock and lifetime remain UNKNOWN.

RBP=RSP+100 in the setter: merge bytes at RSP+70..8f include stores through
RBP-80..-74. Mode1 sends the same three vectors to C+280/+320/+3c0 as
cGaussianBlurParam and uses the same merge block. Mode2 uses the distinct
32-byte cParallelBlurParam blocks and16-byte cParallelMergeParam, documented
with exact helper addresses in JSON; its transcendental helper identities are
not guessed. Nearby468c..4698 fields are not labeled radial.

### Concrete buffer path and its limit

The setter finds named entries through their IDs and the name table reached via
G142907d00+50; missing names/counts skip writes. `140347d50` receives subobject,
entry index, vector pointer and byte count. It saves the pointer in RBP across
calls. For E=[subobject+18]+16*index, B=[E+8], a null or short-capacity buffer
calls `140226350(size, flags2, category11)` and stores the result into E+8.
The allocation is0x70 bytes. `14021f0f0` records16-byte-rounded capacity and
flags; **flags2 bypasses its native-buffer creation branch**.

`14021f5d0(B,0,size,2)` obtains CPU staging storage through TLS command
allocation and records B+28/+30/+34. A nonnull return is passed to141da7ec0
with the saved vector source and size, then B+30 is cleared. This is a concrete
staging/copy-call path, not proof of D3D Map/UpdateSubresource or GPU completion;
the copy-helper body itself was not newly decoded.

After the setter,3614c0 calls349fa0(G+568). Its pointer-array element1 is the
same C. Count/mask/predicate govern virtual+28 dispatch. Captured generic render
code3482b0 sets TLS context+880 from [[subobject+8]+b0], and348615 binds each
nonnull buffer into context+940+8*entryID. The exact concrete virtual targets
remain conditional; no indirect edge is replaced with an assumed callee.

### Shader resource evidence and remaining typed edge

Table14215c090 contains initializer36eae0 at+8 and renderer370ba0 at+28;
36e980/36e9bb installs it in a resource receiver. This is a distinct resource
leaf, not a replay of the exhausted G constructor. Initializer36eae0 constructs
ten descriptors and calls subobject virtual+8 with stridea0. The first three
literal paths are **shader/sm5/posteffect/RadialBlur.shcd** (descriptor index0),
followed by GaussianBlur, ParallelBlur and ParallelMerge descriptors.
Generic initializer347120 consumes descriptor+8, requests the resource through
2fed30/2fedd0 and stores its handle at subobject+8. This is ShCd, not ShPk;
no unrelated package key vector or hashed label is substituted.

Renderer370ba0's captured switch table maps subobjects0..2 to mode0,3..5 to
mode1,6..8 to mode2. Its calls are virtual; mode2 later dispatches C+640.
These sources explain a **conditional** shader path, but do not prove that C
and its subobjects received and retained these tables.

The smallest remaining typed edge is therefore:
**C=[[G+570]+8] and C+a0/+140/+1e0 -> installed initialization/render tables
and returned shader handle at S+8 -> selected bytecode at [[S+8]+b0] with
reflected CB registers.** Exact bytecode hashes, CB registers, actual texture
instances, shader formula and GPU submission are unknown. This is a concrete
instance/handle dependency, not a request to repeat constructor/global surveys.
Aki can use the proven packet/staging mapping; it does not yet authorize an
original-equivalent renderer or COMPLETE action31567/P3-02/all96 claims.

### Evidence, review and preservation

Frozen handoff SHA256 b5308b4fd5db914eb907f54dfb1acf825e9ff5caf04da7423b54a2fa0a86243a;
binary SHA25646a52ab1dbe80b9a8d6c4d4531bf66693904200c5135facacd053ef28a5de14a;
existing Capstone5.0.6. Verified105 initial LF files (103 protected plus both
documents), all528 raw readonly files,253 historical top-level records and16
nested records. They retain their original locations and values.

New capture: **16 code spans /30,617 bytes;15 metadata records /1,148 bytes**.
Total unique native records299 /103,488 bytes, within the requested caps.
Scoped review asserts14 exact instruction sequences and the direct G address;
normal CFG witness and unwind groups are separate private artifacts. No runtime
assertions or rendering tests were performed. One pre-capture import failure is
retained; the explicit existing Capstone path fixed it without installation.
Initial displayed count103/101 was corrected to105/103. Two initial disassembly
windows began inside instructions; the complete caller and reassembled setter
correct them. The initial constant at14211dd60 was not the clamp: the RIP operand
proves14211dd64. All original records/logs remain retained.

Private scratch: `top/assets/official/top-ring-readback-51035`. The single
`radial_sink_audit` JSON key records every new native hash, command/receipt/log
hash, reviewed helper hash, exact joins, counterevidence and limitations.
Documents are published with temporary files plus os.replace and then checked
for exact MD prefix and historical JSON-value preservation. No product source,
tests, Git index, commits, pushes, desktop or game execution were changed.
