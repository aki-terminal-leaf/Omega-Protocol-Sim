# Offline AVFX execution preview (experimental)

This increment runs without AnAn, a game installation, .NET or an in-game plugin.
It is **not complete AVFX playback**, is not wired into the practice renderer and
must not replace the accepted P3 reconstruction yet. No released build changes.

## Executable work

- `tools/avfx_preview_pack.py` combines the existing strict mesh/topology/curve
  decoders into a portable private document. Original bytes are embedded
  losslessly. Emit vertices use the source 28-byte float3/float3/RGBA layout;
  they are not invented from draw triangles. UV sets, material selectors and
  unsupported fields are retained. Exclusive output creation preserves proofs.
- `top/scripts/avfx_animation.gd` evaluates linear/step and monotone scalar
  splines, Const/Repeat/Add boundaries, source axis links, color and Life.
  Non-monotone/unknown/RGB-spline cases fail explicitly. Random sampling is an
  explicitly named portable **preview policy**, not the original game's RNG.
- `top/scripts/avfx_player.gd` executes scheduler and timeline offsets, nested
  point/model emitters, emission intervals/counts, particle lifetimes, parent
  transforms/color and base-texture UV curves. Mesh/LightModel use source
  geometry; Disc preview uses source parameter curves. Native numeric time is
  preserved. The optional 30-unit/s preview rate is not a measured server clock.
- Absolute-time seeking and reset are deterministic. Limits are 1800 native
  units, 16000 work operations, 2048 particles and nesting depth16. Cycles and
  invalid intervals fail closed rather than hanging. No combat/state code was
  changed. Unknown features remain diagnostics and `gameplay_eligible=false`.

## Validation (Linux Godot4.7.2)

- 55 Python AVFX format/compiler tests pass (8 new compiler cases).
- 197 Godot checks pass, including the eight preserved P3 original inputs,
  scheduler offsets, exact expiry, reverse seek, reset, invalid reconfiguration,
  random repeatability and cyclic-graph rejection.
- Eight original files were each actually rendered at five native timestamps:
  40 Xvfb/llvmpipe OpenGL captures, zero engine/shader errors. Sources round-trip
  byte-for-byte. These are execution/capture gates, not visual equivalence.
- Pixel review **rejects original-fidelity acceptance**: the loading effect can
  produce overlong bright layers. Successful screenshots do not certify it.
  No new Windows/Web export or native Windows rendering is claimed.

All original inputs, compiled documents, textures and screenshots stay private.
Public tests contain only original synthetic fixtures.

## Reviewed color-section continuation (2026-10-22)

The isolated [shader section bridge](AVFX_SHADER_SELECTION.md#executable-color-section-bridge)
now executes reviewed 1–4-layer decoded color equations with explicit caller
UVs/host controls. Linux, native Windows and WebGL2 pixel/lifecycle probes each passed
113 fixtures / 1,017 checks. It is
not connected to encounter playback and does not resolve the remaining host
ABI, render-graph, attachment or scheduler semantics below. No full-player
completion or new released build is claimed.

## Remaining hard requirements for complete playback

| Area | Remaining requirement |
| --- | --- |
| Timeline | Looped timelines; stop/unlock/fade/reset/trigger clip semantics and binder-target scope |
| Emitter | Other volume types; injection/velocity, fractional counts, original random distributions and parent inheritance details |
| Particles | Polyline/decal/other types; simple animation, exact billboard and velocity rules |
| Material | TC2–4, normal/reflection/distortion/palette, screen-copy, Fresnel, lighting, exact blend/depth/cull/UV conventions |
| Attachment | Actor skeleton sockets and type-specific binder transforms |
| Proof | Reference-game temporal/pixel comparison and fresh Windows/Web export acceptance |

The local preserved corpus contains selected AVFX/meshes/texture conversions,
not the complete original game shader/runtime or all encounter assets. AnAn is available again as of2026-10-22. The [source-acquisition continuation](AVFX_RESOURCES.md)
adds original EID/skeleton and Apricot shader packages; their presence is not
an implemented original runtime or completed visual comparison. The maintained MIT
VFXEditor format definitions were inspected at pinned revision
`05f6eb0cce19a6a91ae275bce609299d573914b3`; that editor's in-game playback does
not supply a standalone game shader/runtime. Its plugin was not embedded.

## Reproduce

Use the pinned Godot4.7.2 binary as `GODOT` in the examples below.

```sh
python3 -m unittest discover -s tools/tests -p 'test_avfx*.py' -v
python3 tools/avfx_preview_pack.py --input PRIVATE.avfx --output NEW.preview.json
$GODOT --headless --path top --check-only --script tests/avfx_runtime.gd
$GODOT --headless --path top --script tests/avfx_runtime.gd -- PRIVATE_CORPUS_DIR
```

For real render probes, `tests/avfx_render.gd` takes the compiled document, a JSON
map from original texture virtual paths to local PNG paths, and an output folder.
Run with an actual OpenGL display (Xvfb/llvmpipe is sufficient), not `--headless`.
Keep the output private. Reject any `ERROR` and require the final gate sentinel.

This is the next implementation dependency after [AVFX_GRAPH](AVFX_GRAPH.md),
not a completion claim for [P3_EFFECTS](P3_EFFECTS.md) or [FIDELITY](FIDELITY.md).
