# Action 31567: source radial descriptor increment

Engineering increment only. P3-02 original visual acceptance remains OPEN; neither one complete unit nor all96 is accepted. No commit, publication, desktop use or Web export was performed.

## Trusted command

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
C:/Python314/python.exe -B tools/asset_lab/run_ring_action.py --manifest D:/Dev/OpenClawCodexBridge/probes/top-ring-effector-50976/inputs.json --manifest-sha256 8825b3041da9958d724bd686b95282b5e4a3a506e77170b11120b3fac04f3bb4
```

Each invocation keeps a unique directory under `top/assets/official/top-ring-effector-50976/outputs`: `project/project.godot`, `project/action-data.json`, `project/radial-oracle.json`, original private assets, `full-recompile.json`, `numeric.json`, logs, four child receipts and `summary.json`. The export-ready project preserves PNG raw sidecars and the JSON/PNG/source include filter. No export was run. Run from this isolated worktree with the pinned Python and Godot 4.7.2 main executable.

Initial evidence: `top/assets/official/top-ring-effector-50976/a08d8a3a-2523-4d31-977b-1ae3187916bc/initial-validation.json`. All 102 seed pins were verified, every checkout file proved LF-normalized equal, then atomically restored to exact seed bytes before coding. All 87 protected sources remain immutable. Every run rechecks seed, protected, 14 cache, raw/upstream, previous-handoff and executable pins. Current writable source hashes are captured before runtime and checked afterward. Transitive resources must be explicitly scoped writable with recorded hashes, or exactly seed-equal. The original cache is never overwritten or repinned.

## Source and callable runtime

Pinned VFXEditor commit `05f6eb0cce19a6a91ae275bce609299d573914b3` maps EfVT7 to RadialBlur and declares five scalar curves, two f32 distances and one i32 base-point enum. The actual 404-byte Data payload contains Len, Str, Gra, ORad, FSDc, FEDc and FaBP. IRad is absent; its default is unresolved. Len=0.15000000596046448, Gra=1, ORad=2, distances=50/75, FaBP=0. Strength keys are (0,0), (2,1), (6,1), (20,0). No radius/default/opacity is invented.

The compiler decodes by effector type, rejects malformed widths, duplicate fields and nonfinite values, and reports unknown/random/absent fields. Type9 camera decoding remains separate; other types remain unsupported. A private full recompilation is retained. The runtime pack preserves the previous pack and splices only independently raw-decoded `Efct0.data`, with source/payload/prior-pack provenance. Its exact SHA256 `1d167245034ae6e519c8e652aff91aedb4e45765ef7cff9b5d9e44195b15c8da` is hard-pinned in the action runtime, alongside the six unchanged textures.

`original_ring_action.gd` remains the callable preview/game module: configure, seek, seek_seconds, play, pause, release, report, and the new `radial_descriptors()` detached host snapshot. `asset_lab_effect.gd` evaluates the radial helper during its existing emitter traversal. TmLn0/item0 starts Emit1 at global15 and stops scheduling at32 inclusive. Descriptor ages are global age minus15; scope bits bAOV/bAGm and original node fields are retained. This is descriptor scheduling policy through the existing source player, not proof of native post-effect lifetime. Strength's final key at local20 lies beyond this scheduled interval. Direct curve tests cover it separately.

Seek/reverse/restart rebuild snapshots. Pause retains the current snapshot. Replacement, failure and release clear it. Two instances stay independent; consumers cannot mutate internal descriptor state through returned snapshots. Invalid/missing/random/unknown, nonfinite and f32-overflow descriptors fail closed. No shader TIME, guessed screen shader, radial convolution or opacity substitute was added. Preview remains paused0, Play/Pause only, normal1x, same-action restart, no loop/autonext.

## Evidence and limits

Validated reference run: `outputs/cca7bcc5-5ff0-4928-9480-fc4973673edf` beneath the private root above. Four serial guarded children completed in 3.89 seconds total: preparation, three ring unit tests, 92 AVFX regression tests (one skipped), and real headless Godot. Windows JobObject limits: 1.5 GiB, 8 GiB free-memory floor, <=90 seconds per child; runner <=180 seconds. Highest observed child RSS was ~204 MB. Script/parse/compile errors fail the gate even on exit0. Earlier import-path and descriptor-validation failures remain in their original UUID directories.

Engine evidence covers all181 half-unit forward and reverse samples through90, 180 nonempty particle samples, all nine source meshes (positions, colors, four UV pairs, triangle indices), live radial samples against independently unpacked raw keys, direct entry/peak/last/postend samples and reverse traversal, scope/presence, pause, sibling isolation, detached snapshots, stop, malformed descriptors, replacement/release and existing UI/asset failures. Final reruns print their own new UUID and source hashes.

The finite particle/emitter source-graph envelope ends at90. It excludes post-effects, native host release, trigger and loop unknowns. `asset_lab_lifetime.upper_bound` deliberately retains its conservative unsupported-effector result. The inspection window and conditional30 units/second conversion are not native completion/clock proof. Source geometry and textures, record placement, unsupported material/distortion/soft-particle/binder flags and PNG export fix are preserved.

Next seam: obtain exact native radial host projection/convolution/blending and absent-IRad default/serialization evidence, then implement and validate that host path against the original. Other original render-material/attachment gaps and actual Windows/Web visual gates remain OPEN. Descriptor correctness does not clear rendering_accepted, source_status or all96_accepted.
