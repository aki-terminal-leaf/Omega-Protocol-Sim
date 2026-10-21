# P2 Limitless Synergy — implementation checkpoint (2026-10-21)

Five selectable source-based route families: Elemental, Aether, LPDU,
CN Moogle and KR 09STOP. Shared mechanics judge actual positions and owners;
coaching assignments never force a tank to acquire a particular line.

## Live sequence

- Arrow locks an actual non-tank position at cast start: width 10, length 100.
- Both width-90-degree, radius-100 Bladedance cones follow actual holders,
  including a contact occurring in the final physical movement step.
- Beyond Defense selects one of the two actually closest players (radius 5).
  The subsequent source jump is sampled independently from its old position;
  Pile Pitch reads the actual closest player. Ruin and vulnerability persist.
- Three Flare packets record actual recipients and distances over radius 100.
  No fabricated safe circle substitutes for HP, shields or mitigation.
- Eight event types are packed into a 38.2-second independent practice course.
  All durable route/contact state is JSON-native.

## Source audit and limitations

Four complete public FFLogs captures and all 28 referenced hashes were checked.
The public CN video av740517066, part 2, was visually reviewed at 14:30–22:30:
MT upper-half / ST lower-half sources, A/C outward pulls, the north/south Arrow
exception to boss left/right, actual Defense recipient leaving, the other tank
rejoining, and stacked three-Flare mitigation. Other families and source URLs
are recorded in `top/data/p2_limitless_routes.json`.

The public closest-one Pitch reference conflicts with closest-two wording in
some Elemental/KR text. Default mechanics use the observed closest-one family;
forced rank-one variants are explicit stress fixtures, not regional rules.
The twelve Arrow / thirty-degree source families form a training superset,
not a claim that all server spawn RNG has been observed. Exact Flare falloff,
party HP, mitigation and damage survival are not implemented or scored as solved.
Source registry `complete: false` remains intentional.

## Parent validation

- 552 assertions, zero failures: all five routes, four source families,
  twelve Arrow orientations, 56 Flare assignments and negative cases.
- Actual Main/UI runner: five methods × three seeds = 15 courses, zero failures.
- Shared regression checks after contact-pass integration: interactions 21,
  rules 196, retained Loop cases/navigation restore 702, continuous P5 15;
  all zero failures and no script/parse errors.

Evidence lives outside source under the parent artifact directory:
`limitless-source-assigned-full.log`, `limitless-five-methods-native.log`,
`post-limitless-{interactions,rules,p1_fidelity,p5_continuous}.log`.
These checks do not certify all 20 mechanics, Windows/Web exports or live-server HP.
