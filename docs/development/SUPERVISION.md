# Incremental work and independent supervision

Requested by the user on 2026-10-21. Use the existing OpenClaw native scheduler
and Python standard library; no paid service, recursive agent or new daemon.

## Enforced bounds

- Stage wall-clock limit: **25 minutes** (maximum, not renewable by logging).
- No new evidence: **15 minutes** maximum. A new source/result hash can advance
  `last_progress`; printing output or reusing the same file content cannot.
- Command wall-clock limit: default/max **10 minutes**, bounded by its stage.
- Three identical normalized failure fingerprints: circuit breaker. Godot's
  script/parse/compile errors count as failures even when its exit status is 0.
- Timeout, stall or executable-launch failure blocks the stage. Preserve logs;
  do not silently restart. Resuming requires a concrete changed-approach reason.
- One owned command at a time; `flock` rejects overlap. Commands use their own
  process group; termination never searches for/kills unrelated processes.

The wrapper enforces active-command stops. The scheduler independently persists
blocked state and alerts; it cannot terminate arbitrary unwrapped agent thoughts
or old remote jobs. All subsequent work must use the wrapper or an equivalent
explicit bridge timeout. Already-submitted P3/P4 jobs retain their original
40-minute server limits; do not duplicate them to reset elapsed time.

## Routine use

```sh
python3 tools/work_guard.py begin p3-transition-review
python3 tools/work_guard.py run focused-check --timeout 180 -- godot --headless --path top --script tests/example.gd
python3 tools/work_guard.py progress /absolute/path/to/new-check-result.log
# Inspect the actual result and staged diff; commit the coherent segment.
python3 tools/work_guard.py finish
```

Use the actual pinned Godot binary, not an assumed `godot` on PATH. `--` separates
runner options from the command's own flags. In a blocked stage, first preserve
its reproducer and select a changed approach, then for example:

```sh
python3 tools/work_guard.py begin reduced-reproducer --reason 'Retained seed; narrowed to physical last-frame contact'
```

Do not fabricate proof files or call `progress` solely to defer a stall. The
execution ledger and command logs live in the worktree's Git administrative
directory (`git rev-parse --git-path top-work-guard.json`), not public source.

## Deployed observer

Native automation `b8286c9d-0096-4840-b525-f6198bae6b50`, declaration key
`top-segment-watchdog-20261021`, checks **every five minutes**. Its deterministic
source is `tools/top_supervisor.js`: one tool call, 20-second probe, 30-second
scheduler wall limit, no LLM. Normal/done states are silent. A blocked signature
is notified once in the existing private project conversation. Scheduler execution
errors also alert, with a 30-minute cooldown. It never requests new work or retries.

Check timing and notification dedupe are native scheduler state, not a separate
polling timer file. Project execution timestamps are stage evidence, not a second
scheduler. Other existing automations were inspected and left unchanged.

## Validation

`python3 -m unittest discover -s tools/tests -p test_work_guard.py -v` covers
stage/stall bounds, changed-proof requirements, overlap, three-failure breaker,
exit-zero script errors, process timeout, executable-launch failure and terminal
state, and interrupted-wrapper child cleanup. `node tools/tests/test_top_supervisor.js` checks healthy silence, first
alert, duplicate suppression and a genuinely new incident without sending real
messages. A live native scheduler run completed successfully, persisting its
observation while correctly sending no healthy-state notification.

Keep Git index mutation/test/commit sequential. This is especially important for
intermediate snapshots of shared runtime files: validate exactly the staged tree
and never let another stage modify it before that segment is committed.
