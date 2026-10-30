# Radial native mirror sampler: isolated conditional diagnostic

Schema 1. rendering_accepted=false; all96_accepted=false. Owner action31567/P3-02/all96 remains OPEN.
The parent-reviewed gpu_bridge_audit establishes radial packed 0x265: MIN_MAG_LINEAR_MIP_POINT
(filter 0x14), U/V MIRROR (2), W CLAMP (3), bias 0, LOD 0, anisotropy 1, comparison NEVER.
This increment implements its 2D LOD0 sampling semantics, not complete native rendering.
DonutMerge source is immutable; its native sampler and prepass words 377920 remain UNKNOWN.

## Explicit helper schema

Call attach(CanvasItem, "radial"|"merge", inputs), update(inputs), release(), is_current().
Required inputs: sampler_policy, color_space="raw_rgba8_no_srgb",
target="rgba8_unorm_blend_disabled", nonempty provenance; target_size integer2;
viewport and uv_rect float4; s_input ImageTexture and s_input_size integer2.
Radial requires radial float4. Merge requires radii and merge_param float4,
s_merge ImageTexture and s_merge_size integer2.
Policies: linear_clamp_explicit retains existing hardware clamp filtering;
native_radial_0x265_mirror_lod0 is radial-only, explicitly selected, never a default.
Merge rejects native radial policy. A missing/invalid policy fails closed and releases.
Updates support either radial policy in both directions. Per-instance material/shader
ownership isolates updates. is_current checks sampler boolean, all uploaded uniforms,
texture identity/dimensions/bytes and shader identity/code. External mutation fails closed.
No live lifecycle, clock, or native resource factory is introduced.

Conservative host domain: float4 magnitudes <=16, radii MAGNITUDE >=1e-4 (negative radii
remain allowed), f32 radial weight-sum magnitude >=1e-4, UV endpoints within [-2,2].
RGBA8 input textures have no mipmaps, axes 1..4096 including 1x1/1xN/Nx1.
Declared target axes are integers 2..4096. Portable harness caps axes at 256 and checks
actual SubViewport size; target 1x1 is rejected. The caller supplies a matching non-HDR target.
All four channels remain raw; no source_color, premultiplication or blending.

## Mirror proof and precision boundary

For each axis p=f32(f32(coord*N)-0.5), i=floor(p), f=p-i. Each neighbor i and i+1
is addressed with r=((i % (2*N)) + 2*N) % (2*N), index=r if r<N else 2*N-1-r.
The infinite texel-center lattice therefore duplicates both edge texels, reflecting
...1,0,0,1,...,N-1,N-1,... . At normalized seams 0,1,2 the two neighbors are the
same edge texel, so filtering is continuous across both sides. Negative periods use
positive modulo; N=1 maps every neighbor to zero. This is MIRROR, not repeat_enable/REPEAT.
Four texelFetch(...,0) loads are interpolated horizontally then vertically on all RGBA.
LOD0 is explicit; textureSize(...,0) is explicit. No extra coordinate clamp is introduced.
The original four-tap order, saturation*viewport/min, weights and raw third bits 3eaaaaab
are unchanged. Coordinates stay within [-16,16]; N<=4096 bounds p to [-65536.5,65535.5],
so floor/int/modulo are safe. Filtering differences/weights are bounded for UNORM inputs.
Python rounds each reference arithmetic operation to f32. Shader compiler FMA/refactoring
and D3D hardware subtexel/filter precision may differ from this manual f32 bilinear
implementation: exact address semantics are implemented, bit-identical hardware filtering
is NOT claimed. Actual GPU readback remains a separate parent gate.

## Evidence and portable handoff

