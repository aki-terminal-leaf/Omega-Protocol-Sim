# P3 transition: public-observation steering (source increment)

This increment corrects NPC access to future arm order. It is **not** full guide,
manual-player preparation, original-game onset, exported-platform or GPU acceptance.
The initial source increment did not replace the frozen 0.3.17 candidate or live
0.3.13 deployment. The 0.3.18 Web-first candidate below includes that routing fix;
source acceptance alone still is not a published Web version.

## Information boundary

- Fresh runs hold actual positions until current sniper debuffs have been published.
- Before the first observed arm wave, NPCs stage at their nominal strategy angles,
  radius 19; neither solved beat positions nor hidden family/pending events steer them.
- Only actual visible official arm scene nodes with a loaded `GameMesh` produce
  `{id,pos}` receipts. The ordinary frame publishes after movement and scene update;
  unseen internal 50ms substeps cannot reveal answers. IDs are opaque identities.
- The first three distinct same-orientation sources establish first-wave orientation.
  Missing receipts retain memory. An initially mixed/simultaneously skipped six-source
  set is ambiguous and fails closed rather than consulting an oracle.
- Current public debuffs determine the fixed-priority strategy slots; the nominal
  angles and observed orientation reconstruct the existing route phase waypoint.
  Damage geometry, event times, walking speed, RNG and human input are unchanged.
- State-local memory survives JSON and later debuff removal, but resets on a fresh
  course. Retry restores the appropriate beat-start observation snapshot.
- Checkpoint pasts use explicitly `assisted_checkpoint_not_observed` reconstruction.
  That basis is never upgraded to live observation or manual-preparation credit;
  the UI and exported report identify checkpoint assistance.

## Reproducible headless source checks

Use the pinned Godot 4.7.2 engine and an isolated same-version import cache/assets.
These commands operate on scene/runtime objects, **not desktop windows or GPU pixels**.

```sh
Godot --headless --path top --script res://tests/p3_public_observation.gd
Godot --headless --path top --script res://tests/p3_public_main.gd
Godot --headless --path top --script res://tests/p3_transition_fidelity.gd -- --quick
Godot --headless --path top --script res://tests/runtime.gd -- --only-method=1 --only-seed=17391 --progress
```

- Public-observation fixture: 71 full-mechanism walking courses, 489 assertions,
  zero failures. All five profiles x both arm orders x four samples are included;
  additional 0.1/0.3/0.5-second presentation frames and one every-frame JSON course.
  Ring/arm/sniper judgments and actual outside-point arrival are asserted. Hidden
  metadata/pending-input mutation and arm-order trajectory twins are discriminating
  tests. These synthetic presentation fixtures do not count as rendered observations.
- Actual Main scene: 151 assertions, zero failures. All eight human roles remain
  human-owned; deliberately stationary players fail without rescue. Five actual
  Main demo courses pass. Official-node availability, one-frame/substep publication,
  pause/retry/restart and explicitly assisted checkpoints are checked.
- Existing P3 quick fidelity: 2,268 assertions, 13 physical simulations, zero failures;
  all 420 debuff partitions are checked for priority/order invariance only.
  **This is not 420 public-observation full-course proofs.** The integrated fixture
  compares event identities/times and physical judgments, not the old oracle path.
- Shared actual Main smoke: all 20 mechanisms, method 1 / seed 17391, zero failures.
  This is not all 100 methods or all-guide certification.

## 2026-10-24 continuation: exhaustive walking and scripted player input

The 0.3.18 candidate adds **tests and documentation**, not a new damage geometry,
timer, NPC speed, player movement rule or automatic player-preparation feature.

- All **420** unique purple/white partitions x **five** profiles x **two** arm orders:
  **4,200** complete public-observation walking courses at sample 2, **21,685**
  assertions, zero failures. Each profile shard asserts its 840 actual courses and
  all 420 enumerated partitions. These are simulated presentation receipts, not
  native/Web visual receipts. Four-sample and variable-frame coverage remains the
  separate 71-course source increment above; not a 16,800-case cross product.
- Actual Main physical-key input: **40** positive courses (eight human roles x
  five profiles, natural seed 17391) and **three** intentionally bad courses;
  **508** assertions, zero failures. The test reads current public debuffs and
  static route priority, and actual scene-node arm receipts. It independently
  derives the numerical route and sends physical WASD; it never steers through
  bot_goal, observation.goal, solved positions, hidden family/pending events,
  actor writes, demo, checkpoint reconstruction, Sprint or teleport.
- Stationary, wrong-slot and released-input cases really fail; NPCs never rescue
  the released-input player. A dead marked owner may emit fewer than six packets,
  which is an explicit failure case, not an accepted healthy encounter.
- The healthy cases assert eight rings, six arm hits, one sniper event, six sniper
  packets, exactly one actual magic packet per selected human, zero sticky
  physical errors and the independently derived final slot within 0.16 units.
- This natural seed exercises all three debuff classes globally but **only first
  arm order 0**. It does not cover each human/strategy/class/order combination.
  Exhaustive bot walking through both orders is not substituted for that gap.
- Signed exact-waypoint arrival margins are retained. The tightest digital-key
  case reaches within 0.16 of the constructed waypoint **0.023 seconds after**
  sniper, while its interpolated snapshot already satisfies the real geometry.
  The constructed center is not a guide-required exact stopping point. Physical
  judgments were not relaxed; this is not a reaction/latency guarantee.
- Earlier rejected test expectations (JSON float/int priority comparison, exact
  center arrival before sniper, six packets for a dead-owner negative) and their
  raw failures are retained in stage evidence. Only the final corrected suite
  qualifies as passing.

~~~sh
# Run once for each: elemental aether lpdu cn_moogle kr_09stop
Godot --headless --path top --script res://tests/p3_public_observation.gd -- --partition-profile=elemental
Godot --headless --path top --script res://tests/p3_player_input.gd -- --seed=17391
~~~

The audited guides use fixed per-debuff priority here. No player-selected slot,
mandatory mark, confirmation click or handoff is invented. This verifies scripted
execution of that fixed-priority preparation, not actual manual play.

## Outstanding and Web-first publication boundary

Per-human/class/arm coverage, delayed/invalid-cue diagnostic UX and a measured
maximum-delay boundary remain separate work. Original arm/debuff source onset,
original guide numerical paths and encounter HP/shields/damage remain unverified
or unmodeled. Full 20-mechanic/100-method guide conformance, measured optimization
and complete AVFX remain active.

The owner explicitly requested stage-complete **Web-first** publication. A fresh
same-PCK regression and actual exported-browser UI/report checks are required
before updating https://top.servicing.cc. Native acceptance remains
pending_desktop_disabled; it is not a prerequisite for this Web-first stage and
is never reported as passing. No desktop/AnAn GUI, input, focus/capture or idle
probe is used.
