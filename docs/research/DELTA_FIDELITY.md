# Delta live mechanics and regional routes

This branch is an opt-in Delta implementation, not an Encounters/Main integration. It never calls the legacy `ctx.delta()`. Original GDScript implements the mechanic; the public C# files were read as behavioral references, not translated/copied. No raw logs, names, gear, guide artwork, or game assets are included.

## Integration contract

- `p5_delta_courses.gd`: `static append_delta(ctx)` appends the complete 53.976-second course using the existing Encounters context. `append_family(ctx, config)` exposes deterministic patterns for tests/replays. `goals`, `guide`, `world_goals`, `arm_map`, and `sprint_authorized` describe suggested movement only.
- `p5_delta_patterns.gd`: `assignment`, `valid_assignment`, `config`, `events`, `fist_families`, `parameters`, and `route` build JSON-compatible configuration. Both World holders must occupy different remote pairs. Near/Far can occupy either initial blue pair and either member; the supplied actual holders are preserved. Aether puts the actual Near pair inside by swapping guide lanes and their actor-associated fist colours, without changing actual statuses or tether partners.
- `p5_delta_runtime.gd`: `begin`, `tick`, and `sync` are the only three new calls in `statuses.gd`. Delta state lives under `state.delta`. It is independent of P3's generic `paired_tethers`, avoiding their different IDs/timers. Runtime never reads beat guide positions or prescribed owners.
- Parent movement must call the existing production `Interactions.tick` with previous/current actor states. Walk is 6/s. `beat.delta_motion` declares the LPDU blue arm baiter/monitor Sprint window at 7.5/s. Parent must authorize/apply the actual budget via `state.motion_allowances` for Sprint/dash; this module does not teleport actors or increase ordinary walking speed.
- World events call the existing `Rules.resolve_world_pulse`, using actual nearest/farthest selection, radius 8 then 4, three pulses, five-second vulnerability, and actual capped Dynamis gains. Parent should not add a second World handler for the same events.
- Durable pending events, histories, entities, tethers, and configuration use scalar/array/dictionary values. Ephemeral `beat.stage_entities` and shape positions are converted to Vector2 for the current renderer. Actual spawns persist across beats; beat-relative `spawn_delay` becomes zero for already spawned entities. No Arena changes are required to consume this metadata; optional forms need the parent's model registry.
- Same-ID `begin` is idempotent. Retry must restore the whole state including `sim_time`, `delta`, statuses, World chains, and actor positions/facing. A discontinuous clock is rejected. A new appended course gets a different ID.

The parent still needs to replace its old Delta dispatch with `append_delta(ctx)` and wire actual movement/Sprint. Existing Encounters and Main were deliberately not edited.

## Evidence and timing

