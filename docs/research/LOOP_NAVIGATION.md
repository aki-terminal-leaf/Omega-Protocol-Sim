# Program Loop navigation at 6 units/second

2026-10-21; isolated worktree based on `90be92e`. Changes are confined to
`interactions.gd`, additive diagnostics/negative checks in `p1_fidelity.gd`,
and this note. No new helper or navigation-data dependency is required.

## Movement coordination

The existing physical pickup remains an edge crossing of the actual moving
0.65 capsule. The planner only returns movement goals. It does not assign
owners, move actors, change outcomes, or clear failures/statuses.

1. Retiring carriers retain the inward handoff to radius 3. Collectors retain
   the short pickup and angular matching to their prescribed outgoing goals.
2. Acquired carriers keep their rays short while non-carriers leave the center.
   Clustered short rays separate laterally to expose a pickup edge for the
   remaining collector. Free-player refuges are outside radius 5.5.
3. Release requires every non-carrier to be outside radius 4.5 and to have a
   clear continuation toward its destination relative to the future outgoing
   rays. Tower assignments and the five source priorities are unchanged.
4. The nearer outgoing carrier starts first. The other waits until that carrier
   reaches radius 4.5 and aligns with its prescribed cardinal (dot >= 0.995).
   This avoids both visibility-graph paths chasing each other's moving ends.
5. During the last 0.75 seconds, free-player refuges are revalidated against
   actual carrier positions as well as their prescribed R17 destinations.
   Replanning starts below 15.5 clearance and searches with 15.8 clearance;
   the actual Blaster radius remains 15. Tower players keep their tower goals.

All motion in the harness remains ordered `move_toward(goal, 6 * dt)`, with
`dt <= 0.025`; actual previous positions feed swept contacts. No Sprint is used.
The preactivation return precedes any owner-dependent planning. Identical tower
pairs remain in the generator. Blaster destination goals remain the existing
empty cardinals at R17; attack slots, deadlines, HP/Ruin rules, human controls,
and server contact code are unchanged.

The ownership policy remains source-unverified. The full corpus uses the
existing configured policy; passing it does not verify exclusive ownership as
an official rule. The negative crossing fixtures exercise both
`unverified_exclusive` and `allow_multiple` without changing either policy.

## Diagnostics and negative gates

- All 56 ordered distinct initial-owner pairs produce the same preactivation
  goals, independent of the hidden initial-owner array.
- A nearby retiring tower player prevents outgoing ray growth; calling the
  planner changes neither actor positions nor ownership.
- Two actual three-unit crossings over 0.5 seconds steal both live lines under
  each policy, even though the desired owners remain different. Human failure
  remains possible.
- `--loop-trace` logs half-second physical positions, the goals already used
  by the ordered movement loop, holders, and release state. It does not call
  the planner a second time.
- `--loop-regressions` explicitly selects seeds 3, 4, 8, 16, 20, 21, 46, 47
  across all five profiles (40 courses). Default coverage remains all 240.
- `--loop-restore` round-trips only navigation state midway through each Loop
  wave. Route/refuge coordinates are numeric arrays, read with `Rules.v`, and
  cache keys are strings. This is not a full authoritative-state restore test.

An exploratory round-trip of the entire authoritative state failed and is not
claimed as supported by this change. The navigation-only flag deliberately
isolates the planner contract; Rules/Statuses serialization was outside scope.

## Reproduction and validation

Godot: `D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe`.
Run from the worktree, with a writable log outside the source tree:

```powershell
$godot = 'D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe'
& $godot --headless --path top --log-file "$env:TEMP/loop-final-full.log" --script res://tests/p1_fidelity.gd -- --loop-only
& $godot --headless --path top --log-file "$env:TEMP/loop-restore.log" --script res://tests/p1_fidelity.gd -- --loop-only --loop-restore
& $godot --headless --path top --log-file "$env:TEMP/loop-regressions.log" --script res://tests/p1_fidelity.gd -- --loop-only --loop-regressions --loop-restore
& $godot --headless --path top --log-file "$env:TEMP/loop-probe.log" --script res://tests/p1_fidelity.gd -- --loop-probe elemental 3 --loop-trace
```

Completed runs, all exit code 0:

| Gate | Result | Wall time / evidence |
| --- | --- | --- |
| Full default 240, all existing checks plus new negatives | 1102 assertions, 0 failures | 66.54 s; `%TEMP%/loop-final-full.log` |
| Full 240 with navigation JSON restore | 1040 assertions, 0 failures | About 64 s; `%TEMP%/loop-full5.log`; before the 62 new negative assertions |
| Forty retained failure fixtures + navigation JSON restore | 702 assertions, 0 failures | About 13 s; `%TEMP%/loop-regressions.log` |
| Panto/Cannons/events and new negatives | 1266 assertions, 0 failures | 19.69 s; `%TEMP%/loop-final-events.log` |
| Sigma | 5221 assertions, geometry=640, 0 failures | `%TEMP%/loop-sigma.log` |
| P6 | 1334 assertions, 0 failures | `%TEMP%/loop-p6.log` |
| Existing interaction tests | 18 assertions, 0 failures | `%TEMP%/loop-interactions.log` |

The initial intermediate changes produced 66, then 5, then 4, then 2 failing
courses. These were real failures, retained during development rather than
filtered out. Both final full-corpus runs have no failing seeds.
Native/Web and the parent's independent Main checkpoint run are not claimed
by these headless harness results. A Windows root-certificate-store diagnostic
appeared on engine startup; the listed suites completed normally.

## Parent merge verification — 2026-10-21

Three-way merged against90be92e, preserving the parent Omega short-ray handoff, exclusive-vs-multiple ownership navigation consistency, and arena-bounded AI goals. Independent parent full240 with navigation JSON restore: **1,102 assertions, 0 failures**. Actual Main mechanism/strategy/demo path: **15 courses, 0 failures**. Persistent fullP5 after this shared navigation-cache change: **15 courses, 0 failures**. This does not upgrade navigation-only restore into authoritative full-state restore or prove the unverified server ownership policy.
