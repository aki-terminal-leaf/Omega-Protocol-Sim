# Bounded AVFX curve decoding and editor-line math

This stdlib-only stage supports future particle work; it is not a renderer or
original-game playback implementation. No Godot runtime/API is involved. The
project engine baseline remains 4.7.2. Native numeric times are retained without
an FPS/seconds claim; angle values remain radians, without UI degree conversion.

## Evidence and traversal

Format/math reference: maintained MIT
[Dalamud-VFXEditor at 05f6eb0cce19a6a91ae275bce609299d573914b3](https://github.com/0ceal0t/Dalamud-VFXEditor/tree/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat).
The provided local AvfxCurveData, AvfxCurveKey, AvfxCurveKeys, AvfxCurve3Axis,
AvfxLife and Enums sources were read only. Parent mappings were checked against
the same pinned revision's Emitter/AvfxEmitter.cs, Particle/AvfxParticle.cs,
Curve/AvfxCurve1Axis.cs, Curve/AvfxCurveColor.cs and Binder/AvfxBinder.cs through
the GitHub connector. No C# files or game assets were copied into the repository.

The implementation reuses avfx_meshes.blocks, unique, integer, version, count
mappings and the 16 MiB bound. It validates root counts, scalar widths, declared
key counts, alignment and finite values. Unknown enum/type numbers remain
unsupported data. Malformed structure and nonfinite data raise ValueError.

This inventory is **partial**, not a count of every possible curve in a file.
Only these root node paths are opened:

- Emit/Ptcl: Gra/GraR, ARs/ARsR; Pos/Rot/Scl with ACT, ACTR and
  X/Y/Z/XR/YR/ZR; Col with RGB, A, SclR/G/B/A, Bri, RanR/G/B/A, RBri; Life.
- Emit additionally: CrC/CrCR, CrI/CrIR, IAX/IAXR, IAY/IAYR, IAZ/IAZR,
  VRX/VRY/VRZ (these emitter velocity fields have a random role).
- Ptcl additionally: VRX/VRXR, VRY/VRYR, VRZ/VRZR.

Other fields stay opaque, including scheduler/timeline, effectors, binders,
type-dependent Data, particle texture/UV/simple-animation structures, models and
texture strings. No heuristic TLV recursion occurs. Binder Life is an integer
in the reference, deliberately not passed to the curve-Life decoder.
opaque_fields counts unopened fields, including ordinary parameters; it does
not assert every such field is a curve or unknown format feature.

The preservation policy matches the mesh reader: raw_avfx_base64 retains
**every input byte**, including unknown payloads, order and padding. Decoded
curves/axes/Life also retain original payloads; their unknown fields retain base64
payload bytes. Full JSON contains private asset data and must stay private.
Verification captured it in memory, never in tracked files.

## API and CLI

Import tools.avfx_curves or put tools on the import path. Pure entry points:

- decode_keys(data, count, kind="scalar"): actual 16-byte little-endian hHfff.
- decode_curve(payload, kind="scalar", random_role=False): KeyC/Keys,
  BvPr/BvPo/RanT, raw bytes and unsupported reasons.
- decode_axes(payload, kind="scalar"): numeric ACT/ACTR and only present axes;
  no synthetic connected axes or random draws.
- decode_life(payload): exact ffffffff disabled sentinel, otherwise optional
  Val/ValR float32 and Type uint32. Missing values stay null; other short
  sentinels are rejected. Life and random playback remain unsupported.
- sample_scalar(curve, time): bounded, interval-only editor geometry.
- inspect(data): deterministic path-indexed partial inventory.

Scalar/angle keys use data.x/data.y as spline controls and data.z as value.
RGB uses all three floats as color, never scalar.z. Time is signed int16,
type uint16: spline=0, linear=1, step=2. Angles remain radians.

Read-only CLI, JSON to stdout:

    python -X utf8 tools/avfx_curves.py --input PRIVATE_INPUT.avfx

The CLI creates no output file. JSON has no local filename, absolute machine
path or timestamp; it identifies data by hash and reference URL. It always
reports rendering_complete false. Errors return status 2 without leaking paths.

## Sampling contract and proof limits

Math follows **AvfxCurveData.GetDrawLine**, an editor drawing routine, not
independent proof of the game's evaluation, randomness, timing or precision.

For endpoints (x0,y0), (x3,y3), let h=(x3-x0)/2. Spline control points are
(x0+left.data.x*h,y0) and (x3-left.data.y*h,y3). Both x controls come from the
left key. The sampler checks the quadratic derivative minimum on [0,1],
rejects non-monotone x, bisects x(u)=time for exactly 64 iterations, then
evaluates y(u). It never substitutes normalized time for u. Crossing handles
are allowed when the derivative stays nonnegative. Near stationary derivatives,
inversion has ordinary double-precision conditioning limits.

Linear segments interpolate endpoint values. Step holds the left value until
the next exact key time; exact boundaries return that key's value. Keys must
be unique and increasing in original order: no sorting/deduplication.
Unknown types (including the final key), empty curves, RGB, nonfinite data,
non-monotone splines and unknown curve fields cannot be sampled. A one-key
curve supports its exact time only.

All outside-interval samples are rejected, including explicit Const (0).
Repeat (1), Add (2), None (ffffffff), unknown and absent behaviors are retained,
never guessed. Optional Const extension is unimplemented.

Every explicit RanT, including zero (FirstPlusMinus), conservatively blocks
scalar sampling, as does a known random field role without RanT. Thus all scalar
curves in these private inventories are currently rejected by the sampler;
supported math is verified on synthetic non-random curves. Decoding does not
prove whether/how RanT participates in playback. ACT/ACTR are retained; no
composite axis playback is supported even for None/absent connection values.
Individual scalar geometry is not connected-transform evaluation.

## Read-only private verification, 2026-10-21

Each CLI ran twice under subprocess timeouts. JSON parsed, output bytes matched,
full raw bytes round-tripped, and input bytes matched after probing. A separate
direct-path walker using the existing block reader counted Keys lengths / 16
without using the new decoder's counts. All counts matched. No private output
or asset was saved or published.

| Input | Curves | Keys | RGB curves / keys | Axis containers | Life | Opaque fields |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| meteor.avfx | 107 | 170 | 20 / 22 | 60 | 20 | 740 |
| comet.avfx | 71 | 115 | 13 / 15 | 39 | 13 | 500 |
| fist_b6.avfx | 121 | 171 | 15 / 24 | 45 | 15 | 474 |

Key types (spline / linear / step): meteor 0/170/0, comet 4/111/0,
fist_b6 21/146/4. No decoded nonfinite data, unknown key types, duplicate or
decreasing times, unknown curve fields or non-monotone splines were observed.
No Life sentinel occurred; sentinel coverage uses synthetic fixtures.

| Input | BvPr | BvPo | RanT (absent is not a default) |
| --- | --- | --- | --- |
| meteor | Const 107 | Const 101, Add 6 | 0:85, 3:2, absent:20 |
| comet | Const 71 | Const 66, Add 5 | 0:57, 3:1, absent:13 |
| fist_b6 | Const 121 | Const 120, Repeat 1 | 0:104, 1:2, absent:15 |

ACT histograms: meteor {0:47, 1:11, 2:1, 3:1}; comet {0:30, 1:6, 2:1, 3:2};
fist_b6 {0:38, 1:4, 2:3}. ACTR: meteor {0:60}; comet {0:39};
fist_b6 {0:43, 2:2}. These are enum numbers, not applied connection rules.

Unsupported counts overlap. Meteor/comet/fist_b6 respectively have 107/71/121
pre-range and post-range flags each; 60/39/45 axis-playback flags;
20/13/15 Life-playback flags; 20/13/15 RGB-sampling flags.
Random-playback totals are 107/71/121: scalar curves 87/58/106 plus
Life records 20/13/15. All Life records are enabled. Opaque counts above
cover additional unimplemented fields beyond these semantic flags.

## Validation and remaining work

Run the focused suite:

    python -X utf8 -m unittest discover -s tools/tests -p test_avfx_curves.py

Tests cover the 16-byte codec, asymmetric x inversion, monotone crossing
handles, boundaries/step/linear/angles, invalid counts/lengths/scalars,
nonfinite data, RGB distinction, random/outside-range rejection, key ordering,
Life sentinel, axis preservation, opaque traversal and lossless deterministic
inventory. Fixtures are original synthetic data, not game assets.

Remaining work: type-specific curve mappings, effect graph scheduling/emission,
random seeds/distributions and draw timing, axis composition, Life semantics,
pre/post behavior, color evaluation, time bases/loops, particle transforms and
coordinate order, collision, material/texture/UV animation, shaders/blending/
lighting, Godot integration, and actual Windows/Web exports and visual QA.
Original-runtime fidelity requires independent game evidence. Passing Python
assertions and private inventories do not prove those remaining behaviors.
