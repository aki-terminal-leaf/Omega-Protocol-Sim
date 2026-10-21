# P3 Hello World fidelity audit

Implementation on isolated base `cb46a6dc5a5b58ef415f10f10cf796d8d8379152`, 2026-10-21. No commit, push, merge or deployment. The existing encounter collection is not changed.

## Integration and APIs

- `hw_courses.gd`: `append_hw(ctx)` selects four independent eight-way orientations and starting rot colour; `append_family(ctx, orientations, colour)` supports deterministic replay. Context supplies the existing encounter builder's rng, order, profile, beats, positions, labels and beat method.
- `hw_patterns.gd`: event schedule, real tower geometry, formation realization and route registry loading.
- `hw_runtime.gd`: `begin(beat,state)`, `tick(actors,previous,state,dt)` and `sync(beat,state)`. Three corresponding lines are the entire modification to `statuses.gd`, alongside P6 hooks.
- `hw_routes.json`: source registry, guide distinctions, capture-derived geometry, timing and explicit uncertainty provenance.
- `tests/hw_fidelity.gd`: standalone new fidelity gate. Existing tests are untouched.

**Parent integration is now complete; see the parent verification below.** The original integration requirement was: Append `HW.append_hw(ctx)` after encounter collection. This base's Main moves ordinary bots at 11 yalms/sec and only special-cases `p6_route`. Parent must give `hw_route` the same legal 6 yalms/sec walking budget in both live movement and checkpoint/oracle movement. Merely wiring the append call does not complete live integration. This change intentionally does not impersonate a P6 route or edit Main. The HW runtime rejects excess movement; an explicit `motion_allowances` budget may permit Sprint, capped at 7.5 yalms/sec. All generated courses and movement gates use walking at 6.

## Mechanics and geometry

Four real towers per wave have centre radius 14 and circle radius 6, rotated in eight possible orientations. Adjacent pairs have the two colours. Radius 6 is corroborated by the public behavior reference and action 31583/31584 descriptions; captured helper positions were independently validated against interpolated player positions and actual recipients. The registry includes all 64 tower recipient validations across four clears, rather than treating potentially stale helper resources as authoritative.

Nominal timeline relative to initial Smells: Smells 3 seconds, rot 27 seconds, bug 21 seconds; towers at 24/45/66/87. All eight latent Sync last 69 seconds; initial Local latent Defect lasts 27. P3 Local/Remote IDs 3529/3530 activate one second before each tower and last 10 seconds. P5 IDs 1672/1673 are not used. Captures have successive tower intervals 21.01–21.085 seconds and Critical Error 21.127–21.181 seconds after the fourth tower; the simulation uses nominal Critical Error 108.2.

Actual swept contacts spread/overwrite rot through existing Statuses semantics, respecting Debuggers. Genuine expiry grants the carrier's relevant Debugger, clears its latent condition and resolves the actual blast. Overflow radius is 20, Sync and rot radius 5. Sync must hit at least two. Blasts propagate bugs through actual recipients; one-second Magic Vulnerability prevents overlapping damage. Patch applies two ruin stacks with a one-second window, matching captured stack count 2 and roughly 960ms durations. Two patches too close fail. Expired regressions and latent statuses fail genuinely.

Critical Error checks actual Overflow Debuggers on all eight actors. It does not inspect route labels. A missing immunity permits a real 21-second Overflow and fails; the course runs to 130 seconds so that hazardous expiry is also exercised. Healthy Critical Error consumes Overflow Debugger. No expected course position grants or repairs a status.

The runtime uses chronological event boundaries and at most 25ms swept subdivisions. Pending events, history and durable state are JSON-native. Stable actor/name expiry ordering and a nanosecond clock make serialization/retry deterministic; this ordering is not claimed to reproduce an unknowable simultaneous server ordering.

## Five source-derived route families

Numeric waypoints are legal geometric realizations of source semantics, **not official numeric guide coordinates**. Universal mechanics do not make every guide identical. Actor assignment follows debuffs; Toolbox `dps1..4` labels are not assumed to equal application D1..4.

| Family | Ordinary handoff distinction | Fourth round distinction |
| --- | --- | --- |
| Elemental | Remote clears outward; old carriers clear | Local first, Remote inward last; Sync holds, Local finishes inside |
| Aether | Remote clears outward; old carriers clear | Local first, Remote outward last; Sync clears outward |
| LPDU | Remote clears outward; old carriers clear | Explicit GREEN FIRST then BLUE LAST; no Nisi transfer; outward clearance |
| CN Moogle | Old carriers hold marker/inner tower positions; Remote passes outward | Local first, Remote last; Sync holds, Local finishes inside; no transfer |
| KR 09STOP | Old carriers hold; new Remote returns inside boss | Local first, Remote inward last; Sync clears farther outward; no transfer |

Sources were inspected beyond a generic universal label. Initial positioning, colour-side assignment, handoffs, old-carrier clearance, priority and fourth-round instructions are recorded in the JSON registry. Generated transitions stage carriers on separate radii, wait for real rot expiry, and rotate at legal walking speed. Ordinary Local collection is staggered before Remote collection to respect actual existing bot-goal vulnerability pauses. Break order remains Remote then Local; fourth order reverses.

## Primary and supporting sources

