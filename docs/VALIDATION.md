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
