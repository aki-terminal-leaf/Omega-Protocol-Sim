# Unique inverse spline validation

## Parent reconciliation - 2026-10-29, final original-precision acceptance

**Current scoped PASS: conservative unique-inverse scalar editor geometry,
exact-zero endpoint derivative factorization, and sampled source UV/material
updates. Native game semantics, raster and all-96 visual acceptance remain OPEN.**

Frozen runtime SHA-256:
`1ff1d287cbace3680e3181d60c44b29ba95424a59d5aa72336bf85bd7962c266`.
Frozen public test SHA-256:
`29944e5ec4522144ccfa058ad4e61b5ea9b63560c3502be07c573f219a93d4cd`.
Parent froze all four files before review. The comprehensive attempt timed
out at 120 seconds without a verdict (not PASS). One reduced-scope Claude
Sonnet 5.5 read-only retry reviewed the endpoint factor and complete inverse
helper: NO_MUST_FIX. Parent separately reviewed the full four-file diff and
corrected test oracle. This is not native/raster/full-product approval.
Documentation reconciliation is subsequent parent-only text; runtime and test
remain byte-exact to the independent acceptance/review snapshot.

Evidence: private AnAn
`top-spline-endpoint-gate-50685-1793267019654656500/parent-final-proof.json`.
21 public synthetic checks, 42 single-key/source-uniform regressions,
207 spline/source-material checks (18 ambiguous cases remain null),
21 exact fold/tangent/ambiguity checks, and 22 additional exact-original-source
material/forward-reverse checks all PASS, with no script errors.
52,230 original-precision UV component samples at frames 0/9/45/117/171 have
zero unsupported samples (Rot 0 / Scl 0 / Scr 0), versus prior 0/7/8 and the
first unique-spline candidate's 0/0/2. These are finite sample cases, not
52,230 effects or 96 completed performances; unsampled ambiguous portions
remain unsupported, and this audit only covers CUvT=0 component sampling.

The two exact-original source materials restore correct scroll values at
9/16/9 and 45/60/45, rather than leaving the prior timepoint's stale uniform.
Original SHA-pinned JSON is read directly: a 15-digit diagnostic JSON
round-trip previously hid the endpoint-partition failure. Runtime correction
uses exact original-coordinate equality and algebraic derivative factoring,
not tolerance snapping or removing genuine internal roots.

The bridge task `top-spline-endpoint-50685` historically FAILED on its new
public assertion "near right endpoint is not snapped". The model's separate
sandbox run was blocked at external directory creation (WinError 5). Both
records are retained, neither is relabeled a pass. Parent independently
confirmed that synthetic target has exactly one well-conditioned inverse
u=.2/value .104, so mandatory null was an invalid test oracle. Parent changed
only that assertion to accept the correct value or conservative rejection;
no runtime code was changed or source precision rounded. The final bounded
parent invocation above then passed every gate including true multiple-root
and tangent negatives. This correction and failed logs remain in parent
reports; no repeated model job or sandbox/ACL bypass was used.

All runs used real Godot 4.7.2 headless, Dummy driver and dedicated 1.5 GiB
JobObject/free-RAM floor 8 GiB. Import peak RSS 744341504 B; full UV audit peak
RSS 336252928 B; material proof peak RSS 138362880 B. Short-process RSS samples
can undercount peaks: job-private metrics are retained in each receipt.
No desktop, GUI, capture, audible playback, release or push was performed.
Audio remains excluded and its isolated worktree is not integrated.
CoUF/binders, host/player poses, original shaders/material masks, persistent
scene states, cinematics and actual visual/exported-runtime acceptance remain
OPEN; these numeric checks do not clear them.

## Historical candidate records (superseded only for the scope above)

# Endpoint partition correction ? 2026-10-29

Current correction is **BLOCKED / NOT_RUN for runtime acceptance**. It is an
uncommitted change on preserved failed candidate
`bcacca51fa01169a718b6dcc63730ce85a4be27a`; original baseline
`1f79a0316cd319ac23b78584c7f921e5005ddb7d` remains untouched.

## Reconciled historical evidence

