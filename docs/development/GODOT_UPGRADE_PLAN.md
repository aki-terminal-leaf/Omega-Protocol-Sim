# Godot / GDScript upgrade plan

Status: **planned, not migrated** (2026-10-21). Current executable/project baseline
is Godot 4.4.1, GL Compatibility. GDScript ships with the Godot executable; there
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
| Typed arrays/dictionaries, script API typing | Exact pinned-version docs + parser/serialization regression; preserve JSON-native durable state | Existing 4.4 subset only; newer syntax not yet approved |
| Abstract classes / other newer GDScript syntax | Verify exact syntax and semantic support in versioned docs and a tiny executable probe before use | Candidate, not adopted |
| SceneTree/Node/Resource/input API | API exists in pinned reference and representative Windows/Web runtime check passes | Baseline API set; upgrade unverified |
| Rendering/materials/animation | GL Compatibility + real original-asset pixel validation on both export targets | Upgrade unverified |
| Web threading/extensions/platform features | Explicit official Web support and export test; no desktop-only dependency in shared flow | Not approved by assumption |
| Test runner/report/retry state | Error-sensitive headless runner, actual courses, JSON round-trip and failed-seed retention | 4.4 baseline only |

A feature's presence in an unversioned `latest` document is insufficient. If the
pinned target does not support a desired feature, select a documented supported
alternative or create a separately reviewed future upgrade stage.

## Parallel product backlog (not silently marked done)

P3 transition and P4 Wave Cannon are collected/reviewed and production-wired
(commits4e160e6/e9a6b9a). P6 actual request/target controls and public-reference
post-cast locks are wired(e731cc6); ranged edge geometry remains unverified.
Original VFX reconstruction, remaining route/source gaps, full five-profile
coverage for the remaining legacy entries, complete Windows/Web release QA and
this isolated engine migration are not complete. The target release API was
rechecked successfully during this follow-up; no4.7.2 download/import/export or
baseline switch has been performed.
