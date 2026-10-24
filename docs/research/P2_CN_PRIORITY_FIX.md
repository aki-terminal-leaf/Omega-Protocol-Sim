# P2 CN / Moogle NPC pair priority correction

Owner report (2026-10-24): D2 and D4 have the same glyph, but D4 is assigned
left. This regression is reproduced in the CN / Moogle method with seed 2
(Mid/circle) and seed 6 (Remote/cross).

## Scoped contract

For CN NPC guide routes, within each same-glyph pair use the existing role
priority **H1 > MT > ST > D1 > D2 > D3 > D4 > H2**. Higher priority takes
left **facing the Optical eye**. Thus D2 takes left and D4 right in the report.
This is an owner-reported product contract, not new proof of every CN guide
branch. Original glyph assignment, `ctx.order`, RNG calls, shape-row order,
remote reversal and stack-flex policy are not changed. The post-sorting
stack groups use the corrected guide route.

This only corrects NPC route priority. It does not implement the outstanding
CN public glyph-receipt workflow, certify full-guide conformance, or require
the human player to stand on an exact guide coordinate. Actual attack,
Buff/Debuff and death rules are unchanged. Other four methods are unchanged.

## Source verification

With the pinned Godot 4.7.2 engine:

```sh
$GODOT --headless --audio-driver Dummy --path top --script res://tests/synergy_cn_priority.gd
$GODOT --headless --audio-driver Dummy --path top --script res://tests/synergy_cn_priority_main.gd
```

The first gate checks all four pairs in 128 CN seeds (512 pairs / 1,024
assertions). Before the fix, 257 pair-priority assertions fail. The second
uses actual Main in NPC-demo mode for complete seeds 2 and 6: all four
pairs sorted correctly, attacks/status checks clean, sampled within-beat walking bounded at
6m/s, and the real 13m Discharger impulse checked separately. NPC demo is
not player/manual, browser or native-desktop acceptance.

The retained private baseline/candidate comparison covers 640 full course
outputs (128 seeds × five methods): all 512 other-method outputs equal;
all CN non-position data and the first four beats equal. Only later CN
NPC guide positions differ. No build/release version is changed here.
