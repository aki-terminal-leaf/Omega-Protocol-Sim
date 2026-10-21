# P3 transition fidelity handoff

Audit: 2026-10-21. Isolated base: `90be92efcc840f0d61761ba12742ac350d821977`.

## Scope and parent integration

Independent P3 intermission implementation for Elemental, Aether, LPDU, CN Moogle and KR09STOP. This does not claim completion of the other nineteen mechanics. The parent must replace legacy `Encounters.transition()` with `P3TransitionCourses.append_transition(self)`. No parent dispatcher, Main, Arena, Rules, Interactions, strategy JSON or global parameter file was edited. Merge only the three added begin/tick/sync lines from statuses.gd into the parent's newer file, preserving unrelated Delta/Omega/HW hooks.

- `append_course(ctx)` and `append_transition(ctx)`: complete concurrent course.
- `append_family(ctx, arm_first, sample_index=2, purple=[], white=[])`: finite forced families. arm_first0 = N/SE/SW first;1 = NE/S/NW first. Samples0..3 below. Empty partitions use ctx.order[0:4] and [4:6], preserving force-slot contexts.
- Profile overrides: p3_transition_arm_first, p3_transition_sample, p3_transition_purple, p3_transition_white. Invalid parameters assert instead of substituting a route.
- Runtime begin/tick/sync: parent advances sim_time before tick. Actual Interactions/Statuses pipeline tested.
- stage_entities uses id/form/pos/p3_transition_entity, plus cue/form_confidence for arms. Original registry forms final, arm_left, arm_right; no generic Final fallback for arms. Parent rendering/asset availability unverified.

Four coaching beats are movement checkpoints, not isolated mechanic phases. One persistent queue carries eight rings, six arm cues/casts/blows and sniper resolution. Runtime never reads guide goals or labels. Initial scenario spawn is a southern priority conga; all subsequent movement walks at6 units/s. No ownership reassignment, snapping, guide-derived status grants, immunity, failure suppression or11 units/s motion. Encounter marks come from the selected partition independently of the guide. Explicit per-frame parent motion_allowances are honored; the course grants no Sprint.

## Manifest-bound encounter evidence

All28 files in four COMPLETE manifests passed SHA-256 over **decompressed** bytes, as required by the manifest format. Independently counted175,853 replay events and4,875 enemy cast-list events. Exact hashes, retrieval timestamps and URLs retained in route JSON samples[*].hashes. No player names included.

