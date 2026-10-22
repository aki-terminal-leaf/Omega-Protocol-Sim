# Package-local semantic shader selection

2026-10-22. This is source-backed **scene-key selection**, not an AVFX host-state
evaluator, shader translator or complete player. It never sets
`rendering_complete=true` or selects a first match silently.

## Authoritative labels

`tools/data/apricot_crc_names.json` contains297 key/value labels and15pass labels
from VFXEditor`CrcMaps.cs` at revision
`05f6eb0cce19a6a91ae275bce609299d573914b3`, source SHA256
`aa2ac188c09139b19bac3cc825d015c2054c08045bdfcc7894e520859cd71649`.
The newest relevant upstream revision`f54244dad20366283ac64f272fccca13eb6e51a6`
was also checked: that file is byte-identical. Attribution/license accompany the
map in`tools/data/VFXEditor-LICENSE`.

These are explicit source mappings. The numeric CRCs are **not** obtained by
hashing the editor's readable labels. Unknown IDs stay explicit hexadecimal
values; absent names never produce invented IDs or host defaults.

## Actual package schemas

The newly acquired originals do not share one scene-key vector layout.

| Packages | Scene keys with names / total |
| --- | --- |
| decal, decal_ring, gbuffer_decal, gbuffer_decal_ring | 50 / 55 |
| fogmodel, lightmodel, model, model_morph | 51 / 55 |
| shape | 51 / 56 |
| powder | 51 / 57 |
| five dummy packages | 2 / 2 |

Each vector is interpreted using its **own** package's ordered declarations.
Using shape labels to interpret a model vector can silently shift semantic
meanings. Both different key order/count and foreign-cache cases are tested.

## API contract

`tools/avfx_shader_select.py` consumes immutable metadata returned by
`shpk_inspect.inspect`:

- `describe_scene`: ordered IDs/defaults, observed values, known/unknown counts,
  aliases and optional bounded node examples. Default detailed-node count is0;
  at most64may be requested. Observed distinct values are also bounded.
- `resolve_constraints`: readable semantic names or explicit uint32/hex values.
  Duplicate declared-key ordinals and conflicting semantic/hex aliases fail.
- `build_exact_index`: caller-owned full-vector index bound to the exact
  immutable metadata object and ordered schema. Rebuild after loading another
  package; a foreign index is invalid even if vector lengths happen to agree.
- `select_nodes`: `match`, `ambiguous`, `no_match` or `invalid`. All matching
  nodes/pass/program references are preserved. Duplicate vectors are not
  arbitrarily collapsed. Empty constraints do not select a default node.

The name database and its lookup have bounded one-entry caches. Repeated custom
maps do not accumulate strong references; weak-reference tests verify release.
A selector result describes **scene keys only**. System/material/subview state,
dynamic constant buffers and AVFX-to-host derivation are separate requirements.

## CLI

```sh
python3 tools/avfx_shader_select.py PRIVATE.shpk --describe --output NEW_REPORT.json
python3 tools/avfx_shader_select.py PRIVATE.shpk --constraints NAMED_KEYS.json
python3 tools/avfx_shader_select.py PRIVATE.shpk --exact-vector THIS_PACKAGE_VECTOR.json
```

Reports use exclusive creation; existing evidence cannot be overwritten.
Exit codes:0match/description,2invalid,3no match,4ambiguous. An exact vector uses
this package's own order. The command does not guess fields from an AVFX or
execute the returned programs.

## Verification

13selection cases cover public API and CLI behavior, ambiguity, unknown values,
package ownership/order, conflicting constraints, real cache release and bounded
description. The CLI fixture initially mislabeled its one system key as a scene
key; that failure was retained, the fixture was corrected and that case alone
was rerun successfully.

Every one of23,931original nodes across all15packages was passed through the
**public selector** using its own full vector. Its membership and returned VS/PS
references were checked against the owning source metadata, not only by iterating
the newly built index. The gate used512MiB address-space limit; maximum observed
RSS149,004KiB. This checks selection/ref integrity, not shader execution or game
image equivalence. No browser, Godot, game client or persistent service is used.

## Still required for direct playback

A source-justified AVFX/host-state projection must supply the actual key vector.
Do not equate fog boolean with RGB/alpha fog mode,`bFar` with ForceFarZ, an
unknown operation with None, or source enum numbers with dynamic
`CalculateColor/CalculateAlpha` floats without evidence. Mask animation, matching
vertex input generation, camera/render-graph textures, actor poses and original
reference comparison remain separate from this completed selection component.

## Declared fields and reviewed color-section execution (2026-10-22)

`tools/avfx_shader_projection.py` projects only present AVFX fields into the
pinned CRC map. Host fog/depth/final-color context and TC1 dynamic controls
remain explicit diagnostics; partial projection is not exact shader selection.

`tools/apricot_color_plan.py` gates texture-combiner execution on reviewed pixel
bytecode **and resource-layout hashes**. The private original-instruction oracle
currently covers 37 original nodes / 111 sample-control cases across nine
1–4-layer shape/model/powder variants. CTA immediate float32 bits are
`3E990AFE 3F162C23 3DEA7371`; evaluation compares real-valued equations, not
bitwise GPU execution. Enabled CTA layers with alpha=None can have their sampler
optimized away: their constant-white RGB operation must still execute.

The registry contains hashes/manual equation metadata only, no original game
bytecode. UV generation, decode, host CalculateColor/Alpha values, model Fresnel,
lighting, tone-map and MRT remain outside this section. No complete renderer
or encounter integration is claimed (`rendering_complete=false`).

The separate 14-case base-material pixel probe also passed in an AnAn Chrome
WebGL2 export on Godot4.7.2, including nonblank actual-canvas capture. This is
scoped material-path acceptance, not full TOP Web playback acceptance; the
hardware renderer backend was not established. Its task browser, HTTP server
and temporary profile were closed/removed and owned-PID cleanup verified.
