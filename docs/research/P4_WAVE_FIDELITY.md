# P4 Wave Cannon fidelity handoff — 2026-10-21

Implemented in isolated base `90be92efcc840f0d61761ba12742ac350d821977`. This is the P4 Wave Cannon movement/judgment course for the first five route profiles, **not a claim that all 20 mechanics or all of P4 combat are complete**. Parent integration is intentionally not performed. No commit, push, merge or deployment. The original `D:/Dev/Omega-Protocol-Sim` was checked with read-only Git status and is clean.

## Integration contract

- Parent dispatches **only** `p4_wave` to `preload("res://scripts/p4_wave_courses.gd").append_wave(ctx)`. `append_course(ctx)` is an alias.
- Deterministic forcing: `append_family(ctx, [[a,b],[c,d],[e,f]], family)`, actor indices `MT,ST,H1,H2,D1,D2,D3,D4 = 0..7`. Each marked pair is distinct; 28 pairs per cycle. Timing family is 0..3 in JSON order. Random generation uses only `ctx.rng`; seed/checkpoint ownership stays with parent.
- Context needs `profile.id`, `positions`, `rng`, and `beat(title,duration,note)` returning an appended dictionary. Guide positions are goals only, never runtime evidence.
- `statuses.gd` has exactly three added one-line calls, to runtime `begin`, `tick`, `sync`. **Manually merge these three lines into the parent's newer file; do not replace its unrelated Delta/Omega/HW hooks.** No other existing file was changed.
- `begin(beat,state)` queues events only when the first beat carries `p4_wave_events`; subsequent beats preserve pending events. On checkpoint resume, restore state and continue ticking; do not enqueue the first beat again. Retry by restoring the pre-course checkpoint and replaying the same forced pattern/seed.
- `tick(actors,previous,state,dt)` expects `state.sim_time` already advanced, exactly as parent Interactions does. It samples each due event by interpolation across the supplied motion segment. Call it for every movement segment. Skipped historical events fail explicitly. Runtime does not alter positions, actor ownership, route goals or statuses.
- Default motion budget is 6 units/s. Explicit parent `motion_allowances[actor]` is a **per-tick distance**, capped here at 7.5 units/s for real Sprint. No 11/s route or implicit Sprint. Parent must use appropriate bot walking speed; this patch does not edit parent motion logic.
- `stage_entities` contains `p4_wave_boss`, original registry `form:"final"` (Omega Reconfigured), center position. This is the actual P4 boss form, not a generic fallback. P4 evidence does not call for separate fist/arm entities. Asset loading/rendering belongs to parent; this gate does not prove local GLB presence or rendering.
- Preview shapes are decorative and tagged `p4_wave_preview`, rebuilt idempotently without deleting parent shapes. Actual judgments use pending events, not preview shapes.

## Mechanics and measured timing

The course runs continuously from the first Wave Cannon visual cast start (T0) through the last ring plus 0.1 seconds. It does not insert seven-second beat gaps. Boss reappearance precedes T0 by approximately 9.3 seconds. All three cycles contain eight current-player-directed initial beams, eight delayed beams frozen to those bait angles, and two marked-player-directed line shares. All lines are forward length100, full width6. Every living player must be inside exactly one share, with four living players in each. This is not a radius-six circle check. Valid initial hits are recorded; no HP/mitigation immunity is granted.

There are **two expanding four-hit sequences (eight rings total)**, with radii 0–6, 6–12, 12–18, 18–24. Cycle2 proteans follow ring2 by approximately 0.6 seconds; ring3 follows shortly afterward. Sequence2 ring1 occurs just before cycle3 repeat/stack, and ring2 occurs after the stack. The third group must wait outside ring2 before moving inward. All geometric boundaries are unsafe (shared Rules adds its existing 0.001 ring tolerance); deathwall is radius20 inclusive.

Times below are seconds from each capture's first 31617 begincast, not damage-animation arrivals. Near-identical packet timestamps within 100ms were grouped; the earliest timestamp is used (e.g. the 2ms split in LKM's first eight proteans).

