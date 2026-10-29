# Validation status

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

# Endpoint correction status ? 2026-10-29

**Current endpoint correction: BLOCKED / NOT_RUN.** The exact trusted parent
acceptance command exited 1 with WinError 5 creating its external evidence
directory before staging or Godot. No current runtime PASS is claimed.
See [endpoint correction and retained history](UNIQUE_SPLINE.md) for diagnosis,
command, failed output path and the narrow algebraic change.

Parent-reported prior candidate `bcacca51fa01169a718b6dcc63730ce85a4be27a`:
207 spline + 42 regression + 21 exact tangent/ambiguity + 13 public checks PASS,
but exact-original 52,230 UV audit retained 2 unsupported Scroll samples.
The 15-digit diagnostic JSON fixture lost source precision and missed these
endpoint partition failures. These are assistant/parent findings, not owner
experiments. Historical evidence below is preserved, not current acceptance.

Only the evaluator, public synthetic fixture and these two checkpoint documents
are changed. Eight new synthetic cases bring the public fixture to 21 checks;
all await the trusted bounded runner on the final sources. The original cache,
old fixtures, accepted baseline and preserved failed commit are untouched.
Source whitespace validation is separate from parsing and runtime gates.
Native branches, raster and all-96 acceptance remain OPEN; audio is excluded.
No commits, pushes or deployments were made.

---

## Historical validation records (reconciled above)

# Validation status

## Unique-inverse local candidate — 2026-10-29

The [unique spline checkpoint](UNIQUE_SPLINE.md) adds conservative unique-inverse
evaluation only for nonmonotone scalar editor geometry. **New candidate runtime
acceptance: BLOCKED / NOT_RUN.** The trusted acceptance invocation exited 1 at
external evidence-directory creation (`WinError 5`) before staging or Godot.
The frozen 42-check regression, 196 polynomial vectors (including 18 required
null cases), and actual material frames 9/45/9 have not run on this candidate
in this sandbox. The new 13-check public synthetic fixture is also NOT_RUN.
Source whitespace validation passed; it is not parser/runtime acceptance.

The accepted base `1f79a0316cd319ac23b78584c7f921e5005ddb7d` retains its historical
scoped PASS below. That result does not certify this edited candidate. The
parent reports independent unique-root agreement for the 15 remaining source
samples; post-change source-uniform acceptance still requires its bounded
ordinary-user runner. Historical failures are retained. Native semantics,
ambiguous portions, raster and all-96 remain OPEN; audio remains excluded.

## Parent reconciliation — 2026-10-29, after bridge acceptance

**Current scoped status: PASS for the single-key renderer policy and the frozen
42-check source-material fixture. This supersedes only the historical sandbox
blocker below. Native semantics, raster and all-96 visual acceptance remain OPEN.**

The bridge's ordinary-user independent acceptance ran after the model's sandbox
attempt. Evidence: `top-visual-curves-gate-50685-1793265609866258200/summary.json`:
42 checks, no failures/script errors; actual source material at frames 9/45/9 has
scale (8,1), scroll (.27,.225)/(.27,.125)/(.27,.225). Import peak RSS 744390656 B;
source fixture peak RSS 132390912 B; both under 1.5 GiB job limit, free RAM above
8 GiB. No GUI, capture or audible playback was used.

Frozen source SHA-256:
`b0066c2ef4cd459b189d076ec51ef98d2a564ec924e94aee6cea0e8c92262b2b`.
Parent froze all three changed files before Claude Sonnet 5.5 read-only review;
verdict NO_MUST_FIX, not runtime or full-product approval.

Separate actual-source UV audit:
`top-visual-curves-uv-audit-50685-1793265735028449700/summary.json`:
52,230 cases; unsupported Rot 0 / Scl 7 / Scr 8, versus baseline 12 / 35 / 104.
This resolves 136 prior unsupported sample cases, not 136 visual units. Fifteen
remaining samples contain non-monotone spline x geometry. They remain OPEN;
no monotonicity guard was relaxed in this checkpoint. Audit exit 0 merely means
the diagnostic completed, not that the remaining 15 were accepted. Native-game
branch choice/outside behavior, raster and all-96 fidelity are not certified.

The API is static `value()` in `avfx_animation.gd`; `Runtime` is a fixture alias.
Nonfinite key times are explicitly rejected by this patch. Audio remains N_A
under current owner scope; no audio files were integrated.

## Historical model-sandbox snapshot (retained, superseded above)


**All-96 acceptance: OPEN. No release, repository push or existing-site replacement has been performed for this lab.**

Owner correction (2026-10-29): current acceptance is **visual-only**. Audio
development/integration and auditory QA are excluded (N_A for this scope),
not acceptance blockers. The visual baseline is `fef9f5c5`; no files from the
stopped audio worktree are part of this change.

The [single-key visual curve checkpoint](VISUAL_CURVES.md) records the actual
pre-fix material UV failure and conservative renderer policy fix. Post-fix
headless acceptance is **BLOCKED**: the unmodified trusted runner cannot create
its external evidence directory under this session's filesystem permissions.
Native outside semantics, raster validation and all-96 visual acceptance remain
**OPEN**; source inspection is not runtime or visual acceptance.

Godot 4.7.2 only. Original actor/scene-matrix/EID numeric composition has a scoped source-oracle pass (30 poses, 2621 bones); this is not original-game visual fidelity.

The [source lifetime/controller gate](LIFECYCLE.md) passed 17 boundary vectors, 300 independent exact-event oracle cases and supported-subset sampling across 162 source graphs (83 finite supported / 79 unknown). The independent model's too-early-bound counterexample was reproduced before repair; failed logs remain recoverable.

Earlier Windows resource-inspector captures apply only to that earlier frozen inspector build. They do not validate the new composite controller or certify all 96 performances. No AnAn GUI/native playback/capture has been dispatched after the 2026-10-28 18:00 Taipei desktop cutoff.

The [hidden original-reference target gate](ATTACHMENTS.md) also passed all 50 human EIDs (2000 independent world matrices). Recorded individual race/action poses remain unknown; no player bodies are rendered. Nondefault coordinate-update binder semantics are rejected, not guessed.

The actual lab UI now routes through a per-unit director with source/cache/catalogue/attachment pins, exact original cue keys and separate review-window clocks. Review padding never synthesizes a source stop. Six cinematic units plus the P1 exit transition lack original choreography and are unavailable, not successful empty playback. Temporal body/tether context is distinct from action ownership; prior no-removal tethers remain explicitly unknown.

Remaining within current visual scope: complete per-unit performance content beyond this routing, original binding/host semantics and unresolved rendering, recorded-player pose/source host dependencies, cinematic decoding/playback and final actual visual/exported-runtime acceptance. Audio and auditory QA are excluded from current owner acceptance. Sample counts, parser success and numeric checks never substitute for those gates.
