# v0.2.0 驗證紀錄

環境：Godot 4.4.1；Linux Compatibility／Mesa；AnAn Windows／原生 OpenGL；Chromium WebGL2。以下證明程式與操作行為，**不代表所有原戰鬥規則、素材或各區服戰術已完全還原**。

## 自動驗收

- `tests/rules.gd`：**190 assertions，0 failures**。
- `tests/interactions.gd`：**18 assertions，0 failures**。快速穿線不漏接、接線後 Blaster／畫面 owner 同步、跨輪不自動換人、站在線上不來回搶線、再搶線、實際目標吃 debuff、Ruin 疊二層、過期、同號換塔合法、只站正確終點無法代替接線、塔＋Blaster、Looper 過期、實際近遠選人、合法 World 路徑不必等於攻略建議。
- `tests/run.gd`：**27,180 snapshots，0 failures**。20 項機制 × 五種底層約定 × 48 個種子的理想快照；此測試明確不當成過程接線證明。
- `tests/runtime.gd`：**93 complete courses，0 failures**。每種 UI 實際可選的機制／解法 × 三個種子，含開始前必須先選機制／解法、Bot 真正走位、接線、結算與結束後不接續其他機制。
- 接線專項擴測：**192 組 Program Loop＋48 組 Limitless，皆 0 failures**。前者四種解法 × 48 種子；後者 48 種子。Limitless 初測揭露來源左右錯配與起始站位問題，修正後只重跑該模組 48 組。
- Linux／Windows import 無 GDScript parse errors；原生 Linux 與 Windows，以及 Web 匯出皆完成。

## AnAn 真正桌面操作

先以原生 Godot 驗證，再啟動匯出的 `TOP-Practice-Lab.exe`／PCK，而非只以跨平台匯出成功當作實機測試。

實際透過 UI：選 Program Loop、選 HTDH、按開始；使用真正的相對滑鼠事件與帶掃描碼鍵盤事件操作。驗證與 JSON 紀錄一致：

- 右拖 240/-60 像素 → yaw -0.48、pitch 0.79；之後 W 的世界位置沿新鏡頭方向改變。
- 左鍵自由轉鏡頭不改人物朝向；滾輪改距離；跟隨可開啟；重設回 yaw 0、pitch 0.91、距離 44 並關閉跟隨。
- Space 跳躍，暫停時保存的高度約 2.23；不是原型的 Space 暫停。
- 1 疾跑、2 防擊退的剩餘時長可讀；3 突進從初始位置移動 15 個訓練單位。
- 雙鍵／中鍵前進均實際改變角色位置。
- 玩家走位曾接走 Bot 的線，Bot 隨後再接回，紀錄保留 from/to/time；不是靜態畫線。
- 匯出的 Windows 執行檔再次實測環繞鏡頭、W、縮放與跳躍，JSON 為 version 0.2.0、practice 模式，沒有以示範冒充玩家操作。

桌面自動化曾發現兩個工具層差異：僅 SetCursorPos 不產生遊戲需要的 raw mouse delta；不帶 scan code 的鍵盤事件也不足以代表遊戲輸入。已改用對應 Windows 事件重新實際驗證。這不是以 API 直接改玩家位置通過測試。

## Web 黑箱

`tools/web_smoke.py`，固定 1440×900 桌面畫布，在實際匯出的 WebGL2 build 上操作：

1. 選機制，再選該機制的攻略。
2. R 開始、WASD 移動、P 暫停。
3. 右拖旋轉鏡頭、滾輪縮放；Space 跳躍。
4. R 保留種子並重設起點。
5. 換機制後必須重選攻略，R 不可偷跑。
6. 實際下載／解析 JSON；**0 browser errors**。

## 尚未證明

- 遊戲伺服器真正的接線半徑、server tick、雙線所有權分支與全部 debuff／傷害時長。
- 完整 Hello World 接觸感染／Debugger、P5 真正線狀態、所有出現模式與所有區服攻略。
- 原版高精度美術／骨架動作、完整職業減傷／輸出／HP／LB 量表／延遲、八人聯機或控制器。
- GitHub Actions 未啟用，僅有範本；以上都是已執行的本機／AnAn／瀏覽器驗證。

