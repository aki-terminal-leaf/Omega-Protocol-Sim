# Visual curve checkpoint — 2026-10-29

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


Base: `fef9f5c5dc183d02cb2f43ff3e7050e63a85179a`. Scope is visual-only;
audio implementation/integration and auditory QA are excluded by the owner.
Native outside-curve semantics, raster validation and all-96 visual acceptance
remain **OPEN**. The source change below awaits the trusted parent runtime gate.

## Renderer degenerate-curve policy

`avfx_animation.gd: Runtime.value()` treats exactly ONE validated source key as
constant outside its key time only when the applicable BvPr/BvPo is Const (0),
Repeat (1), or Add (2). It returns the original scalar/RGB value. There is no
repeat interval and Add has zero endpoint delta; no division or cycle count is
needed. This is an explicit conservative renderer policy, not a claim about
the native game's outside behavior.

Validation precedes this rule: nonfinite query/key times and key data, unsupported
key types, unknown fields and non-increasing/duplicate times remain rejected.
Missing, None and unknown outside behaviors still return null outside the key.
The existing multi-key interpolation/Repeat/Add path is unchanged, including
flat-valued keys at distinct times. Preview RNG policy, animation units, source
data and material wiring are unchanged.

The owner reports that the pinned VFXEditor `GetDrawLine` source supports the
single-key value and multi-key math, but does not implement native outside
behavior. That source was not independently re-inspected for this checkpoint;
editor behavior labels are not native-host evidence.

## Frozen actual source and pre-fix evidence

Read-only cache: `D:/Dev/OpenClawCodexBridge/probes/top-lab-visual-cache-50685-v1`.
The following files were successfully read and JSON-decoded before editing:

- `record.json`: SHA-256 `99c20b4e3bdcd208ee94b754e13c98db940511402509a29647d6536ec53c7c5b`
- `full-data.json`: SHA-256 `5f5197248e1be5099c9931e7d2371d9dc32e9663fa60864a59f1e1451232e7c3`
- `manifest.json`: SHA-256 `8cac7036e5cc38f671dd6637183f0648f5fcd645f2b1810078cd82a60e1dc90c`

Manifest/full-data resolution reached `assets/full_fx_4d5d73985b7d50213baa.json`
for `bg/ex2/05_zon_z3/common/vfx/eff/b2726pil01_f1.avfx`. Its source SHA-256
matches `1348aa3056de10e7d982b2346d98e76852d922c55ace6812938233dee50fa8e9`.
Ptcl 2, UV set 0 has scale (8,1), single-key ScrX .270000010728836 at t=0
with post Repeat, and ScrY linear [0,0] to [40,1] with post Repeat.
Expected renderer scroll at frames 9/45/9 is (.27,.225)/(.27,.125)/(.27,.225).

OBSERVED: existing parent baseline evidence was read without modification at
`D:/Dev/OpenClawCodexBridge/probes/top-visual-curves-gate-50685-1793265444413096500/`:
`result.json`, `visual-curves.log`, and `visual-curves-receipt.json`.
The frozen fixture executed 42 checks, with 18 failures (24 passing checks).
All three actual `_animate_material` rows reported `uv_curve`; scale and scroll
uniform reads were `<null>`. This is a rejected update, not a measured numeric
pixel/UV displacement: no numeric error magnitude can be inferred from null.
The source branch explains the cause: Repeat/Add require end > start, so a
single-key component returns null and rejects the entire UV update.
Post-fix causal confirmation remains pending runtime acceptance.

The baseline receipt identifies Godot 4.7.2, headless, `--audio-driver Dummy`,
exit 1 without script errors, 1.5 GiB JobObject limit and about 26.36 GiB minimum
free RAM. Parent-reported broader audit: 52,230 actual UV component cases,
Rot 12 / Scl 35 / Scr 104 failures (151 total). That audit was not independently
rerun here; these counts are not a count of affected miniatures or proof that
every failure has the same cause.

## Validation blocker and handoff

The unmodified trusted command was attempted from this worktree:

```text
python -X utf8 D:/Dev/OpenClawCodexBridge/probes/resume-50685-visual-curves-acceptance.py
```

It terminated with exit 1 before staging or Godot startup: `PermissionError:
[WinError 5]` creating the external evidence directory
`D:/Dev/OpenClawCodexBridge/probes/top-visual-curves-gate-50685-1793265482372297300`.
The command was bounded by a 530-second outer timeout; no timeout occurred.
No gate/fixture was modified or relocated, and no permission workaround was used.
The Linux `fcntl` work guard was not run. Runtime regression status is **BLOCKED**,
not PASS; no post-fix Godot execution or raster observation occurred here.

Next: parent runs the same unmodified command with its authorized output access,
reviews actual material uniforms at 9/45/9 and regression assertions, and reruns
the independent actual UV audit under the trusted JobObject memory/time limits.
Preserve the baseline directory and new unique evidence. Even a passing headless
gate does not close native/raster or all-96 visual acceptance. No unrelated
P2 CoUF gate, audio work, GUI, capture, browser, commit, push, release or deployment
is part of this checkpoint.
