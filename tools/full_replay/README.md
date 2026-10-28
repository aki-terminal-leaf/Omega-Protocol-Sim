# Fixed-record full-battle replay preview

This separate Three.js viewer complements the Godot practice app. It does not auto-sequence practice mechanisms, change gameplay verdicts, or replace Web35. The v0.1 preview plays one full event record, excludes the forced P6 cinematic, and remains **visually incomplete**.

## Build

Node.js, npm, exact Three.js0.180.0 and esbuild0.25.11. In this directory: `npm install`, then `npm run build -- --data /path/to/private/offline-cache --out /path/to/new-output`. The output must not already exist. Supply legally held original-model/effect/audio assets and generated `manifest.js`, `record.js`, `weapon-data.js`, `full-data.js`, `assets/`; these media and raw record/cache files are deliberately not in Git. A newly built output is explicitly NOT runtime-validated merely because its input was previously accepted. Run actual browser gates before publishing it.

`compile_resources.py FRESH_PRIVATE_WORKSPACE` uses the existing project AVFX tooling. Put extracted `bundle/raw/` and `bundle/manifest.json` in that workspace. It preserves unsupported features and source hashes, parses source binder/polyline fields and C012/C063 nodes, and does not certify renderer/host equivalence. The compiler refuses to overwrite prior accepted output. Optional SCD decoding uses maintained vgmstream r2168; C063 SoundIndex is zero-based, `vgmstream -s` is one-based. Never play the first stream of a multi-stream bank as a substitute.

## Data/lifecycle contracts

- `TOP_RECORD`: original millisecond event clock and sampled tracks, no global cross-fight video retiming.
- `TOP_MANIFEST`: explicit hashed gzip-encoded cache assets, model bindings/animation metadata and scene placements.
- `TOP_FULL`: per-phase asset lists, C012 cue nodes, status-backed tether events, observed resident-body windows and exact SoundIndex audio cues. Cue arrays must be time-sorted and keys unique.
- Audio is opt-in. Its flat gain/mixing is a reconstruction; BGM/listening fidelity is not certified. Native pause/seek/rate and persisted-page return are independently tested.
- C0126–30s preview envelopes are not original host stop semantics. Tether removal is only inferred where a recorded status/type transition supports it. Unknowns remain missing, not arbitrary defaults.
- Polyline ribbons use source widths/colours/textures but approximate billboard/spline/UV host behaviour. IMC-hidden meteor meshes stay hidden; source resident AVFX is shown only within observed activity windows, not asserted spawn/despawn.
- Unimplemented source particles/materials/effectors remain diagnostics. All renderer and gameplay-equivalence flags remain false.

See [scope and verification](../../docs/development/FULL_REPLAY_PREVIEW.md) and the90in-scope/6excluded unit index. Existing full20/102strategy, optimization and AVFX roadmap work remains open.
