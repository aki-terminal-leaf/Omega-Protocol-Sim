# Configurable marker editor (development increment)

This follows the shipped v0.3.3 manual markers. It is a new development-branch
increment, not an alteration to previously released binaries.

## Implemented

- Save up to32 named waymark layouts, load a draft, copy under a unique name,
  explicitly replace a name, and remove a saved entry. Saving/removing a library
  entry never changes active battle geometry, actor positions or runtime state.
- North-fixed visual draft editor with A/1/B/2/C/3/D/4 and original color pairs.
  Drag individual enabled marks; drag clamps inside radius19.8. Whole-layout
  rotation, generic/outer/empty presets and JSON coordinate editing coexist.
- Invalid JSON/schema/coordinates or full/duplicate-name libraries fail without
  corrupting existing layouts. Fractional/string/bool schema values are rejected;
  JSON's numeric1.0 remains valid. Apply retains the existing report archive and
  practice-restart policy; closing/canceling the dialog leaves the active layout.
- Rebind panel/self/next-free/clear to a nonconflicting set of unmodified keys.
  Movement/action keys are excluded, duplicate choices are rejected, Ctrl+1–8
  retains direct self attack-number marks. Focused text entry and pauses do not
  accept gameplay marking. Old keys cease their previous action after rebinding.
- Actual key settings and named layouts persist. Config writes merge existing
  sections; an invalid stored library is preserved until explicitly replaced.
  Practice reports record the actual key map alongside existing layout snapshots.

## Verified on pinned Linux Godot4.7.2

- New library/Main integration:35 checks/0 failures.
- Existing manual marker/ownership/HUD/retry:71/0.
- Presentation27/0, real input routing19/0, P3 effects17/0.
- Real OpenGL viewport-routed mouse drag, release, camera-capture exclusion,
  custom keys and popup:9/0, with actual dialog screenshots inspected.
- Pixel QA caught and fixed first-open transient wrapping that placed the OK
  button offscreen. The final860×610 dialog and its confirmation button fit
  inside1440×900; no native Windows/Web exported QA is implied by Linux proof.
- Tests use isolated XDG data directories; operator settings are not overwritten.

## Still outside this increment

No new regional preset is invented. Strategy-specific marking profiles, all
manual/assist/none modes, bot responses to actual marks and their source rules
remain in [MARKERS_PLAN](MARKERS_PLAN.md). This increment does not change combat
selection, AoE geometry, timing or the AVFX reconstruction/player distinction.
