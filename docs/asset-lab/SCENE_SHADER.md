# Conditional original lightshaft VS0 / PS0 inspection

This increment implements the supplied lightshaft equations and a standalone three-surface inspection scene. It does not establish native branch selection, environment, CUTB/SGB animation, blend/depth, a verified unit lifecycle, fog, fullfight or all96 acceptance.

Input manifest SHA256: `333eb3f9aa23cec8c63e31c436619488d0b3a4f5ed5318d695a7ba67fb36c649`. Instruction IR: `eb1b70a32ddada16bfca1001a9c8fe2e97eb4a8553159d005e5b854a279e760f`. SHPK: `bef224ebd302f5101e4e29c9dba86192df1a01c7366cf0cbca7893f6c27df6d0`. The manifest pins material mappings and maintained source references. These are source evidence, not captured runtime.

The startup comparison proved LF-normalized equality for all46 protected sources, then restored the exact manifest originals. The runner checks raw hashes before/after. Protected files have no semantic edits, including the accepted player.

The fresh decoder reads installed SqPack using the existing pinned initializer, Lumina and TexTools. Private raw MDL/MTRL/TEX/SHPK snapshots, hashes, declaration/mesh metadata, decoder MVID and lossless RGBA/PNG are retained. Three original MDLs have124 vertices/540 indices each; alpha is read from original Ubyte4n COLOR, not generated. Material constants are matched by original IDs against supplied MTRL mappings; both sampler IDs must match exactly. Raw TextureCoordinates0 is used directly, bypassing glTF orientation and imported materials. BGRA-to-RGBA is the sole texture channel transformation. Actual sampled texture alpha is255 throughout, an observed decode result rather than a substituted value.

Godot standard NORMAL storage alters original half-float normal lengths. The preview therefore passes original normals as CUSTOM0 RGB floats; shader arithmetic uses these components without normalization. COLOR alpha multiplies vertex-stage color before interpolation. Shader ties-to-even handles negative and positive halves. Source world is computed by I0..2 and remains in source space for projected UVs; geometry subtracts explicit(100,0,100) and the inspection camera uses the same recentered space.

The tiny staged project loads the first paused state, selects at zero paused, plays at1x, supports forward/reverse seeks, stops at its chosen10-second inspection duration, and restarts the same selection at end. Source clock is explicitly `origin + relative_seconds * rate`; its chosen origin0/rate0.001 are INSPECTION_FIXTURE inputs. They do not establish the native clock epoch/unit. I6w=5, I7rgb=(1,1,1), Common3x=1, camera direction and exposure1 are explicit fixture inputs. Additive, cull-disabled, no-depth-write is a chosen inspection state. Native PS alpha0 is retained in CPU equation output; Godot ALPHA1 is a separate inspection visibility policy. Texture filtering is chosen linear/wrap without sRGB conversion; native sampler LOD bias/mip equivalence is unverified.

Run from this worktree:

```powershell
python -B tools/asset_lab/run_scene_shader.py
```

Each invocation creates a new `top/assets/official/top-scene-shader-50871/outputs/run-UUID` and prints its exact path. Decode60s, Python tests30s, engine90s, aggregate180s,1.5GiB Job memory and8GiB free-memory floor. No existing output is reused or overwritten. The POSIX work guard is unavailable on this Windows host; the preserved Windows Job Object runner owns and bounds child processes. Shader-error scanning supplements its script-error scanning. Logs and failure receipts are retained.

For an authorized parent preview/export route use the generated `project/project.godot`, whose main scene is `res://scenes/scene_shader_preview.tscn`. No assets from this private project belong in tracked files. To repeat only the headless test, invoke the pinned engine through the same bounded runner with `--headless --path GENERATED/project --script GENERATED/project/test.gd` and a fresh log destination.

Headless checks are numerical/parser evidence only. They compare all original positions/UVs/custom normals/alpha, PNG RGBA bytes, explicit uniforms and independent playhead behavior. A separate literal pinned VS0 IR interpreter checks every vertex at three clocks against the CPU function. Literal reference cases exercise nonidentity rotation/scale and signed ties; affine camera translation is tested separately. ImageTexture row readback is numerical evidence only: actual GPU source-coordinate texture orientation, interpolation, appearance and Web raster remain mandatory parent gates. No visual-fidelity claim is made.

Failure history is preserved: first invocation incorrectly reported numeric pass despite a reserved shader identifier (`source_color`); it is explicitly rejected. Shader log scanning and the identifier were corrected. A literal-IR scalar-swizzle bug was corrected. A stricter normal test exposed standard-normal storage changes; custom float transport replaces it. Consult the latest terminal receipt, not earlier status strings. Godot also emits an unrelated system certificate-store diagnostic; no settings were changed. TexTools may emit its known background SQLite loader diagnostic; direct raw reads do not use that database.

Latest tested private project: `D:/Dev/OpenClawCodexBridge/worktrees/top-scene-shader-50871/top/assets/official/top-scene-shader-50871/outputs/run-f281d933-bff6-4992-a99d-d83662c8f5f1/project`. Final terminal status is HEADLESS_DATA_NUMERIC_PASS_RASTER_OPEN; six Python tests passed, engine failures array empty. Custom normal comparison uses exact float32 conversion of JSON values (not a widened tolerance). Earlier runs remain immutable and rejected where described above. No raster/export was performed.


## Parent review and exported-resource follow-up

Parent literal float32 SM5 oracle independently compared 240 varied cases against the CPU sample function (maximum relative error 6.624e-7). A separate raw-byte oracle located the unique original packed MDL streams and checked all372 positions, half normals, COLOR bytes, UVs and1620 indices without the source decoder. These are narrow numeric/source proofs, not native rendering or all96 acceptance.

Real export found a UTF-8 BOM at byte0 of the standalone TSCN; Godot rejected it although the initial headless test instantiated the script directly. The BOM was removed without changing scene attributes. The regression now loads the actual serialized scene. Frozen v1 and failed export logs remain preserved.

Focused independent review found a real missing mesh-channel contract: absent/quantized CUSTOM0 or absent COLOR could silently alter the shader. Binding now requires nonempty ArrayMesh surfaces with CUSTOM0 RGB_FLOAT, COLOR and UV; checks cardinality and finite positions/custom-normal/UV/color values; rejects unsupported input while clearing prior material/visibility. Scalar float uniforms are explicitly converted, and only known uniforms are bound. RGB_FLOAT is deliberate, not RGBA_FLOAT: the shader reads exactly three original normal components. Negative missing-channel/quantized-format fixtures are retained. The original shader arithmetic is unchanged.

For exported PCK fixtures that call FileAccess.get_file_as_bytes, imported PNG resource remaps do not retain the raw PNG payload at its original path. The private Web route therefore retains byte-identical PNG data under .png.bin names and changes only those private metadata filenames, with exact SHA joins and a retained diff; canonical game sources, decoded image channels and loader code are not changed. This is a route adaptation, not native visual-fidelity proof. The named clock/duration/blend/scene fixture limitations above remain unchanged.