[逐項精確度與未完成事項](research/FIDELITY.md) · [實際看過的素材參考](research/VISUAL_REFERENCE.md)

## 2026-10-21 exported UI font follow-up

Actual Chromium pixels on the P6 production development build exposed missing
glyphs in the older Noto Sans TC subset (including 突進, 鏡頭 and the circled
flow numerals). Rebuilt the existing SIL-OFL font with maintained FontTools from
the cached original, covering current top/*.gd/*.json/*.tscn/*.godot source text
and common punctuation/symbol ranges. Required source CJK and①②③Ω coverage
is checked against the output cmap; no game assets are added. This is a font
resource fix, not a new mechanic or an engine upgrade. Export/runtime visual
verification follows this commit; local evidence retains both before/after pixels.

The primary regional Noto Sans TC source itself omits31 simplified/Japanese
characters used in current source labels/provenance. The first all-source cmap
check exposed that limit. Added an11,424-byte fallback subset from the maintained
full Noto Sans CJK TC font, with its SIL-OFL license and package/export inclusion.
Combined required CJK/①②③Ω coverage:638 distinct characters, zero missing.
The original font-fix commit remains preserved; the fallback is a separate
reviewable correction, not a rewritten remote commit.

## Bounded Web P6 evidence — 2026-10-21

Exported from clean source `dd08409eb2626d96bf4bcef5d151082cbd8959fa`, Godot4.4.1,
private local-asset PCK SHA-256 `5cdadd5bd08108b2ba8b467966caf779242f706a4fa5a7dc3702b0a40e902bc9`. No release uploaded.
Chromium/WebGL2 software-rendered selection pixels were actually inspected:
missing label/flow glyphs are fixed. Task-local copies of the exported HTML used
engine args `-- --scenario=... --player=... --seed=17391`; shipped scripts/PCK
were unchanged. This is focused input QA, not mouse-menu coverage.

Actual keyboard F and downloaded reports independently establish tank/caster
begin+finish, no legacy success flag, blocked D/sprint/jump during lock, caster
ground[0,0], nominal4.5s cast and continuing8.1s post-cast lock. Browser wall
waits were not treated as simulation time: retained caster reports advanced
2.681→3.336→4.001→4.934s using a bounded four-observation gate.

**Overall Web acceptance remains incomplete.** The final caster screenshot
failed with `Page.screenshot: Connection closed while reading from the driver`
after the input assertions. The exit cause is unproven; no OOM or product crash
claim is inferred. Final console-clean status and ranged mouse target selection
are not proved. Retained actual JSON and failure logs are local; no blind rerun.
Native Windows input/visual QA, release packaging and engine migration are pending.

Harness lessons: prefix the existing with_server HTTP command with `exec` so
cleanup owns the actual server, not only a shell; the one stale task-owned child
was identified by exact PID/command and stopped. Web user arguments require the
`--` separator. Software-rendered wall time can advance less simulation time;
assert action deadlines against exported simulation timestamps.

## Godot/GDScript4.7.2 migration acceptance —2026-10-21

Official Linux executable/templates match the pinned release SHA-256 digests;
separate worktree/cache, no4.4 cache reuse. Error-sensitive targeted gates: Rules
196/0, Contacts21/0, Stateful72/0, Review211/0, P1 events1266/0, HW quick2002/0,
Limitless quick92/0, P3 quick2268/0, P4 quick279/0, P6 movement1614/0, LB602/0
with production locks, controls20/0. ContinuousP5:15/0. Original models12 and
equipped players7:0 failures. Actual Main all20 mechanics/86 offered methods,
seed17391:0 failures. Initial unsupported P1 --quick attempt exceeded its150s
budget; retained as incomplete, replaced by the supported events gate.

Native Windows exact exported PCK: physical D, relative right mouse, wheel, Space,
P pause/R retry pass; CLI preselected scenario (not manual-menu proof). Tank and
caster physical F request+finish and actual postlocks block D/sprint/Space.
RX7900XT OpenGL3.3; actual resize1280×800 and1440×900 passed; original model/font
pixels inspected. Linux exported executable startup passes.

Chrome155.0.8059.80 on AnAn: actual menu/strategy/start/move/pause/orbit/zoom/jump/
same-seed retry/JSON download/new-mechanism-needs-strategy pass; **zero final
browser errors**, clean Web source1e0a3cb6. A preceding run's only console issue
was confirmed /favicon.ico404, corrected by the explicit empty data-URL favicon.
The two initial menu-driver attempts selected the placeholder, not a product
judgment failure; actual inspected row558 and explicit Windows UTF-8 decoding
are now in the portable smoke tool. This does not claim native ranged-target UI
or a new published build.

Gameplay PCK for nativefb7fab6 and Web1e0a3cb6 is identical:
`c685ce1dcab84d1d2618e8f742c753c6c7df9caf1555b4a9532109a164b35806`.
Project baseline now pins4.7.2; remaining fidelity/source gaps are separate
publication blockers. No original media or raw private logs were staged.

## Ordinary walking consistency —2026-10-21

Removed the last11-unit fallback from `Movement.speed`; ordinary bots across
all drills now use6 like the human. Explicit logged Sprint still uses7.5.
Actual Main affected-route matrix338/0:320 Party Synergy courses (all32 clone
families ×five methods ×two allocations),18 monitors (six methods ×three
allocations). Maximum measured ordinary speed6.0000169, elapsed51.981s under
Godot4.7.2. The explicit instant Discharger knockback is not a walking step.
No geometry, source pattern, snapshot duration, hit check or player movement
was changed to make this pass. Native/Web acceptance before this increment
retains its exact earlier source/PCK scope; it is not silently a release test
of later commits.


## Published v0.3.0-preview —2026-10-21

Latest user ordering is **publish the accepted preview first, then finish the
remaining items**. Earlier conditional-publication wording above is historical,
not a requirement to ask permission again. Published2026-10-21T10:37:09Z:
https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.0-preview

Immutable tag/source `0e7ef03224ddd390fc90d3c64ff83932ca50ede9`, prerelease=true,
draft=false. Allfive uploaded asset SHA256 digests/sizes matched the already
tested candidate before/after publication; no rebuild or reupload. Shared final
PCK: `988d6c750aa692f8a032e5889d00cae19cfad6d0fa5e83d97697e6c513eb89b3`.

Final Windows4.7.2 SDK gates: source599e77c Main20mechanics/86methods +hiddenP5
5/0; final0e7ef03 precision55/LB602/controls20/Meteors5, all0failures. Final
actual shipped Web/Chrome155 selection→strategy/start/move/pause/orbit/zoom/
jump/retry/JSON and new-mechanism-needs-strategy:0errors. Final native physical
movement/orbit/zoom/jump/retry pass. Real healer F after actual Doom:2-second
cast then cleanse; real ranged dropdown selection of meteor_1, F before bot
schedule,4.5-second finish and actual two large-NPC kills; movement/sprint/jump
blocked through respective postlocks. Ranged used an assisted16.2s checkpoint,
not unassisted full clear or original large-enrage measurement. Linux final
package startup passed. Earlier native tank/caster gates retain their exact
fb7fab6 source scope; do not silently relabel those as fresh0e7 input tests.

Remaining contact/edge/timing/damage/source/region/original-VFX uncertainties are
still disclosed in the released notes and FIDELITY.md. Publishing a preview is
not full completion. Subsequent original-effect geometry/portability validation
is documented in [VFX_PIPELINE](research/VFX_PIPELINE.md) and is **not** included
in the published binaries. No Actions CI pass is claimed.


## Post-publication P6 source-scoped menu integration —2026-10-21

Added14 menu entries for already implemented P6 profile conventions across
Arrow→Dive, Exaflare→Wave, Arrow→Wave and Exaflare→Dive. All entries explicitly
limit claims to their supported fields; unknown offsets/temporal routes remain
unknown. Source code for event geometry, schedules, movement and routes is
unchanged. Existing options are preserved. New development catalog:20mechanics,
100options including extra variants—not100 fully verified community/mechanic
cells. The immutable released0e7 binary remains86options.

Actual Main affected-route gates in Godot4.7.2, seed17391:4mechanics ×5profiles,
20completecourses/0failures. New `tests/p6_route_options.gd`:20actual selections,
93assertions/0failures; verifies selected profile reaches actual encounter data,
E/S stacks and LPDU southeast/paired conventions differ, and unknown escape
angles/completeness flags survive menu selection. This is not merely counting
renamed aliases. All updated UI CJK characters are covered by current fonts.

This does not claim a new full100-option regression, fresh native/Web export or
full original regional temporal fidelity. Previously validated finite-pattern
and published-platform gates retain their exact earlier source scope.


## Published v0.3.1-preview: headless-only —2026-10-21

Published2026-10-21T14:00:43Z, prerelease=true, draft=false:
https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.1-preview

Immutable source `be97a09ffb634a9a63229efd1eddfa664a2c2938`. Allfive uploaded
asset SHA256 digests/sizes matched before and after publication. Windows/Linux/
Web share PCK `1adad6dd7fe6a8248f26b21ddc2d186a4360a14442912766d3ba63328804293a`.
The source ZIP retains its exact tagged README; this documentation-only update
is later and does not rebuild or replace the released files.

- Source gates after the final input change:17 Input.parse_input_event checks,
  24 Main presentation,106 actual party-status and60 camera assertions:207/0.
- Actual exported Windows and Linux headless P6 all-bot courses, seed17391:
  nine snapshots, no failures, final training checkpoint30.5 seconds (within
  float precision). Not physical-input tests or original large-meteor enrage.
- Actual headless Chrome155/WebGL2: mechanism→strategy/start, camera-relative
  WASD, pause, orbit, wheel, jump, same-seed restart and JSON download;0errors.
- Three independent actual Web P6 human D3 runs: no world click, quick world
  click, right-button drag. Each selected meteor_1 through the real HUD, waited
  for observed LB refund, pressed F, completed one actual human cast, reduced
  both large NPC15726 HP to zero, paused and downloaded real JSON;0errors.
  No exitPointerLock workaround or actor/time/HP injection counted as a pass.
- Actual Web P1 missed tower reached failure at simulation13.4s; only the failed
  snapshot enabled advice. R retry cleared failures and hid advice again;0errors.
  Software-rendering wall-clock slowdown was handled by observing simulation
  time, not by changing encounter timing. Headless canvases were inspected.

All verification after the latest explicit user constraint was headless: no
PyAutoGUI, desktop input/focus/window operations, desktop screenshots, headed
browser or interactive Godot. Earlier385edeef physical Windows basic/tank/
caster results remain historical, not relabeled be97 native-window acceptance.
The earlier100-option actual-Main matrix remains scoped before final display/
input fixes; the final increment reran affected checks, not every course.

Twenty drills and100 currently offered options are not100 source-certified
regional timelines. Original VFX execution, unmeasured geometry/timing/damage
and other [FIDELITY](research/FIDELITY.md) limits remain active. AVFX topology
inventory is source-reviewed tooling, not original particle playback. No Actions
CI pass is claimed. Neither the older0.3.0 tag nor its assets were altered.

## 2026-10-22 immersive practice HUD

Headless Godot 4.7.2: presentation 27, input routing 19, party status 107,
camera 60 assertions; zero failures/script errors. Start/retry defaults to
world + eight-member live status HUD, with only necessary P6 LB controls.
Training title/countdown/hotbar/menu/review do not cover ordinary practice.
Tab explicitly toggles tools; Escape opens paused setup. Resuming returns to
the clean view and preserves prior user pause ownership and all runtime data.
Actual ranged/caster requests still use the same authoritative target bindings.
Exported pixel/platform checks belong to the later artifact gate, not these tests.

## 2026-10-22 original arena source gate

All 34 BG exports succeeded. Inspection caught missing BG-specific diffuse/normal
sampler IDs; corrected and re-exported before acceptance. Parent verified every
converted hash, 34 models/103 placements. Godot 4.7.2 imports and six-phase checks:
3880 assertions, zero failures; shared presentation 27 and camera 60 still pass.
Four existing package-evidence tests pass; no official-export-specific unit tests
exist (zero tests was not counted as a pass). Game assets stay ignored.
Local headless Chromium's driver closed while loading the 210MB candidate PCK;
no local pixel gate passed. Windows headless GPU acceptance is tracked separately.

The reusable public exporter was separately run against the local SqPack; every
one of the 34 GLB SHA256 values and all 103 placement records exactly reproduced
the inspected pack. Evidence: main/artifacts/top-immersive-20261022.

Initial Windows headless Chrome pixel/input/download checks passed for P1 Loop,
P3 Hello World and P6 Meteors: true player practice, 1440x900 world, camera follow,
no hints, JSON downloaded, zero browser/script errors. Pixel inspection then
identified the invalid opaque vertical-fog surfaces; final acceptance must use
the corrected pack rather than relabeling these initial screenshots.

Final corrected source gate: arena 3972, presentation 27, input routing 19,
party statuses 107, camera 60, P6 controls 20 assertions; zero failures/errors/skips.
All 34 final converted hashes and 77 original diffuse-tint material bindings were
verified. Three original shader-only fog meshes are deferred, not drawn opaque.
Version 0.3.2-preview exports must pass their own final artifact checks.

## Published v0.3.2-preview (headless only, 2026-10-22)

Source 020e8b4858b4476843122d1f946753656128be18; all three platforms share
PCK SHA256 0ba6429b9897a25ecbf5f77d90e5a1013f232192da0c4b62be46ce6e1b1c441e.
Exact exported Windows and Linux headless P6 demos finish at simulation 30.5s
with no failures. Final headless Chrome six phases (Loop/Synergy/Hello World/
Wave/Delta/Meteors) pass real R/P/Tab and JSON download, 1440x900 player view,
no hints and zero browser/script errors. All six final canvas captures reviewed:
original floors/props and eight-member status HUD visible; opaque white fog
sheets absent. P1-P5 backgrounds remain dark: original fog/emissive/lighting
shaders are not reconstructed. This is not full original-renderer fidelity.
All five release asset sizes and GitHub SHA256 digests match; previous releases
are unchanged. No desktop operations or native-window manual acceptance.
After publication, removed only ignored/regenerable exports and verified matching
ZIP staging; local game pack, SDKs/templates/version caches, source ZIP/checksums,
build metadata, reference archive, QA evidence and all user backups remain.

## v0.3.3-preview — exact source and original-media gates (2026-10-22)

- Godot/GDScript/templates4.7.2-stable. All tracked runtime source/data/font-import
  inputs match the committed tree; the font importer settings were explicitly
  restored before the final export, rather than reusing default regenerated inputs.
- All100 offered independent methods: actual live-party status audit260837 checks,
  zero failures. All300 actual Main courses (three fixed seeds per method), zero
  failures after the physical coincident-ray handoff repair. This is not100 full
  regional temporal routes or exhaustive original/server RNG verification.
- P1 fidelity1746/0; actual status lifecycle13061/0 including packet-duration
  regressions; party projection110/0; marker71/0; facing ring19/0; actual GUI input
  routing19/0; source P3 hit-effect17/0. The original-pack P3 gate additionally
  verifies that both left/right loading nodes use imported game geometry.
- Final exported WebGL on headless Windows Chrome/D3D11: P1 Ctrl+4 self mark,
  actual clear, marker popup/Escape, R restart/QE-facing input, unchanged numeric
  debuffs, game-only view; P3 loading/fire/impact capture/video; P6 Magic Number
  state/report. Three scenarios, zero console/page errors.
- Exact final Windows exported executable: headless P6 Meteors30.5 simulation
  seconds, zero failures, report version0.3.3-preview. Exact Linux exported executable also passed30.5 simulation seconds/0 failures;
  all three platforms share the independently SHA-verified PCK. Upload integrity
  is verified during publication; no native desktop/window
  pixel acceptance is claimed from headless proof.
- A preliminary visual pass exposed near-camera waymark occlusion. Its images
  were rejected for the README; the final pass uses smaller/fading glyphs, the
  more readable wall/monitor patterns, and the exact repository font inputs.
- Earlier full local300-course process exhausted memory; not counted as a pass.
  Test scene frees are now serviced between courses; final matrices ran in an
  isolated Windows source project. Broad ray-separation prototypes regressed
  larger Omega matrices and were rejected; only latched actual-collapse recovery
  passes both the original reproducer and the complete854-check Omega gate.

The README GIF is a transcode of the final exported-game recording, not a guide
movie or hand-authored animation. P3 uses original meshes/textures with a
reconstructed attachment/material/envelope, not a full direct AVFX runtime.
Full HP/jobs/deaths, all spawn families, some collision/timing policies and some
regional temporal routes retain the limitations in FIDELITY.md.


## v0.3.4-preview — stable setup UI (2026-10-22)

Setup geometry498/0 (all100 unique methods;175 selections including resize cases),
actual Linux rendered source smoke25/0, presentation27/0, input20/0, marker
library36/0 and marker GUI9/0. Long labels, phase changes, conditional P6
controls and fullscreen-return preserve the same1048x604 logical preview.
The README setup image is from the actual Linux exported executable; its
PCK SHA256 is `389eb42a8ea97d7e1836b702b038c08a3fd49fe129e471970c73aaef498aaaaf`. Final packaging must match that rendered PCK.
Windows native verification is unavailable (AnAn offline). Web export succeeded
but browser driver connection closed during live-page/screenshot verification;
not a pass. v0.3.4 release scope is Linux/source only; existing Windows/Web
v0.3.3 assets are unchanged. See [interface design](development/INTERFACE_REDESIGN.md).


## v0.3.5 practice preferences — 2026-10-22

- Source setup/layout:498 checks,175 repeated method selections,0 failures.
- Actual X11/Mesa-rendered new preferences gate:97 checks,0 failures; all20 names in3 locales, display-only switching during paused practice, exact preview bounds,3 successive new-seed starts, native R preserving encounter/spawn, fixed seed42, settings persistence/migration/unrelated-key preservation, bottom instructions unclipped and non-overlapping.
- Presentation27/0, input20/0, marker-library36/0, marker-input9/0. Total687 passing checks this iteration; not additional encounter fidelity certification.
- Initial presentation regression asserted the former fixed bottom offset; new footer intentionally raises controls. Replaced that test with actual window enclosure, usable height and non-overlap with instructions, then reran all four targeted regressions successfully. Failing log retained.
- Actual native-render screenshots are labeled as such in README. Web is a user-test deployment, not browser-play acceptance; previous VPS900MiB browser cap prevented completion. Fixed-domain HTTPS/transport proofs are separate from gameplay gates.

- Deployment follow-up:fixed https://top.servicing.cc survived named connector restart; root and all7complete resource SHA256s/MIME/gzip/isolation headers match the60d0bfed6fa4 snapshot. Cloudflare browser-integrity check rejects Python urllib1010; unchanged security settings, curlHTTP2/gzip passed.
- Exact Linux archive PCK matched both real native-window setup and seed42demo capture. Published Linux/source only as top-v0.3.5-preview, source60d0bfed6fa45ceb7e30acb3338332233256534a. Browser gameplay remains user-test pending; no Windows/Web released-platform acceptance claim.

## 0.3.8-preview source chronology/cues —2026-10-22

[All20 clocks, evidence, fixes and limits](research/PRACTICE_TIMELINES.md).
Final unique Main matrix300 courses/0,2397 independent observed-timing checks/0;
320 PT plus18 monitor physical courses/0, max ordinary speed6.000019/s.
PT now waits for actual symbols/new-north visibility; monitor actors no longer
spawn on their answers. PT16663, enemy rings340, markers33 and shared13737
assertions all pass; continuous P5 after Solar5/3.2s15 courses/0.
Source-only fallback logic, original native model wiring and final exported
platform proof are deliberately separate. The earlier210s matrix timeout and
harness failures remain retained; they are not converted into a pass.


### Late damage-preview follow-up (explicit user request0.5s)

All20 actual moving Main courses,110 preview/deadline/renderer/non-mutation
checks,155 independent source-time comparisons and33 marker lifecycle checks:
zero failures. Includes exact0.5/0.5001 boundaries, teaching mode, pause/retry,
and production-rendered PT cross-checkpoint Laser/five-male windows. All queued
decorative damage previews identify their actual deadline; untagged cues are
explicitly classified. No judge timestamp, geometry or speed change. Prior
300-method and338 physical courses remain the unchanged logic evidence, not
claimed as newly rerun. One test-harness parse/type failure is retained; it was
corrected before the passing run. Original damage VFX and browser certification
remain separately scoped.
