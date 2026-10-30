# Cinematic mesh fidelity source audit

Checkpoint: decoded geometry checked for exactly four variant-1 original MDLs against the pinned final GLBs. Material semantics remain OPEN. This does not extend the parent's four-original/nine-clip numerical Skeleton3D acceptance to visual or all96 acceptance.

Manifest SHA-256: `385131d58687249ffcb8fb9b8ac215446f9ca9a4bdd8306ad892bc50ce5aa8a2`.
All 18 protected source seeds, 125 private inputs and 12 direct runtime pins passed before loading READ dependencies and at completion. No protected exports or source seeds changed. The JSON companion preserves every pin, all four original MDL/final GLB hashes, material source metadata, exact commands, receipts and output hashes.

| Model | Parts | Vertices | Triangles | Seconds | Peak RSS MiB | Job peak private MiB |
|---|---:|---:|---:|---:|---:|---:|
| m0110 | 4 | 29,933 | 30,108 | 3.582 | 338.70 | 296.89 |
| m0424 | 2 | 5,119 | 6,918 | 2.529 | 270.48 | 230.08 |
| m8277 | 1 | 1,648 | 1,192 | 2.274 | 257.91 | 217.75 |
| m0771 | 4 | 28,388 | 40,954 | 3.986 | 412.18 | 371.14 |

All 11 exported parts matched actual gN_pN names, source attributes and original variant material paths. POSITION/NORMAL/TEXCOORD_0 maximum absolute error was 0; every triangle index matched exactly. All 65,088 original eight-byte weight sums were 255. Zero sums, non-255 sums, missing positive-weight bone names, out-of-range positive local IDs and duplicate positive local IDs each counted 0. All eight influences were checked against actual JOINTS_0/1 and WEIGHTS_0/1. Maximum absolute weight error was 2.9685450542160652e-08, below declared 1e-7 float32 tolerance. Normalization is byte divided by original eight-byte sum. Synthetic root fallback is never evidence of original weight fidelity.

Source part exclusions, including atr_lod, counted 0 for these decoded models. This is not proof of native part/stance selection. UV2, colors, tangent/binormal and shape data remain outside the comparisons; the per-part exclusion list describes that scope, not a measured inventory of every omitted proprietary attribute.

Nine used source materials and all 36 sampler bindings were inventoried. Each material uses characterlegacy.shpk. Raw MTRL snapshots are private only. Source texture paths, SHA-256, byte counts, dimensions and formats are recorded without raw texture dumps. Maintained parser metadata includes shader key IDs/values, constants, colorset RawValue entries, dye arrays and additional bytes. Empty exposed arrays are recorded as such, not evidence that all possible shader data is absent.

The converter exports diffuse and normal maps, forces diffuse alpha to 255, inverts normal green and sets normal scale to 0.65. Mask and index sampler bindings are omitted; their source usage names and numeric IDs are preserved. Source sampler mirror/LoD settings are not reproduced by the GLB's fixed repeat/filter sampler. The fixed metallic 0.25/roughness 0.65, double-sided PBR approximation does not reconstruct shader keys, colorset, dye or additional-table semantics. Actual final material names/extras and per-part material indices are bound in JSON. No guessed shader formula was implemented and final PNG pixels were not independently compared.

Every child log contains an optional ShaderHelpers.LoadShaderInfo warning: SQLite.Interop.dll could not load. The jobs exited zero and raw material tables were returned, but computed usage/semantic lookup completeness remains OPEN. No dependency install, retry, memory increase or deadline increase followed. Reflection accessed decoded object properties; this is a review limitation because optional semantic lookup was triggered. TexTools is a shared maintained parser, not an independent proprietary decoder or raw native renderer oracle.

Execution used the protected run_cinematic_integration.run via lazy import, never its main/old validator. Four serial jobs used true suspended Job assignment, 60-second deadlines, 1.5 GiB Job memory and 8 GiB free-memory floor; minimum observed free RAM was 32,657,899,520 bytes. The audit implementation SHA was checked before each run and unchanged at completion. Seven pure unit tests passed (joint corruption, normalized-but-wrong weights, source zero weights, index/position corruption and omission, strided normalized accessors, malformed chunks, sparse/nonfinite rejection); no native/model tests reside in that file. The test SHA is recorded at the final checkpoint rather than by the child runner.

Exact parent invocation:

```text
C:\Python314\python.exe -B tools/asset_lab/audit_cinematic_mesh_fidelity.py --manifest top/assets/official/top-cinematic-mesh-fidelity-50796/inputs.json --manifest-sha256 385131d58687249ffcb8fb9b8ac215446f9ca9a4bdd8306ad892bc50ce5aa8a2
```

Immutable retained evidence: `top/assets/official/top-cinematic-mesh-fidelity-50796/outputs/fidelity-1793301116412392800-5190d50c/`. Each model has exact argv, log, guard receipt, result and private raw MTRL snapshots. The summary SHA is in the JSON companion; output hashes exclude the summary itself and bind all earlier outputs. Git ignore protection was verified. No media/binaries were staged, no commit/push/publication occurred, and no shared tools or other worktrees were edited.

All96, visual, raster and exported-platform acceptance are false/OPEN. No new screen evidence or frames were produced. Parser counts and zero-frame execution are not visual acceptance. Shader reconstruction, colorset semantics, source pixels, native part/stance choice and renderer appearance remain OPEN for independent parent review.


## Parent gate correction v2

The independent frozen review found a reproducible aggregation bug: a WEIGHTS_BLOCKED child with a successful process receipt could be summarized as complete. The original source and failed aggregation counterexample are preserved. Parent v2 now checks the actual child status, counterexamples and blocking counters in both direct-child and aggregate paths; blocked results remain in the summary with model/counters and return failure. Ten pure tests pass, including aggregation of zero weights despite guard exit 0, missing status/false-pass counters, and genuine pass retaining shader/visual OPEN.

The numerical run and its immutable output hashes above belong to the original pre-correction implementation. They were NOT replayed or relabelled as v2 native execution. A separate guarded parent oracle independently re-read all four original MDLs/final GLBs, all 65,088 source vertices/eight weights, and nine raw MTRL arrays/36 texture hashes; all four actual raw results were confirmed passing. Candidate source pins are recorded in parent_gate_correction_v2 in the JSON companion. Original SQLite warnings, shader/colorset/pixel/stance and all96 exclusions remain unchanged.


### Parent follow-up correction v3

V2 correctly rejected blocked children, but its real nonzero-receipt branch raised before copying the retained result into the summary. V3 reads and preserves an available child result before deciding the receipt. A failed receipt remains BLOCKED even with passing JSON; absent JSON also blocks. Thirteen pure tests now cover actual nonzero/blocked results, defensive zero-exit/blocked results, failed-receipt/passing JSON, missing JSON with either receipt, and valid pass. No original native numerical job was replayed. V2 and its follow-up finding remain preserved as intermediate evidence, not accepted as the final gate.
