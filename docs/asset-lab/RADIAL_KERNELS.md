# Mixed merge sampler and conditional private chain

Schema 1; rendering_accepted=false; all96_accepted=false. Action31567/P3-02/all96 remains OPEN.
Parent target_factory_audit establishes prepass 0x265 LINEAR MIRROR, merge sInput 0x25 POINT
MIRROR and sMerge1 0x265 LINEAR MIRROR, bias zero / LOD0. I=M+68, A=M+260, B=M+268,
output=M+258; static I->A, A->B->A->B, merge(I,B)->output; rebinding can change endpoints.
This diagnostic does not implement unknown Default prepass math or native resource identity.
Independent immutable native documentation was not modified.

## Explicit policies and bounds

Exactly three policies: linear_clamp_explicit, native_radial_0x265_mirror_lod0, native_merge_0x25_point_0x265_linear_mirror_lod0.
linear_clamp_explicit remains compatible for both kernels. native_radial_0x265_mirror_lod0
is radial-only and unchanged. native_merge_0x25_point_0x265_linear_mirror_lod0 is merge-only.
Missing, invalid and cross-kind policies fail closed and release. attach/update/release/is_current
track every uniform, sampler resource, texture dimensions/format/bytes, shader identity/code.
Clamp<->mixed updates work in both directions with isolated material/shader instances.
Required provenance, raw_rgba8_no_srgb, rgba8_unorm_blend_disabled, target_size, viewport,
uv_rect, input texture/dimensions and kernel parameters remain explicit. Input axes 1..4096,
no mips, finite f32 float4 magnitudes <=16, UV endpoints [-2,2], radius magnitude >=1e-4
(negative radii allowed), radial weight-sum magnitude >=1e-4. Actual target axes 2..4096;
private portable target axes <=256. No 1x1 target support, no native default/lifecycle mapping.

POINT uses f32(coord*N), then floor, then integer MIRROR with positive modulo 2*N and
index r if r<N else 2*N-1-r. At exact integer scaled coordinates k this follows the parent's
normative exact-boundary lemma: coord=-0.5,N=2 maps texel 0. Continuous UV folding before
floor would incorrectly select texel 1. No epsilon or source rounding is added. Noninteger
coordinates use an explicit diagnostic f32 convention, not a bit-identical D3D hardware claim;
D3D fixed-point sampler precision near boundaries remains a renderer comparison concern.
Bounds |coord|<=16 and N<=4096 bound point scaled coordinates to +/-65536, safe for floor/int.
LINEAR uses maintained texel-center p=coord*N-0.5, integer-MIRROR neighbors and four LOD0
texelFetch loads, horizontal then vertical RGBA interpolation. Neighbor floor/int/modulo are
bounded within +/-65538. MIRROR is never repeat_enable/REPEAT. Raw DonutMerge pixel
arithmetic/order and all RGBA are preserved; compiler FMA/filter precision can differ.

## Portable protocol and conditional chain

cases.json is parent-overridable, separate from numeric_cases.json; schema1, <=64 unique
cases and <=16 textures, each axis <=256. All schemas and bindings validate before rendering.
window.__radial_finished and window.__radial_result report finished/ok=false on invalid packs,
including failures with no results array. Output rows are allRGBA top-to-bottom; UV is
(pixel+0.5)/target transformed by explicit uv_rect, no Y flip. Fixtures include exact negative
boundaries, seams and robust away-boundary coordinates, unequal/odd/singleton inputs, varied
alpha, signed radii and distinguishable mixed versus all-linear/clamp after saturation*viewport.

chain_cases.json schema1 contains exactly host texture IDs I and A, and 1..2 unique chain cases.
Each case requires id/provenance and initial/forward arrays of exactly four fully explicit helper
rows. First three are radial A->B, B->A, A->B with output IDs and input/target dimensions;
last is mixed merge(I,B)->output. No implicit inputs, Default copy, downsample or native allocation.
Each row declares viewport/radial or radii+merge_param/uv_rect/target_size and policy/provenance.
The harness runs initial, forward, reverse(initial), retaining bindings and updating resources
without mutating attached textures. Each intermediate is read back and quantized RGBA8 before
reattachment. chain_results records host prepass A, all three radial outputs and final merge for
every state. This is a conditional host-supplied prepass/targets diagnostic, NOT a native passgraph.
CPU chain tests and lifecycle/schema tests are separate from actual WebGL raster acceptance.

