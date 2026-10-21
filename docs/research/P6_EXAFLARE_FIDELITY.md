# P6 Exaflare: current implementation versus old training fixtures

The immutable v0.3 release already contains `P6Patterns.exaflares` and
`P6Courses.append_exaflares` through `Encounter.build`. It does **not** use the
old four-cardinal `Encounters.exaflare_streams` fixture. No hazard, route,
movement budget or scheduled event is changed by this audit.

## What is supported

Four complete source captures (`1bX86aKrVRwLWfTC/19`, `3GW2hjTNk91FZwcK/9`,
`LKMGRJTzgY9HFynk/2`, `Vyq4AcJKZjkFQBpG/32`) contain eight first-explosion
groups:32 sources, radius24, four adjacent45-degree origins. Anonymous origins,
angles and first offsets are in [fflogs_observations.json](../../top/data/fflogs_observations.json).
All underlying replay segment hashes were rechecked in this audit. Their24
consecutive source-stagger intervals span0.936–1.030s (median1.024s), supporting
**nominal1s**, not identical server frames.

The production generator exercises8 start indices ×2 directions =16 finite
variants. This is a symmetry/stress matrix derived from the observed geometry;
eight observed groups do not prove every server RNG outcome or all16 variants
were independently observed. Each line has seven radius8 explosions, advances8
units, starts at normalizedT12/13/14/15, then uses+1.11 for its first advance and
+1.00 for later advances. The previous1614-assertion4.7.2 gate includes those
families at ordinary6-unit movement and JSON checkpoint replay. No new passing
run is claimed for this metadata-only correction.

## Do not infer tighter repeat timing from stale helper samples

A separate independent, position-only matcher re-read all four captures,
without choosing matches by desired timestamps. It deliberately excluded shared
center positions. Of160 expected noncenter followup positions,90 had one match,
21 had multiple matches and49 were missing. Even unique-position matching
produced impossible ordering (repeat deltas as low as−1.027s) and first-advance
outliers to3.130s: sourceResources can be stale and helper instances are reused.
Those results **reject this method as a new repeat-timing calibration**. They are
not filtered into a misleading tight confidence interval. No live deadline,
collision radius, exact tick or repeat interval was changed to fit them.
A reliable per-hit position/identity source or independently timestamped original
recording is still required for stronger timing claims.

## Parameter registry distinction

`exaflare_origin_radius=24` and `arrow_side_start=15` are finite observed geometry,
not unknown values. `exaflare_stream_stagger=1` is a nominal observed interval.
`exaflare_interval=1.1` and `exaflare_first_delay=2` remain the legacy generic
fixture API's values, now explicitly labeled as such; they do not describe the
production P6 scheduler. All numeric values are preserved. Current actual
scheduler events, not the old fixture parameters, remain in exported P6 state.

Full RNG coverage, complete regional temporal routes and exact server timing
remain unresolved. This corrects stale documentation; it does not claim all
original spawn rules are complete. See [P6](P6_FIDELITY.md), [current strategies](STRATEGIES.md)
and [overall limits](FIDELITY.md).
