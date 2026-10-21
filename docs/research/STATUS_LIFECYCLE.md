# Encounter status lifecycle audit — 2026-10-22

Four public full-clear observations in `fflogs_observations.json`, original
Status.csv identities, and the primary linked encounter guides are independent
of strategy labels. The same combat effect has the same identity in every
regional route. A numbered assignment must still be explicitly granted, not
inferred by the HUD from a suggested destination.

## Corrections implemented

- P1 Loop: actual In Line 1–4 + Looper; successful tower consumes both; actual
  tower/Blaster recipients gain Twice-come Ruin; Blaster schedules HP Penalty
  after 0.65s for 9s. Numbering has no invented expiry timer.
- Panto: actual In Line consumed on the actor's missile; each numbered duration
  maps to observed distinct missile and shared-beam packet IDs. Missile / beam
  actual recipients gain short Magic Vulnerability; Cannons gain it as well.
- Limitless: actual Prey targets; successful Defense recipient gains Physical
  Vulnerability and Ruin; actual Pitch recipients gain Ruin.
- P3 transition: actual sniper statuses and hit-recipient Magic Vulnerability.
- Hello World: all smells, active bugs, latent conditions, regression effects,
  debugger rewards, short Ruin and magic-vulnerability aliases have identities.
  Debuggers are permanent presentation, not a 9999-second invented countdown.
- P3 monitors: actual loaded side; P4 proteans and successful shares now grant
  real short Magic Vulnerability to their observed hit lists.
- Delta: use P5-specific Code Smell IDs 3440/3504 rather than HW 3503/3441.
  Regression IDs come from actual paired-tether configuration 1672/1673.
- Sigma: Glitch/Looper/tower Ruin and actual World-hit Dynamis/vulnerability.
- Omega: World holders have actual first/second In Line; consume on the actual
  initial pulse. Monitor Ruin, Blaster HP Penalty and World rewards retained.
- P6: actual tank-job LB, Dynamis/Brilliant availability and spending, Magic
  Number application and actual healer-LB cleansing remain authoritative. Actual LB
  cast completion transforms Brilliant into Spark (3448), retained through refund
  and lost on death. Independent P6 combo courses explicitly start post-Memory
  with Brilliant, rather than incorrectly displaying Quickening stacks.

Definitions cover runtime aliases without conflating Mark of Mortality,
Thrice-come Ruin, Twice-come Ruin or generic knockback resistance. Raw packet
status IDs override generic names. Unknown identities remain text, never an
unrelated guessed icon. Source-only snapshots do not prove full damage/healing,
job mitigation, every original spawn or server timing precision. The existing
fidelity backlog remains open until separately measured and verified.

References: [primary P1 guide](https://ffxiv.tuufless.com/elemental/top/01_omega/),
[observed durations](../../top/data/fflogs_observations.json),
[party presentation](../development/PARTY_STATUSES.md), [full scope](FIDELITY.md).

## Verification checkpoint

Pinned4.7.2 Linux: P1 1746 assertions/0; new actual-status lifecycle13038/0
(on Windows;13006 before combo-entry assertions), party107/0, P4 2454/0
including560 walking cases; Windows P6 LB604/0 and actual controls20/0.
Expanded Main sweep found299/300 full courses passing; Aether Omega seed43
reveals a physical coincident-ray handoff failure. A broad steering prototype
passed that one case but regressed48 larger Omega checks and was rejected.
The status foundation does not claim that known route issue resolved. All
failed logs are preserved privately; subsequent route work must pass both the
focused reproducer and the broader geometry/physical matrix. Local monolithic
300-course process was terminated under memory pressure, not counted as a pass;
Windows source gates ran in an isolated project. No exported-build acceptance
or all-region/server-fidelity completion is claimed by this checkpoint.
