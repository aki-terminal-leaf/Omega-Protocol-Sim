# TOP 全流程回放預覽 v0.1.0

日期：2026-10-28。這是既有 Godot 練習器旁的**單場流程回放預覽**，不是全部原版演出完成，也不改變獨立選機制／打法的練習預設。Godot Web／Windows v0.3.35 與判定完全不變。

已部署獨立入口：<https://top.servicing.cc/replay-v0.1.0/index.html>；[GitHub 開發預覽／離線包](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-replay-v0.1.0-preview)。來源 `e33319e`，公開 HTTPS 12項內容、全新 AnAn Chromium 的實際播放／暫停／特效開關／P6按鈕略過／8個原始隕石常駐效果與收尾通過；正式 Web35 的 HTML／部署資料／執行素材未變。

## 本版限定完成與驗證

- 使用 AnAn 本機原始資源，整合一場完整事件紀錄的 P1～P6 播放；P6 強制過場及擊殺後劇情不在範圍，P3 仍屬戰鬥的轉階段攻擊保留。
- 1,226 個 C012 觸發／120 種技能、原始模型與既有動作、32 個有狀態移除或線型轉換支持的動態連線。原檔／編譯／貼圖數字不當成保真完成率。
- 隕石／彗星的 IMC 隱藏本體不冒充可見外觀；改用原始常駐 AVFX，但只認證「已觀察目標活動區間」的顯示接線，不宣稱真實出生／消失。已見過亮／過大等外觀差異，保真仍 OPEN。
- 82 個精確 C063 SoundIndex 子流與557個音效觸發；音效需手動開啟。不要用多子流聲音庫的第一段代替正確索引。BGM、原版定位／混音與聽覺保真未驗收。
- 實際 AnAn Chromium：六階段十四處初次渲染與三組連線預覽、修正後完整 UI 8× 連播（223 次狀態採樣、原時計18:29.404）、P6 過場略過、結尾特效／音效清理，無 JS／shader 錯誤。
- 原生 WebAudio 在靜音下驗證暫停、1×／2×、0.5／1／2秒偏移、seek 舊節點清理與結束無殘留；實際 bfcache 離頁／返回後可再啟用。**靜音 API 驗證不是聽覺驗收。**
- 凍結來源後做 Sonnet 實作／Opus 唯讀審查與父代理裁決；審查不替代畫面、原始資料或平台測試。source-evidence.json 綁定來源與接受包；原整場證據之後只修了 pagehide 的持久快取分支，另做受影響的實際返回測試，不重跑未改動全流程來製造進度。

## 來源、失敗與時間界線

主紀錄為 [FFLogs LKMGRJTzgY9HFynk / fight2](https://www.fflogs.com/reports/LKMGRJTzgY9HFynk?fight=2)，參照 [Kooper 全通關影片](https://www.youtube.com/watch?v=5P8VnTECmO4)。**兩者不同場**；原事件毫秒保留，不套全場固定偏移／拉伸。影格比較仍是離散採樣，並非逐幀／全部90單元保真驗收。

原96個演出單元排除6個強制／擊殺後過場，剩90個在範圍；[逐項 JSON](../research/FULL_REPLAY_COVERAGE.json) 全部保守保留 partial_not_certified。主紀錄明確是兩大隕石＋六小彗星；歷史「五小」文字已在本清冊更正，不重開已關閉的數量問題。

保留兩個原始失敗：背景 compositor 截圖逾時改成實際 WebGL 畫布讀回；第一次整場8×只到P5，因背景 rAF1Hz配上舊250ms上限丟失經過時間。回放沒有逐步物理積分，改用完整非負經過時間，換階段載入完成重設基準；修正後同一完整流程才到結尾。前次失敗沒有改成成功。

## 仍未完成

塔場景生命週期、部分世界頭標與完整狀態HUD、背景／場景、未知連線解除（原94條中62條缺直接解除依據）、精確特效開始／停止／材質／UV／shader／光照、隕石真正出生／消失與全部音樂／聲音保真。C0126～30秒外框是**有界預覽包絡**，不是原版 host 停止語義；polyline 是來源曲線驅動的重建，不是原生 spline／扭曲執行器。

[全部20／102攻略與最佳化／AVFX路線圖](TOP_DEVELOPMENT_ROADMAP.md)繼續，不能用本回放通過替代攻略互動、玩家責任或完整原版渲染器驗收。角色外觀是代用裝備；部分模型貼圖有縮圖／重編碼。此回放不重算碰撞、命中或通關判定。

## 原始碼與使用

[獨立回放來源與構建契約](../../tools/full_replay/README.md)。遊戲媒體、原始事件快取、解碼音效及私人平台日誌不進 Git。新構建輸出明示未驗證，需實際平台檢查才能發布。

## 發版檔案核對

ZIP為77,539,480 bytes，SHA-256 `737264bcdbc6a42ba9b7bb190232f55679e53627bf7679f521cc0982de9e1194`；ZIP逐檔 CRC／SHA、GitHub伺服器size／digest皆吻合。公開前的隱藏分頁測試未收到 rAF 的失敗保留，改為只對本任務分頁做focus-emulation，沒有啟用OS焦點或全域輸入。草稿tag API404依release ID收回，沒有建立重複草稿；metadata的預設Python請求403，與本機／既有描述性驗證UA回應核對後續行，沒有重新上傳資產。

[限定驗證摘要](FULL_REPLAY_PREVIEW_VALIDATION.json)綁定來源、兩個接受bundle與公開啟動；原始私人平台日誌不進Git。所有task CDP targets、暫存HTTP server與音效節點已清理；使用者Chrome及其他分頁保持原狀。
