# Parameterized radial kernels ? private conditional contract

Pixel-only RadialBlur and DonutMerge implement the accepted pinned SM5 formulas.
Native action31567 / P3-02 / all96 integration and rendering acceptance remain **false**.
Source evidence: `RING_NATIVE.md` and `ring-native.json.shader_contract_audit`;
RadialBlur ShCd SHA `218b8478ba791aacd1fdc3b773ff88e2bab905e38002bf3a0479c79d40bbec2e`,
DonutMerge `e3dafd25f1422745231d06a643c0b2896ff6decb36ee94153408b5101baae117`,
VSSampling1 `59a20841f65fcd46d95949c644d5c40f2b7646945fdb25f991c8fb067882d1e9`.
No native constructors were retraced and no native capture or game execution occurred.

## Inputs and safety

Instantiate the RefCounted helper and call `attach(CanvasItem, "radial"|"merge", inputs)`.
`update(inputs)` replaces all supplied state; `release()` removes its own attachment.
Each instance owns a separate material/shader. Check `is_current()` before drawing after
external changes. Updates fail closed and release on stale texture bytes, texture sizes,
shader code, material replacement or uniform mutation; no automatic process or clock runs.
The helper cannot prevent callers from bypassing it and mutating Godot resources between checks.
The direct material is an embedding boundary, not an enforced native render graph.

All input fields are required: `viewport` float4; `uv_rect` float4; `target_size` integer2;
`s_input` ImageTexture and `s_input_size` integer2; `radial` float4 for radial;
`radii`, `merge_param` float4 plus `s_merge` and `s_merge_size` for merge;
nonempty `provenance`; `sampler_policy="linear_clamp_explicit"`;
`color_space="raw_rgba8_no_srgb"`; `target="rgba8_unorm_blend_disabled"`.
These policies are explicit conditional embedding choices, **not decoded native 0x265**.
Caller must supply an RGBA8 non-HDR target of the stated dimensions. The helper validates
the declared contract and textures; the private harness constructs the actual target.
Textures must be RGBA8 without mipmaps. No `source_color` conversion, premultiplication,
COLOR multiplication, blending or spatial tonemapping is applied by the kernels.

Conservative host domain: float4 components have magnitude <=16; radii magnitude >=1e-4;
float32 radial weight sum magnitude >=1e-4; generated UV endpoints within [-2,2];
positive integer dimensions <=4096. This bounds intermediate math for RGBA8 inputs,
rejects nonfinite values, float32 overflow and singular/near-singular divisions.
It deliberately rejects some valid native finite inputs rather than altering shader math.
The shader has no denominator guard. The weight loop uses integer i=0..3, float32
0x3eaaaaab = 0.3333333432674407958984375, and implicit `texture()` sampling.
Merge never uses viewport.zw. All four color channels participate in both kernels.
No packet mapping, viewport derivation, fixed-rate clock, defaults or native VS is implemented.
Only the first native viewport vector is consumed by these pixel shaders.

## Numeric and Web protocol

Python references explicitly round arithmetic through float32; Godot numeric weight tests
use PackedFloat32Array. These are separate from GPU results. SM5 refactoringAllowed and
cross-driver fused multiply/add differences mean no bit-exact GPU promise is made.
Headless tests inspect actual material uniforms, missing/invalid/reverse updates, isolation,
stale texture/uniform mutation, release and reattachment. Headless is **not shader raster
or shader compile evidence**. Python tests read actual SHA-pinned ShCd DXBC chunks,
reflection and disassembly, including the MUL at SHEX word75 and immediate operand at word81. Diagnostics are synthetic gradients
with varied alpha, never substitutes for original action visuals.

Prepare: `python -B tools/asset_lab/prepare_radial_kernels.py --inputs ABS_MANIFEST --input-sha256 376e1c4f8f5f18890f1dba217eff7d09723fef0112aaec9a89c32d034906ec7a --output NEW_ABS_OUT`.
Run: `python -B tools/asset_lab/run_radial_kernels.py --inputs ABS_MANIFEST --input-sha256 376e1c4f8f5f18890f1dba217eff7d09723fef0112aaec9a89c32d034906ec7a [--output NEW_ABS_OUT]`.
The runner validates all 105 protected LF sources and all readonly files before/after,
uses the pinned WindowsJobObject runner serially, 90s engine/45s other children,
240s cumulative, 1.5GiB hard memory and 8GiB free floor. POSIX work_guard uses fcntl
and is unavailable on this Windows host. Each run preserves unique logs and receipts.
No automatic retry, global installs, network publication or desktop execution.

