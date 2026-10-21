# P1 fidelity implementation and integration handoff

2026-10-21 current parent status: P1 production wiring and6-unit movement are
integrated; all240 Loop navigation cases were subsequently repaired and passed
(1102 assertions/0), see [LOOP_NAVIGATION.md](LOOP_NAVIGATION.md). The red Loop
results below are historical worker checkpoints, not current navigation status.
Panto/Cannons execute full continuous schedules;4.7.2 P1-event1266/0 and all
offered Main methods pass. Server contact radius/ownership uncertainty and
combat-model limits remain; no all-server completeness is asserted.

## Integration boundary

New APIs in `top/scripts/p1_courses.gd`:

```gdscript
P1Courses.append_panto(ctx)
P1Courses.append_cannons(ctx)
P1Courses.append_loop(ctx)
```

They append independent courses to the existing encounter context. `append_loop` retains the existing `program_loop()` slot generator. Parent integration must delegate the three corresponding `Encounters.build` branches and use 6 units/s for `p1_route` bots, including checkpoint simulation. No production integration is claimed here.

`statuses.gd` has exactly three P1 begin/tick/sync hooks. `interactions.gd` adds generic activation-time/contact guards, preactivation goals and hidden-line presentation. The close-ray capsule-edge pickup and proactive carrier-sweep yield navigation remain intact. `rules.gd` changes are confined to Loop state, Ruin, Looper deadlines, delayed HP Penalty and removal of the obsolete numbered-wave expiry shortcut. World, monitors, Omega HP duration, P6 files, global strategy JSON and scene/rendering code are unchanged.

Decorative runtime hazard previews are training guidance, not a claim to reproduce every live cast-bar/marker telegraph. All durable `state.p1` values are JSON-native. It owns `pending`, `history`, and `until`; it never reads a suggested goal to judge damage. Events record actual positions, actual targeted actors, actual hits, aims and scheduled timestamps. Baits capture every actor's interpolated position at the lock instant. The eight pending circles persist through beat changes and JSON restore. Runtime failures and deaths remain sticky. Authorized parent `motion_allowances` are honored; otherwise motion is limited to 6 units/s. There is no P6 metadata or exemption.

## Executed mechanic schedule

Panto T0 is Pantokrator finish / initial status grant. Numeric times below are nominal calibration, not a claim that every packet has zero jitter.

| Event | Schedule | Geometry / recipients |
|---|---|---|
| Flamethrower | T6.1 + 2n, n=0..13 | Two opposite 60-degree cones, radius 65; 30-degree turn each pulse |
| Initial cone family | Six 30-degree offsets relative to boss facing | Both rotation directions |
| Ballistic locks | T9.7 + 2n, n=0..9 | Eight actual actor positions per lock |
| Ballistic explosions | Three seconds after each lock | 80 radius-5 circles, last T30.7 |
| Guided Missile | T12.1, 18.1, 24.1, 30.1 | Number pairs 1,2,3,4; radius 5 |
| Condensed Wave | Same four times | Actual target number pairs 3,4,1,2; full width 6, length 50; three hits each |
| Final flame pair | T32.1 | Course continues through T32.3 |
| Diffuse Wave | Relative 0, 2.1, 4.1, 6.2, 8.3 | Reselect two actual furthest actors every pulse; full angle 120, range 60 |
| Cannon proteans | Relative 0 and 9.0 | Three marked non-tanks, then the other three; full width 6, length 50 |

Cannons includes a six-second legal positioning lead-in; relative zero above is course T6.0. All twenty three-of-six marker subsets are executable. Each beam/missile pulse must cover all eight actors exactly once, in addition to its own count/isolation checks. This rejects overlapping three-person beams even if each individually has three occupants.

Panto guidance uses 0.1-second route waypoints, with the harness independently moving actors in 0.025-second steps. The next missile stays for the additional bait at previous-beam +1.6, moves through the inner lane, reaches the front, exits back/out and rejoins. The alternate CN route actually uses an outer outbound and inner return lane, with a rear missile and forward stack. It is not a renamed constant-radius route. Numeric radii and lane angles were chosen as legal realizations and tested against the real pending puddles; they are not claimed to be official diagram coordinates.

