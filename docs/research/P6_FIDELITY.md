> Historical isolated-worker handoff below. Production Arrow/Exaflare wiring
> is present; the2026-10-21 follow-up now also wires Memory/Meteors/Magic and
> actual Main LB controls. See [P6 LB production integration](P6_LB_FIDELITY.md)
> for current gauge, targeting, cast and post-cast lock behavior. Original
> regional/source/combat limits below are not silently marked complete.

# P6 movement fidelity handoff

2026-10-21; independent worktree based on `18485c4`.

**Implemented:** complete finite Arrow/Exaflare hazards, overlapping followups, actual-position puddles, dynamic Wave/Dive geometry, and meteor movement branches. **Incomplete:** exhaustive authentic routes for five communities, full job combat, flare HP falloff, and production encounter selection. Every route record retains `complete: false`.

## Files and parent integration

- `top/scripts/p6_patterns.gd`: pure finite patterns, regional distinctions and unknowns, training waypoints, 56 flare combinations.
- `top/scripts/p6_courses.gd`: complete combined courses and deterministic family constructors.
- `top/scripts/p6_runtime.gd`: timed actual-position snapshots, persistent explosions, LB locks, JSON-native state, decorative telegraphs.
- `top/tests/p6_fidelity.gd`: independent positive/negative cases, finite movement-family coverage, JSON checkpoint replay.
- `statuses.gd`: exactly three added calls, inside existing begin/tick/sync. No Hello World code or signature changes.

No Encounters, Rules, Main, Interactions, settings, or existing tests were edited. No commit, push, merge, deployment, original checkout write, raw capture, player name, or guide artwork is included.

**Production Encounters does not call these helpers yet.** Existing runtime tests prove the hooks preserve old behavior, not that the menu runs these replacements. Parent integration should replace each entire branch with one call:

| Catalog ID | Call |
|---|---|
| `p6_arrow_dive` | `P6Courses.append_arrow(self, false)` |
| `p6_arrow_wave` | `P6Courses.append_arrow(self, true)` |
| `p6_exa_wave` | `P6Courses.append_exaflares(self, false)` |
| `p6_exa_dive` | `P6Courses.append_exaflares(self, true)` |
| `p6_meteors` | `P6Courses.append_meteors(self)` |

Do not append another old Wave/Dive call: each helper already includes its followup. `ctx` uses existing `profile.id`, `rng`, `positions`, `labels`, `beats`, and `beat()`. No new profile JSON fields are required. Tests additionally use `append_arrow_family`, `append_exaflare_family`, and `append_meteor_combination` to exhaust choices independently of RNG.

**Parent must address movement speed before enabling these courses.** Runtime enforces a uniform 6 units/s training limit. Main currently moves live bots and checkpoint-oracle actors at 11 units/s; changing Encounters alone would make those actors fail. Apply the same 6 units/s integration to both paths, without bot exemptions. Sprint/dash exceptions are not modeled. The harness moves every actor at 6 units/s through production Interactions, without endpoint teleportation.

## Timed geometry

Timings are normalized training values preserving measured overlap, not identical-millisecond claims across captures.

### Arrow

Each occurrence has 42 geometric explosions: central streams contribute 14, side streams contribute 28. Six initial casts split 2/4 or 4/2, two seconds apart. Initial strips have width 10. Central strips split to both signs at offsets 7.5, 12.5, 17.5 with width 5. Side strips begin at signed 15, advance inward by 7.5 then 5 per pulse, cross center, and continue to the opposite side. Pulses are two seconds apart.

Initial telegraphs appear at course T0 and T2. First damage is T8. Center-first ends T22; sides-first ends T20. Wave proteans occur at T17/T19 while Arrow is active; charge resolves T25.6. Dive resolves T23.2. There is no old sequential seven-second followup gap.

### Exaflares and actual puddles

Eight starting directions times CW/CCW gives 16 families. Four adjacent 45-degree starts are radius 24. Each line has seven radius-8 explosions, advancing 8 units through center. Starts are T12/13/14/15; first advance is +1.11 seconds, subsequent advances +1.00 seconds.

All eight actual positions lock at T10/12/14/16/18/20. Eight radius-6 circles are queued per lock, even when stacked, and explode three seconds later. Pending events survive beat boundaries. No suggested goal substitutes for a bait position. Events predating the available movement interval fail explicitly; events inside a tick interpolate actual movement at the scheduled time.

Both 45-degree and 67.5-degree escape variants pass every rotation/direction at 6 units/s. Movement starts center, reaches radius 6 then 14, and rotates around radius 15. An inward step at T23 keeps the Wave fan-out out of the last puddle; that puddle still resolves at T23. Wave follows at T26.2/T28.2/T34.4; Dive resolves T26.3.

### Wave, Dive, meteors

