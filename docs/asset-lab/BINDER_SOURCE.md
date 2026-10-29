# Binder source preservation — current acceptance

## Parent acceptance reconciliation — 2026-10-29

**Current scoped PASS: binder source-byte preservation and real compiler-output
integration. Native semantics UNKNOWN; raster NOT_RUN; all96 OPEN.**

The original AnAn task `top-binder-preserve-50723` remains historically FAILED:
its first bridge gate incorrectly required `unsupported` after `strip_raw`,
whose existing documented behavior removes that diagnostic key. The parent
corrected only its own verifier to skip the diagnostic assertion on the stripped
document; every byte/hash/order/duplicate/subtype check remained unchanged.
No candidate code changed to obtain PASS and no model task was resubmitted.
The original error and exact verifier diff are retained outside Git.

Parent Windows acceptance then PASS: five original SHA-pinned weapon AVFX packs,
eight binder payloads, synthetic duplicate/opaque/unknown/nonzero-padding cases,
JSON/strip_raw byte/hash survival, whole-output compatibility after removing
only the additions, and an actual `compile_resources.py` subprocess whose
output removes whole `raw_avfx_base64` but retains every binder source record.
The accepted compiler SHA-256 is
`b90a1c17d831ab2738962113184e98cced9af951c6f85d20e260844aa46f93cf`.

All three candidate files were frozen before an independent Claude Sonnet 5.5
static review (NO_MUST_FIX). Parent independently reviewed the full patch and
reran eight new public tests plus nine existing preview-pack tests on Linux;
all passed. UV runtime stayed byte-exact at
`1ff1d287cbace3680e3181d60c44b29ba95424a59d5aa72336bf85bd7962c266`;
its unchanged Windows material acceptance was not needlessly rerun.

Intentional compatibility boundary: malformed binder Data now fails strict
nested-block bounds validation, including 1/2/4-byte opaque values that the old
compiler could treat as a literal. Valid-source interpreted output remains
unchanged; compiler_revision is intentionally 3. The historical-equivalence
public test requires Git and the full source history containing commit1398183;
source ZIP/shallow clones cannot run that one comparison without the baseline.

Only source/docs are published to `develop`. No new Web/Windows package,
media/capture, renderer formula, cache overwrite, release or deployment.
The model's record below is an immutable historical snapshot; its NOT_RUN
parent-gate wording is superseded only by the parent acceptance above.

## Historical model handoff (before parent gate)

# Binder source preservation (VISUAL only)

Compiler revision 3 adds `node.binder_source` to every `Bind` in the central
`tools/avfx_preview_pack.py::compile_pack`. Baseline: `1398183`.

```json
{"schema":1,"payload_base64":"...","sha256":"...","blocks":[
  {"tag":"Data","payload_base64":"...","sha256":"...","child_tags":["CoUF","CoUF"]},
  {"tag":"PrpS","payload_base64":"...","sha256":"..."}
]}
```

The outer payload is the exact entire Bind payload, including internal block
headers and padding. Each block payload is its exact declared payload (excluding
that block's own header/alignment padding); its hash is SHA-256 of those bytes.
`blocks` retains source order, duplicate tags and unknown fields. Only Data has
`child_tags`: direct nested tags in order, with duplicates. Empty Data yields an
empty list. The existing strict reader rejects malformed Data bounds. Opaque
property fields and nested child payloads are not recursively interpreted.

Every Data occurrence adds `binder_data_semantics_unverified` at `Bind[index]/Data`.
Existing interpreted fields and unsupported entries, including
`external_attachment`, remain unchanged. JSON serialization, `strip_raw`, and
removal of `raw_avfx_base64` retain this source record. The unchanged full_replay
compiler calls the central compiler and retains the additive field.

## Verification on 2026-10-29

Public, standard-library tests (synthetic bytes only):

```text
python -B tools/asset_lab/test_binder_source.py -v
python -B -m unittest discover -s tools/tests -p test_avfx_preview_pack.py -v
git diff --check
```

Actual results: 8 new tests PASS; 9 existing preview tests PASS; `git diff --check`
PASS (new files also checked for trailing whitespace). Commands were
run inside `subprocess.run(..., timeout=45)` (Git baseline reads timeout=10).
The new suite checks byte/hash oracles, duplicate Data and child tags, opaque
properties/unknown blocks, nonzero padding, empty/malformed Data, no Bind/no Data,
JSON/strip_raw survival, indexed diagnostics, and whole-output equivalence to
`git show 1398183:tools/avfx_preview_pack.py` after removing only additions and
restoring the revision.

A separate in-memory, read-only local check used an independent `struct` block
walker on all five packs referenced by private `weapon-data.json` under
`probes/top-lab-visual-cache-50685-v1`, with originals under
`research/top-weapon-vfx-50208/raw`. All five source SHA-256 values matched the
cache. Exact payload/hash, ordered blocks, Data child tags, JSON/strip_raw survival
and baseline-output equivalence passed: **5 packs, 8 binders, 129 blocks, 8 Data**.
No private bytes, fixtures or result files were written into the repository.

Source identities (path suffix under `vfx/`; SHA-256):

```text
common/eff/cmma_shoot1c.avfx 2fa9a8e7d47def7bb3ee64af0d345d754f6fae7e3ac15b66847e4a4c183e3fa9
monster/m0513/eff/m0513sp15c0c.avfx 7adbe5cb34a6d2e382dc07594d10c81aa9d41a5189deb7c9bb8236e5fd1a9e27
monster/m0513/eff/m0513sp21c0t1.avfx f588f81af2bbac95d21d2f01927975aa4eba56e647a90c99ba2b2c9143e995cd
monster/m0514/eff/m0514sp05c0c.avfx d41f33f4d59075c2cd21990175ce8b645101fc365d8dca865f9b1da618171586
monster/m0514/eff/m0514sp06c0c.avfx a0f34d2b4cdc4b97b9cbb8301b81f70b6f930a578910870390cb8c20d1acd4e4
```

The trusted parent gate
`D:/Dev/OpenClawCodexBridge/probes/next-50723-binder-acceptance.py` is **NOT_RUN**:
no remote bridge execution tool is available in this session. It was not run in
the sandbox or redirected to bypass private output restrictions. Local byte
checks are not a substitute for that independent gate. `work_guard` could not
start: `python3` is absent and Windows Python lacks its required `fcntl` module;
no guard file or wrapper was modified.

## Limits

Native CoUF/scaling semantics remain UNKNOWN. No runtime consumes binder_source;
no renderer formula or renderer gate changes. `rendering_complete` and
`gameplay_eligible` remain false. No native/raster/platform acceptance is claimed;
all 96 remain OPEN. No Godot, build, GUI, game, browser, capture or audio work,
commit, push, deployment or release was performed. The independent parent gate
remains required before accepting the complete preservation stage.
