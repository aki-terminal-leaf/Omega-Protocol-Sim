# Callable source scene-state primitives

This foundation decodes C018 and C196 only. `decode_source_scene_events.py`
provides `records`, `decode`, and `SceneState`; `source_scene_events.gd` is a
standalone RefCounted with `begin(record, resolved_target, epoch)`,
`update(native_event_relative_clock, resolved_target, epoch)`, and `reset()`.
No engine node, host time, FPS, scheduler service, public UI or media is involved.

Each record carries the original source event and the namespace tuple: CUTB
SHA256, TMLB offset, TMAC ID/offset, TMTR ID/offset, event ID/offset. Raw framing
and SHA256 are checked. Unsupported tags and selectors fail explicitly.
Caller resolution must provide `verified`, nonempty `token` and `context`,
matching `namespace`, and `epoch`. This is a caller assertion, not runtime target
discovery. Remap invalidates retained state. Failed begin discards prior state.

C018 requires explicit `current_native_scale`. Position remains in native axes;
Euler radians produce Hamilton XYZW qZ*qY*qX. The result is an explicit native
transform reference, never a replacement Godot transform. Raw words, archived
scale and derived values remain available. Python libm/Godot trig are finite
reference arithmetic, not native sinf bit equivalence.

C196 selector 0 emits CutActionTimeline 792 row 12 then 10; selector 1 emits
13 then 11. Initial rows mean event/event_bt_deactive and event/event_bt_active;
later rows mean normal/idle and battle/idle. This emits requests, not playback.
Initial ratio is rounded f32 with finite/infinite/nan status and raw scalar bits.
No NaN JSON value, division exception, clamp or invented opacity is used. Native
MXCSR and NaN payload equivalence remain unproved. Raw numerator/denominator
bits survive in source words even when derived NaNs are canonicalized.

Descriptors contain typed field writes and byte validity masks. Initial bytes
20..23 and 25..27 are unknown; later bytes 2..3 and 10..11 are unknown. Later
opaque argument is at **0x14**, with u16 writes at 0 and 8, u64 at 12. These
follow PARENT_CORRECTIONS.md, overriding frozen reference defects. Only explicit
caller state bytes receive the 0x10/0x20 bit update; no pointers are invented.

The later gate is strictly greater than f32(signed i32 threshold). An emitted
request records an attempt, not load success. Duration 1 never expires it.
Queued type 0x20 includes a present row override and bypasses generic parsing;
the payload is never parsed as C040. Backward/nonfinite clocks are rejected;
reset and a caller inspection epoch explicitly restart state. No idle-loop,
blend, clock-unit or scheduler termination behavior is claimed.

Run from this worktree:

```powershell
python -B tools/asset_lab/run_source_scene_events.py --manifest D:/Dev/OpenClawCodexBridge/probes/top-source-scene-events-50893/inputs/inputs.json --manifest-sha256 234f612c27cd4b68a34a7e47618af72863d5c87a06914267c7065b298b69dd96
```

The runner verifies nine inputs and 64 protected raw pins before and after,
runs only the new Python tests, then stages exactly the new Godot implementation
and test script in a generated minimal project. It uses the accepted pinned
Godot 4.7.2 executable and existing Windows Job Object runner: at most 90 seconds
per engine process, 1.5 GiB job memory, 8 GiB free RAM floor, 120 seconds total.
Receipts, logs, cases, numeric outputs and summary are retained in a unique
ignored `top/assets/official/top-source-scene-events-50893/outputs/run-UUID`.
Missing results and Godot script/parser errors fail the gate.

Actual 41 C018 and 24 C196 records from 15 TMLBs are distinguished from synthetic
negative/numeric cases. Independent sequential vector rotations test C018.
Parent numeric counterexamples and descriptor padding are explicit assertions.
Remaining gates: selected factory targets, basis/units/parent conversion, native
execution equivalence, scheduler integration, exported platforms and visual
acceptance. A numeric pass does not close TOP96 or raster acceptance.
