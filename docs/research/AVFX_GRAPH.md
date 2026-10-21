# Source-backed AVFX node/reference topology inventory

This bounded stdlib-only layer inventories source structure. It does not execute
particles, scheduler triggers, clips, loops, lifetimes, randomness, materials or
transforms. `rendering_complete` and `execution_implemented` are always false.
No Godot integration or Windows/Web rendering/export gate is claimed.
Base: `4a343302139e420414873418b062b58f0cb6d8e9`. The accepted mesh and curve
readers remain unchanged.

## Source evidence

Format evidence is the maintained MIT Dalamud-VFXEditor revision
`05f6eb0cce19a6a91ae275bce609299d573914b3`. The following pinned sources were
read through the GitHub connector; no C# or UI/plugin implementation was copied
into this worktree. The existing read-only Enums reference supplies Model = 5
for both emitter and particle types.

- [AvfxMain](https://github.com/0ceal0t/Dalamud-VFXEditor/blob/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/AvfxMain.cs)
  writes `ScCn/Schd`, `TlCn/TmLn`, `EmCn/Emit`, `PrCn/Ptcl`, `EfCn/Efct`,
  `BdCn/Bind`, `TxCn/Tex`, `MdCn/Modl`. Nodes retain group-relative source order.
- [Scheduler](https://github.com/0ceal0t/Dalamud-VFXEditor/tree/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/Scheduler):
  AvfxScheduler, AvfxSchedulerItem and AvfxSchedulerItemContainer define
  36-byte records (`bEna`, signed `StTm`, signed `TlNo`). The final `Item`
  container supplies items. The final `Trgr` supplies its **last 12 records**,
  not all records and not an inferred variable trigger count. `ItCn` and `TrCn`
  are checked against the selected lists. A present final trigger container
  shorter than 12 records is rejected. Absent containers produce no records.
- [Timeline](https://github.com/0ceal0t/Dalamud-VFXEditor/tree/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/Timeline):
  AvfxTimeline, Items/AvfxTimelineItem, Items/AvfxTimelineItemContainer and
  Clips/AvfxTimelineClip define final-`Item` selection. Items consist of 12-byte
  fields split before the next `bEna`. Supported values are `bEna`, `StTm`,
  `EdTm`, `BdNo`, `EfNo`, `EmNo`, `Plfm`, `ClNo`; parent values are `LpSt`,
  `LpEd`, `BnNo`, `TICn`, `CpCn`. `Clip` entries are noncumulative: each is a
  164-byte binary record with type int32, four int32 values, four float32 values,
  and 128 reserved bytes. Reserved bytes are preserved, not normalized. No
  clip opcode is executed or interpreted as an inferred graph link.
- [Emitter](https://github.com/0ceal0t/Dalamud-VFXEditor/tree/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/Emitter):
  AvfxEmitter, AvfxEmitterItem and AvfxEmitterItemContainer define final `ItPr`
  and final `ItEm` selection. `ItEm` includes a particle prefix: remove exactly
  the selected particle count before selecting child emitters. Check `PrCn`
  and `EmCn` against these final lists, never the sum of cumulative containers.
  Record sizes follow the source's first-divisible order: 312, 300, 288, 276.
  Unsupported/malformed record sizes are rejected, without guessed boundaries.
  Parent `LpSt`, `LpEd`, `ClCn`, `EfNo`, `PrCn`, `EmCn`, `EVT` are decoded.
  Item creation times/counts/probability, life overrides, delay, start frame,
  flags, influence enums, float unstickiness and injection angles are retained
  numerically. `PrLk` is metadata with unsupported parameter-link semantics.
- [Binder/AvfxBinder](https://github.com/0ceal0t/Dalamud-VFXEditor/blob/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/Binder/AvfxBinder.cs):
  `Life` is an integer, never curve Life. Binder type/rotation, scale flags,
  transform-scale integer and scale-bias float are decoded; properties and
  type-dependent binder data stay opaque.
- [AvfxIntList](https://github.com/0ceal0t/Dalamud-VFXEditor/blob/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/Components/IntList/AvfxIntList.cs),
  [node selectors](https://github.com/0ceal0t/Dalamud-VFXEditor/tree/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat/Nodes),
  Particle/Data/AvfxParticleDataModel and Emitter/Data/AvfxEmitterDataModel
  establish that Model particle `Data/MdNo` is a **byte list**, while Model
  emitter `Data/MdNo` is a signed scalar. Only type 5 opens these Data payloads.
- [ParsedInt](https://github.com/0ceal0t/Dalamud-VFXEditor/blob/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Parsing/Int/ParsedInt.cs),
  Parsing/Bool/ParsedNullableBool and Components/AvfxLiteral establish literal
  width behavior. Integers use int32/int16/unsigned byte for widths 4/2/1;
  other widths are rejected here instead of using the editor's byte fallback.
  Nullable bool reads the first byte (0 false, 1 true, otherwise null); the
  source byte and full raw payload remain available. Float32 must be finite.

## Reference and preservation contract

| Field/context | Target group | Role |
| --- | --- | --- |
| Scheduler item/trigger `TlNo` | TmLn | scheduled/trigger timeline |
| Timeline `BnNo`, item `BdNo` | Bind | binder |
| Timeline item `EfNo`, emitter `EfNo` | Efct | effector |
| Timeline item `EmNo` | Emit | source emitter |
| Timeline item `ClNo` | Clip within its own timeline | clip |
| Selected `ItPr/TgtB` | Ptcl | child particle |
| Selected `ItEm/TgtB` after particle prefix | Emit | child emitter |
| Type 5 emitter/particle `Data/MdNo` | Modl | model |

Signed scalar selector sentinel is -1. Byte-list sentinel is 255. Explicit
negative nonsentinels and references at or above the target count are rejected,
even when a record is disabled. Byte-width scalar integers remain unsigned;
255 is not silently converted to -1 for a scalar selector. Missing selectors
are `null`/`missing`, produce an unsupported entry, and never select node zero.
Empty byte lists remain empty. Explicit zero is validated and linked normally.
Source emitters means timeline links, not an inferred runtime root set.

`references` includes missing and sentinel entries; `edges` includes only
resolved explicit references. These are structural edges, not active events.
Cycles, self-links, reverse/overlapping loop bounds and creation metadata remain
unexecuted; no graph traversal declares cycles corrupt. Runtime termination,
child limits and lifetime semantics require future evidence.

Earlier cumulative containers and excluded prefixes are retained in raw data
but do not contribute edges. Earlier containers are not recursively decoded or
validated as active lists. The selected container's source field index, record
index (including skipped prefix), selected-list index and role are retained.
Missing counts are unsupported, never defaulted to zero; present counts must
match. Duplicate known scalar fields, invalid widths, malformed alignment,
nonfinite decoded floats and invalid root/group counts fail closed.

The implementation reuses `avfx_meshes.blocks`, version `0x20110913`, count
mappings and the 16 MiB bound. Unknown root/node fields, unknown type Data,
effectors, models and texture payloads stay opaque; no heuristic TLV recursion
occurs. Particle/effector/texture and type-specific mappings remain partial.
The graph inventory does not incorporate the separate mesh/curve decoders.

`raw_avfx_base64` preserves **every byte**, including tags, padding, unknown
payloads and order. `source_sha256` identifies the complete input. Nodes,
selected/superseded containers, records and opaque fields carry payload hashes
and raw bytes. These JSON results contain original private asset data and must
remain private. JSON has no local filename, machine path or timestamp.

## Pure API and read-only CLI

`tools.avfx_graph.inspect(data: bytes)` returns a deterministic JSON-compatible
dictionary and raises ValueError for malformed or unsupported record framing.
It performs no filesystem writes or execution. `records(payload, kind)` exposes
the documented scheduler/timeline/emitter splitting rule for focused inspection.

    python -X utf8 tools/avfx_graph.py --input PRIVATE_INPUT.avfx

The CLI reads at most 16 MiB + 1 byte, writes JSON only to stdout, returns 0 on
success and 2 on malformed input/I/O failure. Error output omits local paths.
No output directories or asset-derived files are created.

## Validation evidence

Trusted acceptance command (17 synthetic test cases):

    python -X utf8 -m unittest discover -s tools/tests -p test_avfx_graph.py

Coverage includes cumulative deduplication and emitter particle-prefix removal,
noncumulative malformed counts, trigger tail selection, local clip bounds,
typed signed/byte selectors and sentinels, missing versus zero, scalar widths
and duplicates, bool null preservation, all four emitter record sizes, opaque
payloads that resemble tags, retained cycles/loops, complete deterministic raw
roundtrip, version/size/count rejection and real subprocess CLI status/output.
No assets, C# files, libraries or existing tests were added/changed.

Each private CLI ran twice under explicit 60-second subprocess timeouts. Both
statuses were zero, stdout bytes matched, JSON parsed, raw data round-tripped,
and the original bytes and SHA-256 matched after both runs. Outputs were held
in memory, never saved. These are inventories, not rendered-course assertions.

| Input | Schd | TmLn | Emit | Ptcl | Efct | Bind | Tex | Modl | Nodes | Edges |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| meteor.avfx | 1 | 2 | 6 | 14 | 2 | 2 | 9 | 6 | 42 | 44 |
| comet.avfx | 1 | 2 | 4 | 9 | 1 | 2 | 6 | 6 | 31 | 28 |
| fist_b6.avfx | 1 | 4 | 8 | 7 | 0 | 2 | 9 | 2 | 33 | 39 |

All inventories declare eight groups; nonempty groups are 8, 8, 7 respectively.

| Edge role | meteor | comet | fist_b6 |
| --- | ---: | ---: | ---: |
| Scheduled timeline | 1 | 1 | 1 |
| Trigger timeline | 1 | 1 | 4 |
| Source emitter | 6 | 2 | 8 |
| Child emitter | 0 | 2 | 0 |
| Child particle | 14 | 9 | 13 |
| Binder | 6 | 2 | 8 |
| Effector | 3 | 1 | 0 |
| Local clip | 2 | 2 | 3 |
| Model | 11 | 8 | 2 |

| Unsupported entry reason | meteor | comet | fist_b6 |
| --- | ---: | ---: | ---: |
| Opaque mapping | 874 | 582 | 494 |
| Opaque group payload | 17 | 13 | 11 |
| Opaque type Data | 3 | 2 | 4 |
| Unsupported type mapping | 9 | 5 | 13 |
| Missing selector | 6 | 2 | 8 |
| Parameter-link semantics | 14 | 11 | 13 |
| Clip execution | 2 | 2 | 3 |

Counts overlap in scope and do not measure every possible unsupported feature.
Opaque mappings include known parameters deliberately outside this layer.
All scheduling, timing, emission and rendering execution is unimplemented even
where no per-field unsupported entry exists. Full texture/UV links, other
particle Data variants, binder properties, effector semantics, curve wiring,
randomness, materials and original-runtime visual fidelity remain future work.

Input SHA-256 evidence:

- meteor: `04727278ea0374886f1eb719406991e5a0ac9ce3b5face5de877a7b66aea8f6a`
- comet: `ad8bed47fe153f0e60c95c3b968cf48be765cadf82e0094dae25da83520a7b82`
- fist_b6: `3c7e0a198de899e3b5ef9c2e082bfac716cd3f4c8f8063ffb0f15a9532ac350a`

No commits, pushes, merges, deployments, original-checkout writes or original
asset writes were performed for this stage.


## Parent review (2026-10-21)

Independently checked the pinned emitter/scheduler/timeline container and clip
source. Linux synthetic tests:17/17. All three canonical effect-pack inputs
were read twice, produced identical inventories and exact complete-byte
roundtrips, matched the reported node/edge counts and remained unchanged.
The initial parent fixture lookup assumed friendly filenames; canonical inputs
are `<effect>/effect.avfx`. Correcting that lookup required no parser change.
No scheduler execution, particle playback, rendering or Godot runtime wiring
is claimed by this acceptance.
