# TOP development execution contract

The user's 2026-10-21 instructions supersede older "finish everything before
committing/responding" checkpoints. Preserve the 20-mechanic goal, but deliver
coherent, reviewable increments.

- Commit one validated mechanic, shared dependency layer, visual pipeline or
  tooling stage at a time. Do not wait for all five strategies/all 20 mechanics.
  Stage only task-owned source/docs; never extracted game media, raw logs or
  private build artifacts. After each reviewed commit, push the current project
  development branch directly (user authorization2026-10-21); no repeat approval
  is needed. Never force-push or alter upstream. A development push is not a
  released build; release/export claims still require their actual platform gates.
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
- Current approved engine baseline is **Godot 4.7.2-stable**, after the isolated
  parser/mechanic/original-asset/Windows/Web migration gates passed on2026-10-21.
  `top/data/engine_lock.json` pins engine/templates; rollback4.4.1 is commit2d9e832.
  GDScript is upgraded with
  Godot, not as an independent package. Never share `.godot` caches between
  versions. New feature work after the migration uses only the pinned version's
  documented, locally verified Windows/Web-supported APIs. Do not introduce
  nightly-only, speculative or plugin-required APIs as native features.
- Count passing actual assertions/courses separately from source uncertainty,
  production wiring and exported-platform QA. Godot can exit zero on script
  errors: reject `SCRIPT ERROR`, `Parse Error` and `Compile Error` in test logs.

## Current scope and verification window (owner 2026-10-28, Telegram50293)

All unfinished TOP roadmap work is resumed, superseding the original-resource-only
hold. AnAn desktop/native GUI/input/capture is authorized for this TOP task until
2026-10-28 18:00 Asia/Taipei (10:00 UTC); wrap/save by17:50 and stop desktop work
by18:00, even if scheduling is delayed. It does not renew the next day or authorize
unrelated projects. Preserve unrelated windows and serialize input ownership.
Authorized non-desktop work may continue after the cutoff. Use scoped source and
actual exported-platform gates; do not turn a local pass into full-guide acceptance.

## AVFX / shader schema evidence

- Treat every ShPk file's ordered key schema as local to that file. Apricot
  packages can differ in both key count and order (the current originals have
  2,55,56 or57 scene keys). Never zip another family's labels/defaults against
  a node vector. Resolve by its owning package's IDs and validate cardinality.
- Shader key/value CRC labels are explicit source mappings, not necessarily
  CRC32 of their human-readable labels. Never invent unknown IDs by hashing
  guessed names or claim a partial semantic match is an exact host selection.

## Milestone publication and branch policy (owner 2026-10-28)

After every coherent validated increment, publish its scoped GitHub release and deploy the exact accepted Web build. Keep main as the published baseline and develop as integration; preserve unmerged historical work under recoverable archive refs. Source-only pushes do not complete a releasable milestone. Actual Web gates remain required. See docs/development/BRANCHES.md.