## Evidence

Manifest b4e559dbf5d98e132ea25686902da487cfd6213a9c366e9e5b1bcf1ff6e0ff9d: 105 protected LF sources plus ALL readonly files checked before/after;
nine writable diagnostic sources pinned explicitly. Parent independently freezes 114 sources.
Pinned main Godot 4.7.2 SHA ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424, custom Web release template
 d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0.
WindowsJobObject serial limits: 90s engine/45s others/300s cumulative, 1.5GiB hard and 8GiB free.
POSIX work_guard requires unavailable fcntl; existing pinned Windows runner is used. Private
_sc_/editor_data/cache and logs only; no default templates/global settings. Failures retained.
No native capture/binary probe, browser, desktop, commit, push or deployment was performed.
Latest summary: D:\Dev\OpenClawCodexBridge\worktrees\top-ring-mixed-51061\top\assets\official\top-ring-mixed-51061\run-82727adc-8a62-46bf-876a-713ccbdc54e8\summary.json
Project: D:\Dev\OpenClawCodexBridge\worktrees\top-ring-mixed-51061\top\assets\official\top-ring-mixed-51061\run-82727adc-8a62-46bf-876a-713ccbdc54e8\prepared\project
Web: D:\Dev\OpenClawCodexBridge\worktrees\top-ring-mixed-51061\top\assets\official\top-ring-mixed-51061\run-82727adc-8a62-46bf-876a-713ccbdc54e8\web\index.html
Status: KERNEL_NUMERIC_PASS_WEB_READY; numeric_pass=True; web_export_ready=True;
chain_diagnostic_ready=True; raster_verified=false.
Blocker: None.
Remaining limitations: native formats/sRGB/blend/allocation/views/aliasing; Default prepass math; clock/IRad/lifetime/factoryCreate identity; native input/output rebinding and complete dynamic graph; actual compiled private WebGL allRGBA comparison against independent raw DXBC oracle pending. Export readiness is not GPU acceptance or all96 acceptance.


## Independent parent acceptance (conditional diagnostics only)

Fresh isolated parent validation passed all eight bounded runner receipts: 12 Python tests,
224 Godot numeric/lifecycle assertions, malformed-chain rejections and private Web export.
105 protected LF sources and 1493 readonly inputs remained exact. Original 114-source candidate
was frozen before independent review and remained untouched throughout validation.
Actual compiled Godot 4.7.2 WebGL2 / ANGLE SwiftShader readback matched independent raw-DXBC
f32 arithmetic: 126 pre-candidate independent cases plus 50 default cases, and the host-prepass
A plus all four outputs for initial/forward/reverse states. Both accumulated RGBA8 reference
and actual-previous-stage-input reference were checked. 25264 channel comparisons, maximum
1/255 error, preset tolerance 2/255. Reverse update restored every stage byte-for-byte; forward
update changed actual pixels. Target1x1, malformed chain and oversized chain were rejected early
with finished/ok=false and no results array. Independent review findings and disposition are
in reports/top-ring-mixed-51061/parent-acceptance-v1.json; exact reviewed hashes retained.
First child numeric failure was a non-distinguishing texture-tamper test fixture; corrected
fixture and explicit changed-byte assertion passed fresh parent validation. Failure logs retained.
These are conditional host-supplied prepass/target diagnostics and software WebGL, not hardware
GPU, native D3D fixed-point precision at arbitrary near-boundaries, native allocation/format/
views/blend/default-prepass/clock/lifetime/factory identity, original action31567/P3-02 or all96
acceptance. rendering_accepted=false; all96_accepted=false. No main Web or media publication.
