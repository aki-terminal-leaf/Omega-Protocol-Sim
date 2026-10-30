# Current accepted correction — Play / Pause only

2026-10-30: **Accepted for headless control-signal and numeric behavior only.** The inspector exposes Play and Pause, two model/clip selectors and a read-only elapsed/duration label. Playback is normal 1x; selecting any segment pauses at its start. Pause resumes at the same position. Each segment stops at its own end, never loops or advances to another segment/model; Play at the end restarts that same segment. Speed, Replay, Loop and seeking controls are removed; internal controller capabilities remain unchanged.

Parent review found that the first isolated snapshot contained historical SourceAnimation SHA `d1977f75eb108b6eef4952aea334520c46becd6815a7da50e2acb393046de8f8`, rather than accepted v3 SHA `da629dc551ea44240043b8b92629e9151014f892dd8d815fee3ee8870a723370`. The original accepted checkout stayed intact. Parent restored its exact bytes in this isolated worktree, with the prior file and failed runs preserved. The cause of that staging discrepancy has not been established. The earlier claim of all25 protected files matching accepted v3 was incorrect for that first snapshot; all25 now match the frozen accepted seed. No new animation logic or source-data change was made.

The corrected snapshot passed the existing guarded runner: nine exact native pose cases, 28 engine resident-restoration fixtures and all nine detailed UI signal cases. Total runner time 17.107 seconds; serial true Godot peak RSS 406872064 bytes, unchanged 1.5 GiB Job limit and 8 GiB available-RAM floor. A separately authored parent script passed 89 checks over all nine clips in 3.532 seconds, including normal progression, selection during playback, pause/resume, same-clip endpoint/restart and delayed no-chaining. These are actual headless engine/control-signal checks, not rendered layout or desktop pointer tests. The final source snapshot is `reports/top-simple-playback-50831/final-v2/pins.json`; full immutable results and parent adjudication are retained alongside it on the controller host.

Corrected runner evidence: `top/assets/official/top-cinematic-playback-50818/outputs/playback-26aaa769b5bd48a98b363e8731c17541`. Independent evidence: `outputs/parent-88d23821e54741c48d9bb7f2f9a9eac3`. JSON companion retains the original failure, historical receipts and current successful records. Documentation-only updates after testing do not alter the tested executable source hashes.

No desktop/window, game, audio, export, commit, merge, push or publication occurred. Original shader/material appearance, raster/layout, GPU deformation, exported-platform and all96 visual acceptance remain OPEN/false. The separate original-material-input provisioning blocker is unchanged.

---

# Preserved first-candidate documentation — historical, not current acceptance

Everything below is retained verbatim as evidence of the first failed snapshot and previous controls. Its BLOCKED state and unchanged25 claim are superseded by the parent correction above; its nested v3 receipts remain historical.

# Current owner correction: simple cinematic playback

Status: **BLOCKED runtime acceptance**, 2026-10-30. The inspector now exposes exactly Play and Pause, model/clip selectors and a read-only elapsed/duration label. There is no speed, reverse, Replay, Loop or seeking control. Playback uses the controller defaults, speed=1 and looping=false. Each selected clip is independent: initial selection and model/clip selection pause at t=0; selecting never autoplays. Pause/resume preserves position. End clamps at duration and pauses with the same selection; subsequent Play restarts that same clip at zero. No automatic next segment/model.

The lower-level reverse, seek, loop and replay APIs remain internal capabilities. source_animation.gd, cinematic_player.gd, original geometry/materials/animation data, numeric raw-pose tests and resident restoration tests are unchanged.

## Current validation and blocker

One development invocation was made, with process-local UTF8 settings and explicit Python UTF8 mode:

```powershell
$env:PYTHONUTF8='1'; $env:PYTHONIOENCODING='utf-8'
python -B -X utf8 tools/asset_lab/run_cinematic_playback.py --manifest top/assets/official/top-cinematic-playback-50818/inputs.json --manifest-sha256 92d785edb64684aae4c1a2341bcc51a4b349e4f314f31c920ec14cb962a868ca
```

Result: exit 1, `resident restoration: playing`. The numeric child completed in 1.064 seconds with no script errors. Before ownership the resident was playing `control` at 1.1125 with speed 1.125; after release it was paused with empty clip, position 0 and speed 0. Three model-110 raw pose cases completed before this original resident assertion failed. UI runtime tests were not reached. The staged SourceAnimation SHA is `d1977f75eb108b6eef4952aea334520c46becd6815a7da50e2acb393046de8f8`, the historical pre-fix baseline, not the corrected source described by the historical receipt. It is protected from editing in this task. Parent must resolve that staging discrepancy before independent validation. No retry or weakened assertion was used.

