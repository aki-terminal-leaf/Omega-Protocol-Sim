# Offline continuation checkpoint —2026-10-22

The request is to finish the previously documented remainder and complete AVFX
direct playback without AnAn. **That overall request is not complete.** This
checkpoint preserves reviewable progress and the exact remaining acceptance gates.

## Delivered development increments

| Commit | Result |
| --- | --- |
| `f4c33e2` | Bounded offline AVFX source-graph preview, compiler and original-data execution tests; not integrated into practice |
| `dd97e47` | Saved layout library, visual drag/rotation editor, validated rebindable marker keys, config/report integration |

Details: [AVFX_RUNTIME](../research/AVFX_RUNTIME.md) and
[MARKER_EDITOR](MARKER_EDITOR.md). Extracted source media and private logs were not
committed. The existing main/tag/release were not rewritten.

## Fresh acceptance, not inherited from the old release

- AVFX:55 Python tests and197 Godot checks pass. Eight retained original files
  render40 real OpenGL frames without engine errors. **Original visual fidelity
  is rejected**, not certified. Full material/binder/clip behavior is missing.
- Marker/editor:35 new integration checks,71 marker regressions,27 presentation,
  19 input-routing,17 existing P3 effects checks; real OpenGL GUI9 checks/0.
  Pixel inspection caught/fixed a first-open window-size bug. All settings tests
  used isolated data folders.
- Clean-source isolated Web and Linux exports completed on locked4.7.2. Tracked
  import inputs were unchanged. The candidate runtime source is `dd97e47`.
- The **actual Linux export** ran the P6 Meteors course to30.5 simulation seconds,
  zero failures, and wrote the new marker-key settings into its report.
- **Web acceptance is not passed.** Python Playwright hangs during navigation /
  close on this VPS. Direct headless-shell CDP reaches Godot/WebGL2 but stalls
  before the real engine startup promise resolves. Native Mesa was also checked.
  The **unchanged published v0.3.3 Web PCK** reproduces the same startup stall in
  the same environment; its SHA256 is
  `1be6dea59acbb909243d85f3de4d8d138b2c8eee76dc45b71761c0ce1e423288`.
  This supports an environment/pre-existing path diagnosis, not a new-build pass
  or a proof that no regression exists. A premature blank-page readiness probe
  was rejected after pixel review; no blank screenshot counts as acceptance.
- No new Windows runtime acceptance is available while AnAn is offline.

## Still required

1. Full original AVFX shader/layer/UV/depth/billboard/effectors, binder sockets,
   trigger/stop/fade/reset behavior and original temporal/pixel comparison.
   The preserved selected assets do not contain the complete original runtime /
   shader corpus; an accessible full installation/backup/reference is needed.
2. Strategy-sourced manual/assist/none marking and bots reacting to actual marks;
   no guessed regional presets or hidden-answer assistance were added.
3. The remaining per-mechanic original spawn/contact/simultaneity/timing policies,
   regional temporal coverage, HP/jobs/death/revival/natural-LB/falloff items in
   [FIDELITY](../research/FIDELITY.md), using verifiable gameplay evidence.
4. Fresh accepted Web and Windows exports, then publication and README showcase.

No new release is published from this checkpoint. The previously shipped
v0.3.3 remains unchanged. Passing source checks or exporting a binary does not
remove any of the failed/missing gates above.

## Next planning checkpoint —2026-10-22

[Offline independence plan](OFFLINE_INDEPENDENCE_PLAN.md) separates material
acquisition, portable toolchains, independent development and reference/platform
validation. It records required sources, AnAn alternatives, phased acceptance and
capacity estimates; it does not claim that the missing backup or runtime exists.
