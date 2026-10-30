# Original visual input preservation — local checkpoint 50859

This increment preserves original material inputs; it does not implement the original shader or finish any of the 96 action performances. The accepted player and ActionModule have not been rewired. No commit, push, publication, desktop interaction, game launch, or export was performed.

Initial model checkpoint (v1): **PRESERVATION_IMPORT_PASS_SHADER_OPEN**, 39.33 seconds. Six behavioral negative/roundtrip tests pass. All 40 parent-frozen source files match their exact raw SHA256 values. Sixteen checkout files required the explicitly authorized raw-byte restoration from `top-action-modules-50853`; LF-normalized equality was checked before copying. Those restorations can appear in Git status and are not semantic edits.

| Original model/body | Retained parts | Vertices | MTRL identities | Bindings |
| --- | ---: | ---: | ---: | ---: |
| 110/1 | 4 | 29,933 | 3 | 12 |
| 424/2 | 2 | 5,119 | 2 | 8 |
| 8277/1 | 1 | 1,648 | 1 | 4 |
| 771/1 | 4 | 28,388 | 3 | 12 |

The private final evidence is under `top/assets/official/top-original-visual-inputs-50859/outputs/run-d1e33190-0f2b-4479-93e0-ed2988c52c9f/`. It is Git-ignored. `summary.json` contains complete model, source, implementation, output-hash and Windows Job receipts. The checked-in `original-visual-inputs.json` contains the scoped result and exact summary hash, not game media. Earlier development runs remain preserved. The initial run lacked the raw-array/default exclusion check; only the final run is the accepted checkpoint.

## Source reader and conversion

The immutable private manifest is `D:/Dev/OpenClawCodexBridge/worktrees/top-material-inputs-50830/top/assets/official/top-material-inputs-50830/inputs.json`, SHA256 `52d925afa2ad82f1e00323a851896980c6da371b1bf457cb6c6d5d696064c20e`. Its 140 inputs and 12 runtime pins are checked before and after execution. All 30 old seed pins are compared to this worktree. Five legitimately differ: cinematic inspector, playback gate, playback runner, playback Markdown and playback JSON. These differences are explicitly reported; the current parent-frozen 40 raw pins are authoritative. The report does not claim the old manifest exactly pins this foundation.

The pinned `references/official_export_helpers.py` initializes Pythonnet/CoreCLR, Lumina and TexTools using existing local libraries. Only its initializer is invoked; old export/main functions are never called. `realm.GetFile[FileResource]` reads the installed game archive under `F:/SquareEnix/FINAL FANTASY XIV - A Realm Reborn/game/sqpack`. Each MDL is checked against the pair's exact source path, byte count and SHA256 before decoding. Raw MDL, MTRL and TEX snapshots are written only in the new private run. The current maintained `audit_cinematic_mesh_fidelity.py` supplies strict GLB/accessor comparison and reflection helpers.

Actual reflected `TTVertex` fields include Position, Normal, Binormal, Tangent, FlowDirection, Handedness, UV1, UV2, UV3, VertexColor, VertexColor2, BoneIds and Weights. `VertexColor` is `System.Byte[]`; UV2 is `SharpDX.Vector2`. Reflection and decoder module MVID are retained in receipts. Crucially, TT fields alone could contain defaults. The converter additionally obtains `Mdl.GetXivMdl(raw.Data,path)`, selects LoD0 mesh/group and exact part, subtracts mesh IndexDataOffset from part IndexOffset, and sorts the unique raw triangle vertex indices. It verifies the remapped topology and every raw `VertexData.Colors[id].R/G/B/A` and `TextureCoordinates1[id].X/Y` against the TT part vertex. Missing arrays, NaN sanitization, ambiguous parts or changed mapping block the conversion.

The original frozen GLB's existing binary buffer bytes are retained as an exact prefix; original accessors, buffer views, nodes, skins and animations are verified unchanged. Exact group/part names, attributes, POSITION, NORMAL, UV1, indices and original-material paths must match before appending. New COLOR_0 is unsigned-byte VEC4 with normalized=true; every decoded component is checked against raw byte/255. TEXCOORD_1 carries the proven raw UV2 floats. No native VS COLOR0 mapping is claimed. No standard TANGENT handedness is invented. Other decoded fields, including tangent/binormal components, are retained in per-part compressed JSON sidecars; their original native semantics/default status remain unproved. Excluded LOD/empty parts stay excluded and have explicit identities in receipts.