Evidence is retained under `top/assets/official/top-cinematic-playback-50818/outputs/playback-32fa9cb8ba5a41b4910b2c1d34cecd34`. Manifest/22 seeds/private/runtime pins passed start/end validation. The trusted guard retains the 1.5 GiB Job limit, 8 GiB free-RAM floor and serial <=90-second children; minimum observed free RAM was 32923070464 bytes. The POSIX work_guard is unavailable on Windows; the pinned Windows runner guard was used unchanged.

The new UI test emits actual button and selector signals and records per-case states for initial selection, playing model/clip selection, idle selection, 1x progression, pause/resume, endpoint, a second beyond-end advance, restart and subsequent progression. The runner requires all nine native cases and validates numeric positions, identities, pause states, speed and loop values, exact Play/Pause names and zero forbidden controls. A synthetic schema check accepted a complete fixture and rejected 30 malformed/incomplete/false variants; this is not engine evidence. The final runner includes a schema-only integer-identity tightening after the failed run and awaits independent validation.

Start hashes for all 30 staged files and current source hashes are in the JSON companion. All 25 protected files remain byte-identical. Only the inspector, UI test section, runner evidence gate and two playback docs changed. Historical receipts and failures below and in `historical_v3_receipt` are retained as historical, not current acceptance.

Shader fidelity, raster/layout, GPU deformation, all96 and exported-platform acceptance remain OPEN/false. No desktop, screenshot, media generation, full-project import, commit, push, deployment or export occurred.

---

# Historical v3 documentation (superseded product controls and receipts)

Everything below describes the previous inspector and previous evidence only. Its controls and PASS claims do not describe this correction or its staged source.

# Original-source cinematic playback inspector

Status: PASS for headless numeric playback and separate headless inspector construction and actual control-signal behavior only. Original shader, raster, exported-platform QA, visual material fidelity and all96 acceptance remain **OPEN / false**. No rendering was inspected.

## Launch

Use the pinned Godot 4.7.2 main executable with the TOP project and the explicit scene:

```powershell
& 'D:/Dev/OpenClawCodexBridge/tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe' --path top res://scenes/cinematic_inspector.tscn -- --manifest=D:/Dev/OpenClawCodexBridge/worktrees/top-cinematic-playback-50818/top/assets/official/top-cinematic-playback-50818/inputs.json
```

This is a launch instruction only; this task opened no window. Missing manifest displays help. The separate scene provides model/source clip selectors, play/pause/replay, signed speed, loop and absolute-time slider. Camera fits imported mesh bounds. Source identity does not establish final cinematic timing, and imported PBR is not the original shader. No audio, extraction, model regeneration or native resampling occurs.

## Controller contract

`configure(path)`, `load_model(model_id)`, `select_clip(clip.index)`, `seek(seconds)`, `play()`, `pause()`, `set_speed(value)`, `set_loop(value)`, `replay()`, `release()` are explicit APIs. Model IDs and clip.index values come from manifest pairs/native samples, never action-name guesses. Samples parse at model load and convert at selection; process ticks neither reparse JSON nor deep-copy frame data. Seek is absolute and clamped; zero speed holds position, negative speed reverses, non-looping endpoints pause, looping wraps. Release preserves the model; replacement frees it. Failed load/selection releases playback ownership while preserving the prior valid model scene.

Call release/clear **before** issuing any newer resident animation request, including the same clip. AnimationPlayer has no public generation ID for arbitrary same-clip requests. Explicit handoff is the supported contract, tested with a same-clip newer request and stale double-clear. Different assigned clips/reactivation are observable relinquishments, not a universal detector.

## Actual evidence

