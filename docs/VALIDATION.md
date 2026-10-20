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
