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
channel cannot silently supply zero at construction. This is a caller contract:
the caller must draw that same mesh; material creation cannot enforce later
mesh identity. The experimental player still uses its earlier UV0-only preview
material and does not yet call this color bridge. Host-derived affine rows remain explicit;
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

Total execution coverage is **9 selected programs / 94 recorded cases**,
not all Apricot programs or permutations. Powder1 and shape1 still have the
narrow three-case uniform-texture scope above. Independent reviews and final
hash/process/artifact reconciliation were completed. All harness binaries,
objects, copied raw inputs and owned processes were removed; private sources
and evidence remain. Original VS execution, host packing/defaults, dynamic
Fresnel construction and the complete game render graph remain unproved.

A newly identified signed-input discrepancy remains to be fixed in the portable
section bridge: powder1 clamps nonnegative **before** common factors, whereas
the selected shape/model programs clamp **after** them. Historical positive
fixtures do not establish signed-input equivalence or complete postprocessing.

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