| Capture / family | Proteans ×3 | Repeats ×3 | Stacks ×3 | Rings ×8 |
|---|---|---|---|---|
| 1bX86aKrVRwLWfTC/19 / 0 | [5.604, 15.771, 25.984] | [10.354, 20.524, 30.729] | [10.576, 20.702, 30.907] | [12.973, 15.104, 17.15, 19.237, 30.417, 32.507, 34.593, 36.638] |
| 3GW2hjTNk91FZwcK/9 / 1 | [5.596, 15.771, 25.985] | [10.349, 20.519, 30.744] | [10.572, 20.697, 30.879] | [13.018, 15.149, 17.234, 19.32, 30.432, 32.527, 34.574, 36.625] |
| LKMGRJTzgY9HFynk/2 / 2 | [5.621, 15.8, 26.027] | [10.357, 20.533, 30.762] | [10.581, 20.711, 30.94] | [13.029, 15.129, 17.183, 19.238, 30.45, 32.544, 34.599, 36.654] |
| Vyq4AcJKZjkFQBpG/32 / 3 | [5.583, 15.732, 25.931] | [10.32, 20.472, 30.671] | [10.544, 20.606, 30.804] | [13.001, 15.106, 17.162, 19.219, 30.357, 32.456, 34.515, 36.571] |

These four families are measured timing samples of the same encounter geometry, **not invented randomized ring patterns**. Markers are separately timed from six 22393 cast events in each clear. Marker timestamps and the earlier repeat cast-start timestamps are preserved in JSON.

Snapshot uncertainty: 31616 begin-casts occur about 0.535 seconds before 31614's initial hit, while the behavioral reference presents bait resolution at the initial hit. The implementation freezes actual player angles at initial resolution and repeats them about 4.74 seconds later. The exact sub-frame server angle snapshot is not proved by this replay sampling. It is explicitly unresolved, not silently represented as precise official timing.

Source center validation: every live boss 31617 cast is raw(9999,9999); all 24 stack casts,96 repeat casts and32 ring casts are raw(10000,10000). Raw/100 minus(100,100) yields arena coordinates. Three clears' initial proteans also consistently report center. In 3GW's first cycle, two helper samples report raw(10000,9000), and other helper facings are inconsistent with actual player locations. These are rejected as stale helper state: the live boss, other cast origins, actual player positions, guides and reference support center. No moving source was invented from these fields.

## Five independent source audits

All access/review dates are **2026-10-21**. No login, cookies, secrets or access-control bypass was used. Existing cached evidence was inspected first. Public LPDU/KR pages and the CN video were inspected using a newly created task-owned CDP9222 tab, subsequently closed. Sources establish common geometry independently; five profile labels alone are not evidence.

