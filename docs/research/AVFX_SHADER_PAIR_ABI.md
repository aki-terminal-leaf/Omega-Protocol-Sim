# Reusable shader-pair ABI adapter

`tools/shader_pair_abi.py` adapts already-translated ESSL 300 vertex/fragment
programs. It is **not a shader translator**, renderer or game-host binder. Keep
using the existing DXBC/SPIRV-Cross toolchain for translation. No original game
source, bytecode or fixtures are included in this tool or its public tests.

```sh
python3 tools/shader_pair_abi.py --input reviewed-pair.json --output fresh-pair
python3 -m unittest -v tools.tests.test_shader_pair_abi
```

The importable API is `adapt(manifest_path, new_output_directory)`. Output is
`pair.vert`, `pair.frag`, and `abi.json` with input/output SHA-256 identities,
identifier replacements, consumed varying contracts and explicit UBO mappings.
The directory must not already exist, including a dangling symlink. The tool
checks all six source hashes and all contract gates before creating it. There
is no stale-output fallback. Run a shader compiler/linker on each emitted pair;
this deliberately limited adapter is not a complete GLSL validator.

## Manifest schema 1

`stages.vertex` and `stages.fragment` each require `glsl`, `reflection` and
`disassembly` references. Every reference contains exactly `path` and `sha256`.
Paths may be absolute or relative to the manifest. Reflection is the original
SPIRV-Cross JSON; disassembly is the original sectioned DXBC text.

`reviewed_ubos` is an explicit list, **not a zip of declaration/reflection order**.
Each entry contains:

- `stage`: `vertex` or `fragment`.
- `gl_block`, `gl_instance`: exact original GLSL identifiers.
- `name`, `type`, `binding`, `block_size`, and optional `set` (default 0): the
  explicitly reviewed reflected UBO identity.
- Optional `adapted_block`, `adapted_instance`: valid stage-prefixed identifiers
  (`VS_` or `PS_`). Defaults prepend that prefix to the source identifiers.

The reviewed association itself is a caller-supplied provenance boundary, not
something hash checks or equal array sizes can discover. Supply only mappings
reviewed against the compiler outputs. The adapter requires a bijection among
GLSL declarations, reviewed mappings and reflected UBO records. It verifies
one `vec4` array member, exact member name/length, offset 0, stride 16 and block
size. Other block shapes fail closed. An explicit GLSL binding must agree with
the mapping; ESSL 300 compiler output without binding qualifiers is supported.

## Varying and lexical gates

The adapter independently bounds the original VS Output and PS Input signature
sections. It rejects malformed/ambiguous rows and matches semantic, semantic
index, register, numeric format, vector width and consumed/written channels to
reflection and exact GLSL declarations. Optional location qualifiers must agree.
Generated shared names use `ABI_<SEMANTIC>_<INDEX>`. Missing or extra reflected
interfaces cannot silently supply a match. Unconsumed vertex outputs remain
unchanged.

Only identifier tokens are replaced; comments, strings, arithmetic, precision,
interpolation declarations, sampler state and instructions are not rewritten.
Stage UBO namespaces, conflicting source mappings and target collisions are
checked. The deliberately narrow accepted declaration subset is intended for
the inspected compiler output; unsupported input is not repaired automatically.

## Verification scope (2026-10-22)

- 13 public synthetic regression tests pass, including malformed rows beside
  valid ones, jointly wrong numeric formats/widths, UBO exhaustiveness/layout,
  comments/math, location mismatch, namespace collisions and stale outputs.
- All 16 retained private original VS/PS pairs pass fresh offline links: 54
  consumed varyings and 110 explicit stage-UBO mapping uses. Every emitted
  shader equals its previously reviewed output byte-for-byte after normalizing
  only the different shared-varying identifiers.
- 24 private input-mutation checks reject changed source hashes, missing or
  conflicting UBO mappings, bad names/types/layouts, crossed or absent signature
  sections, comment-only declarations and stale output without mutating output.
- The initial adapter rejected all 16 real pairs because it incorrectly required
  GLSL binding/location qualifiers. That result and the initial independent
  review's invalid-target/extra-reflection findings remain private evidence;
  they are not counted as successful attempts.

These are static adapter/link gates, **not new GPU draws**, host-buffer packing,
permutation selection, spatial interpolation, complete AVFX playback or a new
release. The separate original paired-shader runtime proof retains its own
narrow scope in [AVFX_RUNTIME](AVFX_RUNTIME.md#actual-original-vs--ps-pair-execution-2026-10-22).
