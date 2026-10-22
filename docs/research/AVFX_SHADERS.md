# Original Apricot shader inspection and rendering bridge

2026-10-22. This is **not complete AVFX playback** and is not enabled in the
accepted practice renderer. Public builds and encounter judgments are unchanged.

## Verified original data, not shader-name guesses

The installed executable's literal paths were checked against the actual SqPack
index. The15 `apricot_*` packages contain18,533 programs and23,931 nodes/passes:
10packages version`0x0E01`,5 version`0x0D01`. All original file/transfer SHA256s
were checked. The current maintained TexTools shader-default database contains
zero Apricot rows; background/character defaults are not substitutes.

`tools/shpk_inspect.py` follows the maintained MIT
[Penumbra.GameData reader at b6c5de34](https://github.com/Ottermandias/Penumbra.GameData/blob/b6c5de34c05459c6af97ad14c2dac3d269aa84d9/Files/ShpkFile.cs).
It reads program/resource/constant-buffer bindings, nodes, keys, passes, aliases
and DXBC chunks; selected bytecode extraction is exclusive. Unknown versions,
invalid references, section overlap, out-of-range/overlapping DXBC chunks and
negative extraction indices fail. Aggregate allocation/count limits apply.
DXBC's embedded checksum is **reported, not recomputed**; source and individual
chunk SHA256s are separate observations, not native-checksum certification.

All15packages/18,533programs pass inspection. Each package was inspected in a
separate process with512MiB address-space/30sCPU limits; maximum observed resident
memory was143,360KiB. Processes terminate between packages; no native renderer
or browser is needed. The inspector does not execute or translate shader code.

## Selected original fragment programs

Seventeen original programs were disassembled with the installed Windows
`d3dcompiler_47` API, without creating a GPU device or executing the shaders.
This includes nine particular texture-layer pixel variants; their metadata and
assembly remain private. These are **specific permutations**, not generic
formulas selected only by the number of textures.

Let `Ci` be the corresponding texture sample,
`L(c)=dot(c.rgb,(0.298912,0.586611,0.114478))`,
`M(C1)=(lerp(1,C1.rgb,CalculateColor),lerp(1,C1.a,CalculateAlpha))`, and
`A(C1)=lerp(1,L(C1),CalculateAlpha)`.

| Original selected program | Texture-combiner output before vertex/document factors |
| --- | --- |
| Shape8 / Powder1 | `M(C1)` |
| Shape403 | `(C2.rgb,A(C1))` |
| Shape995 | `M(C1)*C3`, alpha additionally multiplied by`C2.a` |
| Shape466 | `(C2.rgb*C3.rgb+C4.rgb,A(C1)*C2.a)` |
| Model1636 | `(1,1,1,A(C1))` |
| Model1616 | `(C2.rgb,A(C1))` |
| Model1783 | `(M(C1).rgb+C2.rgb,M(C1).a*L(C3))` |
| Model1618 | `(C2.rgb+C3.rgb,A(C1)*C2.a*L(C4))` |

Model variants additionally apply their original Fresnel factor. The displayed
source programs multiply by interpolated vertex color and document modulation,
clamp negative channels, cap alpha at1 and discard below1/255. Tone mapping and
the auxiliary MRT have additional context-dependent operations.

UV mappings also differ between permutations: Shape995 reuses first-layer UVs
for its third sample; Model1618 transforms one UV pair while other samples use
packed varying pairs. A guessed common transform for all textures is not valid.
The initial vertex0 programs are not automatically the matching vertex programs
for these textured pixel variants.

## Implemented rendering corrections

- Preserve distinct source depth-test/write, front/back culling, draw priority,
  nearest/linear and repeat/clamp states instead of forcing one state globally.
- Do not substitute`TC1.TLst[0]` as a primary texture.`TLst` is the source mask
  list; animated selection and its host binding remain unresolved.
- RGB-derived alpha uses the observed weighted luminance, **replacing** stored
  texture alpha, not`stored_alpha*max(RGB)`. The isolated check corresponds to
  the original shader's`CalculateAlpha=1` path; arbitrary host-parameter mapping
  is not certified by that check.
- Advanced/mixed sampler states, soft particles and unsupported blend/cull modes
  remain diagnostics, not silent original-equivalence claims.

Verification:8synthetic shader-container tests;33material-state checks;
14actual320x240Mesa/OpenGL pixel checks (depth obstruction/bypass, front/back
culling, repeat/clamp, alpha discard/depth interaction, all four mapped framebuffer blend equations and three luminance-alpha primaries). Pixel tests exercise
actual rendered output, not only shader-source string comparisons. Source-data
inspection, shader compilation and game-reference equivalence are distinct gates.
The same14pixel checks also pass on AnAn Windows/OpenGL with Godot4.7.2;
its owned process exited and was reaped. FFXIV was not launched. This is a
minimal native rendering test, not full TOP Windows gameplay acceptance.
All owned Godot/Xvfb processes were checked after exit.

## Exact remaining requirements

AVFX fields and shader bytecode do not by themselves establish the host's
package-specific scene-key selection, matching VS/PS pair, dynamically packed
`CalculateColor/CalculateAlpha`, UV matrices, mask animation or actor bind poses.
These require a source-backed host mapping or a controlled reference trace.
VFXEditor's field names and the existence of shader programs do not supply it.
A subsequent bounded source review found VFXEditor`ShpkFormat/Utils/CrcMaps.cs`,
which names many scene-key/value CRCs and supplies a concrete next mapping layer;
it is not itself the complete AVFX-to-key-vector or dynamic-buffer evaluator.

The newly acquired18-effect corpus also actually uses18Decal particles,
1DecalRing,1Polyline,1SphereModel emitter and2CylinderModel emitters beyond the
currently implemented type subset. Actor attachments, stop/reset/unlock/fade/
trigger semantics and original temporal/Windows/Web comparison remain open.
Do not remove incomplete/experimental flags or replace the accepted practice
renderer until these requirements are implemented and verified.

The package-bound [semantic selector](AVFX_SHADER_SELECTION.md) now implements
readable/hex constraint resolution, exact-vector matching and explicit ambiguity,
with all23,931original nodes checked. It does not yet derive the full host state
from an AVFX.

## Reusable, explicitly reviewed pair adapter

The [shader-pair ABI tool](AVFX_SHADER_PAIR_ABI.md) now makes the previously
private identifier-only adaptation reusable. All six inputs are hash-pinned;
UBO associations must be explicit and checked, never inferred from array order.
The 16 private pairs pass fresh offline links and the reviewed byte oracle after
normalizing shared-varying names. This adds no runtime draws, game-host binding
proof or full-player/release claim.
