# Shared action foundation

VISUAL ONLY, Godot 4.7.2. This is a source/control foundation, not a finished GIF showcase. No full-fight wiring, target selection, damage logic or visual acceptance.

`ActionModule` is a Node3D. `configure({backend: "clip", manifest: ABS})` or `configure({backend: "unit", source_root: ABS, camera: Camera3D})` creates an independent existing backend. Unit selections default to `res://data/asset_lab/performances.json`. `select("clip:110:0")` and `select("unit:P1-01")` are separate namespaces. Configure/select/reset pause at zero. `seek(seconds)`, `advance(delta)`, `play()`, `pause()`, `reset()`, `dispose()` and `report()` provide the common interface. Times must be finite/nonnegative; seek clamps at end. Pause preserves time; end pauses; explicit play at end restarts the same selection. There is no loop or automatic next selection.

Results contain `ok` for the last control operation, `selected`, `playing`, `seconds`, `duration`, `identity`, `source_sampling_supported`, `error`, and `source`. A valid unit clock does NOT imply source sampling support. `source` preserves the exact Unit report, including diagnostics. `accepted` is always false. Failed configure/select hides prior content and clears selection. Invalid times preserve the valid playhead. `set_target_context` explicitly returns NOT_IMPLEMENTED.

The facade has no autonomous process. The cinematic backend process is disabled. Preview supplies delta; timeline supplies absolute time. Do not drive both at once. Caller Transform3D placement moves the entire local/record-space presentation; recorded source transforms are never rewritten. Review windows are not proven host spawn/stop or complete choreography.

Launch with the pinned real Godot executable:

```text
Godot_v4.7.2-stable_win64.exe --path top res://scenes/action_preview.tscn -- --backend=clip --manifest=ABS
Godot_v4.7.2-stable_win64.exe --path top res://scenes/action_preview.tscn -- --backend=unit --source-root=ABS
```

Preview exposes only selector, Play, Pause and read-only status. Missing data does not produce a fallback animation. Unit camera follows the legacy recorded-unit convention; clip camera fits source mesh bounds.

```gdscript
var timeline = preload("res://scripts/action_timeline.gd").new()
add_child(timeline)
timeline.add_instance("actor", {"backend":"clip", "manifest":path}, "clip:110:0", 2.0, Transform3D.IDENTITY)
timeline.seek(2.5) # local 0.5, paused; before 2.0 hidden at local zero
timeline.seek(1.0) # deterministic rewind
timeline.dispose()
```

The example is limited to eight named instances. No internal process or target binding exists.

Validation command:

```text
python -B tools/asset_lab/run_action_modules.py --manifest ABS --manifest-sha256 92d785edb64684aae4c1a2341bcc51a4b349e4f314f31c920ec14cb962a868ca --source-root ABS
python -B -m unittest discover -s tests -p test_action_modules.py
```

The runner reuses the accepted playback manifest validator and lazily imports the pinned Windows Job guard. It uses a small isolated project, unique ignored outputs, serial child limit 90 seconds, total budget 120 seconds, 1.5 GiB Job limit and 8 GiB free-memory floor. No conversion or PAP resampling. Before/after hashes and receipts are in each run summary. Tests exercise all nine source clips and P1-01 at 0.1/1.0 seconds; the registry lists all 96 exact source selection records. Numeric checks do not establish raster/shader fidelity, source stop semantics, exports, all96 performance or full-fight acceptance. Independent bridge and desktop review remain outside this run.

## Original development result (preserved failure; superseded below)

The development invocation returned nonzero before launching Godot: the immutable seed fails the accepted manifest validator. Nine seed pins differ, including the Job guard and cinematic adapter. Exact expected/observed hashes are recorded in `action-modules.json`. No existing file was repaired or normalized and no pin was weakened. The preserved receipt is `top/assets/official/top-action-modules-50853/outputs/run-c69e88df2ffe464288fb06bbc859bc7e/summary.json`. Its original `pins_unchanged` field was incorrectly true on preflight failure; this is a runner reporting bug corrected in source after that receipt, and does NOT establish validated pins. The receipt is preserved unchanged.

