# P6 LB and route fidelity — 2026-10-21

This is an implemented, tested LB lifecycle and a further primary-source route audit, **not a claim that all five regional routes or encounter HP verification are complete**. Production replacement, controls and final Windows/Web input QA remain with the parent. The worker made no commits or original-checkout changes. The parent reviewed and committed these building blocks separately; production replacement and final release are still pending.

## Delivered behavior

- `append_memory(ctx)`, `append_meteors(ctx)`, `append_magic(ctx)` are available in `p6_courses.gd`. Magic includes both iterations, not just one exposed exercise.
- `p6_lb.gd` owns actual job/action eligibility, shared gauge reservation, begin/finish/interruption, delayed damage, Brilliant consumption/refund, optional calibrated post-animation locks and unlock events. Legacy `state.lb`/`lb_actor` flags satisfy none of these checks.
- DPS casts are nominal **4.5 seconds**, healers **2 seconds**, tanks **zero cast-bar seconds**. Applying 4.5 seconds universally would contradict both Action.csv and replay.
- Six separately selectable NPC 15727 comets have 228360 HP each. Two separately selectable NPC 15726 meteors have 482324 HP each, at N/S radius 10. Comets occupy the six observed radius-13 locations. Caster damage hits the actual radius-15 circle and also damages the two large meteors; a correctly aimed ranged corridor then finishes both. There is no forced kill flag.
- Caster damage is conservatively 273000 and ranged damage 246000, below the inspected successful LB damage samples. These are encounter training damage values, not an eight-job combat simulator or level/gear damage formula.
- Comets must be dead at T20.5. Large meteors must be dead at T30.5, **an explicit practice checkpoint because their original enrage was not observed**. A missing NPC set cannot vacuously pass.
- Meteor initial puddles lock T5/explode T9, radius 10. Spreads are two independently shuffled four-plus-four sets at T10.2/11.2 and T16.2/17.2, radius 5. Three markers arrive T20.2; flares and the five-person radius-6 stack resolve T28.3.
- Bot decisions at T9/T19 call the same `request_lb` API as humans. These are training decision times, not automatic lock/kill events. Wrong job, insufficient gauge, insufficient Dynamis, spent Brilliant, dead/invalid/out-of-range targets, interrupted casts and missed geometry cannot fake a finish. The designated human is excluded from bot requests.
- A Magic Number tank LB must have applied before the raidwide snapshot; Doom is applied about two seconds after that cast snapshot and expires six seconds later. Healer cast completion clears it. Requesting at Doom 5.9 seconds fails, including a single long tick that crosses both expiry and cast completion.
- All durable new state is JSON-native. Re-entering `LB.begin` preserves pending casts/effects. Runtime events and LB progress share time across course beats. Existing 6/s movement checks and parent `motion_allowances` remain authoritative; no teleports or new Sprint entitlement were introduced.

## Parent integration contract

The existing Status begin/tick/sync already calls P6 runtime. No `statuses.gd` changes were needed. **Do not also tick LB separately when P6 runtime is ticking it.**

Before the first relevant beat, initialize explicitly:

```gdscript
const LB = preload("res://scripts/p6_lb.gd")
LB.begin(state, actors, {
    "jobs": actual_eight_job_codes,
    "gauge": actual_gauge_0_to_30000,
    "brilliant": actual_brilliant_actor_indices,
    "animation_seconds": measured_job_animation_durations,
    "targets": optional_existing_boss_targets
})
```

Use actual job codes (`PLD/WAR/DRK/GNB`, `WHM/SCH/AST/SGE`, all current melee/ranged/caster jobs in `ACTIONS`), not role-slot flags. `state.dynamis` must contain eight actual stack counts; `entry_ready` requires three each. `state.spent` is shared with the parent. Standalone exercises must declare their entry gauge/buffs; production cannot infer them from course progress.

