# DSR player camera reference and TOP presentation

Scoped to arena.gd and the dedicated camera test. Main fullscreen/HUD
integration and exported-platform pixel QA belong to the parent task.
No original application or saved user configuration is loaded.

## Reference and scale

Read-only references: scenes/characters/player.tscn,
scenes/characters/player_movement_controller.gd, scenes/characters/player.gd,
and scripts/autoload/saved_variables.gd. The GPL controller is a behavior/math
reference; its controller code is not copied into the MIT arena. No original
binary identity, animation, or shader equivalence is claimed.

Source hierarchy: player -> TwistPivot -> PitchPivot -> SpringArm3D -> Camera3D.
Godot str_to_var decodes the serialized pitch to **-10 degrees** local X, giving
**+10 degrees elevation**. TOP keeps its public positive-elevation camera_pitch and
applies its negative to the native pitch pivot. Yaw and camera-relative
movement retain their existing axes/signs.

| Parameter | Original | TOP |
| --- | ---: | ---: |
| Character model scale | 1.25 | 0.55 |
| Unit ratio | 1 | 0.44 |
| Pivot height | 3.5 | 1.54 |
| Default distance | 22 | 9.68 |
| Maximum distance | 30 | 13.2 |
| Minimum distance | 0.1 | 0.044 |
| Wheel increment | 0.5 | 0.22 |
| FOV | native 75 degrees | 75 degrees |
| Near plane | native 0.05 | 0.022 |

The source scene's temporary arm length is 5; the controller initializes from
saved settings whose default is 22. TOP follows the selected ground position
plus the existing rendered actor-root offset (0.02) and jump height. It uses
a translation-only surrogate player attachment independent of actor facing
and animation. State updates change the target immediately; processing
recomputes it without interpolation, smoothing, or accumulated drift.

## Native camera and API

Uses Node3D yaw/pitch pivots, SpringArm3D, Camera3D, SphereShape3D, and a
camera-only StaticBody3D/WorldBoundaryShape3D floor. Sweep radius: 0.04;
margin: 0.025. Collision bit 20 is reserved locally for this camera sweep;
the floor has no collision mask. This is a presentation safety plane at y=0,
including beyond the arena edge, not judge or actor collision. Full +/-90 degree
pitch remains available. A downward arm shortens through native physics;
no look_at singularity or actor correction is used. Wait for physics frames
before inspecting arm endpoints.

Existing fields and movement_vector, orbit, zoom, reset_camera, set_follow,
and update_camera remain. zoom(amount) accepts world units.
zoom_steps(steps) uses positive steps outward / negative steps inward:
0.22 per player step, 2 units in overview. Main should use this wheel API.

set_overhead(true) explicitly enters the arena-centered prior high view:
FOV 55 degrees, elevation 0.91 radians, distance 44. It saves player yaw/pitch,
distance, and follow preference. set_overhead(false) restores them.
Overview disables floor sweeping because its pivot is at floor center.
reset_camera() always restores default player framing and follow=true,
including from overview. Main should synchronize checkboxes after reset
and use the mode setter rather than directly toggling overhead.

## Cue presentation choices

Cue sizes are TOP readability choices, not exact original UI reproductions.
In player mode, role/status and stage/boss labels use a factor clamped from
0.35 to 1, based on camera-to-cue distance / 30. This reduces nearby oversized
text while retaining larger distant cues. Text and status/icon selection
are unchanged. Actor labels remain at 2.3 plus jump height; status, debuffs,
and World icons stack at 2.8, 3.3, and 3.9 plus jump height. Debuff widths
are one world unit times the factor; World widths are two, normalized by
texture width. Debuff spacing scales by the same factor.
Overview restores original label sizes and vertical stacking with normalized
icon widths. Required status cues are retained. The subsequent party-status increment
hides answer/guide hints during normal practice; see PARTY_STATUSES.md.
Floor waymarks, AoE geometry, tethers, actor facing, mechanics, speed, Sprint,
and jump simulation are unchanged.

## Verification

Pinned executable:
D:/Dev/OpenClawCodexBridge/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe

Import: --headless --path top --editor --import
Test: --headless --path top --script res://tests/camera_fidelity.gd

Use Python subprocess timeouts (360 seconds import, 120 seconds test) and
reject SCRIPT ERROR, Parse Error, and Compile Error even on exit zero.
Redirect APPDATA and LOCALAPPDATA into top/.godot/local-user for sandboxed
engine caches. Do not share versioned .godot caches.

The test decodes the original serialized pitch without instantiating its
scene. It checks actual camera transforms after physics frames, body sample
projection, translation/jump/selection, variable-delta drift, yaw/movement
axes, zoom limits, floor shortening at negative pitch, both vertical
endpoints, overview/revert/reset, cue content and icon IDs using synthetic
textures, and actor JSON immutability. This is geometric/native physics
evidence, not screenshot or Windows/Web export evidence. Main wiring and
real-pixel readability remain parent validation responsibilities.

### Local result (2026-10-21)

Godot 4.7.2 import exited 0; camera_fidelity reported **60 checks, 0 failures**
and exited 0. Neither final run contained SCRIPT ERROR, Parse Error, or Compile
Error. The Windows environment reported a root-certificate-store error. The
first import also encountered denied external editor cache writes; redirecting
APPDATA/LOCALAPPDATA into the worktree removed those cache errors. Recreated
untracked test UID sidecars were removed to preserve the three-file scope.
No commits, pushes, merges, deployment, original app launch, or Main edits.

Parent integration: fullscreen reuses the existing SubViewport; setup pauses and
resumes only its own pause. LB target/ground controls bind the original action
widgets. Parent Linux camera60 and Main presentation24 checks passed with no
script/parse/compile errors. These are not exported Windows/Web pixel QA.
The subsequent status-only party/failure-review UI requirement is a separate
work item; this increment does not claim it completed.