Actual Godot assertions, poses, UI signals and source subset observed: NONE. The authored tests remain unexecuted and GDScript parser/runtime behavior is unverified. Python negative validator/registry checks passed (3 tests). The independent bridge test was not attempted because the pinned local preflight failed. Parent review must reconcile the immutable seed with the accepted pins before source validation. This stage is an unvalidated implementation, not an accepted milestone.

`python3 tools/work_guard.py begin action-modules-foundation` could not run because python3 is unavailable; that guard also imports POSIX-only fcntl. No existing guard was modified. No desktop, network, export, commit, push or release action occurred.


## Parent recovery and current numeric foundation result

The original bridge task remains `failed`; it is not rewritten as success. Parent diagnosis proved all 13 raw-byte differences among the 30 protected sources were **only CRLF/LF checkout normalization** (`eol=lf`), not content edits. Exact original pinned bytes were restored atomically in this isolated worktree, preserving the initial failure snapshot. All 30 protected files now match their original raw SHA. No manifest/hash was weakened and no global/repository Git configuration was changed. New checkouts must similarly preserve/restore the original pinned bytes before using that private manifest; a normalized Git blob alone is not the raw-byte pin.

The initially supplied `top-lab-visual-cache-50685-v1` was not the cache generation pinned by `performances.json`: full-data/manifest hashes differed. The existing read-only `top-lab-cache-50685-v2` matches all six source files and the attachment pin exactly. Existing performance definitions/statuses and both caches remain unchanged.

The isolated test project originally missed `extends` dependencies (the AVFX base player and shader). The runner now stages transitive literal `res://` resources, including inherited scripts, shaders and the preview scene, and merges already-staged data directories. It pins those resources before/after, still using the same accepted guard. A regression verifies inherited shader inclusion and missing-resource rejection. Clip sampling failure now stops and hides the facade, clears selection, and refuses Play until a valid reselection. Failed end-restart sampling cannot report successful Play; these failures are exercised with an actual released source binding.

Current parent run: `top/assets/official/top-action-modules-50853/outputs/run-04fee53f0740458c833f97f522135958/summary.json`, `NUMERIC_PASS`, real Godot 4.7.2, 12.787 seconds total. Guarded engine peak RSS 1,230,401,536 bytes; job-private peak 1,199,628,288 bytes, within unchanged 1.5 GiB Job limit; minimum free RAM 32,039,612,416 bytes, above the 8 GiB floor. No script/parse errors or guard stop. All nine exact clip identities / 27 nonzero original-time pose comparisons match independent facade instances driven through standalone and external clocks; Play/Pause/reset/end/restart, invalid times, before-start/rewind, distinct simultaneous models, missing selections, source-failure closure and nine actual UI signal cases pass. P1-01 at 0.1/1.0 seconds preserves direct backend diagnostics and actual transform/bone data. All 96 exact original selection rows are mapped, **not performed/accepted**. Four Python evidence/resource regression tests pass. Full SHA/receipt fields are in `action-modules.json`.

Focused cross-family review of the exact final facade/timeline/runner returned `NO_MUST_FIX` (Claude Sonnet 5.5, existing claude.ai subscription, tool-free); its source SHA was frozen before the call. The first broad text review timed out without a verdict, not a pass. Optional stronger evidence serialization/canonical-ID checks remain improvements, not acceptance of any untested subset. Unit duration/error fields exist; source/runtime checks independently verified the unit failure path, supported=false diagnostics, disabled clip autonomous processing and distinct instances. Raster/material/shader, complete GIF-like visual performances, exported-platform QA, target binding and full-fight integration remain OPEN. No desktop, audio, public package/release or repository push occurred during this recovery.