Manifest SHA256: a13b8ca3300f0fab7556310759b00d5076f220d9425e23dbf55781676f2aa5db. All 106 protected LF sources (including merge) and all
readonly files are checked before/after. Manifest new_files is the eight writable existing
paths; diagnostic_sources lists nine kernel files including immutable merge.
Runner uses SHA-pinned Godot 4.7.2 main executable ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424 and the existing custom Web
release template d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0.
A byte-identical private copy of the main exe uses local _sc_/editor_data and explicit
log paths to isolate editor settings/user data. No default/global template install. WindowsJobObject children are serial, 90s engine/45s
others, 240s cumulative, 1.5GiB hard limit, 8GiB free floor. POSIX work_guard's fcntl is
unavailable on Windows. Unique failures/logs/receipts are preserved; publication is atomic.
Headless lifecycle/numeric tests are neither shader compilation nor raster evidence.

Latest summary: D:\Dev\OpenClawCodexBridge\worktrees\top-ring-mirror-reviewed-51051\top\assets\official\top-ring-mirror-51051\parent-runtime-253f3d8485fb4d7280cbae0551a6bc72\summary.json
Project: D:\Dev\OpenClawCodexBridge\worktrees\top-ring-mirror-reviewed-51051\top\assets\official\top-ring-mirror-51051\parent-runtime-253f3d8485fb4d7280cbae0551a6bc72\prepared\project
Web: D:\Dev\OpenClawCodexBridge\worktrees\top-ring-mirror-reviewed-51051\top\assets\official\top-ring-mirror-51051\parent-runtime-253f3d8485fb4d7280cbae0551a6bc72\web\index.html
Status: KERNEL_NUMERIC_PASS_WEB_READY; numeric_pass=True; web_export_ready=True.
Blocker: None.
Summary source_sha256 explicitly hashes all nine listed diagnostic sources with LF
normalization, including generated docs; summary itself is excluded. Output hashes exclude
.godot caches and summary itself. Parent independently freezes all 114 source files.

Parent may replace project cases.json, then re-export. numeric_cases.json stays separate.
Cases schema1 has textures keyed by ID with size and row-major rgba8, plus <=64 unique-ID
cases with helper fields (texture references use IDs); <=16 textures. Readback retains all
RGBA and top-to-bottom rows. UV=(pixel+0.5)/target_size transformed by uv_rect, no Y flip.
Poll window.__radial_finished; window.__radial_result contains finished/ok/failures and
per-case id/width/height/rgba8. Harness pauses after finite isolated SubViewport rendering.
Fixtures cover clamp and mirror, odd 7x5 with varied alpha, singleton axes, and positive/
negative out-of-range sampling from explicit diagnostic viewport values. These are host
choices, NOT proof of a native viewport. No optional three-pass graph was added.

Remaining native dependencies: native merge/prepass sampler words 377920, target dimensions/formats/views/aliasing, Default prepass math, handle factory/cache identity, absent IRad/defaults, default clock/lifetime, complete dynamic native graph. Initial direct C/A/B setup and
rebinding evidence remains static only. Export readiness is not actual Chromium readback,
original visual acceptance, mainWeb publication, or all96 acceptance.


## Independent parent acceptance (narrow)

Actual Godot4.7.2 WebGL2 / Chromium145 / ANGLE SwiftShader compiled shader readback:
116pointcases (52post-kernel sampler seam cases),8independent fullimages and22default fullimages,
9416RGBAchannels,maximum1/255 error vs raw-DXBC/f32 independent triangle-fold mirror oracle,
declared tolerance2/255. Actual odd and singleton-axis mirror/clamp images differ on allRGBA;
1x1 input preserved,1x1target explicitly rejected. Parent visually inspected RGB/alpha contact sheet.
Software WebGL is NOT hardwareGPU, original D3D filter precision, native viewport/target/vertex,
action31567/P3-02 or all96 acceptance. Frozen shader/helper focused Sonnet5.5 subscription review
NO_MUST_FIX; parent independently matched source pins. Fresh11Python tests/107Godot lifecycle
assertions and106protected/1124readonly passed. First parent negative checker assumed a
results-array on early rejection; originalfailure retained, corrected check alone reran.
No product source correction was necessary. Parent comparison: reports/top-ring-mirror-51051/parent-gpu-comparison-v1.json.
