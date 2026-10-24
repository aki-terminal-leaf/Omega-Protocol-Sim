# P3 LPDU N4 spacing correction — v0.3.28 source checkpoint

Only LPDU N4 changes from canonical (10,11) to (7,10.5), mirrored by the existing boss side. Registered Light PF/LPDU Toolbox step5 says N4 near boss and N5 at wall; it does not calibrate exact metres. This is an engineering spacing correction away from M1’s half-plane boundary, not an official tolerance or global optimum.

The earlier actual Main WASD/QE/R comparison reproduced seed1 +0.1degree M1 rotation: original N4 became a third M1 candidate, leaving ST without a hit/status and D2/N4 double-hit under the existing RNG. Seed2 -0.1degree can still select the original pair; not every tilt fails. The isolated candidate passed the same four inputs, 87 checks, eight single hits, exact five/seven-second statuses and no deaths. Fixture precision is not a player-coordinate verdict requirement.

Source regressions: pure32seeds/96 synthetic Rules evaluations/3873 checks, both mirrors; existing72NPC courses/258 checks; six layouts20 actual Main input cases/372 checks. Pure tests are not Main or full-guide acceptance. Player input, 6m/s walking configuration, random assignments/targets, status/death verdict and all other layouts remain unchanged. Legal alternative positions do not fail merely for missing guide coordinates.

A previously selected legacy all-mechanism ideal-snapshot suite failed: 41760 snapshots,719 reported failures and missing statuses/Sigma/Omega runtime-state errors. The unchanged baseline reproduces the same errors/counts/examples; the original failure is retained and is NOT a PASS. Its fixture lacks evolving runtime state; it is not an all-guide certificate. Instead, a separately scoped full-generated-dictionary preservation comparison checks five profiles ×20mechanisms ×48seeds, permitting only the LPDU N4 position to differ. Collected result:4800 normalized full dictionaries equal; only48LPDU N4 positions change, other4752 raw dictionaries are exact. The independent final review is retained separately; it does not execute or certify unseen platforms.

This source checkpoint is not a new Web or native release. Live v0.3.27 remains unchanged until new exact-PCK and actual Web checks pass. AnAn desktop stays disabled; native acceptance pending. All20/100-guide correctness, measured performance and fullAVFX remain ACTIVE.

## Reproduce affected source checks

With pinned Godot4.7.2 and same-version imported assets:

~~~sh
Godot --headless --path top --script res://tests/lpdu_n4_contract.gd
Godot --headless --path top --script res://tests/npc_monitor_preparation.gd
~~~

The20 actual Main regression cases, four original input-sensitivity cases, generation differential and failed legacy baseline comparison are retained task evidence, not additional shipped gameplay fixtures. The new tracked test checks semantic margin/pairs/separation/statuses; it does not assert the exact new N4 coordinate. Its +/-0.1degree and0.05normalized-dot limits are finite engineering regressions, not calibrated FFXIV tolerances.
