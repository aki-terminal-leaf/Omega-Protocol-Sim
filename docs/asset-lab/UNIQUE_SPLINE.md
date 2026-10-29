# Unique inverse spline checkpoint — 2026-10-29

Base: `1f79a0316cd319ac23b78584c7f921e5005ddb7d`. Local-only, visual-only.
Runtime acceptance of this change is **BLOCKED / NOT_RUN**, not PASS.

## Rationale and source boundary

The owner revalidated MIT Dalamud-VFXEditor revision
`05f6eb0cce19a6a91ae275bce609299d573914b3`,
`VFXEditor/Formats/AvfxFormat/Curve/AvfxCurveData.cs`, `GetDrawLine` / `Bezier`.
This editor drawing routine supplies both x handles from the LEFT key:
`x1=x0+left.data[0]*(x3-x0)/2`,
`x2=x3-left.data[1]*(x3-x0)/2`;
`y(u)=y0+(y3-y0)*(3u²-2u³)`.
It does not prove native-game inversion or branch selection.

The previous evaluator rejected an entire segment if its x derivative was
negative anywhere. That rejects queried times with exactly one inverse too.
The change retains the original monotone path and its 48 bisection iterations.
Only nonmonotone scalar segments enter the new helper. Derivative roots split
the domain into at most three monotone intervals; exactly one strict crossing
is required before 64 bounded bisection iterations. Coordinates are translated
and scaled internally for conditioning; source time/value units and handles
are unchanged. The inverse is never replaced by normalized time.

Derivative quadratic roots use the stable quadratic formula, with explicit
linear/constant cases. Near-zero discriminants, unresolved partition spacing,
near-boundary contacts, small inverse derivatives and excessive residuals
return null. A shared tangent boundary is one mathematical inverse, not two;
this implementation rejects such ill-conditioned contact conservatively.
It deliberately does not promise support for every mathematically unique root.
Multiple roots remain unsupported, even with equal y endpoints. No branch is
chosen by first/last/closest position, and no source keys are sorted or merged.

Exact source-key hits and existing outside-mode, single-key, linear, step,
RGB and PRNG paths are unchanged. Existing unknown-field, enum, nonfinite-key
and decreasing/duplicate-time rejection remains in place.

## Evidence and pending acceptance

Owner-reported baseline audit: 52,230 UV samples, unsupported Rot 0 / Scl 7 /
Scr 8. Parent independent derivative-partition bisection and numpy companion
roots agree the 15 remaining sampled failures each have exactly one inverse.
These are parent-provided findings, not a newly executed audit in this session.

Owner-provided actual source example:
`vfx/monster/gimmick2/eff/z3oe_b3_g07c0i.avfx`, SHA-256
`49e344b747d98f57c2ab2ff15d014a381c2e377aa718ca57e1a366e45a2433f1`,
particle 7, UV 2. Expected material values at frames 9 / 45 / 9:
scale `(1.8646448740577428,1)` / `(1,1)` / first value again;
scroll `(-.733907208498072,0)` / `(-.100000001490116,0)` / first value again.
The scale x controls are `[0,18,12,12]`; scroll x controls are
`[0,18,6.00000071525574,12]`.

The immutable parent fixture contains 196 polynomial cases (180 seeded
synthetic, 15 actual, one explicit three-root negative); 18 cases must remain
null. It also exercises actual `_animate_material` at 9 / 45 / 9. The trusted
acceptance runner additionally reruns the frozen 42-check single-key fixture.
Neither fixture nor cache was modified.

Executed from this worktree:
`python -X utf8 D:/Dev/OpenClawCodexBridge/probes/resume-50685-spline-acceptance.py`.
It exited 1 with `PermissionError: [WinError 5]` creating
`D:/Dev/OpenClawCodexBridge/probes/top-unique-spline-gate-50685-1793266154919522700`.
This occurred before staging or Godot launch. No new runtime result, numeric
PASS, resource receipt or raster evidence exists from this attempt. No ACL
bypass or alternate unbounded Godot invocation was attempted. The parent's
ordinary-user JobObject runner must supply acceptance on these exact sources.

`tools/asset_lab/test_unique_spline.gd` adds 13 public synthetic checks for
unique/ambiguous roots, equal-value ambiguity, tangent/near-boundary rejection,
derivative degeneracy, nonfinite geometry, exact keys and the monotone path.
These checks are also **NOT_RUN** here. `git diff --check` passed; that is only
source whitespace validation, not GDScript parsing or runtime acceptance.

Native inversion/branch semantics, ambiguous animation portions, raster and
all-96 visual acceptance remain **OPEN**. Unknown CoUF, binders, material masks,
host stops and shaders are not cleared. Audio is excluded (N_A). No GUI,
input, browser, capture, commits, pushes, releases or deployment were performed.
