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

## Executable color-section bridge

`top/scripts/avfx_color_stage.gd` now creates a Godot4.7.2 Compatibility
ShaderMaterial from a reviewed color plan and an explicit host context. It
executes the reviewed 1–4-layer equations, including constant-only layers whose
sampler was optimized away. Unsupported decode/sampler inputs fail closed.

The compiler and bridge share `top/data/apricot_verified_color_programs.json`.
Godot also recomputes the canonical executable layer-equation fingerprint; a
syntactically valid but contradictory equation is rejected.
Plans must carry the exact reviewed bytecode/layout pair, clamp order and discard
constant; absent/stale or contradictory contracts fail closed. Powder's selected
programs clamp the section to nonnegative **before** caller-combined factors;
selected shape/model programs clamp **after** factors. Alpha saturates afterward.
Discard uses the original float32 immediate `0x3B808081`, not a rounded decimal.
This does not reproduce separate host multiply rounding or complete postprocess.

Required context, with no inferred game defaults:

- `calculate_color`, `calculate_alpha`: finite explicit host controls.
- `common_factor`: caller-combined vertex/document/model RGBA factor.
- `model_fresnel_included`: explicit provenance; required true for model shaders.
- Four `samples` slots. Active samplers require a `Texture2D`, decoded-numeric
  sample assertion, nearest/linear filtering, repeat/clamp wrapping, source UV
  index matching the plan, mesh UV/UV2 input and two finite affine UV rows.

The caller owns the returned material and its texture references. There are no
static material/shader/texture caches; releasing the material and caller context
releases the references. This is a section-execution bridge, **not wired into the
practice player**. Its fixed unshaded/mix/no-depth-write probe states are not an
implementation of the original render graph. It does not generate original UV
transforms, derive host controls or calculate Fresnel/lighting/tone-map/MRT.

Native Linux Mesa/llvmpipe and AnAn Windows each passed **113 fixtures / 1,017
checks**: 111 original-instruction cases, two independent four-layer UV/UV2
cases, and actual material/shader/texture weak-reference release. An additional
25 headless context-contract checks reject missing factors, invalid UV inputs
and unreviewed settings. Both use the same source and fixture hashes.

Initial failed probes are retained: Godot Compatibility internally applies
approximate sRGB conversion even when unshaded; a constant-output shader and
pinned engine source (`ed1daf0bf`, `drivers/gles3/shaders/tonemap_inc.glsl`)
explain its low-level error. Final probes independently account for this
transfer, keep RGB within the LDR target, and encode alpha as `0.25+0.5*a`
before that transfer. They do not alter the original color equations or claim
full-frame/original-game color equivalence. All owned native processes exited;
Windows task-created shader cache was removed.

The CPU compiler now also compares a normalized symbolic equation against the
manual reviewed instruction equation. Matching bytecode/layout hashes alone
cannot make contradictory mutable scene metadata a verified executable plan.
Structured UV-count records participate in the same cardinality validation as
plain integers. The private 37-node / 111-case independent oracle still passes.

The same frozen shader source and 113 fixtures also passed an isolated AnAn
Chrome **WebGL2** no-threads export: **1,017 checks / 0 failures**, no console
errors, page errors or failed requests. Actual canvas capture and source/fixture
hashes were retained privately. Renderer identification was only `WebKit WebGL`
/ `WebKit`; no hardware-backend claim is made. The Web runner adapts SceneTree
entry/output to a Node and JavaScriptBridge without changing the shader core or
pixel assertions. Task browser processes, server, unique profile, Godot cache and
app user data were closed/removed. This remains color-section-only acceptance,
not complete TOP Web or original-game equivalence.

### Signed-input correction (2026-10-22)

The corrected source passed Linux Mesa/llvmpipe **135 fixtures / 1,263 checks**
(including 14 new powder1/shape1 signed/boundary cases and the prior four-UV
cases), plus **38** context-contract checks. Signed RGB is observed through
`0.5+0.25*rgb`; alpha retains its earlier encoded probe. A separate opaque
survival diagnostic distinguishes exact/below-threshold discard. These are
internal numeric probes, not an HDR framebuffer or original render-graph proof.
The same final frozen source also passed AnAn Windows and Chrome WebGL2, each
**135 fixtures / 1,263 checks / 0 failures**; Windows contracts passed **38**
checks. Web output includes all 135 pixel records and weak-reference release.
Initial isolated Web attempts omitted the shared registry, then used a stale
result-variable name; corrected packaging and result adapters passed without
changing numeric assertions. Export logs verify the registry is packed. Final
parent process/cache audits removed a leftover task PowerShell process and
cache. Historical attempts remain evidence, not passes. No hardware-GPU or
complete original-game acceptance claim is made.
