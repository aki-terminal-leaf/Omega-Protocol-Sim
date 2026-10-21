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

2026-10-22 correction: four-clear status observations and the primary P1 guide
confirm actual First/Second/Third/Fourth in Line in Program Loop and Pantokrator.
They now originate in runtime grants, persist without fabricated countdowns,
and are removed by actual tower cleansing / missile resolution respectively.
The earlier rejection of these effects was incorrect. Pantokrator missile/beam
variants retain their observed per-duration packet IDs (3424/3495-3497 and
3507-3510). Successful hits grant real Magic Vulnerability Up as well.

The generic training knockback-resistance control has no job-specific status
packet identity. Its timer is shown under a neutral name/text fallback, not
falsely labeled Arms Length on a caster. Empty route labels are not printed as
blank failure advice. This pre-acceptance review produced a new candidate;
previous candidate launch evidence is not final platform acceptance.

## v0.3.3 全機制查核

[逐機制狀態表](../research/MECHANIC_STATUSES.md) 列出開始訊號、正確解法
仍會取得的Debuff，以及真正消除／轉換的效果。原版封包查核與100方法
模擬覆蓋分開記錄；後者不拿來證明前者。JSON恢復後的浮點actor ID、
實際Bot疾跑、Brilliant→Spark、機制訊號清除也有驗收。
