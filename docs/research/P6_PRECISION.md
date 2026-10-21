# P6 precision evidence checkpoint — 2026-10-21

Historical worker scope: baseline `2d9e832`, isolated worktree. Parent review and
validation now run on the pinned4.7.2 active development branch. This remains a
partial fidelity checkpoint, not a published release or complete server model.

## Executable changes

- Flare `upper` is now null for both own-flare and far observations. Empirical
  extrema are separate `observed_lower` / `observed_upper` fields. The 12917
  observed far maximum cannot be consumed as a universal survival bound.
  Distances beyond the observed 37.088 are explicitly `beyond_samples`.
  Interior uncertainty still rejects practice survival; this change does not
  relax the existing close-flare negative. Public timeline records explicitly
  say HP survival is unverified.
- Parent rejected the worker's proposed moving-target completion range gate:
  client Range does not establish the server's cast-finish grace behavior.
  `p6_lb.gd` stays unchanged. Existing dead/untargetable/removed-target rules
  and moving-target re-aim/delayed-snapshot tests remain; no speculative new
  out-of-range interruption rule is adopted.
- Meteor checkpoint records now carry `server_deadline_verified=false` and
  their practice basis. No unobserved NPC enrage is manufactured.
- Dedicated `p6_precision.gd` covers the current training rectangle's lateral,
  rear and longitudinal boundaries, caster circle boundary, translated origin,
  moving target re-aim at finish, immutable delayed snapshot after JSON restore,
  dead/removed/untargetable targets, real postlocks, and damage
  packets before/at/after the practice deadline. These are model checks, not
  measurements of server collision behavior.

## All-four full-capture meteor audit

Read every `replay-*.json.gz` plus `enemy-casts.json.gz` and `metadata.json.gz`
under `D:/Dev/OpenClawCodexBridge/research/top-v03/fflogs-evidence`.
NPC identity comes from metadata **guid**, not player job or source actor ID.
Zero is each capture's boss **begincast 31664**, not fight start or absolute time.

| Capture | Zero timestamp ms | First large-meteor interaction | Last large-meteor damage packet |
|---|---:|---:|---:|
| Vyq4AcJKZjkFQBpG/32 | 26910172 | +11.534s | +24.361s |
| LKMGRJTzgY9HFynk/2 | 1207039 | +10.182s | +26.439s |
| 3GW2hjTNk91FZwcK/9 | 6290986 | +12.130s | +25.808s |
| 1bX86aKrVRwLWfTC/19 | 14988012 | +12.963s | +28.871s |

All 175853 replay events were read. Neither NPC15726 nor NPC15727 originates a
cast/begincast in any capture. Player Glare casts targeting NPCs in capture19
are not NPC casts. The files contain no NPC spawn event. First interaction is
an upper bound on spawn time, not a spawn timestamp. Last damage in a clear is
not an enrage deadline. Boss visual31665 is +29.226..29.276s, not proof of NPC
enrage. Therefore the existing T8.2 spawn and T30.5 checkpoint remain training
values, not newly established original timings. Exact aggregates are in
`p6_lb_routes.json` → `meteor_landmark_audit`.

## Width / origin / hitbox evidence and blocker

The baseline audit records Action4244/4245/17106: Range30, EffectRange30,
XAxisModifier8. **No Action.csv exists in the supplied research tree or this
local project tree** on this worker. A fresh direct fetch was denied by the
network sandbox; the web fetch rejected the CSV as over its content-size limit.
The parent independently re-read Action4244 through the bounded XIVAPI row endpoint (recorded in `p6_lb_routes.json`): CastType4, Range30, EffectRange30, XAxisModifier8. This confirms the client row, not its server full/half-width or hitbox interpretation; the other rows retain their original audit status.

