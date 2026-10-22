# Explicit Apricot pixel-output reference

This development reference is **not complete AVFX playback** and is not used by
normal practice rendering. Published v0.3.10 is unchanged. It reuses the existing
hash-pinned color-plan implementation and original-instruction evidence rather
than introducing a second shader selector.

`tools/apricot_postprocess.py` implements real-valued equations with original
float32 immediates for nine selected powder/shape/model pixel programs. The
separate registry contains hashes and reviewed metadata only, never game
bytecode or textures. Each execution rechecks the exact bytecode/resource-layout
pair; mutable labels/output-mode flags cannot select an equation.

## Explicit inputs, not inferred host behavior

`evaluate_pixel` consumes the reviewed color plan, four already-decoded numeric
sample slots, CalculateColor/Alpha, separate vertex and document RGBA factors,
explicit postprocess controls and a decoded postprocess sampling function.
Model programs additionally require their consumed PS position/normal, axis
modifier and three FresnelParameter vectors. No camera, exposure, factor, UV,
texture-decoding or sampler-state defaults are invented.

The sampling callback receives `(role, uv)`, with roles `tone_map` and `dof_lut`.
Tone samples are requested at `(0.5,0.5)`; DOF samples at
`((depth-lut_start_z)*lut_inv_range,0.5)`. The caller owns texture decoding,
filtering, address modes and resource binding. The original tone sample's **x**
component is used: its `.yzwx` resource swizzle and destination `.w` do not mean
texture alpha.

## Reviewed equations

Let `T` be the tone-map sample x, `P` the explicit ToneMapParameter vector and
`A` ApplyToneMap. The RGB exposure multiplier is
`1+A*(1/sqrt(1+P.x*(T-1))-1)`, after multiplication by `P.w`.
The reference supports positive finite reciprocal-square-root operands only.

Model Fresnel uses the normalized dot product of
`FresnelParameter[0].xyz-position*axis_modifier` and the supplied normal, takes
its absolute value, floors it at original float32 `0x3727C5AC`, and raises it to
`FresnelParameter[0].w`. That weight interpolates parameter rows 1 and 2,
without saturating the factor. These consumed rows start at byte offset 16 in
the model buffer; they are **not EyePosition at offset 0**. Their host meanings
and coordinate spaces remain unverified. Zero-length normalization and
nonfinite/overflow corner behavior are rejected, not replaced with defaults.

The section is multiplied by Fresnel (model only), then vertex and document
factors separately. Selected powder clamps before those factors; selected
shape/model clamps after them. Alpha then saturates. This preserves instruction
ordering as a real-valued reference, not float32 multiply/FMA rounding.

Only selected **model1** saturates post-tone RGB and computes
`1+alpha*(rgb-1)` (compositing over white). The other eight selected programs do
not apply that RGB saturation or white composition.

Both original MRT outputs are returned. MRT1.x is the sampled DOF x, y/z are
zero. MRT1 alpha uses output RGB luminance with original float32 weights
`3E990ABB 3F162C13 3DEA747E` (different from color-to-alpha weights), the sign of
BlendStateType, and `1-BlendStateType*BlendStateType`. Model1 has an upper min
rather than lower-and-upper saturation at this final coverage boundary.

Alpha below exact float32 threshold `0x3B808081` returns `discard=true` and
**no target values**. It must preserve both existing target attachments, never
write zeros. The reference specifies output values, not instruction scheduling
or sample side effects on discarded fragments.

## Limits

This is a CPU numerical reference and explicit input contract, not a Godot MRT
implementation, verified host constant-buffer construction, original vertex
shader execution, texture decoder, attachment/blend/depth policy, HDR/display
pipeline or complete original render graph. The current Godot color-section
probe remains separate and still stops before this postprocess stage.

## Accepted verification (2026-10-22)

- Independent read-only instruction review: all nine bytecode/layout pairs and
  original float32 immediates match; no must-fix findings. The corrected model
  fixture VS, dynamic inputs, separate buffers, MRT oracle and COM ownership
  received a separate independent static review.
- 29 affected Python color/UV/postprocess tests pass, including nine new output
  contract cases. Existing 37-node/111 color and 111 signed-factor cases remain
  accepted within their original scopes.
- The joined CPU reference matches **104 retained genuine D3D cases** across all
  nine selected programs (including five discards), max absolute error
  `1.50e-7`. These retained cases use neutral postprocess/constant model factors;
  they are not new nonneutral execution coverage.
- **36 new genuine D3D11 WARP cases** execute powder1, shape1 and model1 with
  nonneutral exposure, ApplyToneMap 0/0.4/1, signed/nonbinary BlendStateType and
  a nonuniform DOF LUT sampled using emitted fixture-VS depth. Model1 additionally
  varies Fresnel position/normal/axis/exponent and unequal parameter rows,
  including the orthogonal-vector epsilon floor. Both RGBA32F MRTs agree with
  independent native oracles within `5.97e-8`; separate CPU comparisons are
  within `6.02e-8`. This new nonneutral gate covers **three**, not all nine PSs.
- Failed stale-oracle/VS-input, JSON-format and Windows compiler-quoting attempts
  remain private evidence and are not counted as passes. Corrected cases retain
  the original `3e-6` acceptance tolerance. Task executables, objects, raw input
  copies and owned process trees were released; final normalized-path remote
  audits found no task processes. No VPS renderer/browser was launched.

No new Godot/exported-platform, game-host input or original-game frame-equivalence
claim follows from these CPU and WARP checks.
