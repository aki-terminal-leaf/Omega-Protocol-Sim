# Regional route audit — research only

Audit date: 2026-10-21. Catalog base: `55bbc64`.

**100 cells are recorded (20 mechanics × 5 communities), but the requested exhaustive route audit is not complete.** The JSON contains verified rules, concrete relative goals and branch decisions where obtained, alongside explicit unknowns. No route is marked implemented or exhaustively verified. Unknown fields must never fall back silently to another community.

Only `docs/research/REGIONAL_ROUTE_AUDIT.md` and `top/data/regional_route_spec.json` are authored by this task. No runtime, existing profile, test, commit, push, merge, deploy, original checkout, or game interaction is part of this work.

## What the evidence changes

- **KR is not an Elemental alias.** KR Party Synergy uses O–triangle–square–X, full remote reversal and north-stack flex; Limitless assigns west/east tank tethers; Delta adjusts the outer fist pair and has a different final World geometry. KR P6 stacks Wave Cannon south and starts the first party Arrow group southwest.
- **CN is not an Elemental alias.** Its macro puts D3/D4 at the sides for P1 cannons, gathers A for P2 arrow bait, gives a P6 MT-north/ST-east/H2-south clock, and swaps only MT/D3 for meteors. The full movement/branch rules remain unverified without the tall diagram and videos.
- **Aether P6 is not source-empty.** The WIP page links the 111-step Saus full toolbox. Its steps51/69 explicitly stack SOUTH; step111 provides both Tank→Healer LB sequences. The old page heading cannot justify a universal lack-of-evidence claim.
- **LPDU P5 was read, not inferred from its label.** All65 linked toolbox step descriptions were traversed. It sends the first-break blue pair to Beyond Defense in Delta, specifies monitor eligibility, and gives final tether/World ring references.
- **LPDU P6 has concrete distinct layouts.** All3 raidplan slides were visually read. WC1 has OT east/H2 south; WC2 is a four-quadrant pair layout; meteors swap both MT/R1 and H2/OT.

## Exact evidence obtained and limits

### elemental

- Obtained: Homepage EN/JP macros and full text of all8 phase pages.
- Visual inspection: Homepage textual diagrams read; phase image geometry not exhaustively inspected.
- Not obtained: Original linked PoVs and animated phase figures not frame-audited.

### aether

- Obtained: PF page; Saus Sigma all40 step headers/descriptions; Saus Omega all44; P6 all111 step titles plus selected substantive steps3,19,20,43–45,47,48,51,52,55,65,66,68,69,85,86,97,98,100,101,103,104,106–108,110,111.
- Visual inspection: P6 step48 clock diagram read after closing ordinary ad overlay.
- Not obtained: Other P5/P6 figure geometry; linked videos; early phase toolboxes.

### lpdu

- Obtained: Entire raw markdown including post7.0 changes; all65 P5 toolbox step headers/descriptions.
- Visual inspection: All3 linked P6 raidplan slides read.
- Not obtained: P1 raidplan; P2/P3/P4 linked toolboxes; full LPDU video and mitigation workbooks.

### cn_moogle

- Obtained: QQ macro rendered in normal browser; full route macro on pages1–2 and functional marker section into page3 read. Bilibili author reference text read.
- Visual inspection: QQ route diagrams pages1–2 visually read; Bilibili displayed cropped P5 cover, not full tall guide.
- Not obtained: Full tall reference diagram and upper/lower video contents; no transcript or video-route verification claimed.

### kr_09stop

- Obtained: All8 phase tab texts read through public htmlview/sheet; tab gids indexed. Some long outputs truncated, explicitly reflected in unresolved fields.
- Visual inspection: Selected diagrams P1 row103, P2 row166, P3 row314, P4 row15, Delta row338 both cleave sides, Sigma row145 and one row287 pattern, Omega row183 and row229, P6 row121.
- Not obtained: Every animation frame, all alternate diagram rows, complete macro tab, composition mitigation tabs, independent manual-world article6982 (web decoding failure).

## Evidence identity and reproduction

All links in the JSON are public primary guide URLs. Google Sheets uses stable workbook `gid`, row numbers and zero-based HTML image indices rather than copying expiring image URLs. For example, KR P6 `gid=473115449`, row121, image4 is the clockspread actually inspected. View a sheet through `/htmlview/sheet?headers=true&gid=...` under the same workbook; the source row numbers remain visible.

QQ screenshots were inspected in-session at 100%: page1 top/P1–transition, page1 lower/Hello World–P4, page2 top/P5 manual marking–P6 clocks, and the functional marker section through page3. No screenshots or artwork were written into the repository. Toolbox locations are user-visible step numbers; Raidplan locations are slide numbers.

Browser access used task-created pages. Direct shell HTTPS was denied and Python Playwright lacked greenlet; the installed Node Playwright driver could connect to the authorized Chrome CDP session. Some screenshot calls timed out; selected loaded figures were subsequently read through CDP screenshots. A normal Toolbox ad overlay was closed via its visible close control. No challenge bypass was used. A failed request, cropped image, or missing extraction is recorded as an access/inspection limit, not evidence that a source does not exist.

## Partial equivalences supported by independent evidence

- **Blue Screen side order and adjustment only** (elemental, aether, kr_09stop): TRHM N→S each side; southern of two stack targets trades with opposite melee. Evidence: Elemental Blue Screen first-wave steps1–3; Aether P4 Wave Cannons lines212–213; KR #Phase.4 rows88–113 plus row15 figure. Not established: Identical exact coordinates, all ring timings for Aether, or LPDU/CN full route.
- **Sigma waymark tower allocation only** (elemental, aether, lpdu): ABCD lower4 left→right;1/2 upper;3/4 mid W/E,remote SW/SE; mid tower center,remote outer edge. Evidence: Elemental Sigma knockback macro; Aether Saus Sigma steps17–23; LPDU markdown Sigma macros and P5 steps29–33. Not established: Same shape ordering, marker allocator, final Worlds, or KR macro.
- **P6 first-Wave clock assignment only** (lpdu, cn_moogle): MT N,OT/ST E,H1 W,H2 S,M1/D1 SW,M2/D2 SE,physical ranged NW,caster NE. Evidence: LPDU P6 raidplan slide1 visually read; CN QQ macro page2 eight-way diagram visually read. Not established: Same Arrow movement, stack direction, exaflare path or meteor layout. LPDU meteor adds H2/OT swap; CN macro only MT/D3 swap.
- **Omega mandatory monitor eligibility** (elemental, lpdu, kr_09stop): Two-stack Second in Line must receive monitor before two-stack no-World; First in Line cannot monitor. Evidence: Elemental Omega first Hello World prose; LPDU P5 step54; KR #Phase.5_Omega row214. Not established: Identical World geometry or eligible tie-break. CN marker classification is corroborating partial evidence only.

No whole-community or whole-mechanic equality is asserted from these narrower correspondences.

## Unresolved authentic-route questions

1. **CN:** obtain and read the full tall diagram plus both original videos. Resolve Loop/tower scan origin, all P2 shape/glitch/knockback branches, Delta fist/arm/World route, Sigma tower/laser/World geometry, Omega marker destinations, and P6 movement/LB/flare branches. Macro categories alone do not prove those routes.
2. **KR:** audit every remaining diagram/animation frame and the full macro/mitigation tabs. Explicit open points include the P3 transition slot map, fourth Hello World round, all Sigma tower macros, both laser directions and full Arrow animations. The manual-world article6982 was not successfully read in this pass.
3. **Aether/LPDU:** inspect remaining P1–P4 linked diagrams and full P5/P6 role-facing geometry. For Aether, pin D1/D2 mapping to the job-icon examples rather than assuming roster order. For LPDU, reconcile post7.0 tank composition rules against the historical toolbox.
4. **Source disagreements:** KR calls P1 tank cleaves90° versus Elemental120°; KR says Dive targets three closest versus Aether/Elemental two closest plus farthest; KR says six comets versus Elemental five. Omega light/safe-direction wording also differs. These are source conflicts, not regional mechanic differences, and need encounter evidence or direct visual verification.
5. **Determinism:** several guides permit free selection among equally eligible players or legal positions. A simulator may need an explicit deterministic tie-break, but that would be an implementation convention unless the community source supplies it. Do not mislabel such a convention source-verified.

## Catalog mapping

| Requested mechanic | Actual catalog ID |
|---|---|
| loop | `p1_loop` |
| pantokrator | `p1_panto` |
| p1_cannons | `p1_cannons` |
| party_synergy | `p2_synergy` |
| limitless | `p2_limitless` |
| p3_transition | `p3_transition` |
| hello_world | `p3_hello` |
| p3_monitors | `p3_monitors` |
| blue_screen | `p4_wave` |
| delta | `p5_delta` |
| sigma | `p5_sigma` |
| omega | `p5_omega` |
| solar_ray | `p5_solar` |
| cosmo_memory | `p6_memory` |
| arrow_dive | `p6_arrow_dive` |
| exaflare_wave | `p6_exa_wave` |
| arrow_wave | `p6_arrow_wave` |
| exaflare_dive | `p6_exa_dive` |
| meteors | `p6_meteors` |
| magic_number | `p6_magic` |

## Per-community route records

Each record below corresponds one-to-one to the JSON. All implementation statuses are `not_assessed_research_only`; all exhaustive-completeness flags are false. A verified rule does not imply that the remaining route is verified. Directions are qualitative unless a source explicitly publishes numerical coordinates. LPDU's exact waymark JSON is preserved separately in the JSON; no other numeric positions are invented.

### elemental

#### loop — `p1_loop`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Program Loop, steps 1–9; homepage P1 macro](https://ffxiv.tuufless.com/elemental/top/01_omega/) (primary_source).
- **Role priority:** H1 > MT > ST > D1 > D2 > D3 > D4 > H2 Within each numbered pair, earlier priority takes first eligible position scanning CW from NW.
- **Axes:** True NW is scan origin; arena center is Omega.
- **Goals / waymarks:** Two active towers; tether holders use empty sectors, separated from towers and party.
- **Branches:** Towers 1,2,3,4; tethers 3,4,1,2. Use actual tower pattern each wave; do not reuse fixed role clockspots.
- **Sequence:** Stack to make initial tethers accessible; 3s intercept. Take each tower/tether assignment; next tether pair collects after previous blast. Heal 3s and 4s after HP penalty expires before their tower turn. After fourth wave restore the final HP-penalty pair.
- **Unresolved:** Guide gives empty-sector priority but does not specify a deterministic choice among every legal empty-sector tie.