Loop retains radius-3 towers, radius-15 Blaster, eight offset slots `(±3,±12)/(±12,±3)`, two of four slots in one offset family per wave, and observed identical consecutive pairs. Tower times are 13.4, 22.4, 31.4, 40.4. Initial Looper deadlines are 16/25/34/43 from begin, not the end of a numbered wave. A 2.7-second deadline beat reaches T43.1, followed by 8.4 seconds of status recovery through T51.5, so the final HP Penalty and Ruin also expire within this independent course. Missed towers cannot cause early Memory Loss. Deadline expiry records Memory Loss and death. Tethers activate at T5.3; sampled initial owners are never replaced with wanted owners. Number threes can preposition before activation, but bot goals do not chase a hidden line. Ownership still changes through actual contacts only.

Loop Ruin lasts 11 seconds; a second hit before expiry records Doom and death. P1 HP Penalty is queued at Blaster +0.65, caps maximum HP at 1% for nine seconds, and records gain/expiry. `loop_hp_penalty` stores the scheduled expiry; use `loop_hp_active()` for actual activity, including the delayed start. Restoring the cap is not an automatic heal. Job healing, invulnerability windows and combat HP are not modeled; Cannon judgments cover targeting, role and geometry. Omega HP Penalty remains three seconds.

## Evidence audited

The supplied four complete public captures were inspected read-only outside the repository:

| Report/fight | Panto puddles | Cones | Missile / shared-beam pairs | Observed cannon cleaves / proteans |
|---|---:|---:|---:|---:|
| LKMGRJTzgY9HFynk / 2 | 80 | 28 | 4 / 4 | 4 pairs / one three-player wave |
| 3GW2hjTNk91FZwcK / 9 | 80 | 28 | 4 / 4 | 5 pairs / two three-player waves |
| 1bX86aKrVRwLWfTC / 19 | 80 | 28 | 4 / 4 | 5 pairs / two three-player waves |
| Vyq4AcJKZjkFQBpG / 32 | 80 | 28 | 4 / 4 | 4 pairs / one three-player wave |

The shorter cannon sequences are kills before later scheduled attacks, not evidence for a four-pulse mechanic. Normalized Panto cone times are approximately 6.1..32.1; puddles 12.6/12.7..30.7; missiles/beams 12.1/18.1/24.1/30.1. First cone ID 31501, subsequent cone ID 32368; puddle 31500, missile 31502, shared beam 31503, tank cleave 31504, protean 31505. These IDs are included in runtime events.

Consecutive helper facings change approximately +0.52 radians in the NA/CN captures and -0.52 in EU/KR. Thus both rotation directions are observed, independently of the guide description. FFLogs facing is divided by 100 to obtain screen radians; adding 90 degrees converts to Rules' north/CW angle. Initial family exhaustiveness still comes from guide panels, not four samples. Helper sourceResources positions can be stale `(0,-10)` and were never used as bait coordinates. Anonymous status summaries in `top/data/fflogs_observations.json` corroborate Looper 16/25/34/43, P1 HP Penalty 9s versus Omega 3s, and P1 Ruin about 11s. No raw replay, player names, gear, or artwork was copied into the repository.

### Elemental

