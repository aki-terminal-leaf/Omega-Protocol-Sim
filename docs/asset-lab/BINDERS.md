# Binder evidence and remaining native dependency

Status: **source investigation only; native behavior UNKNOWN, raster NOT_RUN, all96 OPEN**.
Scope: Godot 96-unit miniature visuals only. Audio is excluded. No GUI, game launch,
desktop capture, new model job, renderer change, release or deployment occurred in
this recovery. Existing UV acceptance is unchanged.

## Recovery and source identity

The AnAn task `top-binder-evidence-50685` reached its 420-second model deadline on
2026-10-29. The bridge records `failed`; its worktree remained clean at
`1398183d285a45d4f20edd77f1fe28ccc320c6e1`, and no `final.txt` or changes patch
was produced. The parent recovered completed command outputs from `events.jsonl`
and independently checked the source. This document is **parent-authored recovery**,
not a successful model final. The failed model status is not upgraded by this file.

The collector separately failed by unconditionally reading missing `final.txt`.
That collection error was repaired and verified against the same terminal task;
missing artifacts now remain explicit, without overwriting the first collection.
The original collector and error evidence are retained outside Git.

Relevant frozen source SHA-256:

- `top/scripts/asset_lab_composite.gd`: `2ab3e542d42a943764a51be5604a5a24cfe243b2ca0b8c6c233d9ac94cabf079`.
- `top/scripts/source_avfx_player.gd`: `8c364afa65a574dc9b682f4be84ed9e1a6894ae57df621a0cc3e4df9a2140670`.
- `top/scripts/asset_lab_effect.gd`: `c0c8b8a54eb7dcf6308fc0bb3fe81b759f24260cbedca4b0b99b48b6df5979b7`.
- `top/scripts/avfx_animation.gd`: `1ff1d287cbace3680e3181d60c44b29ba95424a59d5aa72336bf85bd7962c266`.

Private cache provenance is the existing `top-lab-visual-cache-50685-v1`:
`full-data.json` SHA `5f5197248e1be5099c9931e7d2371d9dc32e9663fa60864a59f1e1451232e7c3`,
`weapon-data.json` SHA `cbcc12c95ecb00d1237da984f833b335d860f5761d870c454396e799d175616e`.
These are cache bytes; historical `performances.json.source_hashes` describe an
older compilation and must not be substituted for the cache hashes.

## OBSERVED: inventory is not a performance count

The parent's bounded Python audit resolved main-pack IDs through the manifest,
then overlaid the weapon pack documents by AVFX path, matching `_pack`'s weapon
precedence. The union contains **175 pack documents, 277 binder nodes and 284
property records**. Main/weapon overlap must not be added twice. Property records,
binders, schedule edges, particles, cues and units are different counting units.

The parent's static scheduler/timeline audit found 709 selected schedule edges,
366 with a non-default property `CoUF`. These are source references, not 366
visible failures: trigger schedules, emissions, lifetimes and particle kinds
still determine actual playback. The recovered model's distinct selected-binder
counts use a different traversal and are deliberately not promoted to acceptance.

## OBSERVED: concrete selected and emitted failures

`asset_lab_composite.gd:344` validates each property before obtaining a pose.
Lines 353-354 reject **every `CoUF != -1`**, with
`source_coordinate_update_frame_semantics_unverified/<value>`. No boolean
`CoUF == 1` freeze or silently assumed tracking behavior is applied.

Concrete source path:

- P1-02's selected cue
  `15098|12:0|None|31491|end|10|vfx/common/eff/cmma_shoot1c.avfx`,
  ability 31491, source actor `12:0`.
- Schedule 0 selects timeline 0. Its items 0/1 select binder 0 and item 2 binder 1.
  Both have `PrpS.CoUF=1`.
- Original AVFX SHA is
  `2fa9a8e7d47def7bb3ee64af0d345d754f6fae7e3ac15b66847e4a4c183e3fa9`;
  compiled cache document SHA is
  `8330a555e3efa42defaa65b292b0987682680826a4f43a5f444a1e714ef6dd3c`.