For Memory only, set `state.p6_lb.memory_entry = true` to permit the **tank** LB before Brilliant exists. Successful Memory converts valid entry stacks to Brilliant; it does not refill the tank LB gauge. Gauge generation between Memory and the late melee sequence still requires the parent's real gauge model or explicit sourced gauge observations. This change does not pretend that continuous combat resource generation has been implemented.

Before human input, call `LB.sync(actors, state)` so targeting uses current positions, then:

```gdscript
var result = LB.request_lb(state, actor_index, "caster", Vector2.ZERO)
# Also accepts [x,y] or a live NPC string ID for caster.
var ranged_result = LB.request_lb(state, actor_index, "ranged", "meteor_1")
```

`p6_runtime.request_lb` is an equivalent wrapper. Ranged/melee target strings must identify a live target; caster ground positions are serialized to arrays. The aimed line is derived from caster origin and selected target (normal targeted auto-facing), not a free role-wide hit. The target is revalidated at completion. Parent movement should respect `p6_runtime.is_locked` / `LB.is_locked`; moving during the cast interrupts it without consuming gauge or Brilliant. Explicit supplied animation durations are enforced and survive JSON restore. **No default job post-animation duration is claimed.**

Set `state.p6_auto_lb=true` for bot decisions and `state.human_actor` to the player index (`-1` for all-bot rehearsal). `p6_runtime.sync` exposes `beat.p6_lb_targets` with stable target IDs, positions, HP and NPC IDs, plus selectable decorative shapes. Parent implements Tab/F and presentation. All outcomes are in `state.p6_lb.history` and the common timeline. Do not use the old 45%-of-beat role flag automation for these courses.

For final DPS practice, explicitly enable `state.p6_lb.final_melee` and provide a live boss target with `id`, `npc_id`, `pos`, `hp`, `max_hp`, `targetable`. A previously spent melee can use the genuinely remaining final gauge but receives **no second Brilliant refund**. No free gauge is created by enabling this option. Boss damage is a training amount; boss rotation/DPS enrage is outside this patch.

`p6_damage.apply_packet` optionally consumes explicit `state.p6_hp[actor] = {hp, shield}` and per-packet mitigation/invulnerability. It neither heals at waypoints nor changes HP to make a route pass. Full raidwide/spread/flare HP damage is not wired to an invented universal HP pool.

## Replay audit and calibration

All 20 cached replay JSON.gz chunks across the four supplied captures were parsed in timestamp order: **175853 events**, including calculateddamage/damage, calculatedheal/heal, buffs, headmarkers, gauge/limitbreakupdate and both source/target player resources. The four enemy-cast files contain **4875 events** (1215/1216/1221/1223). `top/data/p6_lb_routes.json` records event-type inventories and anonymous derived flare observations; no player names or gear were copied.

Captures: `LKMGRJTzgY9HFynk/2`, `3GW2hjTNk91FZwcK/9`, `1bX86aKrVRwLWfTC/19`, `Vyq4AcJKZjkFQBpG/32`.

