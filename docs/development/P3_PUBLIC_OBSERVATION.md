# P3 transition: public-observation steering (source increment)

This increment corrects NPC access to future arm order. It is **not** full guide,
manual-player preparation, original-game onset, exported-platform or GPU acceptance.
No version bump or release is included; the frozen 0.3.17 candidate and currently
published 0.3.13 deployment are not replaced by a source commit.

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

## Outstanding

All-partition public-observation walking coverage, positive human-driven sorting and
choice/preparation, delayed/invalid-cue diagnostic UX and a measured maximum-delay
boundary remain separate work. Original arm/debuff source onset and encounter HP,
shields and damage model remain unverified/unmodeled. Exported Windows/Web and
rendered visual acceptance remain pending; headless passes do not waive those gates.

The owner currently requires work without desktop use. No AnAn GUI launch, input,
focus/capture or idle probe was performed for this increment.
