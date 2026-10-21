# P6 ranged LB width correction —2026-10-21

The previous center-based model incorrectly interpreted XAxisModifier8 as a
half-width, producing a full16-unit rectangle. The corrected default is **full
width8 / half-width4**. This is source-based geometry, not a live server-edge
measurement; NPC hitbox, caster-radius range extension and cast grace remain
explicitly unverified. No speculative range recheck or radius inflation is added.

## Evidence

The bounded XIVAPI Action rows independently return CastType4, Range30,
EffectRange30 and XAxisModifier8 for BRD4244, MCH4245 and DNC17106.
The maintained replay analyzer at commit
`21555358de458a56afd0dc361327f8b3b62ebc43` explicitly converts CastType4's
XAxisModifier to rectangle half-width by multiplying by0.5; AIHintsBuilder
uses the same conversion in a separate runtime code path. This resolves the field-interpretation
ambiguity that a raw row or generated width comment alone did not resolve.

- [Replay shape conversion](https://github.com/awgil/ffxiv_bossmod/blob/21555358de458a56afd0dc361327f8b3b62ebc43/BossMod/Replay/Analysis/AbilityInfo.cs)
- [Runtime shape conversion](https://github.com/awgil/ffxiv_bossmod/blob/21555358de458a56afd0dc361327f8b3b62ebc43/BossMod/BossModule/AIHintsBuilder.cs)
- [BRD Action row](https://v2.xivapi.com/api/sheet/Action/4244?fields=Name,Range,EffectRange,XAxisModifier,CastType)
- [MCH Action row](https://v2.xivapi.com/api/sheet/Action/4245?fields=Name,Range,EffectRange,XAxisModifier,CastType)
- [DNC Action row](https://v2.xivapi.com/api/sheet/Action/17106?fields=Name,Range,EffectRange,XAxisModifier,CastType)

Original GDScript ray/cross-product implementation is retained; no upstream C#
code is copied. Existing target liveness, cast completion, damage timing and
post-cast lock rules are unchanged.

## Independent regression

New lateral probes at±4.001 and6 fail against the previous full16 model, with
exactly3 failures among55 assertions and no script errors. After correction,
±4 are included and the outside probes are excluded. These are center-model
checks, not claims about enemy hitbox collision at the same coordinates.
Post-correction4.7.2 results:55 assertions/0, LB602/0 with production locks,
P6 movement1614/0, Main controls20/0. The same physical positive matrices pass
with the narrower source-backed rectangle; no bot exemption or endpoint
teleport was added. Native Windows follow-up is recorded separately.