Each part has a compact independent **raw-model** oracle: four RGBA bytes followed by two little-endian float32 UV2 values per vertex, 12 bytes per row. The GLB writer does not generate this oracle by reading its own accessors. Receipts include per-part distinct/min/max statistics and hashes. Godot compares every retained vertex, not a sample.

MTRL identity is never deduplicated by texture content: m0771 a/b remain separate identities. All sampler IDs and reflected sampler flags, shader keys/constants, colorset raw half-word values, dye data and AdditionalData bytes are retained, together with raw MTRL snapshots and source hashes. The 9 material paths and 36 ordered `(material path, texture path, sampler ID, SHA, bytes)` records are independently checked against the protected accepted mesh-fidelity evidence. Existing PBR materials are explicitly marked approximate/data-only in extras.

The pinned helper's actual texture decode is Pillow `Image.frombytes('RGBA', size, TexFile.ImageData, 'raw', 'BGRA')`. This converter performs only that channel permutation. It retains all decoded RGBA bytes, writes lossless PNGs and checks Pillow roundtrip. No alpha replacement, green inversion, sRGB transfer or opacity rule is applied. Each binding retains its own TEX/PNG/RGBA receipt even where source texture bytes coincide.

## Actual Godot gate and limits

The pinned Godot 4.7.2 executable performs headless `GLTFDocument.append_from_file` and `generate_scene` for all four fresh GLBs and all four baselines. Actual Mesh ARRAY_COLOR and ARRAY_TEX_UV2 are compared to every raw-model oracle row at a fixed absolute tolerance of 1e-7; observed maximum errors are **zero**, with no widened tolerance or transfer correction. Existing imported POSITION/NORMAL/UV1/eight bone/eight weight/index arrays are byte-value equal to the baseline imports. Skeleton names, hierarchy and rest transforms are equal; each mesh has the actual bound Skin/Skeleton3D. Animation JSON and animation buffer/accessor bytes are unchanged; this gate does not resample animation or repeat full animation playback acceptance.

Godot `Image.load_png_from_buffer` then RGBA8 readback equals the complete independent decoded RGBA file for every binding, including all channel bytes and dimensions. This is numeric/data import evidence, not a raster or GPU shader claim.

Independent source investigation found supporting upstream code:

- [TexTools TTModel.cs](https://raw.githubusercontent.com/TexTools/xivModdingFramework/master/xivModdingFramework/Models/DataContainers/TTModel.cs): RGBA byte array, normalization by 255, binormal handedness.
- [TexTools ModelModifiers.cs](https://raw.githubusercontent.com/TexTools/xivModdingFramework/master/xivModdingFramework/Models/Helpers/ModelModifiers.cs): MergeGeometryData raw-part mapping and default/NaN behavior. Upstream master is semantic guidance, not a hash pin of the installed DLL; the runtime raw-array comparisons provide local evidence.
- [Godot 4.7.2 gltf_accessor.cpp](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gltf/structures/gltf_accessor.cpp): decode_as_colors directly constructs colors from decoded components.
- [Godot 4.7.2 gltf_document.cpp](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gltf/gltf_document.cpp): COLOR_0/ARRAY_COLOR and TEXCOORD_1/ARRAY_TEX_UV2 mapping. Actual runtime readback confirms the mapping for these inputs.

`python3 tools/work_guard.py begin` was unavailable: this Windows host has no python3 alias and that guard imports POSIX fcntl. Heavy operations instead lazily reuse only `run_cinematic_integration.run`, with 60-second decoder guards, 90-second engine guard, 180-second aggregate budget, 1.5-GiB Windows Job limit and 8-GiB free-RAM floor. Work is serialized. Final peak Job memory was 655,212,544 bytes; minimum free RAM was 32,089,743,360 bytes. Terminal receipts and errors are saved before nonzero exit. SCRIPT ERROR, Parse Error and Compile Error reject the engine run. No guard limits were extended.

## Commands and remaining gaps

From this worktree:

```powershell
python -B tools/asset_lab/run_original_visual_inputs.py --manifest D:/Dev/OpenClawCodexBridge/worktrees/top-material-inputs-50830/top/assets/official/top-material-inputs-50830/inputs.json --manifest-sha256 52d925afa2ad82f1e00323a851896980c6da371b1bf457cb6c6d5d696064c20e
python -B -m unittest discover -s tests -p test_original_visual_inputs.py
```

The final unit invocation was wrapped in `subprocess.run(..., timeout=30)` and saved to `unit-tests.log`. The six tests cover missing manifests, ambiguous/wrong-model mappings, missing/nonfinite vertex rows, independently specified normalized RGBA bytes, corrupt GLB/value roundtrips and same-count wrong sampler identities. The standalone converter accepts `--manifest ABS --manifest-sha256 SHA --model INT --output ABS`; invoke it through the bounded runner for production use.

Genuine limitations:

- **No nonopaque source-alpha counterexample was found:** all 36 decoded bindings have alpha 255. Synthetic test colors include alpha 3 and 254, but that is not original-source evidence and does not close the requested source-counterexample criterion.
- TexTools logs `SQLite.Interop.dll` missing from `ShaderHelpers.LoadShaderInfo`. The raw MDL/MTRL/TEX reads and all retained arrays still pass. The original log is preserved; this is not full shader metadata/dependency closure, and no installation was attempted.
- Actual shader selection, channel formulas, blend state, native VS input binding, table semantics and raster fidelity remain OPEN. Six candidate pixel shaders are not an actual runtime choice.
- No full 96-performance, Windows/Web export, or published milestone acceptance. No player wiring changes.

New implementation is confined to the six requested files: the converter, bounded runner, Godot gate, Python tests, this document and `original-visual-inputs.json`.

## Parent independent validation — v2

Current accepted numeric-preservation candidate is `outputs/run-a2c92dab-cc6c-4c60-a3dd-fbbb4fd20a63/summary.json`: **PRESERVATION_IMPORT_PASS_SHADER_OPEN**, 39.50 seconds. The v1 evidence and initial review findings remain retained. This does not accept original rendering or any all96 performance.

The trusted prepared 40-source manifest is now itself SHA-pinned (`ceea5ef4d9c449aa91e4e60081250805da8e33d904e1502711886ae445824ad4`) with explicit cardinality40. Both comparison/guard dependencies were already among those 40 protected files; the current runner additionally lists their hashes and verifies the copied Godot test source. The independent comparator rejects row/component count changes and nonfinite values, with default tolerance zero. The original mesh-fidelity identity JSON is also among the protected40.

Direct source declaration inspection additionally confirmed all11 retained meshes declare Color Count0 Ubyte4n and TextureCoordinate Count0 Half4. The converter now requires these exact raw declarations and forbids overwriting an existing COLOR_0/TEXCOORD_1. UV2 is constant in these actual inputs, but is present in original packed four-component storage; it is not accepted merely because TTVertex has a default UV2 field. No native VS semantic binding is inferred. Constant channels do not themselves independently establish vertex permutation; topology remap and exact source geometry checks remain necessary. The separate Lumina MdlFile typed reader failed with EndOfStream on this client; the already proven TexTools GetXivMdl reader supplies the actual declarations.

An independent parent binary reader (no converter imports) verified all65088 color/UV2 rows against compact raw-model oracles, all4 unchanged original BIN prefixes/accessors, and nodes/skins/animation JSON. The v2 GLBs and oracle hashes exactly equal the independently audited v1 outputs. This is independent checking of the conversion output against raw-model-derived oracle values, not a second independent implementation of the native MDL format decoder. The separate source-investigation manifest also matches all9 MTRL hashes/colorsets/additional-data and all36 TEX/sampler bindings.

Frozen cross-family claude-sonnet-5-5 review first raised source-trust concerns; focused v2 followup returned RESOLVED for the numeric-preservation scope. The parent separately verified the helper and baseline identity pins the reviewer had not inspected. The engine binding lists are JSON identity receipts, not GPU material binding proof. PNG readback proves lossless retention of the maintained reader's decoded channel bytes, not an independent texture-format decoder or shader result. Alpha source-counterexample criterion remains OPEN because all36 actual source decodes are opaque. Material variant1 is independently grounded for these four pairs; body base2 is not material variant2.

A separate private Godot Web route recorded nine original clips with Play/Pause/end/no-next checks; inspected start/motion/end frames show changing poses but currently approximate, dark materials and no complete scene/VFX performance. That route used the unchanged prior PBR GLBs, not a claim that these preserved data inputs implement the original shader. No partial public gallery/release/Web deployment is authorized by this narrow gate.