Four complete public captures were read from the existing evidence directory: [NA 2](https://www.fflogs.com/reports/LKMGRJTzgY9HFynk?fight=2), [9](https://www.fflogs.com/reports/3GW2hjTNk91FZwcK?fight=9), [19](https://www.fflogs.com/reports/1bX86aKrVRwLWfTC?fight=19), and [32](https://www.fflogs.com/reports/Vyq4AcJKZjkFQBpG?fight=32). `p5_delta_routes.json` records aggregate intervals and the existing manifest SHA256 values for every continuous replay segment used. T0 is the first Delta status 3442 application, not a visual cast or an arbitrary practice beat.

| Event | Range across captures, seconds from T0 | Runtime representative |
|---|---:|---:|
| Local/Remote activation | 17.958–17.994 | 17.976 |
| Fist Explosion cast begin | 20.101–20.174 | 20.120 |
| Fist Explosion resolution | 23.097–23.151 | 23.114 |
| Arm cast-start bait lock | 25.507–25.553 | 25.527 |
| Beyond Defense actual hit | 25.617–25.685 | 25.617 |
| First Hyper Pulse | 27.988–28.039 | 27.988 |
| Last Hyper Pulse | 30.922–30.967 | 30.935 |
| Monitor actual hit 31597 | 30.445–30.480 | 30.445 |
| Pile Pitch | 30.834–30.980 | 30.980 |
| Swivel cast begin | 33.369–33.410 | 33.395 |
| Swivel resolution | 43.335–43.395 | 43.366 |
| Initial Worlds | 44.050–44.080 | 44.080 |
| First jump | 45.075–45.107 | 45.107 |
| Second jump | 46.055–46.101 | 46.092 |

The raw replay's `source` object identifies some NPC casts which the quick enemy-cast listing omitted. In particular, all eight 31482 begins and resolutions are present in each replay; their observed cast interval is 2.977–2.996s, nominal three seconds. No 31483 wipe occurs in these four clears. The six Hyper Pulses use observed NA times (27.988, 28.613, 29.196, 29.775, 30.355, 30.935), approximately 0.6s apart. Their angles lock before Defense, not at first damage.

All four captures put the World holders on different preparation-remote (201) tether pairs. Live local status is **1672 / 36s**, remote **1673 / 12s**, after the approximately 18s Code Smell. These are not P3 regression status IDs 3529/3530. Initial Worlds last 44s. Four pair breaks are determined by actual movement; observed clear break times are evidence, never scheduled automatic breaks.

Status durations are intentionally distinct:

- Patch: Thrice-come Ruin 2530 and Magic Vulnerability 3516, each observed 0.96s.
- Defense, monitor, and Pile Pitch: Twice-come Ruin 2534, observed 6.95–6.96s. A second such hit during that status fails.
- Monitor: Magic Vulnerability 2941, observed 4.95–4.96s. Patch during that vulnerability fails.
- World: the parent API's five-second World vulnerability. Patch during it fails; World also checks an existing Magic Vulnerability. Actual clips and holder bounce-back remain failures.

## Geometry and actor selection

Eight independently coloured fist entities spawn and chase their initial player bait. NPC chase position and cast destination are different fields: at cast begin, each actual player bait position is captured once. Opposite-colour paired destinations must overlap, and the subsequent radius-3 puddles remain at those locations even when actors/guide goals move. Incorrect pairing produces range-100 31483. NPC chase speed and overlap tolerance remain explicitly provisional below.

Six arms are radius 20, 60 degrees apart, indexed counterclockwise from the eye (matching the reference ArmOffset orientation after converting its coordinate convention). Each selects the actual closest living actor at cast start. All six repeated width-8, length-100 beams retain that angle and turn independently by +/-20 degrees. An inward dodge precedes movement into the monitor formation; directly walking from a bait into its eventual guide endpoint can cross the first beam.

Beyond Defense selects one of the actual two closest living players to the central helper, using the configured random branch. Its radius is 5. Pile Pitch chooses the actual closest at resolution, radius 6, minimum three, and excludes the actual previous victim. No fixed actor or guide-member list decides either hit.

Final's monitor and the player monitor each select two actual living targets from the current half, using production `Rules.monitor_targets`, including its fallback/random behavior. The player's current facing matters. Each target splashes radius 7; actual duplicate hits, splash, Magic Vulnerability, and Twice-come Ruin are checked. The judge does not require all eight players to be hit or a named four-green list.

Swivel is a radius-60 **210-degree cone from the beetle at the arena edge**, before initial World damage. Source resource positions corroborate radius 20 but proxy facing is demonstrably stale across different variants. Orientation is therefore derived from the primary diagram's approximately 15-degree sloped safe boundary, rather than claiming the stale proxy facing as a measurement. The canonical beetle W / eye N form points the cone N for south-safe, or S for north-safe; rotate all geometry with the eye. Tests reject a point which the old center-origin half-plane would incorrectly allow.

## Five distinct source families

| Family | Fist adjustment | Defense / arm responsibility | Final World topology |
|---|---|---|---|
| Elemental Kinda Awk | inner | short blue Defense; outer blue beetle arms | Near middle, Far cardinal wall; inner greens Near receivers, outer greens Far receivers |
| Aether Saus | inner | actual Near pair inside/Defense; Far pair outside/beetle arms | cardinal World layout; idle blues opposite-beetle intercardinal |
| LPDU linked P5 | inner | first-break blue Defense; other blue beetle arms | cardinal World layout; explicitly conditional Sprint for monitor arm baiter |
| CN Moogle + user correction | outer | inner blues Defense; outer blues Final NE/SE arms, inner greens N/S, outer greens Beetle NW/SW arms | cardinal holders, but broken-green safe partner stays near while danger partner crosses to edge; unbroken green danger goes beetle |
| KR 09STOP | outer | first-break outer blue Defense; other blue beetle arms | **Far center, Near beetle intercardinal; other blues receive Near; outer greens idle; inner greens receive Far** |

Sources read: [Elemental Delta](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_delta/), [Aether page](https://www.thepfstrat.com/u/top), downloaded raw [Saus Delta 28 steps](https://ff14.toolboxgaming.space/?id=732288275415761&preview=1), [LPDU-linked full P5 65 steps](https://ff14.toolboxgaming.space/?id=955389449416761&preview=1), [CN original poster](https://www.bilibili.com/opus/800287973844189204), and [KR Delta workbook](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=895996912). KR row338's three figures and row359's text were directly read in a task-created tab through normal CDP9222 public GETs. The CN original was inspected locally at its first-trio/final-World panels, in addition to the parent audit.

Toolbox role keys are not simulator DPS slots. In Saus, `dps1` is DNC, `dps2` DRG, `dps3` SAM (Near example), and `tank2` DRK (Far example). LPDU's Near example is GNB and Far is SMN. The implementation maps tether/World/colour responsibilities to actual actors, not source key names. For the 15x15 canvas, player centers are position + half icon size, arena center is (7.5,7.5), and a schematic diameter-40 calibration is 40/15. This gives Saus's Far example about radius18.13 and Near about5.87, corroborating topology. These are not official server coordinates; exact numerical waypoints are original legal realizations.

The 2026-10-23 user correction supersedes the old CN green-Defense interpretation above: blue-inner now physically baits Defense and the old green-victim monitor substitution is removed. Outer green breaks first during arm movement; inner green receives the long separated World positions and only converges late. CN Defense victims retire toward Final so unchanged radius-seven monitor splashes cannot hit them again. Exact outer numeric-marker return, H1/H2 inner priority and fist CHASE-versus-stationary semantics remain unresolved. The LPDU source also has inconsistent inner/outer wording across steps5/7/9; the explicit first-break-to-Defense rule governs, and the ambiguity is retained in metadata. Elemental's initial blue pair tie-break and CN's initial blue selection remain unspecified.

## Provisional facts and limits

1. Both distance thresholds default to 10y **provisionally**. Interpolated local break samples ranged 3.90–10.82y; second-remote-break samples 8.07–10.05y. First remote pairs were already stretched (13.89–19.59y). Resource interpolation spans range from fractions of a second to several seconds, with an 11.66s extreme; these are not tight server-threshold bounds. They contradict treating 3y/22y as measured values but do not prove an exact 10y threshold. `parameters()` carries the provenance and can be overridden per config.
2. NPC chase speed defaults to 6y/s and is unmeasured. This does not change player speed. Fist pairing center-distance tolerance defaults to 3y as a provisional opposite-radius criterion; the AoE radius itself is sourced 3y. No guide endpoint is used as an NPC collision test.
3. The source does not establish the frequency of every balanced fist distribution or every combination of arm directions. Tests deliberately cover the balanced 36 and independent 64 supersets; generation is a training pattern distribution, not a claim about server RNG weights.
4. Source-ambiguous role ties and the CN conditional prevent claiming five fully authenticated exhaustive guides. `complete_route_verified` and `delta_route_complete` remain false. Passing a simulation is not source authentication.
5. P1 readiness is not inferred from this isolated base. Only three Statuses calls were added; the parent owns integration after P1. Optional model forms and live renderer performance remain parent integration work. No official visual asset is fabricated or distributed. Deterministic actor-index distance ties and configured Defense choice are training conventions; their server RNG weights are not established.

## Validation

The new standalone script uses **production Interactions and Statuses hooks** on every tick. Actors move at 6/s, with only the declared LPDU monitor-arm Sprint using 7.5/s. It does not validate just the endpoints. State checkpoints pass through JSON between beats while pending events, locks, real victims, timers, and World chains continue. The final base suite additionally restores actor positions and facing through explicit numeric-array serialization, not Godot Vector2 stringification.

Commands (Godot4.4.1 console, `--headless --disable-crash-handler --path top`, plus a temporary task-local `--log-file`):

```
--script res://tests/p5_delta_fidelity.gd
--script res://tests/p5_delta_fidelity.gd -- --matrix
--script res://tests/p5_delta_fidelity.gd -- --assignments
```

Completed gates at this document's last update:

- Base/negative/state suite: 71 assertions, zero failures. Includes all five full courses; actual timers; no auto breaks; early multi-Patch deaths; old locked puddles across JSON/beat boundaries; same-colour 31483; actual chase/bait separation; actual nearest arm selection and immutable aim; 210-degree Swivel boundary in eight orientations; movement teleport rejection and explicit Sprint budget; actual original-holder World bounce; actual Dynamis; late green cut during vulnerability; actual three-player Pile Pitch and four single monitor hits; wrong radius-seven monitor splash and Defense-victim stack negatives; initial World radius-eight clip; KR-specific actual recipients.
- Finite branch sweep: **1,780 full moving runs, zero failures**: each profile has 256 NPC-monitor-side/player-monitor-hand/Defense/eye/safe combinations, 36 balanced fist patterns, and 64 independent six-arm rotation patterns. This is a factored exhaustive family sweep, not the entire Cartesian product of all dimensions.
- Forced assignment sweep: **320 full moving runs, zero failures** (64 per profile), covering all eight actors in all eight forced slots with mixed colour/arm/orientation patterns and all eight valid World-holder pair/side arrangements. Aether lane reassignment preserves the supplied status holders. This sweep also passed after the initial blue-pair choice was made independent of Near/Far.
- Existing `rules.gd`: 196 assertions, zero failures; `interactions.gd`: 18, zero; `stateful.gd`: 72, zero; `p6_fidelity.gd`: 1,334, zero.

Godot reports a host root-certificate-store warning, and the scene-loading stateful test reports an unimported font resource in this isolated checkout. Their assertion suites still exit0. No asset import/editor run was performed because it would generate files outside the permitted edit list. `--log-file NUL` caused an engine crash; subsequent runs used temporary task-local logs, removed at handoff. No commits, pushes, merges, deployments, original-checkout edits, or global JSON changes were made.

## Parent integration audit

Reviewed all seven files and independent71/zero gate; integrated production dispatch and persistent hooks alongside P1/Sigma/Omega/P6. Parent71/zero gate passes. `Movement` consumes the declared LPDU Sprint as a genuine10-second ability with60-second cooldown; no11/s Delta bots.

Four complete-clear actual OpticalLaser31521 source positions consistently have radius45, not20. Parent corrected the source entity/line to45; its inward attack geometry inside the20-radius arena is unchanged. Actual first-arm31600 packets identify threeLeftArmUnit15718 and threeRightArmUnit15719, but their relative positions differ across all four captures, independently of rotation icons. Generation therefore samples a balanced3/3 original-body assignment as a visual training family, not a claimed server RNG law. Runtime uses the locally extracted actual left/right GLBs and original b5/b6 fist bodies. Missing auxiliary forms now stay explicitly missing instead of falling through to an unrelated Final Omega procedural body. Original Optical Unit is an invisible ModelChara480 proxy whose visible appearance requires its original VFX; no official mesh is fabricated.


### 2026-10-23 current CN correction gates (distinct from historical sweeps above)

Current Godot4.7.2 gates:293 focused geometry/splash assertions;71 base assertions across five profiles; CN32monitor +36fist +64arm +64mixed-assignment moving courses. The32monitor family fixes eye0/safe+1 while testing both monitor sides/hands/Defense choices and all four monitor slots; mixed assignments add rotations and safety variants. This is not the historical256-branch monitor sweep or wholeCartesian equality. Actual MainDelta seed43 splash failure was retained and the affected three Main seeds passed after CN-only retirement-side repair; the57 unaffected prior Main passes were not rerun. One oversized private420-course attempt timed out and is not accepted evidence.
