# Godot / GDScript upgrade plan

Status: **migration gates passed; pinned4.7.2 baseline** (2026-10-21). Current executable/project baseline
is Godot4.7.2-stable, GL Compatibility. GDScript ships with the Godot executable; there
is no separate GDScript package to upgrade.

## Pinned target and evidence

Target **Godot 4.7.2-stable**, not a nightly/RC. The official GitHub latest-release
response was checked on 2026-10-21: published 2026-08-18T16:12:28Z,
`draft=false`, `prerelease=false`.

- [Official release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)
- [Official release API](https://api.github.com/repos/godotengine/godot/releases/latest)
- [Versioned GDScript reference](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html)
- [Versioned migration guidance](https://docs.godotengine.org/en/4.7/tutorials/migrating/index.html)

Pin executable and export templates to the **same patch version**. Release asset
SHA-256 digests, from the official release response:

| Artifact | SHA-256 |
| --- | --- |
| Linux x86_64 zip | `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4` |
| Windows win64 zip | `731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953` |
| Export templates | `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` |

The release response is evidence for the target, not proof of project
compatibility. Verify downloaded bytes before running anything. Do not change
`project.godot` feature metadata simply to make the upgrade appear complete.

## Separate bounded stages / commits

1. **Baseline seal** — finish current validated segment commits; save failing
   examples and baseline reports. Existing submitted P3/P4 work is reviewed as
   4.4-compatible work, not an excuse to delay the migration indefinitely.
2. **Isolated compatibility spike** — separate branch/worktree, separate import
   cache/user data. Install verified 4.7.2 executable and read 4.4→4.5→4.6→4.7
   migration notes. Run import/parser and representative Loop, HW, P5 and P6
   regression checks. Fix breakage in small commits; keep 4.4.1 rollback usable.
3. **Assets/render compatibility** — reimport the original skeletons, animation,
   materials/emission/normal maps and private status icons. Check GL Compatibility
   and texture-memory limits. Inspect actual pixels and frame behavior, not only
   a headless pass. Do not carry a 4.7 cache back into 4.4.
4. **Export/runtime gate** — install matching templates; export Windows and Web.
   Check real keyboard/mouse, resizing, original assets, shader/material behavior,
   browser startup, memory, time-step/contact determinism and JSON/retry restore.
   Compare the same seeds with the baseline; no unexplained judgment changes.
5. **Version lock commit** — only after gates pass, update project feature
   version, AGENTS baseline, README, build/validation paths and reproducible engine/template pins.
   Record export hashes and tested OS/browser. The fallback is the last 4.4.1
   commit; do not erase it or call a development build a release.
6. **Develop on verified supported capabilities** — use the capability register
   below for each new API/language feature. Prefer targeted adoption that helps
   actual simulator work; do not mass-rewrite scripts just because syntax exists.

Each stage obeys the 25-minute watchdog and creates its own checkpoint/commit.
A failed gate leaves the migration pending, with its reproducer recorded.

## Capability register (must be filled by migration evidence)

| Area | Adoption rule | Current state |
| --- | --- | --- |
| Typed arrays/dictionaries, script API typing | Exact pinned-version docs + parser/serialization regression; preserve JSON-native durable state | Existing used typed subset verified by4.7.2 parser/runtime; unused newer syntax still needs a probe |
| Abstract classes / other newer GDScript syntax | Verify exact syntax and semantic support in versioned docs and a tiny executable probe before use | Candidate, not adopted |
| SceneTree/Node/Resource/input API | API exists in pinned reference and representative Windows/Web runtime check passes | Used API set passes actual Windows physical input and Web UI/input/JSON gates |
| Rendering/materials/animation | GL Compatibility + real original-asset pixel validation on both export targets | Twelve original models/seven players pass import+motion; actual Windows/Web pixels inspected |
| Web threading/extensions/platform features | Explicit official Web support and export test; no desktop-only dependency in shared flow | Non-threaded Web explicitly verified with matching templates; extensions/nightly-only APIs not adopted |
| Test runner/report/retry state | Error-sensitive headless runner, actual courses, JSON round-trip and failed-seed retention | 4.7.2 error-sensitive suites and86 Main methods pass; state-specific restore scope remains explicit |

A feature's presence in an unversioned `latest` document is insufficient. If the
pinned target does not support a desired feature, select a documented supported
alternative or create a separately reviewed future upgrade stage.

## Parallel product backlog (not silently marked done)

P3 transition and P4 Wave Cannon are collected/reviewed and production-wired
(commits4e160e6/e9a6b9a). P6 actual request/target controls and public-reference
post-cast locks are wired(e731cc6); ranged edge geometry remains unverified.
Original VFX reconstruction, remaining route/source gaps, full five-profile
coverage for the remaining legacy entries, remaining ranged-control release QA are not complete.
The isolated engine migration itself has now passed its gates. The target release API was
rechecked successfully during this follow-up; no4.7.2 download/import/export or
baseline switch has been performed.

## Isolated migration checkpoint — 2026-10-21

Official Linux4.7.2 executable and matching template archive bytes match the
SHA-256 digests above. A separate Git worktree/import cache reimported the
private original models, skin/animations and both bundled fonts without script
errors. The old4.4.1 checkout/cache remains untouched.

Reviewed4.4→4.5→4.6→4.7 versioned migration notes. Input dispatch checks event
types, not the changed keyboard/mouse device IDs. Existing rig loaders use
explicit skeleton paths; font hinting remains explicitly1 rather than inheriting
the newer default. Importer-added `modulate_color_glyphs=false` is retained.
No AnimationTree blend-space sync or removed JSONRPC/RenderingServer APIs are
used by the TOP project. Runtime/model/platform gates still decide compatibility.

Packaging now queries the actual stable executable instead of hardcoding4.4.1;
it rejects zero-exit script/export errors, dirty release trees, mismatched
engine locks and stale/mismatched `--skip-export` artifacts. Per-platform
BUILD_INFO stores binary digests; source archives enumerate tracked files only.
Four focused packaging tests cover real-version provenance, prerelease refusal,
zero-exit script errors and missing/nonzero exports. This tooling checkpoint
is not a completed migration or a published release.

Targeted4.7.2 gates passed: Rules196, Contacts21, Stateful72, Review211,
P1 events1266, HW quick2002, Limitless quick92, P3 quick2268, P4 quick279,
P6 movement1614, P6 LB602 (production locks), P6 controls20; all zero failures.
P5 continuous15 courses and12 original models/7 equipped players also pass.
The initial P1 `--quick` attempt did not narrow that suite and exceeded its
150-second per-test budget; it was stopped, retained as incomplete, and replaced
with the supported `--events-only` gate. Existing passing gates were not repeated.
Full Main/Loop/Windows/Web acceptance is still pending at this checkpoint.

## Platform checkpoint (before final version lock)

Clean sourcefb7fab6 exported using the matching official4.7.2 templates. Web
requires **web_nothreads_debug.zip and web_nothreads_release.zip** for the
existing thread_support=false preset; web_release.zip alone is insufficient.
Native Windows (RX7900XT/OpenGL3.3) physical-key movement, relative mouse, zoom,
jump and same-seed retry passed. This used supported CLI preselection, not a
claimed native manual-menu pass. Actual tank/caster F begin+finish and blocked
D/sprint/Space during real post-cast locks also passed; owned windows were closed.
All20/86 Main methods passed on4.7.2; original-model tests12+7 passed and actual
Windows/Web font/model pixels were inspected. Linux exported startup passed.
Web's actual menu/start/move/pause/orbit/zoom/jump/retry/JSON/new-selection
assertions passed, but its final console check found one /favicon.ico404.
An explicit empty data-URL favicon removes that unrelated request; the portable
smoke script also fixes the inspected menu-row coordinate and Windows UTF-8
report decoding. Final console-clean Web acceptance follows this correction.
Native ranged-target UI and a new published release are not claimed.

## Version lock — completed2026-10-21

`top/data/engine_lock.json`, project feature4.7 and the project execution contract
now pin4.7.2. Clean native sourcefb7fab6 and clean Web source1e0a3cb6 ran the
same compiled gameplay PCK SHA-256
`c685ce1dcab84d1d2618e8f742c753c6c7df9caf1555b4a9532109a164b35806`.
The latter adds only the verified favicon head/portable QA correction; final
Chrome155.0.8059.80 menu→strategy/start/D/pause/orbit/wheel/Space/retry/JSON and
new-selection-clears-state gate passes with zero browser errors. Native
RX7900XT/OpenGL3.3 also passes physical F/caster4.5s+8.1s postlock and tank
postlock checks, and actual1280×800→1440×900 resizing with M/F model pixels.
Linux exported executable startup passes. Native manual-popup selection and
ranged-target UI are not claimed by the CLI-preselected native gate.

No arbitrary abstract-class or other new-syntax rewrite was introduced. Existing
used APIs are verified on the pinned engine; a future newer feature still needs
its own versioned-reference/runtime proof. GDScript upgrades with this engine.
The4.4.1 source rollback is2d9e832, with its binary/templates retained and its
cache kept separate. This closes the **engine** work, not the unresolved combat
parameters, regional routes, VFX or publication condition.

The inactive CI template's4.7.2 image tag/digest was checked via Docker Hub's
public tag API on2026-10-21. It remains a template; Actions were not activated,
and no CI-green claim is made.