[Primary P1 guide](https://ffxiv.tuufless.com/elemental/top/01_omega/): read full prose including troubleshooting, the slow/yellow and immediate/green movement figures, and all six decoded frames of the embedded `pantokrator.gif`. HTDH priority, NW/SE reference sectors, CW adjustment when covered. HaruGlory missile-front/beam-back and the additional group bait are implemented. The immediate-exit historical variant is documented but is **not exposed as a validated route**; mixing it with the slower path is explicitly warned against by the guide. Guide text saying towers never repeat is contradicted by full-clear observations; repeats are retained.

### Aether

[Primary Toolbox 609080911754761](https://ff14.toolboxgaming.space/?id=609080911754761&preview=1): all 21 step notes and diagram role/zone records were read from the supplied public JSON capture, not application source. Step 10 explicitly selects G1 south / G2 north, or G1 west / G2 east when A/C are fully covered; partial coverage sidesteps within the sector. TMR flex moves the tank before melee before ranged; healers stay. The old PR350 NE/SW reference is not the default in this helper.

The notes for steps 12–13 contain inconsistent front/back wording, while role/zone movement shows the inner outbound and outer return sequence. This implementation uses that executable sequence and does not claim the prose is internally consistent. Step 16 describes static spread as an option; steps 17–20 describe marked players moving out and returning. Both static and dynamic Cannon options are implemented; dynamic marked players take W/S/E by conga order, with unmarked actors in a southern safe pocket. The saved entity positions remain static across those later steps, so the dynamic geometry follows their explicit text and is labeled a numerical realization.

### LPDU

[Eight-slide P1 raidplan](https://raidplan.io/plan/7gDX3dkkPX1kO9u2): all eight slides visually read in an owned task tab. Slides 1–6 show M1>M2>MT>ST>R1>R2>H1>H2, threes in front for collection, cardinal tether safe areas and idle players near towers. The first northern tower includes a slot slightly west of N; the helper's scan origin includes that slot. Slide 7 explicitly shows G1 north / G2 south, partial-coverage sidesteps and **G1 east / G2 west** on full coverage, not CN/KR's west/east. Tank flexes before melee before ranged, healers never flex. Missile-front clips are linked by the plan. Slide 8 shows the static H1/M1/R1/R2/M2/H2 southern spread and five tank cleaves.

Slide 8 also offers separated northern-intercardinal tanks with mitigation and a tighter dynamically adjusting party area. That alternative is selectable with `p1_tank_variant="split_mitigated"`: tanks take NW/NE, the six non-tanks use a tighter southern spread. All twenty marked subsets pass its 6/s geometry harness; this does not validate mitigation or HP survival. No universal NA/EU or post-7.0 PLD invulnerability policy is claimed.

### CN Moogle

[Original poster](https://www.bilibili.com/opus/800287973844189204), using the parent's complete [15-panel audit](CN_POSTER_AUDIT.md). Loop scans from A/north clockwise. HTDH high N/low S except fully covered A/C, then high W/low E. Both selectable Panto variants are executable: `outer_out_inner_return` = 分摊追火 / 外出内回; `inner_out_outer_return` = 火追分摊 / 内出外回. Default is the latter. Cannon static ordering is D3 W, H1 SW, D1 SSW, D2 SSE, H2 SE, D4 E, tanks north/furthest.

### KR 09STOP

[Original workbook P1 tab](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=2089732780). Read rows 98–211 through the normal public htmlview's actual iframe URL (`/spreadsheets/u/0/d/.../htmlview/sheet?headers=true&gid=2089732780`); the path without `/u/0/` returned an error. Visually read all six row-103 initial panels and the row-130/157 movement and row-186 Cannon figures. Row 100 explicitly allows CW and CCW 30-degree rotation. For initial flame axes 30,60,90,120,150,0 degrees, H1-group safe sector centers are respectively 300,330,0,30,60,270 degrees, H2 opposite. These are sector centers inferred from the figures, not official standing coordinates.

Priority H1 T1 T2 D1 D2 D3 D4 H2; inner outbound / outer return. Cannon figures place D3/D4 W/E, D1/D2 SW/SE, H1/H2 SSW/SSE, tanks north. Row 184 calls the tank cone 90 degrees, conflicting with the common 120-degree geometry used here. This is an evidence conflict, not a regional skill difference.

## Configuration and validation

Overrides on `ctx.profile`: `p1_orientation` (0..5), `p1_direction` (-1/+1), `p1_boss_facing` (north/CW degrees), `p1_panto_variant`, `p1_cannon_variant` (`static`/`dynamic`), `p1_cannon_marked` (three distinct actor IDs 2..7), and LPDU `p1_tank_variant="split_mitigated"` (default `north_together`). Only Aether has source-backed static and dynamic cannon choices. For another community an explicitly selected dynamic override is labeled custom training, not source-verified.

Run with Godot 4.4.1 console (use a writable explicit log file; default user-log creation crashes in this restricted environment):

```powershell
& 'D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe' --headless --log-file "$env:TEMP/p1-events.log" --path top --script tests/p1_fidelity.gd -- --events-only
& 'D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe' --headless --log-file "$env:TEMP/p1-loop.log" --path top --script tests/p1_fidelity.gd -- --loop-only
# No filter runs both matrices. Historical failures below were later repaired; see LOOP_NAVIGATION.md.
# Reproduce a failing course, including actual holder and position snapshots:
& 'D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe' --headless --log-file "$env:TEMP/p1-probe.log" --path top --script tests/p1_fidelity.gd -- --loop-probe elemental 8
```

Event suite: **1204 assertions, zero failures**, including 72 full Panto courses at 6/s, 140 full Cannon courses (including the optional LPDU split-tank layout), all twelve Loop pair topologies and repeats, 14 cone-pair timestamps/geometry, 80 actual puddles, beam target order, cross-beat JSON restore, wrong previous-bait return, movement allowance positive/negative, all four Looper deadlines, delayed HP cap, Ruin Doom, activation under both unverified line policies, and live farthest retargeting. Geometry and pending events are evaluated throughout the walking courses, not just at endpoints.

Existing suites: Rules 196/0, Interactions 18/0, Stateful 72/0, Calibration 16/0, P6 Fidelity 1334/0. The only existing test edits correct fixtures that set T16 before beginning Loop; they now begin at T0 and evaluate successful towers at T13.4 or genuine expiry at T16. No unrelated assertion was weakened. Godot emits a root certificate-store warning; Stateful also reports an unimported font in this fresh worktree, but its 72 assertions pass. Desktop/Web rendering QA remains the parent's task.

The 240-course Loop matrix uses seeds 1..48 for every profile, including 39/44, at 6/s with actual swept transfers. It remains red. For example, Elemental seed 8 misses round-three and round-four towers while carriers hold the correct requested actors; this is a navigation/path-timing failure, not permission to assign owners or shrink hazards. Final ordered-update run: **198/240 courses pass; 42 fail** (1040 assertions in the Loop-only run, including topology, deadline and final HP-recovery checks). Failing seeds: elemental = 8,15,16,23,29,35,40,42; aether = 8,15,16,23,29,35,39,40,42; lpdu = 8,15,16,18,23,29,35,40,42; cn_moogle = 3,8,14,23,29,35,40,42; kr_09stop = 3,8,14,23,29,35,40,42. Seed 44 passes all five profiles; seed 39 fails Aether and passes the other four. These results use Main-like ordered bot updates, actual 6/s travel, and T5.3 activation. The default harness must remain failing until these routes are corrected. Parent should review integration and navigation rather than treat this patch as a completed P1 milestone.

Final unfiltered run after all changes: **1684 assertions, 42 failures**, exit status 1. All failures are the Loop courses listed above. `git diff --check` passes; changed paths remain within the authorized allowlist.

Remaining fidelity limits: unresolved pickup radius/line identity and both ownership policies remain explicit; guides do not provide official numeric route coordinates; the Elemental historical immediate-exit variant is not validated; no job-combat HP/invulnerability/healing model; production Main/Encounters wiring and desktop/Web QA are outstanding by design.

## Historical parent integration checkpoint (before navigation repair)

- All five route menus are exposed for Panto/Cannons, plus CN two lane variants, Aether static/dynamic Cannon and LPDU optional mitigated split tanks. Labels follow the primary sources above.
- Panto was repacked from323 navigation checkpoints to4 UI stages; dynamic coaching retains the exact validated0.1-second goal cadence. The full1204-event assertion suite still passes.
- Main consumes remaining frame budget across stage boundaries and subdivides at50ms, so hundreds of one-frame pauses cannot drift event times.
- Loop tether destinations now use only empty CARDINALS as the guides specify; towers remain actual logged offset slots. Physical pickup/activation/damage rules have not been relaxed.
- Retiring carriers currently walk inward for short physical handoffs; collectors choose outgoing-direction-compatible rays and avoid the other ray. This fixes the previous Elemental8 case, but the full240-course matrix still finds other valid navigation failures. It is NOT completed or release-ready. Reproduce current failures with `--loop-probe elemental 3` and inspect `p1-loop-shorthandoff-full.log` in private task evidence.
- Shared rule196/contact18/calibration16 assertions pass after production wiring. Loop tower topology fixtures now explicitly ignore the two status-recovery beats; no required tower assertion was removed.
