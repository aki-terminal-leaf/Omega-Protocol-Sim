# TOP development execution contract

The user's 2026-10-21 instructions supersede older "finish everything before
committing/responding" checkpoints. Preserve the 20-mechanic goal, but deliver
coherent, reviewable increments.

- Commit one validated mechanic, shared dependency layer, visual pipeline or
  tooling stage at a time. Do not wait for all five strategies/all 20 mechanics.
  Stage only task-owned source/docs; never extracted game media, raw logs or
  private build artifacts. Do not publish merely because a local stage passed.
- One stage is at most **25 minutes**. Require new source/result evidence at
  least every **15 minutes**; text output, repeated status polls and unchanged
  evidence do not renew progress. One command is at most **10 minutes**.
- Use `python3 tools/work_guard.py begin STAGE`, then `run LABEL -- COMMAND`.
  Long tests may set `run LABEL --timeout 600 -- COMMAND`. Record a changed
  evidence file with `progress PATH`; finish only after the stage is reviewed.
- Three identical command-failure fingerprints block the stage. A timeout or
  stalled stage blocks immediately. Preserve the failing seed/log and change
  the approach; resuming requires `begin STAGE --reason 'concrete change'`.
  Never retry by creating fresh task IDs, reset counters or poll indefinitely.
- The independent native scheduler checks every five minutes, not an LLM work
  loop. It alerts once per blocked state and never restarts work. The wrapper
  enforces timeouts and terminates only its own command process group. Already
  submitted remote jobs retain their original server-side 40-minute limits;
  new worker stages must respect this contract. Commit/test phases are serial:
  never mutate the Git index while another stage's gate/commit is pending.
- Every meaningful tool-driven operation must use a bounded command. Where
  this wrapper is unavailable (remote bridge), set the bridge's explicit hard
  timeout and collect a terminal status before resubmitting anything.
- Current approved engine baseline is **Godot 4.4.1**, until the migration gates
  in `docs/development/GODOT_UPGRADE_PLAN.md` pass. GDScript is upgraded with
  Godot, not as an independent package. Never share `.godot` caches between
  versions. New feature work after the migration uses only the pinned version's
  documented, locally verified Windows/Web-supported APIs. Do not introduce
  nightly-only, speculative or plugin-required APIs as native features.
- Count passing actual assertions/courses separately from source uncertainty,
  production wiring and exported-platform QA. Godot can exit zero on script
  errors: reject `SCRIPT ERROR`, `Parse Error` and `Compile Error` in test logs.