Proteans use complementary four-target sets and full width 8. Width-8 charge aims at the selected actor's actual position and requires all eight with both tanks foremost along the actual axis. The server's charge-target selection policy remains unknown: random non-tank selection is a training convention.

Dive selects the actual two nearest and actual farthest actors. Nearest must be tanks, individually isolated at radius 8. Farthest must share a radius-6 stack with exactly six non-tanks. Old `(-4,-4)/(4,-4)` tanks fail at the touching boundary.

Meteor radius-10 puddles lock T5 and explode T9. Radius-5 spread waves resolve T10.2, T11.2, T16.2, T17.2. Flare markers appear T20.2; three flares and the radius-6 five-person stack resolve T28.3. All 56 flare selections are generated and physically tested. D3 stays north while others adjust. E/W ties use an explicitly labeled actor-index training convention.

Nominal 4.5-second caster/ranged cast locks start at training times T9/T20. `P6Runtime.animation_lock(state, actor, duration)` accepts an actual caller-supplied lock. Exact job-specific post-cast animation durations are unresolved. There is no gauge, damage, comet-kill, mitigation, or healer-job simulation.

Attack data gives flare range 100 with unresolved HP falloff. Runtime records actual distances and `falloff: unmodeled`, checks the five-person stack, and makes **no flare-survival verdict**. There is no radius-12 immunity circle. The decorative radius-1 flare indicator is a marker, never damage geometry.

## Community coverage

Read the completed sibling research artifacts in `top-five-route-research-20261021`: `docs/research/REGIONAL_ROUTE_AUDIT.md` and `top/data/regional_route_spec.json`. That audit explicitly marks every route partial. Unknown values remain null in `P6Patterns.route()`; training constructions are labeled in beat metadata/notes.

| Community | Retained distinctions | Unresolved / training choices |
|---|---|---|
| Elemental | East stack; 67.5-degree escape; D3 north/MT northwest clocks | First Arrow quadrant, exact lateral lanes, meteor clock map, flare E/W tie |
| Aether | South stack; MT north/ST south; TH clockwise prepositioning | D1/D2 uses SAM/DRG convention; escape offset, exact lanes, meteor map |
| LPDU | South/C stack; Arrow1 party SE, tanks NW/NE; Arrow2 paired quadrants and directional exits; meteor MT/R1 **and** H2/OT swaps | Full animated Arrow footwork, escape offset, meteor flare/LB plan |
| CN Moogle | MT north/ST east/H2 south clocks; **only** MT/D3 meteor swap; left/right tank Dive | Arrow branches, escape offset, stack direction, meteor flare/LB plan; south stack is a labeled training choice |
| KR09STOP | South stack; first Arrow party SW, tanks toward 11/1; 67.5-degree escape; melee/tank versus outer ranged/healer flares | Exact Arrow quadrant pairing/animations and E/W flare tie. Pairing is a training derivation from clocks. Numeric flare radii 16/18 express the relative distinction, not an audited survival threshold. |

Aether retains its 45-degree exit; LPDU still has an unknown exit and an explicit 45-degree training variant. KR/Elemental use guide-supported 67.5 degrees. The user follow-up specifies CN departure at the relative gap between the first preceding and two-preceding waymarks (67.5 degrees behind the first telegraph in the propagation direction), now applied to both Exaflare followups. The initial T0–T10 center bait is unchanged: this corrects departure heading, not complete gap-start staging. Shared geometry does not establish whole-route equality. The KR Dive wording conflict is resolved using encounter behavior, not modeled as a different regional mechanic.

Primary pointers from the audit:

- [Tuufless Alpha Omega](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/): directly read text supports the escape offset, east stack, relative Dive positions, and D3-dependent flare branches.
- [Aether/Saus P6](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1): audited steps 48, 51, 65, 69 and meteor section.
- [LPDU source](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md), [three P6 slides](https://raidplan.io/plan/mh3bX4KJ9d8rT9nk).
- [CN macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH): page 2; tall diagram/videos remain unaudited.
- [KR P6 workbook](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449): rows 21–85, 149–219, 222–258, 264–313.

Linked Tuufless figures failed with web cache misses. Browser tooling reported no available browser, and direct HTTP was denied by managed network policy. This task does not claim visual verification of those figures. Original diagram/video auditing remains necessary for full five-community fidelity.

## Capture checks and provenance

Read anonymized observations and actual gzip enemy/replay events for `LKMGRJTzgY9HFynk/2`, `3GW2hjTNk91FZwcK/9`, `1bX86aKrVRwLWfTC/19`, and `Vyq4AcJKZjkFQBpG/32`. The parent manifests account for 4,875 enemy events and 175,853 replay events. Raw logs remain outside the repository.

Language-independent IDs: Arrow 31651/31652; exas 31661/31662; puddles 31663; Wave 31659/31658; Dive 31655/31656; meteor puddles/spreads/stack/flares 31666/32699/31667/31668. Eight Arrow observations each have six initial plus 36 subsequent casts: three center-first, five sides-first. Eight exa observations confirm adjacent origins.

Source-resource samples include radius-24 starts and radius-16/radius-8 advances, but also stale/default `(0,-10)` helper positions. Helper identity is not stable across every pulse. Player resources were bracketed/interpolated using metadata fight membership, separating players from LimitBreak/NPC actors. Multi-second sample gaps limit sub-frame conclusions. FFLogs screen facing is `facing/100` radians; arena N/CW conversion requires +90 degrees.

Across four clears, meteor initial puddles resolve 8.975–8.997 seconds, spread waves near 10.18/11.22/16.22/17.24, and flares/stack 28.246–28.295. LB events report nominal 4500ms casts, with observed begin/end intervals around 3966–3994ms. Stationary replay does not establish post-cast animation duration. First exa advances are near 1.11 seconds; later advances are approximately 1 second.

Provided `P6CosmoArrow.cs`, `P6WaveCannon.cs`, `P6CosmoDive.cs`, `P6CosmoMeteor.cs`, `TOPEnums.cs`, and P6 `TOPStates.cs` sections were research cross-checks. The GDScript generators and scheduler are original implementations.

## State and validation

`state.p6` is JSON-native: pending absolute events, history, locks, marker targets, course lifetime. IDs normalize to integers on resolution because Godot JSON restores numbers as floats and Array membership is type-sensitive. Outcomes also enter common `state.timeline`, already exported by the parent report. Existing retry snapshots duplicate the whole state. Parent should expose `state.p6` in mid-course reports when pending-event inspection is needed.

Godot 4.4.1 results, all exit 0:

| Suite | Result |
|---|---|
| New `p6_fidelity.gd` | 1,332 assertions, 0 failures |
| Existing `rules.gd` | 190 assertions, 0 failures |
| Existing `interactions.gd` | 18 assertions, 0 failures |
| Existing `stateful.gd` | 72 assertions, 0 failures |
| Existing `run.gd` | 30,540 snapshots, 0 failures |
| Existing `review.gd` | 218 assertions, 0 failures |
| Existing `runtime.gd`, unfiltered | 93 courses, 0 failures |

The new harness covers all 16 exa families with both followups for five profiles, both Arrow families with both followups, all 56 meteor combinations for five profiles, both escape variants, and 100 seeded combined courses with JSON round trips between beats. Actors move at 6 units/s using 0.025- and 0.1-second steps. Negative cases cover overlapping delayed strips, boundaries, old puddles after beat/JSON restoration, missed historical locks, teleportation, width-8 clips, actual charge aiming, actual Dive targets, and LB locks starting inside large ticks. There is no filtered-empty pass.

`models.gd` exited 0 but loaded zero models because assets are absent; this is not model-fidelity evidence. Existing app suites printed missing imported-font/certificate-store diagnostics while assertions passed. No assets were imported or changed. The managed user-log path was unwritable, so tests temporarily logged to this permitted document path; the final handoff replaced that output after testing.

Typical rerun from this worktree:

```powershell
& 'D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe' --headless --path top --script res://tests/p6_fidelity.gd
```

In a similarly restricted environment, supply an authorized writable `--log-file` path. Preserve this final handoff when rerunning tests.

## Parent integration (in progress)

The four Arrow/Exaflare combined courses are now production-wired. Live and checkpoint P6 actors use6units/s; legitimate player Sprint/dash receives an independently calculated movement budget instead of a blanket6/s failure. Actual LB-lock movement is blocked in input. Other legacy mechanics retain their prior bot navigation speed pending full movement review. Meteors are deliberately not switched to the movement-only helper yet: missing actual LB/comet/meteor judgments must not regress the existing role-action requirement.

The parent subsequently visually read the entire CN1125x33824 poster through its normal public image viewer; see CN_POSTER_AUDIT.md. It confirms south/C charge stack, first Arrow partySW/MTfront, second ArrowTHcardinal/DPSdiagonal, and onlyMT/D3 meteor swap. Four independent clear captures each show six distinct comet15727 instances receiving casterLB damage, resolving the five-versus-six guide conflict in favor of six. These new facts still require route-code updates; a research note is not implementation.


## User-feedback pair correction (2026-10-23)

CN Arrow→Wave uses numbered sectors 1=[D4,ST], 2=[D2,H2], 3=[D1,H1], 4=[D3,MT]. Existing A=MT/B=ST/C=H2/D=H1 clock ownership is retained, not newly repaired. Pair sectors use the existing time-dependent in/out coordinates and counterclockwise cardinal transition, not a static radius-10 hold (which is hit by actual Arrow strips). Arrow→Dive, Meteor and non-CN paths retain their previous behavior. Exact numerical temporal footwork remains a training construction; complete-route flags stay false.
