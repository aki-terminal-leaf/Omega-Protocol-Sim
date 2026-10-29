# Static SCENE visual lifecycle

Base: `c090fc1e89ad32b6fe5e300d72ac6dce6ab6737d`. Scope: visual-only changes to the existing Composite.

`report.phase` follows the absolute seek clock. A separate scene phase identifies the retained geometry. A disabled seek hides the scene root, including floors; re-enabling restores the matching cached root or frees it and constructs the requested phase. Successful same-phase seeks reuse instances. Reverse seeks select the same static phase rows deterministically. Dispose and configure invalidate scene identity and diagnostic caches.

Scene diagnostics are retained with the scene build and re-emitted after each enabled seek clears tick diagnostics. Diagnostics raised while loading a successful scene prototype are also retained across phase rebuilds. A failed phase cannot leave the previous phase's geometry visible or become a successful seek merely because it is cached. Failed builds remain cached until phase change or reconfiguration; no automatic per-tick reload is introduced. Disabled scenes do not contribute scene diagnostics until re-enabled.

Matrices require exactly 16 finite numeric components, affine last row `(0, 0, 0, 1)`, and a finite resulting engine transform. Invalid rows produce `invalid_source_scene_matrix/<key>` before instantiation. Valid rows of a partially invalid phase may still be displayed, but the seek remains failed. Existing `nodes` plus `floor_nodes` selection and the P2 `p1_boss` filter are preserved.

## Public regression and verification

`tools/asset_lab/test_scene_lifecycle.gd` uses actual PackedScene/BoxMesh geometry in the SceneTree and `is_visible_in_tree()`. It covers cross-phase and same-phase disable/re-enable, reverse seeks, instance reuse, repeated failed-load diagnostics, malformed/nonfinite/overflow matrices, floors, P2 filtering, disposal and real configure calls using in-memory JSON fixtures. It contains no original game media and has finite loops.

Runtime gate: the supplied independent `scene-50738-acceptance.py` runner stages this worktree and runs the frozen parent and public tests with Windows Godot 4.7.2 headless, dedicated 1.5 GiB job limit, 8 GiB free-memory floor, and 40s import / 30s test limits. Do not substitute direct Godot execution. Historical model-authoring status was **NOT_RUN**: this sandbox session exposes no bridge execution tool and cannot write the runner's external probes directory. The local POSIX work_guard is unavailable on this Windows environment (`python3` absent; script requires `fcntl`). That authoring-time note is superseded only by the parent results below; the original bridge/tool-failure evidence is retained privately.

Local source check on 2026-10-29: `git diff --check` **PASS**. Working-tree changes are limited to the three authorized paths. This is not parser, runtime or visual acceptance; the independent runtime gate was subsequently collected and accepted by the parent as recorded below.

Native SGB/tower activation, cinematic candidates, CoUF, original shaders, host stop semantics, original/raster fidelity and full96 acceptance remain **UNKNOWN/OPEN**. No `IsVisible` interpretation or new native state rule is introduced. No desktop, export, release or deployment is part of this stage. The accepted source-only increment is published to develop; existing main/site/downloads remain unchanged.

## Parent acceptance — 2026-10-29

- Clean `c090fc1` Windows headless baseline reproduced six failures in the frozen 12-check parent geometry/diagnostic test. The unchanged test passes all 12 checks on runtime SHA-256 `130fe7b4a4698df4128d7ac003c3c0bef58e3c04d867958f31ee48d19a7a9d35`.
- Public synthetic scene test: **86 checks PASS**, using actual visible BoxMesh instances, not just state flags. Independent frozen Sonnet 5.5 static review: **NO_MUST_FIX** for the exact runtime/public-scene-test snapshot.
- Original private `scene-data.json` and manifest plus 66 GLB files were SHA-pinned. Six phases, forward/reverse and disable/re-enable, passed **14,813 numerical checks** of selected node counts, matrices, nonempty visible geometry, instance reuse and repeated shader diagnostics. Phase selection uses a synthetic test clock; this is **not** proof of original activation times, SGB/tower state, native shaders or raster fidelity. Source phase graph hashes: `91196d89748bbbefbf32c6ba644cff3d536de95dc97b2793c66590eba8ee8716` (scene-data) and `8cac7036e5cc38f671dd6637183f0648f5fcd645f2b1810078cd82a60e1dc90c` (manifest). Original-media inputs remain private.
- Actual original-scene process: 2.26s, peak engine RSS about 542 MiB; whole-job hard limit 1.5 GiB and 8 GiB free-RAM floor retained. Import is measured separately. All accepted runtime logs contain no script/parse/compile errors.
- Existing lifetime regression initially failed `default_binder_pose_missing` identically on clean `c090fc1` and this candidate. Its positive synthetic binder omitted required `GenD`, `bRng` and `Pos`; no renderer defect was found. The fixture now supplies explicit zero/empty offset fields, adds six missing-field/diagnostic rejection checks and retains/enlarges CoUF rejection cases. The runtime binder gate is unchanged. Static fixture semantic review found no must-fix; a subsequent explicit `String` annotation corrected an actual GDScript type-inference parse failure. Final fixture SHA-256 `1d247dfa7560da5d96f56ec1872ce9fa8b13113cf7064ad699dc91abfcf014e6` passes all **17 lifetime vectors plus controller checks**. Both initial regression and intermediate parse-failure logs are retained, not relabeled PASS.

Self-contained public scene regression (fresh staging directory, Godot 4.7.2):

```sh
python3 tools/asset_lab/stage.py --out NEW_PROJECT
godot --headless --path NEW_PROJECT --editor --import --quit
godot --headless --path NEW_PROJECT --script REPO/tools/asset_lab/test_scene_lifecycle.gd
```

The private original-asset acceptance additionally used the bounded Windows parent runner; the public command does not ship original assets or reproduce its original-source assertions. No new screenshot, video, downloadable lab build, released Web build or all96 acceptance is claimed.