Portable project: `D:\Dev\OpenClawCodexBridge\worktrees\top-ring-kernels-reviewed-51043\top\assets\official\top-ring-kernels-51043\parent-run-6717067ae93f476d99874aa1d7591988\prepared\project`.
Web destination: `D:\Dev\OpenClawCodexBridge\worktrees\top-ring-kernels-reviewed-51043\top\assets\official\top-ring-kernels-51043\parent-run-6717067ae93f476d99874aa1d7591988\web\index.html`.
Immutable final summary: `D:\Dev\OpenClawCodexBridge\worktrees\top-ring-kernels-reviewed-51043\top\assets\official\top-ring-kernels-51043\parent-final-2a0c5cc6d8f84b41985317887a75ecfa\summary.json`.
Current result: **KERNEL_NUMERIC_PASS_WEB_READY**. Numeric pass: `True`.
Web export ready: `True`. Blocker evidence: see summary `blocker` and the preserved per-child log paths.
Exact exported/project file hashes and child receipts are in that summary.

Parent protocol: modify the private project's `cases.json` before headless re-export.
It contains `textures` keyed by ID with integer `size` and row-major `rgba8` byte arrays,
and at most 64 `cases` (unique IDs, at most 16 textures, textures/targets <=256 per axis) with the required fields above (texture fields use those IDs),
plus unique `id` and `kind`. Existing six cases are deterministic examples.
`numeric_cases.json` is a separate fixed helper-test fixture, so parent case replacement
does not change lifecycle test assumptions. The portable
project contains no absolute original-resource paths. Export using pinned Godot's
`--headless --path PROJECT --export-release Web WEB/index.html` after import.
Serve the exported directory privately using the parent's existing Web tooling; open
index.html in headless Chromium and wait for `window.__radial_finished === true`
with a finite parent timeout (suggested 45s). Read `window.__radial_result` as JSON.
It contains `finished`, `ok`, `failures`, and per-case `id`, `width`, `height`, `rgba8`.
The finite harness renders one isolated SubViewport per case then pauses the tree.
No play UI, looping, next action, duration or accumulation is present.

Input texture bytes and readback rows are top-to-bottom. Godot Canvas UV at pixel center
is ((x+0.5)/width,(y+0.5)/height), then uv = UV*uv_rect.xy + uv_rect.zw.
This explicit Godot bridge has **no extra Y flip** and is not a VSSampling1 port.
Compare against independent linear-clamp texel-center sampling, float32 kernel arithmetic
and RGBA8 clamp/quantization. Orientation, alpha, color space and driver differences
must be adjudicated from actual readback, not screenshots or this headless pass.
The harness bypasses presentation-canvas alpha by reading the SubViewport image directly.

Native integration remains gated on resource factory identity, small CB upload/flush,
0x265 and merge sampler state, A/B+merge target ownership/formats/dimensions, absent IRad,
default values, clock and lifetime. Export readiness is not rendering/all96 acceptance.

## Parent validation and export correction

The parent reuses the existing private Godot4.7.2 release template via explicit
custom_template/release (SHA256 d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0),
validated by prepare_radial_kernels.py. No global template install or configuration change.
The private harness now rejects any requested target dimensions Godot cannot represent
exactly (in particular1x1; SubViewport minimum is2x2), instead of silently accepting resizing.
The helper's conservative radii domain is **absolute magnitude after float32 rounding**
compared with decimal1e-4; negative radii are permitted. Decimal input0.0001 itself rounds
slightly below this threshold and is deliberately rejected. This is host safety, not native math.

Parent independent actual Godot WebGL2/Chromium145/ANGLE SwiftShader readback checked
128 point cases (each2x2) and six9x7 images:3560 RGBA channels, maximum error1/255
against raw-DXBC float32/explicit-linear-clamp oracle (declared tolerance2/255).
A separate real Web case confirmed1x1 target rejection. This is real compiled shader
execution on software WebGL, not hardware-GPU, native sampler, native vertex/target,
action31567, P3-02 or all96 acceptance. Exact evidence is linked from the final summary.
The broad independent review timed out; the focused helper review had contract-premise
findings adjudicated with a fresh Godot scene, not counted as NO_MUST_FIX or broad PASS.
