# Offline AVFX execution preview (experimental)

This increment runs without AnAn, a game installation, .NET or an in-game plugin.
It is **not complete AVFX playback**, is not wired into the practice renderer and
must not replace the accepted P3 reconstruction yet. No released build changes.

## Executable work

- `tools/avfx_preview_pack.py` combines the existing strict mesh/topology/curve
  decoders into a portable private document. Original bytes are embedded
  losslessly. Emit vertices use the source 28-byte float3/float3/RGBA layout;
  they are not invented from draw triangles. UV sets, material selectors and
  unsupported fields are retained. Exclusive output creation preserves proofs.
- `top/scripts/avfx_animation.gd` evaluates linear/step and monotone scalar
  splines, Const/Repeat/Add boundaries, source axis links, color and Life.
  Non-monotone/unknown/RGB-spline cases fail explicitly. Random sampling is an
  explicitly named portable **preview policy**, not the original game's RNG.
- `top/scripts/avfx_player.gd` executes scheduler and timeline offsets, nested
  point/model emitters, emission intervals/counts, particle lifetimes, parent
  transforms/color and base-texture UV curves. Mesh/LightModel use source
  geometry; Disc preview uses source parameter curves. Native numeric time is
  preserved. The optional 30-unit/s preview rate is not a measured server clock.
- Absolute-time seeking and reset are deterministic. Limits are 1800 native
  units, 16000 work operations, 2048 particles and nesting depth16. Cycles and
  invalid intervals fail closed rather than hanging. No combat/state code was
  changed. Unknown features remain diagnostics and `gameplay_eligible=false`.

## Validation (Linux Godot4.7.2)

- 55 Python AVFX format/compiler tests pass (8 new compiler cases).
- 197 Godot checks pass, including the eight preserved P3 original inputs,
  scheduler offsets, exact expiry, reverse seek, reset, invalid reconfiguration,
  random repeatability and cyclic-graph rejection.
- Eight original files were each actually rendered at five native timestamps:
  40 Xvfb/llvmpipe OpenGL captures, zero engine/shader errors. Sources round-trip
  byte-for-byte. These are execution/capture gates, not visual equivalence.
- Pixel review **rejects original-fidelity acceptance**: the loading effect can
  produce overlong bright layers. Successful screenshots do not certify it.
  No new Windows/Web export or native Windows rendering is claimed.

All original inputs, compiled documents, textures and screenshots stay private.
Public tests contain only original synthetic fixtures.

## Reviewed color-section continuation (2026-10-22)