- PCT 34867 and SMN 4246 are observed caster LB identities; BRD 4244, MCH 4245 and DNC 17106 are observed ranged identities. New-job identities were read from actual events and the public Action sheet, not guessed from job release order.
- Nominal DPS 4500 ms corresponds to approximately 3957–3999 ms begin/cast packet deltas across inspected DPS jobs. Healer nominal 2000 ms corresponds to approximately 1467–1478 ms. Runtime deliberately uses nominal casts; it does not shorten the input lock by the packet discrepancy.
- Calculated LB damage snapshots occur on the cast packet. Actual caster add HP packets arrive about 4.6–5.6 seconds later, staggered per NPC. Ranged HP packets arrive about 3.1–3.5 seconds later. Runtime snapshots actual target geometry at finish and applies the conservative last-packet envelope (5.6/3.5 seconds). It does not claim exact per-NPC packet ordering.
- PLD status 196, WAR 863 and DRK 864 last 8000 ms, with recipient application packets about 1.33–2.28 seconds after the instant action. Runtime uses a conservative all-party application at 2.3 seconds. This is an envelope, not exact per-recipient ordering or measured GNB application timing.
- Brilliant 3446 removal / Spark 3448 application and the 30000 gauge update coincide. Observed delays from cast completion are roughly 5.04 seconds for DPS, 3.8 seconds for tanks and 6.04 seconds for healers. Runtime uses 5.05/3.85/6.05. Consumption is recorded at successful finish, conversion/refund at its delayed event. Death removes eligibility and cancels a pending refill.
- The primary Elemental guide describes refill as a consequence of using LB with Brilliant. It is **not modeled as a fabricated nearby-comet-kill trigger**. The caster's first comet death happens near the conversion packet, but temporal proximity is not evidence of kill causation.
- Magic Number 31670 calculateddamage occurs on the boss cast record; damage and status 3532 application follow roughly 1.96–2.28 seconds later. Status duration is 6000 ms. Healer removedebuff records occur on healer cast completion, before later heal packets. The model uses a common +2.0 second Doom application; per-recipient stagger remains approximated.

