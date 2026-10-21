# Headless input review — 2026-10-21

Status: reviewable source patch; exported-platform validation **pending**. No
commit, push, merge, deployment, desktop input, headed browser or interactive
Godot was used. No mechanics, actors, routes, speeds, HP or LB rules were edited.

## Findings

The existing source385 Web export reproduced the post-target JSON failure in
headless Chrome **155.0.8059.80**, at 1440x900:

- Actual GUI selected P6 meteors, Elemental, D3, seed 17391 and checkpoint six.
  The initial JSON succeeded at simulation time 17.137734920635, with
  `checkpoint_assisted=true` and player view active.
- Target-popup screenshots and the later HUD show `meteor_1` selected. Pointer
  lock was null before/after target selection. Immediately after the unnecessary
  world click it became `CANVAS`, persisting through P/F/P and the first JSON
  attempt. That download timed out after 2500 ms.
- The screenshot immediately before JSON still shows player view, closed target
  popup, selected meteor_1, paused HUD and the JSON button at (1393,809). Thus
  this reproduction is not a return-to-setup or stale-coordinate failure.
- Pointer lock cleared during the failed JSON click, before the explicit
  `document.exitPointerLock()` workaround. The subsequent JSON succeeded at
  simulation time 25.0183682539685. Do **not** attribute recovery solely to the
  explicit workaround or count it as a passing original flow.
- The recovered report has a separate real failure: actor 6's F request at
  17.949334920635 was rejected with `Insufficient LB3 gauge`. Both large meteors
  retained 209324 HP. Hints remained false. No successful ranged cast is claimed.

The demonstrated download obstruction is persistent pointer lock after a quick
world click. Asynchronous capture completing after release is the source-level
explanation consistent with the evidence; the exact engine event ordering is
not instrumented. No-click and held-drag comparison runs remain **pending**:
the combined Node fallback job hit its hard 120-second timeout after completing
the click case. No repeated browser submission followed that timeout.

## Changes

- `top/scripts/main.gd`: reconcile captured mouse with zero camera buttons each
  frame, before simulation early returns; Escape also releases a stale capture
  when the logical button count is already zero. This is a narrow proposed fix
  for the observed obstruction, not an exported-Web pass.
- `top/tests/input_presentation.gd`: 17 assertions using real Godot input event
  dispatch, HUD/popup hit testing, pause, focus, release over HUD, Escape and
  actual target binding. Full actor/runtime JSON is unchanged by these GUI
  operations. No actor/state/time fixture edits. This test cannot simulate the
  browser's asynchronous pointer-lock completion.
- `tools/web_smoke.py`: player-HUD JSON coordinates; open settings before
  changing mechanism; use setup JSON coordinates for the unconfigured report.
  Existing gameplay assertions were retained.
- `tools/headless_input_probe.py`: portable bundle/output/channel CLI, owned
  localhost server and headless browser, separate none/click/drag modes,
  screenshots and read-only DOM capture before/after operations, strict actual
  JSON/LB assertions, failure records and explicitly labeled recovery. A 100s
  internal evidence budget leaves room for browser/server cleanup.

## Verification and commands

Commands were launched through Python `subprocess.run(..., timeout=120)` (import
allowed 360); APPDATA and LOCALAPPDATA were redirected only in the Godot child
environment to this worktree's `top/.godot/local-user`.

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path top --script res://tests/input_presentation.gd
INPUT PRESENTATION checks=17 failures=0

Godot_v4.7.2-stable_win64_console.exe --headless --path top --script res://tests/presentation.gd
PRESENTATION checks=24 failures=0
```

Both final runs used the changed main.gd and exited zero. Logs were additionally
checked for SCRIPT ERROR, Parse Error and Compile Error: none. Both emitted
`Failed to read the root certificate store`, an unresolved environment warning.
Python AST parsing passed for both public tools; `git diff --check` passed.

Portable probe invocation (repeat separately for `none`, `click`, `drag`):

```text
python tools/headless_input_probe.py --bundle PATH_TO_WEB_BUNDLE --output OUTPUT_DIR --channel chrome --interaction click
```

Local Python 3.14 execution is **blocked** by missing `greenlet`; the probe now
records this as `pass:false` in diagnostics and closes its server. A bounded
worktree-only dependency installation failed because sandbox networking was
denied. No global dependency/configuration changes were made. The existing
Playwright Node runtime could launch Chrome, so a private equivalent Node probe
provided the baseline click evidence. The Node job ended with TimeoutExpired;
the completed click context closed and the Python server closed in finally.
Final browser-process cleanup after the forced Node termination could not be
independently verified: process ancestry inspection was denied. No unrelated
processes were terminated.

Other corrected harness/tool failures: `python3` and `rg` are absent; Windows
Python and built-in searches were used. `work_guard.py begin` cannot run because
it imports Unix-only `fcntl`; bounded subprocesses were used instead. The first
import's log-save failed because its evidence directory had not been created;
subsequent test logs are preserved. A shell quoting error was corrected using
literal here-strings/apply_patch. Direct viewport event injection failed popup
tests; after stopping that approach, Input.parse_input_event and global popup
coordinates corrected the harness (without weakening assertions).

## Evidence and remaining gates

Private artifacts stay under `top/.godot/headless-input-review/`:
`input_presentation-final.log`, `presentation-final.log`, retained failed input
log, `stage-resume.json`, `python-probe/diagnostics.json`, and
`browser/baseline-probe.js`. The exact fallback command was the installed
Playwright `driver/node.exe -e <baseline-probe.js contents> <owned localhost URL>
<browser output directory>`, bounded to 120 seconds. The click subdirectory
contains diagnostic states, before/workaround-after JSON and screenshots for
each operation, including `after-before.png` and `world-click-after.png`.

Parent must export the changed source canonically, then run independent bounded
no-click/click/held-drag cases and the updated smoke test. The old PCK evidence
does not prove this patch. Browser-race regression coverage, full ranged-cast
success, Windows export QA, and all-source fidelity remain pending. No new
templates were installed and no export claim is made.


## Parent integration review

The changed source independently passed Linux headless input17, presentation24,
party/status106 and camera60 checks, all zero failures with strict script-error
checking. The generic probe now waits for actual shared gauge readiness and
actual NPC damage, with bounded attempts and a three-sample stall breaker.
It does not change simulation time, actors, resource rules or packet delays.
The baseline caster cast at9.0/finish13.5 left gauge0 until the actual queued
refund18.55 (damage19.1/unlock21.6); requesting ranged LB before that refund
correctly rejects. These are existing model timings, not new server calibration.
New canonical exported-browser none/click/drag runs remain pending until built.