| Index | Anonymous clear | First ring begin, report ms | Arms1 / arms2 seconds from begin | Sniper |
|---|---|---:|---|---:|
| 0 | [1bX86aKrVRwLWfTC/19](https://www.fflogs.com/reports/1bX86aKrVRwLWfTC?fight=19) | 14223681 | 16.974 /19.481 | 19.034 |
| 1 | [3GW2hjTNk91FZwcK/9](https://www.fflogs.com/reports/3GW2hjTNk91FZwcK?fight=9) | 5533809 | 16.978 /19.512 | 19.024 |
| 2 | [LKMGRJTzgY9HFynk/2](https://www.fflogs.com/reports/LKMGRJTzgY9HFynk?fight=2) | 440934 | 17.031 /19.529 | 19.039 |
| 3 | [Vyq4AcJKZjkFQBpG/32](https://www.fflogs.com/reports/Vyq4AcJKZjkFQBpG?fight=32) | 26150628 | 17.029 /19.529 | 19.039 |

Runtime T0 is debuff application,0.088/0.089 seconds before first cast start; all deadlines shift consistently. Sample2 ring hits from cast start:4.992,7.086,9.138,11.191,13.152,15.250,17.298,19.350. Other samples retain measured timestamps. IDs31567..31570 occur twice; later P4 reuse excluded by transition window. Bands: circle6; donuts6..12,12..18,18..24. Actual arm begincast timestamps stored separately.

**Cast-list correction:** enemy-casts lists only three arms. Replay supplies the other three with null source IDs and valid live cast positions: (0,+/-14), (+/-12.12,+/-7), two alternating triangles, not radius20 spawns. Named sources are Right Arm Units; anonymous complementary sources use explicitly **inferred** left handedness. Stale sniper helper coordinates are ignored: circles center on current marked players. Sample2 calculateddamage shows exactly one hit per actor, two targets per white. Magic Vulnerability Up1002941 duration1.960s is logged.

Read-only crosschecks: cached TOPEnums.cs, TOPStates.cs, P3Intermission.cs for radius6 snipers/void, radius11 arms, ring bands, timeline1E43/1E44 +13.5s. Original GDScript implementation; no reference implementation copied.

## Five separate route audits

All access dates2026-10-21. North up/east right. Rank each debuff class independently; unmarked rank1 joins white rank1, likewise rank2. M1/M2=D1/D2, R1/R2=D3/D4, T2/OT=ST.

| Route | Evidence inspected | Priority | Purple | White |
|---|---|---|---|---|
| Elemental | [P3 steps1–10](https://ffxiv.tuufless.com/elemental/top/03_omega_reconfigured/), live text; cached primary macro audit | H1 MT ST D1 D2 D3 D4 H2 | W SW SE E | NW NE |
| Aether | [PF source](https://www.thepfstrat.com/u/top), cached primary audit; [Toolbox243183080764761](https://ff14.toolboxgaming.space/?id=243183080764761&preview=1), full cached semantic raw steps0–9 independently read | H1 R1 M1 MT ST M2 R2 H2 | W NW NE E | SW SE |
| LPDU | [Primary markdown](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md), live; linked [Intermission](https://raidplan.io/plan/46r495ZATq3kCqz1), live visual steps1,3 | R1 M1 MT H1 H2 ST M2 R2 | W SW SE E | NW NE |
| CN Moogle | [QQ source](https://docs.qq.com/doc/DSlBpR0JqSElVelhH), cached macro audit; [original poster](https://www.bilibili.com/opus/800287973844189204), cached CN_POSTER_AUDIT.md panels00,04 | H1 MT ST D1 D2 D3 D4 H2 | W SW SE E | NW NE |
| KR09STOP | [Phase.3 gid1826471436](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1826471436), live htmlview rows9–114 and first three transition images | H1 T1 T2 D1 D2 D3 D4 H2 | W SW SE E | NW NE |

KR title/content confirmed Phase3, not assumed from gid. First diagram shows priority; following diagrams show per-class allocation. Rows63,87,110 describe both triangle orders and inward/outward movement. LPDU step3 independently confirms sectors, not inherited from Elemental. Aether semantic notes explicitly put purples north/whites south. CN assignment markers never override debuffs. Supplied CN video leads [av740517066](https://www.bilibili.com/video/av740517066) and [BV1vz4y1B7xP](https://www.bilibili.com/video/BV1vz4y1B7xP) were not independently frame-measured here: timing comes from encounter evidence, not claimed video measurement.

Live access used normal public owned task tabs through local CDP9222; tabs closed afterward. Cached sources first. No authentication, cookies, secrets or bypass.

## Numerical movement and matrices

**Legal numerical realizations, not official guide coordinates.** Southern conga x=-7,-5,...,+7,y=7. Actor-independent initial travel upper bound28.899 units/4.817s, before first center hit>=5.059. Geometry is actor-symmetric; current marks determine guide slots.

| Leg | Construction | Start | Distance / walking time |
|---|---|---|---|
| Conga outward | radius19, first-arm axis+/-46 degrees | T0 | <=28.899 /4.817s |
| First inward | radius19 to16.5, same angle | ring3+0.040s | 2.5 /0.417s |
| Return outward | radius16.5 to19 | ring4+0.040s | 2.5 /0.417s |
| Second inward/arm dodge | radius19 axis+/-46 to radius16.5 axis+/-16 | ring7+0.040s, after arms1 | 9.50011 /1.58335s |
| Resolve/wait | radius16.5 | sniper, ring8, arms2 | 0 |

Adjacent solo centers in one first-arm pocket are9.096 apart, beyond radius6. Minimum second-arm clearance approximately0.658 beyond radius11. Last walking leg arrives before sniper by0.12365,0.11065,0.11765,0.11865s across samples. Tight construction margins are not network-latency guarantees. Continuous void collision clips each segment to its active time; discrete rings/arms interpolate actual positions at snapshot time.

Full matrix:420 partitions = C(8,4)*C(4,2), x5 routes x2 arm orders =4200 physical simulations at sample2. Separately5 x2 x4 timing/source samples=40. Three baseline/JSON-restore/Interactions integration runs: total4243. Actor symmetry factors timing from the exhaustive partition axis; this does **not** claim16800 physical cross-product runs. Both arm orders observed; no invented continuous rotations or ring permutations. Quick:10 standard family runs plus three restore/integration, all420 priority partitions, all64 actor/forced-slot contexts. Full partition step0.1s; timing/quick step0.05s. All movement uses move_toward at6.

Pending events, locked origins and history are JSON-native. Every-frame restore retains discrete order/targets/failures and numeric values within1e-5. Negative/boundary checks: invalid partitions; ring edges/just outside; arm radius11; interpolated ring hit; swept void crossing; void activation/expiry; wall20; unauthorized7.5 versus explicit allowance; white solo/double-white; purple overlap; prior deadly vulnerability; missing marks; dead owner/partner; locked origins through restore; six original arm forms; idempotent sync preserving unrelated entities. Corpses cannot share. Simultaneous sniper geometry uses alive actors at snapshot start, avoiding artificial sequential changes after a failing packet.

## Final verification

Godot4.4.1 stable headless. Composite SHA-256:

`d34a9d9821dc308198a3f7564225f5fd77bc820ae86ba115a98bbc1e1167b0df`

Concatenates exact bytes in order: courses, patterns, runtime, route JSON, statuses, test. Test prints its own hash. Documentation excluded to avoid self-reference.

| Gate | Assertions | Physical runs | Failures | Test time | Exit |
|---|---:|---:|---:|---:|---:|
| --quick | 2268 | 13 | 0 | 834ms | 0 |
| Separate full run | 23418 | 4243 | 0 | 20374ms | 0 |

Commands (supply a writable log path):
```powershell
& <Godot-console.exe> --headless --disable-crash-handler --log-file <writable-log> --path top --script tests/p3_transition_fidelity.gd -- --quick
& <Godot-console.exe> --headless --disable-crash-handler --log-file <writable-log> --path top --script tests/p3_transition_fidelity.gd
```

Default user-log creation initially crashed this sandbox's engine before testing. Redirecting logs to the allowed documentation path enabled runs; this document replaces the temporary log. Successful runs still report the host certificate-store warning; tests use local data/no network. No script parse errors remain. Original D:/Dev/Omega-Protocol-Sim checked read-only with command-local safe.directory override: clean. Never edited. No commit/push/merge/deploy.

## Remaining gaps and confidence limits

1. **Void exact lifetime unmeasured.** Radius6 crosschecked. Approximate window cast-start+6.1 through+21.4: reference appearance~1s after ring1, disappearance~1.6s before targetability near23s. Clean FFLogs lack environmental packets proving exact thresholds.
2. **Arm cue timing/anonymous handedness inferred.** Cast/hit times and origins measured; cues hit-13.5s. Timeline1E43 vs1E44 not distinguished. Arms lock to source positions; evidence does not establish player-targeted arm bait selection, so no selector is invented.
3. **HP/shields/healing unmodeled.** One magic packet per actor certifies geometry only. Primary guides require shields. No free mitigation/immunity granted.
4. **Early marked death random retarget unresolved.** Attempt fails explicitly; no fabricated recovery. Corpses cannot soak.
5. **Parent wiring/rendering outstanding.** Replace legacy transition call and render original-form metadata. Assets/animations not visually validated by headless gate. Ring/sniper overlays are labeled instructional previews, not original game VFX.
6. **CN video timing and source-published numeric paths not fully audited.** Five assignments have separate provenance and tested movement; schematic sources cannot justify100% authentic numeric waypoints or all20 mechanics complete.

## Parent integration — 2026-10-21

The handoff above records the isolated worker state. Parent integration is now
complete: production `Encounters.transition()` calls the new course; the five
audited families are selectable; all three hooks were manually merged into the
newer shared Statuses without removing other runtimes. Production bots walk at
6/s. Stage entities use the existing original-form renderer and hide the duplicate
background boss. No extracted assets or raw player logs are included in this commit.

Exact integrated code fingerprint (same six-file order as above):
`1e1db5d0a1d1b7b8404be220defe51125f6c99b7ea5e766ff6a6dee3649f4fb7`.
Parent Godot 4.4.1 gates: quick 2268/0; full 23418/0 across 4243 physical
simulations; actual Main mechanism→strategy→run 15 courses/0 failures
(5 families × 3 seeds), with no automatic mechanism advance; shared review211/0.
These are headless parent integration checks, not new exported Windows/Web or
visual QA. The six remaining source/combat limits above remain active.