[Maintained BossMod BRD action definitions](https://raw.githubusercontent.com/awgil/ffxiv_bossmod/master/BossMod/ActionQueue/Ranged/BRD.cs)
describe SagittariusArrow4244 as `30+R width 8 rect`, BigShot as width4,
Desperado as width5, and ApexArrow16496/BlastArrow25784 as width4. This is
contrary to treating every XAxisModifier as a half-width. The cached TOPEnums
also describes 31659 as width8 and 31651 as width10; existing encounter modules
use these as full widths. However action comments are not a server collision
experiment. Another public wiki reports LB3 as 30×16, demonstrating conflicting
secondary interpretations, not resolving them.

[AkhMorning's maintained LB research](https://www.akhmorning.com/allagan-studies/limit-break/actions-in-detail/)
specifies a straight line but no numeric width or hitbox-edge policy. It does
support the existing 4.5s DPS cast plus 8.1s caster / 3.7s ranged postlocks.
The present centered successful replays do not discriminate half4 from half8.
No width reduction, target-radius inflation, caster-radius extension or server
verification flag was introduced on this incomplete evidence. The current
half8 center-based model remains explicitly unresolved.

## Regional sources

Re-read cached full P5/P6 Toolbox (`fflogs/p5-p6-primary-diagrams.json`, key
548481027977761, 111 steps), route records, and CN full-poster audit. Toolbox's
`job` field misleadingly says `tank` even for healer/DPS icons; actual labels
are GNB, DRK, WHM, SGE, MCH, DRG, SAM, SMN. Thus raw dps1 maps to simulator
physical-ranged slot6, dps2 to DRG slot5, dps3 to SAM slot4, dps4 to caster7.
Existing Aether clocks already implement that mapping. Step101 explicitly
swaps MT/physical ranged N/NE; no correction to those clocks is justified.
The CN audit supports existing MT/D3-only swap and south charge. No new source
for missing LPDU temporal footage, KR animation, or CN late-flare branches was
found. Equal-cost flare assignments and numeric waypoints remain training
choices. No bot exemptions, teleports, movement allowances or hazard shrinkage.

## Commands / validation

`python3 tools/work_guard.py begin p6-precision --budget 1200` could not launch:
python3 is absent. The provided guard also imports Unix-only fcntl. No guard or
global configuration was edited. Native `python` and bounded subprocess calls
were used; the Godot test was wrapped in `subprocess.run(..., timeout=110)`.

Test invocation:

```
D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe --headless --path top --script res://tests/p6_precision.gd
```

**BLOCKED:** the exact invocation above timed out after 110 seconds with no engine stdout/stderr. Python returned subprocess.TimeoutExpired. Stage stopped; no retry. New and regression suites are NOT claimed passing. The baseline 1614/602 counts are historical. Parent must resolve the launch/termination issue and validate these uncommitted edits.

## Parent review / pinned-engine follow-up

Reviewed every worker changed/new file and the failed-command evidence. Original
checkout remained clean; the worker's timed-out process no longer exists. Only
observation/bound reporting, explicit unverified deadline/HP metadata, anonymous
landmark audit and meaningful edge/snapshot/deadline tests are accepted. The
unsupported completion-range gate was rejected. The historical worker's
`review_required` and its independent baseline602 exit0 do not prove the new
test passed; parent4.7.2 validation is recorded separately after execution.

This does not establish the missing enrage, full flare curve, LB edge/hitbox
policy, contact thresholds or complete regional/VFX coverage. Publication still
requires resolving the user's remaining-fidelity condition, not a renamed
training parameter or an observation labeled as a universal bound.

## Parent independently collected a failed P6 capture

Normal public FFLogs UI exposed14 wipes, including3 P6 wipes. The complete
`1bX86aKrVRwLWfTC/17` (17:54) replay was then collected with the existing
public collector:39,115 events,1,222 enemy cast events, no missing segments.
Boss begincast31664 is zero13136968ms. All six small-comet instances become
untargetable at T20.396; six AID31669 enrage cast events follow at T20.488.
Thus the existing nominal20.5s **small-comet** failure snapshot now has direct
failed-capture support, not only successful-clear timing or a guide estimate.
It remains a nominal snapshot, not a measured universal server tick. Delayed
damage/death packets must not be confused with the original failure snapshot.
Only anonymous aggregates are added to `p6_lb_routes.json`; raw logs/names stay
private. The party wipes to small comets before any large-meteor deadline, so
this does **not** calibrate the large meteor's30.5s practice checkpoint.

The maintained BossMod TOP state source independently marks small comets as
enraging about0.3s after the flare markers, while its large-meteor comment is
explicitly `enrage in ???`; its flare component also retains a falloff TODO.
These comments support retaining uncertainty, not guessing a new radius/time.
Source directory: https://github.com/awgil/ffxiv_bossmod/tree/master/BossMod.Ultimate/Endwalker/Ultimate/TOP

## Parent4.7.2 acceptance

New precision suite:52 assertions/0 failures (including non-finite distance,
damage and mitigation rejection without corrupting HP/shields). Existing
LB602/0 with production locks, P6 movement1614/0 and Main controls20/0 pass.
The first parent run caught an untyped inferred-boolean parse error in the new
test; fixed to an explicit bool, without changing its collision expectations.
The worker's prior timeout remains historical, not a passing test.
