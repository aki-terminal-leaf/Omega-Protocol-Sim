# TOP 共用動作模組計畫 — 2026-10-30 / Telegram50853

## 目標及範圍
同一份 Godot 動作實作可獨立播放（GIF-like mini showcase），亦可由 TOP 編排層呼叫。重用現有 asset_lab_unit/composite 與 cinematic_player，不另建引擎或服務。以現有96項 inventory 為母清單，九個原始clip是補充來源樣本，不把它們當作96項中的九項已完成。

只有視覺：模型、材質、骨架動畫、VFX、場景、時間與生命週期。保留 Play/Pause、選取後暫停於0、1x、播完停住、不循環/不自動接下一段。無音訊、無Unity、無整場戰鬥/練習遷移重啟、無桌面操作/公開發行。

## 實作順序
1. **共用介面（本階段）**：新增輕量 ActionModule facade，分接現有 unit/cinematic backend；明確單一時鐘擁有者，外部秒數取樣、不重複_process推進；選取/播放/暫停/重設/清理；獨立實例隔離。新增簡易 showcase 使用者入口，及非整場戰鬥的外部時鐘呼叫範例/測試。來源不支援/缺件要保留診斷，不能由 facade 消除或冒充成功。原始clip與機制unit採不同ID namespace。
2. **96項覆蓋映射**：逐項連結既有 performance/source status、缺件、source uncertainty 與視覺 gate；不憑數量或來源窗口宣稱完整動作。對未知資料不編造位置、時序/host stop/材質/掛點。
3. **逐項補齊與實際演出**：補原始材質/貼圖/vertex資料、動畫、特效及生命週期；依來源問題分批派工。原材質包缺MDL/MTRL/TEX是已知阻塞，不能用模組架構掩蓋。
4. **動態與編排驗收**：每項完整演出有實際動態畫面；同一ActionModule被獨立入口與受控編排fixture呼叫，測試重播/同時實例/切段/結束/清理/缺件。render/匯出只走當前已授權非桌面途徑；數值PASS不等於視覺PASS。
5. **來源交付**：審查通過的連貫 source increment 推到既有開發分支；原遊戲媒體留ignored/private。96項視覺驗收全部完成之前，不發布半成品展示包、改現有release/Web或宣稱all96完成。整場整合不是本計畫自動授權。

## 第一階段驗收
真實AnAn Godot 4.7.2 headless：九個原始clip透過共用facade的獨立/外部時鐘結果一致；normal1x/pause/reset/end/no-chain；多實例不干擾、dispose後無新增孤兒；unit backend重用原96定義且保留缺件/unsupported狀態。可測具體來源子集，不做全96的虛假數字通過。
AnAn Codex隔離worktree；模型<=10分鐘、每個headless子程序<=90秒、1.5GiB job限額與8GiB free floor，序列重型測試。父層凍結精確來源SHA，獨立驗收及跨家族重點審查；保留原失敗，必要修正後才驗該變更。

## 現有來源
- 已接受播放器：reports/top-simple-playback-50831/parent-acceptance-v2.json（30個來源SHA）
- 原材質阻塞：reports/top-material-preserve-50830/parent-adjudication-v1.json
- 96母清單：top/data/asset_lab/catalog.json、performances.json、inventory.csv

狀態：PLANNED → IMPLEMENTATION_START；非視覺完成或全96完成。