| Profile | Primary evidence inspected | Supported route decisions / limits |
|---|---|---|
| Elemental | [Blue Screen](https://ffxiv.tuufless.com/elemental/top/04_blue_screen/), steps1–12, plus cached regional diagram audit | West MT,D3,H1,D1; east ST,D4,H2,D2. Lower same-side marker trades with opposite melee. Cycle2 inward dodge before stack; cycle3 stack then wait/inward. |
| Aether | [PF P4 prose](https://www.thepfstrat.com/u/top), P4 section; all15 steps of [Dylan v2.1 Toolbox595188367474761](https://ff14.toolboxgaming.space/?id=595188367474761&preview=1) in cached semantic JSON | TRHM, DPS on W/E and SW/SE waymarks; same-side lower marker/opposite melee flex. Steps6–9 establish second-wave ring movement; steps10–15 third-wave outside wait/inward. |
| LPDU | [Live primary markdown](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md), overview and Phase4; follows its exact link to the same15-step Toolbox | Shared Toolbox is direct primary linkage, not inherited from Aether. Overview TRHM/MHRT; same lower-target/melee swap and complete three-wave movement. |
| CN Moogle | [QQ macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) cached regional audit; [original full poster](https://www.bilibili.com/opus/800287973844189204), P4 panel visually inspected from1125x33824 image, crop y15500–16875 | Independently shows MT,D3,H1,D1 left and ST,D4,H2,D2 right, two southern shares, and explicit lower-marker/D1-or-D2 swap. Poster has no precise ring times. |
| KR09STOP | [Public Phase.4 sheet](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/htmlview?gid=776696341), actual tab title verified; rows9–12,35,62,88,113,141,168,195,220, plus cached diagram role map | Tanks/healers between marks, DPS at marks; lower marked/opposite melee swap; restore original slots; cycle2 beam then inward; cycle3 outside share, wait for ring, inward. |

Toolbox audit used actor **job labels**, not repurposed object keys: `healer1` is DRG, `healer2` SAM, `dps1` SGE, `dps2` SMN, `dps3` MCH, `dps4` WHM. Fifteen steps' positions and notes were read. The guide's optional solo-tank stack is not supported by this 4+4 movement course; no mitigation capability is invented.

CN original [av740517066 part3](https://www.bilibili.com/video/av740517066/?p=3) was opened and identified as the P3/P4 tutorial (worker did not preserve the Chinese title), duration26:44. The normal public player showed login/30-second preview. Later P4 frames were not accessed or measured. [BV1vz4y1B7xP](https://www.bilibili.com/video/BV1vz4y1B7xP) is the linked lower guide; it was not used to establish P4 timing. CN poster route plus common encounter timing is implemented; full original-video confirmation remains a concrete gap.

No guide pixel coordinates are claimed official. All five independently support this shared TRHM formation and swap rule; exact 22.5-degree offsets and radii14/9 are **legal numerical realizations**, validated physically. The manifest keeps `complete_source_geometry:false` for every profile.

## Physical movement matrix

Normal traces start at center and use `move_toward(goal,6*dt)` throughout. There is no snapping at beat transitions. Spread radius14 angles in role order are `[292.5,67.5,247.5,112.5,225,135,270,90]`; stack angles west/east are202.5/157.5. Stacks1/3 radius14; stack2 and final inward refuge radius9. The matrix below is the maximum straight-line distance over **all28 marked pairs**, in arena units; return trips have the same distance. It includes actual same-side swaps.

| Role | Spread14 → stack14 maximum | Spread14 → stack9 maximum |
|---|---:|---:|
| MT |19.799|16.643|
| ST |19.799|16.643|
| H1 |19.799|16.643|
| H2 |19.799|16.643|
| D1 |15.556|13.437|
| D2 |15.556|13.437|
| D3 |23.281|19.324|
| D4 |23.281|19.324|

Longest stack1/3 approach needs3.881s; shortest protean→repeat allowance among captures is4.733s. Longest stack2 approach needs3.221s. Initial center→spread needs2.334s, versus earliest protean5.583s. Final inward move needs0.834s after second sequence ring2, versus at least2.047s until ring3. These distance checks alone are insufficient for ring safety: the full matrix samples motion and resolves each overlapping ring/beam at its actual scheduled time.

## Evidence integrity and confidence

All four manifests say complete. All **28 files** (metadata, enemy-casts, five replay segments per clear) verified SHA-256 against **decompressed bytes**, as specified by the collection manifests. Comparing gzip container bytes would incorrectly report mismatches. Across these manifests there are175853 replay events and4875 enemy cast events. No player identities were imported into runtime.

- [1bX86aKrVRwLWfTC/19](https://www.fflogs.com/reports/1bX86aKrVRwLWfTC?fight=19), retrieved `2026-10-21T02:31:49.024960+00:00`; manifest SHA-256 `622656039bd21815a6e144cc0704ece52dfb253d187dd921aca965e06736aace`;7/7 file hashes pass.
- [3GW2hjTNk91FZwcK/9](https://www.fflogs.com/reports/3GW2hjTNk91FZwcK?fight=9), retrieved `2026-10-21T02:31:48.922016+00:00`; manifest SHA-256 `fb50140d950c327c1f86e7a8800a7f3363675f0f2079c4708af4dc3d3e9dcc6a`;7/7 file hashes pass.
- [LKMGRJTzgY9HFynk/2](https://www.fflogs.com/reports/LKMGRJTzgY9HFynk?fight=2), retrieved `2026-10-21T02:30:35.436115+00:00`; manifest SHA-256 `8bfb4d06f41587b3e85847e3cdb5c7a5e07a521e1459291a720f2c7b03fe3347`;7/7 file hashes pass.
- [Vyq4AcJKZjkFQBpG/32](https://www.fflogs.com/reports/Vyq4AcJKZjkFQBpG?fight=32), retrieved `2026-10-21T02:31:49.176920+00:00`; manifest SHA-256 `a5e57ad8e5ff4288ae7b1ed882496ee65a5b7fa1e1706cca16ca0731418b5313`;7/7 file hashes pass.

Read-only behavioral crosschecks: `TOPEnums.cs` identifies31614/31615/31616 and31567–31570 dimensions; `TOPStates.cs` P4 sequence establishes ordering; `P4WaveCannon.cs` establishes boss→actual-player proteans and two target-directed line shares. Original GDScript was written independently; no C# source was copied/translated. Timing confidence is high for these captures; exact snapshot timing and animation are not established. Source file hashes are retained in JSON `reference_audit.files`.

## Final-code acceptance gates

Godot4.4.1 stable `49a5bc7b6`, headless. Both gates independently completed well below120 seconds. The full matrix was launched separately with a longer-running process allowance.

```
P4_WAVE_GATE mode=quick assertions=279 failures=0 physical_cases=20 elapsed_ms=559 max_observed_speed=6.00002925185596
P4_WAVE_GATE mode=full assertions=2454 failures=0 physical_cases=560 elapsed_ms=16919 max_observed_speed=6.00002925185596
```

The tiny speed excess is Vector2 floating-point precision, under the runtime's0.001-unit distance tolerance. Full matrix:5 profiles ×28 pairs ×4 timing families; each cycle uses a different permutation of the28 pairs, so every pair is physically covered in every cycle/profile/family. Quick mode retains all140 logical pair/profile checks and20 physical courses. Additional traces cover timestep0.017/0.033/0.1/0.2 seconds, normal-walk failure, stationary old-beam wipes, exact width/length/ring boundaries, 3+5 and5+3 shares, double clipping, longitudinal line shares that radius-six circles would reject, dead participants, interpolation at lock time, missed historical events, explicit Sprint, rejection of11/s even with an oversized allowance, preview idempotence, no status grants, and JSON restore including old pending beams. Full mode also compares restored and uninterrupted history for every profile/family. The matrix does not enumerate all28^3 independent cross-cycle triples; each cycle's28-pair coverage is exhaustive and inter-cycle assignments reset to the original formation.

Exact command used (PowerShell, in worktree; audit path temporarily held the log and was replaced by this report after the final run):

```powershell
& D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe --headless --disable-crash-handler --log-file D:/Dev/OpenClawCodexBridge/worktrees/top-p4-wave-complete-20261021/docs/research/P4_WAVE_FIDELITY.md --path top --script res://tests/p4_wave_fidelity.gd -- --quick
# Full: omit the trailing -- --quick.
# For reruns, use a separate writable --log-file path to preserve this report.
```

Initial attempts using default user logs and Windows NUL failed because those log destinations were unavailable; task-owned crashed sessions were stopped. Final runs use the explicit writable path. Godot emits an environment `Failed to read the root certificate store` diagnostic, but these offline gates exit0. No network-dependent test is hidden or skipped. `git diff --check` passes.

Code version fingerprint is SHA-256 of each path UTF-8 + NUL + exact file bytes, concatenated in the following order (documentation and UID metadata excluded):

`99a65047a4f615c9e2f393d8230c2256e87f5e04aec0c44e9ba5b6dd161873f8`

| File | SHA-256 |
|---|---|
| `top/scripts/p4_wave_courses.gd` | `dcbcc797cd86f33f0b84c5f717a2b3040e3195a15dcadb570eb2a918adfad9de` |
| `top/scripts/p4_wave_patterns.gd` | `10218b0d157a84ada485dc11558f858b5f8220978ac0de1d706c584b24332e7d` |
| `top/scripts/p4_wave_runtime.gd` | `48083f906ef0ae2671821d5f014afa2089c7509cd45b7474df99809e0bcce834` |
| `top/data/p4_wave_routes.json` | `5abd14b33c251add5e49863f39a8ad1ec4a8b921a1ac7adb6afe7803950e67f7` |
| `top/tests/p4_wave_fidelity.gd` | `4838f04879e8e36b885e91fb9e1247e3f20265d189ba7e02d4d28433a86957b2` |
| `top/scripts/statuses.gd` | `673ca01505eb97f361ec37d0221cc9217316430bfb9eb6c9737e70b5d18df7a3` |

## Remaining scope / limits

- Parent must wire the new course and merge only the three status hooks. Existing old P4 dispatch is not replaced in this isolated patch by design. No Main/Arena/Rules/Interactions/Encounter/global-parameter/strategy changes.
- This handles the full Wave Cannon/ring movement sequence. Boss autos, HP, healing, damage mitigation, job LB casts and Blue Screen's below20% DPS/enrage outcome remain parent/combat scope and are not falsely passed.
- Exact server sub-frame angular lock remains uncertain; original CN P4 video inspection is blocked by the public preview limit; primary diagrams are not a source of official numeric coordinates.
- No end-to-end parent UI/model-render gate was run. Stage metadata references the original P4 form but does not substitute a procedural model or prove assets installed.

## Parent integration — 2026-10-21

The isolated-worker handoff above is historical. Production `p4_wave()` now
dispatches this continuous course; all five audited methods are selectable. The
three hooks were manually merged, preserving P3/P5/HW/Limitless/P6 hooks.
Production bots walk at6/s; the stage's original-form boss hides the duplicate
background actor. No raw encounter logs or extracted assets are committed.

Parent Godot4.4.1 gates: quick279/0; full2454/0 across560 physical cases;
actual Main15 courses/0 (five methods ×three seeds); shared review211/0;
P3 quick2268/0 after adding P4 hooks. The exact integrated fingerprint, using
the path+NUL+bytes convention above, is `b468f47b3e448043ee2f275c1e7db2f64edc1329b67ec653e2005b6a54ac9d95`.
This is parent/headless verification, not exported Windows/Web or visual QA.
All source, snapshot, HP/mitigation and DPS limits above remain active.
