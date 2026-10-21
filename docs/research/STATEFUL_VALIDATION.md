# Stateful validation ? 2026-10-21

Base: `55bbc64529447e1560367f9d402bc2d5224b9a2c`. Work was limited to the job worktree and the requested paths. No commit, push, merge, deployment or packaging. No edits to `visuals.gd`, `arena.gd`, assets or tools. Read-only `git status --short` confirmed `D:/Dev/Omega-Protocol-Sim` remained clean (a command-local safe.directory exception was needed for the sandbox account; no Git configuration was written).

## Sources actually read

- [Tuufless P3](https://ffxiv.tuufless.com/elemental/top/03_omega_reconfigured/): debuff descriptions, contact/overwrite, Debuggers, latents and fourth-iteration order. The text supports these interaction types; it does not establish numerical contact radius or simultaneous server ordering.
- [Delta](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_delta/), [Sigma](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_sigma/), [Omega](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_omega/): actual page contents, not titles alone. Supports paired Delta breaks, fourteen Sigma shots, and Omega utility/World roles.
- [P1](https://ffxiv.tuufless.com/elemental/top/01_omega/) and [Aether](https://www.thepfstrat.com/u/top): Loop ordering and Panto priority/missile-ahead conventions. Panto descriptions no longer describe towers. LPDU/CN/KR prior provenance is retained; this pass obtained no new complete regional macro set.
- Local independent reference files under `D:/Dev/OpenClawCodexBridge/research/top-v03`: `TOPEnums.cs`, `TOPStates.cs`, `P1ProgramLoop.cs`, `P2LimitlessSynergy.cs`, `P3HelloWorld.cs`, `P5Delta.cs`, `P5Sigma.cs`, `P5Omega.cs`, `P6CosmoArrow.cs`, `P6FlashGale.cs`. These supply community event/geometry observations, not server proof. GDScript was implemented independently.
- The local set did not contain `P6WaveCannon.cs`. Public GitHub/raw requests failed, and a read-only network fetch was denied by the sandbox. Consequently exaflare advance, count and origin topology remain explicitly unverified rather than being promoted to measured behavior.

## Executable changes

`statuses.gd` stores serializable runtime statuses, event chronology, failures, death flags, paired lines and moving streams. Contact/expiry evaluation runs on interpolated movement with a configurable numerical step. It never consults route labels or desired recipients. The integration step is not claimed to be a server tick.

P3's old endpoint-pair transfer assertions were removed. Initial grants and assigned tether schedules initialize the encounter; subsequent rot/bug recipients come from actual contact and blast geometry. Unresolved colour latents and early vulnerable breaks fail even after later movement is correct. Simultaneous opposing colour sources use the explicit reject-ambiguous unverified policy; opposite-colour application otherwise overwrites, while Debugger blocks it. Same-colour refresh behavior is configurable and unverified.

Delta lines are breakable player pairs. Omega beetle lines use transferable contacts, radius-15 blasts and actual blast-victim exclusion from the following World; after the blast there is no live line to steal. Continuous P5 carries actual state rather than synthesizing intermediate stacks. Sigma has fourteen shots, not seven grouped checkpoints.

Omega hazard geometry is actual attack primitives, not a result-safe wedge. All 32 supported stance/orientation/wave combinations have independent known-safe test coordinates and attack-boundary checks. This verifies the explicit training family, not all original spawns. Arrow uses orthogonal translated strips. Exaflares keep origin, advance, next explosion and remaining count across beats and judge each scheduled blast.

Reports include statuses, actual positions, timeline, owners, failure history and archived retry attempts. Checkpoints replay interactions. Retry restores the saved pre-beat state; it does not grant desired ownership or erase the archived failed attempt. DSR-style movement, camera, jump, sprint, knockback resistance and dash controls were retained.

## Test commands and results

Godot: `D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe`.

Run from the job worktree in PowerShell:

```powershell
$godot = 'D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe'
& $godot --headless --path top --log-file "$env:TEMP/top-stateful-import.log" --editor --import --quit
& $godot --headless --path top --log-file "$env:TEMP/top-stateful-rules.log" --script res://tests/rules.gd
& $godot --headless --path top --log-file "$env:TEMP/top-stateful-interactions.log" --script res://tests/interactions.gd
& $godot --headless --path top --log-file "$env:TEMP/top-stateful-snapshots.log" --script res://tests/run.gd
& $godot --headless --path top --log-file "$env:TEMP/top-stateful-stateful.log" --script res://tests/stateful.gd
& $godot --headless --path top --log-file "$env:TEMP/top-stateful-runtime.log" --script res://tests/runtime.gd
& $godot --headless --path top --log-file "$env:TEMP/top-stateful-stress.log" --script res://tests/runtime.gd -- --contact-stress
```

| Check | Result |
| --- | --- |
| Import | Exit 0; no script parse/compile errors |
| Existing rules | 190 assertions, 0 failures |
| Existing interactions | 18 assertions, 0 failures |
| Snapshot geometries | 38,700 snapshots, 0 failures |
| Stateful negatives / persistence | 70 assertions, 0 failures |
| Runtime courses | 96 courses, 0 failures |
| Contact stress (Loop + Limitless, seeds 1?48) | 240 courses, 0 failures |
| `git diff --check` | No whitespace errors |

Godot printed an environment certificate-store warning. Editor import also could not save global editor settings under the sandbox account; import still exited 0 and scripts compiled. An initial run without `--log-file` crashed trying to open the restricted default user log; subsequent commands explicitly used the permitted temporary directory. No tests were skipped to conceal that failure.

The snapshot suite still explicitly constructs ideal line-owner fixtures; it is **not** runtime evidence. Runtime and stateful suites physically execute transfers. Existing rules/interactions/snapshot assertions were not weakened. Runtime test changes only add optional `--only-scenario=`, `--only-seed=`, `--only-method=` and `--diagnose` filters; the default suite still runs all exposed courses.

A real contact-stress regression occurred in KR Loop seed 33 with the corrected radius-15 Blaster. The bot released its line but could not reach its far guide refuge in time. The fix selects a nearby safe refuge that also avoids live line capsules; neither radius nor failure judgment was relaxed. The failing case and the full 240-course stress run then passed.

Final Delta route review corrected outer-blue movement inward for fist pairing, then moved the still-live inner pair far enough apart in the later break beat. The targeted Delta/full-P5 courses and all 38,700 snapshots were rerun after that correction.

The negative suite covers wrong/unassigned infection away from an endpoint, donor retention, opposite overwrite/Debugger, simultaneous contact ordering, no recursive same-batch infection, expiry splash/latent death, wrong infection at a geometrically correct tower, early vulnerable and timed-out breaks, both line policies, dynamic damage ownership, previous Blaster-victim World exclusion, clone families/boundaries, Arrow displacement, moving stream origin/spacing/timing, actual Main retry restoration, report contents, checkpoint infections and final Local-before-Remote order.

## Remaining unknowns / limits

See [FIDELITY](FIDELITY.md) for the full mechanic table. Critical remaining gaps: original exaflare spawn families and timings; all original Omega clone spawn combinations; exact contact/tether thresholds, server tick and vulnerability durations; full HP/healing/death-trigger rules; all regional routes; original Panto/Arrow/other snapshot timing. Loop Looper expiry is still wave-resolution based. Paired-tether activation schedules and P3 initial remaining durations are training schedules. No passing test is live-game proof.

## Exact changed files

- `top/scripts/main.gd`
- `top/scripts/encounters.gd`
- `top/scripts/rules.gd`
- `top/scripts/interactions.gd`
- `top/scripts/statuses.gd`
- `top/scripts/statuses.gd.uid`
- `top/tests/runtime.gd`
- `top/tests/stateful.gd`
- `top/tests/stateful.gd.uid`
- `top/data/catalog.json`
- `top/data/strategies.json`
- `top/data/mechanic_strategies.json`
- `top/data/fidelity_parameters.json`
- `top/data/sources.json`
- `docs/research/FIDELITY.md`
- `docs/research/STRATEGIES.md`
- `docs/research/STATEFUL_VALIDATION.md`
