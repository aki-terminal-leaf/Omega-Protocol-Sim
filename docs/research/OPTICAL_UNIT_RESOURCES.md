# Optical Unit original resource investigation — 2026-10-27

## Verdict

Original eye-shaped scene assets are available and structurally usable as an Optical Unit candidate. They were read from a local game installation (game2026.10.16.0000.0000), converted to a textured static GLB, downloaded and hash-verified. This is resource availability/structure evidence, **not final P2/P5 visual/animation or simulator integration acceptance**. No desktop, game GUI, native window, input/focus/capture or idle probe was used. Source game files were read only; outputs are isolated task files.

## Identity and resource chain

- BNpcBase15716 references ModelChara480; its model id/type are0, so an ordinary NPC mesh export cannot provide the eye. The Optical Laser31521 uses generic hit timelines; those alone do not locate the visible object.
- TOP Territory1122 points to `bg/ex2/05_zon_z3/ome/z3oz/level/z3oz.lvb` → `bg.lgb`.
- `bg.lgb` contains eight rotated instances of `bg/ex2/05_zon_z3/shared/for_bg/sgbg_z3oz_p0_gmc05.sgb`.
- That outer scene references `sgbg_z3oz_p0_gmc5.sgb` (without the zero), which references three actual MDLs under `bg/ex2/05_zon_z3/ome/z3of/bgparts/`: `z3of_a0_eye00.mdl`, `z3of_a0_eye01.mdl`, `z3of_a0_eye02.mdl`.
- The same outer scene references eight `b1469*` appearance/beam/attack/closing AVFX and laser/appearance audio. This is a concrete resource association, stronger than filename matching alone. It is distinct from the unrelated `z3oz_p7_eye*` background geometry and from Sigma Rear Power Unit m0525.
- This corrects the earlier inference that the visible eye was VFX-only. The empty NPC proxy does not imply the visible scene lacks original meshes.

## What was recovered

3 original MDLs,7 material files,8 original model textures;8 AVFX with47 unique declared Tex dependencies checked. The corrected static GLB has SHA256 `23999509212f4baad227409a7add272d1ff254e5699302ce2748cd3f714742b3`. All archive members are verified against the original acquisition manifest. Raw game assets remain outside Git/public releases.

## Source transforms — defaults, not measured animation states

The source outer shared-object anchor is `(0,9,-45)` relative to arena center, with X pitch≈0.19739674rad (11.31°) and uniform scale≈43.43899. Each mesh child has scale≈0.55 and local Z offset−0.55; eye02 additionally has X rotation−45°. The eye geometry's front is toward local+Z. The positive X tilt therefore directs this front downward toward the arena. Eight zone instances rotate this assembly around `(100,0,100)` in approximately45° directions; original floating-point values are retained.

Effective static scale is≈23.89145. Eye01 raw X/Y bounds are±1, giving a **default-transform local width≈47.78289**, not a certified on-screen width for every animation state. The default child-origin offset is around `(0,13.686,-68.427)`: the radius45 anchor is not the physical globe center. Do not replace these with the simulator's previous arbitrary size8/height4 values and call them game measurements.

## Remaining limits and integration requirements

- The source BG children initially have `IsVisible=0`. The inspection GLB deliberately enables them; appearance, lid opening, closing and hiding require scene-state/timeline handling. Static source transforms cannot certify dynamic dimensions or phase timing.
- Original materials use `bg.shpk`/`bguvscroll.shpk`. GLB is a PBR inspection approximation; shader parameters, UV animation, blend behavior and full effect playback are not recreated.
- Exact runtime phase/state activation and P2/Delta visual alignment still require source/reference comparison. A valid file and preview do not alone prove all in-game appearances.
- Integrate only as a separate reviewed Optical asset change; keep frozen Web33/NPC work and productionWeb32 untouched. Native acceptance remains pending and desktop remains prohibited.

## Parent validation and correction

Independent Sonnet review checked the frozen resource report/scene/model metadata and found no must-fix on static transform math or candidate-only scope. Parent additionally checked all eight zone instances in the acquired scene. The105 verified bundle files include73 model/material/texture/effect resources plus32 scene witnesses, converted derivatives and metadata files;105 is not a count of distinct final visual components.

The first GLB embedded texture images but incorrectly selected the character diffuse sampler, so zero BG materials had assigned base-color textures. This failed binding was preserved with the initial gray geometry diagnostic. The corrected derived GLB assigns the observed BG primary `_d.tex` sampler510652316 on all7materials; the binary geometry/image chunk and source transforms are byte-identical. This is an inspection mapping, not proof that the layered BG shader is reproduced. `texture-binding-correction.json` retains both hashes and every binding. The raw acquisition ZIP is unchanged; the corrected derived GLB is a separately hashed companion.

Parent inspected both actual CPU-generated PNGs. They confirm loaded globe/lid geometry, but the second preview samples diffuse per triangle and lacks original shader/UV/visibility animation: **not an in-game visual comparison or final appearance acceptance**. Native and simulator integration remain NOT_RUN. No original game meshes/textures or source ZIP are added to public Git.


Integrity/source summary: [machine-readable resource evidence](../verification/OPTICAL_RESOURCE_CANDIDATE.json). This document publishes only paths, hashes and findings, not extracted game assets.
