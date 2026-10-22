# AVFX source acquisition and owned-resource lifecycle

2026-10-22. This is a development dependency stage, **not complete AVFX playback**.
The accepted practice renderer and published v0.3.10 are unchanged.

## Actual installed sources

The existing authenticated AnAn Remote Exec transport reads the installed
`2026.10.16.0000.0000` SqPack without launching/modifying the game or its desktop.
`tools/avfx_resources.py` reuses the existing Lumina initialization and texture
reader. It follows **structured AVFX `Tex` records**, not binary-string regexes.
Explicit roots and unresolved candidates remain distinguishable. A successful
collection means closure for those roots' texture edges, not all TOP assets.

New private source bundle: 18 AVFX, 72 original texture files and decoded PNGs,
9 EID and 9 skeleton files. All 180 source/PNG hashes and the transferred archive
hash were checked. Missing required references: zero. Some guessed body/status
paths did not exist and remain recorded candidates, not verified mappings.
All18effects compile. The beetle body effect exposes an observed `-2` clip
binder scope: it is preserved as opaque/unresolved, never silently remapped
to an array index or assigned an invented global-target meaning.

The executable's shader path strings, cross-checked against the actual hashed
SqPack index, identify the **Apricot** family, not `particle.shpk`:
15 original packages, 124,098,695 source bytes; all source and archive hashes
checked. This provides original shader bytecode, **not** a Godot implementation
or verified permutation/constant binding. Background `bg.shpk` is 90,101,224
bytes and was not required or transferred. Original media stays outside Git.

## Bounded acquisition

- Validate every virtual path before any read/output; preserve full paths to
  avoid texture basename collisions and path traversal.
- Default resource limit16MiB, total256MiB and4096files; shader acquisition uses
  an explicit64MiB per-resource limit only for measured, selected packages.
- Query metadata before materializing large files. Oversized optional candidates
  are reported; required failures cannot pass. Failed manifests are preserved.
- Exclusive output directories protect previous proof. Lumina is disposed in
  `finally`; temporary runtime configs and decoded image buffers are released.
- Existing original/decoded hashes are never substituted for current readings.

## Runtime and test release

The player now stops failed playback and releases its draw nodes, mesh and
texture caches on invalid/budget-rejected seek. Reset/reconfigure/exit are
checked with weak references, not just dictionary lengths.

`work_guard.py` cleans its entire **owned process group on every terminal path**,
including a successful leader that leaves live children. Cleanup never kills by
name or touches unrelated services. Terminal evidence records signalled PIDs and
remaining live members. Zombies are not counted as live resource consumers.
Detached/new-session servers are not a supported test-launch pattern.

Source-backed float fields (near/far/depth offset, binder scale and disc interval)
are decoded as floats, not integer bit patterns. Numeric/bool enable flags are
handled by type. Timeline looping is a bounded deterministic **preview policy**;
Kill/End/Reset/Unlock/Fade/Trigger clip kinds are distinguished but explicitly
unsupported until their runtime-state and binder scope are established.

## Verification

- 65 Python AVFX format/compiler/resource tests, including8 acquisition cases.
- 18 work-guard tests, including exited-leader orphan cleanup and unrelated
  process survival.
- Godot4.7.2:147 owned-resource lifecycle checks;55 timeline checks;347 runtime
  checks with18 freshly acquired original effects. These are separate scopes,
  not pixel/original-runtime equivalence or fresh exported-platform acceptance.
- Minimal isolated test projects avoid loading the full character/arena pack.
  No browser was started. Owned Godot processes are checked after completion.

Remaining: exact Apricot shader selection/binding/equations, advanced particle
and attachment behavior, clip state, original reference captures and actual
Windows/Web visual comparison. See [AVFX_RUNTIME](AVFX_RUNTIME.md).
