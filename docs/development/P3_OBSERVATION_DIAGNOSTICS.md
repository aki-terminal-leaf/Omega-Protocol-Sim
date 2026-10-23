# P3 observation diagnostics — v0.3.19 Web-first release

The fixed Web deployment is now v0.3.19-preview-web-test after the actual new-PCK,
exported-browser and public HTTPS checks passed. This increment adds read-only information status, not movement, a solution
hint, a timing deadline or a new player confirmation step.

## Behaviour

| State | Meaning / UI |
|---|---|
| inactive | Not a P3 public-selection beat; no cue suffix |
| uninitialized | Observation has not been established |
| waiting_marks | Waiting for current sniper debuffs |
| waiting_source | Public debuffs available; no first-wave source recorded |
| partial_first_wave | One or two currently published first-wave sources |
| observed | Valid previously displayed source memory; never a first-side answer |
| assisted | Explicit checkpoint reconstruction; never live/manual credit |
| blocked | The source set was rejected; optional existing R retry notice |
| invalid_record | Malformed/inconsistent record; optional existing R retry notice |

Normal waiting, partial and observed states add only a neutral Tab-overlay suffix.
Normal ordinary practice stays clean. Blocked/invalid records reuse the existing
status panel without pausing the game, enabling answers or changing a grade.
Existing finish/failure/assistance feedback remains. One neutral review line may
be added at an actual teaching-beat judgment; it is not a physical failure.

The additive format-3 report key is p3_observation. Its six primitive fields are
status, marks_seen, checkpoint_assisted, source_onset, sources_seen and
reason_category. Sources are clamped to the first-wave count 0..3, not second-wave
or direction information. source_onset remains source_unknown. The per-judgment
journal gains only p3_observation_status. Raw runtime evidence remains separate.

There are no source IDs, positions, first orientation, rank, waypoint, delay or
deadline in the derived object. It does not lazily begin/repair/publish state or
claim actual NPC motion for deliberately malformed legacy records. No mutation,
timer threshold or maximum-delay claim is introduced.

## Source validation (not exported-platform acceptance)

- Pure diagnostic fixture: 848 assertions, zero failures. Simulated public receipts,
  malformed/cache/JSON boundaries, primitive output, no mutation/aliasing, hidden
  metadata noninterference, both orientations and shifted legal times.
- Actual Main: 210 assertions, zero failures, including 82 normal ordinary frames
  across first-source publication, four normal demo snapshot statuses and zero
  unexpected diagnostic review lines; rejection/missing-model fixtures, real
  retry/checkpoint handling and unchanged physical grades.
- Existing P3 Main151, physical-key40positive+3negative/508, public walking71/490 and
  shared20mechanism Main regression all pass. The 4200 partition proof remains
  the unchanged v0.3.18 baseline, not a new rerun.
- The entire previous observation module is a byte-identical prefix. Seven Main
  motion/lifecycle methods are unchanged. Independent review found no production
  blocker; its required normal-frame scan was added and passed. Earlier CLI
  timeout, test-fixture/output-format/syntax and end-boundary failures are retained,
  not presented as successful runs.

## Reproduction

Use pinned Godot4.7.2 with an isolated same-version import cache/assets:
~~~sh
Godot --headless --path top --script res://tests/p3_observation_diagnostic.gd
Godot --headless --path top --script res://tests/p3_diagnostic_main.gd
~~~

Fresh affected-PCK and real exported-Web UI/report checks are required before
Web-first publication. Ordinary Web does not inject broken state to fabricate an
error-path screenshot; forced rejection/missing-model cases above are explicitly
headless Main fixtures. Native evidence remains pending; the owner has now
made AnAn desktop available for verification. Full guide/player-preparation coverage, original onset/HP/shields,
measured optimization and complete AVFX remain active.

## Deployment closure

Runtime/source tag: 5d790cd70c6a986defc845ddc6a5d7d82084abe9. Fixed URL:
https://top.servicing.cc . Seven exact-PCK affected gates passed; normal actual
Web UI/downloaded reports verify the six-field waiting/observed/reset diagnostics
without injecting broken game state. Rejection/missing-model error paths remain
explicit headless-Main fixtures, not ordinary Web pixel proof. Actual WebGL2 uses
VPS Chromium / SwiftShader, CSS1440x900 / DPR0.5; no physical-GPU/native claim.
All public canonical and decoded-gzip hashes and a fresh HTTPS startup pass.

Web and exact-Git source ZIPs, sanitized verification and SHA256SUMS are published
at https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.19-preview .
Native evidence is still pending; the owner has now made AnAn desktop available.
No Windows19binary has yet been published. Documentation closure
is separate from the runtime commit and does not rebuild the accepted export.
