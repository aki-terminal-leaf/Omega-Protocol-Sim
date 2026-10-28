# TOP Unity native reconstruction

Unity6000.4.10f1 Windows project; first full playerless reconstruction, **then** practice simulator migration (owner2026-10-28 Telegram50455). The existing Godot/Web practice release and Three.js preview remain unchanged. This project is not a complete recreation yet.

## Dependencies and private assets

Pinned maintained official Unity glTFast6.20.0 and Newtonsoft3.2.1. No copied editor caches, native SDK changes or bespoke model importer. Run `python3 tools/unity/prepare_data.py --data PRIVATE_REPLAY_CACHE --out NEW_NATIVE_DATA`, then `node tools/unity/plan-motion.mjs NEW_NATIVE_DATA`. The converter verifies every asset hash/size and converts WebP images to PNG while retaining original geometry/animation buffers. Exact duplicate float32 endpoint times are collapsed only after proving the corresponding output values identical. Media, raw logs and generated native data stay out of Git.

Build: `Unity.exe -batchmode -force-d3d11 -projectPath UNITY_PROJECT -logFile UNIQUE_LOG -executeMethod BuildEntry.BuildAndExit --build-output=FRESH_BUILD/TOPReplay.exe`. Initial package import must complete before build; the method exits explicitly, so no startup `-quit` is required. Actual Unity Personal license must be valid. No license/account/billing bypass.

Run: `TOPReplay.exe --top-data=PRIVATE_NATIVE_DATA`. Default data location is `TOPData` beside the executable. Right-drag orbit, wheel zoom, Space pause, arrows+/-5s; phase/seek/rate controls remain interactive. QA: add `--qa=FRESH_EVIDENCE_DIRECTORY`; this produces native camera renders and state JSON but **not** an automatic fidelity PASS. Inspect pixels and bind the exact source/data/build hashes.

## Lossless source-export images

For a native snapshot, run `python3 tools/unity/restore_source_images.py --data PRIVATE_NATIVE_DATA --sources PRIVATE_PINNED_MAPPING.json --out FRESH_NATIVE_DATA`. Each mapping value supplies `path` and exact `sha256` for an original PNG-containing GLB. The tool matches the original model hash, image names/order, texture routing and material identity, appends unchanged source PNG bytes, then proves every image hash and the entire original native binary prefix. Geometry, materials, skins, nodes, strict animation accessors and clips are unchanged. The reviewed optical exception permits its existing primary-diffuse material-binding correction while additionally proving all original static geometry accessors.

The source-image restoration report is authoritative for replaced native GLBs; the older conversion proof remains upstream provenance. Restoring an earlier exporter image does not certify original TEX sizes or original game shader fidelity. Source mapping/private files never enter Git.

## Foundation contracts

- Original record milliseconds; reference video is a different fight. No global retiming. Exclude only explicit forced-cinematic intervals.
- Eight invisible player target tracks remain available; no player visual roots, party HUD, player skill/LB effects.
- Immutable actor identities and persistent appearance timelines; original P2 simulation/return PAP clips, shield stop and corroborated cast cancellation. Cast-start/paired-loop metadata is read by source key, never guessed by sequential IDs.
- GLTFast mirrors X, so record positions and all nested scene matrices use the same X reflection. Original action PAP tracks contain **model-space** matrices; resident idle/cast-loop clips remain hierarchy-local. `TopAnimationData` directly samples original LINEAR/STEP channels and quaternion SLERP; stock Unity legacy curves drifted on real leg/hair cases. Bone bind hierarchy/channels are restored before each absolute sample, then model-space action joints are independently flattened for rendering (including zero-scale hidden tails).
- Original material textures/alpha retained; materials are still glTF PBR approximations, not original game shader execution. Unsupported lightshaft/fog fallback meshes must not become opaque white geometry.
- Native camera rendering, original animation/part visibility, all six phases, reverse seeks, pause/play and source effect lifetimes require independent gates. No practice migration until full reconstruction acceptance.

## Still open

Complete original AVFX/C012/host-stop/attachments/materials, tower/line lifecycles, background activation/animation/environment/lighting, per-phase BGM and auditory comparison, all90in-scope reference-video units, and native performance/input/export acceptance. Existing20mechanic/102strategy guide/outcome/NPC roadmap remains a separate preserved backlog. A scoped native actor pass is not all-unit restoration.

## Verified foundation scope

Actual Windows/RX7900XT source-channel build,24seeks and all-six-phase64xcontinuous playback/pause/excludedcinematic checks; immutable full build/data hashes. Seven independent Three.js-vs-native complete-pose cases cover698joints (P2shield/cast/clones, P5weapons/legbody2/rearunit andP6Alpha), maximum matrix error<0.000004. The original failed Unity-curve case (legerror0.156) is retained.104models/41380animation samplers are strictly increasing, with original binary prefix unchanged.1221real-source curve/random/axis/color/life math cases pass the native editor. These prove only this source pipeline, NOT full reconstruction or film/game equivalence. Full original effects/audio/environment/video-unit acceptance remains OPEN; no practice migration has begun.

On the private AnAn working project, `TOPData` is an ignored directory junction to the verified private data snapshot so Editor Play can use the same default lookup. It is never placed in Assets or source archives.