#### pantokrator — `p1_panto`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Pantokrator / Condensed Waves and Guided Missiles; English/Japanese macro](https://ffxiv.tuufless.com/elemental/top/01_omega/) (primary_source).
- **Role priority:** H1 > MT > ST > D1 > D2 > D3 > D4 > H2 Earlier of each number goes NW; later SE. H1/H2 separated.
- **Axes:** True NW/SE initial references; rotate with observed Flamethrower.
- **Goals / waymarks:** Beam group trails within safe sector; missile holder leads it. Missile outbound passes through center/inner lane; return uses outside lane.
- **Branches:** If initial cones cover NW/SE, rotate CW to next safe sector. Mirror movement for observed CW/CCW flame rotation. Numbered 1–4 missile order; remaining three share beam.
- **Sequence:** Split by numbers. 1s start near middle, go ahead; group remains ahead of trailing flame. After beam, move together one puddle; next missile player drops next puddle inward, next forward, then backward/out. Return to group after missile and repeat through 4s.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### p1_cannons — `p1_cannons`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Wave Cannons steps 16–17; homepage cannon macro](https://ffxiv.tuufless.com/elemental/top/01_omega/) (primary_source).
- **Role priority:** MT/ST are two furthest players. Non-tanks fixed macro order H1,D1,D3,D4,D2,H2 from west across south to east.
- **Axes:** True north.
- **Goals / waymarks:** Both tanks north outside targeting circle; non-tanks spread through southern half inside circle.
- **Branches:** First three marked non-tanks take beams; other three take second set. Both tanks invuln on fifth marker pulse.
- **Sequence:** Tanks move north and ensure distance targeting. Non-tanks take six nonoverlapping radial lines. Hold spread through both beam waves.
- **Unresolved:** Exact radial distances and six beam angles are diagram-derived, not numeric in macro.

#### party_synergy — `p2_synergy`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Party Synergy steps 1–6; homepage macro](https://ffxiv.tuufless.com/elemental/top/02_omega_mf/) (primary_source).
- **Role priority:** Left H1,MT,D1,D3; right H2,ST,D2,D4, N→S. Duplicate symbol on one side: lower player moves.
- **Axes:** First use true N for light-party lines; then eye=N; knockback uses newly converted male / center of three males=N.
- **Goals / waymarks:** Mid: both sides O,X,triangle,square from eye. Remote: left O,X,triangle,square; right square,X,triangle,O. Knockback left group W; right S for mid, E for remote.
- **Branches:** M sword/F legs: safe toward F; M shield/F legs: toward M. M sword/F staff: outside M circle and F cross; M shield/F staff: lateral shield pocket. If both stacks same side, farther-from-eye stack trades with its shape partner. Tanks Provoke their Packet Filter target after gender swap.
- **Sequence:** Assign symbols; dodge actual M/F pair between waymarks. Resolve optical beam and spreads with glitch distances. Identify new north and stack adjustment. Take knockback to selected W/S or W/E safe spots.
- **Unresolved:** Exact combined-M/F safe-pocket boundaries and mid-glitch distance tolerance require diagram geometry extraction.

#### limitless — `p2_limitless`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Limitless Synergy steps 7–12](https://ffxiv.tuufless.com/elemental/top/02_omega_mf/) (primary_source).
- **Role priority:** MT takes north intercardinal tether; ST south. Tanks bait Beyond Defense; hit tank excludes self from Pile Pitch.
- **Axes:** True south for party bait; external shield clone defines subsequent facing.
- **Goals / waymarks:** Party outside target circle south, then inside after Sagittarius telegraph. Tanks separated outside hitbox on shield-clone side; party center.
- **Branches:** Point collected tethers CW. Beyond Defense hit tank circles to opposite side; other tank rejoins center. Ignore flare separation with guide's mitigation-heavy center stack.
- **Sequence:** Stack south, collect tethers. Dodge arrow into circle. Tanks bait shield charge. Hit tank leaves; seven share Pile Pitch plus flares; mitigate eye raidwide.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### p3_transition — `p3_transition`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Transition steps 1–10 and homepage transition macro](https://ffxiv.tuufless.com/elemental/top/03_omega_reconfigured/) (primary_source).
- **Role priority:** H1 > MT > ST > D1 > D2 > D3 > D4 > H2 Sort purple and white/no-debuff groups separately.
- **Axes:** True N; incoming arms alter local safe pocket.
- **Goals / waymarks:** White/no-debuff pairs NW and NE; purple order W,SW,SE,E.
- **Branches:** First arms may form either triangle; wait outside moving ring then step into previously exploded arm intersection. Pair each white with one no-debuff player by rank.
- **Sequence:** Shield; conga; allocate six positions. Dodge first ring progression and return outward. Watch first arm set; after its explosion move into shared safe pocket of ring and arms. Resolve debuffs with second arm explosion.
- **Unresolved:** Exact conga direction is supplied by macro priority; arm-safe pocket radial coordinates not numerically specified.

#### hello_world — `p3_hello`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Hello World setup, first/second/third iterations, fourth iteration](https://ffxiv.tuufless.com/elemental/top/03_omega_reconfigured/) (primary_source).
- **Role priority:** Assignment is current debuff, not job priority. Defamation pairs with red/green tether; stack with blue tether for rounds 1–3.
- **Axes:** Axes reorient to current colored towers every round.
- **Goals / waymarks:** Defamation on outward part of same-color tower; stack on inward part. Red/green tether outside defamation tower; blue tether between stack towers.
- **Branches:** Determine which color is defamation once, then retain mapping. Rounds 1–3: resolve towers/bugs, transfer rot within 3 seconds, blue breaks first then red/green. Round 4: red/green joins stack side; red/green breaks first; no rot transfer; blue breaks after.
- **Sequence:** Rot holders travel outside hitbox first; tether holders wait inside until rot holders placed. Resolve bug/tower hits. Tether holders collect rot; blue separates naturally; red/green converge. Repeat rotated debuff roles four times; avoid final rot blasts; mitigate Critical Error.
- **Unresolved:** No deterministic job tie-breaker for equivalent tower partners is published in inspected prose.

#### p3_monitors — `p3_monitors`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Oversampled Wave Cannon; homepage Astoh macro](https://ffxiv.tuufless.com/elemental/top/03_omega_reconfigured/) (primary_source).
- **Role priority:** H1 > H2 > MT > ST > D1 > D2 > D3 > D4, separately rank monitors and unmarked.
- **Axes:** Boss faces true N; mirror horizontally for west-facing boss monitors.
- **Goals / waymarks:** East boss monitor: three monitor holders on W half; M1 NW facing outward W, M2 WNW pointing N, M3 WSW pointing S. Unmarked 1 N, 2 slightly E of center, 3 farther E, 4 S inner, 5 S outer.
- **Branches:** All three player monitors opposite boss monitors. Angle M2/M3 slightly to avoid unmarked 3; unmarked adjust to monitor aim. Each source must cover exactly two recipients; no double hits.
- **Sequence:** Line up N→S; split marked/unmarked rank. Move to Astoh pattern and mirror if necessary. Aim monitor half-planes; unmarked avoid crossing extra half-planes. Resolve, then enrage.
- **Unresolved:** Exact monitor angles, target-recipient mapping and tolerances need diagram-specific transcription before executable geometry.

#### blue_screen — `p4_wave`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Blue Screen first/second/third wave steps 1–12](https://ffxiv.tuufless.com/elemental/top/04_blue_screen/) (primary_source).
- **Role priority:** West MT,D3,H1,D1; east ST,D4,H2,D2, N→S.
- **Axes:** True N.
- **Goals / waymarks:** Spread west/east leaving southern gap; four-player stacks SW/SE of south.
- **Branches:** Two stacks one side: lower stack swaps; opposite melee swaps. Round 2 dodge expanding ring after spread before stack; round 3 stack before stepping inward for ring.
- **Sequence:** Spread and identify markers. Resolve spread, gather south with adjustment, return original positions. Repeat with round-specific ring timing. Reach below 20% before Blue Screen.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### delta — `p5_delta`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Run Dynamis Delta steps 1–9](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_delta/) (primary_source).
- **Role priority:** Blue pairs at beetle; green pairs at Final Omega; one inner and one outer pair each. Inner pair adjusts fist color.
- **Axes:** Beetle–Final axis; safe half determined by beetle side cleave.
- **Goals / waymarks:** Outer blue initially stretched to break; inner blue short. Near World three rings from center on safe cardinal between bosses; Far World at wall on same cardinal. Near receivers: beetle-side green at edge intercardinal and same-side marker. Far receivers: other green unsafe player rotates to beetle, partner far intercardinal plus three notches; unmarked blues wall at opposite intercardinal minus three notches toward beetle.
- **Branches:** Same fist color adjacent: inner pair swaps with tether partner. Outer blue breaks on activation; inner blue after fist telegraphs. Outer blue baits beetle-side arms; inner blue baits Beyond Defense; inner green side arms; outer green Final-side arms. Player monitor points opposite Final's; Beyond Defense victim stays out of 3-blue Pile Pitch even if monitor holder. Beetle-side green cuts at 15s remaining; last green at 2s.
- **Sequence:** Form tether lanes; adjust fists; stack fist partners after outer blue cuts. Bait six rotating arms and shield charge. Resolve monitors/Pile Pitch in safe corridor. Move to cleave-safe World layout; resolve jumps and final tether.
- **Unresolved:** Initial inner/outer blue selection tie-breaker not explicit in this guide text; do not substitute Aether's Near/Far assignment without evidence. Precise arm-bait angular offset depends on rotation and remains diagram geometry work.

#### sigma — `p5_sigma`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Sigma sections 1–3, steps 1–10; homepage tower macro](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_sigma/) (primary_source).
- **Role priority:** H1 > MT > ST > D1 > D2 > D3 > D4 > H2 for eligible Omega-F-side selection. No World holders in three-player F group; at least two of group have one Dynamis.
- **Axes:** First Omega-M=N; towers use point/star=N (four towers=S); final Omega-F=N.
- **Goals / waymarks:** Shape columns O,X,triangle,square. Two-mark top pair N/S (left N); bottom W/E (left W). One-mark top unmarked NW/marked SE; lower unmarked NE/marked SW. Mid towers: 1 NW,2 NE,A+3 W,D+4 E,B SW,C SE. Remote: 1+2 N,A W,D E,B+3 SW,C+4 SE. World holders one ring inward of waymarks; Near first recipient edge cardinal/intercardinal, second four notches behind.
- **Branches:** Mid use waymark line then tower center; remote wall then criss-cross toward tower outer edge. Tower formation can reverse from initial male; map by actual tower point, retain previous actual waymark identity. F legs: follow rotating laser into safe region; staff: wait outside cross first. Prefer eligible tanks for arm lasers.
- **Sequence:** Assign shape pairs and six-marker spread; remember physical waymark. Resolve knockback towers with actual glitch. Allocate F-side trio; dodge F plus rotating laser. Take World/arm positions; finish four players at one stack and four at two.
- **Unresolved:** All six World receiver coordinates and automarker tie-break/order require final diagrams; inspected text does not fully fix same-stack ties.

#### omega — `p5_omega`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Omega sections 1–3](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_omega/) (primary_source).
- **Role priority:** Monitor: two-stack Second in Line first, then two-stack no-World; never First in Line. Final tethers: the two three-stack players.
- **Axes:** M/F pair determines cardinal candidates; boss monitors true E/W; final beetle spawn defines relative N.
- **Goals / waymarks:** Legs+sword: near away from M; legs+shield: near toward M; staff+sword: far toward M; staff+shield: middle toward M. World holders one ring inside waymarks; monitor recipients on cleaved side; other six on safe side. Final tethers beside beetle; other six World pattern opposite.
- **Branches:** First central lights eliminate one cardinal candidate; second safe cardinal is 90° CW or CCW. Mandatory two-stack Second in Line monitor ensures next Worlds can resolve. After first World: exactly two at 3 stacks and six at 2. After second all eight at 3.
- **Sequence:** Read both M/F patterns and central cleave; dodge first then second. Allocate monitors and six World roles. Resolve first Worlds/monitors. Three-stacks take tethers; resolve second Worlds then Solar Ray/Blind Faith.
- **Unresolved:** Source prose says lights eliminate direction; KR wording calls glowing direction safe. Preserve visual cue ambiguity until both diagrams are compared. Exact six-person World geometry and eligible-tie ordering need diagram/AM transcription.

