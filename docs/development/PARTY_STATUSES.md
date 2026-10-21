# Independent practice: party statuses and failure review

Normal practice shows the selected player, eight actual party members, live
status icons, stacks and simulation-clock remaining seconds. Hovering an effect
shows its complete name. Unknown identities retain text rather than guessed
icons. No HP bar is fabricated because combat HP is not simulated.

`party_statuses.gd` projects state without mutating it. It reads runtime statuses,
Dynamis, current Brilliant eligibility/spending, actual tank LB start/end, Magic
Number target/expiry, Looper expiry, and actual self-buff timers.
`party_status_definitions.json` records small Status.csv identity/icon facts;
original PNGs remain optional, ignored local assets and are not in source Git.
Runtime status IDs resolve unknown simulation keys when a verified definition
exists. Expired runtime effects override beat metadata. KO rows are explicit.

Party Synergy marker/Glitch and monitor loaded-side metadata come from their
actual random assignments, not from route labels, suggested positions, ideal
facing, distance bands, or strategy priority. Their metadata has no verified
expiry, so no timer is invented. This does not calibrate previously unmodeled
status application times or make existing training durations server-accurate.

Suggested positions, World jump paths, assignment labels and explanatory beat
text are hidden in normal practice, including ordinary pause and regardless
of a legacy saved hint preference. Checkpoint/retry captions are neutral.
An actual failed snapshot enables paused failure review with reasons and a
reference treatment; retry/advance closes that review. Finished runs retain
failure text. An explicitly non-scored demonstration may separately enable
teaching hints. Exported developer reports retain their full replay evidence.

Source validation on Godot4.7.2: party runtime/Main policy106 checks, camera60,
Main presentation24, independent review211, P6 controls20, all passing; actual
Main all100 offered fixed-seed courses passed before the final icon-only
fallback improvement (no judge or route changes). Linux rendered player view
was inspected. These are not Windows/Web exported input or pixel acceptance.

The first failure-review test caught RichTextLabel.append_text not updating
its text property, so the mirrored HUD omitted appended review text. Logging
now updates the authoritative rich text property; actual failure/retry tests
verify the visible mirrored review, not only the source feedback widget.

Review also rejected an inferred In Line icon for Program Loop: its actual
Looper expiry is sufficient; route/order numbers must not invent another buff.

Pantokrator displays its already-granted missile and wave countdowns with
verified shared icons. Their multiple same-name Status.csv variants are not
resolved by the current model, so the definition retains status_id=0 rather
than guessing a particular variant. No numbered In Line buff is fabricated.

The generic training knockback-resistance control has no job-specific status
packet identity. Its timer is shown under a neutral name/text fallback, not
falsely labeled Arms Length on a caster. Empty route labels are not printed as
blank failure advice. This pre-acceptance review produced a new candidate;
previous candidate launch evidence is not final platform acceptance.