Action source, accessed via a new owned CDP 9222 tab through normal public navigation:
[public Action.csv](https://raw.githubusercontent.com/xivapi/ffxiv-datamining/master/csv/en/Action.csv).
Caster `EffectRange=15`, `Range=25`; ranged `EffectRange=30`, `Range=30`, `XAxisModifier=8`; melee `Range=8`. The requested possible 50-unit ranged line is contradicted by this sheet. The runtime interprets XAxisModifier as half-width 8 (total 16), but the field-to-edge interpretation is **not independently verified by the successful central-corridor captures**. Exact hitbox-edge behavior also remains unmeasured.

## Flare analysis: what is and is not identified

Each clear has three 31668 calculateddamage packets with eight recipients: **96 packet/victim observations**, not three undifferentiated distance explosions. Headmarker 346 identifies the three players; the first target in each corresponding packet identifies that flare's marked origin. Player positions are bracket-interpolated from source/target resources at the calculateddamage timestamp. Helper NPC sourceResources are excluded because their default/stale coordinates do not locate a flare.

Matching damage packets, `unmitigatedAmount`, absorbed amounts, multipliers, aura multipliers and mitigation-entry counts are retained separately. Calculateddamage unmitigated values can exclude shields that are reflected in later damage records, so fitting raw calculated amounts directly gives a false curve. Fully shielded/missing damage packets and tank intrinsic defenses remain confounders; a zero reconstructed sample is not damage immunity.

The inspected non-tank own-flare observations range 52488–84539. Other recipients are about **19.292–37.088 units** away. There are no interior-distance samples sufficient to identify the distance law, cap distance or a universal lethal radius. A fitted exponential/linear curve would be arbitrary. `flare_bounds` therefore exposes observed envelopes and an unknown upper bound in the unsampled interior, never a radius-12 safe circle. It retains all 24 source/victim distances per simulated resolution.

Close non-owner separations inside that unsampled region produce an explicit **survival-unverified practice failure**, without inventing a lethal HP value. Far separations remain nonzero-damage observations and `damage_verification` stays incomplete. Passing the geometric course **does not certify full HP survival**. This is a concrete outstanding original-mechanic fidelity gap.

## Five route families

All five retain separate route data and legal finite-geometry tests. Numeric waypoints are simulator realizations, not official source coordinates. `complete` / `guide_route_complete` remain false rather than concealing the gaps below.

| Family | Established/corrected facts | Remaining source gaps |
|---|---|---|
| Elemental | Primary prose and first-Arrow/meteor figures read. First Arrow party SW, MT NW, ST SE, final tanks N/E. Meteor clocks now explicit. Exa exit 67.5 degrees, Wave E. | Exact Arrow2 diagram-to-path audit; flare equal-distance tie unspecified. |
| Aether | All 111 Toolbox step notes/texts read, relevant roles/geometry inspected. Raw dps1=MCH, dps2=DRG, dps3=SAM, dps4=SMN. Source clocks WHM E/SGE W, SAM SW/DRG SE, physical ranged NE/caster NW. First Arrow all SW, TH peel S, final MT NE/ST NW. One-marker exa exit =45 degrees; meteor MT/physical-ranged swap N/NE. | Generic H1/H2/M1/M2 assignment needs party convention; source does not mandate an E/W flare role priority. |
| LPDU | Prior three-slide primary audit preserved: party SE first Arrow; Arrow2 quadrant pairs and horizontal TH/vertical DPS split; meteor BOTH MT/R1 and H2/ST swaps. | Exa offset, complete temporal Arrow video audit, and late flare route absent from inspected three-slide source. Those fallbacks are not relabeled official. |
| CN Moogle | Parent full 15-panel audit used: Wave SOUTH, first Arrow party SW/MT front, second Arrow TH cardinals/DPS diagonals, meteor ONLY MT/D3 swap, optional H2 center, Dive MT left/ST right facing boss. | Exact exa exit and late flare/LB branches absent from poster; numeric footwork remains a training construction. |
| KR 09STOP | Full final-phase workbook text read via normal public htmlview iframe. Row115 permits one marker, recommends extra half-marker; 67.5 is a supported variant. Row313 says nearest B/C/D (or B/D if D3 marked); implemented minimum-total-travel assignment. Fixed north ranged, tank/melee vs outer healer/ranged distinction retained. | Animated pair geometry not frame-audited; equal-cost assignment tie unspecified; numeric 16/18 radii are not claimed source max-melee numbers. |

Aether Toolbox cache key is `548481027977761` (the user-facing longer URL suffix is not the JSON key). Source dps indices are explicitly not our role indices. Toolbox role centers are top-left plus half-size, scaled 40/15; NPC artwork anchors are not used to infer spawn coordinates.

KR prose describing Dive as three closest conflicts with the actual encounter source and captures. The mechanic remains closest two plus furthest for every region. Elemental's five-comet prose conflicts with the six distinct NPC instances in all four captures; runtime uses six.

Primary references: [Elemental](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/), [Aether Toolbox](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1), [LPDU](https://raidplan.io/plan/mh3bX4KJ9d8rT9nk), [KR workbook](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449), and the parent's `CN_POSTER_AUDIT.md`. Local `P6CosmoMeteor.cs`, `TOPEnums.cs`, `TOPStates.cs` were consulted as mechanic evidence; implementation is original GDScript. Dedicated P6MagicNumber/P6CosmoMemory files were not present; TOPStates, Action.csv and replay supplied the available evidence.

## Validation and unresolved work

Godot **4.4.1** headless:

- Existing `tests/p6_fidelity.gd`: **1614 assertions, 0 failures**. All Arrow/Exa counts/cadence, sixteen exa families, 48 bait explosions, both followups, five profiles, 56 flare sets, 6/s movement negatives and legal Sprint checks retained. Replaced the fake scheduled-lock assertion with actual successful casts and added all-eight-NPC kill assertions. Updated the contradicted CN-unknown assertion to the sourced south charge.
- New `tests/p6_lb_fidelity.gd`: **602 assertions, 0 failures**, approximately **6.7 seconds**, below 120 seconds. Includes all 280 profile/flare combinations with real cast locks, wrong job/gauge/stacks/spent, interruption, ground/ranged misses, dead target during cast, late comet kills, missing NPCs, human exclusion, JSON cast/animation checkpoints, two Magic cycles, Doom-at-5.9 failure, tank application/duration, legacy flag rejection and explicit shield/mitigation arithmetic.
- `git diff --check` passed. Godot emitted a sandbox root-certificate-store warning; no script errors occurred in the successful runs.

The last full regression ran after regional changes; the final API-only Vector2 ground-target acceptance and numeric validation change was followed by the 602-assertion suite. No tests were removed or relaxed to hide mechanic failures.

Outstanding: parent production/UI wiring; actual job post-animation calibration; exact ranged width/hitbox-edge interpretation; original large-meteor deadline; full flare interior/damage/mitigation survival; continuous passive/combat gauge generation; remaining LPDU/CN/KR visual route audit. These prevent an honest declaration of complete original P6 fidelity or all five fully authentic timelines.

## Parent checkpoint

All nine delivered files were reviewed; the parent independently reproduced 602
assertions with zero failures. Production LB request controls, complete course
wiring, calibrated default post-cast animation locks and Windows/Web input QA
remain separate follow-up stages. In particular, a zero default animation lock
is not a claim about game behavior; a maintained public LB reference reports
tank 3.86s, healer/caster 8.1s and melee/ranged 3.7s post-cast locks. Ranged width
also needs an independent full-width versus half-width audit before integration.

Parent post-integration regression checkpoint: LB suite 602 assertions and existing
P6 suite 1,614 assertions, both zero failures and no script/parse errors. This is
source-level validation, not completion of the pending production LB controls.

## Production controls integration — 2026-10-21

The isolated/parent foundation handoffs above are historical. Production now
calls `append_memory`, `append_meteors`, and `append_magic`. Main F/button uses
`request_lb`, not the legacy instant success flags. A role-compatible job picker,
explicit live NPC target picker for ranged/melee, caster X/Z ground target, gauge
and cast/lock display are available on these three drills. No selected NPC is
auto-replaced when it dies. Rejections retain their actual reason.

`p6_setup.gd` creates a visibly disclosed **standalone prerequisite snapshot**:
three Dynamis (existing encounter entry), LB3 gauge30000, selected jobs, and
Brilliant for post-Memory isolated drills. Memory starts without Brilliant and
only its actual survival event grants it. This is not passive/combat gauge
generation or evidence of having completed prior P5/P6 content. The boss target
uses a target-liveness HP sentinel, not a measured boss HP/DPS model. Meteor HP
and delayed LB damage retain the reviewed capture-based module's values.

Production supplies role-wide **post-cast** durations from
[AkhMorning / Actions in Detail](https://www.akhmorning.com/allagan-studies/limit-break/actions-in-detail/),
read2026-10-21: tank3.86s, healer/caster8.1s, melee/ranged3.7s. These are in
`top/data/p6_lb_calibration.json`; nominal cast time is additional, not included.
This is maintained-public-reference calibration, not newly measured per-job
server frames. Ranged half-width8 remains explicitly unverified.

Players cannot activate sprint/dash/jump while casting/animation-locked. A new
LB cancels a previously active training dash. Bots request the same action API
and skip the human's slot. Checkpoint oracle reconstructs earlier actions, then
hands future actions back to the human; it never grants a missing future cast.
Retries preserve actual gauge, casts, targets, refund/lock events and failures.

Godot4.4.1 parent acceptance:

- `tests/p6_controls.gd`:20 checks/0, including F, ground-range rejection, target
  selection, missing-human failures, actual cast JSON restore, retry and
  checkpoint ownership.
- `tests/p6_lb_fidelity.gd -- --production-locks`:602 assertions/0; its280
  physical profile×flare cases now use the real caster/ranged post-cast locks.
- Actual Main:86 offered methods across all20 catalog mechanics, seed17391,
  zero failures. The expensive three-seed batch was intentionally interrupted
  after retaining progress, not counted as a pass; targeted physical matrices
  retain their separate exhaustive coverage. Hidden P5 fixtures are not among86.

Exported Windows/Web input/visual QA is not established by these headless gates.
HP/healing/resurrection, passive/combat gauge, full flare falloff, ranged edge
width, original large-meteor deadline and unresolved regional source fields
remain pending. Five offered P6 methods explicitly retain partial-source labels.