#### solar_ray — `p5_solar`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Delta page Solar Ray table and notes](https://ffxiv.tuufless.com/elemental/top/05_run_dynamis_delta/) (primary_source).
- **Role priority:** Tank jobs, not MT/ST, determine invuln sequence.
- **Axes:** Boss at center; separate tankbuster AoEs.
- **Goals / waymarks:** Swap between two hits if not using invuln.
- **Branches:** With WAR: first PLD invuln > GNB invuln > swap/full; second DRK invuln > swap/full; third WAR invuln; fourth swap/full. Without WAR: first PLD > GNB > DRK invuln; second GNB > DRK; third/fourth swap with Rampart split against 30%/healer mitigation. Fast WAR+PLD and unavailable Hallowed: Holmgang second, use no-WAR fallback. PLD MT first Solar + GNB ST second Solar changes P6 Wave invuln order.
- **Sequence:** Plan four casts by composition and available cooldowns. Mitigate before first hit; invuln both or Provoke between hits. Use 90s party mitigation after second hit to cover following trio.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### cosmo_memory — `p6_memory`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Alpha Omega preparation, Cosmo Memory, auto-attacks](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/) (primary_source).
- **Role priority:** Tank LB: WAR > PLD > DRK > GNB.
- **Axes:** True N; party returns from S death wall.
- **Goals / waymarks:** MT holds aggro; ST outside target circle as farthest for subsequent autos; party inside.
- **Branches:** Every player must enter with three Dynamis; Memory converts to Brilliant. Tank LB3 plus shields required.
- **Sequence:** Enter arena, heal/shield, assigned tank LB3 for cast. Re-establish distinct MT and farthest ST for two autos.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### arrow_dive — `p6_arrow_dive`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Alpha Omega Arrow→Dive steps 1–10](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/) (primary_source).
- **Role priority:** Tanks two closest, six-player group farthest.
- **Axes:** Arrow centered on arena; Dive relative to group.
- **Goals / waymarks:** Tanks separate inside hitbox; six stack outside hitbox.
- **Branches:** Inside-first: In → wait → out → wait → out/spread → in. Outside-first: out → wait → in → out/spread → in. Read each Arrow independently; second is not guaranteed opposite first.
- **Sequence:** Read initial telegraphs. Execute pattern through final inward movement. Tanks move closest separated; group forms one distant stack; resolve Dive.
- **Unresolved:** First Arrow group's exact starting quadrant not established from text alone.

#### exaflare_wave — `p6_exa_wave`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Alpha Omega Unlimited Wave Cannon→Wave Cannon steps 1–6; homepage clock macro](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/) (primary_source).
- **Role priority:** MT heavy mitigation, ST invuln; PLD/GNB exception under Solar Ray.
- **Axes:** Exaflare first spawn and CW/CCW arc; return true E for stack.
- **Goals / waymarks:** Clockspread N=D3,NE=D4,E=H2,SE=D2,S=ST,SW=D1,W=H1,NW=MT. Stack center for first bait; move to 1.5 waymarks (67°) BEFORE first exaflare along spawn arc. By third bait reach just outside targeting circle; follow observed spawn direction through six baits. Eight-player beam stack east with tanks the front two.
- **Branches:** First four random targets then complementary four; preserve spread through both. Mirror traversal if exaflare sequence reverses.
- **Sequence:** Bait six puddles following arc. Spread clocks for two beam waves. Stack E, tanks ahead; resolve hard beam.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### arrow_wave — `p6_arrow_wave`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Alpha Omega Arrow→Wave Cannon steps 1–11](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/) (primary_source).
- **Role priority:** Fixed clock roles; MT invuln, ST heavy mitigation, subject to tank-composition exception.
- **Axes:** True N clockspread; Arrow grid axes.
- **Goals / waymarks:** Clockspread N=D3,NE=D4,E=H2,SE=D2,S=ST,SW=D1,W=H1,NW=MT. Stack east after both spread beam sets.
- **Branches:** Inside-first: In → wait → out → wait → out/spread → in. Outside-first: out → wait → in → out/spread → in. Read each Arrow independently; second is not guaranteed opposite first.
- **Sequence:** Dodge initial Arrow pattern. Spread during late out step for first four beams; dodge inward for second four. After last Arrow join E stack, tanks front.
- **Unresolved:** Exact role-specific lateral displacement for simultaneous Arrow/proteans not fully specified by text and clock macro.

#### exaflare_dive — `p6_exa_dive`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Alpha Omega Unlimited Wave Cannon→Cosmo Dive steps 1–4](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/) (primary_source).
- **Role priority:** MT forward-left, ST forward-right relative to group facing center.
- **Axes:** Exaflare relative; final group location is rear of Y.
- **Goals / waymarks:** Stack center for first bait; move to 1.5 waymarks (67°) BEFORE first exaflare along spawn arc. By third bait reach just outside targeting circle; follow observed spawn direction through six baits. Six stay after sixth bait outside targeting circle; tanks advance into circle, split left/right.
- **Branches:** Mirror exaflare route for reversed spawn direction. Melees coordinate two LB3s after dodge; confirm gauge.
- **Sequence:** Center baits, exit and follow exaflares through six puddles. Hold six-player stack; tanks advance for Dive. Resolve Dive, then re-establish autos.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### meteors — `p6_meteors`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Alpha Omega Cosmo Meteor steps 1–8](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/) (primary_source).
- **Role priority:** D4 caster LB3 first; D3 ranged LB3 second. Healer center AST > SGE/SCH > WHM; agree pre-pull.
- **Axes:** True N/S meteor line.
- **Goals / waymarks:** D3 north for ranged LB; other assigned waymarks; one healer center after center AoE. Flares cardinal; nonflares opposite D3 if D3 flare, with D3 otherwise.
- **Branches:** D3 flare: N(D3),E,W flares; stack S. D3 no flare: S,E,W flares; stack N. Do not move LB-locked D3; others adjust.
- **Sequence:** Bait center, spread, caster LB center. Heal four alternating random-AoE waves; wait for gauge refill. Ranged LB through N/S meteors. Resolve three flares and five-player stack.
- **Unresolved:** Exact meteor role-to-waymark map not fully transcribed from phase figure; do not reuse spread clocks blindly. Tie-break between remaining flare players for E/W not explicit in inspected prose.

#### magic_number — `p6_magic`

Evidence state: verified_text_and_macro; coverage: partial_route_with_verified_rules.

