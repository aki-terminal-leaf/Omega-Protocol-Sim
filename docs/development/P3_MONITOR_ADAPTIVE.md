# Astoh M2-player / N3 adaptive monitor staging — scoped source and Web validation

This candidate only changes the N3 NPC goal for ordinary unassisted Astoh monitor practice when the human is source rank M2. Published priority ranks and actual attack/status/death verdicts are unchanged. Other six NPCs and other five layouts keep their original goals; demo is not treated as a human.

The planner waits for the actual human position/facing to stabilize for .3s, with .1m / .5-degree observation tolerances, and for the other six NPCs to settle within .2m. It uses the same current-public party effect projection as the HUD, plus current actor poses/facing and the current Boss half cast. Missing, hidden, consumed or runtime-expired cues invalidate the cached plan before commitment; no future human-facing answer or RNG is read. It keeps canonical N3 whenever actual source memberships and >7.1m spacing already work. Otherwise it searches a finite 595-point mirrored corridor, requiring exact source pairs, >7.1m spacing, arena bounds and affected normalized half-plane margin >=.05. Normal movement stays in Main; reachability assumes the existing6m/s law and arrival by duration-.2s. The last plan freezes at duration-1.25s so late wrong facing is not rescued. Per-beat/R resets clear private plan state.

All numeric staging positions, stability windows, margin and angle probes are engineering training choreography, not official game tolerances, global geometric optimality, or proof that every player input can/should be rescued. Exact player-coordinate conformance never independently determines PASS/FAIL.

## Accepted source evidence (2026-10-24)
- Initial actual ordinary-input Main:19courses/641checks,16positiveclean outcomes,3actualnegativeFAILs.
- Original six controls +six variants preserve exact human pose/face/input and other6NPCs; six controls preserve exact source resolution/status/coverage. Full20course six-layout regression has372checks and all complete rows equal the sealed prior baseline.
- Corrected pure39contract: original source fails5 cue/cache tests, tightened source passes. Parent test-fixture mistakes (missing runtime row is still a public cue; expiry tombstone initially absent) were preserved and corrected, not counted as product defects.
- Existing affected gates: NPC monitor258checks/72courses, interactions21, actualP3Main151, player outcomeMain19/4courses. Repeated after cue fix. Final actual19/20 rerun passed:19/641 and20/372; all19 complete results equal the initial candidate, and all20 complete regression rows equal the prior sealed baseline.
- First independent source reviewer omitted fixtures/Main; no independent fixture certification credited. Parent disproved its R/late-input claims from actual fixture. The focused Read-only CLI review read all7 pinned files and found NO_CONCRETE_MUST_FIX; parent separately verified all7 review hashes and326 engine source hashes. The reviewer did not run tests. Collected NEG18 freezes before8.9s and genuinely fails after the late QE input; no fake pair mutation.

Historical source-only checkpoint: Web/PCK acceptance was still pending and the fixed site was0.3.26. Current Web acceptance is recorded below; native/manual/GPU/all-guide acceptance remains pending. Windows20 is separate, AnAn desktop prohibited. Full20mechanism/100offered-guide correctness, measured optimization and completeAVFX remain active.

## Reproduce source gates

Use the pinned Godot4.7.2 engine and task-private same-version imported assets/cache:

~~~sh
Godot --headless --path top --script res://tests/monitor_adaptive_contract.gd
Godot --headless --path top --script res://tests/monitor_adaptive_main.gd
Godot --headless --path top --script res://tests/npc_monitor_preparation.gd
Godot --headless --path top --script res://tests/interactions.gd
Godot --headless --path top --script res://tests/p3_public_main.gd
Godot --headless --path top --script res://tests/player_outcome_main.gd
~~~

The two new tracked fixtures are byte-identical to the independently reviewed,
executed parent fixtures. The separate20-course comparison is retained local
evidence, not an additional publicly shipped fixture. No source assets/logs or
private diagnostic output are included in Git.

## Bounded policies and remaining gaps

Non-malformed infeasibility retains the previous/canonical target; it is not a
promise to rescue every input. Only the settled human pose triggers a grid
recompute: the other published source sides are fixed for this generated beat.
After commitment, disappearing cues do not restart planning. These policies are
not generic changing-cue support. Scope is ordinary Astoh M2-human/N3 only;
other roles, layouts and all-guide player obligations remain separately open.
A missing runtime row intentionally retains a still-visible authored public cue;
the expiry test inserts an actual expired override and checks the HUD projection.

Source increment is v0.3.27-preview. At this historical source-only checkpoint,
new exported PCK, browser, deployment and release were still pending on live0.3.26.
The Web publication below supersedes that checkpoint; native evidence remains pending.
No desktop operation is authorized in the current work window.


## Web-first v0.3.27 accepted (2026-10-24)

Runtime `485bd84c66d08e93f7b2aa8e58d9598893527cf7`, exact PCK `8a04f5cd8ad6684a9d0d901f719885ca833102a5b6883314c88e1298e23ba9e4`. All21 exact-pack gates passed; original actual ordinary Astoh M2-player/N3 browser workflow passed8 checks, separately reviewed settings/final pixels, actual monitor resolution with exact8-actor active status durations, same-seed R clearing and genuine idle/no-input failure. Prior4 browser workflow failures remain preserved and failed. Thirteen fixed HTTPS identity/decoded-gzip representations and fresh public startup (startup only, not a second gameplay run) passed. [Release](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.27-preview).

Scripted paused0.5x Web correctness only; D3D11 renderer information is not measured FPS/native/manual acceptance.13degrees means -77degree facing relative to canonical-90; it is an engineering input probe, not an official tolerance. Late-QE failure evidence remains source/same-PCK only. Other roles/layouts, all20/100-guide correctness, measured optimization and completeAVFX remain active; native27 pending and AnAn desktop disabled. Historical source-only pending statements above describe the pre-publication checkpoint, not current Web status.