- [Elemental phase guide](https://ffxiv.tuufless.com/elemental/top/03_omega_reconfigured/): full text and initial, ordinary and fourth-round diagrams. The supplied older hello_world URL is not the current phase URL.
- [Aether PF guide](https://www.thepfstrat.com/u/top), Dylan public Toolbox `243183080764761`, full HW steps 11–28.
- LPDU public Toolbox `702399575985961`, all 19 steps, including explicit fourth-round green-first/blue-last. Both complete public semantic JSON exports were read from `research/top-v03/fflogs/western-guide-toolbox-data.json` read-only. Canvas/body coordinates use top-left plus half-size and scale 40/15 only to interpret diagrams, not to claim official game coordinates.
- CN poster and repository `CN_POSTER_AUDIT.md` / `regional_route_spec.json`, supplemented by the [original CN phase video](https://www.bilibili.com/video/av740517066/?p=3). Inspected HW demonstrations from approximately 450–645 seconds, including held old carriers, outward Remote pass, Local convergence and no-transfer fourth round. Poster alone does not establish all these details.
- [KR 09STOP workbook, P3 sheet](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1826471436): rows 118–304, including ordinary inward Remote / held old carriers and fourth-round green-first, inward blue and outward Sync.
- Read-only community `P3HelloWorld.cs`, `TOPStates.cs`, `TOPEnums.cs` research references provide behavior cross-checks. This implementation is original GDScript, not copied licensed C#.
- Four complete captured clears: `LKMGRJTzgY9HFynk/2`, `3GW2hjTNk91FZwcK/9`, `1bX86aKrVRwLWfTC/19`, `Vyq4AcJKZjkFQBpG/32`, under `D:/Dev/OpenClawCodexBridge/research/top-v03/fflogs-evidence/`. Manifest SHA256 and all 28 decompressed JSON file hashes were checked against manifests. The registry preserves anonymous derived positions, timings and hash provenance, not player identities. Original corpus: 4,875 NPC casts and 175,853 replay events.

## Validation gates

Exact executable: `D:/Dev/OpenClawCodexBridge/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe` (Godot 4.4.1 stable). Run headless with `--path top --script res://tests/hw_fidelity.gd`; append `-- --quick` for the unit/evidence/serialization gate. Use a writable absolute `--log-file` in restricted environments.

- Full HW gate: **1,088 assertions, 0 failures**. Covers all five families, both starting colours, all eight orientation families independently in every wave (320 combinations), constant/mixed orientations (32), and reversed/cyclic arbitrary actor assignments across families and colours (80). Each principal wave matrix requires actual 16 tower judgments, 32 blasts and all eight Critical Error blocks, not empty preview geometry. Simulation uses existing `Interactions.bot_goal` and legal 6/s movement.
- Latest quick gate: **2,002 assertions, 0 failures**, after expanding reachable two-actor contact coverage to 1,792 directed combinations and adding explicit Sprint-budget tests. The full movement matrix preceded these final contact-test/budget additions; it was not rerun afterward. Ordinary generated movement remains 6/s.
- Existing Rules: **196 assertions, 0 failures**; calibration: **16 assertions, 0 failures**; P6 fidelity: **1,334 assertions, 0 failures**.
- JSON restores tested at 23.5, 25.6, 46.5 and 86.5 with active bugs/paired lines; repeated previously rendered KR course remains deterministic.
- Negative gates include actual opposite infection, simultaneous opposite-carrier rejection, swept accidental passes, Debugger blocking, expiry before crossing, too-late Local, too-early Patch stacking, incorrect Sync count, latent expiry, and Critical Error lacking real Debugger with subsequent real bug expiry. Failures were fixed rather than suppressed.

Godot emitted an environment root-certificate warning. The last quick run also warned that a relative log path could not be created; script execution and all 2,002 assertions nevertheless completed with exit code 0. No test failure is hidden by these environmental diagnostics.

## Remaining uncertainties and boundaries

1. Exact P3 tether thresholds are not proven by public numeric source. Thirty-two paired removal interpolations suggest Local 10 / Remote 7; ordinary Local samples span approximately 7.93–10.45 and Remote 7.48–8.94 because player samples bracket the event. Existing generic 3/30 values contradict those observed positions. HW uses explicit provisional 10/7, records provenance in state and timeline, and does not alter global parameters.
2. Contact radius 1 and same-colour timer-preservation policy are explicit inherited parameters. Late same-colour refresh is unverified. Ambiguous simultaneous opposite carriers are rejected under explicit policy; no server processing order is asserted.
3. Interpolation and nominal timing are approximations with samples/gaps retained in the registry. Waypoints demonstrate legal realizations, not exact reproduction of every observed player path.
4. Coverage is representative across independent wave orientations, not exhaustive over every 8^4 sequence and every multi-party contact state. Exhaustive contact claims apply only to the enumerated reachable two-actor states, plus targeted multi-actor hazards.
5. HP, shielding and mitigation budgets are not simulated. CN fourth-round healing advice is documented by source but not turned into invented HP judgments. Looper and other phases are outside this HW runtime.
6. Live parent integration and its final end-to-end gate are outstanding, particularly the Main walking-budget change described above. No Encounters, Main, Rules, Interactions, globalparameters, strategyJSON or existing test was edited.

## Parent integration — 2026-10-21

The parent has now wired `HWCourses.append_hw` through Encounters, preserved the independent P1/Delta/Sigma/Omega hooks, added all five per-mechanic methods, and shared normal6/s movement in both live Main and checkpoint/oracle code. The exact integrated code passed the independent full HW matrix: **2,434 assertions, 0 failures**, including the final contact/Sprint additions. Actual Main retry, checkpoint, report and live full-course gate: **72 assertions, 0 failures** (`hw-parent-stateful.log`). All five per-method native UI courses (seed17391) also passed with zero failures. Quarter-second steering was subsequently packed into three paths with the same waypoint cadence; the exact packed code again passed2,434full assertions and2,002quick assertions, with zero failures. The earlier ungrouped15-course native run timed out at8minutes and is not counted as a pass. These supersede the integration-pending status above, not the parameter uncertainties. The remote bridge full acceptance timed out at120seconds; it was not treated as a pass. Parent full-matrix evidence: `hw-parent-full.log`.
