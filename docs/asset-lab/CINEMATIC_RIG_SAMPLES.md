# Original cinematic numerical samples

NUMERIC PASS: four exact original MDL/SKLB/PAP pairs; all nine PAP clips sampled by the pinned 32-bit hkAnimationInterop DLL. Six actor bindings remain in the protected actor report. all96_accepted: false.

Base: 6e11e44c4009f095148e0c15520d25a8b8aeccd2. The six protected seeds are byte-identical. Previous failed/preflight report and failure references are preserved privately; this is a dependency-fixed continuation, not equivalent replay.

Observed clips (logical 30 Hz grid, float32-native duplicate queries removed; start zero, exact native duration queried once):
- m0110 index 0 b_bosomg00210_01a: 2.3333332538604736 s, 118 bones, 71 frames; first-three distinct=3; reverse requery PASS.
- m0110 index 1 b_bosomg00210_02a: 2.2333333492279053 s, 118 bones, 68 frames; first-three distinct=3; reverse requery PASS.
- m0110 index 2 b_bosomg00210_03a: 5.0 s, 118 bones, 151 frames; first-three distinct=3; reverse requery PASS.
- m0424 index 0 b_bosomg00220_05a: 4.5 s, 82 bones, 136 frames; first-three distinct=3; reverse requery PASS.
- m0424 index 1 b_bosomg00220_06a: 0.7333333492279053 s, 82 bones, 23 frames; first-three distinct=3; reverse requery PASS.
- m8277 index 0 b_bosomg00220_03a: 7.0 s, 23 bones, 211 frames; first-three distinct=3; reverse requery PASS.
- m8277 index 1 b_bosomg00220_04a: 0.5 s, 23 bones, 16 frames; first-three distinct=3; reverse requery PASS.
- m0771 index 0 b_bosomg00220_01a: 14.333333015441895 s, 177 bones, 431 frames; first-three distinct=3; reverse requery PASS.
- m0771 index 1 b_bosomg00220_02a: 4.0 s, 177 bones, 121 frames; first-three distinct=3; reverse requery PASS.

All MDL dictionary names from the hash-bound parent extraction exist in loaded SKLB names. m0424 retains body b0002; skeleton b0001 remains a library candidate, not native runtime-choice proof.

Actual SKLB magic is blks. PAP and SKLB containers are TAGFILE. Outer headers/offsets and exact pinned bytes are checked before native calls; no arbitrary TAGFILE/fixup safety claim. Buffers remain alive until container unload. Null handles/count bounds, NaN-initialized 48-byte Translation4/Scale4/Rotation4, guard canaries, VirtualQuery-bounded names and acyclic parents are checked. Getter integers are recorded, not interpreted as success/count. Reference is LOCAL; sampled MODEL follows upstream convention.

All clips are budgeted together before dense sampling; each JSON is below 64 MiB. Four final serial Jobs exited zero, no timeout or low-RAM stop. Each has a 60-second deadline, 1.5 GiB Job cap and 8 GiB free-RAM floor. Full commands, resource receipts, input/runtime/source pins and private sample hashes are in cinematic-rig-samples.json.

Command pattern: python -B <private-root>/guard.py 60 <pinned-python32> tools/asset_lab/sample_cinematic_paps.py --root <private-root> --output <fresh-private-directory> --model <110|424|8277|771>. Tests: same guard and Python with tests/test_cinematic_rigs.py (14 passed). Unit counts are not native acceptance; the four final sample outputs are the numerical evidence.

work_guard could not run: python3 unavailable and its fcntl implementation is POSIX-only. Existing Windows Job guard supplied bounded execution and terminal receipts. The initial incorrect type-byte expectation failed before native calls; its receipt remains.

No extraction was repeated. Retained extractor transitive .NET dependencies are not all pinned. Upstream ABI/binary source: SaintCoinach commit 0b22b78f97951bb66bfa78fb561aa4c7bf7af7cd, DLL git blob b07a2b0492d09f9fb5cdff4c965fe9f58bf6e88c.

OPEN: skeleton/mesh integration and actual playback, choreography, camera, event dispatch and all96. No Godot/render/conversion/export was performed. Next dependency: consume local reference and model-space sampled TRS in a separate integration gate. No commit, push, deployment or desktop actions.

Parent ABI correction: the original 1230 stored logical timestamps contained two duplicate native endpoint queries (m0110 index1; m0424 index1). The original snapshot and receipts are preserved. Corrected four native runs contain 1228 unique float32 queries, with logical times and actual native_query_times recorded separately. All 1228 frames were queried again in full reverse order and exactly matched their forward poses; this is not a visual/render check. Four fresh guarded runs and the 14-test run all exited zero. Focused cross-family source review is recorded separately and must be adjudicated by the parent.
