# Original AVFX reconstruction — post-v0.3 increment

The published `top-v0.3.0-preview` tag remains fixed at `0e7ef03`.
This is subsequent development, **not a change to already downloaded binaries**.

## Existing solutions and scope

Inspected the maintained MIT [Dalamud-VFXEditor format implementation](https://github.com/0ceal0t/Dalamud-VFXEditor/tree/05f6eb0cce19a6a91ae275bce609299d573914b3/VFXEditor/Formats/AvfxFormat)
(`AvfxBase`, `AvfxModel`, `AvfxVertexes`, `AvfxIndexes`, `AvfxIntList`).
Its editor depends on the in-game plugin/UI; this project neither installs nor
runs that plugin. Physis was also inspected: its AVFX reader exposes meshes and
textures but retains scheduler/emitter/particle payloads as placeholders; it is
not a ready-made standalone particle renderer. No third-party parser code or
binaries are embedded in the product. The narrow Python bridge reuses this
project's existing original-model glTF writer and documented format layout.

## Completed geometry layer

`tools/avfx_meshes.py` strictly reads one supported-version, little-endian AVFX
root, aligned tagged blocks, declared node counts, embedded half-float geometry,
packed normal/tangent/color bytes, four UV sets and uint16 triangle indices.
`MdNo` is a **byte list**, despite the upstream class name `AvfxIntList`; treating
it as int32 was rejected by the original-file gate and corrected from source.
Emission-only models are kept as data, never replaced with invented triangles.
Unknown payloads and the complete input are retained losslessly in `graph.json`.
Malformed/truncated buffers, nonfinite positions/UVs and invalid references fail.
Inputs are size-bounded; existing output directories are never overwritten.

Using the already preserved three local source files:

| Source | Particle nodes | Models | Drawable GLBs | Vertices | Triangles |
| --- | ---: | ---: | ---: | ---: | ---: |
| Meteor, NPC15726 | 14 | 6 | 6 | 3621 | 4658 |
| Comet, NPC15727 | 9 | 6 | 5 | 3424 | 4298 |
| Fist, NPC15710/b6 | 7 | 2 | 2 | 36 | 40 |

Ten synthetic regression tests cover source half/byte codecs, raw-data
preservation, unsigned indices, malformed buffers/counts/references, nonfinite
vertices, emitter-only data and the actual glTF buffer values. No game media is
in the fixtures. All13 drawable GLBs were then imported in the pinned Godot4.7.2;
all7081 source vertex positions and all buffer counts matched (7107 checks/0).
Default importer compression introduced~0.00002–0.00004 position differences;
this was diagnosed against the **4.7.2** importer source, not hidden by a looser
assertion. `GLTFDocument.IMPORT_FLAG_FORCE_DISABLE_MESH_COMPRESSION`, supported
and bound in that version, preserves source positions for this import gate.

```sh
python3 -m unittest discover -s tools/tests -p test_avfx_meshes.py -v
python3 tools/avfx_meshes.py --input <local-effects>/meteor/effect.avfx --output <NEW-DIR>/meteor
# Repeat for comet and fist_b6; source files stay untouched.
godot --headless --path top --script tests/avfx_meshes.gd -- <NEW-DIR>
```

## Not completed by extraction

The GLBs deliberately have **no reconstructed game material**. Coordinates and
triangle winding remain source-local; there is no implied actor/arena transform.
Raw packed normals/tangents, position W and all four UV sets remain in JSON even
where the glTF/Godot representation differs. Mesh import is not visual acceptance
of a fully rendered AVFX. Scheduler/timeline evaluation, emitter attachment,
particle lifetime/randomness, transforms/curves, per-layer shaders, blend modes,
UV animation/distortion and effects appearing/disappearing with NPC lifecycle
still require implementation and actual visual comparison. `rendering_complete`
therefore stays **false**; the existing live training cues are unchanged.
Extracted game geometry/textures/proof captures remain local and Git-ignored.

## Portable texture inventory / explicit legacy migration

`export_official_effects.py` now emits only forward-slash relative paths. It
preserves each original virtual texture hierarchy **and its TEX/ATEX extension**;
different directories/extensions cannot silently overwrite a shared basename.
`effect_pack.py` is stdlib-only: schema/hash/path checks plus PNG chunk CRC/IHDR
validation do not require Lumina, .NET or Pillow. Original texture hashes remain
metadata, because the raw TEX/ATEX bytes are not included in this inventory.
This is file integrity, not image decode, AVFX semantics or rendering proof.

```sh
python3 tools/effect_pack.py validate <PACK>
python3 tools/effect_pack.py migrate <LEGACY-PACK> --output <NEW-DISJOINT-DIR>
```

Migration is explicit, copy-only and refuses an existing/overlapping output.
Both native Windows nested paths and literal-backslash filenames synced to Linux
are supported; ambiguous duplicates, unsafe/traversal/drive paths, symlink or
junction escapes, output collisions, missing/tampered files and unsupported
schema/rendering-complete claims are rejected. Input files are never deleted.
18 fixture tests pass on Linux; independent Windows14 pass/4 skip (three
POSIX-only literal filename cases and unavailable native symlink creation;
mocked link rejection still runs). The actual preserved pack's24 PNGs and3 AVFX
files all passed migration hash/dimension checks; original source bytes were
verified unchanged. The validated canonical copy became the active local pack
by same-filesystem rename, with the complete legacy directory retained locally.
No extracted files, private paths or original artwork were added to Git.