- The already-run guarded Windows headless parent probe observed source-emitted
  particle kind 1, binder 0, rejected at frames 0/9/30/60. It also observed
  `CoUF=0` rejection for emitted kinds 8/10 in
  `vfx/monster/gimmick2/eff/z3oa_b0_g05c0c.avfx` (ability 31616).
- Across those two examples the probe recorded nine rejected emitted
  specifications, no probe assertion failures, exit 0 and no script errors.
  This proves **rejection**, not native or raster correctness. No probe was
  rerun merely to recreate that existing evidence.

P2-06 also selects `weapon/158593/21:1/8` (ability 31533), using
`cmma_shoot1c.avfx`. That unit-to-cue mapping is source-selection evidence;
it has not been independently raster-accepted.

## OBSERVED: other data is not fully consumed

The normal mesh path at `asset_lab_composite.gd:467` reads `PrpS`, calls
`_attachment`, and hides the mesh when the returned transform is null. The
endpoint ribbon path at line 379 instead resolves both `PrpS` and `PrpG` and uses
their positions. Neither path demonstrates the full native binder deformation.

`_attachment` receives a property dictionary, not the enclosing binder values or
its `Data`. Its calculation does not dispatch on `BnVr`, `RoTp`, `bStG`, `bFTO`
or the enclosing binder scale flags/bias. A globally false acceptance flag does
not prove these omitted inputs are correctly handled.

For example, `m0514sp05c0c.avfx` binder 1 has `PrpS.CoUF=-1`, `BPTP=3`,
`BPID=20`, with `bTSc=255`, `bVSc=0`, `bTSd=255`, `bFTO=255`.
The original EID row identifies `n_buki_r`. Passing the `CoUF` guard therefore
does not certify the binder's scale/orientation behavior. No numerical expected
native transform is claimed from these labels alone.

Recovered model commands also read the five existing weapon AVFX binaries and
matched their SHA to each pack's `source_sha256`. Each checked binder contained
an 80-byte `Data` block with nested `SpS`, while compiled nodes expose empty
`data`. `tools/full_replay/compile_resources.py:16` extracts `PrpS`/`PrpG` but
skips other binder blocks. Thus source preservation of binder payloads is a
concrete dependency to address; the `SpS` tag alone is not its runtime formula.
Private binaries and bulk command outputs are not included in this document.

## UNKNOWN: native update and transform semantics

Pinned upstream [AvfxBinderProperties.cs](https://github.com/0ceal0t/Dalamud-VFXEditor/blob/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/Binder/AvfxBinderProperties.cs)
has SHA `13b82233067a6616296f4cb7418abf1824ef1cce1fb8c45de238254250080afa`.
It labels `CoUF` as Coordinate Update Frame with default -1. Companion Binder
classes describe serialization, types and UI. They do **not** establish whether
0/1/60/400 mean sampling, transition, freeze, lifetime-relative update or another
native behavior. No formula is authorized by a field name or a parser default.

## Next work, ranked by dependency

1. A source-grounded non-rendering increment can preserve original binder `Data`
   payloads and subtype tags losslessly, with byte/hash round-trip checks in a
   fresh private output. Preserve rejection gates and uncertainty. This removes
   an observed compiler information loss; it is not visual completion.
2. Before implementing `CoUF` or scale/orientation formulas, obtain actual
   runtime semantics from an available native implementation or a separately
   authorized controlled native comparison. A minimal future experiment varies
   only `CoUF` (-1/0/1/60), moves/rotates/scales the host, and samples before/at/
   after the candidate update frame and after host stop, while holding all other
   source data fixed. Include backward seeks and a mesh versus endpoint-ribbon
   distinction. No such desktop experiment was run under expired authorization.
3. Only then implement the proven subset and compare the same original selected
   cues' transforms, visible frames, materials and lifecycles. Native, raster and
   all96 gates remain OPEN until their actual acceptance evidence exists.

No native renderer formula is justified by the currently available references.
The source-preservation increment and explicit missing-input diagnostics are
separable from that blocked runtime work; neither should be reported as all96
performance acceptance.