- Manifest SHA256: `92d785edb64684aae4c1a2341bcc51a4b349e4f314f31c920ec14cb962a868ca`.
- All 22 protected seeds, 125 private inputs and 12 runtime pins validated before runtime and at end; seeds unchanged.
- Four actual original GLBs, nine exact clip IDs, five first/mid/last/backward timestamp records each. Maximum independent raw-source versus Skeleton3D posed matrix error: `7.15255737304688e-07` (tolerance 0.0002), with transformed holder/model nodes.
- Playback forward/backward, zero speed, pause, reverse loop/replay, endpoint, clip/model replacement, failure release, stale clear, and final node lifecycle checks pass. Node counts: `{'after': 1, 'before': 1}`.
- 28 resident cases: playing, paused, stopped/no-current, disabled, reverse per-play custom speed, zero speed_scale, and explicit newer same-clip handoff on each rig. Actual AnimationPlayer.advance calls record pre/owned/post/advanced states, local track poses and released global override error.
- These are clearly labeled **engine-control fixtures**, not original-game resident animations; all four original rigs have no native resident AnimationPlayer.
- Separate headless scene parse/load/construct plus signal QA verifies all five actual button callbacks, decrement through zero into reverse, both loop toggle signals, all four model selectors, all nine clip selectors and all nine timeline signals. Switching from a long clip at its end to a shorter clip must stay at time zero, without slider-range clamping issuing an unintended seek. This is programmatic control-signal evidence, not pointer/keyboard, rendered layout or GPU deformation evidence.
- Final candidate runtime: `D:\Dev\OpenClawCodexBridge\worktrees\top-cinematic-playback-50818\top\assets\official\top-cinematic-playback-50818\outputs\playback-fa9d07843d074d129208095c741a0604`; total `16.892` seconds. Child durations: `[12.606, 3.839]`; peak RSS bytes: `[317964288, 317644800]`. Exact source hashes, argv/Job-memory/RAM-floor receipts and results are in the JSON companion. Runtime PASS alone is not parent acceptance; see the separate frozen parent-acceptance record. All96 remains OPEN.

## Defect and preserved failures

Baseline SourceAnimation SHA256: `d1977f75eb108b6eef4952aea334520c46becd6815a7da50e2acb393046de8f8`. The first actual fixture run demonstrated that pause cleared current_animation and release left a previously playing resident paused. The minimal fix disables evaluation without changing the resident playback cursor, custom speed, direction or playing/paused/stopped state, and associates restoration with an owner token. Exact changed lines are in the JSON companion. No accepted converter/parser/model files were changed.

`playback-49a29e6244ad49a380c449b448133092` retains the baseline defect. `playback-b27480f075b748f88d6e49b8dbb0a0b3` retains the UI parse failure/90-second timeout and stopped-position diagnostics. Resumption changed the malformed callback, added an internal test deadline, and removed pause/replay state reconstruction. No memory increase or restart was used to bypass a resource failure.

## Independent acceptance

```powershell
python -B tools/asset_lab/run_cinematic_playback.py --manifest top/assets/official/top-cinematic-playback-50818/inputs.json --manifest-sha256 92d785edb64684aae4c1a2341bcc51a4b349e4f314f31c920ec14cb962a868ca
```

The runner creates a unique ignored private project/evidence directory, lazy-imports only the pinned Windows guard after validation, uses serial real main Godot children, 1.5 GiB Job limit, 8 GiB available-RAM floor and <=90-second child deadlines within its 115-second child scheduling budget. It requires explicit PASS, exact nine case IDs, exactly 28 distinct (model, mode) resident cases, actual UI button/loop/selector/timeline evidence, error-free script logs and end-pin validation. UTF-8 result files are decoded explicitly, independent of the Windows locale. Failed children retain structured results and propagate nonzero exit. The old runner main/hardcoded validator and Linux fcntl guard are never invoked. Some earlier logs retain an environment root-certificate-store warning.

Raw original media remains ignored/private. No commit, push, merge, publish, deploy, install, desktop access or exported build occurred.


## Parent-discovered UI defects and correction

The original construction-only UI pass did not establish operability. Independent actual Button.pressed signals showed the displayed Unicode minus did not match an ASCII action branch. Model/clip selector signals also reproduced a second issue on all four models: updating a slider maximum clamped a previous long-clip position and emitted an unintended seek into the newly selected shorter clip. Both failures remain immutable under the parent evidence directory. The corrected action matches the displayed minus; clip selection suppresses timeline signals during its range/value synchronization.

The first expanded run also preserved a Windows cp950 JSON-decoding failure. Both engine children passed, but the outer runner remained BLOCKED; explicit UTF-8 decoding at that boundary fixes it without changing OS/global encoding settings. Original failed runs are not retroactively marked accepted.

Lesson: exercise actual connected controls, not only controller APIs or scene construction; range changes can emit user-facing value signals. Preserve the original counterexample, test both directions, and keep locale-sensitive result boundaries explicit.