The isolated [shader section bridge](AVFX_SHADER_SELECTION.md#executable-color-section-bridge)
now executes reviewed 1–4-layer decoded color equations with explicit caller
UVs/host controls. Linux, native Windows and WebGL2 pixel/lifecycle probes each passed
113 fixtures / 1,017 checks. It is
not connected to encounter playback and does not resolve the remaining host
ABI, render-graph, attachment or scheduler semantics below. No full-player
completion or new released build is claimed.

## Four original model UV channels (2026-10-22)

The source-model mesh path no longer discards UV sets 1–3. The dedicated
`avfx_mesh_stage.gd` transports source UV0 through `UV`, UV1 through `UV2`, and
UV2/UV3 through `CUSTOM0.xy`/`.zw` using the pinned engine's RGBA-float custom
vertex format. The experimental player now uses this mesh builder. Source-local
XYZ, triangle winding and vertex colors are retained. Position W and packed
normal/tangent bytes remain in the source document; this is not an original
vertex-shader implementation or a claim about their host-space interpretation.

A private independent oracle decoded the original binary half-floats, checked
that they match the compiled documents, and compared the actual Godot mesh
arrays **bit-for-bit**: all 18 source effects, 56 nonempty models and 14,153
vertices passed 523 checks. The first JSON-double comparison exposed decimal
parser rounding on tiny values; the accepted oracle instead compares exact raw
source float32 bytes, without relaxing UV error tolerance. Source validation
rejects missing UV pairs, nonfinite values, fractional/out-of-range indices and
invalid color bytes; weak references verify mesh release and player reset.
Affected runtime/resource/timeline/material gates passed 580 checks separately.

A standalone Linux Compatibility pixel probe independently samples four distinct
texels through the four original UV channels, including `CUSTOM0` passed from
vertex to fragment stage, and verifies all probe resources are released. This
proves channel transport, not the game's UV scale/rotation/scroll matrix rules.
The same standalone frozen-source probe passed six checks on AnAn Windows,
including resource release, with Godot 4.7.2 Compatibility on an AMD Radeon
RX 7900 XT; all four pixels exactly matched. Its first launch stalled and was
terminated. The first bounded WebGL2 follow-up timed out and was **not a pass**. Its
Node-based test adapter retained an invalid SceneTree `quit()` call. After
fixing that adapter and the isolated Python-path/Playwright shutdown issues,
AnAn Chrome WebGL2 passed the same six checks and all four exact pixels, with
no script/page/request errors. Task-owned processes, server port, profile,
export and caches were verified released. The browser reports WebKit WebGL;
hardware acceleration is not established by that string.
The reviewed color bridge now accepts explicit sources 0–3 and passes `CUSTOM0`
from vertex to fragment when required. Custom sources require the caller's actual
nonempty `ArrayMesh`, with RGBA-float `CUSTOM0` on every surface, so an absent
channel cannot silently supply zero at construction. Standalone `create` remains a caller contract: the caller must draw that same
mesh. The opt-in player integration described below binds compilation and later
updates to its exact drawn mesh and rejects replacement. Unbound particles retain
the earlier preview material. Host-derived affine rows remain explicit;
this does not infer the game's matrix construction or source-selection rules.
Linux passed 121 independent color-section fixtures / 1,109 pixel and lifecycle
checks, including eight distinct-texel identity/rotation probes through the source
mesh builder and weak-reference release of all created meshes. This extension's
Windows/Web acceptance is separate from the historical three-platform color
bridge results above and is not yet established. No encounter/release or complete
original rendering is claimed.

The current 18-effect source corpus also makes the remaining limits concrete:
166 particle definitions include 44 uses of render-mode value 4, which the
experimental material path still diagnoses as unsupported; 2 of 268 UV-set
records request pixel-position UVs. TC1 color-control values 0 and 1 both occur,
and all observed TC1 alpha-control values are 1. These are static occurrences,
not evidence of the corresponding host constant values or production playback.
They must not be silently mapped to a convenient shader default.

## Original D3D11 execution scope (2026-10-22)

Separate private harnesses executed genuine original powder and shape pixel
programs (`ps_5_0`) through D3D11 WARP, not replacement pixel shaders. Three
explicit input cases per program, independently varying CalculateColor and
CalculateAlpha, matched SV_TARGET0 with zero maximum absolute error. The downstream tonemap was
explicitly neutralized; SV_TARGET1 was bound but not equation-validated.
These two uniform-texture probes do not validate UV texel or multi-slot selection.
The Visual Studio developer environment was recovered after a PATH-only compiler
check failed; the later shape follow-up used the recovered compiler. These
uniform-texture runs retain their original narrow scope. COM resources
and task-owned executable/object/bytecode copies were released/removed. These
results do not establish real host defaults, original vertex-shader execution,
full rendering equivalence or encounter playback.

A further genuine original model-layer-1 program passed 12 cases: four distinct
2×2 RGBA32F texture locations times three explicit CalculateAlpha values.
Nontrivial vertex, document and fixed Fresnel factors were supplied explicitly.
Both SV_TARGET0 and SV_TARGET1 matched independent equations, including the
selected program's white-compositing output and DOF/secondary-alpha output;
maximum error was zero. The parent independently recalculated all 12 cases.
An initial harness omitted six owner COM releases; the corrected harness was
rebuilt and all 12 cases rerun before accepting the complete release checklist.
The original failed cleanup attempt is preserved separately.

The remaining selected shape2–4 and model2–4 pixel programs have also executed
through WARP: 12 cases each (36 shape and 36 model), four distinct texture
locations times the exact control pairs `(1,1)`, `(0,1)`, `(1,0)`. Both MRTs
matched the recorded independent equations with zero harness error; parent
recalculations also passed. Model fixtures use distinct RGBA textures and UV
routes, a nonidentity UV0 transform, and an exact 48-byte VS constant buffer.
Earlier degenerate/routing/buffer attempts are retained, not counted as passes.
Shape fixtures preserve RGB above 1.0. Because that made shape4's secondary
alpha zero throughout its baseline, a separate four-corner low-exposure probe
verified nonzero MRT1 alpha without replacing the HDR baseline.

Total execution coverage is **9 selected programs / 94 initial recorded cases**,
not all Apricot programs or permutations. Powder1 and shape1 still have the
narrow three-case uniform-texture scope above. Independent reviews and final
hash/process/artifact reconciliation were completed. All harness binaries,
objects, copied raw inputs and owned processes were removed; private sources
and evidence remain. Original VS execution, host packing/defaults, dynamic
Fresnel construction and the complete game render graph remain unproved.

A subsequent genuine powder1/shape1 signed-input probe passed **16 more cases**
(eight each), validating both MRTs with maximum error below `6e-8` at tolerance
`3e-6`. Signed inputs distinguish powder's nonnegative clamp **before** common
factors from shape/model clamping **after** factors. Alpha saturation and the
exact float32 discard boundary were exercised. Both targets were cleared to
distinct sentinels before every draw; all five discarded cases retained both
sentinels bit-exactly. Nonzero secondary alpha was also checked. These additional
1×1 probes do not establish nonuniform powder1/shape1 UV routing or host defaults.
The CPU/Godot section bridge now uses hash/layout-pinned clamp contracts, shared
reviewed equation signatures and the exact discard immediate. Signed diagnostics
encode internal values for LDR observation; complete postprocessing is unproved.

## Exact paired-program UV ABI (2026-10-22)

`tools/apricot_uv_plan.py` provides an isolated CPU reference for the UV-only
portion of 11 original vertex programs paired to the nine reviewed textured
pixel programs: 37 original pass uses / 16 distinct hash pairs. Both shader
bytecode and resource-layout signatures must match, and the pair must occur in
that original package. There is no fallback to vertex program 0.

The input is **explicit vertex INPUT semantics**, not inferred AVFX UvSN or
Godot mesh-channel numbering. Reviewed shape variants convert signed int32 UVs
and multiply by 0.001, 0.005 or 0.01; powder variants pass float UVs, while the
reviewed model programs pass float4 UV varyings. Color samplers select pairs
from those varyings per exact pixel program. The model programs which consume
`g_PS_UvTransform` use two explicit float4 rows' **x/y/w**, not x/y/z. A missing
attribute or required row is rejected; no identity transform is invented.

Nine focused Python tests cover precision variants, four distinct pairs,
negative coordinates, affine translation, ignored row-z values, no-default
contracts and unreviewed-pair/layout/package or intervening-stage rejection. A
separate private original package corpus gate checks every one of the 37 pass uses against independent
numeric expectations and rejects mutated layouts (111 checks, zero failures).

This is not original vertex-shader execution, rasterization/interpolation or
bit-exact GPU dot-product proof. It does not establish the host input layout,
AVFX curve-to-matrix construction, source-UV packing, time/random composition or
world/projection/Fresnel semantics, and is not connected to practice playback.
Original disassembly/bytecode remains private; only hash-pinned route summaries
are included in the repository.

## Offline original shader translation feasibility (2026-10-22)

A private feasibility experiment uses existing packaged `vkd3d-compiler 1.2`,
SPIRV-Tools 2025.1, SPIRV-Cross and glslang 15.1.0; no custom bytecode translator
was built. All nine selected original pixel programs pass DXBC-to-SPIR-V,
SPIR-V validation/reflection, ES 3.00 generation and GLSL validation (45 stages).
A 64-byte truncated DXBC is rejected with an invalid-checksum diagnostic. The
11 actual vertex programs from the exact original pairings also pass their
55 corresponding stages, with package/payload hashes checked against the
previously reviewed original metadata.

The first shell reproduction recipe had a stale-output acceptance flaw. A
fresh-directory replacement freezes all nine input hashes, requires the exact
45 successful stage records and checks newly generated MRT reflection. Its
fresh rerun passes; trying to reuse its output directory fails without altering
the accepted report. The original first-run hashes and all stage results were
independently checked. Tested package versions are not a claim of current
upstream feature coverage or support for every original program.

Naive cross-stage GLSL linking is insufficient: generated VS `oN` and PS `vN`
identifiers differ, while D3D's stage-local constant buffers can collide or
silently alias under GLSL's shared block namespace. The unmodified offline
linker returned zero for 13 pairs and errors for three incompatible model
blocks; those zero exits alone are **not** accepted as connected runtime pairs.

A corrected, explicit identifier-only adapter namespaces **all** VS/PS uniform
blocks separately and connects varyings using original DXBC semantic/index,
register/mask/format and reflected location/type. All **16 adapted pairs** pass
offline linking; all **54 live varying mappings**, constant-buffer register sizes
and exact identifier-only source changes were independently checked. A first
adapter's signature reader crossed into the next signature section; that attempt
is preserved but rejected. The corrected bounded reader rejects wrong semantic
and index cases. These are adapted static links, not original runtime draws.

This experiment does not execute a GPU draw, establish pixel equivalence or
actual host inputs, or integrate original shaders into Godot/practice playback.
Raw bytecode and derived SPIR-V/GLSL stay private, outside the repository.

## Translated pixel-program WebGL2 execution (2026-10-22)

A separate AnAn Chrome WebGL2 experiment now executes the **unchanged translated
fragment sources** for three original programs (powder1, shape1 and model1).
A synthetic fullscreen vertex shader supplies explicit pixel-stage inputs; the
original vertex programs are **not** executed by this gate. All **36 frozen cases**
(12 per program) match the previously accepted genuine D3D11 WARP outputs in
both RGBA32F MRTs. The maximum absolute component error is `1.233364868e-7`,
within the unchanged `3e-6` tolerance. Fixtures include nonneutral tonemapping,
depth lookup and model1 dynamic Fresnel inputs from the original D3D probes.

The gate requires WebGL2, `EXT_color_buffer_float` and a complete two-attachment
float framebuffer, and reads actual FLOAT pixels from both targets after each
draw. Parent review independently reconciles every measured component, exact
case identity, frozen expectations and original/translated/remote file hashes.
There are no final GL, page, browser-console or request errors. ANGLE emits
preserved shader-link warnings about `isnan`; the result is not warning-free.
The reported renderer is ANGLE / AMD Radeon RX 7900 XT / D3D11; this remains a
reported driver string, not independent physical-GPU certification.

Three failed harness/diagnostic attempts remain separate from the accepted run;
shader math, expected values and tolerances were not changed to accept them.
All created GL resources/context and task browser/server processes were released.
A fresh parent audit verifies the eight recorded browser PIDs, normalized task
root, profile/cache/staged copied shaders and fixtures are absent on AnAn, with
no VPS renderer or validator processes left. Necessary private sources and
numeric evidence are retained outside Git. The small canvas screenshot is not
used as the numerical oracle.

This closes only the three-program explicit-input fragment gate. It establishes
neither all nine translated pixel programs, original paired-VS execution,
actual host vertex packing/constants/sampler policy, attachment blending nor
complete AVFX playback or a new released build.

## Actual original VS + PS pair execution (2026-10-22)

A further isolated gate executes the **genuine original powder VS1 + PS1 pair**
on D3D11 WARP, then the reviewed identifier-only adapted translated pair on
Chrome WebGL2. Neither accepted draw uses a synthetic vertex shader. All
**12 explicit cases / both RGBA32F MRTs** match at maximum component error
`6.001034547e-8`, within the unchanged `3e-6` tolerance. An independent CPU
calculation from the actual input bytes matches the original D3D outputs within
`6.675678e-8`.

The input freeze predates execution and includes exact interleaved semantic
bytes, signed int4 color attributes, three consumed VS buffers, four separate
PS buffers and three RGBA32F textures. Cases distinguish integer color scaling,
two distinct texture locations, nonneutral postprocessing and VS-derived depth
lookup. They use deliberately selected inputs, **not inferred game host packing
or defaults**. Source signatures, buffer sizes, raw bytes and hashes were
independently reviewed. Actual remote pre-execution/pre-launch hashes reconcile
with the frozen original DXBC and adapted GLSL; parent review also checks every
case identity and all 96 measured components per platform.

The first draws failed because clearing D3D state between cases removed the
explicit raster/depth/blend configuration. The accepted harness restores all
required state before every draw and uses the frozen distinct MRT clear colors.
Four diagnostic attempts, an earlier incomplete input manifest, and the initial
numerical pass lacking complete provenance checks remain private evidence, not
accepted replacements. Review also required exact case-ID binding and source
hash provenance; both were corrected before closing the gate. Shader math,
frozen inputs and tolerances were not relaxed. Final GL, page, console, HTTP and
request error lists are empty; preserved ANGLE link warnings concern `isnan`.

COM/GL objects, task browser/server processes and staged copies were released.
A fresh parent audit verifies task commands, recorded native PIDs and the remote
staging root are absent. Necessary private source and numeric evidence remain
outside Git. Only one original pair and one constant-varying covered 1×1 sample
per case are established: **spatial interpolation, coordinate-convention
coverage, all 16 pairs, physical-GPU certification, actual host rules, complete
compositing and full AVFX playback remain unproved**. The practice renderer and
released v0.3.10 are unchanged.

## Opt-in experimental player color-section integration (2026-10-23)

`Player.configure_color_stage_bindings(bindings)` now connects reviewed color
sections to the **actual experimental player draw path**. It does not select
original permutations or change encounter/practice playback. Configure the
player document first, then supply integer particle-definition indices before
any draws exist. Each entry contains a hash/layout-reviewed `plan` and a
`context_provider` callable. Invalid requested bindings fail closed; they never
silently substitute the legacy material. Unbound particles preserve legacy
preview behavior.

The provider receives particle index/key/age, sampled particle color, a copy
of the source particle node and the exact `actual_mesh`. It must supply explicit
finite CalculateColor/Alpha, decoded texture samples and affine UV rows, a
combined common factor, and boolean provenance flags
`factor_includes_particle_color`, `factor_includes_mesh_color` and
`model_fresnel_included`. The first two must be true; required model Fresnel
must already be included. The player does not multiply particle/mesh color a
second time or invent host defaults. A provider-supplied `source_mesh` cannot
replace the actual drawn mesh.

`ColorStage.compile(plan, context, state, actual_mesh)` creates each draw's
material/shader once. `apply(binding, context, actual_mesh)` revalidates the
contract and updates texture objects, controls, common factor and UV rows without
regenerating shader source. Sampler modes/UV routing, reviewed plan, shader,
material identity, mesh identity and render priority remain locked. The player
preserves supported source mix/multiply/add/subtract, front/back/disabled cull,
depth-test/write and clamped priority states. Unsupported render modes, soft
particles and dynamic Disc meshes fail closed. Missing/invalid runtime context
clears all draws and stops playback; provider reentry into configure/reset/
seek/trigger is rejected. Expiry and reset release owned draw resources.

Linux Godot 4.7.2 Compatibility/llvmpipe acceptance includes 363 player contract
checks and **135 actual-player color fixtures / 2,461 checks**, covering measured
RGB, encoded alpha/signed outputs, exact discard boundaries, all four original
model UV channels, seek updates without shader/material replacement, no duplicate
tint and resource release. The initial renderer attempt timed out because its
synthetic RGB curve used an invalid data representation; that failed attempt
is retained separately. The corrected fixture uses the existing runtime's
three-float `rgb` schema; no shader equations or tolerances were relaxed.
An additional 64 actual-player state/framebuffer checks pass: four blend
equations, front/back culling, depth-test/write, discard-before-depth, shifted
repeat/clamp sampling and animated factor/control/UV changes with stable
material/shader identity. Historical section-only and legacy material regression
gates also pass. This new player path has no new Windows/Web acceptance and does not implement the
original postprocessing/MRT render graph, host mapping or full AVFX playback.
The accepted P3 reconstruction and released v0.3.10 remain unchanged.

## Remaining hard requirements for complete playback

| Area | Remaining requirement |
| --- | --- |
| Timeline | Looped timelines; stop/unlock/fade/reset/trigger clip semantics and binder-target scope |
| Emitter | Other volume types; injection/velocity, fractional counts, original random distributions and parent inheritance details |
| Particles | Polyline/decal/other types; simple animation, exact billboard and velocity rules |
| Material | TC2–4, normal/reflection/distortion/palette, screen-copy, Fresnel, lighting, exact blend/depth/cull/UV conventions |
| Attachment | Actor skeleton sockets and type-specific binder transforms |
| Proof | Reference-game temporal/pixel comparison and fresh Windows/Web export acceptance |

The local preserved corpus contains selected AVFX/meshes/texture conversions,
not the complete original game shader/runtime or all encounter assets. AnAn is available again as of2026-10-22. The [source-acquisition continuation](AVFX_RESOURCES.md)
adds original EID/skeleton and Apricot shader packages; their presence is not
an implemented original runtime or completed visual comparison. The maintained MIT
VFXEditor format definitions were inspected at pinned revision
`05f6eb0cce19a6a91ae275bce609299d573914b3`; that editor's in-game playback does
not supply a standalone game shader/runtime. Its plugin was not embedded.

## Reproduce

Use the pinned Godot4.7.2 binary as `GODOT` in the examples below.

```sh
python3 -m unittest tools.tests.test_apricot_uv_plan -v
python3 -m unittest discover -s tools/tests -p 'test_avfx*.py' -v
python3 tools/avfx_preview_pack.py --input PRIVATE.avfx --output NEW.preview.json
$GODOT --headless --path top --check-only --script tests/avfx_runtime.gd
$GODOT --headless --path top --script tests/avfx_runtime.gd -- PRIVATE_CORPUS_DIR
```

For real render probes, `tests/avfx_render.gd` takes the compiled document, a JSON
map from original texture virtual paths to local PNG paths, and an output folder.
Run with an actual OpenGL display (Xvfb/llvmpipe is sufficient), not `--headless`.
Keep the output private. Reject any `ERROR` and require the final gate sentinel.

This is the next implementation dependency after [AVFX_GRAPH](AVFX_GRAPH.md),
not a completion claim for [P3_EFFECTS](P3_EFFECTS.md) or [FIDELITY](FIDELITY.md).
