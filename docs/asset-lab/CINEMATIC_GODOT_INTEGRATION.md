# Cinematic original MDL / Skin / Skeleton3D integration

Status: numerical integration PASS; full visual / all96 OPEN. No commit or publication.

Required manifest SHA256: `7ad8d152163dc1985e8c067d390a58b4b16ff5acc8b71075f9bc5a6bc0dc810d`.
Source baseline: `6e11e44c4009f095148e0c15520d25a8b8aeccd2`. All eleven protected seeds verified unchanged before and after execution. The JSON companion binds manifest, input/runtime pins, implementation hashes, original model/material/texture hashes, GLB hashes, numeric output, and guard receipts with exact argv.

## Reproduction

```powershell
C:/Python314/python.exe -B tools/asset_lab/run_cinematic_integration.py --manifest top/assets/official/top-cinematic-godot-deps-50790/inputs.json --manifest-sha256 7ad8d152163dc1985e8c067d390a58b4b16ff5acc8b71075f9bc5a6bc0dc810d
C:/Python314/python.exe -B tests/test_cinematic_godot.py
```

Each invocation creates a fresh ignored private output directory. Four serial converter children have 60-second deadlines; the actual pinned Godot main engine has a 90-second deadline. A suspended process is assigned to a dedicated Windows Job before resuming. The Job has a 1.5 GiB private-memory hard limit, kill-on-close descendants, and an 8 GiB available-RAM floor. Receipts preserve exit, stop reason, exact argv, RSS and Job private peaks. This is resource containment, not a security proof: ten direct .NET libraries are pinned; the transitive closure is incomplete. Pythonnet and all 114 pinned private Pillow files are validated before import; no installation or user-site dependency.

## Actual results

| Model / body | Bones | Vertices | Triangles | Imported meshes | Exported textures | Source frames |
|---|---:|---:|---:|---:|---:|---:|
| 110 / 1 | 118 | 29933 | 30108 | 4 | 2 | 290 |
| 424 / 2 | 82 | 5119 | 6918 | 2 | 4 | 159 |
| 8277 / 1 | 23 | 1648 | 1192 | 1 | 2 | 227 |
| 771 / 1 | 177 | 28388 | 40954 | 4 | 4 | 552 |

All four exact original variant-1 MDLs were read through Lumina and converted through the maintained TexTools helper. Raw MDL and SKLB hashes passed before conversion. The PAP path is historical snapshot provenance; original PAP bytes are not re-read by this gate. The accepted sampled JSON is independently hash-verified. The m0424 body is b0002; its b0001 library skeleton is tested here only against this exact model and sample, not proved to be the cinematic runtime selection.

Nine clips / 1,228 timestamps passed forward and reverse: 2465 matrix-checked seeks including one repeated start per clip, plus nine rebind endpoint seeks. Exact source timestamps are retained; no 1,230-frame grid or epsilon snapping. Godot JSON decimal decoding can differ at double precision, so query identity is compared in float32 on both sides, with strict float32 ordering; the Python preflight verifies exact stored float32 query values. Clip selection uses `clip.index`.

Maximum actual `get_bone_global_pose()` component error: 1.90734863281e-06; declared absolute float32 tolerance: 0.0002. Every clip exhibited nonzero actual bone motion. Names, parents and full nonuniform LOCAL rest matrices passed without renaming, remapping or pruning. GLB geometry, eight joint/weight influences, normalization, joint ranges and inverse bind matrices passed. Godot verified real MeshInstance3D mesh/skin/skeleton bindings, nonempty vertex and weight arrays, and textured material surfaces. Nonidentity transforms and scales were applied on both holder and model roots and excluded from the bone frame. Clear restored actual global rests; rebind and repeated seeks passed.

Peak child RSS: 527298560 bytes (502.87 MiB). Peak Job private: 489385984 bytes (466.71 MiB). Godot runtime: 4.491 seconds. Twelve pure malformed-input tests passed; they do not import models or native runtimes.

Accepted private run: `top/assets/official/top-cinematic-godot-deps-50790/outputs/run-1793300447634945600`. Full output hashes and all earlier attempts are bound in the JSON companion. Raw game media, samples, runtime binaries and generated GLBs remain ignored.

## Preserved failures and limits

- First attempt stopped before conversion because an unnecessary lookup treated historical `raw/...pap` snapshot provenance as a SqPack key. The corrected approach consumes pinned samples and checks actual MDL/SKLB bytes. Original failure log/receipt retained.
- Second attempt exported all four originals, then rejected a Godot JSON double-versus-float32 query comparison. The correction compares native float32 representations without modifying times; failure retained.
- Later successful runs are retained, including the final resource and clear-rest checks. The earlier parent-owned 50789 dependency failure was not altered.
- Godot emits a root certificate-store warning in this restricted environment. Final run has no SCRIPT ERROR, Parse Error or Compile Error, crash, timeout or OOM. Private engine logging is explicitly directed inside the run.
- Resident-player restoration is **OPEN / not exercised**: `animations=[]` deliberately yields no resident AnimationPlayer. No resident clip was invented to claim coverage.
- GPU skin deformation, raster appearance, original shader/colorset/VFX and exact part/stance fidelity remain **OPEN**. Helper materials are PBR approximations; generated GLB pose metadata is corrected without changing the helper. The helper's zero-total-weight fallback remains a converter limitation; normalized output does not prove original-weight fidelity.
- Native cinematic model/body selection, complete dependency trust, platform exports and all96 visual acceptance remain **OPEN**. This is a bounded four-original numerical integration gate only.