The parent reports frozen 207 spline checks (including material 9/45/9),
42 regression checks, 21 exact ambiguity/tangent checks and 13 public checks
PASS on the prior candidate. Nevertheless, its exact-original 52,230-case UV
audit still had **2 unsupported Scroll samples**. Those passes do not accept
that candidate or this correction. The historical sandbox attempt below is
retained; its NOT_RUN status describes that attempt, not the later parent run.

Read-only diagnosis:
`D:/Dev/OpenClawCodexBridge/probes/resume-50685-spline-endpoint-diagnosis.json`.
The parent identified m0513sp04c0c.avfx Ptcl2 UV0 ScrY at 9 (SHA-256
`ba9120ff627ed182dba6cbdf4a755770d1c76bcbe2db08282bf90e0fb3adfacd`) and
m0515hide_sp01c0c.avfx Ptcl3 UV0 ScrY at 45 (SHA-256
`a5992e439aaf8b36bd4ef0d27d0a265eb211b03ef21299879a0f61d5575c6102`).
Both have exact x2==x3, but expanded quadratic evaluation produced roots
0.9999999999999998 / 0.9999999999999996 and spurious tiny final partitions.
Earlier fixtures used Godot diagnostic JSON's 15-digit serialized controls,
not exact original-source doubles: their scoped PASS missed these failures.
These are assistant/parent findings, not owner experimental claims. Historical
fixtures/results and the immutable source cache are unchanged.

## Scoped correction and verification

Only exact original-coordinate equality x1==x0 or x2==x3 selects derivative
factorization. For a=0, D(u)/3=u*(2*b+(c-2*b)*u); for c=0,
D(u)/3=(1-u)*(a+(2*b-a)*u). Solve only the remaining linear factor;
when both endpoints are zero, 2*b*u*(1-u) has no internal root for positive
span. This removes endpoint roots algebraically, without tolerance snapping,
root merging or source-handle rounding. Generic stable quadratic/linear and
uncertain-discriminant handling, spacing/residual/derivative guards, 64-step
bisection, monotone 48-step path, exact keys and RNG are unchanged.

The public fixture now contains 21 checks: the historical 13 plus eight for
full-double exact endpoint zeros at each end, both zeros, another left-zero
inverse, near-but-not-exact endpoints, tangent rejection and multiple inverses.
The synthetic overshoot 1.6300000000000003 reproduces the old formula's
spurious root 0.9999999999999997 in a Python double arithmetic source check;
that check is not a Godot runtime result. No original asset dump was added.

Executed the required command from this worktree:
`python -X utf8 D:/Dev/OpenClawCodexBridge/probes/resume-50685-spline-endpoint-acceptance.py`.
It exited 1 with PermissionError / WinError 5 creating
`D:/Dev/OpenClawCodexBridge/probes/top-spline-endpoint-gate-50685-1793266695001153600`.
Failure preceded staging/import/Godot; all current runtime gates are NOT_RUN.
No permission bypass or alternate Godot runner was used. The trusted parent
runner must validate the final saved sources with its 1.5 GiB JobObject and
8 GiB free-memory floor, including zero unsupported samples in all 52,230
exact-original UV cases. Even that PASS would cover sampled curves only.

Native branches, raster and all 96 units remain **OPEN**. Audio is excluded.
No GUI/input/capture/browser, commit/push/release/deploy was performed.

---

## Historical checkpoint (retained; reconciled above)

# Unique inverse spline checkpoint — 2026-10-29

Base: `1f79a0316cd319ac23b78584c7f921e5005ddb7d`. Local-only, visual-only.
Runtime acceptance of this change is **BLOCKED / NOT_RUN**, not PASS.

## Rationale and source boundary

The prior assistant/parent findings reference MIT Dalamud-VFXEditor revision
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

Parent-reported baseline audit: 52,230 UV samples, unsupported Rot 0 / Scl 7 /
Scr 8. Parent independent derivative-partition bisection and numpy companion
roots agree the 15 remaining sampled failures each have exactly one inverse.
These are parent-provided findings, not a newly executed audit in this session.

Parent-provided actual source example:
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
