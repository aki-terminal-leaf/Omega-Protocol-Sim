# Independent-practice timeline and cue audit (2026-10-22)

All20 menu drills now carry an explicit normalized clock contract. Reports export
`practice_clock`; the catalog no longer incorrectly labels every course as the
same slowed training window. At speed1.0, recorded simulation seconds are the
contract clock. Slow-speed controls scale wall time only. Starting another drill
resets its clock; it never automatically continues a different mechanic.

Core timings were checked against the four complete public captures already
listed in `fflogs_observations.json`, after checking every capture-file SHA256.
[Reproducible derivation](../../tools/audit_practice_timelines.py) writes only
action IDs and anonymous timing arrays/ranges; no player identities or raw logs.
[Finite observations](../../top/data/practice_timing_observations.json) retain
all four samples, unavailable event types, and inferred-anchor flags.
[Runtime contracts](../../top/data/practice_timelines.json) declare per-event
numeric tolerances. Live Main gates compare actual recorded impacts, not route
waypoints or fixture endpoint positions.

## Clock origins and core evidence

| Drill | T0 origin | Live source checks |
|---|---|---|
| Program Loop | First In Line / Looper application | towers |
| Pantokrator | Pantokrator cast finish | missiles, flames |
| Diffuse Wave Cannon Kyrios | Explicit six-second practice lead-in before first impact; original icon frame unmeasured | cleaves, spreads |
| Party Synergy | Party Synergy cast start | double_aoes, fire, laser, discharger, spotlight |
| Limitless Synergy | Limitless Synergy cast finish | arrow, bladedance, defense, flares, pitch, raidwide |
| Reconfiguration | Sniper debuff application | rings, sniper |
| Hello World | Initial Hello World Smells/Latent Sync application | towers, critical_error |
| Oversampled Wave Cannon | Oversampled Wave Cannon cast start | monitors |
| Blue Screen | P4 Wave Cannon visual cast start | proteans, stacks, rings |
| Run: Dynamis Delta | Initial Delta Near World status3442 application | laser, swivel, world |
| Run: Dynamis Sigma | Sigma Glitch/status application | cannons, discharger, towers, lasers |
| Run: Dynamis Omega | First clone stance tell;13.2s lead-in inferred, not independently measured | clone_aoes, blaster |
| Solar Ray | Solar Ray cast start | first, second |
| Cosmo Memory | Cosmo Memory cast start | memory |
| Cosmo Arrow → Cosmo Dive | Cosmo Arrow cast start | dive |
| Unlimited Wave Cannon → Wave | Unlimited Wave Cannon cast start | charge, proteans |
| Cosmo Arrow → Wave Cannon | Cosmo Arrow cast start | charge, proteans |
| Unlimited Wave Cannon → Dive | Unlimited Wave Cannon cast start | dive |
| Cosmo Meteor | Cosmo Meteor cast start | spreads, flares |
| Magic Number | First Magic Number cast start | magic_number |

## Repaired presentation/timing

- Party Synergy now includes memory signs before fake/genuine identification,
  the two M/two F opening, actual main-actor disappear/swap/reappear order,
  the visible Optical Unit, separate Fire/Laser/Spotlight/five-M snapshots,
  center female knockback and five outer male circles. Sword source models
  remain visible during their immediate impacts. [Detailed PT audit](P2_SYNERGY_TIMELINE.md).
- Solar Ray was incorrectly6+6 seconds and radius4: now a5-second cast,
  second hit3.2 seconds later and radius5, consistent with the action definition,
  community timeline and sixteen observed cast pairs. Vulnerability remains4s;
  a tank swap is still required. No damage or walking budget is relaxed.
- P3 monitor visual cast is10s; damage follows it. The independent snapshot is
  now10.1s (four observed damage packets10.053–10.073 from cast start).
- Initial Flame Thrower and initial P3/P4 ring cues now use their actual4s/5s
  cast windows instead of a shared2s preview. The unsourced P3 sniper-radius
  answer overlay is teaching-only; real debuffs and ring/arm cues remain visible.
- Source-colored vector PlayStation and Cannon signs now coexist in Sigma.
  P1 Cannon, P4 line-stack, Limitless and P6 Flare targets have graphical heads
  tied to their actual current assignments and removal times, independently of
  coaching labels and manual marks. No future second Cannon set is revealed early.
- Delta already had an invisible Optical proxy; the common documented eye
  reconstruction now renders it. Limitless also retains its north Optical source
  for the later Cosmo Memory. No duplicate Delta eye or P6 scenery substitution.
- Test commands now explicitly preserve fixed seeds. The UI still defaults to a
  fresh seed on Start, and R still reuses its encounter; tests must not accidentally
  randomize their advertised three fixed allocations.

## Precision limits that are NOT converted into passing claims

Nominal timers are not exact server frames. The source checks generally allow
0.10–0.25s around the observed finite range; HW permits0.4s because the nominal
21-second status cycles accumulate capture/tick drift. These tolerances are
**comparison tolerances**, not added gameplay grace periods. P3 transition/P4
retain their existing capture families rather than inventing a universal stream.

P1 Cannon's6s standalone lead-in and Omega's inferred first-tell origin are
marked unmeasured; interval evidence must not become proof of an exact icon frame.
Where public replay omits helpers, `unavailable_events` is explicit; the existing
P3 arm/cast family files remain their separate source. No zero events is treated
as evidence that a mechanic does not occur. Source contradictions, collision/
HP/mitigation limitations and incomplete regional routes in FIDELITY.md remain.

Optical Unit and the colored head signs are documented reconstructions. Original
models/backgrounds/fonts are retained where available; original AVFX animation,
shaders, every spawn family and sub-frame appearance/disappearance are not all
certified. A screenshot proves rendered wiring, not every game animation frame.

## Gates and platform separation

- Initial source smoke: all20 actual Main courses, one offered method /fixed
  seed17391 each, zero gameplay/timeline failures. This checks selectors before
  broadening; it is not the full100-method matrix.
- Observed-marker gate:31 checks/0, across P1/P2/P3/P4/P5/P6; includes simultaneous
  Sigma pair+Cannon heads, delayed/removal behavior, cast windows, one Delta eye,
  and no teaching-only radius leak. PT's separate320-family gate remains scoped.
- Expanded all100 offered methods ×three seeds and the partitioned motion gates
  are collected in the later final verification record; partial/timeout runs are
  not called complete. Source-only fallback gates prove logic, not original-asset
  pixels. Native final-pack renders and transport hashes are separate checks.
- Web remains the established test deployment. Its old900MiB software-browser
  failure is not repeated or turned into a browser acceptance claim. A native
  engine loading a Web PCK is a pack-content/render check, not browser gameplay.
