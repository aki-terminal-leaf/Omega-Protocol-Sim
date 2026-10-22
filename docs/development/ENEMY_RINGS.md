# v0.3.7 enemy target-ring radius and facing

## Sources and world scale

Captured actor radii come from the pinned BossMod TOPEnums snapshot:
https://github.com/awgil/ffxiv_bossmod/blob/d409d336edb909b71b25fa8761f88667f5bdce1b/BossMod.Ultimate/Endwalker/Ultimate/TOP/TOPEnums.cs

BNpcBase Scale / IsOmnidirectional flags were independently read from XIVAPI,
client version0874aee069e1e7c4, schema e773c41a90aed788cf4c1c48469fa85618ef01fb.
These are client/captured-community data, not a fresh server packet recording.
Exact URLs, NPC IDs, units and source digest are in top/data/enemy_ring_profiles.json.

| Enemy form | Ring radius (yalms) |
| --- | ---: |
| P1 Omega / beetle helper |12.006|
| Active full-scale Omega-M/F, P5 M/F |5.010|
| P3/P4 Reconfigured / Final Omega |12.502|
| P6 Alpha Omega |13.000|
| Rocket Punch variants |1.500|
| Arm units |1.680|
| Rear Power Unit |6.720|

P2 captures contain a3.000-5.010 range. Current full-scale models use5.010;
explicit per-entity hitbox_radius supports the smaller captured state without
rescaling the mesh. We do not pretend this proves every dynamic P2 transform.
All registered NPC rows have IsOmnidirectional=false, retaining the rear90 gap.
The circle is procedural display geometry, not the original game target-circle
texture/selection system. It does not modify collisions, damage or melee range.

## Direction convention

Original SqPack anatomy faces local+Z: M/F eye bones are ahead of j_kao, P1 jaw
landmarks are at positiveZ, and Alpha eye bones are atZ0.373 versus headZ0.021.
Rotate only the imported GameMesh child180 degrees once. The scene root, ring
front triangle and Rules now share north0 / clockwise-positive headings.
Remove the former per-stage180-degree compensation, preserve inward M/F poses,
read both facing and the legacy P4 face field, and consume P1 route boss_facing.
Large-radius arrow/stroke dimensions are capped; player0.8 rings keep their size.

## Checks

-340 enemy radius/mesh/front-angle checks, covering12 forms and eight headings,
  original and procedural models, P1/P2/P4 live scene wiring and explicit P2 radius.
-19 existing player-ring and25 original P3-effect checks pass:384 assertions total.
-12 original enemy rigs and seven equipped player presets pass animation integration.
-Actual native rendered P1/P2/P3/P4/P6 captures exist. A cumulative llvmpipe capture
  exceeded180 seconds after four captures; its failure is retained, then the same
  guarded stage resumed with an isolated P6 process, which passed. No silent retry.
-This is native rendering and export-data verification, not Web gameplay certification.

![Actual native P1/P3/P6 ring comparison](../images/top-v037-enemy-rings.webp)