- Source: [Alpha Omega Magic Number and preparation](https://ffxiv.tuufless.com/elemental/top/06_alpha_omega/) (primary_source).
- **Role priority:** Tanks DRK > MT > ST; healers H1 > H2.
- **Axes:** No directional route beyond safe party location.
- **Goals / waymarks:** Party survives with Tank LB3; healer LB3 removes six-second debuff.
- **Branches:** Two cycles use distinct available tank/healer Brilliant refunds. DRK optional suicide variant changes tank order; not presumed default.
- **Sequence:** Tank LB3 before Magic Number hit. Healer LB3 after debuff appears and before expiry. Repeat with second tank/healer. Use refunded final melee LB3 during enrage.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

### aether

#### loop — `p1_loop`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P1 Loop lines123–130](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Light parties; flex Tank > Melee > Ranged. G1 NW/CCW; G2 N/CW.
- **Axes:** True N/NW scan origins.
- **Goals / waymarks:** Numbered pairs allocate two towers/tethers by group scan; G2 takes tower between NW and N.
- **Branches:** Duplicate numbers within light party: TMR flex. Towers1234; tethers3412.
- **Sequence:** Resolve duplicate number distribution. Take towers and tethers using independent group scans. Repeat four waves.
- **Unresolved:** Which same-role member flexes in every duplicate-number case and all empty-sector tether goals need P1 toolbox diagram audit. Healer behavior beyond TMR is not explicit.

#### pantokrator — `p1_panto`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P1 Pantokrator lines132–137](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Light party TMR flex.
- **Axes:** G1 NW/CCW,G2 N/CW preposition; observed cone movement determines travel.
- **Goals / waymarks:** Three-player beam group at back safe sector; missile ahead.
- **Branches:** Each numbered player leaves on turn, rejoins after missile; count three puddles. Flex group if duplicate number.
- **Sequence:** Split according to safe cones. Stagger group along hitbox ahead of cone. Missile goes ahead and loops back after hit; repeat.
- **Unresolved:** Exact initial sector under all cone orientations and role flex ties need P1 toolbox.

#### p1_cannons — `p1_cannons`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [TB + Protean Beams lines141–149](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Tanks NW/NE; remaining six conga south.
- **Axes:** True N.
- **Goals / waymarks:** Marked beams W/E slightly south of D/B and directly S; unmarked max-melee SW/SE.
- **Branches:** First three marked assigned by spread order; second three repeat same outlets.
- **Sequence:** Tanks split NW/NE for cleaves. Three marked move to W/E/S beams. First group returns safe as complementary three move out.
- **Unresolved:** Six-person role conga order not established in prose; do not substitute Elemental fixed six-way spread.

#### party_synergy — `p2_synergy`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P2 Party Synergy lines156–169](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Recommended conga H1,R1,M1,MT,ST,M2,R2,H2; left/right of same symbol defines group.
- **Axes:** Eye=N; subsequent knockback orientation requires P2 toolbox.
- **Goals / waymarks:** Mid both X,square,O,triangle; remote left same, right triangle,O,square,X.
- **Branches:** If both stacks same side, northmost marked player and matching shape partner trade.
- **Sequence:** Conga and assign pairs. Dodge M/F; spread eye-relative BPOG/GPOB. North-flex stack pair; resolve knockback.
- **Unresolved:** Four stance combination safe pockets and knockback group destinations not supplied by inspected Aether prose.

#### limitless — `p2_limitless`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [TLDR phase2 lines53–54](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Tanks bait Beyond Defense; six party center.
- **Axes:** True S/SW arrow bait; shield-clone side determines tank placement.
- **Goals / waymarks:** 611: party S/SW hitbox bait; after dodge six middle, tanks separated on shield side. Stack flares center with mitigation.
- **Branches:** Hit tank must avoid Pile Pitch; detailed Aether rule needs P2 toolbox.
- **Sequence:** Bait arrow S/SW, dodge inward. Tanks bait charge; party middle. Resolve center flares/stack.
- **Unresolved:** Tether ownership and charge-victim escape complete branch details not verified in linked P2 toolbox.

#### p3_transition — `p3_transition`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P3 Transition lines178–183](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Conga H1,R1,M1,MT,ST,M2,R2,H2; rank debuff groups by left-right.
- **Axes:** True N.
- **Goals / waymarks:** Purple W,NW,NE,E; whites and empties paired in two southern safe slots.
- **Branches:** Purple move forward from conga; whites backward. Leftmost white pairs leftmost empty; rightmost pair likewise.
- **Sequence:** Conga; assign class-specific ranks. Move to four north purple and two south pair positions. Dodge ring/arms while preserving separation.
- **Unresolved:** Ring/arm safe pockets need Dylan toolbox steps1–10.

#### hello_world — `p3_hello`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P3 Hello World lines185–193](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Debuff roles; fixed job tower priority not specified.
- **Axes:** Colored towers.
- **Goals / waymarks:** Tether players approach their corresponding rot holders; final non-defamation group shares stacks.
- **Branches:** Ordinary loops blue breaks before red/green. Final tower set blue breaks after vulnerability; watch final rot.
- **Sequence:** Follow color/bug tower placement. Resolve tower then rot transfer and tethers. Repeat four sets, final non-defamation stack-side grouping.
- **Unresolved:** Complete colored tower placement, fourth-round green order, and role cycling require Dylan steps11–28; not inherited from Elemental.

#### p3_monitors — `p3_monitors`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P3 Monitors lines194–203](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Vertical conga on left: H1,R1,M1,MT,ST,M2,R2,H2.
- **Axes:** True N; boss monitor cleaving half.
- **Goals / waymarks:** Monitor1 cleaving-side NW/NE inner marker corner; monitor2 same-side SW/SE inner corner; monitor3 safe-side SW/SE directly south of marker.
- **Branches:** Mirror with boss monitor side; unmarked safe half rank by conga.
- **Sequence:** Conga marked/unmarked. First2 monitors enter boss-cleaving half; third safe-side south. Unmarked safe-side waymark slots; resolve.
- **Unresolved:** Five unmarked exact slots and all player facing angles need Dylan steps29–36. Not Astoh: two marked players are on boss-cleaving side.

#### blue_screen — `p4_wave`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P4 Wave Cannons lines210–213](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Each side Tank,Ranged,Healer,Melee N→S.
- **Axes:** True N.
- **Goals / waymarks:** Second/fourth in line on W/E and SW/SE waymarks; others above/between.
- **Branches:** Southmost of two stacks swaps; opposite melee swaps.
- **Sequence:** Spread, read stacks, resolve beams. Adjust to southern stacks, return original positions. Repeat with ring mechanics.
- **Unresolved:** Aether prose does not fully specify all three ring timings; P4 toolbox not read.

#### delta — `p5_delta`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P5 Delta lines227–241; linked Saus Delta](https://www.thepfstrat.com/u/top) (text).
- **Role priority:** Blue to beetle; Near-blue pair inner, Far-blue pair outer; green first-come first-served. INNER pair swaps for matching fists.
- **Axes:** Eye/Beetle/Final frame; safe half from beetle cleave.
- **Goals / waymarks:** Green inner to N/S arms; outer green to Final arms; outer blue to beetle arms. Near holder safe cardinal middle; Far holder wall cardinal; no-World blues wall between Far and far green.
- **Branches:** Beyond Defense victim excluded from stack even if monitor holder; monitor south-facing opposite Final. Safe-side green plants, unsafe partner moves. Closest-beetle green breaks and receives Near; far green crosses to beetle wall and opposite wall for Far. Last green waits for magic vulnerability to expire.
- **Sequence:** Assign tether lanes, inner fist adjustment. Break outer blue and bait arms; inner blue breaks later. Resolve monitors and Pile Pitch. Go safe World layout, cut green at safe timings.
- **Unresolved:** Aether page's arm assignment differs from LPDU linked toolbox. Keep separate. Exact blue-break timing and rotating-arm bait angular offsets need Delta diagram audit.

#### sigma — `p5_sigma`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus Sigma steps2–40](https://ff14.toolboxgaming.space/?id=107380954136761&preview=1) (text).
- **Role priority:** Shape pairs BPOG; sort pair by north/south and number of markers. Three F-side players have1 Dynamis and no World; remaining three no-World are receivers.
- **Axes:** M=N, tower point=N/four towers=S, F=N.
- **Goals / waymarks:** 1-mark upper unmarkedNW/markedSE; lower unmarkedNE/markedSW. 2-mark upperN/S leftN; lowerE/W. ABCD on bottom four towers in order; 1/2 top; mid3/4 W/E; far3/4 SW/SE. World holders1 ring inside markers; other six wall.
- **Branches:** Mid stand in front of waymarks and tower centers; far behind marks at wall and tower outer edges. F hot-wing follow in; cross wait outside before following laser. Looking inward, left arm baiter waits until rotation ends. Receiver conga toward rotating AoE: Near1,Near2,Far.
- **Sequence:** Assign shape rows and six-mark spread; remember waymark. Map tower using actual point and glitch, take knockback. Allocate F-side trio and opposite five. Resolve F first, follow laser, spread World/arm roles; finish4x1+4x2.
- **Unresolved:** Two-mark lower pair E/W left/right not stated in inspected text. Full AM role-tie assignment and exact final receiver wall notches require diagram audit.

#### omega — `p5_omega`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus Omega steps6–44; linked monitor raidplan U0QfgaRAT6tcB0KX](https://ff14.toolboxgaming.space/?id=078384491946761&preview=1) (text).
- **Role priority:** Chains1/2 monitors; attack1/4 Far receivers; attack2/3 Near receivers. Final two3-stack players take beetle tethers.
- **Axes:** True N for first monitor layout; beetle=N for final layout.
- **Goals / waymarks:** Final Near S1 ring inside mark; Far E1 ring inside mark; four receivers wall; tethers near beetle parallel markers.
- **Branches:** Solve F then M, choose safe cardinal using center cue; second dodge after first AoEs. Four World debuffs assigned I/II; first use I, second II.
- **Sequence:** Dodge two predation combinations. Use marked monitor/receiver positions and first Worlds. Three-stacks take final tethers; six others second Worlds. Below20% for Blind Faith.
- **Unresolved:** Required two-stack+II monitor priority is in diagram textboxes, not captured header prose; needs full diagram transcription. Full four-combo rule3 and exact first World geometry unresolved.

#### solar_ray — `p5_solar`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus Omega steps2,43; Aether TOP Mitty link](https://ff14.toolboxgaming.space/?id=078384491946761&preview=1) (text).
- **Role priority:** Tanks coordinate.
- **Axes:** Boss-relative separated tank positions.
- **Goals / waymarks:** Two-hit tankbuster occurs before Omega and at its end.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Prepare assigned mitigation/invuln or swap.
- **Unresolved:** Aether-specific four-cast tank-composition plan not established; linked TOP Mitty remains unaudited.

#### cosmo_memory — `p6_memory`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus P6 step3](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1) (text).
- **Role priority:** One tank LB3; role/job order not specified in inspected toolbox text.
- **Axes:** True arena center.
- **Goals / waymarks:** Three Dynamis convert to Brilliant on Memory.
- **Branches:** Tank LB3 required.
- **Sequence:** Enter arena and Tank LB3 for first raidwide.
- **Unresolved:** Tank job priority, party start, shielding plan not established.

#### arrow_dive — `p6_arrow_dive`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus P6 steps5–41;19,20,36,37](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1) (text).
- **Role priority:** Tank/healer and DPS dodges differentiated. Two closest players tanks; furthest player six-person stack (steps20/98).
- **Axes:** Arena Arrow grid.
- **Goals / waymarks:** After final in take Dive positions. Tanks loosely separated in hitbox; party on ring or slightly inside.
- **Branches:** Plus/in-first: in→wait→out→wait→spread/out→in. Box/out-first: out→wait→in→spread/out→in.
- **Sequence:** Read Plus/Box. Dodge through sequence. Re-form Dive positions before cast finishes.
- **Unresolved:** Exact first group quadrant, tanks' Dive endpoints, and side-step lanes not fully read.

#### exaflare_wave — `p6_exa_wave`

Evidence state: verified_text_and_selected_diagram; coverage: partial_route_with_verified_rules.

- Source: [Saus P6 steps42–53; diagram48 inspected](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1) (text_and_diagram).
- **Role priority:** Tanks front; exact mitigation order unresolved.
- **Axes:** First exaflare appears random cardinal/intercardinal; final true S.
- **Goals / waymarks:** Step48 diagram: MT/GNB N,ST/DRK S,WHM W,SGE E,MCH NW,SMN NE,SAM SW,DRG SE. Job icons verified; generic D1/D2 assignment not assumed. After sixth bait move to clock waymarks; after beams stack SOUTH.
- **Branches:** Two sets4 proteans then wild-charge beam. Exaflare direction independent per occurrence.
- **Sequence:** Find first exaflare and dodge six baits. Spread clocks for two beam waves. Stack S with tanks front.
- **Unresolved:** Precise exaflare exit-offset rule not in inspected step headers. Melee D1/D2-to-job mapping and tank cooldown branches remain unresolved.

#### arrow_wave — `p6_arrow_wave`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus P6 steps54–90;55,65,69](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1) (text).
- **Role priority:** Tank/healer cardinals move CW into their quadrants; DPS intercardinal.
- **Axes:** True clock/quadrant grid.
- **Goals / waymarks:** Step48 diagram: MT/GNB N,ST/DRK S,WHM W,SGE E,MCH NW,SMN NE,SAM SW,DRG SE. Job icons verified; generic D1/D2 assignment not assumed. Final wild charge SOUTH.
- **Branches:** Plus/in-first: in→wait→out→wait→spread/out→in. Box/out-first: out→wait→in→spread/out→in. Plus: special TH lateral move at spread/out prevents protean clipping; only applies in-first.
- **Sequence:** Move cardinals CW into paired quadrants. Execute independent Plus/Box pattern while separating proteans. After second proteans join S stack.
- **Unresolved:** Exact TH lateral displacement still requires step65 diagram; Box timing differs and cannot be inferred from Plus.

#### exaflare_dive — `p6_exa_dive`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus P6 steps91–99;97](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1) (text).
- **Role priority:** Tanks split; both melees LB3 before meteor. Two closest players tanks; furthest player six-person stack (steps20/98).
- **Axes:** Last puddle defines relative party position.
- **Goals / waymarks:** After sixth bait rotate one extra step; party stays on or slightly inside hitbox ring. Tanks loosely separated in hitbox; party on ring or slightly inside.
- **Branches:** Follow observed exaflare direction.
- **Sequence:** Dodge six puddles. One more rotation step; form Dive. Use both melee LB3s here before meteor.
- **Unresolved:** Tank endpoint orientation and exact exaflare offset not established from inspected headers.

#### meteors — `p6_meteors`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus P6 steps100–110, including101,103,104,106–108](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1) (text).
- **Role priority:** Caster LB3 then ranged LB3; ranged fixed while LB-locked. Regen healer may go center after bait AoEs disappear (step103).
- **Axes:** True N/S.
- **Goals / waymarks:** Center bait then assigned waymark spread; stay spread until flares.
- **Branches:** Ranged flare→party SOUTH; ranged no-flare→party NORTH. All other flare endpoint selection remains diagram-dependent.
- **Sequence:** Center bait, spread with mitigation. Caster then ranged LB; take two AoEs per player. Resolve flare/stack around ranged.
- **Unresolved:** Meteor-specific clock swaps and remaining flare endpoint tie-breaks not fully diagram-audited.

#### magic_number — `p6_magic`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Saus P6 step111 (full text inspected)](https://ff14.toolboxgaming.space/?id=548481027977761&preview=1) (text).
- **Role priority:** Tank1→Healer1, then Tank2→Healer2.
- **Axes:** No directional dependency.
- **Goals / waymarks:** Party survives Tank LB3; healer LB3 only after Magic Number debuff is applied.
- **Branches:** Repeat with second tank/healer; no early healer LB before debuff.
- **Sequence:** Tank1 LB3 as first cast begins; Healer1 waits for debuff then LB3. Tank2 LB3 as second cast begins; Healer2 waits for debuff then LB3. Finish Run:Dynamis enrage.
- **Unresolved:** Tank1/2 and Healer1/2 job-specific priorities are not prescribed in this toolbox.

### lpdu

#### loop — `p1_loop`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase1 priority and raidplan](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** CW M1>M2>MT>OT>R1>R2>H1>H2 CCW.
- **Axes:** CW/CCW; scan origin not explicit in markdown.
- **Goals / waymarks:** Use published LPDU waymarks.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Assign numbered partners by published priority.
- **Unresolved:** Origin, tower/tether goal selection, empty-sector branches need linked raidplan 7gDX3dkkPX1kO9u2; priority alone is not complete.

#### pantokrator — `p1_panto`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase1 Pantokrater priority](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** North MT>M1>R1>H1; south OT>M2>R2>H2.
- **Axes:** North/south group reference.
- **Goals / waymarks:** Use published LPDU waymarks.
- **Branches:** This is TMRH panto, distinct from MTRH Loop.
- **Sequence:** Split numbered players using light-party order.
- **Unresolved:** Duplicate-number flex details, starting cone sectors, missile return lanes require P1 raidplan.

#### p1_cannons — `p1_cannons`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Post7.0 changes / Phase1](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** Post7.0 PLD composition: MT NW,OT NE.
- **Axes:** True N.
- **Goals / waymarks:** Split tankbusters and kitchen-sink mitigation when PLD invuln timing forces change.
- **Branches:** Markdown change explicitly applies to PLD comps; not universal invuln policy.
- **Sequence:** Split tanks per comp branch; mitigate.
- **Unresolved:** Non-tank beam assignments, non-PLD policy and detailed cleave timing need P1 raidplan.

#### party_synergy — `p2_synergy`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase2; full overview; post7.0 changes](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** M side MT,H1,M1,R1; F side OT,H2,M2,R2. Right side adjusts per overview.
- **Axes:** Eye=N for BPOG.
- **Goals / waymarks:** Mid X,square,O,triangle both sides; remote full reverse right.
- **Branches:** NIN/SCH overview may place M1 on F and H2 on M. Post7.0: non-PLD tank aggros both bosses/invulns; after tankbusters MT taunts Female,OT Male.
- **Sequence:** Establish prepositions and filter. Perform shape spread and full-cross remote.
- **Unresolved:** Duplicate-symbol/stack adjust participant selection, full M/F and knockback routes need toolbox502396712985961; 'right adjusts' insufficient.

#### limitless — `p2_limitless`

Evidence state: verified_text; coverage: unresolved_route.

- Source: [Phase2 toolbox502396712985961](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** Not established in markdown.
- **Axes:** Unresolved.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** LPDU P2 linked toolbox not inspected through Limitless; tether ownership, arrow dodge branch, stack/flare and charge assignments unresolved.

#### p3_transition — `p3_transition`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase3 transition; overview](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** R1,M1,MT,H1,H2,OT,M2,R2 (RMTHHTMR).
- **Axes:** Stacks north.
- **Goals / waymarks:** Healers shield before spreading.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Shield; assign debuff classes by conga; stacks north.
- **Unresolved:** Four purple slots and white/empty pairing placements need raidplan46r495ZATq3kCqz1.

#### hello_world — `p3_hello`

Evidence state: verified_text; coverage: unresolved_route.

- Source: [Phase3 Hello World link](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** Debuff/job priorities unresolved.
- **Axes:** Colored towers, exact route unverified.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Toolbox702399575985961 linked, not step-audited; do not presume Aether/Elemental Hello World equivalence.

#### p3_monitors — `p3_monitors`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase3 monitors link and overview](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** RMTHHTMR overview order; role mapping R1,M1,MT,H1,H2,OT,M2,R2.
- **Axes:** Unresolved boss-relative geometry.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Allocate by published conga only after confirming marked/unmarked handling.
- **Unresolved:** Toolbox736282987145761 not inspected; monitor-side allocation/facing/recipients unresolved.

#### blue_screen — `p4_wave`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase4 and overview](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** TRHM / MHRT; melee adjusts.
- **Axes:** North/south orientation implied overview, exact spread diagram unverified.
- **Goals / waymarks:** Two side groups.
- **Branches:** Melee flex mentioned; stack-holder choice not explicitly in markdown.
- **Sequence:** Use side groups and melee adjustment.
- **Unresolved:** Toolbox595188367474761 not audited; exact stack swap rule and ring timelines unresolved.

#### delta — `p5_delta`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [LPDU-linked Dylan/Battle Litany P5 steps3–20](https://ff14.toolboxgaming.space/?id=955389449416761&preview=1) (text).
- **Role priority:** Blue beetle,green Final; INNER pairs adjust identical fists. First-break outer blue baits Beyond Defense; remaining blue baits beetle arms.
- **Axes:** Eye=N during first portion; beetle/Final W/E in worked example.
- **Goals / waymarks:** Green outer Final arms; green inner center N/S arms. Green lines near wall; player monitor opposite Final. Near middle close to cleave; Far wall cardinal; no-World blues intercardinal away from beetle.
- **Branches:** Facing rotating fist: orange bait left,blue bait right. Wait visible eye laser, not audio, before leaving fist stack. Monitor victim of Beyond Defense moves toward Final; stack remains same corridor. Beetle-side green breaks when safe; other green cuts around3s Patch remaining after World AoEs.
- **Sequence:** Set lanes/fists; first blue cuts then stacks. Bait shield charge and six arms. Resolve monitors/Pile Pitch excluding victim. Move into non-glowing safe half; green split to Near/Far recipients; resolve Worlds and last cut.
- **Unresolved:** Exact inner/outer initial blue assignment not specified; source text has wording ambiguity at step6 versus8. Final World notches require diagram audit; no numerical coordinates invented.

#### sigma — `p5_sigma`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [LPDU markdown Sigma macros; linked P5 steps22–45](https://ff14.toolboxgaming.space/?id=955389449416761&preview=1) (text).
- **Role priority:** Quickmarch flex then BPOG. Three1-stack/no-World toward F; prioritize MT. Mini-conga each side.
- **Axes:** M=N; towers newN at M or opposite; F=N for World.
- **Goals / waymarks:** First blank pair unmarked NW/partnerSE; second unmarkedNE/partnerSW; first double N/S(right of male S),last doubleE/W. Mid1/2 top, A+3 left,D+4 right,B/C lower; far1+2 top,A/D sides,B+3/C+4 lower. Far holder4th ring between arms; far recipients opposite wall and center of F-side trio; arm baits NW/NE; Near side wall few notches from cardinal.
- **Branches:** Mid ring in front markers then tower center; remote wall then outer tower edge. Staff wait; blades follow laser closely. F-side arm baiter opposite rotation waits to end. Aggro tank must not take second World bounce into auto vulnerability.
- **Sequence:** Flex shape pairs; fan and remember physical mark. Resolve macro towers. Mini-congas allocate arm/World roles. Dodge rotating laser and stance; place six World roles; finish4x1+4x2.
- **Unresolved:** Exact near wall notches and same-rank conga ties left open by prose.

#### omega — `p5_omega`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [LPDU-linked P5 steps48–63](https://ff14.toolboxgaming.space/?id=955389449416761&preview=1) (text).
- **Role priority:** 2-stack II-mark MUST monitor before blank2-stack; exclude First in Line. Final3-stacks take tethers.
- **Axes:** First trueN,monitor E/W; final beetle=N.
- **Goals / waymarks:** First Far holder inside4th ring N/S or relativeW/E on safe side; receivers N/S wall cheated safe. Near holder opposite monitor4th ring; two Near recipients wall. Final tethers wall3 ticks from intercardinal toward beetle; Far holder E/W4th ring with wall receivers opposite; Near S4th ring with remaining wall receivers.
- **Branches:** Sword M away/shield M toward; adjust toward F for legs,away for staff, while obeying center orbs. Orbs mark safe side; second cleave flips. Required II-mark2-stack monitor takes precedence.
- **Sequence:** Read both clone pairs; dodge first then second. Mark monitors and Far receivers early. Resolve Worlds1 leaving2x3+6x2. Three-stacks grab tethers, second Worlds all3, heal tether tank before last Solar.
- **Unresolved:** Exact Near-receiver wall notches and permitted Far-holder alternatives need diagram calibration.

#### solar_ray — `p5_solar`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [P5 steps1,21,46,64; markdown general info](https://ff14.toolboxgaming.space/?id=955389449416761&preview=1) (text).
- **Role priority:** MT aggro; OT Provoke during first cast per toolbox. Tank jobs/available cooldowns modify later casts.
- **Axes:** Separate tanks so AoEs do not overlap.
- **Goals / waymarks:** First both full mitigation+Reprisal; second invuln; third consider sharing without WAR; fourth full mitigation.
- **Branches:** Prepop90s mitigation before third to recover for fourth. PLD+GNB third GNB full/PLD healer help; fourth PLD full/GNB healer help. 90s raidwide mitigation on second hit covers each trio.
- **Sequence:** Plan four casts and available cooldowns. Swap/invuln as specified. Heal after final tether then last Solar.
- **Unresolved:** Toolbox and post7.0 comp guidance not reconciled into every tank-composition table.

#### cosmo_memory — `p6_memory`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase6 Cosmo Memory](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** MT/OT positions explicit; tank LB job order not specified.
- **Axes:** True N/S.
- **Goals / waymarks:** Party in front of C; MT between A and middle; OT outside near B away from party.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Start C; set separated autos after Memory.
- **Unresolved:** Tank LB3 timing/job order and shields not explicitly in markdown P6 paragraph.

#### arrow_dive — `p6_arrow_dive`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase6 Cosmo Arrow1→Dive1](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** Party starts in front of2; tanks also start2; MT ends toward4 inside,OT toward1 inside.
- **Axes:** True numbered marks.
- **Goals / waymarks:** Party ends in front of2 (SE).
- **Branches:** In/out branch mentioned but full Plus/Box sequences not in markdown.
- **Sequence:** Start2; dodge Arrow. Re-form party at2; tanks move to4/1 directions near boss.
- **Unresolved:** Complete in-first/out-first footwork not specified; do not import Saus Arrow automatically.

#### exaflare_wave — `p6_exa_wave`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [Phase6 Exajoels1; raidplan slide1](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text_and_diagram).
- Source: [slide1 Wave cannon1](https://raidplan.io/plan/mh3bX4KJ9d8rT9nk) (diagram_visually_read).
- **Role priority:** WC1 MT N,OT E,H1 W,H2 S,M1 SW,M2 SE,R1 NW,R2 NE.
- **Axes:** True N; published waymarks.
- **Goals / waymarks:** After exaflares clockspread; final stack in front of C.
- **Branches:** Read exaflare start, group middle, move safe and follow.
- **Sequence:** Dodge exaflares; spread WC1. After both beams gather C.
- **Unresolved:** Exact exaflare exit offset, six-bait path and tank invuln order not specified in markdown.

#### arrow_wave — `p6_arrow_wave`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [Phase6 Arrow2; raidplan slide2](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text_and_diagram).
- Source: [slide2 Wave cannon2](https://raidplan.io/plan/mh3bX4KJ9d8rT9nk) (diagram_visually_read).
- **Role priority:** NW MT+R1; NE OT+R2; SW H1+M1; SE H2+M2.
- **Axes:** True quadrants; arrows relative to cardinal grid.
- **Goals / waymarks:** Slide2: MT goes E,OT W; H1 E,H2 W; R1/R2 S; M1/M2 N into arrow-safe lanes. After final dodge/beam stack C.
- **Branches:** Role/marker determines dodge; Plus/Box timing not fully represented by static slide.
- **Sequence:** Take quadrant pair positions. Use slide arrows to split TH horizontal/DPS vertical. Wait spread beams then gather C.
- **Unresolved:** Full start-pattern temporal branch not verified; static arrows are not complete timeline.

#### exaflare_dive — `p6_exa_dive`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [Phase6 Exajoels2→Dive2](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** MT through boss left;OT through boss right.
- **Axes:** Party final exaflare endpoint defines rear of Y.
- **Goals / waymarks:** Party outside hitbox where last exaflare exploded; tanks advance split Y.
- **Branches:** Confirm LB gauge before first melee LB.
- **Sequence:** Group/dodge exaflares. Hold party endpoint; tanks through boss left/right. Resolve Dive and melee LBs.
- **Unresolved:** Exact six-puddle path/exaflare offset not given by markdown.

#### meteors — `p6_meteors`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [Phase6 Meteors; raidplan slide3](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text_and_diagram).
- Source: [slide3 Meteor spreads](https://raidplan.io/plan/mh3bX4KJ9d8rT9nk) (diagram_visually_read).
- **Role priority:** WC1 but MT↔R1 and H2↔OT.
- **Axes:** True N/S meteor line.
- **Goals / waymarks:** Slide3: R1 N,MT NW,R2 NE,H1 W,H2 E,M1 SW,M2 SE,OT S. MT short cooldown R1;OT short cooldown caster.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Use meteor-specific spread after center bait. Tanks support ranged/caster.
- **Unresolved:** Caster/ranged LB timing, flare endpoints and tie-break branches not specified by inspected LPDU prose/three-slide spread plan.

#### magic_number — `p6_magic`

Evidence state: verified_text; coverage: unresolved_route.

- Source: [Full LPDU video and P6 mitigation references](https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md) (text).
- **Role priority:** Not established in LPDU inspected source.
- **Axes:** No verified directional assignment.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Tank/healer LB ownership and refund order require full LPDU video qNdjZOgCU1I or mitigation workbook. Video not watched.

### cn_moogle

#### loop — `p1_loop`

Evidence state: route_unresolved_macro_scope_only; coverage: unresolved_route.

- Source: [Page1 all-phase priority; pages1–2 route macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** Not established for this mechanic by macro.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Full mechanic-specific route not present in the inspected macro. Author's diagram/video required; no Elemental route inheritance. Shared priority does not establish matching spatial layout or branches.

#### pantokrator — `p1_panto`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page1 P1 全能之主](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2. Left high priority; right low.
- **Axes:** B/D start per macro; exact interpretation of left/right view must be checked against video.
- **Goals / waymarks:** Macro says BD起跑，左高右低.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Start from B/D convention, assign high/low side.
- **Unresolved:** Cone-pattern adjustment, missile/beam front/back and travel paths not resolved from macro; full guide necessary.

#### p1_cannons — `p1_cannons`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page1 P1 激光死刑 diagram](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** MT/ST north outside; D3 west,D4 east; H1,D1,D2,H2 southern interior.
- **Axes:** True A north, boss center.
- **Goals / waymarks:** Macro diagram top both tanks; A beneath tanks; D3–Omega–D4 middle row; H1 D1 D2 H2 lower row. Tanks outside circle, party inside.
- **Branches:** Not established from inspected evidence.
- **Sequence:** After panto place both tanks outside north and six inside in macro arrangement.
- **Unresolved:** Invuln timing and exact six laser angles/two-wave adjustment rule not stated. Do not use Elemental H1/H2 side layout: CN explicitly places D3/D4 sides.

#### party_synergy — `p2_synergy`

Evidence state: route_unresolved_macro_scope_only; coverage: unresolved_route.

- Source: [Page1 all-phase priority; pages1–2 route macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** Not established for this mechanic by macro.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Full mechanic-specific route not present in the inspected macro. Author's diagram/video required; no Elemental route inheritance. Shared priority does not establish matching spatial layout or branches.

#### limitless — `p2_limitless`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page1 P2 射手天箭](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** MT north-half tether; ST south-half tether.
- **Axes:** True A/C reference.
- **Goals / waymarks:** Party gathers A; fixed A/C tether pulls.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Group at A, tanks collect their half's tether and take fixed A/C layout.
- **Unresolved:** Arrow-dodge alternate branch, tether clockwise orientation, shield charge/Pile Pitch/flare resolution not given in macro. Party A differs from Elemental/KR C bait.

#### p3_transition — `p3_transition`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page1 P2.5 转场 diagram](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2. Manual: forbid1+bind1 pair,forbid2+bind2 pair; attack1–4 solo.
- **Axes:** A north,C south,D west,B east.
- **Goals / waymarks:** Forbid1+bind1 NW;forbid2+bind2 NE;attack1 W;attack2 SW;attack3 SE;attack4 E.
- **Branches:** Follow hand-mark timing; exact mark-to-debuff mapping not explicitly printed.
- **Sequence:** Receive manual markers and go six-slot layout. Handle transition timing per source reminder.
- **Unresolved:** Who is marked forbid/bind/attack and how same-class ties apply needs guide confirmation. Arm/ring dodge paths not specified by macro.

#### hello_world — `p3_hello`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page1 P3HW 提示+移动规则](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** Current debuff determines role; all-phase priority does not replace debuff logic.
- **Axes:** Boss targeting circle as radial reference.
- **Goals / waymarks:** Large-circle rot outside target circle; stack rot on circle; Near/Far tethers inside circle.
- **Branches:** Macro cycle: drop big→soak stack→drop stack→soak big (diagram cycle).
- **Sequence:** Identify rot/bug role and position by circle. Rotate through big/stack assignments.
- **Unresolved:** Tower colors, partner selection, rot-transfer route, blue/green break order, final-round exception absent from macro.

#### p3_monitors — `p3_monitors`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page1 P3 小电视：小电视点名在安全区](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2. No separately printed P3 priority override found.
- **Axes:** Boss safe side opposite monitors.
- **Goals / waymarks:** Player monitors named to safe area.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Marked players go safe side.
- **Unresolved:** Exact three monitor/five unmarked positions, facing angles, and rank order not given. Existing HTD P3 preset is not evidence of CN route.

#### blue_screen — `p4_wave`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page1 P4 蓝屏 diagram](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** West MT,D3,H1,D1; east ST,D4,H2,D2. Macro says D1/D2 swap.
- **Axes:** A north,C south; D/B west/east.
- **Goals / waymarks:** D3 atD,D4 atB; D1 near3,D2 near2; two stacks either sideC.
- **Branches:** D1/D2 adjustment explicitly named; trigger and stack-holder swapping not fully stated.
- **Sequence:** Use shown TRHM spread; gather southern split stacks; apply D1/D2 adjustment when source trigger confirmed.
- **Unresolved:** Do not infer southern marked player's swap from Elemental; macro only says D12换位. Three ring/echo sequences need guide.

#### delta — `p5_delta`

Evidence state: route_unresolved_macro_scope_only; coverage: unresolved_route.

- Source: [Page1 all-phase priority; pages1–2 route macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** Not established for this mechanic by macro.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Full mechanic-specific route not present in the inspected macro. Author's diagram/video required; no Elemental route inheritance. Shared priority does not establish matching spatial layout or branches.

#### sigma — `p5_sigma`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page2 P5二运二传](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** 1-Dynamis gets attack mark; no-buff idle gets forbid. Attack1/2/3 go F; remaining opposite; attack5 treated like forbid.
- **Axes:** F defines near/far split; tower orientation unresolved.
- **Goals / waymarks:** Manual marking time is emphasized.
- **Branches:** No-buff/idle terminology may exclude World holders; must confirm video rather than treating all unstacked players the same.
- **Sequence:** Apply manual mark categories. Attack1–3 group atF; others opposite; attack5 follows forbid category.
- **Unresolved:** Shape order/six-marker fan/tower macros, final receiver positions, bind/forbid meanings and laser rotation rules not provided.

#### omega — `p5_omega`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page2 P5三运三传 / 三运四传](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** First Worlds unmarked. Only1-Dynamis or Second-in-Line+1 → attack; only2 → bind; Second-in-Line+2 → forbid. Second resolution: Second-in-Line unmarked;2-Dynamis→attack;3-Dynamis→forbid.
- **Axes:** Not printed; source diagram required.
- **Goals / waymarks:** Manual marker categories verified; monitor/tether destinations not printed.
- **Branches:** First and second World resolutions use different marker classification. Two-stack Second-in-Line gets distinguished forbid mark rather than ordinary bind.
- **Sequence:** Apply first-resolution marker categories after timed prompt. Resolve first Worlds then reclassify to2-stack attack/3-stack forbid for second.
- **Unresolved:** Mapping forbid/bind to monitor recipients and tie selection must be corroborated by diagram/video; macro category alone is not full monitor rule. All six World locations, boss-relative axes and tether endpoints unresolved.

#### solar_ray — `p5_solar`

Evidence state: route_unresolved_macro_scope_only; coverage: unresolved_route.

- Source: [Page1 all-phase priority; pages1–2 route macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** Not established for this mechanic by macro.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Full mechanic-specific route not present in the inspected macro. Author's diagram/video required; no Elemental route inheritance. Shared priority does not establish matching spatial layout or branches.

#### cosmo_memory — `p6_memory`

Evidence state: route_unresolved_macro_scope_only; coverage: unresolved_route.

- Source: [Page1 all-phase priority; pages1–2 route macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** Not established for this mechanic by macro.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Full mechanic-specific route not present in the inspected macro. Author's diagram/video required; no Elemental route inheritance. Shared priority does not establish matching spatial layout or branches.

#### arrow_dive — `p6_arrow_dive`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page2 P6 八方站位 / 宇宙箭 / 宇宙龙炎](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2. Cosmo Dive: MT left out,ST right out.
- **Axes:** True eight-direction clock unless Dive-relative. Left/right relative to party facing boss; video orientation not independently confirmed.
- **Goals / waymarks:** N MT,NE D4,E ST,SE D2,S H2,SW D1,W H1,NW D3.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Take separate MT-left/ST-right Dive endpoints while party stacks.
- **Unresolved:** Full Arrow/Exaflare approach, starting quadrant, tank distance targets and both pattern branches not printed.

#### exaflare_wave — `p6_exa_wave`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page2 P6 八方站位 / 宇宙箭 / 宇宙龙炎](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** True eight-direction clock unless Dive-relative.
- **Goals / waymarks:** N MT,NE D4,E ST,SE D2,S H2,SW D1,W H1,NW D3.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Use macro eight-direction spread.
- **Unresolved:** Exaflare path/direction/offset, sixth-puddle exit, wave-stack direction and tank mitigation rotation unresolved.

#### arrow_wave — `p6_arrow_wave`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page2 P6 八方站位 / 宇宙箭 / 宇宙龙炎](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2. Second Arrow: tanks/healers cardinals; DPS diagonals.
- **Axes:** True eight-direction clock unless Dive-relative.
- **Goals / waymarks:** N MT,NE D4,E ST,SE D2,S H2,SW D1,W H1,NW D3.
- **Branches:** Role groups separate into cardinal TH and diagonal DPS lanes.
- **Sequence:** Use TH cardinals and DPS diagonals for second Arrow spread.
- **Unresolved:** Plus/Box footwork, quadrant pairing, spread beam timing and final stack direction unresolved.

#### exaflare_dive — `p6_exa_dive`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page2 P6 八方站位 / 宇宙箭 / 宇宙龙炎](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2. Cosmo Dive: MT left out,ST right out.
- **Axes:** True eight-direction clock unless Dive-relative. Left/right relative to party facing boss; video orientation not independently confirmed.
- **Goals / waymarks:** N MT,NE D4,E ST,SE D2,S H2,SW D1,W H1,NW D3.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Take separate MT-left/ST-right Dive endpoints while party stacks.
- **Unresolved:** Full Arrow/Exaflare approach, starting quadrant, tank distance targets and both pattern branches not printed.

#### meteors — `p6_meteors`

Evidence state: verified_macro_partial; coverage: partial_route_with_verified_rules.

- Source: [Page2 P6 八方站位 / 宇宙箭 / 宇宙龙炎](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** True eight-direction clock unless Dive-relative.
- **Goals / waymarks:** N D3,NW MT,NE D4,E ST,SE D2,S H2,SW D1,W H1.
- **Branches:** Swap MT and D3 from macro clocks for meteors; no H2/ST swap is printed.
- **Sequence:** Use meteor-specific MT/D3-swapped spread.
- **Unresolved:** Caster/ranged LB sequence, flare branches, E/W tie-break and healer-center assignment require diagram/video. Do not add LPDU's H2/OT meteor swap: CN macro lacks it.

#### magic_number — `p6_magic`

Evidence state: route_unresolved_macro_scope_only; coverage: unresolved_route.

- Source: [Page1 all-phase priority; pages1–2 route macro](https://docs.qq.com/doc/DSlBpR0JqSElVelhH) (canvas_macro_visually_read).
- **Role priority:** All-phase macro order H1 > MT > ST > D1 > D2 > D3 > D4 > H2.
- **Axes:** Not established for this mechanic by macro.
- **Goals / waymarks:** Not established from inspected evidence.
- **Branches:** Not established from inspected evidence.
- **Sequence:** Not established from inspected evidence.
- **Unresolved:** Full mechanic-specific route not present in the inspected macro. Author's diagram/video required; no Elemental route inheritance. Shared priority does not establish matching spatial layout or branches.

### kr_09stop

#### loop — `p1_loop`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.1_ rows 14–93; diagrams row 17](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=2089732780) (primary_source).
- **Role priority:** H1 > T1 > T2 > D1 > D2 > D3 > D4 > H2 Scan clockwise from true N.
- **Axes:** True N=12 o'clock; A north, B east, C south, D west.
- **Goals / waymarks:** Party initially 6 o'clock; 3s slightly inside to intercept. Use tower-free sectors for Blaster; others shelter by active tower's letter marker.
- **Branches:** Tower order 1234; tether order 3412. Initial N/S tower pair: 3s wait briefly so north tower soaker can pass. Outgoing holder stays still until tether taken.
- **Sequence:** Gather south, assign numbers/priorities. 3s intercept and move CW to empty sectors; 1s soak. Transfer 4→1→2 after each blast, taking numbered towers in order. Heal HP-penalty recovery before 3/4 towers; face boss N afterward.
- **Unresolved:** Every empty-sector tie is not formalized as executable geometry.

#### pantokrator — `p1_panto`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.1_ rows 98–178; row 103 image 11 (zero-based)](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=2089732780) (primary_source).
- **Role priority:** H1 > T1 > T2 > D1 > D2 > D3 > D4 > H2 Earlier number partner H1 group; later H2 group.
- **Axes:** True cardinal axes; six initial flame patterns in row 103.
- **Goals / waymarks:** H1 starts safe sector on north/west half; H2 opposite. Six-panel figure shows H1 NW,NNW,N,NNE,NE,W depending on initial flame sectors; H2 diametric.
- **Branches:** Move in observed CW/CCW direction. 1s ahead initially; 2–4 middle of safe wedge. Active missile exits through center, returns outside; other three share.
- **Sequence:** Identify safe wedge using row-103 pattern. Split all numbers into healer groups. Stagger puddles with flame; each number goes ahead then rejoins via outer lane. Repeat 1–4.
- **Unresolved:** Panel-to-exact flame angle mapping needs numerical transcription; do not substitute Elemental NW default.

#### p1_cannons — `p1_cannons`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.1_ rows 183–206](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=2089732780) (primary_source).
- **Role priority:** T1/T2 farthest north; six non-tanks spread.
- **Axes:** True N.
- **Goals / waymarks:** Tanks max-melee north with invulns; six inside hitbox.
- **Branches:** Three random non-tanks then complementary three. Source calls tank cleave 90°; Elemental says 120°. Preserve discrepancy.
- **Sequence:** Tanks north after panto. Non-tanks spread as row-186 figure. Time invulns without castbar; hold spread for two waves.
- **Unresolved:** Exact six non-tank positions in row-186 diagram not inspected in this pass. Tank cleave angle conflict needs encounter evidence.

#### party_synergy — `p2_synergy`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.2 rows 58,83–156,186,210,239–285; image 29 row166](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1552381437) (primary_source).
- **Role priority:** H1 > T1 > T2 > D1 > D2 > D3 > D4 > H2 used for west/east conga endpoints; H1 always group 1, H2 group 2. Same symbol west member group1, east group2.
- **Axes:** Eye=N for spread; three-male row=N for knockback.
- **Goals / waymarks:** Mid both O,triangle,square,X; remote left O,triangle,square,X, right X,square,triangle,O. Stay outside eye-beam waymark corridor. Remote knockback W/E at wall; mid W/S near marker after knockback.
- **Branches:** Both stacks same side: nearer-eye stack and same symbol partner trade. M sword/F legs→F; shield/legs→M; sword/staff→outside; shield/staff→shield lateral pockets. After gender swap tanks re-Provoke original assigned target.
- **Sequence:** Conga, identify groups; optional manual shape marks. Dodge M/F before tethers become relevant. Resolve shape spread with mid/remote distances. Check stack distribution; knockback by new male north.
- **Unresolved:** Initial complete role-to-conga order requires row-38 figure; source endpoint roles are explicit.

#### limitless — `p2_limitless`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.2 rows 290–461](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1552381437) (primary_source).
- **Role priority:** T1 west tether; T2 east tether. Two tanks closest to shield clone.
- **Axes:** True C south bait; external shield M for charge.
- **Goals / waymarks:** Party in front of C; tanks extend tethers clockwise outward. Party center for mitigation-heavy flare stack.
- **Branches:** Sagittarius source at N/S: center dodge insufficient; move toward numbered waymark where tether add spawned. Other arrow sources: move into boss hitbox. Beyond Defense victim circles opposite shield; unhit tank joins seven stack.
- **Sequence:** Collect assigned west/east tethers. Bait arrow C and use source-dependent dodge. Tanks bait shield charge; hit tank leaves. Seven share Pile Pitch/flares; use mitigation lasting through eye raidwide.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### p3_transition — `p3_transition`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.3 rows 9–114](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1826471436) (primary_source).
- **Role priority:** H1 > T1 > T2 > D1 > D2 > D3 > D4 > H2 conga; rank each debuff class independently.
- **Axes:** True N; arm triangle may invert.
- **Goals / waymarks:** Six assignment slots shown row18; text only does not name all directions.
- **Branches:** Wait outermost ring, step in after preceding ring, return out. At second ring plus first arm explosion step inward into first-arm safe space. Shield before spread.
- **Sequence:** Conga and separate purple, white, empty. Pair empty with white; purple separate. Dodge ring/first arms then second arms while preserving debuff spread.
- **Unresolved:** Full six-slot position map and priority direction not visually inspected; no inherited Elemental coordinates.

#### hello_world — `p3_hello`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.3 rows 118–303](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1826471436) (primary_source).
- **Role priority:** Roles assigned by debuffs; no fixed job-order tower assignment.
- **Axes:** Reorient to colored towers.
- **Goals / waymarks:** Blue tether between stack-color towers; green outside defamation-color towers. Defamation holders max-melee at waymark direction.
- **Branches:** Red-defamation and blue-defamation are both explicit. Towers/bugs resolve before tether holders move to acquire rot. Blue breaks while acquiring; then blue goes inward, green converges to break. Fourth round differs; exact row277 final figure still needs full audit.
- **Sequence:** Color holders move first without crossing each other; tethers wait. Resolve tower and bug. Tether holders approach nearest rot; defamation+green meet on marker. Blue breaks first then green; repeat.
- **Unresolved:** Final-round green-first/no-transfer exception not fully re-read in truncated KR text; verify rows 277–303 before declaring complete. Equal partner selection needs clarification.

#### p3_monitors — `p3_monitors`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.3 rows314–388; image40 row314 (east-facing boss)](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1826471436) (primary_source).
- **Role priority:** H1 > H2 > T1 > T2 > D1 > D2 > D3 > D4 separately for marked/unmarked.
- **Axes:** Boss true N; mirror across N/S for monitor side.
- **Goals / waymarks:** Boss east: marked1 NW facing W, marked2 WNW faces N, marked3 WSW faces S. Unmarked1 N west of midline,2 just E center,3 outer E,4 inner S west of midline,5 outer S west of midline.
- **Branches:** West boss monitor mirrors all positions. Optional fixed-DPS unmarked variant: nonmonitor DPS remain preset; TH fill northern position and vacated DPS spots; D3 may replace D4. Monitor angle should align with square waymark edges.
- **Sequence:** Rank marked/unmarked. Position by boss monitor side. Aim each player monitor at two intended receivers; keep 1/4/5 off boss half. Resolve before enrage.
- **Unresolved:** Fixed-DPS variant's complete role-slot picture not transcribed. Exact angle tolerances and receiver pairs require calibrated geometry.

#### blue_screen — `p4_wave`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.4 rows15–220; image0 row15](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=776696341) (primary_source).
- **Role priority:** West T1,D3,H1,D1; east T2,D4,H2,D2.
- **Axes:** True N; south stacks between 3/C and C/2.
- **Goals / waymarks:** DPS on waymarks; tanks/healers between; boss hitbox is spread reference.
- **Branches:** Two stack markers one side: southern marker trades with opposite melee. Return original slots after each stack. Wave2: spread then inward ring dodge then stack. Wave3: stack outside then wait for ring before inward.
- **Sequence:** Spread eight beams. Move to two southern groups avoiding echo beams; adjust if needed. Repeat with wave-specific ring timing. Bring boss below20%.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### delta — `p5_delta`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.5_Delta rows149–359; row338 images38/39 show both cleave sides](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=895996912) (primary_source).
- **Role priority:** Tether/color and starting inner/outer pair determine jobs; no role priority claimed. OUTER pair swaps sides for identical fist colors.
- **Axes:** Beetle=N; Final opposite; side cleave selects E/W half.
- **Goals / waymarks:** Blue to beetle, green to Final; one outer pair and one marker-line pair each. Final World differs from Elemental: Far holder close to center at safe cleave boundary; Near holder near beetle-side intercardinal, one floor unit inward. Unmarked blues outer safe cardinal ±2 floor notches; original outer green pair near opposite-beetle intercardinal, two units inward; other green pair far endpoints by beetle and opposite.
- **Branches:** Blue2 (outer) breaks on activation then joins blue1. After fists: blue1 breaks and baits beetle arms; blue2 baits Beyond Defense. Green1 outer baits Final arms; green2 inner baits side arms. Monitor faces opposite Final; charge victim excluded even if monitor. Break green1 only after monitor/charge ruin expires; green2 after World vulnerability expires. Reflect World layout when safe cleave side changes.
- **Sequence:** Set lanes; outer fist pair adjusts. Stack fist partners after activation break. Bait arms and charge, resolve monitors/three-person Pile Pitch. Move into safe half; make staggered green cuts and World positions.
- **Unresolved:** Fist pairing initial tie-break not specified; exact floor-unit coordinate scale needs arena calibration. Source describes eye safe line ambiguously; diagram should govern.

#### sigma — `p5_sigma`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.5_Sigma rows49–347; row287 image24, row145 image16](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=791137168) (primary_source).
- **Role priority:** Group pairs in O,triangle,square,X order. Manual: one-stack/no-World players claim bind1–3; remaining no-World claim attack1–3.
- **Axes:** First M=N; tower four-tower side defines orientation; final F=N.
- **Goals / waymarks:** Two-mark pairs assigned N/S then W/E; one-mark pairs use opposite arm diagonals, unmarked away from arm. Bind1 NW arm,bind2 N far receiver,bind3 NE arm; Far holder N third ring. Attack1 S far receiver; Near rotates90° with laser to side; attack2/3 on either side of near-side arm, separated two notches.
- **Branches:** Mid at waymarks and tower centers; remote at wall/tower outer edge. Select tower using remembered physical waymark macro and actual 4-tower side; layout can invert. F staff wait outside cross; legs follow laser. Near side rotates with CW/CCW; bind1/3 fixed relative NW/NE regardless of rotation.
- **Sequence:** Assign shape spread and count red markers. Remember waymark and select knockback tower via macro. Assign bind/attack marks and go N/S groups (Far N,Near S initially). Resolve F stance, rotating laser, arm baits and Worlds; finish 4x1+4x2.
- **Unresolved:** Exact per-waymark tower macro mapping must be transcribed from #Simulater&Macro; do not use Elemental mapping by assumption. Both laser directions not fully visually audited; selected CW diagram read.

#### omega — `p5_omega`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.5_Omega rows25–260; images36 row183 and38 row229](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=577861208) (primary_source).
- **Role priority:** First monitors: 2-stack Second in Line > 2-stack no-World; First in Line excluded. Final tethers: two 3-stack players; other six resolve Worlds.
- **Axes:** First boss monitors true E/W; final beetle=N.
- **Goals / waymarks:** Monitor recipients inside intercardinal on boss-monitor half; Far holder N or S third ring, Far receivers N/S wall cheated safe. Near holder on opposite B/D side third ring; Near receivers wall ±2 floor notches. Final tethers near NW/NE wall two floor notches toward beetle from intercardinal; Far holder E or W third ring, receivers E/W wall slightly south; Near S third ring and wall recipients ±2.
- **Branches:** M/F four combos classified inner/front-of-marker/outside-marker; central light selects cardinal; second cleave reverses. KR calls lit side safe; preserve difference from Elemental prose. World1 must leave 2 players at3 and six at2; World2 all3.
- **Sequence:** Solve first and second M/F combos sequentially. Manually mark required monitor recipients; place six World roles. Resolve monitors/World1. Three-stacks take beetle tethers; execute second World layout; heal tanks for Solar.
- **Unresolved:** Four-combo icon decision tree not fully visually transcribed; source light wording conflicts with Elemental. Tie-break among equally eligible two-stack no-World players remains free/manual.

#### solar_ray — `p5_solar`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.5_Delta rows11–16; #Phase.5_Omega rows270–275](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=895996912) (primary_source).
- **Role priority:** Tank composition determines swap or invuln; specific composition workbook linked.
- **Axes:** Boss north, separate tanks.
- **Goals / waymarks:** Two consecutive hits on aggro target; swap with mitigation or invuln both.
- **Branches:** Four occurrences. T1 and D3 use90s mitigation on first Solar second hit to cover trio raidwides. Final Solar: start mitigation before Worlds finish, not after cast starts.
- **Sequence:** Plan invulns/cooldowns by comp. Take both hits or swap between. Heal next aggro tank before trio.
- **Unresolved:** Linked tank composition sheets not audited; exact four-cast plan unresolved.

#### cosmo_memory — `p6_memory`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.6_Alpha Omega rows9–19](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449) (primary_source).
- **Role priority:** WAR > PLD > GNB > DRK tank LB; negotiable.
- **Axes:** True N; exit south wall.
- **Goals / waymarks:** MT north inside; other tank west max-melee for farthest autos; party inside.
- **Branches:** Three Dynamis required; Tank LB3 plus party mitigation. Distinct MT and farthest player must take autos.
- **Sequence:** Enter arena; tank LB cast. Set north/west tank autos.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

#### arrow_dive — `p6_arrow_dive`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.6_Alpha Omega rows21–85](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449) (primary_source).
- **Role priority:** T1 11 o'clock, T2 1 o'clock, six-person party7 o'clock.
- **Axes:** True N for first Arrow.
- **Goals / waymarks:** Tanks end inside boss at11/1; party hitbox boundary SW.
- **Branches:** Inside-first: wait inner border→in→wait again→out to number markers splitting TH left/DPS right facing boss→wait at letter line→side→in. Outside-first: wait outer border→out→wait again→forward→side (TH left/DPS right)→forward.
- **Sequence:** Preposition three groups. Read inner/outer-first and perform listed sequence. Finish separated tanks and six-player stack for Dive.
- **Unresolved:** Workbook calls Dive three closest targets, conflicting with Elemental two closest plus farthest; route positions are independently supported. Animated Arrow figures not frame-by-frame audited.

#### exaflare_wave — `p6_exa_wave`

Evidence state: verified_text_and_selected_diagrams; coverage: partial_route_with_verified_rules.

- Source: [#Phase.6_Alpha Omega rows87–142; row121 image4](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449) (primary_source).
- **Role priority:** Tanks front of final south stack.
- **Axes:** True clocks; first exaflare and observed CW/CCW arc.
- **Goals / waymarks:** N D3, NE D4, E H2, SE D2, S T2, SW D1, W H1, NW T1. Start center; move opposite spawn progression toward marker preceding first exaflare. Guide recommends an extra half-marker offset for safety, then follow arc through six puddles. Final eight stack south.
- **Branches:** Four random beams then other four; stay assigned clocks. 15s party mitigation after sixth bait;10s debuff about30% into11s cast to cover stack.
- **Sequence:** Bait six puddles. Spread eight clocks. Resolve both beam sets then south stack with two tanks front.
- **Unresolved:** Exact tank invuln rotation delegated to linked mitigation sheet.

#### arrow_wave — `p6_arrow_wave`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.6_Alpha Omega rows149–219](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449) (primary_source).
- **Role priority:** Pairs by quadrant; TH left, DPS right when facing boss.
- **Axes:** True arena quadrants.
- **Goals / waymarks:** N D3, NE D4, E H2, SE D2, S T2, SW D1, W H1, NW T1. Start four two-player pairs; spread naturally into clocks; final stack south.
- **Branches:** Inside-first: wait inner border→in→wait again→out to number markers splitting TH left/DPS right facing boss→wait at letter line→side→in. Outside-first: wait outer border→out→wait again→forward→side (TH left/DPS right)→forward.
- **Sequence:** After autos pair for Arrow. Execute independent inner/outer-first pattern while separating two beam sets. Gather south with tanks front.
- **Unresolved:** Exact pair-to-quadrant layout and animated timing not fully audited.

#### exaflare_dive — `p6_exa_dive`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.6_Alpha Omega rows222–258](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449) (primary_source).
- **Role priority:** T1 relative11, T2 relative1; party relative6. Melee LB D1 then D2, except DRG later.
- **Axes:** Final bait location defines relative S.
- **Goals / waymarks:** Start center; move opposite spawn progression toward marker preceding first exaflare. Guide recommends an extra half-marker offset for safety, then follow arc through six puddles. After sixth bait take one more step; six stay hitbox boundary; tanks enter boss split left/right.
- **Branches:** Rotate route with exaflare start/direction. After Dive party slightly in and farthest tank out for autos.
- **Sequence:** Bait six puddles and extra step. Tanks enter Y endpoints; six stack. Use two melee LB3s and restore autos.
- **Unresolved:** Same Dive target-selection wording conflict as first Dive.

#### meteors — `p6_meteors`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.6_Alpha Omega rows264–313](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449) (primary_source).
- **Role priority:** D4 caster LB3 then D3 ranged LB3 from A. Healers can step in; choose center healer before pull.
- **Axes:** True N/S meteor axis.
- **Goals / waymarks:** N D3, NE D4, E H2, SE D2, S T2, SW D1, W H1, NW T1. Center bait then eight spread; D3 remains north during LB.
- **Branches:** D3 no flare: three flares B/C/D, five stack A. D3 flare: other flares B/D, five stack C. Tank/melee flares max-melee; healer/ranged flares wall. Workbook says six comets; Elemental says five. Do not resolve using assumption.
- **Sequence:** Bait center AoE, spread and caster LB. Healers top up through four random-AoE waves. Ranged LB A→C after refill. Resolve flares/stack around locked D3.
- **Unresolved:** E/W assignment tie-break among flare holders not specified. Comet-count conflict requires encounter evidence.

#### magic_number — `p6_magic`

Evidence state: verified_text; coverage: partial_route_with_verified_rules.

- Source: [#Phase.6_Alpha Omega rows320–324](https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=473115449) (primary_source).
- **Role priority:** Default T1→H1 then T2→H2; DRK may tank LB first.
- **Axes:** No directional dependency.
- **Goals / waymarks:** Tank LB3 before hit; healer LB3 after debuff visibly applied within6s.
- **Branches:** Do not healer LB immediately on damage before debuff exists. Optional DRK suicide variant is explicitly optional. Last healer refund enables final melee LB3.
- **Sequence:** Tank LB, receive debuff, healer LB. Repeat second pair. Final melee LB and enrage burst.
- **Unresolved:** Text/macro supplies this logical sequence; exhaustive diagram geometry, every equivalent-role tie, and encounter-level validation were not completed in this research pass.

## Handoff and validation

The JSON is an audit specification, not a drop-in runtime route implementation. Preserve evidence locations when turning a verified rule into model code. Resolve each entry's open facts before promoting it to a faithful regional route. Validate exactly100 unique `(community, catalog_id)` pairs,20 entries per community, the catalog mapping against `top/data/catalog.json`, and absence of implementation claims. No runtime tests were changed or run because this task only adds research artifacts.

